我找到了 **GitHub Webhooks 官方对于 Discussions 相关事件的说明（包括事件类型和回调 payload 的字段结构概要）**。
📌 注意：GitHub 官方文档中 **并没有一个单独的、完整的 JSON Schema 例子供你直接复制粘贴**，但文档确实列出了各事件的 **字段名称和结构层级**，可以据此提取你关心的字段。([GitHub Docs][1])

---

## 📌 1. 支持的有关 Discussions 的 Webhook 事件

GitHub Webhooks 支持以下两个与 Discussions 相关的事件类型：

### ✅ discussion

发生在 **Discussion 本身的变化** 时，例如：

* discussion.created
* discussion.edited
* discussion.deleted
* discussion.answered
* discussion.labeled / unlabeled
* discussion.locked / unlocked
* discussion.pinned / unpinned
* discussion.reopened / transferred
* discussion.unanswered

这些都是这个事件的不同 `action` 值（事件子类型），可以通过请求头 `X-GitHub-Event: discussion` + Payload 里的 `action` 区分具体动作。([GitHub][2])

### ✅ discussion_comment

发生在 **评论操作** 时，例如：

* discussion_comment.created
* discussion_comment.edited
* discussion_comment.deleted

这些事件的 `X-GitHub-Event` 也是 `discussion_comment`，Payload 中的 `action` 区分不同类型。([GitHub][2])

---

## 📌 2. Webhook Payload 结构（核心字段）

以下是 **核心字段层级** — 大体结构大家可以据此实现 webhook 处理逻辑：

### 🧾 `discussion` 事件的 Payload

GitHub 文档指出以 `discussion` 为例，Webhooks 会包含：

```
{
  "action": "...",            # 事件动作，例如 created / edited / answered 等
  "discussion": {             # Discussion 对象
    "...": "..."              # （具体字段参见 API docs / GitHub Responses）
  },
  "repository": { ... },      # 仓库基本信息
  "sender": { ... },          # 触发事件的用户
  "installation": { ... }?,   # 完整权限的 App 事件才有
  "organization": { ... }?,   # 组织仓库才会有
  "enterprise": { ... }?      # 企业账户才会有
}
```

📌 其中核心的字段细节如：

* `discussion.id` — 讨论的唯一 ID
* `discussion.title` — 讨论标题
* `discussion.body` / `discussion.bodyHTML` / `discussion.bodyText` — 正文
* `discussion.html_url` — Web 页面链接
* `discussion.created_at`, `discussion.updated_at` — 时间
* `discussion.author` / author login/avatar 等
* `discussion.category.name`, 讨论分类
* `discussion.answers` 等聚合信息
  等（这些来自 GitHub Discussions API 对象结构）([GitHub Docs][1])

📌 Webhook 核心上级结构还包含 `repository`, `sender` 等通用字段 — 这些是所有 webhook 事件都会包含的。([GitHub Docs][1])

---

### 🧾 `discussion_comment` 事件的 Payload

```
{
  "action": "...",            # created / edited / deleted
  "comment": {                # 评论对象
    "...": "..."              # 评论内容、评论ID等
  },
  "discussion": {             # 评论对应的 Discussion 对象
    "...": "..."              # 如 id / title / url 等
  },
  "repository": { ... },
  "sender": { ... },
  "installation": { ... }?,
  "organization": { ... }?,
  "enterprise": { ... }?
}
```

📌 评论对象（`comment`）常见字段包括：

* `comment.id` — 评论的唯一 ID
* `comment.body` / `comment.bodyText` / `comment.bodyHTML` — 评论内容
* `comment.author` — 作者信息
* `comment.created_at`, `comment.updated_at` — 时间戳
* 关联 Discussion 信息嵌套在 `discussion` 键下（可用于定位讨论）([GitHub Docs][1])

---

## 🧠 3. Headers 与其他附带信息

当 webhook 被 GitHub 推送到你服务器时：

🔹 **HTTP Header 会包含：**

```
X-GitHub-Event: discussion
X-GitHub-Delivery: <UUID>
# X-Hub-Signature-256: <signature>    我没有设置 webhook secret
```

这些常用来：

* 识别事件类型（`X-GitHub-Event`）
* 校验签名确保推送真伪
* 跟踪 webhook 投递 ID 等

---

## 📌 提示：为什么你需要实际 dump Payload

官方并没有针对 Discussions 提供完整的、详尽的 JSON Schema 文档（目前仍缺少 schema 细节）。因此 **最可靠的方式是实际设置 webhook**, 然后：

```python
print(request.json)
```

— 这样你能看到自己仓库的 Samples 实际字段，这些字段包含哪些 Discussion 属性，尤其是各种 `action`（created / edited / answered）对应不同字段。([GitHub Docs][1])

---

## 🧩 总结要点

✅ GitHub Webhooks 支持的核心 Discussions 事件是：

* `discussion`
* `discussion_comment`

它们的响应 payload 都包含：

```
{
  action,
  discussion or comment,
  repository,
  sender,
  installation?, organization?, enterprise?
}
```

📌 这些字段足够你判断什么时候有新的讨论或评论，并提取标题、内容、链接等核心信息用于你的 Python 处理。([GitHub Docs][1])

---
