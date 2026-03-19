# Vast.ai + GHCR — ComfyUI image

Pre-bakes **ComfyUI**, PyTorch **2.7**, Manager, Webhook, Crystools, LoadImageFromHttpURL, OpenAI, VideoHelperSuite, ReActor.

**ComfyUI-Trellis2** is **not installed in the GHCR layer** (native `meshlib` / wheels break headless CI). On **first instance boot**, on-start runs **`install-trellis2-runtime.sh`** (log: **`/workspace/trellis2-install.log`**). With a **persistent `/workspace`**, marker **`/workspace/.trellis2_runtime_ok`** skips reinstall.

**DINOv3** downloads on first boot too (**`/workspace/dinov3-download.log`**). After both finish, open workflows from **`custom_nodes/ComfyUI-Trellis2/example_workflows/`** and refresh ComfyUI.

**Base image:** `pytorch/pytorch:2.7.0-cuda12.8-cudnn9-runtime` — use a Vast GPU with a recent driver (CUDA 12.x–compatible).

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

## 3. Vast template (quick reference)

**Image:** `ghcr.io/<OWNER>/vast-comfyui:latest`

**On-start:** `bash /usr/local/bin/vast-onstart-comfyui.sh`

See **§4** below for the full Vast walkthrough.

---

## 4. Using this image on Vast.ai (detailed)

This section assumes your image is already on GHCR (e.g. **`ghcr.io/cypherhub/vast-comfyui:latest`** — replace with your org/user).

### 4.1 Before you rent a GPU

1. **Image exists:** In GitHub → your repo → **Actions** → confirm **GHCR — Vast ComfyUI** succeeded. In **Packages**, you should see `vast-comfyui`.
2. **Vast can pull the image:**
   - **Public package:** In GitHub → package **Package settings** → visibility **Public** (simplest for Vast).
   - **Private package:** You must add **Docker registry authentication** on the template (see §4.6).

### 4.2 Create a reusable template (Vast UI)

