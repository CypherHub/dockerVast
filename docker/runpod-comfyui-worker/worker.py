import json
import os
import time
from typing import Any, Dict, Optional

import requests
import runpod

COMFYUI_HOST = os.environ.get("COMFYUI_HOST", "127.0.0.1")
COMFYUI_PORT = int(os.environ.get("COMFYUI_PORT", "8188"))
COMFYUI_BASE_URL = f"http://{COMFYUI_HOST}:{COMFYUI_PORT}"
REQUEST_TIMEOUT = int(os.environ.get("REQUEST_TIMEOUT_SEC", "60"))
POLL_INTERVAL = float(os.environ.get("COMFYUI_POLL_INTERVAL_SEC", "1.5"))
MAX_WAIT_SEC = int(os.environ.get("COMFYUI_MAX_WAIT_SEC", "900"))


def _wait_for_comfyui() -> None:
    started = time.time()
    while time.time() - started < REQUEST_TIMEOUT:
        try:
            res = requests.get(f"{COMFYUI_BASE_URL}/system_stats", timeout=5)
            if res.ok:
                return
        except requests.RequestException:
            pass
        time.sleep(1)
    raise RuntimeError("ComfyUI is not responding.")


def _submit_prompt(prompt: Dict[str, Any], client_id: str) -> str:
    payload = {"prompt": prompt, "client_id": client_id}
    res = requests.post(f"{COMFYUI_BASE_URL}/prompt", json=payload, timeout=REQUEST_TIMEOUT)
    res.raise_for_status()
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


def _normalize_prompt(job_input: Dict[str, Any]) -> Dict[str, Any]:
    if "prompt" in job_input and isinstance(job_input["prompt"], dict):
        return job_input["prompt"]

    if "workflow" in job_input:
        wf = job_input["workflow"]
        if isinstance(wf, dict):
            return wf
        if isinstance(wf, str):
            return json.loads(wf)

    if "workflow_json" in job_input:
        return json.loads(job_input["workflow_json"])

    raise ValueError("Input must include `prompt` (dict) or `workflow`.")


def _post_webhook(url: str, payload: Dict[str, Any], token: Optional[str]) -> None:
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    requests.post(url, json=payload, headers=headers, timeout=REQUEST_TIMEOUT).raise_for_status()


def handler(job: Dict[str, Any]) -> Dict[str, Any]:
    job_input = job.get("input", {})
    prompt = _normalize_prompt(job_input)
    client_id = str(job_input.get("client_id", "runpod-comfyui-worker"))
    webhook_url = job_input.get("webhook_url") or os.environ.get("RESULT_WEBHOOK_URL")
    webhook_token = job_input.get("webhook_token") or os.environ.get("RESULT_WEBHOOK_TOKEN")

    _wait_for_comfyui()
    prompt_id = _submit_prompt(prompt, client_id)
    result = _poll_history(prompt_id)

    response = {"ok": True, "prompt_id": prompt_id, "result": result}
    if webhook_url:
        _post_webhook(webhook_url, response, webhook_token)
        response["webhook_posted"] = True

    return response


if __name__ == "__main__":
    runpod.serverless.start({"handler": handler})
