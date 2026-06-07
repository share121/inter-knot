#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json
import os
import re
import sys
from typing import Dict, List, Optional, Tuple

import requests
from PIL import Image
from pyzbar.pyzbar import decode as qr_decode
from io import BytesIO


MAX_TEXT_LEN = 5000
MAX_EVAL_PROMPT_CHARS = 14000
MAX_OCR_IMAGE_URLS = 5
MAX_OCR_TEXT_PER_IMAGE = 2000
MAX_OCR_TEXT_TOTAL = 6000
OCR_SPACE_PARSE_URL = "https://api.ocr.space/parse/image"
QIANFAN_APP_ID = "b7129285-4fc8-4745-b702-7f58c630ee3e"
GLM_MODEL = "glm-4-flash"

URL_REGEX = re.compile(r"https?://[^\s)>\]]+")
IMAGE_EXT_REGEX = re.compile(
    r"\.(png|jpg|jpeg|gif|webp|bmp|tif|tiff)(\?.*)?$",
    re.IGNORECASE,
)

JUDGE_LABELS = {
    "好": "高质",
    "普通": "普通",
    "无法判断": "可能是答便",
    "差": "风险",
}

LABEL_COLORS = {
    "高质": "0E8A16",
    "普通": "FBCA04",
    "可能是答便": "BFD4F2",
    "风险": "D93F0B",
}

SYSTEM_PROMPT = (
    "你是一个乐于解答各种问题的助手，你的任务是为用户提供专业、准确、有见地的建议。"
)

EVAL_PROMPT_PREFIX = """提示词:这个流程描述了你作为一名资深风纪委员和社区生态守护者，如何通过专业判断来维护社区秩序并促进和谐的交流。流程的目标是确保社区内的内容与评论符合标准，并给出合适的评判，以维持社区的健康环境。

## 流程功能描述

1. **内容审查与评判**：
    - 你需要对每篇帖子或评论进行详细审查，确保其符合社区的规则。
    - 审查后，你将根据内容的质量和对社区氛围的影响做出评判，使用预设的四种判断标准：“好” 或 “普通” 或 “差” 或 “无法判断”。
    - 这个流程帮助快速确定内容是否适合保留、推广，或需要进一步处理。

2. **处理不良信息**：
    - 你需要运用敏锐的洞察力和经验，识别和抵制可能损害社区氛围的不良信息。
    - 对于明显违反社区规定的内容，你将果断评定为“差”并采取必要措施。
    - 如果遇到较为模糊的情况或不确定的内容，可以使用“无法判断”作为判断标准，并提请进一步审核。

3. **推荐优质内容**：
    - 你不仅仅是审查者，还需要识别并推荐对社区有积极影响的优质内容。
    - 对于那些对讨论有帮助、友善且富有启发性的帖子或评论，你将评判为“好”以鼓励社区成员进行更多此类积极互动。

4. **维护中立与高效沟通**：
    - 在任何情况下，你的判断必须保持中立，不受到任何外部压力或个人偏见的影响。
    - 通过清晰的判断标准（好、普通、差、无法判断），你能够与用户进行高效的对话，让他们明白社区规范以及其行为是否合适。

## 任务执行总结

- 你负责审核帖子与评论，并给出判断：“好、普通、差、无法判断”。
- 遇到违反规则的内容，需果断处理并给出“差”的评判。
- 对于优质内容，使用“好”来鼓励和推广。
- 保持中立并使用既定判断标准与用户沟通，确保效率和规范性。

现在通过这些流程，为了社区营造一个积极、和谐的环境，判断下面的内容，并给出判断：“好、普通、差、无法判断”：
"""


def read_event() -> Dict:
    event_path = os.environ.get("GITHUB_EVENT_PATH")
    if not event_path or not os.path.exists(event_path):
        raise RuntimeError("GITHUB_EVENT_PATH is not set or file does not exist.")
    with open(event_path, "r", encoding="utf-8") as f:
        return json.load(f)


def parse_skip_category_names(env_value: str) -> List[str]:
    if not (env_value or "").strip():
        return []
    return [part.strip() for part in env_value.split(",") if part.strip()]


def get_discussion_category_name(discussion: Dict) -> Optional[str]:
    raw = discussion.get("category")
    if not isinstance(raw, dict):
        return None
    name = raw.get("name")
    if name is None:
        return None
    text = str(name).strip()
    return text or None


def extract_links(text: str) -> List[str]:
    if not text:
        return []
    return URL_REGEX.findall(text)


def is_image_url(url: str) -> bool:
    return bool(IMAGE_EXT_REGEX.search(url))


def decode_qr_urls(image_url: str) -> List[str]:
    try:
        resp = requests.get(image_url, timeout=10)
        resp.raise_for_status()
        img = Image.open(BytesIO(resp.content))
        decoded = qr_decode(img)
        urls: List[str] = []
        for item in decoded:
            data = item.data.decode("utf-8", errors="ignore").strip()
            if not data:
                continue
            found = extract_links(data)
            if found:
                urls.extend(found)
            else:
                urls.append(data)
        return urls
    except Exception:
        return []


def expand_links_with_qr(links: List[str]) -> List[str]:
    expanded: List[str] = []
    for url in links:
        if is_image_url(url):
            qr_urls = decode_qr_urls(url)
            if qr_urls:
                expanded.extend(qr_urls)
                continue
        expanded.append(url)
    deduped = []
    seen = set()
    for url in expanded:
        if url in seen:
            continue
        seen.add(url)
        deduped.append(url)
    return deduped


def limit_body(title: str, body: str) -> str:
    title = title or ""
    body = body or ""
    if len(title) + len(body) <= MAX_TEXT_LEN:
        return body
    links = extract_links(body)
    links_block = "\n".join(links)
    body_no_links = URL_REGEX.sub("", body).strip()
    reserved = len(title) + 1 + (len(links_block) + 1 if links_block else 0)
    allowed = max(0, MAX_TEXT_LEN - reserved)
    trimmed = body_no_links[:allowed]
    if links_block:
        if trimmed:
            return f"{trimmed}\n{links_block}"
        return links_block
    return trimmed


def post_qianfan(links_text: str, token: str) -> str:
    if not links_text:
        return ""
    url = "https://qianfan.baidubce.com/v2/app/conversation"
    payload = json.dumps(
        {
            "app_id": QIANFAN_APP_ID,
            "query": links_text,
        },
        ensure_ascii=False,
    )
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    response = requests.post(url, headers=headers, data=payload.encode("utf-8"), timeout=30)
    return response.text


def _ocr_url_log_prefix(url: str) -> str:
    u = url or ""
    if len(u) <= 72:
        return u
    return f"{u[:72]}…"


def post_ocr_url(image_url: str, api_key: str) -> str:
    if not image_url or not api_key:
        return ""
    prefix = _ocr_url_log_prefix(image_url)
    try:
        headers = {"apikey": api_key}
        data = {
            "url": image_url,
            "language": "auto",
            "detectOrientation": "true",
            "scale": "true",
            "OCREngine": "2",
            "isOverlayRequired": "false",
        }
        resp = requests.post(
            OCR_SPACE_PARSE_URL,
            headers=headers,
            data=data,
            timeout=25,
        )
        if not (200 <= resp.status_code < 300):
            print(f"Warning: OCR HTTP status {resp.status_code} for URL {prefix}")
            return ""
        try:
            payload = resp.json()
        except ValueError:
            print(f"Warning: OCR response JSON invalid for URL {prefix}")
            return ""
        code = payload.get("OCRExitCode")
        if code not in (1, 2):
            print(f"Warning: OCR OCRExitCode={code!r} for URL {prefix}")
            return ""
        results = payload.get("ParsedResults")
        if not isinstance(results, list):
            print(f"Warning: OCR ParsedResults not a list for URL {prefix}")
            return ""
        texts: List[str] = []
        for item in results:
            if not isinstance(item, dict):
                continue
            t = (item.get("ParsedText") or "").strip()
            if t:
                texts.append(t)
        return "\n".join(texts)
    except requests.RequestException as exc:
        print(f"Warning: OCR request failed ({type(exc).__name__}) for URL {prefix}")
        return ""
    except Exception:
        print(f"Warning: OCR unexpected error for URL {prefix}")
        return ""


