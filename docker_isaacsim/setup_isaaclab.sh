#!/usr/bin/env bash
# ============================================================================
# Isaac Lab Python Environment Setup
# ============================================================================
# Description:
#   One-time setup script that creates a persistent Python virtual environment
#   in /root/workspace/.isaaclab_env (survives container restarts via the workspace
#   bind-mount) and installs all Isaac Lab Python extensions into it.
#
#   Run this ONCE per user workspace after launching the container:
#       bash /setup_isaaclab.sh
#
# What it does:
#   1. Creates a Python 3.10 venv at /root/workspace/.isaaclab_env
#   2. Adds Isaac Sim's python_packages to the venv's PYTHONPATH
#   3. Installs PyTorch (CUDA-compatible) into the venv
#   4. Installs all IsaacLab source extensions via pip install -e
#   5. Writes /etc/profile.d/isaaclab_venv.sh so every new terminal
#      auto-activates the venv
#
# Environment Variables (all have defaults from compose.yaml):
#   ISAACSIM_PATH   - Isaac Sim installation root  (default: /root/IsaacSim)
#   ISAACLAB_PATH   - Isaac Lab source root         (default: /root/IsaacLab)
#
# Usage:
#   bash /setup_isaaclab.sh            # normal install
#   bash /setup_isaaclab.sh --force    # re-install even if venv exists
# ============================================================================

set -e

log()  { echo "[$(date +'%H:%M:%S')] [SETUP] $*"; }
fail() { echo "[$(date +'%H:%M:%S')] [ERROR] $*" >&2; exit 1; }

# -----------------------------------------------------------------------
# 0. Defaults & argument parsing
# -----------------------------------------------------------------------
FORCE_REINSTALL=false
for arg in "$@"; do
    case "$arg" in
        --force) FORCE_REINSTALL=true ;;
        -h|--help)
            sed -n '2,40p' "$0" | grep '^#' | sed 's/^# *//'
            exit 0 ;;
    esac
done

: "${ISAACSIM_PATH:=/root/IsaacSim/_build/linux-x86_64/release}"
: "${ISAACLAB_PATH:=/root/IsaacLab}"

VENV_DIR="/root/workspace/.isaaclab_env"
SENTINEL_FILE="$VENV_DIR/.setup_complete"
PROFILE_SCRIPT="/etc/profile.d/isaaclab_venv.sh"

# -----------------------------------------------------------------------
# 1. Pre-flight checks
# -----------------------------------------------------------------------
log "Checking prerequisites..."
[ -d "$ISAACSIM_PATH" ] || fail "Isaac Sim not found at $ISAACSIM_PATH. Is the volume mounted?"
[ -d "$ISAACLAB_PATH" ]  || fail "Isaac Lab not found at $ISAACLAB_PATH. Is the volume mounted?"
[ -d "/root/workspace" ]   || fail "/root/workspace directory not found. Is the workspace volume mounted?"

ISAAC_PYTHON="$ISAACSIM_PATH/python.sh"
[ -x "$ISAAC_PYTHON" ]    || fail "Isaac Sim python.sh not found at $ISAAC_PYTHON"

log "  ISAACSIM_PATH = $ISAACSIM_PATH"
log "  ISAACLAB_PATH = $ISAACLAB_PATH"
log "  VENV_DIR      = $VENV_DIR"

# -----------------------------------------------------------------------
# 2. Skip if already set up (unless --force)
# -----------------------------------------------------------------------
if [ -f "$SENTINEL_FILE" ] && [ "$FORCE_REINSTALL" = false ]; then
    log "Isaac Lab environment already set up at $VENV_DIR"
    log "Run with --force to reinstall. Activating..."
    # shellcheck source=/dev/null
    source "$VENV_DIR/bin/activate"
    log "Activated! Use 'isaaclab-python <script>' or 'python <script>' to run scripts."
    exit 0
fi

# -----------------------------------------------------------------------
# 3. Determine Python 3.10 executable (Isaac Sim ships Python 3.10)
# -----------------------------------------------------------------------
PYTHON310=""
for candidate in python3.10 "$ISAACSIM_PATH/kit/python/bin/python3.10" python3; do
    if command -v "$candidate" &>/dev/null; then
        PY_VER=$("$candidate" -c "import sys; print(sys.version_info[:2])" 2>/dev/null || true)
        if [[ "$PY_VER" == "(3, 10)" ]]; then
            PYTHON310=$(command -v "$candidate")
            break
        fi
    fi
done

# Fallback: use system python3 if 3.10 not found
if [ -z "$PYTHON310" ]; then
    log "WARN: Python 3.10 not found; falling back to $(python3 --version 2>&1)"
    PYTHON310=$(command -v python3)
    PY_VER=$($PYTHON310 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || true)
    if [[ ! "$PY_VER" =~ ^3\.(10|11)$ ]]; then
        fail "Python must be 3.10 or 3.11, got $PY_VER. Isaac Sim omni.* modules are Python 3.10 compiled."
    fi
fi
log "Using Python: $PYTHON310 ($($PYTHON310 --version 2>&1))"

