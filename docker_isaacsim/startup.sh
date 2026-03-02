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
# Workspace Ownership & Permissions (Optimized)
# -------------------------------------------------
# Purpose:
#   Ensures the bind-mounted /root/workspace is owned by the host user.
#   Only runs if ownership is incorrect to avoid expensive chown on every startup.
# -------------------------------------------------

if [ -n "${HOST_UID}" ] && [ -n "${HOST_GID}" ]; then
    log_info "Checking /root/workspace ownership (target: UID:GID ${HOST_UID}:${HOST_GID})"
    # Only chown if ownership is incorrect
    CURRENT_UID=$(stat -c '%u' /root/workspace 2>/dev/null || echo "0")
    CURRENT_GID=$(stat -c '%g' /root/workspace 2>/dev/null || echo "0")
    
    if [ "${CURRENT_UID}" != "${HOST_UID}" ] || [ "${CURRENT_GID}" != "${HOST_GID}" ]; then
        log_info "Adjusting /root/workspace ownership to UID:GID ${HOST_UID}:${HOST_GID}"
        chown -R "${HOST_UID}:${HOST_GID}" /root/workspace
    else
        log_info "Workspace ownership already correct, skipping chown"
    fi
else
    log_info "HOST_UID and/or HOST_GID not set; using defaults (${HOST_UID}:1000)"
    chown -R 1000:1000 /root/workspace 2>/dev/null || true
fi

# Set umask so files created by root remain readable/writable by the group
umask 0002

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

# Find CUDA installations (prefer those with nvcc)
CUDA_DIR=""
if [ -n "$CUDA_VERSION_TRIMMED" ] && [ "$CUDA_VERSION_TRIMMED" != "default" ]; then
    # Look for specific version
    CUDA_DIR=$(find /usr/local -maxdepth 1 -type d -name "cuda-${CUDA_VERSION_TRIMMED}" 2>/dev/null | head -n1)
fi

# Fallback: find any CUDA installation (prefer with nvcc)
if [ -z "$CUDA_DIR" ]; then
    CUDA_DIR=$(find /usr/local -maxdepth 1 -type d -name "cuda-*" -o -name "cuda" 2>/dev/null | \
        while read -r dir; do
            [ -x "$dir/bin/nvcc" ] && echo "$dir" && break
        done | head -n1)
fi

# If still not found, use any CUDA directory
if [ -z "$CUDA_DIR" ]; then
    CUDA_DIR=$(find /usr/local -maxdepth 1 -type d -name "cuda-*" -o -name "cuda" 2>/dev/null | sort -V | tail -n1)
fi

# Detect compiler (use highest available gcc version)
CC_COMPILER=$(find /usr/bin -maxdepth 1 -name 'gcc-[0-9]*' -type f 2>/dev/null | sort -V | tail -n1)
if [ -z "$CC_COMPILER" ]; then
    CC_COMPILER="/usr/bin/gcc"
else
    CC_COMPILER=$(basename "$CC_COMPILER")
fi
CXX_COMPILER="${CC_COMPILER/gcc/g++}"

if [ -n "$CUDA_DIR" ] && [ -d "$CUDA_DIR" ]; then
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
EOF
    chmod +x "$CUDA_ENV_FILE"

    # Add to bashrc if not already present
    grep -q 'profile.d/cuda.sh' /root/.bashrc 2>/dev/null || \
        echo 'source /etc/profile.d/cuda.sh' >> /root/.bashrc

    # Create nvcc symlink if available
    [ -x "$CUDA_DIR/bin/nvcc" ] && ln -sf "$CUDA_DIR/bin/nvcc" /usr/local/bin/nvcc

    # Source the environment
    # shellcheck source=/dev/null
    source "$CUDA_ENV_FILE"
else
    log_info "No CUDA installation detected; setting fallback compiler"
    export CC=/usr/bin/$CC_COMPILER
    export CXX=/usr/bin/$CXX_COMPILER
fi

# -------------------------------------------------
# Volume Mount Validation (Production Safety Check)
# -------------------------------------------------
log_info "Validating required volume mounts..."
MOUNT_ERRORS=0

for mount_path in "/root/IsaacSim" "/root/IsaacLab" "/root/Assets_IsaacSim" "/root/workspace"; do
    if [ ! -d "$mount_path" ]; then
        log_error "CRITICAL: Volume not mounted at $mount_path"
        MOUNT_ERRORS=$((MOUNT_ERRORS + 1))
    else
        log_info "  ✓ $mount_path mounted"
    fi
done

