#!/usr/bin/env python3
"""
AI 生成脚本 — 提交异步生成任务，返回 taskId 和提交时间戳。

用法: python3 generate.py <access_token> --mis <mis_id> [json_file]

参数:
  access_token  meigen login 输出的 access_token 字符串
  --mis         用户 MIS 工号（必填，写入请求头用于身份识别）
  json_file     包含请求参数的 JSON 文件（可选，省略时从 stdin 读取）

成功时输出三行到 stdout：第一行 taskId，第二行 submit_time（毫秒，UTC+8），第三行 request_body（实际发送的请求 JSON）。
进度日志以 [STEP] 前缀输出到 stderr。
"""

from __future__ import annotations

import sys
import json
import os
from datetime import datetime, timezone, timedelta

from common import api_post
from resolution import adapt_resolution, SEEDREAM_RATIOS, DEFAULT_RATIOS, GPT_RATIOS

UTC8 = timezone(timedelta(hours=8))


# 一期支持的模型 type
SUPPORTED_TYPES = {
    # 图片生成
    105,   # 即梦 4.5
    106,   # 即梦 5.0
    401,   # Longcat-image (美境 Meigen)
    601,   # Qwen-Image
    602,   # Qwen-Image-Turbo
    901,   # GPT-image-1.5
    7012,  # Nano Banana2
    7013,  # Nano Banana Pro
    # 视频生成
    503,   # 即梦视频 3.0
    502,   # LongCat-Video
    505,   # Kling 2.5
    # 数字人 (LipSync)
    701,   # 数字人 (单人)
    702,   # 数字人 (双人)
}

DIRECT_FIELDS = [
    "type", "image", "styleId", "referenceImages", "lora",
    "prompt", "promptReinforce", "sampler", "strength", "seed",
    "width", "height", "batchSize", "context", "modelPath",
    "modelVersion", "aspectRatio", "videoLength",
    "lipSync", "videoGenerateType", "outputFormat", "webSearch",
]

# 各模型参数规格：category(image/video)、supports(有效参数)、defaults(默认值)、note(提示)
MODEL_SPECS = {
    # ---- 图片模型 ----
    106: {
        "category": "image",
        "supports": ["referenceImages", "width", "height", "batchSize",
                     "seed", "outputFormat", "webSearch", "promptReinforce"],
        "defaults": {"webSearch": True, "outputFormat": "jpeg"},
        "name": "即梦 5.0",
        "resolution_mode": "width_height_only",
        "ratios": SEEDREAM_RATIOS,
    },
    105: {
        "category": "image",
        "supports": ["referenceImages", "width", "height", "batchSize",
                     "seed", "promptReinforce"],
        "defaults": {},
        "name": "即梦 4.5",
        "resolution_mode": "width_height_only",
        "ratios": SEEDREAM_RATIOS,
    },
    401: {
        "category": "image",
        "supports": ["referenceImages", "width", "height", "batchSize", "seed"],
        "defaults": {},
        "name": "Longcat-image",
        "note": "有参考图时 width/height 不生效",
        "resolution_mode": "width_height_only",
        "ratios": DEFAULT_RATIOS,
    },
    601: {
        "category": "image",
        "supports": ["referenceImages", "aspectRatio", "seed", "promptReinforce"],
        "defaults": {},
        "name": "Qwen-Image",
        "resolution_mode": "aspect_ratio_only",
    },
    602: {
        "category": "image",
        "supports": ["prompt"],
        "defaults": {},
        "name": "Qwen-Image-Turbo",
        "resolution_mode": "none",
    },
    901: {
        "category": "image",
        "supports": ["referenceImages", "width", "height", "batchSize"],
        "defaults": {},
        "name": "GPT-image-1.5",
        "note": "图生图模式 size 由后端自动转换",
        "resolution_mode": "width_height_only",
        "ratios": GPT_RATIOS,
    },
    7012: {
        "category": "image",
        "supports": ["referenceImages", "aspectRatio", "batchSize"],
        "defaults": {},
        "name": "Nano Banana2",
        "resolution_mode": "aspect_ratio_only",
        "needs_context_ratio": True,
    },
    7013: {
        "category": "image",
        "supports": ["referenceImages", "aspectRatio", "batchSize"],
        "defaults": {},
        "name": "Nano Banana Pro",
        "resolution_mode": "aspect_ratio_only",
        "needs_context_ratio": True,
    },
    # ---- 视频模型 ----
    503: {
        "category": "video",
        "supports": ["referenceImages", "aspectRatio", "videoLength"],
        "defaults": {"videoLength": 5},
        "name": "即梦视频 3.0",
        "note": "1张参考图=首帧，2张参考图=首帧+尾帧",
        "resolution_mode": "aspect_ratio_only",
    },
    502: {
        "category": "video",
        "supports": ["referenceImages", "aspectRatio", "videoLength", "videoGenerateType"],
        "defaults": {"videoLength": 3, "aspectRatio": "16:9"},
        "name": "LongCat-Video",
        "resolution_mode": "aspect_ratio_only",
    },
    505: {
        "category": "video",
        "supports": ["referenceImages", "aspectRatio", "videoLength"],
        "defaults": {"videoLength": 5},
        "name": "Kling 2.5",
        "note": "1张参考图=首帧，2张参考图=首帧+尾帧(pro模式)",
        "resolution_mode": "aspect_ratio_only",
    },
    # ---- 数字人 (LipSync) ----
    701: {
        "category": "lipsync",
        "supports": ["lipSync"],
        "defaults": {},
        "name": "数字人 (单人)",
        "note": "需要 lipSync.asset（人物图片URL）和 lipSync.wholeSpeech（音频URL）",
        "resolution_mode": "none",
    },
    702: {
        "category": "lipsync",
        "supports": ["lipSync"],
        "defaults": {},
        "name": "数字人 (双人)",
        "note": "需要 lipSync.asset（双人图片URL）和 lipSync.wholeSpeech（完整音频URL），推荐提供 leftSpeech/rightSpeech",
        "resolution_mode": "none",
    },
}

