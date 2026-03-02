# Isaac Lab Docker Architecture

**Complete technical reference for the production Isaac Lab container system**

- **Version**: 1.2  
- **Target**: Production deployment with multi-user support  
- **CUDA**: 12.8 | **PyTorch**: 2.9.1+cu128 | **Python**: 3.10+

---

## System Overview

```bash
┌─────────────────────────────────────────────────────────────────────┐
│ Host Machine                                                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│ /mount/Data2/saswata/isaac_sim_storage/                             │
│ ├── app/                    ← Isaac Sim 5.1 (ro-mount)              │
│ ├── IsaacLab/               ← Isaac Lab source + _isaac_sim symlink │
│ └── assets_root/            ← Physics assets (ro-mount)             │
│                                                                      │
│ launch_user.sh              ← Multi-user container launcher         │
│ ./build.sh                  ← Docker image builder                  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
                                     │
                    ┌────────────────┼────────────────┐
                    │                                 │
                    ▼                                 ▼
        ┌──────────────────────┐      ┌──────────────────────┐
        │  docker-compose run  │      │  Supervisor manages: │
        │  alice_isaac [user]  │      │  - Xvfb (X server)   │
        │  bob_isaac [user]    │      │  - Openbox (WM)      │
        │  charlie_isaac [user]│      │  - x11vnc (VNC)      │
        └──────────────────────┘      │  - LXPanel (taskbar) │
                    │                 └──────────────────────┘
                    │
                    ▼
        ┌──────────────────────────────────────────┐
        │ Container: alice_isaac                  │
        ├──────────────────────────────────────────┤
        │ (/workspace: rw per-user)                │
        │ (/root/isaacsim: ro shared)              │
        │ (/root/IsaacLab: ro shared)              │
        │ (/root/isaacsim_assets: ro shared)       │
        │ (/.nvidia-omniverse: rw per-user)        │
        │                                          │
        │ Available commands:                      │
        │ - isaaclab               (GUI)           │
        │ - isaaclab-python        (training)      │
        │ - python, conda, pip     (development)   │
        │ - VNC access: port 5900                  │
        └──────────────────────────────────────────┘
```

---

## Container Stack

### Base Image

```dockerfile
FROM nvidia/cuda:12.8.0-devel-ubuntu22.04
```

**Why CUDA 12.8?**

- Matches PyTorch 2.9.1+cu128 wheels
- RTX A6000 native support
- Latest stable NVIDIA image

### Key Components

| Component | Version | Purpose |
|-----------|---------|---------|
| Ubuntu | 22.04 (Jammy) | Base OS |
| Python | 3.10+ | Isaac Sim modules (omni.*) |
| PyTorch | 2.9.1+cu128 | NN training + CUDA compute |
| Isaac Sim | 5.1 | Robotics physics simulator |
| Isaac Lab | Latest | RL training framework |
| LXDE | Latest | Desktop environment |
| x11vnc | Latest | VNC server |
| Supervisor | Latest | Process manager |
| UV | 0.9.20 | Fast Python package manager |

---

## Mount Architecture

### Read-Only Mounts (Shared)

```yaml
# Isaac Sim installation (read-only)
- /mount/Data2/saswata/isaac_sim_storage/app:/root/isaacsim:ro

# Isaac Lab source code (read-only)
- /mount/Data2/saswata/isaac_sim_storage/IsaacLab:/root/IsaacLab:ro

# Physics assets (read-only)
- /mount/Data2/saswata/isaac_sim_storage/assets_root:/root/isaacsim_assets:ro
```

**Benefits:**

[-] Multiple containers share same Isaac Sim (no duplication)
[-] ✅ Zero corruption risk (immutable)
[-] ✅ Fast container startup
[-] ✅ Efficient disk usage (20GB → shared across all users)

### Read-Write Mounts (Per-User)

