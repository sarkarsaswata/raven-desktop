#!/usr/bin/env bash
set -e

# -------------------------------------------------
# Defaults
# -------------------------------------------------
: "${DISPLAY:=:0}"
: "${RESOLUTION:=1920x1080}"
: "${VNC_PASSWORD:=changeme}"

# -------------------------------------------------
# Dynamic CUDA Integration
# -------------------------------------------------
for cuda_dir in /usr/local/cuda-*; do
    if [ -d "$cuda_dir" ]; then
        echo "[startup] Found CUDA at $cuda_dir. Updating paths..."
        export PATH="$cuda_dir/bin:$PATH"
        export LD_LIBRARY_PATH="$cuda_dir/lib64:$LD_LIBRARY_PATH"
        break 
    fi
done

# -------------------------------------------------
# Dimension Export for Supervisor
# -------------------------------------------------
export WIDTH=$(echo "$RESOLUTION" | cut -d'x' -f1)
export HEIGHT=$(echo "$RESOLUTION" | cut -d'x' -f2)

echo "[startup] Display: $DISPLAY"
echo "[startup] Resolution: ${WIDTH}x${HEIGHT}"

# -------------------------------------------------
# Prepare Environment
# -------------------------------------------------
mkdir -p /tmp/.X11-unix /root/.vnc /var/run/dbus
chmod 1777 /tmp/.X11-unix

# -------------------------------------------------
# D-Bus Initialization
# -------------------------------------------------
# Clean up potential stale locks
rm -f /var/run/dbus/pid /var/run/dbus/system_bus_socket

# Generate machine-id (required for apps to launch)
dbus-uuidgen > /var/lib/dbus/machine-id

# Start System Bus
dbus-daemon --config-file=/usr/share/dbus-1/system.conf --print-address

# Start Session Bus (Critical for pcmanfm)
# We export these variables so Supervisor processes inherit them
echo "[startup] Starting D-Bus Session Bus..."
eval $(dbus-launch --sh-syntax)
export DBUS_SESSION_BUS_ADDRESS
export DBUS_SESSION_BUS_PID

# -------------------------------------------------
# VNC Password Setup
# -------------------------------------------------
VNC_PASS_FILE=/root/.vnc/passwd
rm -f "$VNC_PASS_FILE"
x11vnc -storepasswd "$VNC_PASSWORD" "$VNC_PASS_FILE"


# -------------------------------------------------
# Theming & Wallpaper Configuration
# -------------------------------------------------
mkdir -p /root/.config/pcmanfm/LXDE/
mkdir -p /root/.config/lxsession/LXDE/
mkdir -p /root/.config/gtk-3.0/

# 1. Set Wallpaper (pcmanfm config)
# We use the standard Ubuntu wallpaper installed by 'ubuntu-wallpapers'
cat <<EOF > /root/.config/pcmanfm/LXDE/desktop-items-0.conf
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

# 2. Set Dark Theme & Icons (LXDE config)
# Sets Arc-Dark theme and Papirus icons
cat <<EOF > /root/.config/lxsession/LXDE/desktop.conf
[Session]
lock_manager/command=

[GTK]
sNet/ThemeName=Arc-Dark
sNet/IconThemeName=Papirus
sGtk/FontName=Sans 10
iGtk/ToolbarStyle=3
EOF

# 3. Force GTK3 apps (like Terminal/VS Code) to use the Dark Theme
cat <<EOF > /root/.config/gtk-3.0/settings.ini
[Settings]
gtk-theme-name=Arc-Dark
gtk-icon-theme-name=Papirus
gtk-font-name=Sans 10
gtk-cursor-theme-name=Adwaita
EOF

# -------------------------------------------------
# Start Supervisor
# -------------------------------------------------
echo "[startup] Launching Supervisor..."
exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf