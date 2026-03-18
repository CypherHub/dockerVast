# Vast.ai + GHCR — ComfyUI image

Pre-bakes **ComfyUI** and the same **custom nodes** as your previous on-start script (Manager, Webhook, Crystools, LoadImageFromHttpURL, OpenAI, VideoHelperSuite, ReActor + pins). Models stay on **`/workspace/models`** via the bundled on-start script.

## 0. Launch this on GitHub (repo + automatic image build)

Do this once so GitHub stores the Dockerfile and (optionally) builds the image to **GHCR**.

### A. Create an empty repo on GitHub

1. Open [github.com/new](https://github.com/new).
2. Name it (e.g. `vast-comfyui` or use your monorepo name).
3. Leave **without** README / .gitignore (avoids merge noise), create the repo.
4. Copy the repo URL, e.g. `https://github.com/YOU/vast-comfyui.git`.

### B. Push this folder’s project from your computer

From the **root of the project** that contains `docker/vast-comfyui/` and `.github/workflows/ghcr-vast-comfyui.yml`:

```bash
cd /path/to/your/project   # parent of docker/ and .github/

git init
git add docker/vast-comfyui .github/workflows/ghcr-vast-comfyui.yml
# add any other files you want in the repo, e.g. git add .
git commit -m "Add Vast ComfyUI Docker image + GHCR workflow"
git branch -M main
git remote add origin https://github.com/YOU/REPO.git
git push -u origin main
```

Use **SSH** remote if you prefer: `git@github.com:YOU/REPO.git`.

### C. Build the image on GitHub → GHCR

After the push, GitHub Actions runs **“GHCR — Vast ComfyUI”** when `docker/vast-comfyui/**` changes on `main` or `master`.

- **Manual run:** Repo → **Actions** → **GHCR — Vast ComfyUI** → **Run workflow**.
- When it finishes, the image is at:  
  **`ghcr.io/YOU/vast-comfyui:latest`**  
  (same **YOU** as your GitHub username or org; see **Packages** on your profile/org).

**First-time package visibility:** If Vast cannot pull the image, open the package on GitHub → **Package settings** → set visibility to **public**, or give Vast a PAT with `read:packages` (see §2).

---

## 1. Build locally

```bash
cd docker/vast-comfyui
docker build -t ghcr.io/<YOUR_GH_USER_OR_ORG>/vast-comfyui:latest .
```

## 2. Push to GHCR

1. Create a GitHub PAT with `write:packages` (or use `gh auth login` + `ghcr.io`).
2. Login: `echo $GITHUB_TOKEN | docker login ghcr.io -u USER --password-stdin`
3. Push: `docker push ghcr.io/<OWNER>/vast-comfyui:latest`

Or push this repo to GitHub and run workflow **“GHCR — Vast ComfyUI”** (builds on changes under `docker/vast-comfyui/`).

**Vast private image:** In Vast template, set Docker registry auth to GitHub (`ghcr.io`, user = GitHub username, token = PAT with `read:packages`).

## 3. Vast template

Use your image instead of `vastai/pytorch`:

**Image:** `ghcr.io/<OWNER>/vast-comfyui:latest` (or your tag)

**Ports / env** (same idea as before):

- Ports: `1111, 6006, 8080, 8384, 8188, 72299`
- Env (example):

  `OPEN_BUTTON_PORT=1111`, `OPEN_BUTTON_TOKEN=1`, `JUPYTER_DIR=/`, `DATA_DIRECTORY=/workspace/`,  
  `PORTAL_CONFIG=localhost:1111:11111:/:Instance Portal|localhost:8080:18080:/:Jupyter|...`

**Launch mode:** Jupyter + SSH + direct (or your usual Vast options).

**On-start command** (starts ComfyUI after instance is up; models under `/workspace`):

```bash
bash /usr/local/bin/vast-onstart-comfyui.sh
```

CLI-style:

```text
vastai create instance <OFFER_ID> \
  --image ghcr.io/<OWNER>/vast-comfyui:latest \
  --env '-p 1111:1111 -p 6006:6006 -p 8080:8080 -p 8384:8384 -p 8188:8188 -p 72299:72299 ...' \
  --onstart-cmd 'bash /usr/local/bin/vast-onstart-comfyui.sh' \
  --disk 16 --jupyter --ssh --direct
```

ComfyUI logs: `/workspace/comfyui.log`.

## Notes

- Base image: `pytorch/pytorch:2.5.1-cuda12.4-cudnn9-runtime`. If that tag disappears, change the `FROM` line in `Dockerfile`.
- First GPU run: confirm CUDA matches the host driver if you see driver errors.
- ReActor `install.py` runs at image build time; rebuild the image to refresh face models bundled by that step.