# 图片模型不应使用的视频参数
VIDEO_ONLY_PARAMS = {"videoLength", "videoGenerateType", "lipSync"}
# 视频模型一般不适用的图片参数（非严格，部分模型支持）
IMAGE_ONLY_PARAMS = {"strength", "sampler",
                     "styleId", "lora", "modelPath", "modelVersion"}
# 数字人 (LipSync) 类型
LIPSYNC_TYPES = {701, 702}
# 数字人模型不适用的参数
LIPSYNC_IRRELEVANT_PARAMS = {
    "strength", "sampler", "styleId", "lora", "modelPath", "modelVersion",
    "videoLength", "videoGenerateType", "referenceImages", "aspectRatio",
    "width", "height", "batchSize",
}


def validate_params(params: dict) -> list[str]:
    """校验参数与模型的适配性，返回 warning 列表（不阻断，参数仍保留透传）。"""
    warnings: list[str] = []
    task_type = params.get("type")
    spec = MODEL_SPECS.get(task_type)
    if spec is None:
        return warnings

    category = spec["category"]
    model_name = spec.get("name", f"type={task_type}")

    # 1. 分类校验：图片模型传了视频参数
    if category == "image":
        for p in VIDEO_ONLY_PARAMS:
            if params.get(p) is not None:
                warnings.append(f"[{model_name}] 图片模型不支持 {p}，参数将被忽略")

    # 2. 分类校验：视频模型传了图片专属参数（warning但不严格拦截，因为部分模型可能用到）
    if category == "video":
        for p in IMAGE_ONLY_PARAMS:
            if params.get(p) is not None:
                warnings.append(f"[{model_name}] 视频模型通常不使用 {p}，参数可能被忽略")

    # 3. 互斥校验已由 resolution adapter 处理，此处不再 warning

    # 4. 视频模型首帧/尾帧提示
    if category == "video":
        ref_imgs = params.get("referenceImages")
        if isinstance(ref_imgs, dict) and "images" in ref_imgs:
            img_count = len(ref_imgs["images"])
            if img_count >= 2:
                warnings.append(
                    f"[{model_name}] 传入 {img_count} 张参考图：第1张=首帧，第2张=尾帧")
            elif img_count == 1:
                warnings.append(f"[{model_name}] 传入 1 张参考图作为首帧")

    # 5. 数字人模型：不适用的参数 warning
    if category == "lipsync":
        for p in LIPSYNC_IRRELEVANT_PARAMS:
            if params.get(p) is not None:
                warnings.append(f"[{model_name}] 数字人模型不使用 {p}，参数将被忽略")

    # 6. 数字人模型：必填字段 warning + 自动填充 isCouple
    if task_type in LIPSYNC_TYPES:
        lip_sync = params.get("lipSync")
        if not isinstance(lip_sync, dict):
            warnings.append(f"[{model_name}] lipSync 对象为必填参数")
        else:
            if not lip_sync.get("asset"):
                warnings.append(f"[{model_name}] lipSync.asset（人物图片URL）为必填参数")
            if not lip_sync.get("wholeSpeech"):
                warnings.append(
                    f"[{model_name}] lipSync.wholeSpeech（音频URL）为必填参数")
            if task_type == 702:
                lip_sync.setdefault("isCouple", True)
                if not lip_sync.get("leftSpeech") and not lip_sync.get("rightSpeech"):
                    warnings.append(
                        f"[{model_name}] 建议提供 leftSpeech/rightSpeech，否则后端将自动分割音频")
            else:
                lip_sync.setdefault("isCouple", False)

    return warnings


