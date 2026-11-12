# Wisecow on Kubernetes

Wisecow is a small Bash web server that shows a cow saying a random fortune.
This repository containerizes it, deploys it to Kubernetes, builds and tests
it automatically with GitHub Actions (CI/CD), and serves it over HTTPS (TLS).
It also contains two small operations scripts (Problem Statement 2).

Original application: https://github.com/nyrahul/wisecow

## Repository contents

| Path | Purpose |
|---|---|
| `wisecow.sh` | The application (listens on port 4499) |
| `Dockerfile` | Builds the container image |
| `k8s/deployment.yaml` | Runs 2 replicas of the app |
| `k8s/service.yaml` | Gives the pods one stable internal address |
| `k8s/ingress.yaml` | Routes HTTPS traffic to the Service using a TLS secret |
| `.github/workflows/ci.yml` | CI/CD pipeline (build, push, deploy, smoke test) |
| `scripts/health_check.py` | Application health checker (Python) |
| `scripts/log_analyzer.sh` | Web server log analyzer (Bash) |
| `sample/access.log` | Sample access log for the log analyzer |

## Prerequisites

Docker, kubectl, kind, openssl, and Python 3 (for the health checker).

# Problem Statement 1

## 1. Run with Docker only

```bash
docker build -t wisecow:test .
docker run -d --name wisecow -p 4499:4499 wisecow:test
curl localhost:4499
docker rm -f wisecow
```

## 2. Deploy to Kubernetes (kind)

Create a local cluster, then apply the Deployment and Service:

```bash
kind create cluster --name test
kubectl apply -f k8s/deployment.yaml -f k8s/service.yaml
kubectl get pods
```

The Deployment uses the public image
`ghcr.io/danishwani1999/wisecow-devops:latest`, which is built by the
GitHub Actions pipeline described below.

Quick test through the Service:

```bash
kubectl port-forward svc/wisecow 8081:80
curl localhost:8081
```

## 3. Enable TLS (HTTPS)

Install the ingress controller and wait until it is ready:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.1/deploy/static/provider/cloud/deploy.yaml
kubectl wait --namespace ingress-nginx --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller --timeout=300s
```

Create a self-signed certificate (keep the key OUT of the repository) and
store it in the cluster as a TLS secret:

```bash
mkdir -p ~/wisecow-tls && cd ~/wisecow-tls
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=wisecow.local" \
  -addext "subjectAltName=DNS:wisecow.local"
kubectl create secret tls wisecow-tls --cert=tls.crt --key=tls.key
```

Apply the Ingress and open a tunnel to the ingress controller:

```bash
kubectl apply -f k8s/ingress.yaml
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8443:443
```

In a second terminal:

```bash
curl -k --resolve wisecow.local:8443:127.0.0.1 https://wisecow.local:8443
```

`-k` is needed only because the certificate is self-signed. The connection
uses TLS 1.3 and the certificate subject is `CN=wisecow.local`.

## CI/CD pipeline (GitHub Actions)

The workflow in `.github/workflows/ci.yml` runs on every push to `main`
(and can be started manually). It has two jobs:

1. **build-and-push**: logs in to GitHub Container Registry with the built-in
   `GITHUB_TOKEN`, builds the Docker image, and pushes it with two tags:
   `latest` and the commit SHA.
2. **deploy** (runs after the build succeeds): creates a temporary kind
   cluster inside the GitHub runner, applies the Deployment and Service,
   switches the Deployment to the image that was just built (the commit SHA
   tag), waits for the rollout to finish, and runs a smoke test with `curl`.

Note: the deploy job targets a temporary cluster that disappears when the job
ends. It proves that every new image can be deployed and verified
automatically, but it does not update a long-running cluster. The Ingress is
not part of the pipeline because it needs the ingress controller and a TLS
secret.

## Design notes

- The container runs as a non-root user.
- The Deployment sets CPU and memory requests and limits, and a readiness probe.
- TLS is terminated at the Ingress; the app itself still speaks plain HTTP.
- The image name is lowercase because container registries require it.
- The repository is public, as required by the assessment instructions.
- Private keys and certificates are never committed (see `.gitignore`).

# Problem Statement 2

Two objectives were chosen from the list: the Application Health Checker
(Python) and the Log File Analyzer (Bash).

## Application Health Checker

`scripts/health_check.py` sends an HTTP request to a URL and reports whether
the application is UP or DOWN. A status code from 200 to 399 means UP. An
error status (4xx, 5xx) or no response at all (connection refused, timeout)
means DOWN. The exit code is 0 when UP and 1 when DOWN, so other tools can use
the result.

```bash
python3 scripts/health_check.py http://localhost:4499
```

Example output:

```
[2026-11-11 05:27:25] http://localhost:4499 is UP (HTTP 200)
[2026-11-11 05:27:07] http://localhost:4499 is DOWN (no response: [Errno 111] Connection refused)
[2026-11-11 05:27:10] https://github.com/this-page-does-not-exist-xyz is DOWN (HTTP 404)
```

## Log File Analyzer

`scripts/log_analyzer.sh` analyzes an Apache or Nginx access log (combined
format) and prints the total number of requests, the number of 404 errors, a
count per HTTP status code, the most requested pages, the IP addresses with
the most requests, and the pages that returned 404.

```bash
./scripts/log_analyzer.sh sample/access.log      # top 5 in each list
./scripts/log_analyzer.sh sample/access.log 3    # top 3 in each list
```

Example output for the sample log (shortened):

```
Total requests : 20
404 errors     : 6

--- Top 5 most requested pages ---
      5 /
      2 /missing.html
      ...

--- Top 5 IP addresses by number of requests ---
      5 203.0.113.7
      4 192.168.1.10
      ...
```

The sample log includes one IP address (203.0.113.7) probing paths such as
`/wp-admin` and `/.env`, which is the kind of pattern the analyzer helps spot.

## Possible improvements

- Deploy to a persistent cluster (cloud or self-hosted runner), or use a
  GitOps tool such as Argo CD.
- Use cert-manager with a real domain and Let's Encrypt instead of a
  self-signed certificate.
- Add image vulnerability scanning to the pipeline.
- Run the health checker on a schedule and send alerts when the app is DOWN.
