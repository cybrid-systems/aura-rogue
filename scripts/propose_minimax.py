#!/usr/bin/env python3
"""Host-side MiniMax proposer for aura-rogue loot/AI packs.

HTTP stays here. Soft only reads the lambda file this script writes and
gates it (set!/display/mutate/eval/load/shell/http are Soft's job).

Config: $MINIMAX_ENV_FILE or ~/.config/aura-build/minimax.env
  MINIMAX_API_KEY_FILE, MINIMAX_BASE_URL, MINIMAX_MODEL

Default base is https://api.minimax.cn/v1. A configured api.minimaxi.com
host is rewritten to api.minimax.cn. This script never calls api.minimaxi.com.

Usage: propose_minimax.py OUT_PATH [ROUND [NOTE [PREV_PATH]]]
Stdout stays empty. Stderr is PROPOSE_WROTE or PROPOSE_FAIL <reason>.
The API key is never printed.
"""
from __future__ import annotations

import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

CN_BASE = "https://api.minimax.cn/v1"


def _env_file() -> Path | None:
    raw = os.environ.get("MINIMAX_ENV_FILE", "").strip()
    candidates = []
    if raw:
        candidates.append(Path(raw))
    candidates.append(Path.home() / ".config" / "aura-build" / "minimax.env")
    candidates.append(Path("/home/box/.config/aura-build/minimax.env"))
    for p in candidates:
        if p.is_file():
            return p
    return None


