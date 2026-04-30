#!/usr/bin/env bash
# ============================================================================
# Startup Script for Ubuntu Desktop Container
# ============================================================================
# Description:
#   Initializes the containerized desktop environment including:
#   - Workspace ownership alignment (bind-mount safety)
#   - VNC server password setup
#   - D-Bus session and system daemons
#   - Desktop and GTK configuration
#   - Desktop shortcuts
#   - Process supervision via supervisord
#
# Environment Variables:
#   DISPLAY       X11 display identifier (default: :0)
#   RESOLUTION    Desktop resolution (default: 1920x1080)
#   VNC_PASSWORD  Password for VNC access (default: changeme)
#   HOST_UID      User ID for workspace file ownership (default: 1000)
#   HOST_GID      Group ID for workspace file ownership (default: 1000)
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
# Configuration Defaults
# -------------------------------------------------
: "${DISPLAY:=:0}"
: "${RESOLUTION:=1920x1080}"
: "${VNC_PASSWORD:=changeme}"

# -------------------------------------------------
# Workspace Ownership (bind-mount safety)
# -------------------------------------------------
# Only runs chown if the ownership is already incorrect to avoid
# an expensive recursive chown on every container restart.

if [ -n "${HOST_UID}" ] && [ -n "${HOST_GID}" ]; then
    log_info "Checking /root/workspace ownership (target: ${HOST_UID}:${HOST_GID})"
    CURRENT_UID=$(stat -c '%u' /root/workspace 2>/dev/null || echo "0")
    CURRENT_GID=$(stat -c '%g' /root/workspace 2>/dev/null || echo "0")

    if [ "${CURRENT_UID}" != "${HOST_UID}" ] || [ "${CURRENT_GID}" != "${HOST_GID}" ]; then
        log_info "Adjusting /root/workspace ownership to ${HOST_UID}:${HOST_GID}"
        chown -R "${HOST_UID}:${HOST_GID}" /root/workspace
    else
        log_info "Workspace ownership already correct, skipping chown"
    fi
else
    log_info "HOST_UID/HOST_GID not set; applying default 1000:1000 ownership"
    chown -R 1000:1000 /root/workspace 2>/dev/null || true
fi

# Files created by root remain readable/writable by the group
umask 0002

# -------------------------------------------------
# Export Display Dimensions for Supervisor
# -------------------------------------------------
WIDTH=$(echo "$RESOLUTION" | cut -d'x' -f1)
HEIGHT=$(echo "$RESOLUTION" | cut -d'x' -f2)
export WIDTH
export HEIGHT

log_info "Display: $DISPLAY  Resolution: ${WIDTH}x${HEIGHT}"

# -------------------------------------------------
# Directory Structure and D-Bus Initialization
# -------------------------------------------------
log_info "Initializing directories and D-Bus..."

mkdir -p /tmp/.X11-unix /root/.vnc /var/run/dbus
chmod 1777 /tmp/.X11-unix

# D-Bus system daemon
rm -f /var/run/dbus/pid /var/run/dbus/system_bus_socket
dbus-uuidgen > /var/lib/dbus/machine-id 2>/dev/null || true
dbus-daemon --config-file=/usr/share/dbus-1/system.conf --print-address &

# D-Bus session bus (for desktop applications)
eval "$(dbus-launch --sh-syntax)"
export DBUS_SESSION_BUS_ADDRESS DBUS_SESSION_BUS_PID

# -------------------------------------------------
# VNC Password and Desktop Configuration
# -------------------------------------------------
log_info "Configuring VNC password and desktop environment..."

# VNC password file
VNC_PASS_FILE=/root/.vnc/passwd
rm -f "$VNC_PASS_FILE"
x11vnc -storepasswd "$VNC_PASSWORD" "$VNC_PASS_FILE" 2>/dev/null

# Desktop configuration directories
mkdir -p /root/.config/{pcmanfm/LXDE,lxsession/LXDE,gtk-3.0}

# File Manager desktop configuration
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

# LXDE session configuration
cat <<'EOF' > /root/.config/lxsession/LXDE/desktop.conf
[Session]
lock_manager/command=

[GTK]
sNet/ThemeName=Arc-Dark
sNet/IconThemeName=Papirus
sGtk/FontName=Sans 10
iGtk/ToolbarStyle=3
EOF

# GTK3 settings
cat <<'EOF' > /root/.config/gtk-3.0/settings.ini
[Settings]
gtk-theme-name=Arc-Dark
gtk-icon-theme-name=Papirus
gtk-font-name=Sans 10
gtk-cursor-theme-name=Adwaita
EOF

# -------------------------------------------------
# X11 Session Configuration
# -------------------------------------------------
log_info "Configuring X11 session settings..."

cat <<'EOF' > /root/.xsessionrc
#!/bin/bash
# Keyboard repeat rate: 200 ms delay, 30 repeats/sec
xset r rate 200 30

# Disable screen blanking and power management
xset s off
xset -dpms
xset s noblank

# Clipboard synchronization
autocutsel -fork
autocutsel -selection PRIMARY -fork
EOF
chmod +x /root/.xsessionrc

# -------------------------------------------------
# Shell Configuration (bash)
# -------------------------------------------------
log_info "Configuring bash environment..."

cat <<'EOF' >> /root/.bashrc

# Bash completion
if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

# History settings
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

cat <<'EOF' > /root/Desktop/vscode.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=VS Code
Comment=Code editing, redefined
Exec=code --no-sandbox
Icon=com.visualstudio.code
Terminal=false
Categories=Development;IDE;
EOF

cat <<'EOF' > /root/Desktop/brave.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Brave Browser
Comment=Browse the Web
Exec=brave-browser --no-sandbox
Icon=brave-browser
Terminal=false
Categories=Network;WebBrowser;
EOF

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

# Make desktop files executable and trusted
chmod +x /root/Desktop/*.desktop

# PCManFM main config (icon view, wallpaper)
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
log_info "Launching Supervisor to manage desktop services..."
exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
