#!/usr/bin/env python3
"""Application health checker.

Usage: python3 scripts/health_check.py [URL]
Prints whether the application is UP or DOWN, based on the HTTP status code.
Exit code is 0 when UP and 1 when DOWN, so other tools can use the result.
"""
import socket
import sys
import urllib.error
import urllib.request
from datetime import datetime


def check(url, timeout=5):
    """Return (state, detail) for the given URL."""
    try:
        with urllib.request.urlopen(url, timeout=timeout) as resp:
            code = resp.status
    except urllib.error.HTTPError as err:
        code = err.code  # the server answered, but with an error (404, 500, ...)
    except urllib.error.URLError as err:  # could not connect at all
        return "DOWN", f"no response: {err.reason}"
    except (socket.timeout, TimeoutError):
        return "DOWN", f"no response: timed out after {timeout}s"
    except Exception as err:  # anything unexpected, e.g. a malformed URL
        return "DOWN", f"error: {type(err).__name__}: {err}"

    if 200 <= code < 400:
        return "UP", f"HTTP {code}"
    return "DOWN", f"HTTP {code}"


def main():
    url = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:4499"
    state, detail = check(url)
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{now}] {url} is {state} ({detail})")
    sys.exit(0 if state == "UP" else 1)


if __name__ == "__main__":
    main()
