FROM ubuntu:24.04

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      fortune-mod fortunes-min cowsay netcat-openbsd && \
    rm -rf /var/lib/apt/lists/*

# fortune and cowsay install into /usr/games
ENV PATH="/usr/games:${PATH}"

# run as a non-root user
RUN useradd --create-home --uid 10001 wisecow
WORKDIR /app
RUN chown wisecow:wisecow /app
COPY --chown=wisecow:wisecow wisecow.sh .
RUN chmod +x wisecow.sh

USER 10001
EXPOSE 4499
CMD ["./wisecow.sh"]
