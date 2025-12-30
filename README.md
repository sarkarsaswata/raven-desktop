<div align="center">

# 🦅 RAVEN v2

### Remote Access Virtual Environment Node

[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04%20%7C%20Configurable-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![noVNC](https://img.shields.io/badge/noVNC-1.6.0-orange)](https://novnc.com/)
[![CUDA](https://img.shields.io/badge/CUDA-Auto%20Detected-76B900?logo=nvidia&logoColor=white)](https://developer.nvidia.com/cuda-toolkit)

**A high-performance, containerized Ubuntu desktop environment with browser-based access, GPU acceleration, and auto-detected CUDA support**

[Features](#-features) • [Quick Start](#-quick-start) • [Architecture](#%EF%B8%8F-architecture) • [GPU Support](#-gpu-support) • [Troubleshooting](#-troubleshooting)

</div>

---

## 📖 Overview

**RAVEN v2** is a containerized desktop environment built on Ubuntu LTS versions (configurable). It provides a complete LXDE desktop accessible through your web browser via noVNC, eliminating the need for VNC client software. Perfect for remote development, CI/CD GUI testing, cloud workstations, and educational environments.

### What's New in v2?

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

### CUDA Auto-Detection (v2 Feature)

RAVEN v2 automatically detects CUDA installations on startup and configures the environment. This means `nvcc` and CUDA tools are available immediately in all interactive shells.

#### How It Works

1. **Startup Detection** - When the container starts, `startup.sh` searches for CUDA installations
2. **Persistent Configuration** - CUDA paths are written to `/etc/profile.d/cuda.sh`
3. **Universal Availability** - All future shells automatically source the CUDA configuration

#### Verifying CUDA Setup

```bash
# Enter the container
docker exec -it raven bash

# Check CUDA compiler
nvcc --version

# Check CUDA in Python
python -c "import torch; print(torch.cuda.is_available())"

# List GPU devices
nvidia-smi
```

#### Common CUDA Paths

| CUDA Version | Path |
|-------------|------|
| **12.8** | `/usr/local/cuda-12.8` |
| **12.x** | `/usr/local/cuda-12` |
| **11.8** | `/usr/local/cuda-11.8` |
| **Symlink** | `/usr/local/cuda` |

#### Installing CUDA in Container

If your host CUDA isn't auto-detected:

```bash
docker exec -it raven bash

# Install CUDA toolkit
apt-get update
apt-get install -y cuda-toolkit-12-8

# Or bind-mount your host CUDA
# (see examples in Quick Start)
```

#### Host GPU Passthrough

To use your host's GPU capabilities:

```bash
docker run -d --name raven \
  --gpus all \
  --device /dev/nvidiactl \
  --device /dev/nvidia0 \
  -v /usr/local/cuda-12.8:/usr/local/cuda-12.8:ro \
  sarkarsaswata001/raven_personal:v0
```

---



## 📂 Repository Structure

```bash
raven/
├── Dockerfile              # Multi-stage image definition
├── startup.sh              # Container entrypoint script
├── supervisord.conf        # Process management configuration
├── README.md               # This file
├── LICENSE                 # Apache 2.0 license
└── NOTICE                  # Third-party attributions
```

### Key Files

- **[Dockerfile](Dockerfile)** - Defines system dependencies, GUI stack, and development tools
- **[startup.sh](startup.sh)** - Initializes D-Bus, themes, VNC credentials, and launches supervisor
- **[supervisord.conf](supervisord.conf)** - Orchestrates lifecycle of all desktop services

---

## 🔧 Advanced Usage

### Managing the Container

```bash
# Start the container
docker start raven

# Stop the container
docker stop raven

# View logs
docker logs -f raven

# Access shell inside container
docker exec -it raven bash

# Remove container
docker rm -f raven
```

### Inspecting Service Logs

All services log to `/var/log/supervisor/`:

```bash
# List all service logs
docker exec raven ls /var/log/supervisor/

# View specific service logs
docker exec raven cat /var/log/supervisor/xvfb.err.log
docker exec raven cat /var/log/supervisor/x11vnc.err.log
docker exec raven cat /var/log/supervisor/nginx.err.log
```

### Installing Additional Software

```bash
# Access container shell
docker exec -it raven bash

# Install packages with apt
apt-get update
apt-get install -y <package-name>

# Install Python packages with conda
conda install <package-name>

# Install Python packages with uv
uv pip install <package-name>
```

### Persisting Changes

To save changes made inside the container:

```bash
# Commit container to new image
docker commit raven raven-desktop:custom

# Or use volumes for data persistence
docker run -v /host/path:/workspace raven-desktop:latest
```

### Customizing the Ubuntu Base Image

RAVEN is designed to be compatible with different Ubuntu versions. You can easily switch the base image to match your requirements or organizational standards.

#### Why Change the Base Image?

- **LTS Compatibility**: Use Ubuntu 20.04 LTS for longer support cycles (until 2025)
- **Latest Features**: Switch to Ubuntu 24.04 LTS for newer packages and kernel features
- **Security Requirements**: Align with corporate security policies requiring specific OS versions
- **Package Availability**: Some packages may only be available or stable on certain Ubuntu releases

#### How to Change the Base Image

1. **Open the Dockerfile** and locate the base image declaration:

   ```dockerfile
   FROM ubuntu:22.04
   ```

2. **Replace with your desired Ubuntu version:**

   ```dockerfile
   # For Ubuntu 20.04 LTS (Focal Fossa)
   FROM ubuntu:20.04
   
   # For Ubuntu 24.04 LTS (Noble Numbat)
   FROM ubuntu:24.04
   
   # For specific point releases
   FROM ubuntu:22.04.3
   
   # For Debian-based alternative
   FROM debian:12-slim
   ```

3. **Rebuild the image** with your changes:

   ```bash
   docker build -t raven-desktop:ubuntu20.04 .
   ```

4. **Test the new image** to ensure all services start correctly:

   ```bash
   docker run -d --name raven-test \
     -p 8080:80 \
     -e VNC_PASSWORD=test123 \
     raven-desktop:ubuntu20.04
   
   # Check service status
   docker exec raven-test supervisorctl status
   ```

#### Important Considerations

> **⚠️ Package Compatibility**: Different Ubuntu versions may have different package versions or names. You may need to adjust the Dockerfile if:
>
> - Package names have changed between releases
> - Certain packages are not available in repositories
> - Dependencies require different versions

**Common adjustments needed:**

| Ubuntu Version | Potential Changes |
| --------- | ------------- |
| **20.04** | Python 3.8 by default; some newer packages unavailable |
| **22.04** | Recommended baseline; best package availability |
| **24.04** | Latest features; may require testing for stability |

#### Example: Building for Multiple Versions

```bash
# Build for Ubuntu 20.04 LTS
sed -i 's/FROM ubuntu:22.04/FROM ubuntu:20.04/' Dockerfile
docker build -t raven-desktop:20.04 .

# Build for Ubuntu 24.04 LTS
sed -i 's/FROM ubuntu:20.04/FROM ubuntu:24.04/' Dockerfile
docker build -t raven-desktop:24.04 .

# Restore original
git checkout Dockerfile
```

#### Using Build Arguments (Advanced)

For a more flexible approach, you can parameterize the Ubuntu version:

```dockerfile
# Modify Dockerfile to accept build argument
ARG UBUNTU_VERSION=22.04
FROM ubuntu:${UBUNTU_VERSION}
```

Then build with:

```bash
docker build --build-arg UBUNTU_VERSION=20.04 -t raven-desktop:20.04 .
docker build --build-arg UBUNTU_VERSION=24.04 -t raven-desktop:24.04 .
```

#### Verification Checklist

After changing the base image, verify:

- ✅ All packages install without errors
- ✅ X11/Xvfb starts successfully
- ✅ Desktop environment renders correctly
- ✅ VNC/noVNC connections work
- ✅ GPU detection functions (if applicable)

```bash
# Quick verification script
docker exec raven-test bash -c "
  echo '=== OS Version ===' && cat /etc/os-release &&
  echo '=== Services ===' && supervisorctl status &&
  echo '=== Display ===' && echo \$DISPLAY
"
```

---

## 🐛 Troubleshooting

### Issue: Black Screen in Browser

**Symptoms:** Browser connects but shows only black screen

**Solutions:**

1. Check if Xvfb is running:

   ```bash
   docker exec raven ps aux | grep Xvfb
   ```

2. Verify desktop components started:

   ```bash
   docker exec raven supervisorctl status
   ```

3. Check PCManFM logs:

   ```bash
   docker exec raven cat /var/log/supervisor/pcmanfm.err.log
   ```

### Issue: Browser Crashes or Freezes

**Symptoms:** Brave/Chromium crashes with "Aw, Snap!" errors

**Solution:** Increase shared memory:

```bash
docker run --shm-size=2g ...
```

### Issue: Cannot Connect to VNC

**Symptoms:** Connection refused or timeout errors

**Solutions:**

1. Verify ports are exposed:

   ```bash
   docker port raven
   ```

2. Check x11vnc is running:

   ```bash
   docker exec raven supervisorctl status x11vnc
   ```

3. Review x11vnc logs:

   ```bash
   docker exec raven cat /var/log/supervisor/x11vnc.err.log
   ```

### Issue: Wrong Password

**Solution:** Recreate container with new password:

```bash
docker rm -f raven
docker run -e VNC_PASSWORD=NewPassword123 ...
```

### Issue: Poor Performance

**Solutions:**

1. Reduce resolution: `-e RESOLUTION=1280x720`
2. Allocate more resources to Docker
3. Close unused applications in the desktop
4. Use VNC client instead of browser for better performance

---

## 🔒 Security Considerations

### Production Deployment

1. **Always set a strong VNC password:**

   ```bash
   -e VNC_PASSWORD=$(openssl rand -base64 32)
   ```

2. **Use HTTPS with Let's Encrypt:**
   - Deploy behind a reverse proxy (Traefik, Nginx, Caddy)
   - Enable SSL/TLS certificates

3. **Restrict port access:**
   - Only expose port 80/443
   - Use firewall rules to limit access

4. **Run with limited privileges:**
   - Consider using Docker user namespaces
   - Avoid running privileged containers in production

5. **Regular updates:**

   ```bash
   # For pre-built image
   docker pull sarkarsaswata001/raven_personal:v0
   
   # For custom builds
   docker pull ubuntu:22.04
   docker build --no-cache -t raven-desktop:latest .
   ```

---

## ❓ FAQ

**Q: What's new in v2?**  
A: Auto-detected CUDA support with persistent environment variables, better GPU documentation, enhanced volume binding examples, and improved flexibility for different Ubuntu versions.

**Q: Can I run this in Kubernetes?**  
A: Yes! Create a Deployment and expose via Service/Ingress. Set environment variables via ConfigMap. For GPU support, use `nvidia.com/gpu` resource limits.

**Q: Should I use the pre-built image or build from source?**  
A: Use the pre-built image (`sarkarsaswata001/raven_personal:v0`) for quick deployment. Build from source if you need to customize the Ubuntu version, packages, or configurations.

**Q: Does this support multiple users?**  
A: This image is designed for single-user sessions. For multi-user, deploy multiple containers.

**Q: How do I use CUDA/GPU with RAVEN?**  
A: CUDA is auto-detected on startup. Just use `--gpus all` flag and CUDA tools will be available in interactive shells. Use `docker exec -it raven nvcc --version` to verify.

**Q: Can I access CUDA from Python/TensorFlow/PyTorch?**  
A: Yes! Install `pytorch`, `tensorflow`, or `jax` with GPU support inside the container and they'll automatically detect your CUDA installation.

**Q: What's the image size?**  
A: Approximately 3-4GB due to desktop environment, Brave Browser, Miniconda, and development tools.

**Q: Can I customize the desktop theme?**  
A: Yes, modify the theme settings in [startup.sh](startup.sh) before building the image.

**Q: Is audio supported?**  
A: ALSA is installed. Use `--device /dev/snd` and set `ALSADEV` environment variable for audio device mapping.

---

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

1. **Fork the repository**
2. **Create a feature branch:** `git checkout -b feature/amazing-feature`
3. **Commit your changes:** `git commit -m 'Add amazing feature'`
4. **Push to the branch:** `git push origin feature/amazing-feature`
5. **Open a Pull Request**

### Development Guidelines

- Follow existing code style and documentation patterns
- Test changes thoroughly in a clean Docker environment
- Update README.md if adding new features
- Add comments to complex configuration changes

---

## ⚖️ License & Credits

### License

RAVEN is licensed under the **Apache License 2.0**. See [LICENSE](LICENSE) for full details.

```HTTP
Copyright 2025 RAVEN Contributors

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0
```

### Third-Party Components

This project integrates the following open-source software:

| Component | Version | License | Copyright |
| --------- | --------- | ------ | ------------- |
| **noVNC** | 1.6.0 | MPL 2.0 / BSD | © 2024 The noVNC Authors |
| **Websockify** | Latest | LGPLv3 | © Joel Martin and Websockify Contributors |
| **Ubuntu** | 22.04 LTS | Various | © Canonical Ltd. |
| **Miniconda** | Latest | BSD 3-Clause | © Anaconda, Inc. |
| **VS Code** | Latest | MIT | © Microsoft Corporation |
| **Brave Browser** | Latest | MPL 2.0 | © Brave Software, Inc. |
| **LXDE** | Latest | GPL | © LXDE Team |

See [NOTICE](NOTICE) file for detailed attribution and license information.

### Acknowledgments

Special thanks to:

- The noVNC project for browser-based VNC access
- The Docker community for container best practices
- All contributors who help improve RAVEN

---

## 📞 Support

- **Issues:** [GitHub Issues](https://github.com/yourusername/raven/issues)
- **Discussions:** [GitHub Discussions](https://github.com/yourusername/raven/discussions)
- **Documentation:** [Wiki](https://github.com/yourusername/raven/wiki)

---

## 🗺️ Roadmap

- [ ] Multi-architecture support (ARM64)
- [ ] Audio streaming support
- [ ] Pre-built Docker images on Docker Hub
- [ ] Kubernetes Helm chart
- [ ] Additional IDE options (JetBrains, Eclipse)
- [ ] Built-in file transfer mechanism
- [ ] Session recording capabilities

---

<div align="center">

**RAVEN v2 - Built with ❤️ for the developer community**

If you find RAVEN useful, please consider giving it a ⭐ on GitHub!

[⬆ Back to Top](#-raven-v2)

</div>
