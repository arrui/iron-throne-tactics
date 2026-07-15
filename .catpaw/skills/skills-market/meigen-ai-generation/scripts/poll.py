#!/usr/bin/env python3
"""
轮询生成结果脚本 — 根据 taskId 查询任务状态，直到终态。

用法: python3 poll.py <task_id> <access_token> --submit-time <ms> --mis <mis_id> [--type <model_type>] [--timeout <seconds>] [--request-body <json>]

参数:
  task_id          generate.py 返回的任务 ID
  access_token     meigen login 输出的 access_token 字符串
  --submit-time    任务提交时间戳（毫秒，UTC+8），用于锁定 history 查询的时间窗口
  --mis            用户 MIS 工号（必填，用于 history 查询过滤）
  --type           模型类型（用于选择合理的默认超时，同时作为 history 查询过滤条件）
  --timeout        自定义超时秒数（覆盖默认值）
  --request-body   generate.py 输出的实际请求 JSON，用于埋点上报的 request 字段

成功时输出 JSON 结果到 stdout（含 images/videoUrl），进度以 [STEP] 输出到 stderr。
"""

from __future__ import annotations

import sys
import json
import os
import time

from common import api_post

# 任务终态
STATUS_SUCCEED = 3
STATUS_FAILED = 4
STATUS_TIMEOUT = 5
STATUS_INVALID = 6         # 后审不通过
STATUS_PRE_INVALID = 7     # 前审不通过
STATUS_RESOURCE_NOT_ENOUGH = 10
STATUS_SENSITIVE = 11

TERMINAL_STATUSES = {STATUS_SUCCEED, STATUS_FAILED, STATUS_TIMEOUT, STATUS_INVALID,
                     STATUS_PRE_INVALID, STATUS_RESOURCE_NOT_ENOUGH, STATUS_SENSITIVE}

STATUS_NAMES = {
    0: "初始化", 1: "生成中", 2: "审核中", 3: "成功",
    4: "失败", 5: "超时", 6: "审核不通过", 7: "前审不通过",
    10: "资源不足", 11: "敏感内容",
}

# 按模型类型设定默认超时（秒）
TIMEOUT_BY_TYPE = {
    # 图片模型
    105: 180,   # 即梦 4.5
    106: 180,   # 即梦 5.0
    401: 180,   # Longcat-image
    601: 180,   # Qwen-Image
    602: 120,   # Qwen-Image-Turbo
    901: 180,   # GPT-image-1.5
    7012: 300,  # Nano Banana2
    7013: 300,  # Nano Banana Pro
    # 视频模型
    503: 600,   # 即梦视频 3.0
    502: 600,   # LongCat-Video
    505: 600,   # Kling 2.5
    # 数字人 (LipSync)
    701: 1200,  # 数字人 (单人)
    702: 1200,  # 数字人 (双人)
}

DEFAULT_TIMEOUT = 300
POLL_INTERVAL = 5           # 轮询间隔秒数
INITIAL_WAIT = 3            # 提交后初始等待秒数
TIME_WINDOW_MS = 10000      # 时间窗口前后各 10 秒
FIND_PAGE_SIZE = 20         # 查询每页大小


def find_task(task_id: int, submit_time: int, access_token: str,
              task_type: int | None = None, mis: str | None = None) -> dict | None:
    """在 history 中按 id 查找任务，递增页码直到找到或翻完。"""
    page = 1
    while True:
        body: dict = {
            "startTime": submit_time - TIME_WINDOW_MS,
            "endTime": submit_time + TIME_WINDOW_MS,
            "page": page,
            "pageSize": FIND_PAGE_SIZE,
        }
        if mis is not None:
            body["mis"] = mis
        if task_type is not None:
            body["type"] = task_type

        result = api_post("/ai/generate/history", body, access_token, timeout=30)

        data = result.get("data") or {}
        task_list = data.get("list") or []

        for task in task_list:
            if task.get("id") == task_id:
                return task

        # 当前页数据量 < pageSize，说明已翻完所有数据
        if len(task_list) < FIND_PAGE_SIZE:
            return None

        page += 1


def poll_task(task_id: int, access_token: str, submit_time: int,
              mis_id: str, task_type: int | None = None, timeout: int | None = None) -> dict:
    """轮询任务直到终态，返回 ImageGenTaskDTO dict。"""
    if timeout is None:
        timeout = TIMEOUT_BY_TYPE.get(task_type, DEFAULT_TIMEOUT) if task_type else DEFAULT_TIMEOUT

    print(f"[STEP] 等待任务入库（{INITIAL_WAIT}s）...", file=sys.stderr, flush=True)
    time.sleep(INITIAL_WAIT)

    print(f"[STEP] 开始轮询任务 {task_id}（超时 {timeout}s）...", file=sys.stderr, flush=True)

    mis = mis_id

    start = time.time()
    last_status = None

    while True:
        elapsed = time.time() - start
        if elapsed > timeout:
            print(f"ERROR: 轮询超时（{timeout}s），任务可能仍在执行", file=sys.stderr)
            sys.exit(1)

        task = find_task(task_id, submit_time, access_token, task_type, mis)

        if task is None:
            print(f"[STEP] [{int(elapsed)}s] 任务未找到，等待...", file=sys.stderr, flush=True)
            time.sleep(POLL_INTERVAL)
            continue

        status = task.get("status")
        status_name = STATUS_NAMES.get(status, f"未知({status})")

        if status != last_status:
            print(f"[STEP] [{int(elapsed)}s] 状态: {status_name}", file=sys.stderr, flush=True)
            last_status = status

        if status in TERMINAL_STATUSES:
            return task

        time.sleep(POLL_INTERVAL)


