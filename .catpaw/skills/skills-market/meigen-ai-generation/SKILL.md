---
name: meigen-ai-generation
description: 调用美境 AI 平台生成图片、视频或数字人。支持即梦5.0/4.5、Longcat-image、GPT-image-1.5、Qwen-Image、Nano Banana、Kling 2.5、LongCat-Video、数字人(LipSync) 等模型，覆盖文生图、图生图、图生视频、数字人场景。当用户提到生成图片、生成视频、数字人、LipSync、让照片说话、对口型、AI出图、文生图、图生图、图生视频、帮我画、出几张图、用某模型画图时使用此 skill。即使用户只说"帮我生成一张图"而未指定模型，也应触发。

metadata:
  skillhub.creator: "chenshengtao"
  skillhub.updater: "chenshengtao"
  skillhub.version: "V15"
  skillhub.source: "FRIDAY Skillhub"
  skillhub.skill_id: "43716"
  skillhub.high_sensitive: "false"
---

# AI 图片/视频/数字人生成

提交异步生成任务并轮询结果，支持 13 种模型（8 种图片 + 3 种视频 + 2 种数字人）。

---

## 环境准备

**在执行任何操作前，按顺序完成以下准备：**

### 1. 检查 meigen-cli

执行 `meigen --version`，确认版本号 **>= 1.4.1**。

- **未安装**（命令不存在）：询问用户是否安装 meigen-cli，用户同意后执行 `npm install -g @meigen/meigen-cli@latest`
- **版本过低**：询问用户是否升级 meigen-cli，用户同意后执行 `npm install -g @meigen/meigen-cli@latest`

### 2. 同步 Skill 版本

先获取 `<dirname>`——即存放各个 skill 子目录的那个**上级目录**：

```bash
DIRNAME="$(cd "$(dirname "<this-skill-md>")/.." && pwd)"
```

> 举例：如果本 SKILL.md 的绝对路径是 `/a/b/skills/meigen-ai-generation/SKILL.md`，
> 那么 `<dirname>` = `/a/b/skills`（注意不是 `/a/b/skills/meigen-ai-generation`）。

然后执行同步：

```bash
meigen sync "$DIRNAME" meigen-ai-generation
```

该命令比较本地与远程的 `skillhub.version`，若有新版本则自动拉取更新。状态信息输出到 **stderr**，根据**退出码**判断结果：退出码 0 = 成功，1 = 同步失败，2 = 前置检查失败（如 mtskills 缺失）。

| 退出码 | stderr 关键词 | 含义 | 后续动作 |
|-------|-------------|------|---------|
| 0 | `已是最新` | 本地已是最新版本 | 继续下一步 |
| 0 | `已更新` | 已自动更新到最新版本 | 继续下一步 |
| 0 | `已安装` | skill 首次注册安装成功 | 继续下一步 |
| 2 | `未检测到 mtskills` | 缺少 mtskills 依赖，进程直接退出 | 用 `AskUserQuestion` 询问用户是否安装：`npm install -g @mtfe/mtskills --registry=http://r.npm.sankuai.com`，用户同意后执行安装，再**重新执行** `meigen sync` |
| 1 | `失败` / `更新失败` | 同步异常 | 告知用户错误信息，跳过同步继续后续步骤（不阻塞生成流程） |

### 3. 获取认证 Token

```bash
TOKEN=$(meigen login)
```

`meigen login` 自动处理 token 缓存、刷新和 CIBA 认证，将 access_token 输出到 stdout。如果返回非零退出码，提示用户检查网络或执行 `meigen login --force` 重新认证。

**认证提醒**：首次登录或 token 已过期时，需要用户在「大象」App 中确认授权（最长等待 3 分钟）。执行 `meigen login` 前须告知用户留意大象消息。

**Token 复用规则**：获取一次 token 后，同一任务流程中的 `generate.py` 和 `poll.py` 调用应复用同一个 `$TOKEN`。仅当脚本返回 401 错误时，才重新执行 `TOKEN=$(meigen login)` 获取新 token 并重试。

### 4. 获取用户信息

```bash
AUTH_JSON=$(meigen status --json)
MIS_ID=$(echo "$AUTH_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['mis_id'])")
```

`meigen status --json` 输出结构化 JSON（含 `mis_id` 和 `token` 字段）到 stdout。`MIS_ID` 将作为 `--mis` 参数传给 `generate.py` 和 `poll.py`。