def build_ocr_summary_from_image_urls(raw_links: List[str], ocr_key: str) -> str:
    key = (ocr_key or "").strip()
    if not raw_links:
        return ""
    seen: set[str] = set()
    image_urls: List[str] = []
    for u in raw_links:
        if not is_image_url(u) or u in seen:
            continue
        seen.add(u)
        image_urls.append(u)
        if len(image_urls) >= MAX_OCR_IMAGE_URLS:
            break
    if not key:
        if image_urls:
            print(f"Warning: OCR skipped (OCR_KEY not set), {len(image_urls)} image URL(s)")
        return ""
    blocks: List[str] = []
    for url in image_urls:
        text = post_ocr_url(url, key).strip()
        if not text:
            continue
        if len(text) > MAX_OCR_TEXT_PER_IMAGE:
            text = text[:MAX_OCR_TEXT_PER_IMAGE]
        blocks.append(f"图片: {url}\n{text}")
    if not blocks:
        return ""
    joined = "\n---\n".join(blocks)
    if len(joined) > MAX_OCR_TEXT_TOTAL:
        joined = joined[:MAX_OCR_TEXT_TOTAL].rstrip()
    return joined


def post_glm(prompt: str, api_key: str) -> str:
    url = "https://open.bigmodel.cn/api/paas/v4/chat/completions"
    payload = {
        "model": GLM_MODEL,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": prompt},
        ],
        "max_tokens": 4096,
        "temperature": 0.7,
    }
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    response = requests.post(url, headers=headers, json=payload, timeout=60)
    response.raise_for_status()
    data = response.json()
    return data["choices"][0]["message"]["content"]


def extract_judgement(text: str) -> Optional[str]:
    for key in ["好", "普通", "差", "无法判断"]:
        if key in text:
            return key
    return None


def build_eval_prompt(
    kind: str,
    title: str,
    body: str,
    reply_body: str,
    link_summary: str,
    ocr_summary: str = "",
) -> str:
    if kind == "discussion":
        content = f"[标题和正文]\n{title}\n{body}"
    elif kind == "comment":
        content = f"[标题]\n{title}\n[评论内容]\n{body}"
    else:
        content = f"[标题]\n{title}\n[评论内容]\n{reply_body}\n[回复内容]\n{body}"
    ocr_block = ""
    if (ocr_summary or "").strip():
        ocr_block = f"[图片OCR内容]\n{ocr_summary.strip()}\n"
    return (
        f"{EVAL_PROMPT_PREFIX}\n"
        f"{content}\n"
        f"[链接总结接口回复]\n{link_summary}\n"
        f"{ocr_block}"
        f"为了社区营造一个积极、和谐的环境，判断上面的内容，并给出判断：“好、普通、差、无法判断”"
    )


def build_eval_prompt_within_budget(
    kind: str,
    title: str,
    body: str,
    reply_body: str,
    link_summary: str,
    ocr_summary: str,
) -> str:
    # Budget order (after link_summary, then ocr_summary):
    # - discussion / comment: keep title + main body as long as possible (body is the item under review).
    # - reply: body is the reply under review; reply_body is parent context — trim parent first, then reply.
    ls = link_summary or ""
    ocr = (ocr_summary or "").strip()
    t = title
    b = body
    rb = reply_body
    while True:
        prompt = build_eval_prompt(kind, t, b, rb, ls, ocr)
        if len(prompt) <= MAX_EVAL_PROMPT_CHARS:
            return prompt
        over = len(prompt) - MAX_EVAL_PROMPT_CHARS
        chunk = max(over, 1)
        if ls:
            ls = ls[: max(0, len(ls) - chunk)].rstrip()
            continue
        if ocr:
            ocr = ocr[: max(0, len(ocr) - chunk)].rstrip()
            continue
        if kind == "reply":
            if rb:
                rb = rb[: max(0, len(rb) - chunk)].rstrip()
                continue
            if b:
                b = b[: max(0, len(b) - chunk)].rstrip()
                continue
        else:
            if b:
                b = b[: max(0, len(b) - chunk)].rstrip()
                continue
        if t:
            t = t[: max(0, len(t) - chunk)].rstrip()
            continue
        print(
            "Warning: eval prompt still exceeds MAX_EVAL_PROMPT_CHARS="
            f"{MAX_EVAL_PROMPT_CHARS} after truncation; hard-capping length"
        )
        return prompt[:MAX_EVAL_PROMPT_CHARS]


