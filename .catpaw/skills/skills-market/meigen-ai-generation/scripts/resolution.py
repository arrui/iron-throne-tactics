"""Resolution adapter — 根据模型支持的分辨率格式自动转换 aspectRatio / width+height。"""

from __future__ import annotations

import sys
from typing import Any


ASPECT_RATIO_ONLY = "aspect_ratio_only"
WIDTH_HEIGHT_ONLY = "width_height_only"
RESOLUTION_NONE = "none"

STANDARD_RATIOS: list[dict[str, Any]] = [
    {"ratio": "1:1",  "value": 1.000},
    {"ratio": "4:3",  "value": 1.333},
    {"ratio": "3:2",  "value": 1.500},
    {"ratio": "16:9", "value": 1.778},
    {"ratio": "21:9", "value": 2.333},
    {"ratio": "3:4",  "value": 0.750},
    {"ratio": "2:3",  "value": 0.667},
    {"ratio": "9:16", "value": 0.563},
    {"ratio": "9:21", "value": 0.429},
]

# 各模型的 aspectRatio→width/height 尺寸映射表（与前端配置对齐）
SEEDREAM_RATIOS: dict[str, tuple[int, int]] = {
    "1:1":  (2048, 2048),
    "4:3":  (2304, 1728),
    "3:4":  (1728, 2304),
    "16:9": (2560, 1440),
    "9:16": (1440, 2560),
}

DEFAULT_RATIOS: dict[str, tuple[int, int]] = {
    "1:1":  (1024, 1024),
    "3:2":  (1536, 1024),
    "2:3":  (1024, 1536),
    "4:3":  (1088, 816),
    "3:4":  (816, 1088),
    "16:9": (1344, 756),
    "9:16": (756, 1344),
}

GPT_RATIOS: dict[str, tuple[int, int]] = {
    "1:1":  (1024, 1024),
    "3:2":  (1536, 1024),
    "2:3":  (1024, 1536),
}


def find_closest_ratio(width: int, height: int) -> str:
    """根据 width/height 计算最接近的标准宽高比（欧几里得距离）。"""
    target = width / height
    best = min(STANDARD_RATIOS, key=lambda r: abs(r["value"] - target))
    return best["ratio"]


def _find_closest_in_table(target_value: float, ratio_table: dict[str, tuple[int, int]]) -> str:
    """从给定映射表中找到数值比最接近 target_value 的比例。"""
    best_key = next(iter(ratio_table))
    best_dist = float("inf")
    for key, (w, h) in ratio_table.items():
        dist = abs(w / h - target_value)
        if dist < best_dist:
            best_dist = dist
            best_key = key
    return best_key


def ratio_to_dimensions(ratio_str: str, ratio_table: dict[str, tuple[int, int]]) -> tuple[int, int]:
    """从映射表查找宽高比对应的固定像素尺寸。比例不在表中时回退到表内最近匹配。"""
    if ratio_str in ratio_table:
        return ratio_table[ratio_str]
    parts = ratio_str.split(":")
    if len(parts) == 2:
        try:
            w_ratio, h_ratio = float(parts[0]), float(parts[1])
            if h_ratio != 0:
                target_value = w_ratio / h_ratio
                closest = _find_closest_in_table(target_value, ratio_table)
                print(f"[STEP] 比例 {ratio_str} 不在模型支持列表中，匹配到最近的 {closest}",
                      file=sys.stderr, flush=True)
                return ratio_table[closest]
        except ValueError:
            pass
    return ratio_table.get("1:1", next(iter(ratio_table.values())))


def _parse_context(ctx_value: Any) -> dict:
    """安全解析 context 字段，支持 dict 和 JSON 字符串。"""
    if isinstance(ctx_value, dict):
        return {**ctx_value}
    if isinstance(ctx_value, str):
        import json
        try:
            parsed = json.loads(ctx_value)
            if isinstance(parsed, dict):
                return parsed
        except (json.JSONDecodeError, ValueError):
            pass
    return {}


def adapt_resolution(params: dict, model_spec: dict | None) -> dict:
    """根据模型 resolution_mode 适配分辨率参数，返回新 dict。"""
    if model_spec is None:
        return params

    mode = model_spec.get("resolution_mode", RESOLUTION_NONE)
    if mode == RESOLUTION_NONE:
        return params

    result = {**params}
    has_ratio = result.get("aspectRatio") is not None
    has_wh = result.get("width") is not None and result.get("height") is not None
    has_partial_wh = (result.get("width") is not None) != (result.get("height") is not None)

    if has_partial_wh:
        print("[WARN] width 和 height 应同时传入，仅传一个时不做转换",
              file=sys.stderr, flush=True)
        return result

    needs_context_ratio = model_spec.get("needs_context_ratio", False)

    if mode == ASPECT_RATIO_ONLY:
        if has_wh and not has_ratio:
            ratio = find_closest_ratio(result["width"], result["height"])
            print(f"[STEP] 分辨率转换: {result['width']}x{result['height']} → aspectRatio={ratio}",
                  file=sys.stderr, flush=True)
            result["aspectRatio"] = ratio
            del result["width"]
            del result["height"]
            if needs_context_ratio:
                ctx = _parse_context(result.get("context"))
                ctx["ratio"] = ratio
                result["context"] = ctx
                print(f"[STEP] NanoBanana 双写: context.ratio={ratio}",
                      file=sys.stderr, flush=True)
        elif has_wh and has_ratio:
            print(f"[STEP] 模型仅支持 aspectRatio，移除 width/height",
                  file=sys.stderr, flush=True)
            del result["width"]
            del result["height"]
            if needs_context_ratio:
                ctx = _parse_context(result.get("context"))
                ctx["ratio"] = result["aspectRatio"]
                result["context"] = ctx
        elif has_ratio and needs_context_ratio:
            ctx = _parse_context(result.get("context"))
            ctx["ratio"] = result["aspectRatio"]
            result["context"] = ctx

    elif mode == WIDTH_HEIGHT_ONLY:
        ratio_table = model_spec.get("ratios", DEFAULT_RATIOS)
        if has_ratio and not has_wh:
            w, h = ratio_to_dimensions(result["aspectRatio"], ratio_table)
            print(f"[STEP] 分辨率转换: aspectRatio={result['aspectRatio']} → {w}x{h}",
                  file=sys.stderr, flush=True)
            result["width"] = w
            result["height"] = h
            del result["aspectRatio"]
        elif has_ratio and has_wh:
            print(f"[STEP] 模型仅支持 width/height，移除 aspectRatio",
                  file=sys.stderr, flush=True)
            del result["aspectRatio"]

    return result
