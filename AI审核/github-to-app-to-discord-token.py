# Dependencies (install separately):
# pip install discord.py nest_asyncio aiohttp requests
import discord
import asyncio
from discord.ext import commands
import nest_asyncio
import logging
import os
import json

import requests
import aiohttp

# 使用 logging.info()、logging.error() 等替代 print()
logging.basicConfig(level=logging.INFO)
# 应用 nest_asyncio
nest_asyncio.apply()

def load_env_file(path: str) -> None:
    if not os.path.exists(path):
        return
    try:
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, value = line.split("=", 1)
                key = key.strip()
                value = value.strip()
                if key and key not in os.environ:
                    os.environ[key] = value
    except OSError as e:
        logging.error(f"Failed to load .env file: {e}")


env_path = os.path.join(os.path.dirname(__file__), ".env")
load_env_file(env_path)

# GitHub API 配置
github_api = "https://api.github.com/graphql"
repo = os.getenv("REPO", "HKLHaoBin/inter-knot")
# NOTE: keep tokens as examples; real usage should use env vars.
github_token = os.getenv(
    "GITHUB_TOKEN",
    '',
)
owner = repo.split("/")[0]
repo_name = repo.split("/")[1]
last_discussion_file = os.path.join(os.path.dirname(__file__), "last_discussion.txt")
page_size = 10
poll_interval_seconds = 30

# Discord 配置
discord_token = os.getenv(
    "DISCORD_TOKEN",
    '',
)
channel_id = int(os.getenv("CHANNEL_ID", ""))
target_user_ids_raw = os.getenv("TARGET_USER_ID", "")
target_user_ids = {
    int(v.strip()) for v in target_user_ids_raw.split(",") if v.strip()
}
variable = 5381

intents = discord.Intents.default()
intents.message_content = True
client = commands.Bot(command_prefix="!", intents=intents)

# 验证 Discord 环境变量
if not all([discord_token, channel_id, target_user_ids]):
    raise ValueError("Some required Discord environment variables are missing.")

channel_id = int(channel_id)


async def main():
    try:
        await client.start(discord_token)
    except discord.errors.LoginFailure as e:
        logging.error(f"Login failed: {e}")
    except discord.errors.HTTPException as e:
        logging.error(f"HTTP Exception occurred: {e}")
    except Exception as e:
        logging.error(f"Unexpected error: {e}")


@client.event
async def on_ready():
    logging.info(f"Logged in as {client.user}")
    logging.info(f"Listening on channel_id={channel_id}, target_user_ids={sorted(target_user_ids)}")
    try:
        await fetch_and_process_discussions()
    except Exception:
        logging.exception("Unhandled error in fetch_and_process_discussions")


def load_state():
    if not os.path.exists(last_discussion_file):
        return {"last_number": 0, "cursor": None}
    try:
        with open(last_discussion_file, "r", encoding="utf-8") as f:
            data = json.load(f)
            return {
                "last_number": int(data.get("last_number", 0)),
                "cursor": data.get("cursor"),
            }
    except (OSError, ValueError, json.JSONDecodeError, TypeError):
        return {"last_number": 0, "cursor": None}


def save_state(number: int, cursor: str | None) -> None:
    try:
        with open(last_discussion_file, "w", encoding="utf-8") as f:
            json.dump({"last_number": number, "cursor": cursor}, f, ensure_ascii=True)
        logging.info(f"Saved state: number={number}, cursor={cursor}")
    except OSError as e:
        logging.error(f"Failed to save last discussion number: {e}")


async def get_discussions_page(after_cursor: str | None):
    after_clause = f', after: "{after_cursor}"' if after_cursor else ""
    query = f"""
    {{
        repository(owner: "{owner}", name: "{repo_name}") {{
            discussions(first: {page_size}, orderBy: {{field: CREATED_AT, direction: ASC}}{after_clause}) {{
                edges {{
                    cursor
                    node {{
                        id
                        number
                        title
                        body
                    }}
                }}
            }}
        }}
    }}
    """
    response = await graphql(query)
    if not response:
        return None
    return (
        response.get("data", {})
        .get("repository", {})
        .get("discussions", {})
        .get("edges", [])
    )


async def find_next_discussion():
    state = load_state()
    logging.info(f"Loaded state: number={state['last_number']}, cursor={state['cursor']}")
    edges = await get_discussions_page(state["cursor"])
    if not edges:
        return None
    edge = edges[0]
    node = edge.get("node", {})
    return {
        "number": node.get("number"),
        "id": node.get("id"),
        "title": node.get("title"),
        "body": node.get("body"),
        "cursor": edge.get("cursor"),
    }


def trim_message(text: str, max_len: int = 1900) -> str:
    if len(text) <= max_len:
        return text
    return text[: max(0, max_len - 3)] + "..."


def build_discussion_message(discussion: dict, max_len: int = 1900) -> str:
    header = (
        f"讨论 ID：{discussion['number']}\n"
        f"标题：{discussion['title']}\n"
        f"[论坛内容]："
    )
    footer = "\n[评论内容：好 or 普通 or 差 or 无法判断]"
    body = discussion.get("body") or ""
    available = max_len - len(header) - len(footer)
    if available < 0:
        available = 0
    if len(body) > available:
        body = body[: max(0, available - 3)] + "..."
    return f"{header}{body}{footer}"