```yaml
# Workspace: user code, venv, outputs
- /mount/Data2/${USER}/workspace:/workspace:rw

# Omniverse config: per-user Isaac Sim state
- /mount/Data2/${USER}/omni_data:/root/.nvidia-omniverse:rw
```

**Isolation:**

- Alice's `/workspace` ≠ Bob's `/workspace`
- Alice's `omni_data` ≠ Bob's `omni_data`
- No interference between users

---

## Startup Sequence

When a container launches, `startup.sh` performs:

```bash
1. Workspace ownership
   └─ Verify /workspace mounted and readable

2. Pre-flight validation (CRITICAL)
   ├─ Check all ro-mounts exist and are readable
   ├─ Validate /root/IsaacLab/_isaac_sym exists
   └─ Fail immediately with clear error if missing

3. CUDA environment
   ├─ Detect host GPU
   ├─ Set CUDA_HOME env vars
   └─ Export PATH, LD_LIBRARY_PATH

4. Isaac Sim/Lab environment
   ├─ Export ISAACSIM_PATH, ISAACLAB_PATH
   ├─ Set environment aliases (isaaclab, isaaclab-python)
   └─ Save to /etc/profile.d/isaaclab.sh for persistence

5. Display & VNC
   ├─ Configure X11 DISPLAY=${DISPLAY}
   ├─ Initialize Xvfb (virtual X server)
   ├─ Set up D-Bus
   └─ Configure x11vnc password

6. Desktop environment
   ├─ Configure GTK theme
   ├─ Initialize LXDE panel
   └─ Configure PCManFM file manager

7. Supervisor
   └─ Start all managed processes (Xvfb, Openbox, x11vnc, LXPanel, etc.)
```

**Critical Failure Points:**

- Mount validation (line 2) → Fails fast with diagnostic message
- Symlink validation (line 2) → Clear instructions if missing

---

## Python Environment Setup

Containers come with TWO setup approaches:

### Option A: UV-Based Setup (RECOMMENDED)

```bash
bash /setup_isaaclab_uv.sh [--force] [--use-pip]
```

**Performance:** 3-5 minutes  
**Tool:** UV (ultra-fast Python resolver)

**Steps:**

1. Pre-flight checks (mounts, disk space, Python version)
2. Create venv at `/workspace/.isaaclab_env`
3. Install PyTorch 2.9.1+cu128 (from pytorch wheel index)
4. Install `isaaclab`, `isaaclab_assets`, `isaaclab_tasks`
5. Install RL libraries (rsl_rl, stable-baselines3, etc.)
6. Auto-activate venv in `/etc/profile.d/isaaclab_venv.sh`
7. Enable UV caching at `/workspace/.uv-cache`

**Advantages:**

- 10-100x faster than pip
- Deterministic dependency resolution
- Persistent caching across container restarts
- Parallel downloads
- Better error messages

### Option B: Traditional Setup (FALLBACK)

```bash
bash /setup_isaaclab.sh
```

**Performance:** 5-10 minutes  
**Tool:** pip (standard Python package manager)

**Same 7 steps as Option A, but using pip instead of UV**

**Use when:**

- UV is unavailable
- You prefer traditional tooling
- You want explicit `--use-pip` mode from Option A

---

## Environment Variables

Automatically set in all containers:

```bash
# Isaac paths
export ISAACSIM_PATH=/root/isaacsim
export ISAACLAB_PATH=/root/IsaacLab
export ISAACSIM_ASSET_PATH=/root/isaacsim_assets

# CUDA
export CUDA_HOME=/usr/local/cuda
export CUDA_VERSION=12.8
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH

# PyTorch (auto-detected after setup)
export TORCH_HOME=/workspace/.cache/torch
export PYTHONPATH=$PYTHONPATH:${ISAACSIM_PATH}/python_packages

# Display (VNC)
export DISPLAY=:0

# Optional (if using UV)
export UV_CACHE_DIR=/workspace/.uv-cache
```

---

## Available Commands

Inside container, after setup:

```bash
# Isaac Lab launcher (GUI mode, requires VNC)
isaaclab [--help]
isaaclab --help
isaaclab source/standalone/examples/...

# Isaac Lab Python (training, headless mode)
isaaclab-python [args]
isaaclab-python -c "from isaaclab.envs import make; ..."

# Python interactive
python
python -c "import torch; print(torch.cuda.is_available())"

# Activate venv manually (auto-active but useful to know)
source /workspace/.isaaclab_env/bin/activate

# Isaac Sim direct (if needed)
isaac  # Alias for isaac-sim.sh launcher

# Desktop (if using VNC)
# Already running via supervisor
```

---

## GPU & CUDA Handling

### Inside Container

```bash
# Check GPU availability
nvidia-smi  # Shows all accessible GPUs

# Python check
python -c "import torch; print(torch.cuda.is_available())"  # True

# Check device
python -c "import torch; print(torch.cuda.get_device_name(0))"  # RTX A6000
```

### Compute Capabilities

Isaac Lab can:

[-] Use GPU for physics simulation (Isaac Sim)
[-] Use GPU for neural network training (PyTorch)
[-] Run 1000+ parallel environments on RTX A6000

### Multi-Container GPU Sharing

With RTX A6000 (24GB VRAM):

```bash
# Scenario: 2 concurrent users
./launch_user.sh alice 8081 9091  # Uses GPU automatically
./launch_user.sh bob 8082 9092    # Shares same GPU

# Both containers see full GPU
docker exec alice_isaac nvidia-smi  # Shows GPU
docker exec bob_isaac nvidia-smi    # Shows same GPU

# No conflicts: Isaac Sim is multithreaded
# Can handle multiple users efficiently
```

### Memory Usage

Typical per-user:

- Isaac Lab env: 2-3 GB GPU VRAM
- Training headless: 4-8 GB (depends on num_envs)
- GUI desktop: 1-2 GB
- **Total per user:** 6-10 GB (safe for RTX A6000)

---

## File Structure

### Inside Container

```bash
/root/
├── isaacsim/                           # ro-mount from host
│   ├── isaac-sim.sh                   # Main launcher
│   └── python_packages/               # omni.* modules
├── IsaacLab/                          # ro-mount from host
│   ├── source/                        # isaaclab, isaaclab_assets
│   ├── isaaclab.sh                    # IsaacLab launcher
│   └── _isaac_sym → /root/isaacsim   # Symlink (KEY!)
├── isaacsim_assets/                   # ro-mount from host
│   └── Assets/Isaac/5.1/             # Physics objects, environments
└── .nvidia-omniverse/                 # rw-mount per-user
    └── [Omni config cache]

/workspace/                            # rw-mount per-user
├── .isaaclab_env/                    # Python venv
│   ├── bin/
│   ├── lib/python3.10/site-packages/
│   └── pyvenv.cfg
├── .uv-cache/                        # Optional: UV package cache
├── .cache/torch/                      # PyTorch model cache
└── [user code, projects, outputs]

/etc/profile.d/
├── isaaclab.sh                        # Sourced on shell init
└── isaaclab_venv.sh                   # Auto-activate venv
```

---

## Network Topology

### VNC Access

```bash
User's Machine
├─ VNC Client (TightVNC, RealVNC, etc.)
│  └─ Port 5900 [TCP]
│     └─ x11vnc in container
│        └─ X11 server (Xvfb)
│           └─ LXDE desktop
│
└─ Web Browser
   └─ http://container-ip:6080
      └─ noVNC proxy
         └─ x11vnc in container
            └─ X11 server (Xvfb)
               └─ LXDE desktop
```

### SSH Access

```bash
User's Machine
└─ SSH client
   └─ Port 22 [TCP]
      └─ SSH daemon in container
         └─ Interactive bash shell
```

---

## Workflow Examples

### Example 1: Headless Training

```bash
# No VNC needed, no desktop
docker exec alice_isaac isaaclab-python \
  source/standalone/examples/rl_games/train.py \
  --headless
```

