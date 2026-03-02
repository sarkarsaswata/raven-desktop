# ============================================================================
# Docker Image: Ubuntu Desktop with LXDE, VNC, and Isaac Sim/Lab Support
# ============================================================================
# Multi-stage optimized build for production Isaac Sim/Lab deployment
#
# Description:
#   A production-grade containerized desktop environment optimized for
#   Isaac Sim 5.1 and Isaac Lab with full developer experience. Includes
#   LXDE desktop, VNC/noVNC remote access, Python tools, VS Code, Brave
#   browser, and complete CUDA 12.8 support for GPU acceleration.
#
# Stages:
#   1. uv-builder: Extract UV package manager binary (~100 MB)
#   2. base-runtime: CUDA + Python + system essentials (~5-6 GB)
#   3. desktop-env: LXDE + x11vnc + noVNC + supervisor (adds ~800 MB)
#   4. dev-tools: VS Code + Brave + development tools (adds ~1-2 GB)
#   5. final: Complete production desktop for Isaac Sim/Lab (8-9 GB total)
#
# Build command:
#   docker build -t local/ubuntu-desktop-vnc:isaac-5.1 .
#
# Environment Variables:
#   - DISPLAY: X11 display number (default: :0)
#   - RESOLUTION: Desktop resolution (default: 1920x1080)
#   - VNC_PASSWORD: VNC access password (REQUIRED - set at runtime)
#   - ISAACSIM_PATH: Isaac Sim installation path
#   - ISAACLAB_PATH: Isaac Lab source path
#
# Exposed Ports:
#   - 80: HTTP/noVNC web interface
#   - 5900: VNC protocol (raw TCP)
#   - 6080: WebSocket VNC (noVNC)
# ============================================================================

# ============================================================================
# Stage 1: UV Package Manager Builder
# ============================================================================
# Extracts UV binary for fast Python package management (~100 MB)
# ============================================================================
FROM ghcr.io/astral-sh/uv:0.9.20 AS uv-builder


# ============================================================================
# Stage 2: Base Runtime Image  
# ============================================================================
# Core: CUDA 12.8 + Python 3.10 + Python 3.11 + build tools + system essentials
# No GUI, no browsers, no IDEs yet - pure compute + scripting foundation
# Final size: ~5-6 GB
# ============================================================================
FROM nvidia/cuda:12.8.0-devel-ubuntu22.04 AS base-runtime

LABEL maintainer="Saswata Sarkar <sarkarsaswata01@gmail.com>"
LABEL description="Base runtime: CUDA 12.8 + Python + Core system libraries for Isaac Sim/Lab"

# ============================================================================
# CUDA and Build Environment Configuration
# ============================================================================
ENV CUDA_HOME=/usr/local/cuda

ENV CC=/usr/bin/gcc \
    CXX=/usr/bin/g++ \
    CUDA_LAUNCH_BLOCKING=1 \
    PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
    TORCH_CUDA_ARCH_LIST="8.6" \
    TCNN_CUDA_ARCHITECTURES="86" \
    TCNN_HALF_PRECISION=1 \
    PATH=/root/.local/bin:${CUDA_HOME}/bin:/usr/local/bin:${PATH} \
    LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH} \
    LIBRARY_PATH=${CUDA_HOME}/lib64/stubs:${LIBRARY_PATH}

# ============================================================================
# Isaac Sim / Isaac Lab Paths Configuration
# ============================================================================
ENV ISAACSIM_PATH=/root/IsaacSim \
    ISAACLAB_PATH=/root/IsaacLab \
    ISAACSIM_ASSET_PATH=/root/Assets_IsaacSim \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive

# ============================================================================
# Core System Dependencies, Build Tools, and Python
# ============================================================================
RUN set -e && \
    sed -i 's#http://archive.ubuntu.com/ubuntu/#mirror://mirrors.ubuntu.com/mirrors.txt#' /etc/apt/sources.list || true && \
    apt-get update && \
    apt-get install -y --no-install-recommends software-properties-common apt-transport-https && \
    add-apt-repository universe && \
    add-apt-repository multiverse && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    # Build tools (compiler, cmake, make, git)
    build-essential cmake ninja-build pkg-config \
    gcc g++ git curl wget \
    # CUDA development headers and graphics libraries
    libegl1-mesa-dev libglu1-mesa-dev libx11-6 libxcb1 libxau6 \
    libgl1-mesa-dev libgles2-mesa-dev libtbb-dev \
    # Graphics libraries (for Isaac Sim rendering)
    libglib2.0-0 libsm6 libxext6 libxrender1 \
    libjpeg-dev libpng-dev libopencv-dev \
    # Fonts for better text rendering
    fonts-liberation fonts-dejavu fonts-noto fonts-ubuntu \
    # Shell and shell utilities
    bash-completion command-not-found \
    # Essential system tools
    htop vim nano gedit mousepad tmux net-tools procps scrot xdotool \
    # File management tools
    file-roller unzip zip p7zip-full \
    # Network and security
    ca-certificates \
    # Python 3.10 (Isaac Sim primary)
    python-is-python3 python3.10-dev python3-pip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*

# ============================================================================
# Copy UV Package Manager from Builder Stage
# ============================================================================
COPY --from=uv-builder /uv /uvx /bin/

# ============================================================================
# Install Python Base Packages (websockify, setuptools, wheel)
# ============================================================================
RUN pip3 install --no-cache-dir websockify setuptools wheel

# ============================================================================
# Create workspace directory
# ============================================================================
RUN mkdir -p /root/workspace

# ============================================================================
# Stage 3: Desktop Environment
# ============================================================================
# Adds: LXDE desktop, x11vnc, Xvfb, supervisor, noVNC, nginx
# Builds on: base-runtime
# Adds size: ~800 MB (GUI stack + VNC infrastructure)
# Final size: ~6-7 GB
# ============================================================================
FROM base-runtime AS desktop-env

LABEL description="Desktop environment: base-runtime + LXDE + x11vnc + noVNC"

# ============================================================================
# Display and Desktop Environment Configuration
# ============================================================================
ENV DISPLAY=:0 \
    UV_LINK_MODE=copy \
    UV_VENV_CLEAR=1 \
    UV_HTTP_TIMEOUT=300 \
    PYTHONWARNINGS=ignore \
    OMNI_KIT_ACCEPT_EULA=YES \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=graphics,compute,utility \
    __GLX_VENDOR_LIBRARY_NAME=nvidia

# ============================================================================
# LXDE, VNC, and Desktop Stack Installation
# ============================================================================
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    # X11 virtual framebuffer and VNC server
    dbus-x11 x11-utils xvfb x11vnc xcompmgr \
    # Process supervisor (manages X11, VNC, desktop components)
    supervisor \
    # Web server for noVNC
    nginx tini \
    # LXDE desktop environment (lightweight)
    lxde \
    # LXDE components and utilities
    lxterminal pcmanfm lxappearance lxrandr lxinput \
    # Linux utilities
    xarchiver gpicview galculator gnome-system-monitor \
    # Clipboard utilities
    xclip xsel autocutsel \
    # Desktop theming and icons
    arc-theme adwaita-icon-theme papirus-icon-theme ubuntu-wallpapers \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# noVNC Installation (WebSocket VNC bridge)
