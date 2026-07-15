#!/usr/bin/env python3
"""
公共模块 — 环境配置加载和 HTTP API 调用。

generate.py 和 poll.py 共享此模块，避免重复代码。
"""

from __future__ import annotations

import sys
import json
import os
import ssl
import urllib.request
import urllib.error


def load_env() -> dict[str, str]:
    defaults: dict[str, str] = {
        "BASE_URL": "https://aidesign.meituan.com",
        "CLIENT_ID": "2a7394863a",
    }
    result: dict[str, str] = dict(defaults)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    for env_file in [".env", ".env.local"]:
        env_path = os.path.join(script_dir, env_file)
        if os.path.exists(env_path):
            with open(env_path) as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith("#") and "=" in line:
                        key, _, val = line.partition("=")
                        key = key.strip()
                        if key in defaults:
                            result[key] = val.strip().rstrip("/")
    return result


_ENV = load_env()
BASE_URL = f"{_ENV['BASE_URL']}/api/aidesign"
CLIENT_ID = _ENV["CLIENT_ID"]
SSO_COOKIE_NAME = f"{CLIENT_ID}_ssoid"


def api_post(path: str, body: dict, access_token: str, timeout: int = 60,
             extra_headers: dict[str, str] | None = None) -> dict:
    url = f"{BASE_URL}{path}"
    payload = json.dumps(body, ensure_ascii=False).encode("utf-8")

    headers = {
        "Content-Type": "application/json",
        "Cookie": f"{SSO_COOKIE_NAME}={access_token}",
    }
    if extra_headers:
        headers.update(extra_headers)

    req = urllib.request.Request(
        url,
        data=payload,
        headers=headers,
        method="POST",
    )

    ssl_context = ssl.create_default_context()
    ssl_context.check_hostname = False
    ssl_context.verify_mode = ssl.CERT_NONE

    try:
        with urllib.request.urlopen(req, timeout=timeout, context=ssl_context) as resp:
            raw = resp.read()
            result = json.loads(raw.decode("utf-8", errors="replace"))

            if isinstance(result, dict):
                code = result.get("code")
                if code is not None and code != 0:
                    msg = result.get("msg", result.get("message", "未知错误"))
                    print(f"ERROR: 业务错误 code={code}, msg={msg}", file=sys.stderr)
                    sys.exit(1)

            return result

    except urllib.error.HTTPError as e:
        body_text = ""
        try:
            body_text = e.read().decode("utf-8", errors="replace")[:500]
        except Exception:
            pass

        if e.code == 401:
            print("[ERROR] 认证失败 (401)，请重新执行 meigen login 获取新 token", file=sys.stderr)
            sys.exit(1)

        print(f"ERROR: HTTP {e.code} - {e.reason}. Body: {body_text}", file=sys.stderr)
        sys.exit(1)
    except urllib.error.URLError as e:
        print(f"ERROR: 网络错误 - {e.reason}", file=sys.stderr)
        sys.exit(1)
    except TimeoutError:
        print(f"ERROR: 请求超时（{timeout}s）", file=sys.stderr)
        sys.exit(1)