**GPU Usage:** Full GPU available for simulation  
**Runtime:** Fastest (no X11 overhead)

### Example 2: Interactive Development

```bash
# Use VNC to access desktop
# http://container-ip:6080

# Inside VNC:
# - Open terminal
# - Run: isaaclab-python -i
# - Develop interactively
```

**GPU Usage:** Shared between X11 and compute  
**Runtime:** Slower than headless

### Example 3: Multi-User Distributed Training

```bash
# Launch 3 users
./launch_user.sh alice 8081 9091 &
./launch_user.sh bob 8082 9092 &
./launch_user.sh charlie 8083 9093 &

# All three training simultaneously
docker exec alice_isaac isaaclab-python train.py --headless &
docker exec bob_isaac isaaclab-python train.py --headless &
docker exec charlie_isaac isaaclab-python train.py --headless &

# All share RTX A6000, all make progress
# No conflicts (Isaac Sim multithread-safe)
```

---

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker logs alice_isaac | head -50

# Look for:
# - CRITICAL ERROR: mount validation failed
# - CRITICAL ERROR: symlink validation failed
# - GPU initialization errors

# Fix symlink (if that's the issue)
ln -sfn /root/isaacsim /mount/Data2/.../IsaacLab/_isaac_sym
docker restart alice_isaac
```

### PyTorch Import Fails

```bash
docker exec alice_isaac bash /setup_isaaclab_uv.sh --force
# OR
docker exec alice_isaac bash /setup_isaaclab.sh
```

### GPU Not Available

```bash
# Check host GPU
nvidia-smi  # Must work on host first

# Check container GPU access
docker exec alice_isaac nvidia-smi

# If both work but torch doesn't:
docker exec alice_isaac python -c "import torch; print(torch.__version__)"

# Rebuild environment without GPU (fallback)
docker exec alice_isaac bash /setup_isaaclab_uv.sh --use-pip
```

### Disk Full

```bash
# Check workspace disk usage
du -sh /workspace/*

# Issue: venv or cache too large
# Solution: Clean and rebuild
rm -rf /workspace/.isaaclab_env /workspace/.uv-cache
bash /setup_isaaclab_uv.sh
```

---

## Performance Tuning

### For Large-Scale Training

```bash
# Increase resource limits in compose.yaml
services:
  isaac:
    cpu_limit: 28  # Use 28 of 56 cores
    mem_limit: 60g  # Use 60GB of 125GB
```

### For Headless Mode

```bash
# Disable X11 startup (optional optimization)
# (Advanced: modify supervisord.conf)

# Just run training directly
docker exec alice_isaac isaaclab-python train.py --headless
```

---

## Production Deployment Checklist

Before going live:

- [ ] Read [PRE_DEPLOYMENT_CHECKLIST.md](PRE_DEPLOYMENT_CHECKLIST.md)
- [ ] Create _isaac_sim symlink on host
- [ ] Build Docker image
- [ ] Launch test container
- [ ] Complete Python environment setup
- [ ] Run sample training script
- [ ] Verify multi-user isolation
- [ ] Test failure scenarios (e.g., disk full)
- [ ] Set up monitoring/logging (optional)
- [ ] Document custom workflows

---

## References

| Document | Purpose |
| ---------- | --------- |
| [QUICK_START.md](QUICK_START.md) | 5-step deployment |
| [PRE_DEPLOYMENT_CHECKLIST.md](PRE_DEPLOYMENT_CHECKLIST.md) | Verification before production |
| [SYMLINK_AND_RO_MOUNT.md](SYMLINK_AND_RO_MOUNT.md) | How immutable mounts work |
| [DEPLOYMENT.md](DEPLOYMENT.md) | Comprehensive deployment guide |
| [PRODUCTION_FIXES.md](PRODUCTION_FIXES.md) | Safety improvements made |

---

**Status**: Production Ready | **Last Updated**: February 26, 2026