def _parse_env(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        out[k.strip()] = v.strip().strip('"').strip("'")
    return out


def _read_key(env: dict[str, str], env_path: Path) -> str:
    key = os.environ.get("MINIMAX_API_KEY", "").strip()
    if key:
        return key
    file_raw = env.get("MINIMAX_API_KEY_FILE", "").strip()
    candidates = []
    if file_raw:
        candidates.append(Path(file_raw))
        candidates.append(env_path.parent / Path(file_raw).name)
    candidates.append(env_path.parent / "minimax_api_key")
    for p in candidates:
        if p.is_file():
            return p.read_text(encoding="utf-8").strip()
    return ""


def _redact(text: str, key: str) -> str:
    if key and key in text:
        text = text.replace(key, "[redacted]")
    return text


def _base_url(env: dict[str, str]) -> str:
    base = (
        os.environ.get("MINIMAX_BASE_URL", "").strip()
        or env.get("MINIMAX_BASE_URL", "").strip()
        or CN_BASE
    ).rstrip("/")
    # Never call api.minimaxi.com. The product host is api.minimax.cn.
    if "minimaxi.com" in base:
        print("PROPOSE_BASE " + CN_BASE, file=sys.stderr)
        return CN_BASE
    return base


def _balanced(s: str) -> bool:
    n = 0
    for ch in s:
        if ch == "(":
            n += 1
        elif ch == ")":
            n -= 1
            if n < 0:
                return False
    return n == 0


def _extract_lambda(text: str) -> str:
    if not text:
        return ""
    fence = re.search(r"```(?:aura|scheme|lisp)?\s*([\s\S]*?)```", text, re.I)
    body = fence.group(1) if fence else text
    start = body.find("(lambda")
    if start < 0:
        return ""
    n = 0
    end = -1
    for i, ch in enumerate(body[start:], start):
        if ch == "(":
            n += 1
        elif ch == ")":
            n -= 1
            if n == 0:
                end = i + 1
                break
    if end < 0:
        return ""
    line = " ".join(body[start:end].split())
    if not line.startswith("(lambda"):
        return ""
    if "list" not in line:
        return ""
    if not _balanced(line):
        return ""
    return line


def _prompt(rnd: int, note: str, prev: str) -> str:
    prev_s = prev.strip() if prev else "none"
    # Round-stamped integers so the model cannot copy the previous body.
    lhp = 1 + (rnd % 6)
    latk = rnd % 4
    ai = 1 + (rnd % 3)
    example = f"(lambda () (list {lhp} {latk} {ai}))"
    return (
        "Return ONLY one Aura line of the form (lambda () (list loot-hp loot-atk ai-div)). "
        f"You are proposing a Soft loot/AI rule pack for round {rnd}. "
        "loot-hp is post-clear HP gain (0..8), loot-atk is post-clear ATK gain (0..4), "
        "ai-div is enemy ATK divisor (1..4; higher is more timid). All three must be integers. "
        "ONLY use: lambda, list, and non-negative integers in parentheses. "
        "Do NOT use set!, begin, display, mutate, eval, load, shell, http, "
        "mod, modulo, floor, quotient, or division. No markdown. "
        f"Include the integer {rnd} as one of the three numbers or change at least "
        f"one field from the previous lambda. "
        f"Previous lambda (do not repeat it verbatim): {prev_s}. "
        f"Last note: {note}. "
        f"Shape example, change it: {example}"
    )


def _banned(lam: str) -> str:
    banned = (
        "set!",
        "vector-set!",
        "begin",
        "display",
        "mutate",
        "eval",
        "load",
        "shell",
        "http",
        "mod",
        "modulo",
        "floor",
        "quotient",
    )
    low = lam.lower()
    for b in banned:
        if b.lower() in low:
            return b
    if " / " in lam or "(/" in lam:
        return "/"
    return ""


def _looks_like_pack(lam: str) -> bool:
    # (lambda () (list N N N)) with optional whitespace already collapsed.
    m = re.match(
        r"^\(lambda\s*\(\s*\)\s*\(list\s+(-?\d+)\s+(-?\d+)\s+(-?\d+)\s*\)\s*\)$",
        lam,
    )
    if not m:
        return False
    lhp, latk, ai = (int(m.group(i)) for i in range(1, 4))
    if lhp < 0 or lhp > 16:
        return False
    if latk < 0 or latk > 16:
        return False
    if ai < 1 or ai > 16:
        return False
    return True


def _call(base: str, key: str, model: str, prompt: str, temperature: float) -> str:
    body = {
        "model": model,
        "messages": [
            {"role": "system", "content": "You output a single Aura lambda and nothing else."},
            {"role": "user", "content": prompt},
        ],
        "temperature": temperature,
        "max_tokens": 256,
        "thinking": {"type": "disabled"},
    }
    req = urllib.request.Request(
        f"{base}/chat/completions",
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        payload = json.loads(resp.read().decode("utf-8"))
    return str(payload["choices"][0]["message"]["content"] or "")


def main() -> int:
    if len(sys.argv) < 2 or len(sys.argv) > 5:
        print("PROPOSE_FAIL usage", file=sys.stderr)
        return 2
    out = Path(sys.argv[1])
    rnd = 1
    note = "none"
    prev = ""
    if len(sys.argv) >= 3:
        try:
            rnd = int(sys.argv[2])
        except ValueError:
            rnd = 1
    if len(sys.argv) >= 4:
        note = sys.argv[3].replace("\n", " ")[:180]
    if len(sys.argv) >= 5 and sys.argv[4]:
        pp = Path(sys.argv[4])
        if pp.is_file():
            prev = " ".join(pp.read_text(encoding="utf-8").split())
    env_path = _env_file()
    if env_path is None:
        print("PROPOSE_FAIL no_env", file=sys.stderr)
        return 1
    env = _parse_env(env_path)
    key = _read_key(env, env_path)
    if not key:
        print("PROPOSE_FAIL no_key", file=sys.stderr)
        return 1
    base = _base_url(env)
    model = (
        os.environ.get("MINIMAX_MODEL", "").strip()
        or env.get("MINIMAX_MODEL", "").strip()
        or "MiniMax-M3"
    )
    prompt = _prompt(rnd, note, prev)
    lam = ""
    last_fail = "no_lambda"
    for _attempt, temp in ((1, 0.4), (2, 0.8)):
        try:
            content = _call(base, key, model, prompt, temp)
        except urllib.error.HTTPError as exc:
            err = exc.read().decode("utf-8", errors="replace")[:300]
            print("PROPOSE_FAIL http_" + str(exc.code) + " " + _redact(err, key), file=sys.stderr)
            return 1
        except Exception as exc:  # noqa: BLE001
            print("PROPOSE_FAIL " + _redact(type(exc).__name__, key), file=sys.stderr)
            return 1
        cand = _extract_lambda(content)
        if not cand.startswith("(lambda"):
            last_fail = "no_lambda"
            continue
        bad = _banned(cand)
        if bad:
            last_fail = "banned_" + bad.replace("!", "").strip()
            continue
        if not _looks_like_pack(cand):
            last_fail = "shape"
            continue
        if prev and cand == prev:
            last_fail = "repeat"
            prompt = prompt + " The previous attempt repeated the prior lambda. Change a number."
            continue
        lam = cand
        break
    if not lam:
        print("PROPOSE_FAIL " + last_fail, file=sys.stderr)
        return 1
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(lam + "\n", encoding="utf-8")
    print("PROPOSE_WROTE", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
