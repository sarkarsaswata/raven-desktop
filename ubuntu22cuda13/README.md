# Ubuntu 22.04 Desktop Environment with noVNC and CUDA Support

A complete containerized Ubuntu 22.04 LXDE desktop environment with VNC/noVNC remote access, NVIDIA CUDA 13.0 support, and a full suite of desktop applications. Access your desktop environment through any modern web browser - no VNC client required!

## 🌟 Features

### Desktop Environment

- **LXDE Desktop** - Lightweight, fast, and user-friendly
- **Browser Access** - noVNC web interface (no client installation needed)
- **Full VNC Support** - Standard VNC protocol on port 5900
- **Multiple Applications** - Pre-installed productivity tools

### GPU & Development

- **NVIDIA CUDA 13.0** - Full CUDA toolkit for GPU computing
- **Compiler Tools** - GCC, G++, CMake, Ninja build system

### Pre-installed Applications

- **Browsers**: Firefox, Brave
- **Editors**: Gedit, Mousepad, Nano, Vim
- **Terminal**: LXTerminal with bash completion
- **File Manager**: PCManFM with desktop integration
- **System Monitor**: Gnome System Monitor
- **Utilities**: Calculator, Image Viewer, Archive Manager
- **Tools**: htop, tmux, git, curl, wget

## 📋 Requirements

- Docker Engine 20.10+
- NVIDIA Docker runtime (for GPU support)
- 4GB+ RAM recommended
- 10GB+ disk space

### For GPU Support (Optional)

Make sure you have the NVIDIA Container Toolkit installed. Follow the instructions here: [NVIDIA Container Toolkit Installation](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)

## 🚀 Quick Start

### Build the Image

```bash
docker build -t ubuntu-desktop-vnc .
```

### Run the Container

**Basic Usage with GPU Support:**

```bash
docker run -d --name my_desktop \
  --gpus all \
  --device /dev/snd \
  -p 8080:80 -p 9090:5900 \
  -e ALSADEV=hw:2,0 \
  -e RESOLUTION=1920x1080 \
  -e VNC_PASSWORD=my_secure_password \
  -v /dev:/dev \
  -v /dev/shm:/dev/shm \
  -v /dev/bus/usb:/dev/bus/usb \
  -v /run/udev:/run/udev:ro \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  -v ${path_to_host_workspace}:/workspace \
  ubuntu-desktop-vnc
```

## ⚙️ Environment Variables

| Variable | Default | Description |
| ---------- | --------- | ------------- |
| `VNC_PASSWORD` | `changeme` | VNC access password (⚠️ **Change this!**) |
| `RESOLUTION` | `1920x1080` | Desktop resolution (e.g., `1280x720`, `2560x1440`) |
| `DISPLAY` | `:0` | X11 display identifier |
| `HOST_UID` | `1000` | User ID for `/workspace` ownership |
| `HOST_GID` | `1000` | Group ID for `/workspace` ownership |
| `HOST_USER` | `dev` | Username for workspace access |
| `CUDA_VERSION` | (auto) | Specific CUDA version to use |

## 🐛 Troubleshooting

### Desktop Not Loading

```bash
# Check supervisor logs
docker logs ubuntu-desktop

# Check individual service logs
docker exec ubuntu-desktop cat /var/log/supervisor/xvfb.err.log
docker exec ubuntu-desktop cat /var/log/supervisor/x11vnc.err.log
```

### Black Screen

```bash
# Restart the container
docker restart ubuntu-desktop

# Or rebuild with no cache
docker build --no-cache -t ubuntu-desktop-vnc .
```

### Clipboard Not Working

The clipboard synchronization is enabled by default. If issues persist:

```bash
# Check autocutsel service
docker exec ubuntu-desktop cat /var/log/supervisor/autocutsel.err.log

# Restart container
docker restart ubuntu-desktop
```

### GPU Not Detected

```bash
# Verify NVIDIA runtime
docker run --rm --gpus all nvidia/cuda:13.0.0-base-ubuntu22.04 nvidia-smi

# Check CUDA in container
docker exec ubuntu-desktop nvidia-smi
docker exec ubuntu-desktop nvcc --version
```

### Performance Issues

- Reduce resolution: `-e RESOLUTION=1280x720`
- Allocate more resources in Docker settings
- Close unnecessary applications in the desktop

## 🔐 Security Considerations

⚠️ **Important Security Notes:**

1. **Change Default Password**: Always set a strong `VNC_PASSWORD`
2. **Network Exposure**: Don't expose ports to public internet without VPN/firewall
3. **Container Isolation**: Consider using Docker networks for isolation
4. **User Permissions**: Use `HOST_UID` and `HOST_GID` for proper file ownership

### Secure Deployment Example

```bash
# Run on localhost only
docker run -d \
  -p 127.0.0.1:6080:80 \
  -p 127.0.0.1:5900:5900 \
  -e VNC_PASSWORD=$(openssl rand -base64 12) \
  ubuntu-desktop-vnc

# Access via SSH tunnel
ssh -L 6080:localhost:6080 user@server
```

## 📝 Docker Compose Example

```yaml
version: '3.8'

services:
  ubuntu-desktop:
    build: .
    ports:
      - "6080:80"
      - "5900:5900"
    environment:
      - VNC_PASSWORD=your_secure_password
      - RESOLUTION=1920x1080
      - HOST_UID=1000
      - HOST_GID=1000
    volumes:
      - ./workspace:/workspace
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    restart: unless-stopped
```

Run with:

```bash
docker-compose up -d
```

## 👤 Maintainer

**Saswata Sarkar**  

- Email: mailto:sarkarsaswata01@gmail.com

## 🙏 Acknowledgments

- [NVIDIA CUDA Base Images](https://hub.docker.com/r/nvidia/cuda)
- [noVNC Project](https://github.com/novnc/noVNC)
- [LXDE Desktop Environment](https://www.lxde.org/)
- [Astral UV Package Manager](https://docs.astral.sh/uv/)

## 📊 System Architecture

```bash
┌─────────────────────────────────────────┐
│         Browser (Port 80/6080)          │
└───────────────┬─────────────────────────┘
                │
        ┌───────▼────────┐
        │     Nginx      │
        └───────┬────────┘
                │
        ┌───────▼────────┐
        │  Websockify    │ (WebSocket Bridge)
        └───────┬────────┘
                │
        ┌───────▼────────┐
        │    x11vnc      │ (VNC Server)
        └───────┬────────┘
                │
        ┌───────▼────────┐
        │     Xvfb       │ (Virtual Display :0)
        └───────┬────────┘
                │
    ┌───────────┴───────────┐
    │                       │
┌───▼───┐              ┌────▼────┐
│ LXDE  │              │  Apps   │
│Desktop│              │(Firefox)│
└───────┘              └─────────┘
```

---
