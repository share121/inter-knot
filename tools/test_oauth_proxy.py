import os
import sys
import requests


def main() -> int:
    proxy_url = os.environ.get("OAUTH_PROXY_URL")
    code = os.environ.get("OAUTH_CODE")
    redirect_uri = os.environ.get("OAUTH_REDIRECT_URI")
    verifier = os.environ.get("OAUTH_CODE_VERIFIER")

    missing = [k for k, v in [
        ("OAUTH_PROXY_URL", proxy_url),
        ("OAUTH_CODE", code),
        ("OAUTH_REDIRECT_URI", redirect_uri),
        ("OAUTH_CODE_VERIFIER", verifier),
    ] if not v]
    if missing:
        print("Missing env vars:", ", ".join(missing))
        return 1

    res = requests.post(
        proxy_url,
        json={
            "code": code,
            "redirect_uri": redirect_uri,
            "code_verifier": verifier,
        },
        timeout=20,
    )
    print("status:", res.status_code)
    print(res.text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
