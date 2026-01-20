# ============================================================================
# Docker Image: Ubuntu with LXDE Desktop, and VNC Access
# ============================================================================
# Description:
#   A complete containerized desktop environment with LXDE.
#   Brave browser, and VNC/noVNC remote access via websockets.
#   Includes Python (Miniconda), uv package manager, and GPU support.
#
# Environment Variables:
#   - DISPLAY: X11 display (default: :0)
#   - RESOLUTION: Desktop resolution (default: 1920x1080)
#   - VNC_PASSWORD: VNC access password (REQUIRED - override at runtime for security)
#
# Exposed Ports:
#   - 80: HTTP/noVNC web interface
#   - 5900: VNC protocol (raw)
#   - 6080: Websocket VNC (noVNC)
# ============================================================================

# ============================================================================
# Stage 1: UV Package Manager
# ============================================================================
FROM ghcr.io/astral-sh/uv:0.9.20 AS uv-builder

# ============================================================================
# Stage 2: Main Image
# ============================================================================
FROM nvidia/cuda:13.0.0-devel-ubuntu22.04

LABEL maintainer="Saswata Sarkar <sarkarsaswata01@gmail.com>"
LABEL description="Ubuntu Desktop Environment with noVNC"

# ============================================================================
# CUDA and Build Configuration (Static, Build-Time)
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
# Desktop Environment Configuration (Static, Build-Time)
# ============================================================================
ENV DISPLAY=:0 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive \
    UV_LINK_MODE=copy \
    UV_VENV_CLEAR=1 \
    UV_HTTP_TIMEOUT=300 \
    PYTHONWARNINGS=ignore

# ============================================================================
# APT Optimization & System Dependencies
# ============================================================================
RUN set -e && \
    sed -i 's#http://archive.ubuntu.com/ubuntu/#mirror://mirrors.ubuntu.com/mirrors.txt#' /etc/apt/sources.list || true && \
    apt-get update && \
    apt-get install -y --no-install-recommends software-properties-common apt-transport-https && \
    add-apt-repository universe && \
    add-apt-repository multiverse && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    # Build tools
    build-essential cmake ninja-build pkg-config \
    gcc g++ git curl wget \
    # CUDA development
    libegl1-mesa-dev libgl1-mesa-dev libgles2-mesa-dev libtbb-dev \
    # GUI & VNC stack
    dbus-x11 x11-utils xvfb x11vnc lxde supervisor nginx tini \
    # Graphics libraries
    libglib2.0-0 libsm6 libxext6 libxrender1 \
    libjpeg-dev libpng-dev libopencv-dev \
    # Desktop components
    arc-theme adwaita-icon-theme papirus-icon-theme ubuntu-wallpapers \
    # Desktop applications
    lxterminal pcmanfm lxappearance lxrandr lxinput \
    xarchiver gpicview galculator gnome-system-monitor \
    # Clipboard & utilities
    xclip xsel autocutsel \
    # Fonts for better rendering
    fonts-liberation fonts-dejavu fonts-noto fonts-ubuntu \
    # Shell & completion
    bash-completion command-not-found \
    # System tools
    htop vim nano gedit mousepad \
    # File management
    file-roller unzip zip p7zip-full \
    # Network tools
    firefox ca-certificates \
    # Python & dev
    python-is-python3 python3.10-dev python3-pip \
    # Utilities
    tmux net-tools procps scrot xdotool \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*

# ============================================================================
# VS Code Installation via APT Repository
# ============================================================================
RUN set -e && \
    wget -O- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /usr/share/keyrings/vscode.gpg > /dev/null && \
    echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/vscode.gpg] https://packages.microsoft.com/repos/code stable main" | tee /etc/apt/sources.list.d/vscode.list > /dev/null && \
    apt-get update && \
    apt-get install -y --no-install-recommends code && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*

# ============================================================================
# Copy Pre-built Tools from Earlier Stages
# ============================================================================
COPY --from=uv-builder /uv /uvx /bin/

# ============================================================================
# Install websockify, setuptools, wheel with system Python
# ============================================================================
RUN pip3 install --no-cache-dir websockify setuptools wheel 

# ============================================================================
# noVNC & Brave Browser Installation
# ============================================================================
RUN mkdir -p /opt/novnc && \
    curl -fsSL https://github.com/novnc/noVNC/archive/refs/tags/v1.6.0.tar.gz | \
    tar xz --strip 1 -C /opt/novnc && \
    ln -s /opt/novnc/vnc.html /opt/novnc/index.html && \
    curl -fsSL https://dl.brave.com/install.sh | sh && \
    rm -rf /tmp/* /var/tmp/*

# ============================================================================
# Nginx Configuration (Reverse Proxy for noVNC)
# ============================================================================
RUN printf "server {\n  listen 80;\n  location / {\n    proxy_pass http://127.0.0.1:6080/;\n    proxy_http_version 1.1;\n    proxy_set_header Upgrade \$http_upgrade;\n    proxy_set_header Connection \"Upgrade\";\n  }\n}\n" \
    > /etc/nginx/sites-available/default

# ============================================================================
# Configuration Setup (Consolidated)
# ============================================================================
RUN mkdir -p /etc/xdg/autostart /root/.config/lxsession/LXDE /workspace /var/log/supervisor && \
    echo "[Desktop Entry]\nHidden=true" > /etc/xdg/autostart/light-locker.desktop && \
    echo "[Session]\nlock_manager/command=" > /root/.config/lxsession/LXDE/desktop.conf

WORKDIR /workspace

# ============================================================================
# Copy Configuration & Startup Scripts
# ============================================================================
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY startup.sh /startup.sh
COPY entrypoint-user.sh /usr/local/bin/entrypoint-user.sh
RUN chmod +x /startup.sh /usr/local/bin/entrypoint-user.sh

# ============================================================================
# Expose Service Ports
# ============================================================================
EXPOSE 80 5900 6080

# ============================================================================
# Entrypoint: Use tini for proper signal handling
# ============================================================================
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint-user.sh"]
CMD ["/startup.sh"]
