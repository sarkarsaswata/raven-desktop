# Isaac Lab Docker Container — Complete Documentation

## **A production-grade Docker setup for Isaac Sim + Isaac Lab training**

**Status**: Production Ready  
**Version**: 1.2  
**CUDA**: 12.8 | **PyTorch**: 2.9.1+cu128 | **Isaac Lab**: Latest

---

## Documentation Map

### Getting Started (Start Here!)

| Document | Time | Purpose |
| ---------- | ------ | --------- |
| **[QUICK_START.md](QUICK_START.md)** | 5 min | 5-step deployment guide |
| **[PRE_DEPLOYMENT_CHECKLIST.md](PRE_DEPLOYMENT_CHECKLIST.md)** | 10 min | Verify system readiness |
| **[SYMLINK_AND_RO_MOUNT.md](SYMLINK_AND_RO_MOUNT.md)** | 5 min | Understand the architecture |

### Reference Documentation

| Document | Pages | Purpose |
| ---------- | ------- | --------- |
| **[ARCHITECTURE.md](ARCHITECTURE.md)** | 8 | Complete technical reference |
| **[DEPLOYMENT.md](DEPLOYMENT.md)** | 12 | Full deployment & troubleshooting guide |
| **[PRODUCTION_FIXES.md](PRODUCTION_FIXES.md)** | 10 | Safety improvements & audit trail |

---

## Quick Navigation

### "I want to..."

