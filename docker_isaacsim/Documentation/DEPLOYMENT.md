# Isaac Sim + Isaac Lab Docker Deployment Guide

**Version**: 1.1 (Production-Ready with UV Support)  
**Date**: February 2026  
**Status**: Safe for multi-user production deployment  
**PyTorch**: 2.9.1+cu128 (CUDA 12.8 compatible)  
**Setup Time**: 3-5 minutes (with UV caching) or 5-10 minutes (traditional venv)

---

## Pre-Deployment Checklist

### 1. Host System Requirements

```bash
# Required
✓ Ubuntu 22.04 LTS
✓ NVIDIA GPU (RTX or better, 12GB+ VRAM recommended)
✓ NVIDIA Driver 535+
✓ Docker 24.0+
✓ NVIDIA Container Toolkit installed and configured
✓ At least 120GB free disk space (SSD for /workspace recommended)

# Check driver
nvidia-smi

# Check Docker works with GPU
docker run --rm --runtime=nvidia nvidia/cuda:12.4.0-base nvidia-smi
```

### 2. One-Time Host Setup (CRITICAL)

This step **must be completed before starting any containers**.

```bash
# Step 1: Create the _isaac_sim symlink that isaaclab.sh requires
# This symlink points Isaac Lab to the read-only Isaac Sim installation
ln -sfn /root/isaacsim /mount/Data2/saswata/isaac_sim_storage/IsaacLab/_isaac_sim

# Verify it was created
ls -la /mount/Data2/saswata/isaac_sim_storage/IsaacLab/ | grep _isaac_sim
# Expected: _isaac_sim -> /root/isaacsim

# Step 2: Verify all storage paths are accessible
df /mount/Data2/saswata/isaac_sim_storage/app
df /mount/Data2/saswata/isaac_sim_storage/assets_root
df /mount/Data2/saswata/isaac_sim_storage/IsaacLab

# Step 3: Verify Isaac Sim installation integrity
[ -x /mount/Data2/saswata/isaac_sim_storage/app/isaac-sim.sh ] && echo "✓ Isaac Sim OK" || echo "✗ Isaac Sim MISSING"

# Step 4: Verify Isaac Lab files exist
[ -d /mount/Data2/saswata/isaac_sim_storage/IsaacLab/source ] && echo "✓ IsaacLab OK" || echo "✗ IsaacLab MISSING"
```

**If setup is incomplete, containers will FAIL to start with clear error messages.**

---

## Build & Deploy

### Build the Docker Image

```bash
cd /home/saswata/raven-desktop/docker_isaacsim
./build.sh

# Verify image built
docker images | grep isaac
```

**Build time**: ~10-15 minutes (first build, subsequent builds are cached)

### Launch a Container for User

```bash
# First-time user setup
./launch_user.sh alice 8081 9091

# This will:
# 1. Create /mount/Data2/alice/workspace and /mount/Data2/alice/omni_data
# 2. Prompt for VNC password
# 3. Launch container with unique port bindings
# 4. Print access URLs

# Example output:
# Container launched: http://localhost:8081
# Access via 192.168.1.100
```

### Access the Container

**Via Web Browser (noVNC):**

```bash
http://localhost:8081
```

**Via VNC Client (TightVNC, RealVNC, etc):**

```bash
192.168.1.100:9091
```

**Via SSH into Host → Inside Container:**

```bash
docker exec -it alice_isaac bash
```

---

## 🔧 First-Time Inside Container Setup

### 1. Open Terminal (inside VNC)

Click **Terminal** icon on desktop or use `Ctrl+Alt+T`

### 2. Set Up Isaac Lab Python Environment (ONE-TIME)

Choose **Option A (UV - Recommended)** for fastest setup, or **Option B (Traditional)** if you need compatibility.

#### Option A: UV-Based Setup (3-5 minutes, with caching)

```bash
# Creates a Python venv at /workspace/.isaaclab_env with PyTorch 2.9.1+cu128
# Uses UV (extremely fast package manager bundled in the image)
bash /setup_isaaclab_uv.sh

# If UV fails for any reason, fallback to pip:
bash /setup_isaaclab_uv.sh --use-pip

# To rebuild (e.g., after updating Isaac Lab):
bash /setup_isaaclab_uv.sh --force
```

**Expected output:**