def generate(params: dict, access_token: str, mis_id: str) -> tuple[int, int]:
    """提交生成任务，返回 (taskId, submit_time_ms)。"""
    task_type = params.get("type")
    if task_type not in SUPPORTED_TYPES:
        print(
            f"ERROR: 不支持的模型 type={task_type}，一期支持: {sorted(SUPPORTED_TYPES)}", file=sys.stderr)
        sys.exit(1)

    if not params.get("prompt"):
        if task_type not in LIPSYNC_TYPES:
            print("ERROR: prompt 为必填参数", file=sys.stderr)
            sys.exit(1)
        else:
            params.setdefault("prompt", "")

    # LipSync 必填参数硬校验
    if task_type in LIPSYNC_TYPES:
        lip_sync = params.get("lipSync")
        if not isinstance(lip_sync, dict) or not lip_sync.get("asset") or not lip_sync.get("wholeSpeech"):
            print("ERROR: 数字人模型必须提供 lipSync.asset（人物图片URL）和 lipSync.wholeSpeech（音频URL）",
                  file=sys.stderr)
            sys.exit(1)

    # 分辨率参数适配
    spec = MODEL_SPECS.get(task_type, {})
    params = adapt_resolution(params, spec)

    # 填充模型默认值（用户未传时）
    for key, default_val in spec.get("defaults", {}).items():
        if key not in params or params[key] is None:
            params[key] = default_val
            print(f"[STEP] 使用默认值: {key}={default_val}",
                  file=sys.stderr, flush=True)

    # 参数校验（warning 不阻断）
    warnings = validate_params(params)
    for w in warnings:
        print(f"[WARN] {w}", file=sys.stderr, flush=True)

    # 模型特殊提示
    note = spec.get("note")
    if note:
        print(f"[INFO] {note}", file=sys.stderr, flush=True)

    body = {**{k: params[k] for k in DIRECT_FIELDS if k in params and params[k] is not None}, 'source': 'skill'}

    print(f"[STEP] 提交生成任务 (type={task_type})...", file=sys.stderr, flush=True)

    submit_time = int(datetime.now(UTC8).timestamp() * 1000)
    result = api_post("/ai/skill/generate", body,
                      access_token, extra_headers={"mis": mis_id})

    # MWS 透传格式: {"code": 0, "data": <taskId>, "message": "success"}
    task_id = result.get("data")
    if task_id is None:
        print(
            f"ERROR: 响应中无 data 字段: {json.dumps(result, ensure_ascii=False)}", file=sys.stderr)
        sys.exit(1)

    print(f"[STEP] 任务已提交，taskId={task_id}", file=sys.stderr, flush=True)
    return task_id, submit_time, body


def main():
    if len(sys.argv) < 2:
        print(
            "用法: python3 generate.py <access_token> --mis <mis_id> [json_file]", file=sys.stderr)
        print("  access_token: meigen login 输出的 token 字符串", file=sys.stderr)
        print("  --mis: 用户 MIS 工号（必填）", file=sys.stderr)
        print("  json_file 省略时从 stdin 读取 JSON", file=sys.stderr)
        sys.exit(1)

    positional: list[str] = []
    mis_id: str | None = None
    i = 1
    while i < len(sys.argv):
        if sys.argv[i] == "--mis" and i + 1 < len(sys.argv):
            mis_id = sys.argv[i + 1]
            i += 2
        else:
            positional.append(sys.argv[i])
            i += 1

    if not positional:
        print("ERROR: 缺少 access_token 参数", file=sys.stderr)
        sys.exit(1)

    if not mis_id:
        print("ERROR: 缺少 --mis <mis_id> 参数", file=sys.stderr)
        sys.exit(1)

    access_token = positional[0]

    if len(positional) >= 2:
        json_file = positional[1]
        if not os.path.exists(json_file):
            print(f"ERROR: JSON 文件不存在: {json_file}", file=sys.stderr)
            sys.exit(1)
        with open(json_file, "r") as f:
            params = json.load(f)
    else:
        params = json.load(sys.stdin)

    task_id, submit_time, request_body = generate(params, access_token, mis_id)
    print(task_id)
    print(submit_time)
    print(json.dumps(request_body, ensure_ascii=False))


if __name__ == "__main__":
    main()
