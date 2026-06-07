# 机密说明（参数获取与来源）

本文件用于记录本脚本所需参数的获取方式与含义。
参数通过同目录的 `.env` 读取，不要将真实密钥提交到公共仓库。

## GitHub 相关

### GITHUB_TOKEN
- 作用: 调用 GitHub GraphQL API 的访问令牌。
- 获取路径:
  1) GitHub -> Settings -> Developer settings -> Personal access tokens
  2) 选择 Fine-grained tokens 或 Tokens (classic)
- 需要权限(建议最小化):
  - 目标仓库的 Discussions: Read/Write (读取讨论 + 打标签)
  - Metadata: Read
- 备注:
  - 401 Bad credentials 通常表示 token 无效或权限不足。

### REPO
- 作用: 目标仓库，格式为 "owner/repo"。
- 获取: 直接填你的仓库全名，例如 "HKLHaoBin/inter-knot"。

### discussion_id / discussion_number
- 作用:
  - discussion_number: 讨论的数字编号（URL 中可见）。
  - discussion_id: GraphQL 的 node ID（用于打标签）。
- 获取 discussion_id:
  - 通过 GraphQL 查询讨论详情时会返回 id 字段。

## Discord 相关

### DISCORD_TOKEN
- 作用: Discord 机器人登录用 token。
- 获取路径:
  1) Discord Developer Portal -> Applications -> 选择应用 -> Bot
  2) Reset Token 并复制

### CHANNEL_ID
- 作用: 目标频道 ID，用于发送消息。
- 获取:
  - 在 Discord 启用开发者模式
  - 右键频道 -> Copy ID

### TARGET_USER_ID
- 作用: 只接受该用户的回复。
- 获取:
  - 开发者模式下右键用户 -> Copy ID

## 运行提示

1) 编辑 `.env`:
   GITHUB_TOKEN=...
   DISCORD_TOKEN=...
   CHANNEL_ID=...
   TARGET_USER_ID=...
   REPO=HKLHaoBin/inter-knot
2) 安装依赖:
   pip install discord.py nest_asyncio aiohttp requests
3) 启动脚本:
   py AI审核\\github-to-app-to-discord-token.py
