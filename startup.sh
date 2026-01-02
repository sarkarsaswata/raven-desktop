#!/usr/bin/env bash
# ============================================================================
# Startup Script for Ubuntu Desktop Container
# ============================================================================
# Description:
#   Initializes the containerized desktop environment including:
#   - X11 display server (Xvfb)
#   - D-Bus session/system daemons
#   - VNC server with password authentication
#   - LXDE desktop components
#   - Process supervision via supervisord
#
# Environment Variables:
#   - DISPLAY: X11 display identifier (default: :0)
#   - RESOLUTION: Desktop resolution (default: 1920x1080)
#   - VNC_PASSWORD: Password for VNC access (default: changeme)
#   - HOST_UID: User ID for workspace file ownership (default: 1000)
#   - HOST_GID: Group ID for workspace file ownership (default: 1000)
#   - HOST_USER: Username for workspace file ownership (default: dev)
#
# Exit on error to catch configuration issues early
# ============================================================================

set -xe

# -------------------------------------------------
# Helper Functions
# -------------------------------------------------

log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $*"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $*" >&2
}

# -------------------------------------------------
# Workspace Ownership & Permissions (User-Agnostic)
# -------------------------------------------------
# Purpose:
#   Ensures the bind-mounted /workspace is owned by the host user,
#   preventing permission conflicts when edited in VS Code or other editors.
#   This runs on every container startup to maintain consistency.
#
# Environment variables (set by docker run):
#   - HOST_UID: Host user ID (passed via -e HOST_UID=$(id -u))
#   - HOST_GID: Host group ID (passed via -e HOST_GID=$(id -g))
# -------------------------------------------------

if [ -n "${HOST_UID}" ] && [ -n "${HOST_GID}" ]; then
    log_info "Adjusting /workspace ownership to UID:GID ${HOST_UID}:${HOST_GID}"
    chown -R "${HOST_UID}:${HOST_GID}" /workspace
else
    log_info "HOST_UID and/or HOST_GID not set; using defaults (1000:1000)"
    chown -R 1000:1000 /workspace
fi

# Set umask so files created by root remain readable/writable by the group
# This ensures container-created files can be edited on the host
umask 0002
log_info "umask set to 0002"

# -------------------------------------------------
# Configuration Defaults
# -------------------------------------------------
: "${DISPLAY:=:0}"
: "${RESOLUTION:=1920x1080}"
: "${VNC_PASSWORD:=changeme}"

# -------------------------------------------------
# GPU/CUDA Support & Compiler Detection
# -------------------------------------------------
log_info "Detecting CUDA installation and compiler setup..."

CUDA_ENV_FILE="/etc/profile.d/cuda.sh"
: "${CUDA_VERSION:=}"   # optional override: "12.8"
CUDA_VERSION_TRIMMED="${CUDA_VERSION%%,*}"

has_nvcc() { [ -x "$1/bin/nvcc" ]; }

CUDA_WITH_NVCC=()
CUDA_RUNTIME_ONLY=()
for cuda_path in /usr/local/cuda-* /usr/local/cuda; do
    [ -d "$cuda_path" ] || continue
    if has_nvcc "$cuda_path"; then
        CUDA_WITH_NVCC+=("$cuda_path")
    else
        CUDA_RUNTIME_ONLY+=("$cuda_path")
    fi
done