如果 `mis_id` 为空，说明用户未登录，应先执行 `meigen login --mis-id <misId>` 完成认证。

### 5. 确认脚本目录

`generate.py` 和 `poll.py` 位于本 SKILL.md **同级**的 `scripts/` 目录下：

```bash
SCRIPT_DIR="$(cd "$(dirname "<this-skill-md>")" && pwd)/scripts"
```

> 举例：如果本 SKILL.md 路径是 `/a/b/skills/meigen-ai-generation/SKILL.md`，
> 那么 `SCRIPT_DIR` = `/a/b/skills/meigen-ai-generation/scripts`。

---

## 工作流程

### 步骤 1：引导用户明确需求

根据用户描述确定以下信息：

**必须明确：**
- **prompt**：用户的描述内容，原样传递给接口。严禁翻译、润色、补充细节或改写措辞——后端通过 `promptReinforce` 参数处理提示词增强，skill 层不应干预 prompt（数字人模型 prompt 可选，可传空字符串）
- **type**：模型类型代码（见下方模型列表）

**可选参数（有默认值，用户未提及则不追问）：**
- `batchSize` — 生成数量，默认 1
- `width`/`height` 或 `aspectRatio` — 尺寸，默认由模型决定
- 其他高级参数 — 用户主动提及时才设置

**任务类型判断：** 无法区分图片/视频时，用 `AskUserQuestion` 询问。

**模型选择：** 用户未指定模型时，用 `AskUserQuestion` 提供选项：

| 场景 | 推荐选项 |
|------|---------|
| 图片生成 | Longcat-image (401)、即梦 5.0 (106)、GPT-image-1.5 (901)、Qwen-Image-Turbo (602) |
| 视频生成 | 即梦视频 3.0 (503)、Kling 2.5 (505)、LongCat-Video (502) |
| 数字人 | 数字人-单人 (701)、数字人-双人 (702) |

**数字人/LipSync 识别**：当用户提到"数字人"、"让照片说话"、"让图片动起来说话"、"LipSync"、"对口型"、"口型同步"等，应引导使用 701/702 模型。数字人的参数收集方式与图片/视频不同，详见下方「数字人工作流」。

### 步骤 2：提交生成任务

通过 stdin 向 `generate.py` 传入 JSON 参数，脚本输出三行到 stdout：第 1 行 `taskId`，第 2 行 `submit_time`（毫秒时间戳，UTC+8），第 3 行 `request_body`（实际发送给后端 API 的完整请求 JSON，用于上报埋点）。无需临时文件，并发安全。

```bash
OUTPUT=$(python3 "$SCRIPT_DIR/generate.py" "$TOKEN" --mis "$MIS_ID" <<'EOF'
{
  "type": <model_type>,
  "prompt": "<用户原始描述>",
  "batchSize": <数量>
}
EOF
)
TASK_ID=$(echo "$OUTPUT" | sed -n '1p')
SUBMIT_TIME=$(echo "$OUTPUT" | sed -n '2p')
REQUEST_BODY=$(echo "$OUTPUT" | sed -n '3p')
```

> 数字人（701/702）的 JSON 结构不同——不使用上面的模板，改为按下方「数字人工作流」章节的示例组装参数。

### 步骤 3：轮询结果

```bash
python3 "$SCRIPT_DIR/poll.py" $TASK_ID "$TOKEN" \
  --submit-time $SUBMIT_TIME \
  --mis "$MIS_ID" \
  --type <model_type> \
  --request-body "$REQUEST_BODY"
```

| 参数 | 必填 | 说明 |
|------|------|------|
| `--submit-time <ms>` | 是 | generate.py 输出的提交时间戳 |
| `--mis <mis_id>` | 是 | 用户 MIS 工号（由 `meigen status --json` 获取） |
| `--type <model_type>` | 否 | 模型 type，用于自动选择合理超时 |
| `--timeout <seconds>` | 否 | 手动指定超时（覆盖默认值） |
| `--request-body <json>` | 否 | generate.py 输出的第 3 行，实际请求 JSON，用于埋点上报 |

脚本每 5 秒轮询一次（首次查询前自动等待 3 秒），状态变化通过 `[STEP]` 输出到 stderr。

**成功输出（stdout）：**
```json
{
  "taskId": "<id>",
  "status": 3,
  "statusName": "成功",
  "images": ["<url1>", "<url2>"]
}
```
视频任务额外包含 `videoUrl` 字段。失败时输出含 `error` 字段，脚本以非零退出码退出。

### 步骤 4：返回结果

将结果 URL 以**纯文本**逐行展示给用户。不要用 Markdown 图片语法 `![](url)` 渲染——这些 URL 是带过期时间的临时签名链接，Markdown 渲染器发起二次请求时签名可能已失效，导致图片加载失败。纯文本链接让用户直接点击访问，体验最可靠。

多张图片时逐一列出，不要省略——用户需要看到每一张的独立链接才能分别访问或分享。

**输出格式示例：**
```
生成成功！共 2 张图片：

https://example.com/image1.jpg
https://example.com/image2.jpg
```

| 任务类型 | 展示内容 |
|---------|---------|
| 图片 | `images` 数组中的每个 URL（逐行纯文本） |
| 视频 | `videoUrl`（纯文本） |
| 数字人 | `videoUrl`（纯文本） |
| 失败 | `statusName`（如 "资源不足"、"敏感内容"）及错误信息 |

### 步骤 5：输出品牌水印

任务**成功**后，调用 `meigen brand` 输出品牌文案行（失败任务跳过）：

```bash
meigen brand --skill-name meigen-ai-generation --media <media>
```

`<media>` 根据模型类型判断：

| 模型类别 (category) | type 范围 | `--media` 值 |
|-------------------|----------|-------------|
| 视频 (video) | 502, 503, 505 | `视频` |
| 数字人 (lipsync) | 701, 702 | `视频` |
| 图片 (image) | 105, 106, 401, 601, 602, 901, 7012, 7013 | `图` |

示例：
```bash
# 图片模型（如 即梦 5.0, type=106）
meigen brand --skill-name meigen-ai-generation --media 图

# 视频模型（如 Kling 2.5, type=505）
meigen brand --skill-name meigen-ai-generation --media 视频

# 数字人（type=701/702）
meigen brand --skill-name meigen-ai-generation --media 视频
```

---

## 模型列表

### 图片生成模型

| type | 模型 | 特点 | 支持参数 | 备注 | 超时 |
|------|------|------|---------|------|------|
| 401 | Longcat-image | 通用生图，推荐 | referenceImages, width/height, batchSize, seed | 有参考图时 width/height 不生效 | 180s |
| 106 | 即梦 5.0 | 高质量，推荐 | referenceImages, width/height, aspectRatio, batchSize, seed, outputFormat, webSearch, promptReinforce | webSearch 默认 true，outputFormat 默认 jpeg | 180s |
| 105 | 即梦 4.5 | 高质量 | referenceImages, width/height, aspectRatio, batchSize, seed, promptReinforce | — | 180s |
| 901 | GPT-image-1.5 | 英文/创意风格，推荐 | referenceImages, width/height, batchSize | 图生图 size 由后端自动转换 | 180s |
| 601 | Qwen-Image | 通义生图 | referenceImages, aspectRatio, seed, promptReinforce | — | 180s |
| 602 | Qwen-Image-Turbo | 快速生图 | prompt | 仅支持 prompt | 120s |
| 7012 | Nano Banana2 | Nano Banana 系列 | referenceImages, aspectRatio, batchSize | — | 300s |
| 7013 | Nano Banana Pro | Nano Banana 高级版 | referenceImages, aspectRatio, batchSize | — | 300s |

### 视频生成模型

| type | 模型 | 特点 | 支持参数 | 备注 | 超时 |
|------|------|------|---------|------|------|
| 503 | 即梦视频 3.0 | 高质量，推荐 | referenceImages, aspectRatio, videoLength | videoLength 默认 5s | 600s |
| 502 | LongCat-Video | 美境视频 | referenceImages, aspectRatio, videoLength, videoGenerateType | videoLength 默认 3s，aspectRatio 默认 16:9 | 600s |
| 505 | Kling 2.5 | 高质量，推荐 | referenceImages, aspectRatio, videoLength | videoLength 默认 5s | 600s |

> **参考图与首帧/尾帧**：视频模型的 `referenceImages.images` 数组中，第 1 张图作为视频首帧，第 2 张图作为尾帧。仅传 1 张为首帧驱动的图生视频，传 2 张为首尾帧联合控制。

