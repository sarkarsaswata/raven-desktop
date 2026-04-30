#!/usr/bin/env bash
# ============================================================================
# Isaac Lab Python Environment Setup (UV-based - Fast & Modern)
# ============================================================================
# Description:
#   Modern Python environment setup using `uv` (extremely fast package manager).
#   Creates a persistent Python virtual environment in /root/workspace/.isaaclab_env
#   with all Isaac Lab extensions and cached dependencies.
#
#   Run this ONCE per user workspace after launching the container:
#       bash /setup_isaaclab_uv.sh
#
# What it does:
#   1. Creates a Python 3.10 venv at /root/workspace/.isaaclab_env using `uv`
#   2. Adds Isaac Sim's python_packages to the venv's PYTHONPATH via .pth
#   3. Installs PyTorch 2.9.1+cu128 (NVIDIA's official cuDNN build)
#   4. Installs all IsaacLab source extensions via pip install -e
#   5. Writes /etc/profile.d/isaaclab_venv.sh for auto-activation
#   6. Creates /root/workspace/.uv-cache for persistent dependency caching
#
# Environment Variables (all have defaults):
#   ISAACSIM_PATH   - Isaac Sim installation root  (default: /root/IsaacSim)
#   ISAACLAB_PATH   - Isaac Lab source root         (default: /root/IsaacLab)
#   UV_CACHE_DIR    - UV cache location (for fast rebuilds)
#
# Usage:
#   bash /setup_isaaclab_uv.sh            # normal install
#   bash /setup_isaaclab_uv.sh --force    # re-install even if venv exists
#   bash /setup_isaaclab_uv.sh --use-pip  # fallback to pip if uv fails
#
# Performance:
#   - First run: ~3-5 minutes (downloads & builds)
#   - Subsequent runs (--force): ~1-2 minutes (uses cache)
# ============================================================================

set -e

log()  { echo "[$(date +'%H:%M:%S')] [SETUP] $*"; }
fail() { echo "[$(date +'%H:%M:%S')] [ERROR] $*" >&2; exit 1; }

# -----------------------------------------------------------------------
# 0. Argument parsing
# -----------------------------------------------------------------------
FORCE_REINSTALL=false
USE_PIP_FALLBACK=false

for arg in "$@"; do
    case "$arg" in
        --force) FORCE_REINSTALL=true ;;
        --use-pip) USE_PIP_FALLBACK=true ;;
        -h|--help)
            sed -n '2,50p' "$0" | grep '^#' | sed 's/^# *//'
            exit 0 ;;
    esac
done

: "${ISAACSIM_PATH:=/root/IsaacSim/_build/linux-x86_64/release}"
: "${ISAACLAB_PATH:=/root/IsaacLab}"
: "${UV_CACHE_DIR:=/root/workspace/.uv-cache}"

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

log "  ISAACSIM_PATH = $ISAACSIM_PATH"
log "  ISAACLAB_PATH = $ISAACLAB_PATH"
log "  VENV_DIR      = $VENV_DIR"
log "  UV_CACHE_DIR  = $UV_CACHE_DIR"

# -----------------------------------------------------------------------
# 2. Skip if already set up (unless --force)
# -----------------------------------------------------------------------
if [ -f "$SENTINEL_FILE" ] && [ "$FORCE_REINSTALL" = false ]; then
    log "Isaac Lab environment already set up at $VENV_DIR"
    log "Run with --force to reinstall. Activating..."
    # shellcheck source=/dev/null
    source "$VENV_DIR/bin/activate"
    log "Activated! Use 'isaaclab-python <script>' to run scripts."
    exit 0
fi

# -----------------------------------------------------------------------
# 3. Determine Python 3.10 executable
# -----------------------------------------------------------------------
PYTHON310=""
for candidate in python3.10 "$ISAACSIM_PATH/kit/python/bin/python3.10" python3; do
    if command -v "$candidate" &>/dev/null; then
        PY_VER=$("$candidate" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || true)
        if [[ "$PY_VER" == "3.10" ]]; then
            PYTHON310=$(command -v "$candidate")
            break
        fi
    fi
done

# Fallback with version check
if [ -z "$PYTHON310" ]; then
    PYTHON310=$(command -v python3)
    PY_VER=$($PYTHON310 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || true)
    if [[ ! "$PY_VER" =~ ^3\.(10|11)$ ]]; then
        fail "Python must be 3.10 or 3.11, got $PY_VER. Isaac Sim omni.* modules require Python 3.10."
    fi
