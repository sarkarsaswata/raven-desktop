#!/bin/bash
# Usage: ./launch_user.sh <username> <http_port> <vnc_port>

# --- 1. USER INPUT ---
USER_NAME=$1
HTTP_P=$2
VNC_P=$3

if [ -z "$VNC_P" ]; then
    echo "Usage: ./launch_user.sh <username> <http_port> <vnc_port>"
    exit 1
fi

read -s -p "Enter VNC Password for $USER_NAME: " USER_PASS
echo ""

# --- 2. DYNAMIC HOST IDs ---
# Grabs your current User and Group IDs (e.g., 1009) to prevent "Locked" files on Data2
MY_UID=$(id -u)
MY_GID=$(id -g)

# --- 3. STORAGE SETUP ---
# Creates unique folders on the Data2 HDD to protect the 82.4 GB SSD space
U_WORKSPACE="/mount/Data2/${USER_NAME}/workspace"
U_DATA="/mount/Data2/${USER_NAME}/omni_data"
mkdir -p "$U_WORKSPACE" "$U_DATA"

# --- 4. DEPLOYMENT ---
# Uses -p (Project Name) to allow multiple simultaneous containers
CONTAINER_NAME="${USER_NAME}_isaac" \
HOST_UID=$MY_UID \
HOST_GID=$MY_GID \
USER_NAME=$USER_NAME \
HTTP_PORT=$HTTP_P \
VNC_PORT=$VNC_P \
VNC_PASSWORD=$USER_PASS \
HOST_WORKSPACE=$U_WORKSPACE \
HOST_USER_DATA=$U_DATA \
docker compose -p "${USER_NAME}_project" up -d

echo "Container launched: http://localhost:$HTTP_P"
SSH_IP=$(hostname -I | awk '{print $1}')
echo "Access via $SSH_IP"