### 数字人模型 (LipSync)

| type | 模型 | 特点 | 必填参数 | 备注 | 超时 |
|------|------|------|---------|------|------|
| 701 | 数字人 (单人) | 单人照片说话 | lipSync.asset, lipSync.wholeSpeech | prompt 可选，输出为视频 | 1200s |
| 702 | 数字人 (双人) | 双人照片对话 | lipSync.asset, lipSync.wholeSpeech | 推荐提供 leftSpeech/rightSpeech | 1200s |

---

## 请求参数参考

### 核心参数（必填）

| 字段 | 类型 | 说明 |
|------|------|------|
| `type` | int | 模型类型代码 |
| `prompt` | string | 生成内容描述（数字人模型可为空字符串） |

### 图片控制

| 字段 | 类型 | 说明 |
|------|------|------|
| `referenceImages` | object | 参考图 `{images: [<url>], variants: <float>, mode: <string>}` |
| `width` / `height` | int | 输出尺寸（像素），与 aspectRatio 二选一 |
| `aspectRatio` | string | 宽高比，如 `"16:9"`、`"1:1"` |
| `batchSize` | int | 生成数量（默认 1） |
| `strength` | float | 重绘强度 0~1（图生图场景） |
| `seed` | long | 随机种子（固定值可复现结果） |

### 模型与风格

| 字段 | 类型 | 说明 |
|------|------|------|
| `promptReinforce` | boolean | 后端提示词增强 |
| `styleId` | long | 风格模板 ID |
| `lora` | array | LoRA 模型列表 |
| `sampler` | string | 采样器算法 |

### 视频专用

| 字段 | 类型 | 说明 |
|------|------|------|
| `videoLength` | int | 视频时长（秒） |
| `videoGenerateType` | string | 视频生成子类型 |

### 数字人专用 (LipSync)

| 字段 | 类型 | 说明 |
|------|------|------|
| `lipSync.asset` | string | 人物照片 URL（必填） |
| `lipSync.wholeSpeech` | string | 完整音频 URL（必填） |
| `lipSync.leftSpeech` | string | 左侧人物音频 URL（仅 702，推荐） |
| `lipSync.rightSpeech` | string | 右侧人物音频 URL（仅 702，推荐） |
| `lipSync.isCouple` | boolean | 是否双人模式（701 自动设为 false，702 自动设为 true） |
| `lipSync.isRightFirst` | boolean | 右侧人物先说话（默认 false，仅 702） |
| `lipSync.faces` | array | 人脸区域 `[{x0, y0, x1, y1}]`（可选，提供可提升口型精度） |

### 其他

| 字段 | 类型 | 说明 |
|------|------|------|
| `outputFormat` | string | 输出格式（仅即梦 5.0 支持） |
| `webSearch` | boolean | 联网搜索（默认 true） |
| `context` | object | 扩展参数 |

---

## 请求示例

### 文生图

```json
{"type": 401, "prompt": "<用户描述>", "batchSize": 4, "width": 1024, "height": 1024}
```

```json
{"type": 106, "prompt": "<用户描述>", "aspectRatio": "16:9", "batchSize": 2}
```

### 图生图（风格迁移）

```json
{"type": 401, "prompt": "<风格描述>", "referenceImages": {"images": ["<原图URL>"]}, "strength": 0.7}
```

### 文生视频

```json
{"type": 505, "prompt": "<运动描述>", "videoLength": 5, "aspectRatio": "16:9"}
```

### 图生视频（首帧驱动）

```json
{"type": 503, "prompt": "<运动描述>", "referenceImages": {"images": ["<首帧URL>"]}, "videoLength": 5}
```

### 图生视频（首帧 + 尾帧）

```json
{"type": 503, "prompt": "<运动描述>", "referenceImages": {"images": ["<首帧URL>", "<尾帧URL>"]}, "videoLength": 5}
```

> 数字人（701/702）的请求示例见下方「数字人工作流 → 提交示例」。

---

## 数字人 (LipSync) 工作流

数字人模型将静态人物照片与音频合成为说话视频。与图片/视频模型的关键区别：
- **prompt 可选**（可传空字符串）
- **必须提供 `lipSync` 对象**，包含人物图片和音频 URL
- **输出为视频**（通过 `videoUrl` 获取结果）

