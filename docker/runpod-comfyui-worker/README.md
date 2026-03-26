# Runpod Serverless + GHCR - ComfyUI Worker

Builds a Runpod serverless container that:

- Starts ComfyUI in the container.
- Accepts Runpod jobs with a ComfyUI prompt/workflow.
- Waits for completion via ComfyUI history.
- Optionally posts the final payload to your webhook URL.

Image target:

- `ghcr.io/<OWNER>/runpod-comfyui-worker:latest`

## Input contract

Pass one of:

- `input.prompt` (ComfyUI prompt JSON object), or
- `input.workflow` (JSON object or JSON string).

Optional:

- `input.client_id`
- `input.webhook_url`
- `input.webhook_token`

You can also set defaults with env vars:

- `RESULT_WEBHOOK_URL`
- `RESULT_WEBHOOK_TOKEN`

## Local build

```bash
cd docker/runpod-comfyui-worker
docker build -t ghcr.io/<OWNER>/runpod-comfyui-worker:latest .
```

## Push to GHCR manually

```bash
echo "$GITHUB_TOKEN" | docker login ghcr.io -u <GITHUB_USER> --password-stdin
docker push ghcr.io/<OWNER>/runpod-comfyui-worker:latest
```

## GitHub Actions publish

Workflow file:

- `.github/workflows/ghcr-runpod-comfyui-worker.yml`

It publishes on push changes under:

- `docker/runpod-comfyui-worker/**`

or manual dispatch.

## Example Runpod job input

```json
{
  "input": {
    "client_id": "my-job",
    "workflow": {
      "3": {
        "class_type": "KSampler",
        "inputs": {}
      }
    },
    "webhook_url": "https://example.com/my-webhook"
  }
}
```

## Notes

- Ensure your workflow JSON is valid for the exact ComfyUI version/custom nodes in this image.
- Outputs are written by ComfyUI to `/workspace/output`.
- For large models, mount persistent storage and preload models under `/workspace/models`.