- **...deploy immediately** → [QUICK_START.md](QUICK_START.md)
- **...verify my system** → [PRE_DEPLOYMENT_CHECKLIST.md](PRE_DEPLOYMENT_CHECKLIST.md)
- **...understand symlinks** → [SYMLINK_AND_RO_MOUNT.md](SYMLINK_AND_RO_MOUNT.md)
- **...understand the architecture** → [ARCHITECTURE.md](ARCHITECTURE.md)
- **...troubleshoot issues** → [DEPLOYMENT.md](DEPLOYMENT.md#troubleshooting)
- **...see production improvements** → [PRODUCTION_FIXES.md](PRODUCTION_FIXES.md)
- **...set up a multi-user system** → [DEPLOYMENT.md](DEPLOYMENT.md#multi-user-deployment)
- **...run training jobs** → [ARCHITECTURE.md](ARCHITECTURE.md#workflow-examples)

---

## The 5-Step Summary

```txt
1. Create symlink (host, one-time):
   ln -sfn /root/isaacsim /mount/Data2/.../IsaacLab/_isaac_sim

2. Build image:
   cd /home/saswata/raven-desktop/docker_isaacsim && ./build.sh

3. Launch container:
   ./launch_user.sh alice 8081 9091

4. Setup environment (inside container):
   bash /setup_isaaclab_uv.sh  # (3-5 min)

5. Verify:
   python -c "import torch; print(torch.cuda.is_available())"
   isaaclab-python -c "from isaaclab.envs import make; print('OK')"
```

**Full details**: [QUICK_START.md](QUICK_START.md)

---

## System Overview

### What You Get

**Isaac Sim 5.1** — Physics simulator (read-only shared)  
**Isaac Lab** — RL training framework (read-only shared)  
**PyTorch 2.9.1+cu128** — CUDA 12.8 compatible  
**Multi-user Ready** — Isolated workspaces per user  
**Desktop Environment** — VNC access (noVNC + TightVNC)  
**Production Safe** — Read-only mounts prevent corruption  
**GPU Optimized** — Full RTX A6000 support  
**Fast Setup** — UV package manager (3-5 minutes)  

### Key Features

| Feature | Benefit |
| --------- | --------- |
| **Read-only mounts** | Zero corruption risk for shared Isaac Sim/Lab |
| **Pre-created symlink** | No race conditions, fast startup |
| **Per-user workspaces** | Complete isolation between users |
| **VNC desktop** | GUI access to Isaac Lab examples |
| **Headless mode** | Efficient training without X11 overhead |
| **UV package manager** | 10-100x faster than pip |
| **GPU sharing** | Multiple users on single RTX A6000 |

---

## What's Different (vs. Manual Installation)

### Without Containers

```txt
- Install IsaacSim on each machine
- Install IsaacLab in each user's home
- Complex environment setup
- Risk of system-wide dependency conflicts
- Scaling to multi-user is painful
```

### With These Containers

```txt
- Single container image for all users
- Instant multi-user deployment
- Guaranteed reproducible environments
- Easy version management
- Safe, isolated workspaces
- VNC access from anywhere
```

---

## System Requirements

### Host Machine (Minimum)

Check as per official documentation [here](https://docs.isaacsim.omniverse.nvidia.com/5.1.0/installation/requirements.html)

---

## Workspace Files

### Core Files (In Repository)

```bash
/home/saswata/raven-desktop/docker_isaacsim/
├── Dockerfile                    # Multi-stage build (production-ready)
├── compose.yaml                  # Docker Compose config (ro-mounts)
├── startup.sh                    # Container init + validation
├── build.sh                      # Image builder script
├── launch_user.sh                # Multi-user launcher
├── supervisord.conf              # Desktop process manager
├── entrypoint-user.sh            # Per-user entry script
├── setup_isaaclab.sh             # Traditional pip setup
├── setup_isaaclab_uv.sh          # Modern UV setup (RECOMMENDED)
├── pyproject.toml         # Reference for user projects
│
└── Documentation:
    ├── QUICK_START.md            # 5-step guide
    ├── PRE_DEPLOYMENT_CHECKLIST  # Pre-flight verification
    ├── SYMLINK_AND_RO_MOUNT.md   # Architecture explanation
    ├── ARCHITECTURE.md           # Technical reference
    ├── DEPLOYMENT.md             # Full guide
    ├── PRODUCTION_FIXES.md       # Safety audit trail
    └── README.md                 # (This file)
```

### Host Storage Structure

```bash
/mount/Data2/saswata/isaac_sim_storage/
├── IsaacSim/                         # Isaac Sim binaries (20GB)
├── IsaacLab/                    # Isaac Lab source (10GB)
│   └── _isaac_sym → IsaacSim/  # (CRITICAL: Pre-created symlink)
├── assets_IsaacSim/                 # Physics assets (10GB)
│
└── [Per-user workspace directories created by launch_user.sh]
    ├── alice/workspace          # Alice's venv, code, outputs
    └── alice/omni_data          # Alice's Omni config
```

---

## Production Safety Improvements

This system includes **8 major safety improvements** over naive approaches:

| # | Issue | Fix | Document |
| --- | ------- | ----- | ---------- |
| 1 | CUDA version mismatch | Changed to 12.8 base + cu128 wheels | [PRODUCTION_FIXES.md](PRODUCTION_FIXES.md) |
| 2 | IsaacLab corruption risk | Changed rw-mount → ro-mount + symlink | [PRODUCTION_FIXES.md](PRODUCTION_FIXES.md) |
| 3 | Symlink race conditions | Pre-create symlink on host | [SYMLINK_AND_RO_MOUNT.md](SYMLINK_AND_RO_MOUNT.md) |
| 4 | Silent mount failures | Added validation block with clear errors | [PRODUCTION_FIXES.md](PRODUCTION_FIXES.md) |
| 5 | Python version issues | Strict 3.10-3.11 validation | [PRODUCTION_FIXES.md](PRODUCTION_FIXES.md) |
| 6 | Hidden PyTorch issues | Removed --quiet flags from pip | [PRODUCTION_FIXES.md](PRODUCTION_FIXES.md) |
| 7 | Disk space failures | Pre-flight 5GB validation | [PRODUCTION_FIXES.md](PRODUCTION_FIXES.md) |
| 8 | Slow setup times | Switched to UV (3-5 min vs 5-10 min) | [ARCHITECTURE.md](ARCHITECTURE.md#option-a-uv-based-setup) |

**Details**: [PRODUCTION_FIXES.md](PRODUCTION_FIXES.md)

---

## Common Tasks

### Launch New User

```bash
./launch_user.sh bob 8082 9092
```

**Time:** ~30 seconds  
**Isolation:** Complete (separate workspace, omni_data, ports)

### Train a Model (Headless)

```bash
docker exec alice_isaac isaaclab-python \
  source/standalone/examples/rl_games/train.py \
  --headless
```

**Performance:** Maximum (full GPU, no X11 overhead)

### Run GUI Training

1. Access VNC: `http://ipaddress:6080`
2. Open terminal
3. Run: `isaaclab source/standalone/examples/...`

**Performance:** Good (X11 + compute share GPU)

### Check GPU Usage

```bash
docker exec alice_isaac nvidia-smi

# Or from host:
nvidia-smi dmon  # Monitor by process
```

### Multi-User Training

```bash
# Launch 3 users
./launch_user.sh alice 8081 9091 &
./launch_user.sh bob 8082 9092 &
./launch_user.sh charlie 8083 9093 &

# All training simultaneously
for user in alice bob charlie; do
  docker exec ${user}_isaac isaaclab-python train.py --headless &
done
```

---

## Performance Characteristics

### Setup Time

| Approach | Time | Recommended |
|----------|------|-------------|
| UV setup | 3-5 min | YES |
| Pip setup | 5-10 min | Fallback |
| Docker build | 10-15 min | Once per version |

### Training Performance

| Scenario | GPU VRAM Used | Throughput |
|----------|---------------|-----------|
| Single user headless | 8-12 GB | Maximum |
| Single user + desktop | 10-14 GB | Good |
| 2 users headless | 14-18 GB | Good (shared) |
| 3 users headless | 18-22 GB | Fair (shared) |

**Your GPU:** RTX A6000 = 24GB VRAM (handles 2-3 concurrent trainers easily)

---

## Getting Help

### Issues & Questions

| Problem | Document | Section |
|---------|----------|---------|
| Symlink not found | [SYMLINK_AND_RO_MOUNT.md](SYMLINK_AND_RO_MOUNT.md) | Troubleshooting |
| Container won't start | [DEPLOYMENT.md](DEPLOYMENT.md) | Troubleshooting |
| GPU not available | [ARCHITECTURE.md](ARCHITECTURE.md) | Troubleshooting |
| Setup fails | [DEPLOYMENT.md](DEPLOYMENT.md) | Advanced Setup |
| Multi-user issues | [DEPLOYMENT.md](DEPLOYMENT.md) | Multi-User Deployment |

### Pre-Deployment Verification

Before going live, complete: **[PRE_DEPLOYMENT_CHECKLIST.md](PRE_DEPLOYMENT_CHECKLIST.md)**

---

## Deployment Workflow

```bash
┌─────────────────────────────────┐
│ 1. Read QUICK_START.md          │
└────────────┬────────────────────┘
             │
┌────────────▼────────────────────┐
│ 2. Complete PRE_DEPLOYMENT_     │
│    CHECKLIST.md                 │
└────────────┬────────────────────┘
             │
┌────────────▼────────────────────┐
│ 3. Run: ln -sfn /root/isaacsim  │
│         .../IsaacLab/_isaac_sym │
└────────────┬────────────────────┘
             │
┌────────────▼────────────────────┐
│ 4. Run: ./build.sh              │
└────────────┬────────────────────┘
             │
┌────────────▼────────────────────┐
│ 5. Run: ./launch_user.sh alice  │
│    8081 9091                    │
└────────────┬────────────────────┘
             │
┌────────────▼────────────────────┐
│ 6. Inside container:            │
│    bash /setup_isaaclab_uv.sh   │
└────────────┬────────────────────┘
             │
┌────────────▼────────────────────┐
│ 7. Verify installation          │
│    (runs python -c "import...") │
└────────────┬────────────────────┘
             │
┌────────────▼────────────────────┐
│    READY FOR PRODUCTION!        │
└─────────────────────────────────┘
```

---

## Change History

### Version 1.2 (February 26, 2026)

- Added UV-based setup script (3-5 min setup)  
- Added SYMLINK_AND_RO_MOUNT.md (architecture explanation)  
- Added PRE_DEPLOYMENT_CHECKLIST.md (verification guide)  
- Added QUICK_START.md (5-step guide)  
- Upgraded PyTorch to 2.9.1+cu128  
- Upgraded CUDA base to 12.8.0  

### Version 1.1 (Previous)

- Initial production fixes (CUDA, ro-mounts, validation)  
- Created DEPLOYMENT.md (comprehensive guide)  
- Created PRODUCTION_FIXES.md (audit trail)  

### Version 1.0 (Initial)

- Basic Isaac Lab Docker integration  

---

## Sign-Off

- **Author**: Saswata Sarkar | [sarkarsaswata01@gmail.com](mailto:sarkarsaswata01@gmail.com)
- **Last Updated**: March 2, 2026
- **Status**: Production Ready
- **Tested On**: Ubuntu 22.04, CUDA 12.8, Docker 24.x
- **Hardware**: RTX A6000, 56-core CPU, 125GB RAM

---

## Learning Resources

For deeper understanding, see:

- [ARCHITECTURE.md](ARCHITECTURE.md) — Complete technical reference (8 pages)
- [DEPLOYMENT.md](DEPLOYMENT.md) — Full deployment & troubleshooting (12 pages)
- [PRODUCTION_FIXES.md](PRODUCTION_FIXES.md) — Safety improvements (10 pages)

---

## Support

For questions not covered in documentation:

1. Check [DEPLOYMENT.md](DEPLOYMENT.md#troubleshooting)
2. Check [ARCHITECTURE.md](ARCHITECTURE.md#troubleshooting)
3. Review container logs: `docker logs alice_isaac`
4. Verify symlink: `ls -la /mount/Data2/.../IsaacLab/_isaac_sym`

---

**Next Step**: Open [QUICK_START.md](QUICK_START.md) and execute the 5 steps!
