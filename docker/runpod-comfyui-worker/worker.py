import json
import logging
import os
import time
from typing import Any, Dict, Optional
from urllib.parse import urlparse

import requests
import runpod

COMFYUI_HOST = os.environ.get("COMFYUI_HOST", "127.0.0.1")
COMFYUI_PORT = int(os.environ.get("COMFYUI_PORT", "8188"))
COMFYUI_BASE_URL = f"http://{COMFYUI_HOST}:{COMFYUI_PORT}"
# HTTP timeout for individual ComfyUI API calls (prompt, history, etc.).
REQUEST_TIMEOUT = int(os.environ.get("REQUEST_TIMEOUT_SEC", "120"))
# How long to poll /system_stats until ComfyUI is up (serverless cold start can be minutes).
COMFYUI_READY_TIMEOUT = int(os.environ.get("COMFYUI_READY_TIMEOUT_SEC", "600"))
POLL_INTERVAL = float(os.environ.get("COMFYUI_POLL_INTERVAL_SEC", "1.5"))
MAX_WAIT_SEC = int(os.environ.get("COMFYUI_MAX_WAIT_SEC", "900"))
LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO").upper()

logging.basicConfig(
    level=getattr(logging, LOG_LEVEL, logging.INFO),
    format="%(asctime)s %(levelname)s %(message)s",
)
LOGGER = logging.getLogger("runpod-comfyui-worker")


def _wait_for_comfyui() -> None:
    started = time.time()
    while time.time() - started < COMFYUI_READY_TIMEOUT:
        try:
            res = requests.get(f"{COMFYUI_BASE_URL}/system_stats", timeout=5)
            if res.ok:
                LOGGER.info("ComfyUI is ready at %s", COMFYUI_BASE_URL)
                return
        except requests.RequestException:
            pass
        time.sleep(1)
    raise RuntimeError(
        f"ComfyUI is not responding at {COMFYUI_BASE_URL} within {COMFYUI_READY_TIMEOUT}s."
    )


def _submit_prompt(prompt: Dict[str, Any], client_id: str) -> str:
    payload = {"prompt": prompt, "client_id": client_id}
    res = requests.post(f"{COMFYUI_BASE_URL}/prompt", json=payload, timeout=REQUEST_TIMEOUT)
    if not res.ok:
        detail = res.text[:8000] if res.text else "(empty body)"
        # Return the raw ComfyUI response body so the caller can see why /prompt rejected the graph.
        # (Runpod error payload otherwise only contains "400 Bad Request".)
        raise RuntimeError(f"ComfyUI /prompt failed {res.status_code}: {detail}")
    data = res.json()
    prompt_id = data.get("prompt_id")
    if not prompt_id:
        raise RuntimeError(f"Missing prompt_id from ComfyUI response: {data}")
    return prompt_id


def _poll_history(prompt_id: str) -> Dict[str, Any]:
    started = time.time()
    while time.time() - started < MAX_WAIT_SEC:
        res = requests.get(f"{COMFYUI_BASE_URL}/history/{prompt_id}", timeout=REQUEST_TIMEOUT)
        res.raise_for_status()
        body = res.json()
        if prompt_id in body:
            return body[prompt_id]
        time.sleep(POLL_INTERVAL)
    raise TimeoutError(f"Timed out waiting for prompt {prompt_id} history.")


def _strip_workflow_meta(prompt: Dict[str, Any]) -> Dict[str, Any]:
    """Remove `_meta` from each node; ComfyUI /prompt often rejects UI-only fields."""
    out: Dict[str, Any] = {}
    for node_id, node in prompt.items():
        if not isinstance(node, dict):
            out[node_id] = node
            continue
        cleaned = {k: v for k, v in node.items() if k != "_meta"}
        out[node_id] = cleaned
    return out


def _normalize_prompt(job_input: Dict[str, Any]) -> Dict[str, Any]:
    if "prompt" in job_input and isinstance(job_input["prompt"], dict):
        return job_input["prompt"]
    if "prompt" in job_input and isinstance(job_input["prompt"], str):
        return json.loads(job_input["prompt"])

    if "workflow" in job_input:
        wf = job_input["workflow"]
        if isinstance(wf, dict):
            return wf
        if isinstance(wf, str):
            return json.loads(wf)

    if "workflow_json" in job_input:
        return json.loads(job_input["workflow_json"])

    # Some callers send the ComfyUI workflow object directly as `input`.
    if (
        job_input
        and all(isinstance(v, dict) for v in job_input.values())
        and any(isinstance(v, dict) and "class_type" in v for v in job_input.values())
    ):
        return job_input

    raise ValueError("Input must include `prompt` (dict) or `workflow`.")


def _prepare_prompt_for_comfyui(prompt: Dict[str, Any]) -> Dict[str, Any]:
    return _strip_workflow_meta(prompt)


def _validate_webhook_url(url: str) -> str:
    parsed = urlparse(url)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise ValueError("webhook_url must be a valid http(s) URL.")
    return url


def _post_webhook(url: str, payload: Dict[str, Any], token: Optional[str]) -> None:
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    requests.post(url, json=payload, headers=headers, timeout=REQUEST_TIMEOUT).raise_for_status()


def handler(job: Dict[str, Any]) -> Dict[str, Any]:
    job_id = str(job.get("id") or "unknown")
    LOGGER.info("Starting job id=%s", job_id)
    try:
        job_input = job.get("input", {})
        # Support direct webhook testing where payload body is not wrapped
        # in Runpod's `{ "input": ... }` envelope.
        if not job_input and "input" not in job and isinstance(job, dict):
            excluded_keys = {
                "id",
                "webhook",
                "status",
                "delayTime",
                "executionTime",
                "workerId",
                "worker",
            }
            job_input = {k: v for k, v in job.items() if k not in excluded_keys}
        if not isinstance(job_input, dict):
            raise ValueError("Job input must be an object.")

        prompt = _normalize_prompt(job_input)
        if not prompt:
            raise ValueError("Prompt/workflow payload is empty.")
        prompt = _prepare_prompt_for_comfyui(prompt)

        client_id = str(job_input.get("client_id", "runpod-comfyui-worker"))
        webhook_url = job_input.get("webhook_url") or os.environ.get("RESULT_WEBHOOK_URL")
        webhook_token = job_input.get("webhook_token") or os.environ.get("RESULT_WEBHOOK_TOKEN")
        if webhook_url:
            webhook_url = _validate_webhook_url(str(webhook_url))

        _wait_for_comfyui()
        prompt_id = _submit_prompt(prompt, client_id)
        LOGGER.info("Submitted prompt id=%s for job id=%s", prompt_id, job_id)
        result = _poll_history(prompt_id)
        LOGGER.info("Completed prompt id=%s for job id=%s", prompt_id, job_id)

        response = {"ok": True, "prompt_id": prompt_id, "result": result}
        if webhook_url:
            _post_webhook(webhook_url, response, webhook_token)
            response["webhook_posted"] = True
            LOGGER.info("Posted webhook for prompt id=%s", prompt_id)

        return response
    except Exception as exc:
        LOGGER.exception("Job failed id=%s", job_id)
        return {
            "ok": False,
            "error_type": type(exc).__name__,
            "error": str(exc),
        }


if __name__ == "__main__":
    runpod.serverless.start({"handler": handler})
