# -------------------------------------------------
# Stage 1: Miniconda
# -------------------------------------------------
FROM continuumio/miniconda3:main AS conda

# -------------------------------------------------
# Stage 2: uv
# -------------------------------------------------
FROM ghcr.io/astral-sh/uv:0.9.20 AS uvbin

# -------------------------------------------------
# Stage 3: Main image
# -------------------------------------------------
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:0 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PATH=/opt/conda/bin:$PATH

# OPTIMIZATION: Use local mirrors for faster package downloads
RUN sed -i 's#http://archive.ubuntu.com/ubuntu/#mirror://mirrors.ubuntu.com/mirrors.txt#' /etc/apt/sources.list

# -------------------------------------------------
# Consolidated System, GUI, and Dev Stack
# -------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash coreutils ca-certificates dbus-x11 x11-utils x11-xserver-utils \
    xauth xvfb x11vnc lxde gtk2-engines-murrine gtk2-engines-pixbuf \
    arc-theme supervisor nginx tini ffmpeg alsa-utils libasound2 \
    fonts-dejavu-core libglib2.0-0 libsm6 \
    libxext6 libxrender1 net-tools procps openssl curl wget gnupg \
    build-essential gcc g++ cmake ninja-build pkg-config git tmux \
    python3 python3-pip python-is-python3 python3.10-dev \
    libegl1-mesa-dev libgl1-mesa-dev libgles2-mesa-dev \
    libjpeg-dev libpng-dev libopencv-dev libtbb-dev \
    adwaita-icon-theme papirus-icon-theme ubuntu-wallpapers \
    && rm -rf /var/lib/apt/lists/*

# -------------------------------------------------
# VS Code Desktop Installation (Official MS Repo)
# -------------------------------------------------
RUN wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/vscode.gpg && \
    echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/vscode.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list && \
    apt-get update && apt-get install -y code && \
    rm -rf /var/lib/apt/lists/*

# -------------------------------------------------
# noVNC and Websockify
# -------------------------------------------------
RUN mkdir -p /opt/novnc && \
    curl -L https://github.com/novnc/noVNC/archive/refs/tags/v1.6.0.tar.gz | tar xz --strip 1 -C /opt/novnc && \
    ln -s /opt/novnc/vnc.html /opt/novnc/index.html && \
    pip3 install --no-cache-dir websockify setuptools wheel pip

# -------------------------------------------------
# Brave browser (official installer)
# -------------------------------------------------
RUN curl -fsS https://dl.brave.com/install.sh | sh

# -------------------------------------------------
# Miniconda + uv (multi-stage COPY)
# -------------------------------------------------
COPY --from=conda /opt/conda /opt/conda
COPY --from=uvbin /uv /uvx /bin/

# -------------------------------------------------
# Nginx Configuration for noVNC
# -------------------------------------------------
RUN printf "server {\n  listen 80;\n  location / {\n    proxy_pass http://127.0.0.1:6080/;\n    proxy_http_version 1.1;\n    proxy_set_header Upgrade \$http_upgrade;\n    proxy_set_header Connection \"Upgrade\";\n  }\n}\n" > /etc/nginx/sites-available/default

# -------------------------------------------------
# Workspace and startup
# -------------------------------------------------
RUN mkdir -p /workspace /var/log/supervisor

# Disable light-locker and lock manager to prevent session errors
RUN mkdir -p /etc/xdg/autostart /root/.config/lxsession/LXDE && \
    echo "[Desktop Entry]\nHidden=true" > /etc/xdg/autostart/light-locker.desktop && \
    echo "[Session]\nlock_manager/command=" > /root/.config/lxsession/LXDE/desktop.conf

WORKDIR /workspace

COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY startup.sh /startup.sh
RUN chmod +x /startup.sh

EXPOSE 80 5900 6080

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/startup.sh"]