# docker_ubuntu

Minimal Ubuntu 22.04 desktop container with LXDE, browser-accessible noVNC, NVIDIA GPU support, VS Code, and Brave. Designed for general-purpose interactive GPU workloads. No Isaac Sim, no CUDA build tools.

| Property     | Value                                    |
|--------------|------------------------------------------|
| Base image   | `nvidia/cuda:12.8.0-runtime-ubuntu22.04` |
| Desktop      | LXDE + Openbox                           |
| Remote access| noVNC (browser) + raw VNC port 5900      |
| GPU          | NVIDIA runtime (no nvcc)                 |
| Python       | 3.10 + `uv`                              |
| Workspace    | `/root/workspace` (bind mount)           |
| Image size   | ~5-6 GB                                  |

## Quick Start

```bash
# 1. Build
./build.sh

# 2. Launch (prompts for VNC password)
./launch_user.sh alice 8080 9090

# 3. Open browser
http://<host-ip>:8080
```

Full documentation is in the [docs/](docs/) directory:

| Doc | Purpose |
|-----|---------|
| [docs/QUICK_START.md](docs/QUICK_START.md) | Fastest path to a running container |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | Host prerequisites, build, launch, access |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Image layers, process stack, startup sequence |
| [docs/MOUNTS.md](docs/MOUNTS.md) | `mounts.conf` format and per-user volume strategy |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common failures and fixes |