def format_result(task: dict) -> str:
    """格式化任务结果为用户友好的 JSON 输出。"""
    status = task.get("status")

    output: dict = {
        "taskId": task.get("id"),
        "status": status,
        "statusName": STATUS_NAMES.get(status, "未知"),
    }

    if status == STATUS_SUCCEED:
        images = task.get("images", [])
        video_url = task.get("videoUrl") or task.get("videoPreviewUrl")
        if video_url:
            output["videoUrl"] = video_url
        if images:
            output["images"] = images
    else:
        output["error"] = STATUS_NAMES.get(status, "未知错误")

    return json.dumps(output, ensure_ascii=False, indent=2)


def parse_args(argv: list[str]) -> tuple[int, str, int, str, int | None, int | None, str | None]:
    """解析参数: task_id, access_token, submit_time, mis_id, type, timeout, request_body"""
    positional: list[str] = []
    task_type: int | None = None
    timeout: int | None = None
    submit_time: int | None = None
    mis_id: str | None = None
    request_body: str | None = None
    i = 0
    while i < len(argv):
        if argv[i] == "--type" and i + 1 < len(argv):
            task_type = int(argv[i + 1])
            i += 2
        elif argv[i] == "--timeout" and i + 1 < len(argv):
            timeout = int(argv[i + 1])
            i += 2
        elif argv[i] == "--submit-time" and i + 1 < len(argv):
            submit_time = int(argv[i + 1])
            i += 2
        elif argv[i] == "--mis" and i + 1 < len(argv):
            mis_id = argv[i + 1]
            i += 2
        elif argv[i] == "--request-body" and i + 1 < len(argv):
            request_body = argv[i + 1]
            i += 2
        elif argv[i] == "--prompt" and i + 1 < len(argv):
            i += 2
        else:
            positional.append(argv[i])
            i += 1

    if len(positional) < 2 or submit_time is None:
        print("用法: python3 poll.py <task_id> <access_token> --submit-time <ms> --mis <mis_id> "
              "[--type <model_type>] [--timeout <seconds>] [--request-body <json>]", file=sys.stderr)
        sys.exit(1)

    if not mis_id:
        print("ERROR: 缺少 --mis <mis_id> 参数", file=sys.stderr)
        sys.exit(1)

    return int(positional[0]), positional[1], submit_time, mis_id, task_type, timeout, request_body


def _read_skill_meta() -> tuple[str | None, str | None]:
    skill_md = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "SKILL.md")
    sid, ver = None, None
    try:
        with open(skill_md) as f:
            for line in f:
                line = line.strip()
                if line == "---" and sid is not None:
                    break
                if line.startswith("skillhub.skill_id:"):
                    sid = line.split(":", 1)[1].strip().strip('"')
                elif line.startswith("skillhub.version:"):
                    ver = line.split(":", 1)[1].strip().strip('"')
    except (OSError, IOError):
        pass
    return sid, ver


def _report(scene: str, status: int, duration_ms: int, request_obj: dict,
            response_obj: dict | None = None, username: str | None = None) -> None:
    import subprocess
    import shutil
    cli = shutil.which("meigen")
    if not cli:
        return
    skill_id, skill_ver = _read_skill_meta()
    cmd = [
        cli, "report",
        "--scene", scene,
        "--skill-name", scene,
        "--status", str(status),
        "--task-duration", str(duration_ms // 1000),
        "--request", json.dumps(request_obj, ensure_ascii=False),
    ]
    if skill_id:
        cmd += ["--skill-id", skill_id]
    if skill_ver:
        cmd += ["--skill-version", skill_ver]
    if response_obj:
        cmd += ["--response", json.dumps(response_obj, ensure_ascii=False)]
    resolved_user = username
    if not resolved_user:
        _mis_path = os.path.join(os.path.expanduser("~"), ".meigen-cli", "token", "mis_id")
        try:
            with open(_mis_path) as _f:
                _v = _f.read().strip()
                if _v:
                    resolved_user = _v
        except (OSError, IOError):
            pass
    if resolved_user:
        cmd += ["--user-id", resolved_user]
    try:
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)
    except Exception:
        pass


def main():
    task_id, access_token, submit_time, mis_id, task_type, timeout, request_body = parse_args(sys.argv[1:])
    task = poll_task(task_id, access_token, submit_time, mis_id, task_type, timeout)

    status = task.get("status")
    if status == STATUS_SUCCEED:
        print(f"[STEP] 生成成功!", file=sys.stderr, flush=True)
    else:
        print(f"[STEP] 生成结束: {STATUS_NAMES.get(status, '未知')}", file=sys.stderr, flush=True)

    result_json = format_result(task)

    # --- 上报 ---
    duration_ms = int(time.time() * 1000) - submit_time
    if request_body:
        try:
            request_obj = json.loads(request_body)
        except json.JSONDecodeError:
            request_obj = {"raw": request_body}
    else:
        request_obj = {}
        if task_type is not None:
            request_obj["type"] = task_type

    if status == STATUS_SUCCEED:
        response_obj: dict = {}
        images = task.get("images", [])
        video_url = task.get("videoUrl") or task.get("videoPreviewUrl")
        if images:
            response_obj["images"] = images
        if video_url:
            response_obj["videoUrl"] = video_url
        _report("meigen-ai-generation", 2, duration_ms, request_obj, response_obj, mis_id)
    else:
        _report("meigen-ai-generation", 3, duration_ms, request_obj, username=mis_id)

    print(result_json)

    if status != STATUS_SUCCEED:
        sys.exit(1)


if __name__ == "__main__":
    main()
