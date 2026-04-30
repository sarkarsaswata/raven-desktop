# Quick Start

**docker_ubuntu — Minimum steps to a running desktop**

---

## Prerequisites (one-time)

Confirm your host has these before continuing:

```bash
# NVIDIA driver is loaded
nvidia-smi

# Docker can use the GPU
docker run --rm --runtime=nvidia nvidia/cuda:12.8.0-runtime-ubuntu22.04 nvidia-smi

# /mount/Data2 is available and writable
df -h /mount/Data2
```

If any of these fail, see [DEPLOYMENT.md](DEPLOYMENT.md) for the full
host prerequisites checklist.

---

## Step 1 — Build the Image

```bash
cd /home/saswata/raven-desktop/docker_ubuntu
./build.sh
```

Takes 15-25 minutes the first time. Verify:

```bash
docker images local/ubuntu-desktop
```

---

## Step 2 — Launch

```bash
./launch_user.sh alice 8080 9090
```

When prompted, enter a VNC password (minimum 6 characters).

The script creates `/mount/Data2/alice/workspace` and
`/mount/Data2/alice/mounts.conf` on the first run for this user, then
starts the container.

---

## Step 3 — Open the Desktop

Open a browser and navigate to:

```
http://<host-ip>:8080
```

Enter the VNC password. The LXDE desktop appears in the browser.

---

## Common Tasks

### Open a terminal in the desktop

Right-click the desktop background and select **Terminal**, or click the
Terminal shortcut on the desktop.

### Access the container shell directly

```bash
docker exec -it alice_desktop bash
```

### Check GPU from inside the container

```bash
docker exec alice_desktop nvidia-smi
```

### Stop the container

```bash
docker compose -p alice_project down
```

### Add extra volume mounts (datasets, codebases)

Edit `/mount/Data2/alice/mounts.conf`, then stop and re-launch. See
[MOUNTS.md](MOUNTS.md) for the file format and validation rules.

### Launch a second user on different ports

```bash
./launch_user.sh bob 8081 9091
```

Each user gets their own isolated container, workspace, and VNC password.

---

## What's on the Desktop

| Shortcut | Application |
|----------|-------------|
| Terminal | LXTerminal |
| File Manager | PCManFM |
| VS Code | `code --no-sandbox` |
| Brave Browser | `brave-browser --no-sandbox` |
| System Monitor | gnome-system-monitor |

`uv` is available in every terminal for fast Python package management:

```bash
uv venv .venv
source .venv/bin/activate
uv pip install numpy torch
```
