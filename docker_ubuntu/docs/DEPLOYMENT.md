# Deployment Guide

**docker_ubuntu — Step-by-step guide for admins deploying multi-user containers**

---

## Host Prerequisites

All items must be satisfied before building or launching containers.

### System Requirements

| Requirement | Minimum | Check Command |
|-------------|---------|---------------|
| Ubuntu | 22.04 LTS | `lsb_release -rs` |
| NVIDIA driver | 525+ (CUDA 12.8 compat.) | `nvidia-smi` |
| Docker | 24.0+ | `docker --version` |
| Docker Compose | v2 (plugin) | `docker compose version` |
| NVIDIA Container Toolkit | installed | `nvidia-ctk --version` |
| Free disk space | 15 GB for image + per-user workspaces | `df -h /mount/Data2` |

### Verify GPU is Accessible in Docker

```bash
docker run --rm --runtime=nvidia nvidia/cuda:12.8.0-runtime-ubuntu22.04 nvidia-smi
```

Expected output: GPU table showing your GPU model and driver version.

If this fails, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md#gpu-not-visible).

### Verify /mount/Data2 Exists and is Writable

```bash
df -h /mount/Data2
ls -la /mount/Data2
```

User workspace directories will be created at `/mount/Data2/<username>/`.

---

## Build the Docker Image

Navigate to the `docker_ubuntu/` directory and run:

```bash
cd /home/saswata/raven-desktop/docker_ubuntu
./build.sh
```

Build time is approximately 15-25 minutes on first run. Subsequent builds
use Docker layer cache and are significantly faster if only the scripts change.

Verify the image was created:

```bash
docker images local/ubuntu-desktop
```

Expected output:

```
REPOSITORY             TAG       IMAGE ID       CREATED         SIZE
local/ubuntu-desktop   latest    <id>           <time>          ~5.5GB
```

---

## Launch a Container per User

### Basic Launch

```bash
./launch_user.sh <username> <http_port> <vnc_port>
```

Example for three concurrent users:

```bash
./launch_user.sh alice   8080 9090
./launch_user.sh bob     8081 9091
./launch_user.sh charlie 8082 9092
```

Each call will:

1. Validate arguments and prompt for a VNC password
2. Read the caller's `id -u` and `id -g` for UID/GID alignment
3. Create `/mount/Data2/<username>/workspace` if it doesn't exist
4. Create a template `/mount/Data2/<username>/mounts.conf` if it doesn't exist
5. Parse `mounts.conf` and generate an ephemeral compose override at `/tmp/<username>_compose_override.yml`
6. Run `docker compose -p <username>_project -f compose.yaml [-f override] up -d`
7. Print access URLs and clean up the temporary override file

### Port Assignment

Choose non-overlapping ports for each user. Standard suggestions:

| User | HTTP port | VNC port |
|------|-----------|----------|
| user1 | 8080 | 9090 |
| user2 | 8081 | 9091 |
| user3 | 8082 | 9092 |
| user4 | 8083 | 9093 |

Ports below 1024 require root. Avoid ports already in use on the host
(`ss -tlnp | grep <port>`).

---

## Access the Desktop

### Browser (noVNC) — Recommended

```
http://<host-ip>:<http_port>
```

Enter the VNC password when prompted. The LXDE desktop loads in the browser.
No client software required. Works from any device with a modern browser.

### VNC Client (TightVNC, RealVNC, Remmina, etc.)

```
<host-ip>:<vnc_port>
```

Password: same as the one entered at launch.

### Shell Access (no desktop needed)

```bash
docker exec -it <username>_desktop bash
```

---

## Stop and Remove Containers

### Stop a single user's container

```bash
docker compose -p <username>_project down
```

### Stop without removing (preserves container state)

```bash
docker compose -p <username>_project stop
```

### Restart a stopped container

```bash
docker compose -p <username>_project start
```

### List all running desktop containers

```bash
docker ps --filter "name=_desktop"
```

---

## Update Workflow

When the image needs to be rebuilt (e.g., after updating startup scripts):

```bash
# 1. Stop all running containers
docker ps --filter "name=_desktop" --format "{{.Names}}" | \
    sed 's/_desktop//' | \
    xargs -I{} docker compose -p {}_project down

# 2. Rebuild the image
./build.sh

# 3. Re-launch each user
./launch_user.sh alice 8080 9090
./launch_user.sh bob   8081 9091
```

User workspaces at `/mount/Data2/<username>/workspace` are preserved on the
host and reattached automatically on the next launch.

---

## Environment Variables Reference

The following variables are passed from the host into each container at launch.
They are set by `launch_user.sh` and consumed by `compose.yaml` and the
startup scripts.

| Variable | Set by | Default | Purpose |
|----------|--------|---------|---------|
| `VNC_PASSWORD` | launch prompt | — | VNC authentication |
| `HOST_UID` | `id -u` on host | 1000 | File ownership in workspace |
| `HOST_GID` | `id -g` on host | 1000 | File ownership in workspace |
| `HTTP_PORT` | launch arg | 8080 | Host port to container:80 |
| `VNC_PORT` | launch arg | 9090 | Host port to container:5900 |
| `HOST_WORKSPACE` | `/mount/Data2/<user>/workspace` | — | Bind mount source |
| `CONTAINER_NAME` | `<user>_desktop` | `desktop_container` | Container name |
| `DISPLAY` | compose.yaml | `:0` | X11 display ID |
| `RESOLUTION` | compose.yaml | `1920x1080` | Virtual framebuffer size |
| `NVIDIA_VISIBLE_DEVICES` | compose.yaml | `all` | GPU allocation |

---

## Verification Checklist

After launching a container, confirm the following:

```bash
USERNAME=alice
PORT=8080

# Container is running
docker ps | grep "${USERNAME}_desktop"

# noVNC web UI responds
curl -s -o /dev/null -w "%{http_code}" http://localhost:${PORT}/
# Expected: 200

# GPU visible inside the container
docker exec "${USERNAME}_desktop" nvidia-smi

# Workspace is bind-mounted and owned by correct UID
docker exec "${USERNAME}_desktop" stat -c "%U %G %n" /root/workspace

# VS Code available
docker exec "${USERNAME}_desktop" code --version

# Supervisor is managing all services
docker exec "${USERNAME}_desktop" supervisorctl status
```
