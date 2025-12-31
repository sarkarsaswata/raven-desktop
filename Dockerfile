# ============================================================================
# Docker Image: Ubuntu with LXDE Desktop, and VNC Access
# ============================================================================
# Description:
#   A complete containerized desktop environment with LXDE.
#   Brave browser, and VNC/noVNC remote access via websockets.
#   Includes Python (Miniconda), uv package manager, and GPU support.
#
#
# Environment Variables:
#   - DISPLAY: X11 display (default: :0)
#   - RESOLUTION: Desktop resolution (default: 1920x1080)
#   - VNC_PASSWORD: VNC access password (default: changeme)
#
# Exposed Ports:
#   - 80: HTTP/noVNC web interface
#   - 5900: VNC protocol (raw)
#   - 6080: Websocket VNC (noVNC)
# ============================================================================

# -------------------------------------------------
# Stage 1: Miniconda Base
# -------------------------------------------------
FROM continuumio/miniconda3:main AS conda-builder

# -------------------------------------------------
# Stage 2: UV Package Manager
# -------------------------------------------------
FROM ghcr.io/astral-sh/uv:0.9.20 AS uv-builder

# -------------------------------------------------
# Stage 3: Main Image
# -------------------------------------------------
FROM  nvidia/cuda:11.8.0-devel-ubuntu22.04

LABEL maintainer="Saswata Sarkar <sarkarsaswata01@gmail.com>"
LABEL description="Ubuntu Desktop Environment with noVNC"

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:0 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PATH=/opt/conda/bin:$PATH

# -------------------------------------------------
# APT Optimization: Use Ubuntu mirror network
# -------------------------------------------------
RUN sed -i 's#http://archive.ubuntu.com/ubuntu/#mirror://mirrors.ubuntu.com/mirrors.txt#' /etc/apt/sources.list

# -------------------------------------------------
# System Dependencies & GUI Stack
# -------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core utilities
    bash coreutils ca-certificates curl wget gnupg openssl \
    # X11 & VNC
    dbus-x11 x11-utils x11-xserver-utils xauth xvfb x11vnc \
    libxkbcommon-x11-0 \
    # LXDE & Desktop components
    lxde gtk2-engines-murrine gtk2-engines-pixbuf \
    # Themes & Icons
    arc-theme adwaita-icon-theme papirus-icon-theme ubuntu-wallpapers \
    # Audio & Media
    alsa-utils libasound2 ffmpeg \
    # Utilities
    supervisor nginx tini net-tools procps tmux \
    # Fonts & Graphics
    fonts-dejavu-core libglib2.0-0 libsm6 libxext6 libxrender1 \
    # Development tools
    build-essential gcc g++ cmake ninja-build pkg-config git \
    python3 python3-pip python-is-python3 python3.10-dev \
    # GPU/Graphics libraries
    libegl1-mesa-dev libgl1-mesa-dev libgles2-mesa-dev \
    libjpeg-dev libpng-dev libopencv-dev libtbb-dev \
    && rm -rf /var/lib/apt/lists/*

# -------------------------------------------------

# -------------------------------------------------
# noVNC & Websockify (Web-based VNC)
# Integrated from: https://github.com/novnc/noVNC

# -------------------------------------------------
# noVNC (Web-based VNC)
RUN mkdir -p /opt/novnc && \
    curl -L https://github.com/novnc/noVNC/archive/refs/tags/v1.6.0.tar.gz | \
    tar xz --strip 1 -C /opt/novnc && \
    ln -s /opt/novnc/vnc.html /opt/novnc/index.html && \
    pip3 install --no-cache-dir websockify setuptools wheel pip

# -------------------------------------------------
# Brave Browser (Official Installer)
# -------------------------------------------------
RUN curl -fsS https://dl.brave.com/install.sh | sh

# -------------------------------------------------
# Copy Pre-built Tools from Earlier Stages
# -------------------------------------------------
COPY --from=conda-builder /opt/conda /opt/conda
COPY --from=uv-builder /uv /uvx /bin/

# -------------------------------------------------
# Nginx Configuration (Reverse Proxy for noVNC)
# -------------------------------------------------
RUN printf "server {\n  listen 80;\n  location / {\n    proxy_pass http://127.0.0.1:6080/;\n    proxy_http_version 1.1;\n    proxy_set_header Upgrade \$http_upgrade;\n    proxy_set_header Connection \"Upgrade\";\n  }\n}\n" \
    > /etc/nginx/sites-available/default

# -------------------------------------------------
# Disable Lock Manager (Prevents Session Errors)
# -------------------------------------------------
RUN mkdir -p /etc/xdg/autostart /root/.config/lxsession/LXDE && \
    echo "[Desktop Entry]\nHidden=true" > /etc/xdg/autostart/light-locker.desktop && \
    echo "[Session]\nlock_manager/command=" > /root/.config/lxsession/LXDE/desktop.conf

# -------------------------------------------------
# Setup Workspace & Logs
# -------------------------------------------------
RUN mkdir -p /workspace /var/log/supervisor
WORKDIR /workspace

# -------------------------------------------------
# Copy Configuration & Startup Script
# -------------------------------------------------
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY startup.sh /startup.sh
RUN chmod +x /startup.sh

# -------------------------------------------------
# Expose Service Ports
# -------------------------------------------------
EXPOSE 80 5900 6080

# -------------------------------------------------
# Entrypoint: Use tini for proper signal handling
# -------------------------------------------------
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/startup.sh"]