if [ $MOUNT_ERRORS -gt 0 ]; then
    log_error "FATAL: $MOUNT_ERRORS required volumes are missing. Check compose.yaml volume mounts."
    exit 1
fi

# Validate _isaac_sym symlink exists (must be pre-created on host)
if [ ! -L "/root/IsaacLab/_isaac_sim" ]; then
    log_error "CRITICAL: /root/IsaacLab/_isaac_sim symlink not found."
    log_error "The symlink MUST be pre-created on the host before starting containers:"
    log_error "  ln -sfn ../IsaacSim /mount/Data2/saswata/isaac_sim_storage/IsaacLab/_isaac_sim"
    exit 1
fi
log_info "  ✓ _isaac_sim symlink present"

# -------------------------------------------------
# Isaac Sim & Isaac Lab Environment Bootstrap
# -------------------------------------------------
log_info "Bootstrapping Isaac Sim / Isaac Lab environment..."

ISAACLAB_ENV_FILE="/etc/profile.d/isaaclab.sh"
cat > "$ISAACLAB_ENV_FILE" <<'ENVEOF'
#!/bin/bash
# Isaac Sim & Isaac Lab — auto-generated by startup.sh
export ISAACSIM_PATH=/root/IsaacSim
export ISAACLAB_PATH=/root/IsaacLab
export ISAACSIM_ASSET_PATH=/root/Assets_IsaacSim

# Isaac Sim binaries on PATH
export PATH="$ISAACSIM_PATH:$ISAACSIM_PATH/kit:$PATH"

# Expose Isaac Sim Python packages to the system-Python PYTHONPATH so
# scripts that use the system interpreter can import omni.* modules.
if [ -d "$ISAACSIM_PATH/python_packages" ]; then
    export PYTHONPATH="$ISAACSIM_PATH/python_packages${PYTHONPATH:+:$PYTHONPATH}"
fi

# Aliases (available in every interactive terminal)
alias isaac="$ISAACSIM_PATH/isaac-sim.sh --allow-root"
alias isaacfull="$ISAACSIM_PATH/isaac-sim.sh --allow-root --/persistent/isaac/asset_root/default=\"$ISAACSIM_ASSET_PATH/Assets/Isaac/5.1\""
alias isaaclab="$ISAACLAB_PATH/isaaclab.sh"
alias isaaclab-python="$ISAACLAB_PATH/isaaclab.sh -p"
ENVEOF
chmod +x "$ISAACLAB_ENV_FILE"

# Source it for this session so the rest of startup.sh also benefits
# shellcheck source=/dev/null
source "$ISAACLAB_ENV_FILE"

# -------------------------------------------------
# Export Display Dimensions for Supervisor
# -------------------------------------------------
# Parse resolution string (e.g., "1920x1080" -> WIDTH=1920, HEIGHT=1080)
WIDTH=$(echo "$RESOLUTION" | cut -d'x' -f1)
HEIGHT=$(echo "$RESOLUTION" | cut -d'x' -f2)
export WIDTH
export HEIGHT

log_info "Display: $DISPLAY"
log_info "Resolution: ${WIDTH}x${HEIGHT}"

# -------------------------------------------------
# Directory Structure & D-Bus Initialization (Consolidated)
# -------------------------------------------------
log_info "Initializing directories and D-Bus..."

# Prepare directory structure
mkdir -p /tmp/.X11-unix /root/.vnc /var/run/dbus
chmod 1777 /tmp/.X11-unix

# D-Bus System Configuration
rm -f /var/run/dbus/pid /var/run/dbus/system_bus_socket
dbus-uuidgen > /var/lib/dbus/machine-id 2>/dev/null || true
dbus-daemon --config-file=/usr/share/dbus-1/system.conf --print-address &

# D-Bus Session Bus (for desktop apps)
eval "$(dbus-launch --sh-syntax)"
export DBUS_SESSION_BUS_ADDRESS DBUS_SESSION_BUS_PID

# -------------------------------------------------
# VNC Password & Desktop Configuration (Consolidated)
# -------------------------------------------------
log_info "Configuring VNC and desktop environment..."

# VNC password
VNC_PASS_FILE=/root/.vnc/passwd
rm -f "$VNC_PASS_FILE"
x11vnc -storepasswd "$VNC_PASSWORD" "$VNC_PASS_FILE" 2>/dev/null

# Desktop configuration directories
mkdir -p /root/.config/{pcmanfm/LXDE,lxsession/LXDE,gtk-3.0}

# File Manager Desktop Configuration
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
cat <<'EOF' > /root/.config/lxsession/LXDE/desktop.conf
[Session]
lock_manager/command=