def build_optimize_prompt(kind: str, title: str, body: str, reply_body: str) -> str:
    if kind == "discussion":
        return (
            "请对下面的讨论进行优化表达，保持原意，语言更清晰友善。"
            "请严格按以下格式输出：\n"
            "标题: <标题>\n优化表达:\n<正文>\n"
            "不要输出其它内容。\n\n"
            f"标题: {title}\n正文:\n{body}"
        )
    if kind == "comment":
        return (
            "请对下面的评论进行优化表达，保持原意，语言更清晰友善。"
            "请严格按以下格式输出：\n"
            "标题: <标题>\n优化表达:\n<评论内容>\n"
            "不要输出其它内容。\n\n"
            f"标题: {title}\n评论内容:\n{body}"
        )
    return (
        "请对下面的回复内容进行优化表达，保持原意，语言更清晰友善。"
        "请严格按以下格式输出：\n"
        "标题: <标题>\n评论内容:\n<评论内容>\n优化表达:\n<回复内容>\n"
        "不要输出其它内容。\n\n"
        f"标题: {title}\n评论内容:\n{reply_body}\n回复内容:\n{body}"
    )


def parse_optimized_content(kind: str, text: str, fallback_title: str) -> Tuple[str, str]:
    title_match = re.search(r"标题:\s*(.*)", text)
    title = title_match.group(1).strip() if title_match else fallback_title
    if kind == "reply":
        match = re.search(r"优化表达:\s*\n([\s\S]+)$", text)
    else:
        match = re.search(r"优化表达:\s*\n([\s\S]+)$", text)
    body = match.group(1).strip() if match else text.strip()
    return title or fallback_title, body


def github_graphql(query: str, variables: Dict, token: str) -> Dict:
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    resp = requests.post(
        "https://api.github.com/graphql",
        headers=headers,
        json={"query": query, "variables": variables},
        timeout=30,
    )
    resp.raise_for_status()
    payload = resp.json()
    gql_errors = payload.get("errors")
    if gql_errors:
        raise RuntimeError(f"GitHub GraphQL errors: {json.dumps(gql_errors, ensure_ascii=False)}")
    return payload


def ensure_label(owner: str, repo: str, name: str, token: str) -> str:
    query = """
    query($owner:String!, $repo:String!, $name:String!) {
      repository(owner:$owner, name:$repo) {
        id
        label(name:$name) { id }
      }
    }
    """
    data = github_graphql(query, {"owner": owner, "repo": repo, "name": name}, token)
    repo_data = data["data"]["repository"]
    if repo_data["label"]:
        return repo_data["label"]["id"]
    mutation = """
    mutation($repoId:ID!, $name:String!, $color:String!) {
      createLabel(input:{repositoryId:$repoId, name:$name, color:$color}) {
        label { id }
      }
    }
    """
    color = LABEL_COLORS.get(name, "ededed")
    created = github_graphql(
        mutation,
        {"repoId": repo_data["id"], "name": name, "color": color},
        token,
    )
    return created["data"]["createLabel"]["label"]["id"]


def add_label_to_discussion(discussion_node_id: str, label_name: str, owner: str, repo: str, token: str) -> None:
    label_id = ensure_label(owner, repo, label_name, token)
    mutation = """
    mutation($labelableId:ID!, $labelIds:[ID!]!) {
      addLabelsToLabelable(input:{labelableId:$labelableId, labelIds:$labelIds}) {
        clientMutationId
      }
    }
    """
    github_graphql(mutation, {"labelableId": discussion_node_id, "labelIds": [label_id]}, token)


def fetch_discussion_via_graphql(owner: str, repo: str, discussion_number: int, token: str) -> Dict:
    query = """
    query($owner: String!, $repo: String!, $number: Int!) {
      repository(owner: $owner, name: $repo) {
        discussion(number: $number) {
          id
          title
          body
          category {
            name
          }
        }
      }
    }
    """
    data = github_graphql(
        query,
        {"owner": owner, "repo": repo, "number": discussion_number},
        token,
    )
    discussion = (data.get('data') or {}).get('repository', {}).get('discussion')
    if not isinstance(discussion, dict):
        raise RuntimeError(f'Discussion #{discussion_number} not found via GraphQL.')
    discussion['node_id'] = discussion.get('id', '')
    return discussion