# ============================================================================
RUN mkdir -p /opt/novnc && \
    curl -fsSL https://github.com/novnc/noVNC/archive/refs/tags/v1.6.0.tar.gz | \
    tar xz --strip 1 -C /opt/novnc && \
    ln -s /opt/novnc/vnc.html /opt/novnc/index.html && \
    rm -rf /tmp/* /var/tmp/*

# ============================================================================
# Nginx Configuration (Reverse proxy for noVNC WebSocket)
# ============================================================================
RUN printf "server {\n  listen 80;\n  location / {\n    proxy_pass http://127.0.0.1:6080/;\n    proxy_http_version 1.1;\n    proxy_set_header Upgrade \$http_upgrade;\n    proxy_set_header Connection \"Upgrade\";\n  }\n}\n" \
    > /etc/nginx/sites-available/default

# ============================================================================
# Desktop Configuration (LXDE, autostart, session files)
# ============================================================================
RUN mkdir -p /etc/xdg/autostart /root/.config/lxsession/LXDE /var/log/supervisor && \
    echo "[Desktop Entry]\nHidden=true" > /etc/xdg/autostart/light-locker.desktop && \
    echo "[Session]\nlock_manager/command=" > /root/.config/lxsession/LXDE/desktop.conf

# ============================================================================
# Stage 4: Development Tools
# ============================================================================
# Adds: VS Code + Brave browser + optional development utilities
# Builds on: desktop-env
# Adds size: ~1-2 GB (browser, IDE, fonts)
# Final size: ~7-8 GB
# ============================================================================
FROM desktop-env AS dev-tools

LABEL description="Development tools: desktop-env + VS Code + Brave browser"

# ============================================================================
# VS Code Installation via Microsoft Repository
# ============================================================================
RUN set -e && \
    wget -O- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /usr/share/keyrings/vscode.gpg > /dev/null && \
    echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/vscode.gpg] https://packages.microsoft.com/repos/code stable main" | tee /etc/apt/sources.list.d/vscode.list > /dev/null && \
    apt-get update && \
    apt-get install -y --no-install-recommends code && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*

# ============================================================================
# Brave Browser Installation
# ============================================================================
RUN curl -fsSL https://dl.brave.com/install.sh | sh && \
    rm -rf /tmp/* /var/tmp/*

# ============================================================================
# Stage 5: Final Production Image
# ============================================================================
# Complete desktop environment with Isaac Sim/Lab support
# Builds on: dev-tools
# Final size: ~8-9 GB (production-ready)
# ============================================================================
FROM dev-tools AS final

LABEL maintainer="Saswata Sarkar <sarkarsaswata01@gmail.com>"
LABEL description="Production desktop for Isaac Sim 5.1 and Isaac Lab with full developer environment"

# ============================================================================
# Isaac Sim and Isaac Lab Environment Aliases
# ============================================================================
RUN echo "# Isaac Sim" >> /root/.bashrc && \
    echo "alias isaac='/root/IsaacSim/isaac-sim.sh --allow-root'" >> /root/.bashrc && \
    echo "alias isaacfull='/root/IsaacSim/isaac-sim.sh --allow-root --/persistent/isaac/asset_root/default=\"/root/Assets_IsaacSim/Assets/Isaac/5.1\"'" >> /root/.bashrc && \
    echo "" >> /root/.bashrc && \
    echo "# Isaac Lab" >> /root/.bashrc && \
    echo "alias isaaclab='/root/IsaacLab/isaaclab.sh'" >> /root/.bashrc && \
    echo "alias isaaclab-python='/root/IsaacLab/isaaclab.sh -p'" >> /root/.bashrc && \
    echo "" >> /root/.bashrc && \
    echo "# PATH setup for Isaac Sim binaries" >> /root/.bashrc && \
    echo "export PATH=\"\$ISAACSIM_PATH:\$ISAACSIM_PATH/kit:\$PATH\"" >> /root/.bashrc

# ============================================================================
# Set Working Directory
# ============================================================================
WORKDIR /root/workspace

# ============================================================================
# Copy Configuration and Startup Scripts
# ============================================================================
RUN mkdir -p /root/workspace/setup
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY startup.sh /startup.sh
COPY entrypoint-user.sh /usr/local/bin/entrypoint-user.sh
COPY setup_isaaclab.sh /setup_isaaclab.sh
COPY setup_isaaclab_uv.sh /setup_isaaclab_uv.sh
RUN chmod +x /startup.sh /usr/local/bin/entrypoint-user.sh /setup_isaaclab.sh /setup_isaaclab_uv.sh

# ============================================================================
# Expose Service Ports
# ============================================================================
# 80: HTTP for noVNC web interface
# 5900: VNC protocol (raw TCP, ~75 fps)
# 6080: WebSocket VNC (noVNC, works through firewalls)
# ============================================================================
EXPOSE 80 5900 6080

# ============================================================================
# Container Entrypoint and Default Command
# ============================================================================
# tini: Process supervisor for signal handling (prevents zombie processes)
# entrypoint-user.sh: User/group setup for bind-mount compatibility
# startup.sh: Initialize X11, VNC, desktop, and Isaac Sim environment
# ============================================================================
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint-user.sh"]
CMD ["/startup.sh"]
