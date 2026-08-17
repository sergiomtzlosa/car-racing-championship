#!/usr/bin/env python3
"""Apex Slot Racing cloud-AI mock server.

Run from the repository root:

    python3 Tools/ai-mock-server.py --port 8787

The same server exposes both supported transports:

    Direct JSON:          http://127.0.0.1:8787/v1/drive
    OpenAI-compatible:    http://127.0.0.1:8787/v1/chat/completions

Enable Cloud AI in Settings -> Cloud AI, choose the matching connection style
and use the endpoint above. The server intentionally uses only the Python
standard library. It returns a conservative local safe-speed policy. The game
always keeps its local AI active underneath, so stopping this server should
never interrupt a race.
"""

from __future__ import annotations

import argparse
import json
import math
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any


SYSTEM_PROMPT_MARKER = "Apex Slot Racing"


def _clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def _lookahead_target(payload: dict[str, Any]) -> float:
    maximum = float(payload.get("maxSpeed", 8.0) or 8.0)
    lookahead = payload.get("lookahead") or []
    target = maximum
    for item in lookahead:
        try:
            distance = max(0.0, float(item.get("distance", 0.0)))
            curvature = max(0.0, float(item.get("curvature", 0.0)))
        except (TypeError, ValueError):
            continue
        if item.get("loop"):
            target = min(target, 6.6)
            continue
        if curvature > 0.03:
            # v = sqrt(grip / curvature), with a generous slot-car grip value.
            safe = math.sqrt(16.5 / max(0.025, curvature)) * 0.94
            target = min(target, safe)
        # Brake earlier for far-away hazards; the local AI is authoritative.
        if distance < 3.0:
            target = min(target, max(2.2, maximum * (0.35 + distance * 0.12)))
    return _clamp(target, 1.0, maximum)


def make_decision(payload: dict[str, Any]) -> dict[str, Any]:
    speed = float(payload.get("speed", 0.0) or 0.0)
    maximum = float(payload.get("maxSpeed", 8.0) or 8.0)
    target = _lookahead_target(payload)
    error = target - speed
    throttle = _clamp(0.55 + error * 0.40, 0.0, 1.0)
    brake = _clamp(-error * 0.32, 0.0, 1.0) if error < -0.15 else 0.0
    if speed >= maximum * 0.985 and error <= 0:
        throttle = 0.0
    confidence = _clamp(0.98 - abs(error) * 0.04, 0.35, 1.0)
    return {
        "throttle": round(throttle, 4),
        "brake": round(brake, 4),
        "targetSpeed": round(target, 4),
        "confidence": round(confidence, 4),
    }


def _extract_chat_telemetry(payload: dict[str, Any]) -> dict[str, Any]:
    messages = payload.get("messages")
    if not isinstance(messages, list) or not messages:
        raise ValueError("messages must be a non-empty array")
    user_content: str | None = None
    for message in reversed(messages):
        if not isinstance(message, dict):
            continue
        if message.get("role") != "user":
            continue
        content = message.get("content")
        if isinstance(content, str):
            user_content = content
            break
        if isinstance(content, list):
            parts = [part.get("text", "") for part in content if isinstance(part, dict)]
            user_content = "".join(parts)
            break
    if not user_content:
        raise ValueError("no user telemetry message found")
    telemetry = json.loads(user_content)
    if not isinstance(telemetry, dict):
        raise ValueError("telemetry must be a JSON object")
    return telemetry


class Handler(BaseHTTPRequestHandler):
    server_version = "ApexSlotRacingMockAI/1.1"

    def _write_json(self, status: int, value: dict[str, Any]) -> None:
        body = json.dumps(value, separators=(",", ":")).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self) -> None:  # noqa: N802 (HTTP method name)
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.end_headers()

    def do_GET(self) -> None:  # noqa: N802
        if self.path in ("/health", "/v1/health"):
            self._write_json(200, {
                "ok": True,
                "service": "apex-cloud-ai-mock",
                "transports": ["/v1/drive", "/v1/chat/completions"],
                "time": time.time(),
            })
        else:
            self._write_json(404, {"error": "not_found", "path": self.path})

    def do_POST(self) -> None:  # noqa: N802
        is_direct = self.path in ("/v1/drive", "/drive")
        is_chat = self.path in ("/v1/chat/completions", "/chat/completions")
        if not is_direct and not is_chat:
            self._write_json(404, {"error": "not_found", "path": self.path})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length <= 0 or length > 1_000_000:
                raise ValueError("invalid content length")
            raw = self.rfile.read(length)
            payload = json.loads(raw.decode("utf-8"))
            if not isinstance(payload, dict):
                raise ValueError("payload must be an object")
        except (ValueError, UnicodeDecodeError, json.JSONDecodeError) as exc:
            self._write_json(400, {"error": "invalid_json", "detail": str(exc)})
            return

        if is_direct:
            self._write_json(200, make_decision(payload))
            return

        try:
            telemetry = _extract_chat_telemetry(payload)
            decision = make_decision(telemetry)
        except (ValueError, TypeError, json.JSONDecodeError) as exc:
            self._write_json(400, {"error": "invalid_chat_payload", "detail": str(exc)})
            return

        model = payload.get("model") or "mock-racer"
        created = int(time.time())
        self._write_json(200, {
            "id": f"chatcmpl-mock-{uuid.uuid4().hex[:12]}",
            "object": "chat.completion",
            "created": created,
            "model": model,
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": json.dumps(decision, separators=(",", ":")),
                },
                "finish_reason": "stop",
            }],
            "usage": {
                "prompt_tokens": 64,
                "completion_tokens": 24,
                "total_tokens": 88,
            },
        })

    def log_message(self, fmt: str, *args: Any) -> None:
        # Keep stdout useful when demonstrating the server in a terminal.
        print(f"[{self.log_date_time_string()}] {fmt % args}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Apex Slot Racing cloud AI mock server")
    parser.add_argument("--host", default="127.0.0.1", help="bind address (default: localhost only)")
    parser.add_argument("--port", type=int, default=8787, help="port (default: 8787)")
    args = parser.parse_args()

    server = ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"Apex Slot Racing mock AI listening on http://{args.host}:{args.port}")
    print("POST /v1/drive | POST /v1/chat/completions | GET /health | Ctrl-C to stop")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping mock AI.")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