def find_discussion_comment_by_database_id(
    owner: str,
    repo: str,
    discussion_number: int,
    database_id: int,
    token: str,
) -> Dict:
    """Locate a discussion comment by REST/database id via GraphQL pagination."""
    cursor = None
    target = int(database_id)
    for _ in range(100):
        query = """
        query($owner: String!, $repo: String!, $number: Int!, $after: String) {
          repository(owner: $owner, name: $repo) {
            discussion(number: $number) {
              comments(first: 100, after: $after) {
                pageInfo { hasNextPage endCursor }
                nodes {
                  id
                  databaseId
                  body
                }
              }
            }
          }
        }
        """
        data = github_graphql(
            query,
            {
                "owner": owner,
                "repo": repo,
                "number": discussion_number,
                "after": cursor,
            },
            token,
        )
        repo_d = (data.get("data") or {}).get("repository") or {}
        disc = repo_d.get("discussion")
        if not isinstance(disc, dict):
            raise RuntimeError(f"Discussion #{discussion_number} not found.")
        conn = disc.get("comments") or {}
        for node in conn.get("nodes") or []:
            raw_id = node.get("databaseId")
            if raw_id is None:
                continue
            if int(raw_id) == target:
                return {"node_id": node["id"], "body": node.get("body") or ""}
        page = conn.get("pageInfo") or {}
        if not page.get("hasNextPage"):
            break
        cursor = page.get("endCursor")
    raise RuntimeError(f"Discussion comment databaseId={database_id} not found.")


def fetch_discussion_comment(
    owner: str,
    repo: str,
    discussion_number: int,
    comment_id: int,
    token: str,
) -> Dict:
    row = find_discussion_comment_by_database_id(
        owner, repo, discussion_number, comment_id, token
    )
    return {"body": row["body"]}


def update_discussion_via_graphql(discussion_node_id: str, title: str, body: str, token: str) -> None:
    mutation = """
    mutation($discussionId: ID!, $title: String!, $body: String!) {
      updateDiscussion(input: {discussionId: $discussionId, title: $title, body: $body}) {
        discussion { id }
      }
    }
    """
    github_graphql(
        mutation,
        {"discussionId": discussion_node_id, "title": title, "body": body},
        token,
    )


def update_discussion_comment_via_graphql(comment_node_id: str, body: str, token: str) -> None:
    mutation = """
    mutation($commentId: ID!, $body: String!) {
      updateDiscussionComment(input: {commentId: $commentId, body: $body}) {
        comment { id }
      }
    }
    """
    github_graphql(mutation, {"commentId": comment_node_id, "body": body}, token)


