# Pre-Deployment Checklist

**Purpose**: Verify your system is ready before launching Isaac Lab containers

**Target**: Production deployment with multiple concurrent users  
**Time**: ~10 minutes  
**Success Criteria**: All items checked ✓

---

## CRITICAL - Host Setup (Must Complete Before Any Containers)

### 1. Verify Host Paths

```bash
# ✓ Isaac Sim source exists
ls -d /mount/Data2/saswata/isaac_sim_storage/app
# Expected: no "No such file or directory" error

# ✓ Isaac Sim has .bin binaries
ls /mount/Data2/saswata/isaac_sim_storage/app/*.bin | head -5
# Expected: isaac-sim.so., isaac-sim.app, etc.

# ✓ Isaac Lab source exists
ls -d /mount/Data2/saswata/isaac_sim_storage/IsaacLab
# Expected: no "No such file or directory" error

# ✓ Isaac Lab has isaaclab.sh in root
ls /mount/Data2/saswata/isaac_sim_storage/IsaacLab/isaaclab.sh
# Expected: file exists

# ✓ Assets directory exists
ls -d /mount/Data2/saswata/isaac_sim_storage/assets_root
# Expected: no "No such file or directory" error
```

**Status**:  All paths verified

---

### 2. Create _isaac_sim Symlink (CRITICAL)

```bash
# ✓ Create the symlink
ln -sfn /root/isaacsim /mount/Data2/saswata/isaac_sim_storage/IsaacLab/_isaac_sim

# ✓ Verify it exists and points correctly
ls -la /mount/Data2/saswata/isaac_sim_storage/IsaacLab/_isaac_sim
# Expected output: _isaac_sim -> /root/isaacsim
```

**Status**:  Symlink created and verified

---

### 3. Check Host Storage Space

```bash
# ✓ Verify /mount/Data2 has space
df -h /mount/Data2 | tail -1
# Expected: At least 200GB available (for multuple workspaces)

# ✓ Expected breakdown:
# - Isaac Sim: ~20GB (already present)
# - Isaac Lab: ~10GB (already present)
# - Per-user workspace: ~5GB each
# - Per-user omni_data: ~2GB each
```

**Status**:  Storage verified (min 200GB available)

---

## HIGH - Docker Configuration

### 4. Docker Daemon & GPU Support

```bash
# ✓ Docker is running
docker ps
# Expected: output shows container list, no error

# ✓ GPU driver installed
nvidia-smi
# Expected: shows GPU (RTX A6000)

# ✓ Container GPU support enabled
docker run --rm --runtime=nvidia nvidia/cuda:12.8.0-devel-ubuntu22.04 \
  nvidia-smi | grep -c "NVIDIA-SMI"
# Expected: output > 0 (GPU accessible in containers)
```

**Status**:  Docker & GPU ready

---

### 5. Image Build and Tag

```bash
# ✓ Navigate to workspace
cd /home/saswata/raven-desktop/docker_isaacsim

# ✓ Build image (will take 10-15 minutes)
./build.sh
# Expected: build completes without errors, image tagged as
#           local/ubuntu-desktop-vnc:isaac-5.1

# ✓ Verify image exists
docker images | grep isaac
# Expected: Shows local/ubuntu-desktop-vnc:isaac-5.1 with CUDA 12.8
```

**Status**:  Docker image built successfully

---

## MEDIUM - Container Configuration

### 6. Test Single-User Launch

```bash
# ✓ Navigate to workspace
cd /home/saswata/raven-desktop/docker_isaacsim

# ✓ Launch test container
./launch_user.sh test_user 8081 9091

# Prompted for VNC password? Enter: testpass123

# Expected output:
# - Container created: test_user_project
# - Access URLs printed
# - noVNC available at: http://<IP>:6080
```

**Status**:  Container launched successfully

---

### 7. Verify Container Startup

```bash
# ✓ Container is running
docker ps | grep test_user_isaac
# Expected: Shows running container

# ✓ Check startup logs
docker logs test_user_isaac | tail -20
# Expected: No ERROR lines, shows desktop startup sequence

# ✓ Verify mount structure inside
docker exec test_user_isaac ls -la /root/
# Expected: Shows isaacsim, IsaacLab, isaacsim_assets, workspace directories

# ✓ Verify _isaac_sym is accessible
docker exec test_user_isaac ls /root/IsaacLab/_isaac_sim/isaac-sim.sh
# Expected: No "No such file or directory" error
```

**Status**:  Container running with correct mounts

---

### 8. VNC Access Test

```bash
# ✓ Get IP address (from launch_user.sh output or:)
hostname -I | awk '{print $1}'
# Note IP address: <IP>

# ✓ Test Ping
ping -c 2 <IP>
# Expected: receives 2 replies

# ✓ Test VNC Port (from another machine)
ncat -zv <IP> 5900
# Expected: Connection successful

# ✓ Test noVNC Port
curl -I http://<IP>:6080/
# Expected: HTTP 200 or 401 (auth page OK)
```

