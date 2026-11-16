"""Test real object reads with short-lived metadata credentials, never keys."""

import json
import os
import urllib.error
import urllib.parse
import urllib.request


def access_token():
    request = urllib.request.Request(
        "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token",
        headers={"Metadata-Flavor": "Google"},
    )
    with urllib.request.urlopen(request, timeout=10) as response:
        return json.load(response)["access_token"]


def object_status(bucket, token):
    bucket_path = urllib.parse.quote(bucket, safe="")
    request = urllib.request.Request(
        f"https://storage.googleapis.com/storage/v1/b/{bucket_path}/o/health.txt?alt=media",
        headers={"Authorization": f"Bearer {token}"},
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            response.read()
            return response.status
    except urllib.error.HTTPError as error:
        status = error.code
        error.close()
        return status


def run(allowed, restricted, expected_allowed):
    token = access_token()
    passed = True
    for bucket, expected in ((allowed, expected_allowed), (restricted, 403)):
        status = object_status(bucket, token)
        matched = status == expected
        print(json.dumps({"test": "bucket_read", "bucket": bucket, "http_status": status,
                          "expected_status": expected, "passed": matched}), flush=True)
        passed = passed and matched
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(run(os.environ["ALLOWED_BUCKET"], os.environ["RESTRICTED_BUCKET"],
                        int(os.environ["EXPECTED_ALLOWED_STATUS"])))
