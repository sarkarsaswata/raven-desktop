# Architecture

**docker_ubuntu — Minimal Ubuntu Desktop Container**

---

## System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│ Host Machine                                                          │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│ /mount/Data2/<username>/                                              │
│ ├── workspace/          ← per-user bind mount → /root/workspace      │
│ └── mounts.conf         ← extra volume declarations                  │
│                                                                       │
│ docker_ubuntu/                                                        │
│ ├── build.sh            ← builds local/ubuntu-desktop:minimal         │
│ ├── compose.yaml        ← service definition                         │
│ └── launch_user.sh      ← per-user launcher (reads mounts.conf)      │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘
                                    │
               ┌────────────────────┴────────────────────┐
               │                                         │
               ▼                                         ▼
   ┌───────────────────────┐              ┌───────────────────────┐
   │  alice_desktop        │              │  bob_desktop          │
   │  port 8080 / 9090     │              │  port 8081 / 9091     │
   └───────────────────────┘              └───────────────────────┘
               │
               ▼
   ┌───────────────────────────────────────────────────────────┐
   │ Container internals                                        │
   ├───────────────────────────────────────────────────────────┤
   │ /root/workspace  ← rw bind mount (host Data2 workspace)   │
   │ /dev/shm         ← shared memory                          │
   │                                                           │
   │ Supervisor manages:                                        │
   │  10 Xvfb       virtual X11 display (:0)                   │
   │  20 Openbox    window manager                             │
   │  21 xcompmgr   compositor (prevents ghosting)             │
   │  22 lxpanel    taskbar                                    │
   │  23 pcmanfm    desktop icons and file manager             │
   │  30 x11vnc     VNC server → port 5900                    │
   │  31 autocutsel clipboard synchronization                  │
   │  40 websockify VNC over WebSocket → port 6080             │
   │  50 nginx      HTTP reverse proxy → port 80               │
   └───────────────────────────────────────────────────────────┘
```

---

## Image Layers (3-Stage Build)

### Stage 1: uv-builder

```dockerfile
FROM ghcr.io/astral-sh/uv:latest AS uv-builder
```

Extracts the `uv` binary (~10 MB). Copied into the final image to avoid
adding the full uv image as a dependency in the runtime layer.

---

### Stage 2: desktop-env

```dockerfile
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04 AS desktop-env
```

**Why runtime, not devel?**

The `runtime` image (~2 GB) includes CUDA runtime libraries for executing
GPU-accelerated programs. The `devel` image (~6 GB) additionally includes
`nvcc`, build headers, and static libraries needed to compile CUDA code.
Since this container runs pre-built GPU applications (VS Code extensions,
Python GPU libraries via pip/uv), no compiler is needed and the 3-4 GB
saving is worthwhile.

**What this stage installs:**

| Category | Packages |
|----------|----------|
| Build tools (minimal) | `build-essential cmake git curl wget` |
| Python | `python3.10-dev python3-pip python-is-python3` |
| X11 / VNC | `dbus-x11 x11-utils xvfb x11vnc xcompmgr` |
| Supervisor / web | `supervisor nginx tini` |
| Desktop (LXDE) | `lxde lxterminal pcmanfm lxappearance lxrandr lxinput` |
| Accessories | `xarchiver gpicview galculator gnome-system-monitor` |
| Clipboard | `xclip xsel autocutsel` |
| Themes | `arc-theme adwaita-icon-theme papirus-icon-theme ubuntu-wallpapers` |
| Fonts | `fonts-liberation fonts-dejavu fonts-noto fonts-ubuntu` |
| Shell tools | `htop vim nano tmux net-tools procps file-roller unzip zip p7zip-full` |
| Python (pip) | `websockify` |

Also installs:
- `uv` binary copied from Stage 1
- noVNC v1.6.0 downloaded to `/opt/novnc`
- nginx configured as reverse proxy (port 80 to 6080)
- LXDE autostart cleaned (light-locker disabled)

**Environment variables set permanently in the image:**

```
DISPLAY=:0
RESOLUTION=1920x1080
LANG=C.UTF-8
LC_ALL=C.UTF-8
DEBIAN_FRONTEND=noninteractive
NVIDIA_VISIBLE_DEVICES=all
NVIDIA_DRIVER_CAPABILITIES=graphics,compute,utility
UV_LINK_MODE=copy
```

---

### Stage 3: final

```dockerfile
FROM desktop-env AS final
```

Adds browser and IDE on top of the complete desktop layer:

- **VS Code** via Microsoft apt repository (`code` package)
- **Brave Browser** via the official `install.sh` script
- Startup scripts (`supervisord.conf`, `startup.sh`, `entrypoint-user.sh`) baked in
- `WORKDIR /root/workspace`
- `ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint-user.sh"]`
- `CMD ["/startup.sh"]`