fi
log "Using Python: $PYTHON310 ($($PYTHON310 --version 2>&1))"

# -----------------------------------------------------------------------
# 4. Pre-flight disk space check
# -----------------------------------------------------------------------
AVAILABLE=$(df "$VENV_DIR" | awk 'NR==2 {print $4}')  # Available KB
REQUIRED_KB=$((5 * 1024 * 1024))  # 5 GB minimum
if [ "$AVAILABLE" -lt "$REQUIRED_KB" ]; then
    fail "Insufficient disk space: $(($AVAILABLE / 1024 / 1024)) GB available, need 5 GB at $VENV_DIR"
fi
log "Disk space OK: $(($AVAILABLE / 1024 / 1024)) GB available"

# -----------------------------------------------------------------------
# 5. Create virtual environment (using UV if available, else Python)
# -----------------------------------------------------------------------
log "Creating virtual environment at $VENV_DIR..."
rm -rf "$VENV_DIR"

if command -v uv &>/dev/null && [ "$USE_PIP_FALLBACK" = false ]; then
    log "Using UV (fast package installer)..."
    mkdir -p "$UV_CACHE_DIR"
    UV_CACHE_DIR="$UV_CACHE_DIR" uv venv "$VENV_DIR" --python="$PYTHON310"
else
    log "Using standard Python venv..."
    "$PYTHON310" -m venv "$VENV_DIR"
fi

# Activate for this session
# shellcheck source=/dev/null
source "$VENV_DIR/bin/activate"
log "Virtual environment activated."

# -----------------------------------------------------------------------
# 6. Inject Isaac Sim python_packages into the venv PYTHONPATH
# -----------------------------------------------------------------------
log "Injecting Isaac Sim python_packages into venv..."
ISAACSIM_PY_PKGS="$ISAACSIM_PATH/python_packages"
if [ -d "$ISAACSIM_PY_PKGS" ]; then
    SITE_PKGS=$(python -c 'import site; print(site.getsitepackages()[0])')
    
    # Create .pth file so Isaac Sim modules are always importable
    cat > "$SITE_PKGS/isaacsim_python_packages.pth" <<'PTHEOF'
# Isaac Sim Python packages - auto-generated by setup_isaaclab_uv.sh
/root/IsaacSim/python_packages
/root/IsaacSim/kit/python/lib/python3.10/site-packages
PTHEOF
    
    log "  ✓ Isaac Sim packages injected via $SITE_PKGS/isaacsim_python_packages.pth"
else
    log "  WARN: $ISAACSIM_PY_PKGS not found — omni.* imports may fail without it"
fi

# -----------------------------------------------------------------------
# 7. Upgrade pip, setuptools, wheel
# -----------------------------------------------------------------------
log "Upgrading pip, setuptools, wheel..."
if command -v uv &>/dev/null && [ "$USE_PIP_FALLBACK" = false ]; then
    UV_CACHE_DIR="$UV_CACHE_DIR" uv pip install --upgrade pip setuptools wheel
else
    pip install --upgrade pip setuptools wheel
fi

# -----------------------------------------------------------------------
# 8. Install PyTorch + torchvision + torchaudio (CUDA 12.8 build)
# -----------------------------------------------------------------------
log "Installing PyTorch 2.9.1 + torchvision + torchaudio (CUDA 12.8 build)..."
log "  This step may take 3-5 minutes (packages are cached on subsequent runs)..."

if command -v uv &>/dev/null && [ "$USE_PIP_FALLBACK" = false ]; then
    UV_CACHE_DIR="$UV_CACHE_DIR" uv pip install \
        torch==2.9.1 \
        torchvision==0.24.1 \
        torchaudio==2.9.1 \
        --index-url https://download.pytorch.org/whl/cu128
else
    pip install \
        torch==2.9.1 \
        torchvision==0.24.1 \
        torchaudio==2.9.1 \
        --index-url https://download.pytorch.org/whl/cu128
fi

log "  ✓ PyTorch 2.9.1 installed (CUDA 12.8 compatible)"

# -----------------------------------------------------------------------
# 9. Install IsaacLab Python extensions (source/editable installs)
# -----------------------------------------------------------------------
log "Installing IsaacLab extensions (this may take 2-3 minutes)..."

# Core extensions (always required)
CORE_EXTENSIONS=(
    "$ISAACLAB_PATH/source/isaaclab"
    "$ISAACLAB_PATH/source/isaaclab_assets"
    "$ISAACLAB_PATH/source/isaaclab_tasks"
)