```bash
[HH:MM:SS] [SETUP] Checking prerequisites...
[HH:MM:SS] [SETUP] Using UV (fast package installer)...
[HH:MM:SS] [SETUP] Creating virtual environment...
[HH:MM:SS] [SETUP] Installing PyTorch 2.9.1 + torchvision + torchaudio...
  This step may take 3-5 minutes...
[HH:MM:SS] [SETUP] Installing IsaacLab extensions...
[HH:MM:SS] [SETUP] Isaac Lab Python environment setup COMPLETE ✓
============================================================
  Venv location    : /workspace/.isaaclab_env
  Python version   : Python 3.10.x
  PyTorch version  : 2.9.1+cu128
  CUDA available   : True
  Package manager  : UV (fast)
  Cache directory  : /workspace/.uv-cache
```

#### Option B: Traditional Setup (5-10 minutes, no caching)

```bash
# Legacy approach using Python venv and pip
# Use this if you have compatibility issues with UV
bash /setup_isaaclab.sh

# Rebuild:
bash /setup_isaaclab.sh --force
```

### 3. Verify Installation

```bash
# New terminal (or source profile)
source /etc/profile.d/isaaclab_venv.sh

# Test imports
python -c "import omni; print('✓ omni.* available')"
python -c "import torch; print(f'✓ PyTorch {torch.__version__}')"

# Try isaaclab alias
isaaclab-python -c "from isaaclab.envs import make; print('✓ IsaacLab OK')"
```

---

## Using UV for Your Own Projects

The container includes `uv` (ultra-fast Python package manager). Here's how to use it for your Isaac Lab projects:

### Quick Start: Create a Project with UV

```bash
# Inside the container
mkdir -p /workspace/my_isaaclab_project
cd /workspace/my_isaaclab_project

# Copy the sample pyproject.toml
cp /home/saswata/raven-desktop/docker_isaacsim/sample_pyproject.toml pyproject.toml

# Create venv with UV (much faster than pip!)
UV_CACHE_DIR=/workspace/.uv-cache uv venv

# Activate
source .venv/bin/activate

# Install dependencies (with PyTorch cu128)
UV_CACHE_DIR=/workspace/.uv-cache uv pip install -e .

# Or if you prefer traditional pip:
pip install -e .
```

### Advanced: Using UV with PyTorch Custom Index

Edit your `pyproject.toml`:

```toml
[project]
name = "my-isaac-project"
version = "0.1.0"
requires-python = ">=3.10"
dependencies = [
    "torch==2.9.1",
    "torchvision==0.24.1",
    "numpy>=1.24.0",
    # Your other deps...
]

# IMPORTANT: PyTorch index configuration for CUDA 12.8
[[tool.uv.index]]
name = "pytorch-cu128"
url = "https://download.pytorch.org/whl/cu128"
explicit = true

[tool.uv.sources]
torch = [{ index = "pytorch-cu128" }]
torchvision = [{ index = "pytorch-cu128" }]
```

Then install with UV:

```bash
UV_CACHE_DIR=/workspace/.uv-cache uv pip install -e .
```

### Why UV is Better

| Feature | UV | Pip |
| --- | --- | --- |
| **Speed** | 10-100x faster | Slow |
| **Caching** | Persistent cache | No persistent cache |
| **Lock files** | uv.lock (deterministic) | Manual requirements.txt |
| **Parallel downloads** | Yes | Sequential |
| **Resolver speed** | Rust-based, instant | Slow (Python) |

---

### 1. In the container terminal

```bash
# Source the environment (auto-loads in new terminals after /setup_isaaclab.sh)
source /etc/profile.d/isaaclab_venv.sh

# Run a simple RL training example (headless mode — no UI)
isaaclab-python source/standalone/workflows/rsl_rl/train.py \
  task=Isaac-Cartpole-v0 \
  headless=True \
  num_envs=4096

# Expected: Training starts; you see episode rewards increasing
```

### 2. GUI Examples (run inside VNC desktop)

```bash
# Create an empty scene
isaaclab-python source/standalone/tutorials/00_sim/create_empty.py

# Or use the Isaac Sim UI directly
isaac
# Then File → Open Examples → Isaac Lab
```

---

## Troubleshooting

### Container Fails to Start

**Error**: `_isaac_sim symlink not found`

- **Cause**: Pre-startup host setup not completed
- **Fix**: Run step 1 from "One-Time Host Setup" above

**Error**: `Volume not mounted at /root/IsaacLab`

- **Cause**: compose.yaml volume path or permissions issue
- **Fix**: Check `docker logs <container_name>` and verify NFS/mount permissions

### PyTorch Import Fails

**Error**: `ImportError: libcuda.so.1: cannot open shared object file`

- **Cause**: NVIDIA Container Toolkit not configured
- **Fix**: On host, run `sudo nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker`

**Error**: `RuntimeError: CUDA out of memory`

- **Cause**: Running multiple large simulations
- **Fix**: Reduce `num_envs` in scripts or restart container to free VRAM