# -----------------------------------------------------------------------
# 4. Pre-flight disk space check
# -----------------------------------------------------------------------
AVAILABLE=$(df "$VENV_DIR" | awk 'NR==2 {print $4}')  # Available KB
REQUIRED_KB=$((5 * 1024 * 1024))  # 5 GB minimum
if [ \"$AVAILABLE\" -lt \"$REQUIRED_KB\" ]; then\n    fail \"Insufficient disk space: $(($AVAILABLE / 1024 / 1024)) GB available, need 5 GB at $VENV_DIR\"\nfi\nlog \"Disk space OK: $(($AVAILABLE / 1024 / 1024)) GB available\"\n\n# -----------------------------------------------------------------------
# 5. Create virtual environment
# -----------------------------------------------------------------------
log \"Creating virtual environment at $VENV_DIR ...\"\nrm -rf \"$VENV_DIR\"\n\"$PYTHON310\" -m venv \"$VENV_DIR\""

# Activate for this session
# shellcheck source=/dev/null
source "$VENV_DIR/bin/activate"
log "Virtual environment activated."

# -----------------------------------------------------------------------
# 5. Inject Isaac Sim python_packages into the venv PYTHONPATH
# -----------------------------------------------------------------------
ISAACSIM_PY_PKGS="$ISAACSIM_PATH/python_packages"
if [ -d "$ISAACSIM_PY_PKGS" ]; then
    log "Injecting Isaac Sim python_packages into venv PYTHONPATH..."
    # Write a .pth file — Python automatically adds every path in .pth files
    SITE_PKGS="$(python -c 'import site; print(site.getsitepackages()[0])')"
    echo "$ISAACSIM_PY_PKGS" > "$SITE_PKGS/isaacsim_python_packages.pth"
    
    # Also add kit-sdk python packages if present
    KIT_PY_PKGS="$ISAACSIM_PATH/kit/python/lib/python3.10/site-packages"
    [ -d "$KIT_PY_PKGS" ] && echo "$KIT_PY_PKGS" >> "$SITE_PKGS/isaacsim_python_packages.pth"
    
    log "Injected: $ISAACSIM_PY_PKGS"
else
    log "WARN: $ISAACSIM_PY_PKGS not found — omni.* imports may fail without it"
fi

# -----------------------------------------------------------------------
# 6. Upgrade pip and install wheel/setuptools
# -----------------------------------------------------------------------
log "Upgrading pip / setuptools / wheel..."
pip install --upgrade pip setuptools wheel

# -----------------------------------------------------------------------
# 7. Install PyTorch (CUDA-compatible with Isaac Sim 5.1 / CUDA 12.x)
# -----------------------------------------------------------------------
# Isaac Sim 5.1 ships with CUDA 12.x libraries; torch 2.5.1+cu121 is a
# recommended pairing. Adjust the index URL for your CUDA driver version.
log "Installing PyTorch (CUDA 12.1 build) — this may take several minutes..."
pip install \
    torch==2.5.1+cu121 \
    torchvision==0.20.1+cu121 \
    --extra-index-url https://download.pytorch.org/whl/cu121

# -----------------------------------------------------------------------
# 8. Install IsaacLab Python extensions (source/editable installs)
# -----------------------------------------------------------------------
log "Installing IsaacLab extensions..."

# Core extensions (always required)
CORE_EXTENSIONS=(
    "$ISAACLAB_PATH/source/isaaclab"
    "$ISAACLAB_PATH/source/isaaclab_assets"
    "$ISAACLAB_PATH/source/isaaclab_tasks"
)

for ext in "${CORE_EXTENSIONS[@]}"; do
    if [ -d "$ext" ] && [ -f "$ext/setup.py" -o -f "$ext/pyproject.toml" ]; then
        log "  Installing $(basename $ext)..."
        pip install -e "$ext" || fail "CRITICAL: Failed to install core extension $(basename $ext). Check output above."
    else
        log "  SKIP: $ext not found or missing setup files"
    fi
done

# Optional extensions — install if present
OPTIONAL_EXTENSIONS=(
    "$ISAACLAB_PATH/source/isaaclab_mimic"
    "$ISAACLAB_PATH/source/isaaclab_rl"
)
for ext in "${OPTIONAL_EXTENSIONS[@]}"; do
    if [ -d "$ext" ] && [ -f "$ext/setup.py" -o -f "$ext/pyproject.toml" ]; then
        log "  Installing optional: $(basename $ext)..."
        pip install --quiet -e "$ext" || log "  WARN: optional extension $(basename $ext) failed, skipping"
    fi
done

# Common RL libraries used with Isaac Lab
log "Installing RL libraries (rsl_rl, stable-baselines3, skrl)..."
pip install \
    rsl-rl \
    stable-baselines3 \
    "skrl>=1.3.0" \
    tensorboard \
    hydra-core \
    omegaconf \
    || log "WARN: Some RL libraries failed to install — check pip output above"

# -----------------------------------------------------------------------
# 9. Write auto-activation profile script
# -----------------------------------------------------------------------
log "Writing $PROFILE_SCRIPT for auto-activation in all terminals..."
cat > "$PROFILE_SCRIPT" <<PROFILE_EOF
#!/bin/bash
# Auto-activate IsaacLab virtual environment (generated by setup_isaaclab.sh)
if [ -f "$VENV_DIR/bin/activate" ]; then
    source "$VENV_DIR/bin/activate"
fi
PROFILE_EOF
chmod +x "$PROFILE_SCRIPT"

# -----------------------------------------------------------------------
# 10. Stamp sentinel and print summary
# -----------------------------------------------------------------------
date > "$SENTINEL_FILE"
log "============================================================"
log " Isaac Lab Python environment setup COMPLETE"
log "============================================================"
log " Virtual env : $VENV_DIR"
log " Auto-active : $PROFILE_SCRIPT (all new terminals)"
log ""
log " Quick-start commands:"
log "   isaaclab-python source/standalone/tutorials/00_sim/create_empty.py"
log "   isaaclab-python source/standalone/workflows/rsl_rl/train.py \\"
log "       task=Isaac-Cartpole-v0 headless=True"
log ""
log " Re-run with --force to rebuild the environment."
log "============================================================"