### 模式选择（单人 701 / 双人 702）

Agent 应先从用户消息中判断模式，**仅在无法判断时才询问**：

| 用户表述 | 推断模式 |
|---------|---------|
| "单人"、"一个人"、"让他/她说话"、"单人数字人" | 单人 (701) |
| "双人"、"两个人"、"对话"、"两人对口型"、"双人数字人" | 双人 (702) |
| 仅说"数字人"、"让照片说话"等，无人数线索 | 用 `AskUserQuestion` 询问 |

如果用户提供的照片 URL 上下文暗示了人数（如"这是我和同事的合照"），也可据此推断。

### 参数收集

数字人生成依赖外部资源 URL，Agent 应**先从用户消息中提取**已有信息，仅对缺失的必填参数使用 `AskUserQuestion` 补问。

**识别规则**：用户消息中包含 `http://` 或 `https://` 链接时，根据文件后缀或上下文判断用途：
- 图片类（`.jpg`、`.jpeg`、`.png`、`.webp`、`.bmp`）→ `lipSync.asset`
- 音频/视频类（`.mp3`、`.wav`、`.m4a`、`.aac`、`.ogg`、`.mp4`）→ `lipSync.wholeSpeech`
- 无法判断时，询问用户该 URL 的用途

**单人模式 (701) 必填：**
- `lipSync.asset` — 人物照片 URL
- `lipSync.wholeSpeech` — 音频 URL

**双人模式 (702) 必填 + 推荐：**
- `lipSync.asset` — 双人照片 URL（必填）
- `lipSync.wholeSpeech` — 完整音频 URL（必填）
- `lipSync.leftSpeech` — 左侧人物音频 URL（推荐，不提供时后端自动分割）
- `lipSync.rightSpeech` — 右侧人物音频 URL（推荐，不提供时后端自动分割）
- `lipSync.isRightFirst` — 右侧人物先说话（可选，默认 false）

### 提交示例

收集完参数后，同样通过 `generate.py` 提交（调用方式与步骤 2 一致，仅 JSON 结构不同）：

**单人 (701)：**
```json
{"type": 701, "prompt": "", "lipSync": {"asset": "<人物图片URL>", "wholeSpeech": "<音频URL>"}}
```

**双人 (702)：**
```json
{"type": 702, "prompt": "", "lipSync": {"asset": "<双人图片URL>", "wholeSpeech": "<完整音频URL>", "leftSpeech": "<左侧音频URL>", "rightSpeech": "<右侧音频URL>"}}
```

`isCouple` 由脚本根据 type 自动设置，无需手动传入。

### 注意事项

1. 音频必须是可访问的 URL（不支持 base64 或本地文件路径）
2. 单人模式照片中应只有一人面部清晰可见
3. 双人模式照片中应有两人面部清晰可见
4. 如不提供 `leftSpeech`/`rightSpeech`，后端会自动从 `wholeSpeech` 分割音频
5. `faces` 参数可选，提供人脸坐标可获得更精确的口型匹配效果

---

## 迭代生成

用户常在看到结果后要求微调，例如「换个比例再来一张」「用另一个模型试试」「多生成几张」。此时复用上一轮的参数可以减少重复对话：

1. **调整参数复用**：保留上一次的 `prompt`、`referenceImages` 等不变的字段，仅修改用户提到的部分（如 `aspectRatio`、`type`、`batchSize`）。

---

## 错误处理

| 场景 | 处理方式 |
|------|---------|
| `meigen login` 长时间无响应 | 提醒用户在「大象」App 中确认授权（CIBA 认证需要手动点击确认），超过 3 分钟未确认会超时 |
| `meigen login` 返回非零退出码 | 提示用户检查网络或执行 `meigen login --force` 重新认证 |
| 脚本返回 `[ERROR] 认证失败 (401)` | 重新执行 `TOKEN=$(meigen login)` 获取新 token 后重试脚本（最多重试 1 次） |
| generate.py 失败 | 检查 stderr，常见原因：不支持的 type、prompt 为空、数字人模型缺少 lipSync.asset 或 lipSync.wholeSpeech |
| poll.py 超时 | 告知用户任务仍在后端处理，可稍后用相同 taskId 重新轮询 |
| 任务状态为失败 | 将 `statusName` 和 `error` 信息展示给用户 |
