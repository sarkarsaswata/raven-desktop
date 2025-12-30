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
#
# Exit on error to catch configuration issues early
# ============================================================================

set -e

# -------------------------------------------------
# Configuration Defaults
# -------------------------------------------------
: "${DISPLAY:=:0}"
: "${RESOLUTION:=1920x1080}"
: "${VNC_PASSWORD:=changeme}"

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
# GPU/CUDA Support Detection
# -------------------------------------------------
log_info "Detecting CUDA installation..."

# Create a persistent CUDA environment script that will be sourced by all shells
CUDA_ENV_FILE="/etc/profile.d/cuda.sh"

# Check if CUDA is installed
CUDA_DIR=""
for cuda_path in /usr/local/cuda-* /usr/local/cuda; do
    if [ -d "$cuda_path" ]; then
        CUDA_DIR="$cuda_path"
        log_info "Found CUDA at $CUDA_DIR"
        break
    fi
done

if [ -n "$CUDA_DIR" ]; then
    # Create persistent environment script for all future shells
    cat > "$CUDA_ENV_FILE" <<EOF
#!/bin/bash
# CUDA Environment Configuration - Auto-detected at container startup
export CUDA_HOME="$CUDA_DIR"
export PATH="\$CUDA_HOME/bin:\$PATH"
export LD_LIBRARY_PATH="\$CUDA_HOME/lib64:\$LD_LIBRARY_PATH"
EOF
    chmod +x "$CUDA_ENV_FILE"
    
    # Source it immediately for the current process
    source "$CUDA_ENV_FILE"
    
    log_info "CUDA environment configured at $CUDA_DIR"
    log_info "  - Added to PATH"
    log_info "  - Added to LD_LIBRARY_PATH"
else
    log_info "No CUDA installation detected"
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