for ext in "${CORE_EXTENSIONS[@]}"; do
    if [ -d "$ext" ] && [ -f "$ext/setup.py" -o -f "$ext/pyproject.toml" ]; then
        log "  Installing $(basename $ext)..."
        if command -v uv &>/dev/null && [ "$USE_PIP_FALLBACK" = false ]; then
            UV_CACHE_DIR="$UV_CACHE_DIR" uv pip install -e "$ext" || fail "CRITICAL: Failed to install $(basename $ext)"
        else
            pip install -e "$ext" || fail "CRITICAL: Failed to install $(basename $ext)"
        fi
    else
        log "  SKIP: $ext not found or missing setup config"
    fi
done

# Optional extensions (nice-to-have)
log "Installing optional extensions..."
OPTIONAL_EXTENSIONS=(
    "$ISAACLAB_PATH/source/isaaclab_mimic"
    "$ISAACLAB_PATH/source/isaaclab_rl"
)

for ext in "${OPTIONAL_EXTENSIONS[@]}"; do
    if [ -d "$ext" ] && [ -f "$ext/setup.py" -o -f "$ext/pyproject.toml" ]; then
        log "  Installing optional: $(basename $ext)..."
        if command -v uv &>/dev/null && [ "$USE_PIP_FALLBACK" = false ]; then
            UV_CACHE_DIR="$UV_CACHE_DIR" uv pip install -e "$ext" || log "    WARN: optional extension $(basename $ext) failed, continuing"
        else
            pip install -e "$ext" || log "    WARN: optional extension $(basename $ext) failed, continuing"
        fi
    fi
done

# -----------------------------------------------------------------------
# 10. Install common RL libraries
# -----------------------------------------------------------------------
log "Installing RL libraries (rsl_rl, stable-baselines3, skrl, tensorboard, hydra)..."

if command -v uv &>/dev/null && [ "$USE_PIP_FALLBACK" = false ]; then
    UV_CACHE_DIR="$UV_CACHE_DIR" uv pip install \
        rsl-rl \
        stable-baselines3 \
        "skrl>=1.3.0" \
        tensorboard \
        hydra-core \
        omegaconf \
        || log "  WARN: Some RL libraries failed; this may be expected for optional deps"
else
    pip install \
        rsl-rl \
        stable-baselines3 \
        "skrl>=1.3.0" \
        tensorboard \
        hydra-core \
        omegaconf \
        || log "  WARN: Some RL libraries failed; this may be expected for optional deps"
fi

log "  ✓ RL libraries installed"

# -----------------------------------------------------------------------
# 11. Write auto-activation profile script
# -----------------------------------------------------------------------
log "Writing $PROFILE_SCRIPT for auto-activation..."
cat > "$PROFILE_SCRIPT" <<PROFILE_EOF
#!/bin/bash
# Auto-activate IsaacLab virtual environment (generated by setup_isaaclab_uv.sh)
# This script is sourced by /etc/profile.d/ in every new shell session
if [ -f "$VENV_DIR/bin/activate" ]; then
    source "$VENV_DIR/bin/activate"
    # Set UV cache for future use if uv is available
    export UV_CACHE_DIR="$UV_CACHE_DIR"
fi
PROFILE_EOF
chmod +x "$PROFILE_SCRIPT"

# -----------------------------------------------------------------------
# 12. Stamp sentinel and print summary
# -----------------------------------------------------------------------
date > "$SENTINEL_FILE"
log "============================================================"
log " Isaac Lab Python environment setup COMPLETE ✓"
log "============================================================"
log " Venv location    : $VENV_DIR"
log " Python version   : $($PYTHON310 --version 2>&1)"
log " PyTorch version  : $(python -c 'import torch; print(torch.__version__)')"
log " CUDA available   : $(python -c 'import torch; print(torch.cuda.is_available())')"
log " Auto-activate    : $PROFILE_SCRIPT"
if command -v uv &>/dev/null && [ "$USE_PIP_FALLBACK" = false ]; then
    log " Package manager  : UV (fast)"
    log " Cache directory  : $UV_CACHE_DIR"
else
    log " Package manager  : pip (standard)"
fi
log ""
log " Quick-start commands:"
log "   isaaclab-python source/standalone/tutorials/00_sim/create_empty.py"
log "   isaaclab-python source/standalone/workflows/rsl_rl/train.py \\"
log "       task=Isaac-Cartpole-v0 headless=True num_envs=4096"
log ""
log " Re-run with --force to rebuild the environment."
log "============================================================"