def build_prompt_message(text: str, max_len: int = 1900) -> str:
    return trim_message(text, max_len=max_len)


async def fetch_and_process_discussions():
    channel = client.get_channel(channel_id)
    if not channel:
        logging.error(f"Channel with ID {channel_id} not found.")
        return



    def check(m):
        if m.author.id not in target_user_ids:
            return False
        if m.channel.id == channel_id:
            return True
        parent_id = getattr(m.channel, "parent_id", None)
        return parent_id == channel_id

    while True:
        discussion = await find_next_discussion()
        if not discussion:
            logging.info("No new discussions, polling...")
            await asyncio.sleep(poll_interval_seconds)
            continue

        msg = build_discussion_message(discussion)

        while True:
            await channel.send(msg)
            logging.info("Sent message to channel")

            logging.info("Waiting for reply...")
            try:
                reply = await client.wait_for("message", timeout=60.0, check=check)
            except asyncio.TimeoutError:
                await channel.send(f"没有收到回复，重新发送讨论 ID {discussion['number']} 。")
                continue

            logging.info(f"Received reply content: {reply.content!r}")
            await channel.send(f"收到回复: {reply.content}")

            fairy_type = "其他"
            if "无法判断" in reply.content:
                fairy_type = "低质"
            elif "普通" in reply.content:
                fairy_type = "普通"
            elif "好" in reply.content:
                fairy_type = "高质"
            elif "差" in reply.content:
                fairy_type = "风险"
            elif "等待" in reply.content:
                await asyncio.sleep(15)
                continue

            if fairy_type in {"低质", "风险"}:
                prompt = (
                    "请提供优化后的讨论内容表达（直接回复优化后的正文）：\n"
                    f"  标题：{discussion['title']}\n"
                    f"  正文：{discussion.get('body') or ''}"
                )
                await channel.send(build_prompt_message(prompt))
                while True:
                    try:
                        improved = await client.wait_for("message", timeout=120.0, check=check)
                    except asyncio.TimeoutError:
                        await channel.send("没有收到优化内容，请继续回复优化后的正文。")
                        continue
                    new_body = improved.content.strip()
                    if not new_body:
                        await channel.send("内容为空，请重新提供优化后的正文。")
                        continue
                    updated = await update_discussion_body(discussion["id"], new_body)
                    if updated:
                        await channel.send("已更新讨论内容，请重新评价该讨论。")
                        discussion["body"] = new_body
                    else:
                        await channel.send("更新讨论内容失败，请稍后重试。")
                    break
                if updated:
                    msg = build_discussion_message(discussion)
                    continue

            await add_label(fairy_type, discussion["id"])
            save_state(discussion["number"], discussion["cursor"])
            break


async def add_label(label_name: str, labelable_id: str):
    label_id = await get_label_id(label_name)
    if label_id:
        logging.info(f"Adding label {label_name} to discussion {labelable_id}")
        query = f"""
        mutation {{
            addLabelsToLabelable(
                input: {{labelableId: "{labelable_id}", labelIds: ["{label_id}"]}}
            ) {{
                clientMutationId
            }}
        }}
        """
        await graphql(query)
    else:
        logging.error(f"Label ID for {label_name} not found.")


async def get_label_id(label_name: str) -> str:
    logging.info(f"Getting label ID for {label_name}")
    query = f"""
    {{
        repository(owner: "{owner}", name: "{repo_name}") {{
            label(name: "{label_name}") {{
                id
            }}
        }}
    }}
    """
    response = await graphql(query)
    if response:
        repository = response.get("data", {}).get("repository", {})
        label = repository.get("label")
        if not label:
            return None
        return label.get("id")
    return None


async def graphql(query: str, variables: dict | None = None):
    headers = {"Authorization": f"Bearer {github_token}"}
    async with aiohttp.ClientSession() as session:
        payload = {"query": query}
        if variables:
            payload["variables"] = variables
        async with session.post(github_api, json=payload, headers=headers) as response:
            if response.status == 200:
                return await response.json()
            else:
                logging.error(f"GraphQL request failed with status {response.status}: {await response.text()}")
                return None


async def update_discussion_body(discussion_id: str, new_body: str) -> bool:
    query = """
    mutation($discussionId: ID!, $body: String!) {
        updateDiscussion(input: {discussionId: $discussionId, body: $body}) {
            discussion {
                id
            }
        }
    }
    """
    response = await graphql(query, {"discussionId": discussion_id, "body": new_body})
    if not response:
        return False
    errors = response.get("errors")
    if errors:
        logging.error(f"updateDiscussion errors: {errors}")
        return False
    return True


@client.event
async def on_error(event, *args, **kwargs):
    logging.error(f"Error occurred in {event}: {args} - {kwargs}")
    await asyncio.sleep(5)
    try:
        await client.close()
        await client.start(discord_token)
    except Exception as e:
        logging.error(f"Reconnection failed: {e}")


@client.event
async def on_message(message):
    if message.author.bot:
        return
    same_channel = message.channel.id == channel_id
    parent_id = getattr(message.channel, "parent_id", None)
    in_thread = parent_id == channel_id
    if same_channel or in_thread:
        logging.info(
            "Incoming message: author=%s channel=%s parent=%s content=%r",
            message.author.id,
            message.channel.id,
            parent_id,
            message.content,
        )
    await client.process_commands(message)


if __name__ == "__main__":
    asyncio.run(main())
