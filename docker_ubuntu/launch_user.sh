#!/bin/bash
# ============================================================================
# launch_user.sh - Launch a per-user Ubuntu desktop container
# ============================================================================
# Usage: ./launch_user.sh <username> <http_port> <vnc_port>
#
# Description:
#   Launches an isolated ubuntu-desktop container for a specific user.
#   Reads /mount/Data2/<username>/mounts.conf to generate ephemeral extra
#   volume mounts via a compose override file. The workspace directory and
#   a template mounts.conf are created automatically on first run.
#
# Arguments:
#   username   Name used for the container, project, and data directories
#   http_port  Host port mapped to container port 80 (noVNC web UI)
#   vnc_port   Host port mapped to container port 5900 (raw VNC)
#
# mounts.conf format:
#   # comment
#   /host/path:/container/path:ro
#   /host/path:/container/path:rw
# ============================================================================

set -euo pipefail

# -------------------------------------------------
# 1. Argument Parsing and Validation
# -------------------------------------------------
if [ "${#}" -lt 3 ]; then
    echo "Usage: ./launch_user.sh <username> <http_port> <vnc_port>"
    exit 1
fi

USER_NAME="${1}"
HTTP_PORT="${2}"
VNC_PORT="${3}"

if ! [[ "${HTTP_PORT}" =~ ^[0-9]+$ ]] || ! [[ "${VNC_PORT}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: http_port and vnc_port must be integers."
    exit 1
fi

# -------------------------------------------------
# 2. VNC Password Prompt
# -------------------------------------------------
read -r -s -p "Enter VNC password for ${USER_NAME}: " VNC_PASSWORD
echo ""

if [ -z "${VNC_PASSWORD}" ]; then
    echo "ERROR: VNC password cannot be empty."
    exit 1
fi

# -------------------------------------------------
# 3. Host UID/GID Detection
# -------------------------------------------------
MY_UID=$(id -u)
MY_GID=$(id -g)

# -------------------------------------------------
# 4. User Data Directory and mounts.conf Setup
# -------------------------------------------------
USER_DATA_DIR="/mount/Data2/${USER_NAME}"
U_WORKSPACE="${USER_DATA_DIR}/workspace"
MOUNTS_CONF="${USER_DATA_DIR}/mounts.conf"

mkdir -p "${U_WORKSPACE}"

# Write a template mounts.conf if none exists
if [ ! -f "${MOUNTS_CONF}" ]; then
    cat > "${MOUNTS_CONF}" <<'CONF'
# mounts.conf - Extra volume mounts for this user's desktop container
#
# Format (one mount per line):
#   host_path:container_path:mode
#
#   host_path      absolute path on the host
#   container_path absolute path inside the container
#   mode           ro (read-only) or rw (read-write)
#
# Lines starting with # and blank lines are ignored.
# The /root/workspace mount is already defined in compose.yaml; do not repeat it here.
#
# Examples:
#   /mount/Data2/shared/datasets:/root/datasets:ro
#   /mount/Data2/${USER}/codebase:/root/codebase:rw
CONF
    echo "INFO: Created template mounts.conf at ${MOUNTS_CONF}"
fi

# -------------------------------------------------
# 5. Parse mounts.conf and Build Extra Volume List
# -------------------------------------------------
EXTRA_VOLUMES=()

while IFS= read -r line; do
    # Strip leading/trailing whitespace
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    # Skip comments and blank lines
    [[ -z "${line}" || "${line}" == \#* ]] && continue

    # Basic format check: must contain exactly two colons
    colon_count=$(echo "${line}" | tr -cd ':' | wc -c)
    if [ "${colon_count}" -lt 2 ]; then
        echo "WARN: Skipping invalid mounts.conf entry (expected host:container:mode): ${line}"
        continue
    fi

    HOST_PATH=$(echo "${line}" | cut -d':' -f1)
    CONTAINER_PATH=$(echo "${line}" | cut -d':' -f2)
    MODE=$(echo "${line}" | cut -d':' -f3)

    # Validate mode
    if [[ "${MODE}" != "ro" && "${MODE}" != "rw" ]]; then
        echo "WARN: Skipping entry with unknown mode '${MODE}' (use ro or rw): ${line}"
        continue
    fi

    # Guard the reserved workspace mount
    if [ "${CONTAINER_PATH}" = "/root/workspace" ]; then
        echo "WARN: /root/workspace is reserved in compose.yaml; skipping: ${line}"
        continue
    fi

    # Validate host path existence
    if [ ! -e "${HOST_PATH}" ]; then
        echo "WARN: Host path does not exist, skipping: ${HOST_PATH}"
        continue
    fi

    EXTRA_VOLUMES+=("      - ${HOST_PATH}:${CONTAINER_PATH}:${MODE}")
    echo "INFO: Adding mount: ${HOST_PATH} -> ${CONTAINER_PATH} (${MODE})"

done < "${MOUNTS_CONF}"

# -------------------------------------------------
# 6. Generate Ephemeral Compose Override File
# -------------------------------------------------
OVERRIDE_FILE="/tmp/${USER_NAME}_compose_override.yml"

# Remove the override file on exit (success or failure)
trap 'rm -f "${OVERRIDE_FILE}"' EXIT

if [ "${#EXTRA_VOLUMES[@]}" -gt 0 ]; then
    {
        echo "services:"
        echo "  ubuntu-desktop:"
        echo "    volumes:"
        for vol in "${EXTRA_VOLUMES[@]}"; do
            echo "${vol}"
        done
    } > "${OVERRIDE_FILE}"
    echo "INFO: Generated compose override at ${OVERRIDE_FILE} with ${#EXTRA_VOLUMES[@]} extra mount(s)."
    COMPOSE_OVERRIDE_ARGS=(-f "${OVERRIDE_FILE}")
else
    echo "INFO: No extra mounts; running without compose override."
    COMPOSE_OVERRIDE_ARGS=()
fi

# -------------------------------------------------
# 7. Launch Container
# -------------------------------------------------
echo "INFO: Starting container for user '${USER_NAME}'..."

CONTAINER_NAME="${USER_NAME}_desktop" \
HOST_UID="${MY_UID}" \
HOST_GID="${MY_GID}" \
HTTP_PORT="${HTTP_PORT}" \
VNC_PORT="${VNC_PORT}" \
VNC_PASSWORD="${VNC_PASSWORD}" \
HOST_WORKSPACE="${U_WORKSPACE}" \
docker compose \
    -p "${USER_NAME}_project" \
    -f compose.yaml \
    "${COMPOSE_OVERRIDE_ARGS[@]}" \
    up -d

# -------------------------------------------------
# 8. Print Access Information
# -------------------------------------------------
HOST_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "============================================================"
echo " Container started for user: ${USER_NAME}"
echo " noVNC (browser): http://${HOST_IP}:${HTTP_PORT}"
echo " VNC (client):    ${HOST_IP}:${VNC_PORT}"
echo " Workspace:       ${U_WORKSPACE}"
echo "============================================================"