1. Go to [vast.ai](https://vast.ai) → **Templates** (or start from **Search** and use **Create template** when configuring an instance).
2. **Template name / description:** Anything you like (e.g. “ComfyUI GHCR”).
3. **Docker image**  
   - **Image:** `ghcr.io/<YOUR_GITHUB_USER_OR_ORG>/vast-comfyui:latest`  
   - Example: `ghcr.io/cypherhub/vast-comfyui:latest`  
   - **Version tag:** leave default or set `latest`.

### 4.3 Ports

Expose at least **8188** (ComfyUI). To match a typical Jupyter + portal setup like your old template, also expose:

| Port  | Use |
|-------|-----|
| 8188  | **ComfyUI** (main UI) |
| 8080  | Jupyter / terminal |
| 1111  | Instance portal |
| 6006  | TensorBoard |
| 8384  | Syncthing |
| 72299 | Extra (if you use Vast “open” links) |

In the template **Docker options** / **Ports** field, you can use CLI-style port flags, e.g.:

```text
-p 1111:1111 -p 6006:6006 -p 8080:8080 -p 8384:8384 -p 8188:8188 -p 72299:72299
```

### 4.4 Environment variables (portal / Jupyter)

These match the common Vast “portal” layout (adjust if you use a minimal template):

```text
OPEN_BUTTON_PORT=1111
OPEN_BUTTON_TOKEN=1
JUPYTER_DIR=/
DATA_DIRECTORY=/workspace/
PORTAL_CONFIG=localhost:1111:11111:/:Instance Portal|localhost:8080:18080:/:Jupyter|localhost:8080:8080:/terminals/1:Jupyter Terminal|localhost:8384:18384:/:Syncthing|localhost:6006:16006:/:Tensorboard
```

Paste **Name = value** pairs in the template’s environment section, or fold into `--env` on the CLI (see §4.8).

### 4.5 Launch mode

Choose what you’re used to:

- **Jupyter Lab + SSH + Direct** — same class of setup as the original `vastai/pytorch` template; good for file upload and notebooks.
- **SSH only** — lighter; you still get ComfyUI on 8188 if ports are mapped.

**On-start command** (required so ComfyUI actually starts):

```bash
bash /usr/local/bin/vast-onstart-comfyui.sh
```

If your template still runs Vast’s **`entrypoint.sh`** first (typical for **Jupyter + SSH**), **chain** them so ComfyUI starts after the base entrypoint returns (or use Vast’s documented pattern), e.g.:

```bash
entrypoint.sh; bash /usr/local/bin/vast-onstart-comfyui.sh
```

If you **merge** this image with a Jupyter base in your own Dockerfile, Docker warns when there are **multiple `ENTRYPOINT`s** — only the **last** runs. In that case you **must** still invoke **`vast-onstart-comfyui.sh`** from Vast’s **On-start Script**; otherwise Jupyter comes up on 8080 but **nothing starts ComfyUI on 8188**.

This script:

- Ensures **`/workspace/models`** exists and **symlinks** ComfyUI’s `models` folder there so **checkpoints and LoRAs survive** instance stop/start when `/workspace` is on a persistent volume.
- Starts ComfyUI in the background on **`0.0.0.0:8188`** with `--highvram`.
- Logs to **`/workspace/comfyui.log`**.

### 4.6 Private GHCR image (Docker login on Vast)

If the package is **private**:

1. Create a GitHub **fine-grained or classic PAT** with **`read:packages`**.
2. In the Vast template, open **Docker Repository Authentication**:
   - **Registry:** `ghcr.io`
   - **Username:** your GitHub username
   - **Password / token:** the PAT

### 4.7 Disk and models

- **Container disk:** e.g. **16 GB+** for the image layers; add more if you install extra tools at runtime.
- **Models:** Stored under **`/workspace/models/...`** once ComfyUI runs. Use a Vast **volume** mapped to `/workspace` (or ensure your workflow keeps `/workspace` persistent) so you don’t re-download large checkpoints every time.

### 4.8 After the instance is running

1. Wait **1–3 minutes** after first boot (ComfyUI loads in background).
2. **Open ComfyUI:** In Vast, use the exposed **8188** link (or your portal entry if you mapped it). URL is usually shown in the instance **Connect** / **Open** UI.
3. **Check if ComfyUI is up:** SSH in and run:
   - `tail -f /workspace/comfyui.log`
   - `netstat -tuln | grep 8188` or `curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8188/`
4. **Jupyter / SSH:** Use the links/credentials Vast shows for the instance.

### 4.9 CLI example (`vastai`)

Replace `<OFFER_ID>` and image owner:

```bash
vastai create instance <OFFER_ID> \
  --image ghcr.io/cypherhub/vast-comfyui:latest \
  --env '-p 1111:1111 -p 6006:6006 -p 8080:8080 -p 8384:8384 -p 8188:8188 -p 72299:72299 -e OPEN_BUTTON_PORT=1111 -e OPEN_BUTTON_TOKEN=1 -e JUPYTER_DIR=/ -e DATA_DIRECTORY=/workspace/ -e PORTAL_CONFIG="localhost:1111:11111:/:Instance Portal|localhost:8080:18080:/:Jupyter|localhost:8080:8080:/terminals/1:Jupyter Terminal|localhost:8384:18384:/:Syncthing|localhost:6006:16006:/:Tensorboard"' \
  --onstart-cmd 'bash /usr/local/bin/vast-onstart-comfyui.sh' \
  --disk 16 --jupyter --ssh --direct
```

### 4.10 ComfyUI not running

If ComfyUI never appears on port 8188:

1. Confirm **`/workspace/onstart.log`** exists and mentions **ComfyUI supervisor** — if not, the on-start script never ran (fix Vast **On-start** per §4.5, especially Jupyter/merged images).
2. Read **`/workspace/comfyui.log`** for Python errors. The on-start script **starts ComfyUI first** (after the models symlink), then runs Trellis2 + DINOv3 in the background — slow Trellis/DINO no longer block startup on current images.
3. If you still see **`Installing ComfyUI-Trellis2 (first boot, several min)`** before ComfyUI, you are on an **older** image; rebuild/pull the latest GHCR tag.

If you see repeated restarts in **`comfyui.log`**, the cause is usually a missing dependency or CUDA/driver mismatch; run the same `python main.py …` command by hand in `/opt/ComfyUI` with the venv activated to see the traceback.

### 4.11 Troubleshooting (general)

| Problem | What to try |
|---------|-------------|
| Instance fails to pull image | Set package **public** or add **ghcr.io** auth (§4.6). |
| ComfyUI won’t load | Read `/workspace/comfyui.log`; confirm port **8188** is published. |
| Models missing after new instance | Use persistent **`/workspace`**; models live under `/workspace/models`. |
| ReActor: `inswapper_128.onnx` not in `[]` | On-start copies/downloads **`/workspace/models/insightface/inswapper_128.onnx`** before linking models. Recreate the instance or restart after pulling a newer image; or download that file into `models/insightface` manually. |

ComfyUI logs: **`/workspace/comfyui.log`**.

### 4.12 SSH — install a custom wheel (ComfyUI’s Python only)

ComfyUI runs with **`/opt/ComfyUI/venv`** — not system Python. Over SSH:

```bash
# Copy mypackage.whl to /workspace (scp / Jupyter upload), then:
/opt/ComfyUI/venv/bin/pip install /workspace/mypackage.whl
```

Or:

```bash
source /opt/ComfyUI/venv/bin/activate
pip install /workspace/mypackage.whl
```

**Pick up new installs:** stop the running ComfyUI process (e.g. `pkill -f "python main.py"`). With a **current** image, the on-start **supervisor** brings ComfyUI back within ~10s. Otherwise restart the instance.

### 4.13 Does port 8188 / ComfyUI restart after a crash?

**Images before the supervisor change:** No — one `nohup` run; if ComfyUI died, 8188 stayed down until you rebooted the instance.

**Current on-start script:** ComfyUI is run inside a **loop** that waits **~10s** after exit and starts it again. Crash lines look like: `ComfyUI exited (code …); restarting in 10s…` in **`/workspace/comfyui.log`**.

### 4.14 ComfyUI-Trellis2 (first-boot on Vast)

Watch **`/workspace/trellis2-install.log`** and **`/workspace/dinov3-download.log`**. If Trellis install fails, SSH and run **`bash /usr/local/bin/install-trellis2-runtime.sh`** manually, then **`pkill -f "python main.py"`**.

### 4.15 SSH key for remoting in (troubleshooting)

The image includes **openssh-server** and the on-start script starts **sshd** so you can SSH into every new VM. To use it:

1. **Generate an SSH key** on your machine (if you don’t have one):
   ```bash
   ssh-keygen -t ed25519 -C "vast-comfyui" -f ~/.ssh/vast_comfyui
   ```
2. **Add the public key to Vast** so it is injected into every new instance: Vast dashboard → **SSH Keys** (or account settings) → add the contents of `~/.ssh/vast_comfyui.pub`.
3. When you rent an instance from this image, Vast will add that key to the container; you can then SSH in (e.g. using the SSH command Vast shows for the instance) to troubleshoot.

## Notes

- Base image: **`pytorch/pytorch:2.7.0-cuda12.8-cudnn9-runtime`**. If that tag disappears, update `FROM` in `Dockerfile` and re-pin Torch to match Trellis `wheels/Linux/Torch270` (cp312).
- First GPU run: confirm CUDA matches the host driver if you see driver errors.
- ReActor `install.py` runs at image build time; rebuild the image to refresh face models bundled by that step.