**Status**:  VNC connectivity verified

---

## HIGH - Python Environment Setup

### 9. Run Isaac Lab Setup (Inside Container)

Choose one approach:

#### Option A: UV Setup (RECOMMENDED, 3-5 minutes)

```bash
# ✓ SSH into container
docker exec -it test_user_isaac bash

# ✓ Run UV setup
bash /setup_isaaclab_uv.sh

# Expected output (final lines):
# ✓ IsaacLab environment ready!
# ✓ PyTorch version: 2.9.1+cu128
# ✓ CUDA available: True
# ✓ Setup completed in: ~3-5 minutes
```

#### Option B: Traditional Setup (5-10 minutes)

```bash
# ✓ SSH into container
docker exec -it test_user_isaac bash

# ✓ Run traditional setup
bash /setup_isaaclab.sh

# Expected output (final lines):
# ✓ IsaacLab environment ready!
# ✓ PyTorch version: 2.5.1+cu121
# ✓ CUDA available: True
# ✓ Setup completed in: ~5-10 minutes
```

**Status**:  Setup completed (chose Option A  or Option B )

---

### 10. Verify Python Imports

```bash
# ✓ Inside container, test imports
python -c "import torch; print(f'✓ PyTorch: {torch.__version__}')"
# Expected: ✓ PyTorch: 2.9.1+cu128 (or 2.5.1+cu121)

# ✓ Test CUDA
python -c "import torch; print(f'✓ CUDA: {torch.cuda.is_available()}')"
# Expected: ✓ CUDA: True

# ✓ Test Omni modules
python -c "import omni; print('✓ omni available')"
# Expected: ✓ omni available

# ✓ Test Isaac Lab
isaaclab-python -c "from isaaclab.envs import make; print('✓ IsaacLab OK')"
# Expected: ✓ IsaacLab OK
```

**Status**:  All imports successful

---

## MEDIUM - Multi-User Testing

### 11. Launch Second Container

```bash
# ✓ From host, launch another user
./launch_user.sh alice 8082 9092

# ✓ Verify independence
docker ps | grep alice
docker ps | grep test_user
# Expected: Both containers running, different ports

# ✓ Verify separate workspaces
docker exec test_user_isaac ls /workspace
docker exec alice_isaac ls /workspace
# Expected: Different contents (or both empty if first launch)
```

**Status**:  Multi-user isolation verified

---

### 12. Concurrent Setup Test

```bash
# ✓ Both containers setup in parallel
docker exec -d test_user_isaac bash /setup_isaaclab_uv.sh
docker exec -d alice_isaac bash /setup_isaaclab_uv.sh

# ✓ Monitor progress
docker logs test_user_isaac | tail -5 &
docker logs alice_isaac | tail -5 &

# Expected: Both complete without conflicts
# (UV caching at /workspace/.uv-cache should work fine with separate workspaces)
```

**Status**:  Concurrent setup works

---

## LOW - Performance & Optimization

### 13. Run Sample Workload

```bash
# ✓ Inside alice container, run a training step
docker exec alice_isaac isaaclab-python \
  -c "from isaaclab.envs import make; env = make('Isaac-Push-Cube-v0'); obs, _ = env.reset(); print(f'✓ Env working, obs shape: {obs.shape}')"

# Expected: Prints obs shape (e.g., (1, 27) or similar)
```

**Status**:  Sample workload successful

---

## Sign-Off

| Item | Status |
| ------ | -------- |
| Host paths verified | OK |
| _isaac_sim symlink created | OK |
| Storage space confirmed | OK |
| Docker & GPU ready | OK |
| Image built (isaac-5.1) | OK |
| Single container launches | OK |
| Container mounts correct | OK |
| VNC connectivity works | OK |
| Python environment setup | OK |
| Imports (torch, omni, isaaclab) | OK |
| Multi-user isolation | OK |
| Concurrent setup | OK |
| Sample workload runs | OK |

**Overall Status**:  READY FOR PRODUCTION

---

## Next Steps Upon Success

1. **Scale to production** with multiple users
2. **Configure resource limits** (if needed) in compose.yaml
3. **Set up monitoring** (optional: prometheus, ELK stack)
4. **Create backup strategy** for user workspaces
5. **Document custom workflows** (if any)

---

**Questions?** See:

- [SYMLINK_AND_RO_MOUNT.md](SYMLINK_AND_RO_MOUNT.md) - How symlinks work
- [DEPLOYMENT.md](DEPLOYMENT.md) - Full deployment guide
- [PRODUCTION_FIXES.md](PRODUCTION_FIXES.md) - Production safety details
