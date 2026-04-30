# ============================================================================
# Docker Image: Ubuntu Desktop with LXDE, VNC, and GPU Support
# ============================================================================
# Multi-stage build for a minimal Ubuntu desktop container.
#
# Description:
#   A clean, minimal containerized desktop environment with LXDE, VNC/noVNC
#   remote access, VS Code, Brave browser, and NVIDIA CUDA runtime support
#   for GPU-accelerated workloads. No Isaac Sim/Lab, no CUDA build tools.
#
# Stages:
#   1. uv-builder:  Extract uv binary (~100 MB)
#   2. desktop-env: CUDA runtime + Python + LXDE + VNC + noVNC (~4-5 GB)
#   3. final:       VS Code + Brave + startup scripts (adds ~1-2 GB)
#
# Build command:
#   docker build -t local/ubuntu-desktop:minimal .
#
# Environment Variables:
#   - DISPLAY:       X11 display number (default: :0)
#   - RESOLUTION:    Desktop resolution (default: 1920x1080)
#   - VNC_PASSWORD:  VNC access password (REQUIRED - set at runtime)
#   - HOST_UID:      UID for workspace ownership alignment
#   - HOST_GID:      GID for workspace ownership alignment
#
# Exposed Ports:
#   - 80:   HTTP/noVNC web interface
#   - 5900: VNC protocol (raw TCP)
#   - 6080: WebSocket VNC (noVNC)
# ============================================================================

# ============================================================================
# Stage 1: UV Package Manager Builder
# ============================================================================
FROM ghcr.io/astral-sh/uv:latest AS uv-builder


# ============================================================================
# Stage 2: Desktop Environment
# ============================================================================
# Core: CUDA 12.8 runtime + Python 3.10 + LXDE + VNC/noVNC + supervisor
# No CUDA build headers, no nvcc, no compiler toolchain vars.
# ============================================================================
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04 AS desktop-env

LABEL maintainer="Saswata Sarkar <sarkarsaswata01@gmail.com>"
LABEL description="Ubuntu desktop: CUDA 12.8 runtime + LXDE + VNC/noVNC"

# ============================================================================
# Environment Configuration
# ============================================================================
ENV DISPLAY=:0 \
    RESOLUTION=1920x1080 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=graphics,compute,utility \
    UV_LINK_MODE=copy

# ============================================================================
# Core System Dependencies + Desktop Stack
# ============================================================================
RUN set -e && \
    sed -i 's#http://archive.ubuntu.com/ubuntu/#mirror://mirrors.ubuntu.com/mirrors.txt#' /etc/apt/sources.list || true && \
    apt-get update && \
    apt-get install -y --no-install-recommends software-properties-common apt-transport-https ca-certificates && \
    add-apt-repository universe && \
    add-apt-repository multiverse && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    # Minimal build tools
    build-essential cmake git curl wget \
    # Python 3.10
    python3.10-dev python3-pip python-is-python3 \
    # X11 and VNC stack
    dbus-x11 x11-utils xvfb x11vnc xcompmgr \
    # Process supervisor and web server
    supervisor nginx tini \
    # LXDE desktop environment
    lxde \
    # LXDE utilities
    lxterminal pcmanfm lxappearance lxrandr lxinput \
    # Desktop accessories
    xarchiver gpicview galculator gnome-system-monitor \
    # Clipboard utilities
    xclip xsel autocutsel \
    # Themes and icons
    arc-theme adwaita-icon-theme papirus-icon-theme ubuntu-wallpapers \
    # Fonts
    fonts-liberation fonts-dejavu fonts-noto fonts-ubuntu \
    # Shell tools and utilities
    htop vim nano tmux net-tools procps file-roller unzip zip p7zip-full \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*

# ============================================================================
# Copy UV Package Manager from Builder Stage
# ============================================================================
COPY --from=uv-builder /uv /uvx /bin/

# ============================================================================
# Install websockify (VNC WebSocket bridge)
# ============================================================================
RUN pip3 install --no-cache-dir websockify

# ============================================================================
# noVNC Installation (WebSocket VNC bridge web UI)
# ============================================================================
RUN mkdir -p /opt/novnc && \
    curl -fsSL https://github.com/novnc/noVNC/archive/refs/tags/v1.6.0.tar.gz | \
    tar xz --strip 1 -C /opt/novnc && \
    ln -s /opt/novnc/vnc.html /opt/novnc/index.html && \
    rm -rf /tmp/* /var/tmp/*

# ============================================================================
# Nginx Configuration (reverse proxy: port 80 -> 6080)
# ============================================================================
RUN printf "server {\n  listen 80;\n  location / {\n    proxy_pass http://127.0.0.1:6080/;\n    proxy_http_version 1.1;\n    proxy_set_header Upgrade \$http_upgrade;\n    proxy_set_header Connection \"Upgrade\";\n  }\n}\n" \
    > /etc/nginx/sites-available/default

# ============================================================================
# LXDE Desktop Configuration (disable screensaver, set session defaults)
# ============================================================================
RUN mkdir -p /etc/xdg/autostart /root/.config/lxsession/LXDE /var/log/supervisor && \
    echo "[Desktop Entry]\nHidden=true" > /etc/xdg/autostart/light-locker.desktop && \
    echo "[Session]\nlock_manager/command=" > /root/.config/lxsession/LXDE/desktop.conf

# ============================================================================
# Create workspace directory
# ============================================================================
RUN mkdir -p /root/workspace


# ============================================================================
# Stage 3: Final Production Image
# ============================================================================
# Adds: VS Code + Brave browser + startup scripts
# Builds on: desktop-env
# Final size: ~5-6 GB
# ============================================================================
FROM desktop-env AS final

LABEL maintainer="Saswata Sarkar <sarkarsaswata01@gmail.com>"
LABEL description="Production Ubuntu desktop with VS Code, Brave, GPU support"

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
# Set Working Directory
# ============================================================================
WORKDIR /root/workspace

# ============================================================================
# Copy Configuration and Startup Scripts
# ============================================================================
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY startup.sh /startup.sh
COPY entrypoint-user.sh /usr/local/bin/entrypoint-user.sh
RUN chmod +x /startup.sh /usr/local/bin/entrypoint-user.sh

# ============================================================================
# Expose Service Ports
# ============================================================================
# 80:   HTTP for noVNC web interface
# 5900: VNC protocol (raw TCP)
# 6080: WebSocket VNC (noVNC, browser-accessible)
EXPOSE 80 5900 6080

# ============================================================================
# Container Entrypoint and Default Command
# ============================================================================
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint-user.sh"]
CMD ["/startup.sh"]