pick_cuda_dir() {
    if [ -n "$CUDA_VERSION_TRIMMED" ]; then
        for dir in "${CUDA_WITH_NVCC[@]}"; do
            [[ "$dir" =~ cuda-"$CUDA_VERSION_TRIMMED"$ ]] && { echo "$dir"; return; }
            [[ "$dir" == "/usr/local/cuda" && "$CUDA_VERSION_TRIMMED" == "default" ]] && { echo "$dir"; return; }
        done
        for dir in "${CUDA_RUNTIME_ONLY[@]}"; do
            [[ "$dir" =~ cuda-"$CUDA_VERSION_TRIMMED"$ ]] && { echo "$dir"; return; }
            [[ "$dir" == "/usr/local/cuda" && "$CUDA_VERSION_TRIMMED" == "default" ]] && { echo "$dir"; return; }
        done
    fi
    if [ ${#CUDA_WITH_NVCC[@]} -gt 0 ]; then
        printf '%s\n' "${CUDA_WITH_NVCC[@]}" | sort -V | tail -n1
    else
        printf '%s\n' "${CUDA_RUNTIME_ONLY[@]}" | sort -V | tail -n1
    fi
}

CUDA_DIR="$(pick_cuda_dir)"

# Detect compiler versions
detect_compiler() {
    if [ -x /usr/bin/gcc-11 ]; then
        echo "gcc-11"
    elif [ -x /usr/bin/gcc-12 ]; then
        echo "gcc-12"
    elif [ -x /usr/bin/gcc ]; then
        echo "gcc"
    fi
}

CC_COMPILER="$(detect_compiler)"
CXX_COMPILER="${CC_COMPILER/gcc/g++}"

if [ -n "$CUDA_DIR" ]; then
    log_info "Using CUDA at $CUDA_DIR"
    log_info "Using compilers: CC=$CC_COMPILER, CXX=$CXX_COMPILER"
    
    cat > "$CUDA_ENV_FILE" <<EOF
#!/bin/bash
export CUDA_HOME="$CUDA_DIR"
export CC=/usr/bin/$CC_COMPILER
export CXX=/usr/bin/$CXX_COMPILER
export PATH="\$CUDA_HOME/bin:/root/.local/bin:/usr/local/bin:\$PATH"
export LD_LIBRARY_PATH="\$CUDA_HOME/lib64:\$LD_LIBRARY_PATH"
export LIBRARY_PATH="\$CUDA_HOME/lib64/stubs:\$LIBRARY_PATH"
export CUDA_LAUNCH_BLOCKING=1
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
export UV_LINK_MODE=copy
export UV_VENV_CLEAR=1
export UV_HTTP_TIMEOUT=300
export PYTHONWARNINGS=ignore
EOF
    chmod +x "$CUDA_ENV_FILE"

    if ! grep -q 'profile.d/cuda.sh' /root/.bashrc 2>/dev/null; then
        echo 'source /etc/profile.d/cuda.sh' >> /root/.bashrc
    fi

    if has_nvcc "$CUDA_DIR"; then
        ln -sf "$CUDA_DIR/bin/nvcc" /usr/local/bin/nvcc
    else
        log_info "nvcc not found under $CUDA_DIR (likely runtime-only)"
    fi

    source "$CUDA_ENV_FILE"
else
    log_info "No CUDA installation detected; setting fallback compiler and PATH"
    export CC=/usr/bin/$CC_COMPILER
    export CXX=/usr/bin/$CXX_COMPILER
    export PATH="/root/.local/bin:/usr/local/bin:$PATH"
    export UV_LINK_MODE=copy
    export UV_VENV_CLEAR=1
    export UV_HTTP_TIMEOUT=300
    export PYTHONWARNINGS=ignore
fi

# -------------------------------------------------
# Export Display Dimensions for Supervisor
# -------------------------------------------------
# Parse resolution string (e.g., "1920x1080" -> WIDTH=1920, HEIGHT=1080)
export WIDTH=$(echo "$RESOLUTION" | cut -d'x' -f1)
export HEIGHT=$(echo "$RESOLUTION" | cut -d'x' -f2)

log_info "Display: $DISPLAY"
log_info "Resolution: ${WIDTH}x${HEIGHT}"

# -------------------------------------------------
# Prepare Directory Structure
# -------------------------------------------------
log_info "Creating required directories..."
mkdir -p /tmp/.X11-unix /root/.vnc /var/run/dbus
chmod 1777 /tmp/.X11-unix

# -------------------------------------------------
# D-Bus System Configuration
# -------------------------------------------------
log_info "Initializing D-Bus..."

# Remove stale sockets/PIDs that could prevent startup
rm -f /var/run/dbus/pid /var/run/dbus/system_bus_socket

# Generate unique machine identifier (required for desktop apps)
dbus-uuidgen > /var/lib/dbus/machine-id

# Start system bus (allows system-wide service communication)
dbus-daemon --config-file=/usr/share/dbus-1/system.conf --print-address

# -------------------------------------------------
# D-Bus Session Bus
# -------------------------------------------------
# Essential for:
# - File manager (pcmanfm) to function properly
# - Desktop notifications
# - Inter-process communication in user session
log_info "Starting D-Bus Session Bus..."
eval $(dbus-launch --sh-syntax)
export DBUS_SESSION_BUS_ADDRESS
export DBUS_SESSION_BUS_PID

# -------------------------------------------------
# VNC Server Password Authentication
# -------------------------------------------------
log_info "Setting up VNC password..."
VNC_PASS_FILE=/root/.vnc/passwd
rm -f "$VNC_PASS_FILE"
x11vnc -storepasswd "$VNC_PASSWORD" "$VNC_PASS_FILE"

# -------------------------------------------------
# Desktop Theme & Wallpaper Configuration
# -------------------------------------------------
log_info "Configuring desktop theme and wallpaper..."

mkdir -p /root/.config/pcmanfm/LXDE/ \
         /root/.config/lxsession/LXDE/ \
         /root/.config/gtk-3.0/

# File Manager Desktop Items Configuration
# - Wallpaper: Ubuntu default wallpaper
# - Background color: Black (#000000)
# - Show trash & mount points on desktop
cat <<'EOF' > /root/.config/pcmanfm/LXDE/desktop-items-0.conf
[*]
wallpaper_mode=stretch
wallpaper_common=1
wallpaper=/usr/share/backgrounds/warty-final-ubuntu.png
desktop_bg=#000000
desktop_fg=#ffffff
desktop_shadow=#000000
show_wm_menu=0
sort=mtime;ascending;
show_documents=0
show_trash=1
show_mounts=1
EOF

# LXDE Session Configuration
# - Theme: Arc-Dark (modern dark theme)
# - Icons: Papirus (comprehensive icon set)
# - Disables lock manager to avoid session errors
cat <<'EOF' > /root/.config/lxsession/LXDE/desktop.conf
[Session]
lock_manager/command=

[GTK]
sNet/ThemeName=Arc-Dark
sNet/IconThemeName=Papirus
sGtk/FontName=Sans 10
iGtk/ToolbarStyle=3
EOF

# GTK3 Settings for Modern Applications
# Ensures VS Code, Terminal, and other GTK3 apps respect the dark theme
cat <<'EOF' > /root/.config/gtk-3.0/settings.ini
[Settings]
gtk-theme-name=Arc-Dark
gtk-icon-theme-name=Papirus
gtk-font-name=Sans 10
gtk-cursor-theme-name=Adwaita
EOF

# -------------------------------------------------
# Launch Supervisor
# -------------------------------------------------
# Supervisor manages multiple processes:
# 1. Xvfb (X Virtual Framebuffer)
# 2. Openbox (Window Manager)
# 3. LXPanel (Taskbar)
# 4. PCManFM (File Manager)
# 5. x11vnc (VNC Server)
# 6. Websockify (VNC over WebSocket)
# 7. Nginx (HTTP Reverse Proxy)
#
# -n flag: Run in foreground (don't daemonize)
# This allows Docker to track the main process
log_info "Launching Supervisor to manage desktop services..."
exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
