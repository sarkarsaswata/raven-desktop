# Quick Start Guide

**For**: Getting Isaac Lab containers running in minutes  
**Time**: ~20 minutes (including setup)  
**Prerequisites**: Read [PRE_DEPLOYMENT_CHECKLIST.md](PRE_DEPLOYMENT_CHECKLIST.md) first

---

## The Absolute Minimum Steps

### Step 1: Create Symlink (Host)

```bash
sudo ln -sfn /mount/Data2/saswata/isaac_sim_storage/IsaacSim /mount/Data2/saswata/isaac_sim_storage/IsaacLab/_isaac_sim
```

**One command, one-time only.** Symlink is now ready for all future containers.

---

### Step 2: Build Docker Image

```bash
cd /path/to/raven-desktop/docker_isaacsim
./build.sh
```

Takes ~10-15 minutes  
Creates image: `local/ubuntu-desktop-vnc:isaac-5.1`

---

### Step 3: Launch Container

```bash
./launch_user.sh alice 8081 9091
```

When prompted: Enter your VNC password (e.g., `mypassword123`)

Container is now running. Output shows:

- noVNC URL: `http://<IP>:6080`
- VNC Port: `<IP>:5900`
- SSH available (if configured)

---

### Step 4: Inside Container - Setup Environment

```bash
docker exec -it alice_isaac bash
```

Inside container, choose one:

**Fastest (UV, 3-5 min):**

```bash
bash /setup_isaaclab_uv.sh
```

**Traditional (5-10 min):**

```bash
bash /setup_isaaclab.sh
```

Setup completes with summary showing PyTorch version and CUDA availability

---

### Step 5: Verify It Works

```bash
python -c "import torch; print(f'PyTorch: {torch.__version__}, CUDA: {torch.cuda.is_available()}')"
isaaclab-python -c "from isaaclab.envs import make; print('✓ IsaacLab ready')"
```

Both commands should succeed without errors

---

## Command Reference

### Access Container

```bash
# Via terminal/shell
docker exec -it alice_isaac bash

# Via VNC web browser
http://<your-ip>:6080
# Password: what you entered in step 3

# Via VNC client (e.g., TightVNC, RealVNC)
<your-ip>:5900
# Password: what you entered in step 3
```

### Run Isaac Lab Training

```bash
# Inside container terminal:
isaaclab -p source/standalone/examples/rl_games/train.py
```

### Run Headless (No VNC)

```bash
# Inside container:
isaaclab-python source/standalone/examples/rl_games/train.py --headless
```

### Stop Container

```bash
docker compose -p alice_project down
```

### Logs

```bash
docker logs alice_isaac
docker logs -f alice_isaac  # Follow in real-time
```

---

## Common Issues & Quick Fixes

### "symlink not found" Error

```bash
# Fix: Run on HOST (not inside container)
sudo ln -sfn /mount/Data2/saswata/isaac_sim_storage/IsaacSim /mount/Data2/saswata/isaac_sim_storage/IsaacLab/_isaac_sim
```

### Setup fails with "Read-only filesystem"

This is normal! `_isaac_sym` is read-only.

```bash
# Don't write to /root/IsaacLab, use /workspace instead
cp my_file /workspace/  # ✓ Works
cp my_file /root/IsaacLab/  # ✗ Fails (read-only)
```

### "import torch" fails

Try inside container:

```bash
python -c "import torch; print(torch.__version__)"
```

If fails, run setup again:

```bash
bash /setup_isaaclab_uv.sh --force
```

### GPU not available (torch.cuda.is_available() = False)

```bash
# Inside container:
nvidia-smi  # Should show GPU

# If no GPU output, check host:
nvidia-smi  # Host should show GPU too

# Restart container:
docker restart alice_isaac
```

---

## What's Included

**Isaac Sim 5.1** — Robotics physics simulator  
**Isaac Lab** — RL training framework on top of Isaac Sim  
**PyTorch 2.9.1+cu128** — CUDA 12.8 compatible  
**Desktop Environment** — LXDE with VNC access  
**Multi-user Ready** — Isolated workspaces per user  
**Production Safe** — Read-only mounts prevent corruption

---

## Next: Multi-User Deployment

Once Step 5 works, launch more users:

```bash
./launch_user.sh bob 8082 9092
./launch_user.sh charlie 8083 9093
```

Each user gets:

- Independent container
- Separate workspace
- Separate GPU access (if not overloaded)
- Separate VNC port

---

## Questions?

| Topic | Document |
| ------- | ---------- |
| How symlinks work | [SYMLINK_AND_RO_MOUNT.md](SYMLINK_AND_RO_MOUNT.md) |
| Full setup guide | [DEPLOYMENT.md](DEPLOYMENT.md) |
| Production safety | [PRODUCTION_FIXES.md](PRODUCTION_FIXES.md) |
| Pre-deployment verification | [PRE_DEPLOYMENT_CHECKLIST.md](PRE_DEPLOYMENT_CHECKLIST.md) |

---

**Status**: Ready to deploy! Execute the 5 steps above in order.