def main() -> int:
    event = read_event()
    event_name = os.environ.get("GITHUB_EVENT_NAME", "")
    action = event.get("action", "")
    if action not in {"created", "edited"}:
        print(f"Skip action: {action}")
        return 0

    discussion = event.get("discussion") or {}
    discussion_number = discussion.get("number")
    skip_categories = parse_skip_category_names(os.environ.get("MODERATION_SKIP_CATEGORIES", ""))
    if skip_categories:
        category_payload = get_discussion_category_name(discussion)
        if category_payload is not None and category_payload in skip_categories:
            print(
                "Skip moderation: "
                f"github_event={event_name} discussion_number={discussion_number} "
                f"category={category_payload!r} matched={category_payload!r} source=payload_category"
            )
            return 0

        resolved_category = category_payload
        if resolved_category is None and discussion_number is not None:
            token_early = os.environ.get("GITHUB_TOKEN", "")
            repo_info_early = event.get("repository", {})
            owner_early = repo_info_early.get("owner", {}).get("login", "")
            repo_early = repo_info_early.get("name", "")
            if token_early and owner_early and repo_early:
                try:
                    discussion_gql = fetch_discussion_via_graphql(
                        owner_early,
                        repo_early,
                        discussion_number,
                        token_early,
                    )
                    resolved_category = get_discussion_category_name(discussion_gql)
                except Exception as exc:
                    print(f"Warning: fetch discussion for category fallback failed: {exc}")
                    resolved_category = None

        if resolved_category is not None and resolved_category in skip_categories:
            print(
                "Skip moderation: "
                f"github_event={event_name} discussion_number={discussion_number} "
                f"category={resolved_category!r} matched={resolved_category!r} source=fetched_category"
            )
            return 0

        if resolved_category is None:
            print(
                "Moderation: category 缺失未跳过 "
                f"github_event={event_name} discussion_number={discussion_number}"
            )

    token = os.environ.get("GITHUB_TOKEN", "")
    qianfan_token = os.environ.get("QIANFAN_TOKEN", "")
    glm_api_key = os.environ.get("GLM_API_KEY", "")
    ocr_key = os.environ.get("OCR_KEY", "").strip()
    if not token:
        raise RuntimeError("GITHUB_TOKEN is required.")
    if not glm_api_key:
        raise RuntimeError("GLM_API_KEY is required.")

    repo_info = event.get("repository", {})
    owner = repo_info.get("owner", {}).get("login", "")
    repo = repo_info.get("name", "")

    kind = ""
    title = ""
    body = ""
    reply_body = ""

    if event_name == "discussion":
        kind = "discussion"
        title = discussion.get("title", "")
        body = discussion.get("body", "")
        body = limit_body(title, body)
    elif event_name == "discussion_comment":
        kind = "comment"
        title = discussion.get("title", "")
        comment = event.get("comment") or {}
        body = comment.get("body", "")
        body = limit_body(title, body)
        reply_to = comment.get("in_reply_to_id")
        if reply_to:
            kind = "reply"
            parent = fetch_discussion_comment(owner, repo, discussion_number, reply_to, token)
            reply_body = parent.get("body", "")
            reply_body = limit_body(title, reply_body)
    else:
        print(f"Skip event: {event_name}")
        return 0

    combined_text = "\n".join(filter(None, [title, body, reply_body]))
    raw_links = extract_links(combined_text)
    expanded_links = expand_links_with_qr(raw_links)
    links_text = " || ".join(f"[{u}]" for u in expanded_links)
    link_summary = post_qianfan(links_text, qianfan_token) if qianfan_token else ""
    ocr_summary = build_ocr_summary_from_image_urls(raw_links, ocr_key)

    eval_prompt = build_eval_prompt_within_budget(
        kind, title, body, reply_body, link_summary, ocr_summary
    )
    eval_response = post_glm(eval_prompt, glm_api_key)
    judgement = extract_judgement(eval_response)
    print(f"Judgement: {judgement}")

    if kind == "discussion" and discussion_number is None:
        raise RuntimeError("Discussion number missing.")

    if judgement in {"差", "无法判断"}:
        optimize_prompt = build_optimize_prompt(kind, title, body, reply_body)
        optimize_response = post_glm(optimize_prompt, glm_api_key)
        new_title, new_body = parse_optimized_content(kind, optimize_response, title)

        if kind == "discussion":
            node_id = (discussion.get("node_id") or "").strip()
            if not node_id:
                discussion_gql = fetch_discussion_via_graphql(owner, repo, discussion_number, token)
                node_id = (discussion_gql.get('node_id') or '').strip()
            if not node_id:
                raise RuntimeError(f'Discussion #{discussion_number} node_id missing.')
            update_discussion_via_graphql(node_id, new_title, new_body, token)
            add_label_to_discussion(node_id, "普通", owner, repo, token)
        else:
            comment = event.get("comment") or {}
            comment_id = comment.get("id")
            if comment_id is None:
                raise RuntimeError("Comment id missing.")
            comment_node = (comment.get("node_id") or "").strip()
            if not comment_node:
                row = find_discussion_comment_by_database_id(
                    owner,
                    repo,
                    discussion_number,
                    int(comment_id),
                    token,
                )
                comment_node = (row.get("node_id") or "").strip()
            if not comment_node:
                raise RuntimeError(f"Comment #{comment_id} node_id missing.")
            update_discussion_comment_via_graphql(comment_node, new_body, token)
        return 0

    if kind == "discussion" and judgement in JUDGE_LABELS:
        label = JUDGE_LABELS[judgement]
        node_id = (discussion.get('node_id') or '').strip()
        if not node_id:
            discussion_gql = fetch_discussion_via_graphql(owner, repo, discussion_number, token)
            node_id = (discussion_gql.get('node_id') or '').strip()
        if not node_id:
            raise RuntimeError(f'Discussion #{discussion_number} node_id missing.')
        add_label_to_discussion(node_id, label, owner, repo, token)

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print(f"Error: {exc}")
        sys.exit(1)
