import argparse
import json
import sys
import urllib.error
import urllib.request


def build_payload(action: str) -> dict:
    return {
        "action": action,
        "discussion": {
            "title": "test discussion",
            "html_url": "https://example.com/discussions/1",
            "author": {"login": "tester", "author_association": "NONE"},
        },
    }


def request(
    url: str,
    method: str,
    headers: dict,
    body: bytes | None,
    use_proxy: bool,
) -> tuple[int, dict, str]:
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    if use_proxy:
        opener = urllib.request.build_opener()
    else:
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    try:
        with opener.open(req, timeout=10) as resp:
            status = resp.status
            resp_headers = dict(resp.headers.items())
            text = resp.read().decode("utf-8", errors="replace")
            return status, resp_headers, text
    except urllib.error.HTTPError as err:
        text = err.read().decode("utf-8", errors="replace")
        return err.code, dict(err.headers.items()), text
    except urllib.error.URLError as err:
        return 0, {}, f"URL error: {err}"


def main() -> int:
    parser = argparse.ArgumentParser(description="Test GitHub webhook endpoint.")
    parser.add_argument("--url", required=True, help="Webhook URL")
    parser.add_argument("--event", default="discussion", help="X-GitHub-Event")
    parser.add_argument("--action", default="created", help="Payload action")
    parser.add_argument("--method", default="POST", help="HTTP method")
    parser.add_argument("--payload-file", help="Path to JSON payload file")
    parser.add_argument("--health", action="store_true", help="Send GET request only")
    parser.add_argument(
        "--use-proxy",
        action="store_true",
        help="Allow system proxy settings (default: disabled).",
    )
    args = parser.parse_args()

    method = args.method.upper()
    if args.health:
        method = "GET"

    headers = {
        "Accept": "*/*",
        "User-Agent": "GitHub-Hookshot/test",
    }

    body = None
    if method != "GET":
        headers["Content-Type"] = "application/json"
        if args.payload_file:
            with open(args.payload_file, "r", encoding="utf-8") as f:
                payload = json.load(f)
        else:
            payload = build_payload(args.action)
        headers["X-GitHub-Event"] = args.event
        body = json.dumps(payload).encode("utf-8")

    status, resp_headers, text = request(args.url, method, headers, body, args.use_proxy)
    print(f"status: {status}")
    if resp_headers:
        print("headers:")
        for key in sorted(resp_headers):
            print(f"{key}: {resp_headers[key]}")
    if text:
        print("body:")
        print(text)
    return 0 if status else 1


if __name__ == "__main__":
    sys.exit(main())
