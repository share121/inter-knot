import json
import os
import urllib.error
import urllib.request

from fastapi import FastAPI, Request, Response

app = FastAPI()

HANDLED_DISCUSSION_ACTIONS = {"created", "edited", "answered"}
HANDLED_COMMENT_ACTIONS = {"created", "edited"}
IGNORED_COMMENT_ACTIONS = {"deleted"}
DISCORD_WEBHOOK_URL = os.environ.get("DISCORD_WEBHOOK_URL")


def is_admin_author(author: dict | None) -> bool:
    if not author:
        return False
    return author.get("author_association") == "OWNER"


def send_to_discord(webhook_url: str, message: str) -> bool:
    payload = {"content": message}
    request = urllib.request.Request(
        webhook_url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            return 200 <= response.status < 300
    except (urllib.error.HTTPError, urllib.error.URLError, ValueError):
        return False


def get_author_login(author: dict | None) -> str | None:
    if not author:
        return None
    return author.get("login")


def format_message(
    event: str,
    action: str,
    title: str | None,
    url: str | None,
    detail: str | None,
    author_login: str | None,
) -> str:
    parts = [f"[{event}:{action}]"]
    if title:
        parts.append(title)
    if url:
        parts.append(url)
    if detail:
        parts.append(detail)
    if author_login:
        parts.append(f"by {author_login}")
    return " | ".join(parts)


def log_event(
    event: str,
    action: str,
    title: str | None,
    url: str | None,
    detail: str | None = None,
    author_login: str | None = None,
) -> None:
    parts = [f"event={event}", f"action={action}"]
    if title:
        parts.append(f"title={title}")
    if url:
        parts.append(f"url={url}")
    if detail:
        parts.append(f"detail={detail}")
    if author_login:
        parts.append(f"author={author_login}")
    print(" ".join(parts))
    if DISCORD_WEBHOOK_URL:
        message = format_message(event, action, title, url, detail, author_login)
        send_to_discord(DISCORD_WEBHOOK_URL, message)


def handle_discussion_created(payload: dict) -> None:
    discussion = payload.get("discussion", {})
    author = discussion.get("author") or discussion.get("user")
    log_event(
        "discussion",
        "created",
        discussion.get("title"),
        discussion.get("html_url"),
        author_login=get_author_login(author),
    )


def handle_discussion_edited(payload: dict) -> None:
    discussion = payload.get("discussion", {})
    author = discussion.get("author") or discussion.get("user")
    log_event(
        "discussion",
        "edited",
        discussion.get("title"),
        discussion.get("html_url"),
        author_login=get_author_login(author),
    )


def handle_discussion_answered(payload: dict) -> None:
    discussion = payload.get("discussion", {})
    answer = payload.get("answer", {})
    author = answer.get("user") or answer.get("author")
    log_event(
        "discussion",
        "answered",
        discussion.get("title"),
        discussion.get("html_url"),
        detail=answer.get("html_url"),
        author_login=get_author_login(author),
    )


def handle_discussion_comment_created(payload: dict) -> None:
    discussion = payload.get("discussion", {})
    comment = payload.get("comment", {})
    author = comment.get("author") or comment.get("user")
    log_event(
        "discussion_comment",
        "created",
        discussion.get("title"),
        discussion.get("html_url"),
        detail=comment.get("html_url"),
        author_login=get_author_login(author),
    )


def handle_discussion_comment_edited(payload: dict) -> None:
    discussion = payload.get("discussion", {})
    comment = payload.get("comment", {})
    author = comment.get("author") or comment.get("user")
    log_event(
        "discussion_comment",
        "edited",
        discussion.get("title"),
        discussion.get("html_url"),
        detail=comment.get("html_url"),
        author_login=get_author_login(author),
    )


@app.post("/github-webhook")
async def github_webhook(request: Request) -> Response:
    return await handle_github_webhook(request)


@app.post("/github-webhook/")
async def github_webhook_slash(request: Request) -> Response:
    return await handle_github_webhook(request)


@app.post("/aicheck/github-webhook")
async def github_webhook_prefixed(request: Request) -> Response:
    return await handle_github_webhook(request)


@app.post("/aicheck/github-webhook/")
async def github_webhook_prefixed_slash(request: Request) -> Response:
    return await handle_github_webhook(request)


async def handle_github_webhook(request: Request) -> Response:
    payload = await request.json()
    event = request.headers.get("X-GitHub-Event")
    action = payload.get("action")

    if event == "discussion":
        if action not in HANDLED_DISCUSSION_ACTIONS:
            return Response(status_code=200)

        if action in {"created", "edited"}:
            discussion = payload.get("discussion", {})
            author = discussion.get("author") or discussion.get("user")
            if is_admin_author(author):
                return Response(status_code=200)

        if action == "answered":
            answer = payload.get("answer", {})
            answer_author = answer.get("user") or answer.get("author")
            if is_admin_author(answer_author):
                return Response(status_code=200)

        if action == "created":
            handle_discussion_created(payload)
        elif action == "edited":
            handle_discussion_edited(payload)
        elif action == "answered":
            handle_discussion_answered(payload)

        return Response(status_code=200)

    if event == "discussion_comment":
        if action in IGNORED_COMMENT_ACTIONS:
            discussion = payload.get("discussion", {})
            comment = payload.get("comment", {})
            author = comment.get("author") or comment.get("user")
            log_event(
                "discussion_comment",
                "deleted",
                discussion.get("title"),
                discussion.get("html_url"),
                author_login=get_author_login(author),
            )
            return Response(status_code=200)

        if action not in HANDLED_COMMENT_ACTIONS:
            return Response(status_code=200)

        comment = payload.get("comment", {})
        author = comment.get("author") or comment.get("user")
        if is_admin_author(author):
            return Response(status_code=200)

        if action == "created":
            handle_discussion_comment_created(payload)
        elif action == "edited":
            handle_discussion_comment_edited(payload)

    return Response(status_code=200)


@app.get("/github-webhook")
async def github_webhook_get() -> Response:
    return Response(content="github-webhook服务正常-9f5e2d", media_type="text/plain")


@app.get("/")
async def health_check() -> Response:
    return Response(content="aicheck服务正常-9f5e2d", media_type="text/plain")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=7608)
