"""Exit successfully only when the private endpoint returns HTTP 200."""

import json
import os
import time
import urllib.error
import urllib.request


def probe(url, attempts=24, delay=5):
    # Direct VPC egress startup can take over a minute. Bound the total wait.
    for attempt in range(1, attempts + 1):
        try:
            with urllib.request.urlopen(url, timeout=5) as response:
                status = response.status
            print(json.dumps({"test": "private_http", "attempt": attempt, "http_status": status}), flush=True)
            if status == 200:
                return 0
        except (urllib.error.URLError, TimeoutError, OSError) as error:
            if isinstance(error, urllib.error.HTTPError):
                error.close()
            print(json.dumps({"test": "private_http", "attempt": attempt, "error": type(error).__name__}), flush=True)
        if attempt < attempts:
            time.sleep(delay)
    print(json.dumps({"test": "private_http", "result": "failed"}), flush=True)
    return 1


if __name__ == "__main__":
    raise SystemExit(probe(os.environ["HEALTH_URL"]))