### IsaacLab Setup Script Hangs

**Symptom**: `setup_isaaclab.sh` stops responding during PyTorch install

- **Cause**: pip timeout on slow network
- **Fix**: Run with increased timeout:

  ```bash
  export PIP_DEFAULT_TIMEOUT=300
  bash /setup_isaaclab.sh --force
  ```

---

## Multi-User Deployment

### Launch Multiple Users Simultaneously

```bash
# User 1
./launch_user.sh alice 8081 9091

# User 2 (different ports)
./launch_user.sh bob 8082 9092

# User 3
./launch_user.sh charlie 8083 9093

# Each has:
# - Unique VNC port
# - Separate /mount/Data2/<user>/workspace
# - Separate /mount/Data2/<user>/omni_data (Omniverse user data)
# - Shared /root/isaacsim (read-only)
# - Shared /root/IsaacLab (read-only)
```

### Stop All Containers

```bash
docker compose down  # Stops all in current directory
# OR
docker stop $(docker ps -q)  # Stops all containers
```

### View Logs

```bash
# Container stderr/stdout
docker logs -f alice_isaac

# Inside container: desktop logs
tail -f /var/log/supervisor/xvfb.out.log
tail -f /var/log/supervisor/x11vnc.out.log
```

---

## Production Safety Features

**Implemented**:

- IsaacLab mounted as **read-only (ro)** → Zero corruption risk
- `_isaac_sim` symlink is **pre-created on host** → Not created on every container start
- Mount validation at startup → Fails immediately if volumes missing
- Python 3.10 strict validation → Rejects incompatible Python versions
- PyTorch CUDA 12.1 → Matches Isaac Sim 5.1 official requirements
- Per-user workspace isolation → Each user has separate omni_data and workspace
- Supervisor manages all services → Automatic restart on crash

**NOT present (would require additional setup)**:

- Persistent DB for multi-user auth
- Resource quotas per user
- Centralized log aggregation
- Backup/snapshot automation

---

## Performance Tuning

### For Large Simulations (10K+ environments)

```bash
# Inside container, Edit /workspace/.isaaclab_env setup if needed
# Or pass runtime flags:

isaaclab-python example.py \
  num_envs=16384 \
  headless=True \
  device=cuda:0

# If CUDA OOM occurs, either:
# 1. Reduce num_envs
# 2. Allocate more GPU memory to container (edit compose.yaml CUDA_VISIBLE_DEVICES)
# 3. Use multi-GPU setup (advanced)
```

### For Real-Time Streaming

```bash
# Use Isaac Sim streaming (Omniverse Connectors)
isaac-sim --/app/window/drawingMode=none --/persistent/app/livestream/enabled=true
```

---

## Maintenance

### Rebuild After Updates

```bash
# Update any of: Dockerfile, startup.sh, supervisord.conf, setup_isaaclab.sh

# Clean build (remove old image)
docker rmi local/ubuntu-desktop-vnc:isaac-5.1
./build.sh

# Deploy to new container
./launch_user.sh newuser 8090 9090
bash /setup_isaaclab.sh  # Re-run once inside
```

### Update Isaac Lab Code

```bash
# On Host:
cd /mount/Data2/saswata/isaac_sim_storage/IsaacLab
git pull origin main  # or your branch

# Inside container (workspace is already fresh):
isaaclab-python -c "from isaaclab import *; print(__version__)"
```

---

## Support & Debugging

### Enable Verbose Logging

Inside container:

```bash
# startup.sh logs
export DEBUG=1
# then check /var/log/supervisor/

# Isaac Sim logs
tail -f ~/.nvidia-omniverse/logs/kit/2024.*/kit.log
```

### Collect Diagnostic Info

```bash
# On host
docker inspect alice_isaac  # See container config
docker stats alice_isaac    # CPU/memory usage
docker ps -a                # Container status

# Inside container
uname -a                     # Kernel info
nvidia-smi                   # GPU info
python --version             # Python version
python -c "import torch; print(torch.cuda.is_available())"
```

---

## Sign-Off Checklist

Before considering deployment production-ready:

- [ ] Host pre-startup setup completed (`_isaac_sim` symlink created)
- [ ] Docker image builds without errors
- [ ] Container starts and shows desktop via VNC
- [ ] `/setup_isaaclab.sh` completes without errors
- [ ] `isaaclab-python --version` works
- [ ] Sample training script runs (e.g., CartPole)
- [ ] Multi-user containers launch independently
- [ ] Logs are readable and informative

---

**Version Control**: 1.0 | **Last Updated**: Feb 26, 2026 | **Status**: REVIEWED FOR PRODUCTION
