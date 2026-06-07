import os
import sys

import requests


def main() -> int:
    token = os.environ.get("GITHUB_TOKEN")
    if not token:
        print("Missing GITHUB_TOKEN env var.")
        return 1

    owner = "HKLHaoBin"
    repo = "inter-knot"
    query = f"""
    {{
      repository(owner: "{owner}", name: "{repo}") {{
        pinnedDiscussions(first: 10) {{
          nodes {{
            discussion {{
              number
              title
              updatedAt
            }}
          }}
        }}
      }}
    }}
    """

    res = requests.post(
        "https://api.github.com/graphql",
        json={"query": query},
        headers={"Authorization": f"Bearer {token}"},
        timeout=20,
    )
    print("status:", res.status_code)
    print(res.json())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
