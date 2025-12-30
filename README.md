<div align="center">

# 🐦‍⬛ RAVEN

### <strong>R</strong>emote <strong>A</strong>ccess <strong>V</strong>irtual <strong>E</strong>nvironment <strong>N</strong>ode

[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04%20%7C%20Configurable-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![noVNC](https://img.shields.io/badge/noVNC-1.6.0-orange)](https://novnc.com/)
[![CUDA](https://img.shields.io/badge/CUDA-Auto%20Detected%20%2F%20Bindable-76B900?logo=nvidia&logoColor=white)](https://developer.nvidia.com/cuda-toolkit)

**A high-performance, containerized Ubuntu desktop environment with browser-based access, GPU acceleration, and auto-detected CUDA support**

[Features](#-features) • [Quick Start](#-quick-start) • [Architecture](#%EF%B8%8F-architecture) • [GPU Support](#-gpu-support) • [Troubleshooting](#-troubleshooting)

</div>

---

## 📖 Overview

**RAVEN** is a containerized desktop environment built on Ubuntu LTS versions (configurable). It provides a complete LXDE desktop accessible through your web browser via noVNC, eliminating the need for VNC client software. Perfect for remote development, CI/CD GUI testing, cloud workstations, and educational environments.

### What's New in?

- ✨ **Auto-Detected CUDA** - CUDA environment automatically detected and configured on startup
- 🎯 **Persistent GPU Support** - CUDA paths persist across all interactive shells and processes
- 📦 **Flexible Base Images** - Easy switching between Ubuntu 20.04, 22.04, and 24.04
- 🚀 **Enhanced Volume Bindings** - Better GPU and shared memory mounting examples
- 📝 **Improved Documentation** - Comprehensive GPU setup and troubleshooting guides

### Why RAVEN?

- ✅ **Zero Client Setup** - Access full desktop from any browser
- ✅ **Docker Native** - Designed specifically for container orchestration
- ✅ **GPU Ready** - CUDA auto-detection with persistent environment variables
- ✅ **Developer Focused** - Python (Conda + UV), Brave Browser, and build tools
- ✅ **Production Stable** - Process supervision with automatic recovery
- ✅ **Lightweight** - Optimized resource usage with LXDE

---

## 🚀 Features

### Desktop Environment

- 🖥️ **Full Linux Desktop** powered by **LXDE** (Openbox + PCManFM) for a lightweight, responsive GUI
- 🎨 **Modern Theming** with Arc-Dark theme, Papirus icons, and Ubuntu wallpapers
- 🪟 **Window Management** via Openbox for smooth multi-window operations
- 📁 **File Manager** with PCManFM for intuitive file operations

### Remote Access

- 🌐 **Browser-Based Access** via noVNC (v1.6.0) - no VNC client required
- 🔒 **Password Protected** VNC sessions with configurable authentication
- 🔄 **Nginx Reverse Proxy** for clean HTTP access on port 80
- 📱 **Cross-Platform** - works on desktop, tablet, and mobile browsers

### Development Tools

- 🦁 **Brave Browser** for secure web development and testing
- 🐍 **Miniconda3** for Python environment management
- ⚡ **uv Package Manager** for blazing-fast Python package installation
- 🛠️ **Build Tools** including GCC, G++, CMake, Ninja, and Git

### System Features

- 🎮 **GPU Support** with automatic NVIDIA CUDA detection and configuration
- 🔊 **Audio System** via ALSA (Advanced Linux Sound Architecture)
- 📦 **Multi-Stage Build** for optimized image size
- 🔄 **Process Supervision** with automatic service recovery
- 📊 **Comprehensive Logging** for all services

---

## 🏗️ Architecture

RAVEN uses a **decomposed desktop architecture** managed by Supervisor to ensure stability and automatic recovery. Unlike traditional LXDE setups that use `startlxde`, RAVEN launches each component independently to prevent Docker PID conflicts.

### Service Stack

| Priority | Service | Port | Description |
| --------- | --------- | ------ | ------------- |
| **10** | **Xvfb** | - | Virtual X11 display server (headless framebuffer) |
| **20** | **Openbox** | - | Lightweight window manager for UI rendering |
| **21** | **LXPanel** | - | Taskbar and application menu |
| **22** | **PCManFM** | - | File manager, desktop icons, and wallpaper handler |
| **30** | **x11vnc** | 5900 | VNC server exposing the virtual display |
| **40** | **Websockify** | 6080 | WebSocket bridge for browser compatibility |
| **50** | **Nginx** | 80 | HTTP reverse proxy serving noVNC interface |

### Data Flow

```HTTP
Browser (HTTP:80) → Nginx → Websockify (WebSocket:6080) → x11vnc (VNC:5900) → Xvfb (Display:0) → Desktop Apps
```

---

## 📦 Quick Start

### Prerequisites

- **Docker** 20.10+ installed on your host system
- (Optional) **NVIDIA Container Toolkit** for GPU acceleration
- **4GB+ RAM** recommended for optimal performance
- **Modern web browser** (Chrome, Firefox, Safari, Edge)

### 1️⃣ Get the Image

You have two options to get the RAVEN Docker image:

#### Option A: Pull Pre-built Image (Recommended for Quick Start)

```bash
# Pull the latest stable image from Docker Hub
docker pull sarkarsaswata001/raven_personal:v0

# Tag it for convenience (optional)
docker tag sarkarsaswata001/raven_personal:v0 raven-desktop:latest
```

**Download time:** depending on your connection speed.

> ✨ **Pre-built image includes:** Ubuntu 22.04 LTS, All dependencies, Brave Browser, Miniconda, UV and development tools pre-configured and ready to use.

#### Option B: Build from Source (For Customization)

```bash
# Clone the repository
git clone https://github.com/yourusername/raven.git
cd raven

# Build the Docker image
docker build -t raven-desktop:latest .
```

**Build time:** ~10-15 minutes depending on your connection speed.

> 🔧 **Build from source if you need to:**
>
> - Customize the Ubuntu base version
> - Modify installed packages
> - Add custom configurations
> - Use different desktop environments

### 2️⃣ Run the Container

#### Basic Usage

```bash
docker run -d --name raven \
  -p 80:80 \
  -p 5900:5900 \
  -e VNC_PASSWORD=YourSecurePassword123 \
  -e RESOLUTION=1920x1080 \
  --shm-size=2g \
  sarkarsaswata001/raven_personal:v0
```

#### With GPU Support (Recommended for CUDA)

```bash
docker run -d --name raven \
  --gpus all \
  -p 80:80 \
  -p 5900:5900 \
  -e VNC_PASSWORD=YourSecurePassword123 \
  -e RESOLUTION=1920x1080 \
  --shm-size=2g \
  sarkarsaswata001/raven_personal:v0
```

**CUDA will be auto-detected** and available in all interactive shells:

```bash
docker exec -it raven bash
nvcc --version  # CUDA Compiler available!
python -c "import torch; print(torch.cuda.is_available())"  # Works!
```

#### With GPU + Host CUDA Binding (Advanced)

For access to host CUDA libraries:

```bash
docker run -d --name raven \
  --gpus all \
  -p 80:80 \
  -p 5900:5900 \
  -e VNC_PASSWORD=YourSecurePassword123 \
  -e RESOLUTION=1920x1080 \
  --shm-size=2g \
  -v /usr/local/cuda-12.8:/usr/local/cuda-12.8 \
  -v /dev/shm:/dev/shm \
  sarkarsaswata001/raven_personal:v0
```

#### With Audio Support

```bash
docker run -d --name raven \
  -p 80:80 \
  -p 5900:5900 \
  -e VNC_PASSWORD=YourSecurePassword123 \
  -e RESOLUTION=1920x1080 \
  -e ALSADEV=hw:0,0 \
  --device /dev/snd \
  --shm-size=2g \
  sarkarsaswata001/raven_personal:v0
```

#### With Persistent Workspace

```bash
docker run -d --name raven \
  -p 80:80 \
  -p 5900:5900 \
  -e VNC_PASSWORD=YourSecurePassword123 \
  -e RESOLUTION=1920x1080 \
  -v $(pwd)/workspace:/workspace \
  --shm-size=2g \
  sarkarsaswata001/raven_personal:v0
```

#### Full Example: GPU + Audio + Workspace + Custom Ports

```bash
docker run -it --name raven \
  --gpus all \
  -p 8000:80 \
  -p 9090:5900 \
  --device /dev/snd \
  -e ALSADEV=hw:2,0 \
  -e VNC_PASSWORD=YourSecurePassword \
  -e RESOLUTION=1920x1080 \
  -v /dev/shm:/dev/shm \
  -v /usr/local/cuda-12.8:/usr/local/cuda-12.8 \
  -v $(pwd)/workspace:/workspace \
  --shm-size=2g \
  sarkarsaswata001/raven_personal:v0
```

### 3️⃣ Access the Desktop

#### Web Browser (Recommended)

Open your browser and navigate to:

```
http://localhost
```

Password: `<your VNC_PASSWORD>`

#### VNC Client (Advanced)

Use any VNC client to connect:

```
vnc://localhost:5900
Password: <your VNC_PASSWORD>
```

> **⚠️ Important:** Set `--shm-size` to at least **2g** to prevent browser crashes. Browsers use shared memory for rendering.

---

## ⚙️ Configuration

### Environment Variables

| Variable | Default | Description |
| --- | --- | --- |
| `VNC_PASSWORD` | `changeme` | Password for VNC authentication |
| `RESOLUTION` | `1920x1080` | Virtual screen resolution (WxH) |
| `DISPLAY` | `:0` | X11 display identifier |

### Common Resolutions

```bash
# Full HD
-e RESOLUTION=1920x1080

# HD
-e RESOLUTION=1280x720

# 4K (requires more resources)
-e RESOLUTION=3840x2160

# Ultrawide
-e RESOLUTION=2560x1080
```

### Port Mapping

| Container Port | Protocol | Purpose |
| ------------- | --------- | -------- |
| `80` | HTTP | noVNC web interface |
| `5900` | VNC | Raw VNC protocol |
| `6080` | WebSocket | noVNC WebSocket bridge |

---

## 🎮 GPU Support

### CUDA Support

RAVEN supports CUDA in two primary ways:

#### Option 1: Auto-Detection (Container CUDA - Recommended)

CUDA is automatically detected if installed inside the container during startup:

```bash
docker run -d --name raven \
  --gpus all \
  -p 80:80 \
  -p 5900:5900 \
  -e VNC_PASSWORD=YourPassword \
  -e RESOLUTION=1920x1080 \
  --shm-size=2g \
  sarkarsaswata001/raven_personal:v0
```

**How it works:**
1. `startup.sh` searches for CUDA installations in `/usr/local/cuda-*`
2. Found CUDA paths are configured persistently in `/etc/profile.d/cuda.sh`
3. All interactive shells automatically source this configuration
4. `nvcc` and CUDA tools are immediately available

**Verify auto-detection:**
```bash
docker exec -it raven bash
nvcc --version  # Should work!
echo $CUDA_HOME
```

#### Option 2: Host CUDA Binding (Advanced)

**⚠️ Important:** Host CUDA binding requires additional configuration to work correctly.

When binding your host's CUDA installation, you need to:
1. Bind the CUDA directory
2. Also bind the symlink (if it exists)
3. Ensure proper library paths

**Method A: With CUDA Symlink (Recommended)**

```bash
# First, find your CUDA installation
which nvcc
# Output: /usr/local/cuda-12.8/bin/nvcc

# Check if symlink exists
ls -la /usr/local/cuda
# If it points to cuda-12.8, great!

# Run container with both bindings
docker run -it --name raven \
  --gpus all \
  -p 8000:80 \
  -p 9090:5900 \
  -e VNC_PASSWORD=test \
  -e RESOLUTION=1920x1080 \
  -v /usr/local/cuda-12.8:/usr/local/cuda-12.8:ro \
  -v /usr/local/cuda:/usr/local/cuda:ro \
  -v /dev/shm:/dev/shm \
  --shm-size=2g \
  sarkarsaswata001/raven_personal:v0
```

**Method B: With Device Binding and Read-Only Mount**

```bash
docker run -it --name raven \
  --gpus all \
  --device /dev/nvidiactl \
  --device /dev/nvidia0 \
  --device /dev/nvidia1 \
  -p 8000:80 \
  -p 9090:5900 \
  -e VNC_PASSWORD=test \
  -e RESOLUTION=1920x1080 \
  -v /usr/local/cuda-12.8:/usr/local/cuda-12.8:ro \
  -v /dev/shm:/dev/shm \
  --shm-size=2g \
  sarkarsaswata001/raven_personal:v0
```

#### Troubleshooting Host CUDA Binding

**Problem: `nvcc: command not found` after binding CUDA**

Check if the CUDA path is correctly configured:

```bash
docker exec -it raven bash

# Check if CUDA directory is mounted
ls /usr/local/cuda-12.8/bin/ | grep nvcc

# If empty, the mount failed. Verify on your host:
# On HOST system:
ls -la /usr/local/cuda-12.8/bin/nvcc

# Check environment variables in container
echo $CUDA_HOME
echo $PATH | grep cuda

# If empty, manually source the profile
source /etc/profile.d/cuda.sh
echo $CUDA_HOME
```

**Problem: CUDA mounted but libraries not found**

```bash
# Inside container
export CUDA_HOME=/usr/local/cuda-12.8
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH

# Now test
nvcc --version
nvidia-smi
```

**Solution: Create CUDA symlink in container**

If your host has `/usr/local/cuda-12.8` but no `/usr/local/cuda` symlink, create it:

```bash
docker exec -it raven bash

# Create symlink inside container
ln -s /usr/local/cuda-12.8 /usr/local/cuda

# Verify
nvcc --version
```

#### Verifying CUDA Installation

**For both auto-detection and binding:**

```bash
docker exec -it raven bash -c "
  echo '=== CUDA Home ===' && echo \$CUDA_HOME &&
  echo '=== nvcc ===' && nvcc --version &&
  echo '=== GPU Devices ===' && nvidia-smi &&
  echo '=== Python GPU ===' && python -c 'import torch; print(torch.cuda.is_available())'
"
```

#### Common CUDA Paths

| CUDA Version | Directory | Has nvcc |
|-------------|-----------|----------|
| **12.8** | `/usr/local/cuda-12.8` | ✅ Yes |
| **12.x** | `/usr/local/cuda-12` | ✅ Yes |
| **11.8** | `/usr/local/cuda-11.8` | ✅ Yes |
| **Symlink** | `/usr/local/cuda` | ✅ Yes (points to active) |

#### When to Use Each Method

| Scenario | Method | Reason |
|----------|--------|--------|
| **Quick Testing** | Auto-Detection | No host setup needed; just works |
| **Exact Host Version** | Host Binding | Ensures CUDA version matches host exactly |
| **Production** | Auto-Detection | More stable; fewer mount issues |
| **Development** | Either | Depends on your testing needs |

#### Why Auto-Detection is Recommended

✅ **Auto-Detection advantages:**
- No bind mounts needed
- Works consistently across shells
- Persistent environment configuration
- No symlink issues
- Easier troubleshooting

❌ **Host Binding challenges:**
- Requires correct symlink setup
- Library path mismatches possible
- Mount timing issues
- More complex troubleshooting

#### Manual CUDA Setup in Container

If auto-detection doesn't find CUDA, install it manually:

```bash
docker exec -it raven bash

# Update package manager
apt-get update

# Install CUDA toolkit
apt-get install -y cuda-toolkit-12-8

# Add to path permanently
echo "export PATH=/usr/local/cuda-12.8/bin:\$PATH" >> /root/.bashrc
echo "export LD_LIBRARY_PATH=/usr/local/cuda-12.8/lib64:\$LD_LIBRARY_PATH" >> /root/.bashrc

# Source and verify
source /root/.bashrc
nvcc --version
```