**Total image size: ~5-6 GB** (vs ~8-9 GB for the `devel`-based isaac image)

---

## Startup Sequence

When the container starts, the entrypoint and CMD chain executes as follows:

```
tini (PID 1 signal handler)
  └── entrypoint-user.sh
        ├── Creates OS group matching HOST_GID if absent
        ├── Creates OS user matching HOST_UID if absent
        └── exec → startup.sh
              ├── Check / fix /root/workspace ownership (HOST_UID:HOST_GID)
              ├── Set umask 0002
              ├── Parse RESOLUTION → export WIDTH, HEIGHT
              ├── mkdir /tmp/.X11-unix, /root/.vnc, /var/run/dbus
              ├── Start dbus-daemon (system bus)
              ├── dbus-launch (session bus)
              ├── x11vnc -storepasswd (write VNC password file)
              ├── Write desktop config (pcmanfm, lxsession, gtk-3.0)
              ├── Write /root/.xsessionrc (keyboard, screensaver, clipboard)
              ├── Append to /root/.bashrc (completion, aliases, prompt)
              ├── Create /root/Desktop shortcuts (terminal, files, vscode, brave, monitor)
              └── exec supervisord -n
                    (manages all 9 processes listed above)
```

**tini** acts as PID 1 so it correctly reaps zombie processes and forwards
SIGTERM to supervisord on `docker stop`.

---

## Port Mapping

```
Host port (configurable)       Container port   Service
─────────────────────────────────────────────────────────
HTTP_PORT (default 8080)  →  80               nginx (noVNC web UI)
VNC_PORT  (default 9090)  →  5900             x11vnc (raw VNC)
(internal)                →  6080             websockify (WebSocket VNC)
```

The browser-accessible noVNC path through the stack:

```
Browser → host:HTTP_PORT → nginx:80 → websockify:6080 → x11vnc:5900 → Xvfb:0
```

---

## Volume Strategy

| Mount | Source | Mode | Purpose |
|-------|--------|------|---------|
| `/root/workspace` | `/mount/Data2/<user>/workspace` | rw | Per-user project files |
| `/dev/shm` | host `/dev/shm` | rw | Shared memory (GPU buffers) |
| `/run/udev` | host `/run/udev` | ro | Device event socket |
| `/tmp/.X11-unix` | host `/tmp/.X11-unix` | rw | X11 socket pass-through |
| extra mounts | `mounts.conf` entries | ro/rw | Per-user datasets, codebases |

Extra mounts are declared in `/mount/Data2/<user>/mounts.conf` and injected
at launch time via an ephemeral compose override. See [MOUNTS.md](MOUNTS.md).

---

## UID/GID Alignment

Files written to bind-mounted directories must be owned by the correct host
user to remain writable from the host. This is handled in two places:

1. **entrypoint-user.sh** (container boot): creates an OS user and group
   with UID=`HOST_UID` and GID=`HOST_GID` (passed via compose environment).

2. **startup.sh** (after entrypoint): checks if `/root/workspace` is
   already owned by `HOST_UID:HOST_GID` and runs `chown -R` only when
   the ownership has drifted, avoiding an expensive recursive chown on
   every container restart.

---

## GPU Support

The image uses the CUDA **runtime** image, so `nvidia-smi` and CUDA runtime
libraries are available but `nvcc` is not. GPU access inside the container
requires:

- Host: NVIDIA driver >= 525 (CUDA 12.8 compatible)
- Host: NVIDIA Container Toolkit (`nvidia-ctk`, `nvidia-container-runtime`)
- Compose: `runtime: nvidia` + `deploy.resources.reservations.devices`

Both `runtime: nvidia` and `deploy.resources.reservations` are set in
`compose.yaml` for compatibility with both `docker compose` and Docker
Swarm modes.