[GTK]
sNet/ThemeName=Arc-Dark
sNet/IconThemeName=Papirus
sGtk/FontName=Sans 10
iGtk/ToolbarStyle=3
EOF

# GTK3 Settings
cat <<'EOF' > /root/.config/gtk-3.0/settings.ini
[Settings]
gtk-theme-name=Arc-Dark
gtk-icon-theme-name=Papirus
gtk-font-name=Sans 10
gtk-cursor-theme-name=Adwaita
EOF

# -------------------------------------------------
# X11 & Keyboard Configuration
# -------------------------------------------------
log_info "Configuring X11 settings for better desktop experience..."

# Create X11 startup script for keyboard repeat and settings
cat <<'EOF' > /root/.xsessionrc
#!/bin/bash
# Keyboard repeat rate (delay 200ms, rate 30 per second)
xset r rate 200 30

# Disable screen blanking and power management
xset s off
xset -dpms
xset s noblank

# Enable clipboard synchronization between X selections
autocutsel -fork
autocutsel -selection PRIMARY -fork
EOF
chmod +x /root/.xsessionrc

# -------------------------------------------------
# Bash Completion & Shell Configuration
# -------------------------------------------------
log_info "Configuring bash completion and shell improvements..."

cat <<'EOF' >> /root/.bashrc

# Enhanced bash completion
if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

# Better history
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend

# Colored prompt
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# Useful aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
EOF

# -------------------------------------------------
# Desktop Application Shortcuts
# -------------------------------------------------
log_info "Creating desktop application shortcuts..."

mkdir -p /root/Desktop
chmod 755 /root/Desktop

# Terminal shortcut
cat <<'EOF' > /root/Desktop/terminal.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Terminal
Comment=Use the command line
Exec=lxterminal
Icon=utilities-terminal
Terminal=false
Categories=System;TerminalEmulator;
EOF

# File Manager shortcut
cat <<'EOF' > /root/Desktop/files.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=File Manager
Comment=Browse files
Exec=pcmanfm
Icon=system-file-manager
Terminal=false
Categories=System;FileManager;
EOF

# Text Editor shortcut
cat <<'EOF' > /root/Desktop/editor.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Text Editor
Comment=Edit text files
Exec=mousepad
Icon=accessories-text-editor
Terminal=false
Categories=Utility;TextEditor;
EOF

# System Monitor shortcut
cat <<'EOF' > /root/Desktop/monitor.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=System Monitor
Comment=View system resources
Exec=gnome-system-monitor
Icon=utilities-system-monitor
Terminal=false
Categories=System;Monitor;
EOF

# Isaac Sim shortcut
cat <<'EOF' > /root/Desktop/isaac-sim.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Isaac Sim
Comment=NVIDIA Isaac Sim Robotics Simulator
Exec=bash -c '/root/IsaacSim/isaac-sim.sh --allow-root --/persistent/isaac/asset_root/default="/root/Assets_IsaacSim/Assets/Isaac/5.1"'
Icon=/root/IsaacSim/data/omni.isaac.sim.png
Terminal=false
Categories=Science;Robotics;
EOF

# Isaac Lab terminal shortcut (opens lxterminal in the IsaacLab directory)
cat <<'EOF' > /root/Desktop/isaac-lab.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Isaac Lab Terminal
Comment=Open terminal in Isaac Lab workspace
Exec=lxterminal --working-directory=/root/IsaacLab
Icon=utilities-terminal
Terminal=false
Categories=Science;Robotics;Development;
EOF

# Isaac Lab Setup shortcut (one-time Python environment installer)
cat <<'EOF' > /root/Desktop/setup-isaaclab.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Setup Isaac Lab (first time)
Comment=Install IsaacLab Python packages into /root/workspace/.isaaclab_env
Exec=lxterminal -e "bash /setup_isaaclab.sh; exec bash"
Icon=system-installer
Terminal=false
Categories=Science;Robotics;Development;
EOF

# Make desktop files executable and trusted
chmod +x /root/Desktop/*.desktop

# Configure PCManFM to show desktop icons
mkdir -p /root/.config/pcmanfm/LXDE
cat <<'EOF' > /root/.config/pcmanfm/LXDE/pcmanfm.conf
[config]
bm_open_method=0
su_cmd=lxsudo %s
view_mode=icon
show_hidden=0
sort_by=name
sort_type=ascending
[desktop]
wallpaper_mode=stretch
wallpaper=/usr/share/backgrounds/warty-final-ubuntu.png
desktop_bg=#000000
desktop_fg=#ffffff
show_documents=0
show_trash=1
show_mounts=1
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
