#!/usr/bin/env python3
"""
Submit the Reface (ReActor) workflow to a RunPod serverless endpoint via /runsync.

Requires:
  RUNPOD_API_KEY
  RUNPOD_ENDPOINT_ID

Optional:
  WORKFLOW_JSON   Path to workflow JSON (default: docker/runpod-comfyui-worker/workflows/RefaceImageToImageAPI.json)
  RUNSYNC_WAIT_MS Max HTTP wait for /runsync (RunPod allows 1000–300000 ms; default 300000 = 5 min).
  For longer jobs, set USE_ASYNC=1 to use /run and poll /status instead.
"""
from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path


def _repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def main() -> int:
    api_key = os.environ.get("RUNPOD_API_KEY", "").strip()
    endpoint_id = os.environ.get("RUNPOD_ENDPOINT_ID", "").strip()
    if not api_key or not endpoint_id:
        print("Set RUNPOD_API_KEY and RUNPOD_ENDPOINT_ID.", file=sys.stderr)
        return 1

    default_wf = (
        _repo_root()
        / "docker"
        / "runpod-comfyui-worker"
        / "workflows"
        / "RefaceImageToImageAPI.json"
    )
    wf_path = Path(os.environ.get("WORKFLOW_JSON", str(default_wf))).expanduser()
    workflow = json.loads(wf_path.read_text(encoding="utf-8"))

    wait_ms = max(1000, min(300000, int(os.environ.get("RUNSYNC_WAIT_MS", "300000"))))
    use_async = os.environ.get("USE_ASYNC", "").lower() in ("1", "true", "yes")

    body = {"input": {"workflow": workflow}}
    data = json.dumps(body).encode("utf-8")
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": api_key,
    }

    if use_async:
        url = f"https://api.runpod.ai/v2/{endpoint_id}/run"
        req = urllib.request.Request(url, data=data, method="POST", headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                start = json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            print(f"HTTP {e.code}: {e.read().decode('utf-8', errors='replace')}", file=sys.stderr)
            return 1
        job_id = start.get("id")
        if not job_id:
            print(start, file=sys.stderr)
            return 1
        poll_sec = float(os.environ.get("STATUS_POLL_SEC", "3"))
        max_wait = int(os.environ.get("JOB_MAX_WAIT_SEC", "1800"))
        deadline = time.time() + max_wait
        while time.time() < deadline:
            st_url = f"https://api.runpod.ai/v2/{endpoint_id}/status/{job_id}"
            st_req = urllib.request.Request(st_url, headers={"Authorization": api_key})
            with urllib.request.urlopen(st_req, timeout=60) as st_resp:
                st = json.loads(st_resp.read().decode("utf-8"))
            status = st.get("status")
            print(json.dumps(st, indent=2))
            if status == "COMPLETED":
                return 0 if st.get("output") is not None else 1
            if status in ("FAILED", "CANCELLED", "TIMED_OUT"):
                return 1
            time.sleep(poll_sec)
        print("Timed out waiting for job.", file=sys.stderr)
        return 1

    url = f"https://api.runpod.ai/v2/{endpoint_id}/runsync?wait={wait_ms}"
    req = urllib.request.Request(url, data=data, method="POST", headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=wait_ms / 1000 + 120) as resp:
            out = resp.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8", errors="replace")
        print(f"HTTP {e.code}: {err_body}", file=sys.stderr)
        return 1
    except urllib.error.URLError as e:
        print(f"Request failed: {e}", file=sys.stderr)
        return 1

    print(out)
    try:
        parsed = json.loads(out)
        status = parsed.get("status")
        if status and status != "COMPLETED":
            return 1
    except json.JSONDecodeError:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
