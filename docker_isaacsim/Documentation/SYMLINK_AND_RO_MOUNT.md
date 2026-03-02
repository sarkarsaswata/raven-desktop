# Isaac Lab Symlink & Read-Only Mount Architecture

**Document Purpose**: Explain how the `_isaac_sim` symlink works in a read-only production environment

**Last Updated**: February 26, 2026  
**Security Level**: Production-Ready (immutable mounts)

---

## The _isaac_sim Symlink: Why It's Needed

### Problem It Solves

`isaaclab.sh` (the Isaac Lab launcher script) looks for:

```bash
${ISAACLAB_PATH}/_isaac_sim/
```

This is a symlink that points to the Isaac Sim installation so isaaclab can:

1. Find Isaac Sim binaries
2. Load Isaac Sim Python modules
3. Locate the Kit SDK components

### Why NOT Create It Inside the Container?

**Old Approach (RW-Mount):**

```yaml
- /mount/Data2/saswata/isaac_sim_storage/IsaacLab:/root/IsaacLab:rw
```

- Startup.sh tries to create symlink on every container start
- **Problem**: If the mount fails, symlink creation silently fails
- **Risk**: Container starts but IsaacLab is broken
- **Issue**: Multiple containers could race to create the same symlink

**New Approach (RO-Mount + Pre-Created Symlink):**

```yaml
- /mount/Data2/saswata/isaac_sim_storage/IsaacLab:/root/IsaacLab:ro
```

- Symlink is created **once** on the host (before any containers start)
- Startup.sh **validates** (doesn't create) the symlink exists
- **Benefit**: Fast, deterministic, no race conditions
- **Safety**: Mount is read-only, zero corruption risk

---

## Step-by-Step Setup Guide

### Step 1: Create the Symlink on Host (ONE-TIME)

Run this **once**, on the host machine, **before starting any containers**:

```bash
# Create the symlink
ln -sfn /root/isaacsim /mount/Data2/saswata/isaac_sim_storage/IsaacLab/_isaac_sim

# Verify it was created correctly
ls -la /mount/Data2/saswata/isaac_sim_storage/IsaacLab/ | grep _isaac_sim

# Expected output:
# _isaac_sim -> /root/isaacsim
```

**Why `/root/isaacsim`?**

- Inside the container, Isaac Sim is mounted at `/root/isaacsim` (see compose.yaml)
- The symlink **target path** must match what the container will see
- `/root/isaacsim` is the container-side path (where Isaac Sim appears inside)

**Alternative target paths** (if you change mount locations):

```bash
# Example: if you mount Isaac Sim at /opt/isaac instead:
ln -sfn /opt/isaac /mount/Data2/saswata/.../IsaacLab/_isaac_sim
```

### Step 2: Verify Mount Structure

Before launching containers, verify all paths are correct:

```bash
# Check host paths exist
ls -la /mount/Data2/saswata/isaac_sim_storage/app/isaac-sim.sh
ls -la /mount/Data2/saswata/isaac_sim_storage/IsaacLab/source
ls -la /mount/Data2/saswata/isaac_sim_storage/IsaacLab/_isaac_sim
# All should exist without errors

# Check permissions are readable
find /mount/Data2/saswata/isaac_sim_storage -type f -readable | head -3
```

### Step 3: Launch Container

```bash
./launch_user.sh alice 8081 9091
```

The container will:

1. Mount IsaacLab as read-only
2. startup.sh validates the symlink exists
3. If symlink is missing: **container fails with clear error**
4. If symlink exists: **container continues**

### Step 4: Inside Container - Verify Symlink

```bash
# SSH into container
docker exec -it alice_isaac bash

# Verify symlink is present and correct
ls -la /root/IsaacLab/_isaac_sim
# Expected: _isaac_sim -> /root/isaacsim

# Verify it points to valid Isaac Sim
ls /root/IsaacLab/_isaac_sim/isaac-sim.sh
# Should succeed (no "No such file or directory")

# Run isaaclab
isaaclab --help
# Should work without errors
```

---

## How the Read-Only Mount Protects You

### Scenario: Container Crashes Mid-Operation

```bash
# Container is writing a large checkpoint
# Power fails, kernel panic, whatever...

# Result: IsaacLab source is STILL INTACT
# (because it's mounted as :ro)

# Other containers can still use IsaacLab without issues
docker logs alice_isaac    # Logs show error
docker exec -it bob_isaac bash  # Still works fine
```

### Scenario: Buggy Script Writes to /root/IsaacLab

```python
# Inside container, buggy code:
import shutil
shutil.rmtree("/root/IsaacLab/source")  # OOPS!

# Result: Permission denied (read-only filesystem)
# IsaacLab source is protected
```

---

## Troubleshooting

### Q: Container fails with "symlink not found"

```bash
[ERROR] CRITICAL: /root/IsaacLab/_isaac_sim symlink not found.
[ERROR] Create it on the host: ln -sfn /root/isaacsim /mount/Data2/.../IsaacLab/_isaac_sim
```

**Fix:**

```bash
# On HOST machine:
ln -sfn /root/isaacsim /mount/Data2/saswata/isaac_sim_storage/IsaacLab/_isaac_sim

# Verify:
ls -la /mount/Data2/saswata/isaac_sim_storage/IsaacLab/_isaac_sim
```

### Q: Symlink points to wrong location

```bash
# Current (wrong):
ls -la /mount/Data2/.../IsaacLab/_isaac_sim
# /usr/local/isaac  (WRONG!)

# Fix: Remove and recreate
rm /mount/Data2/saswata/isaac_sim_storage/IsaacLab/_isaac_sim
ln -sfn /root/isaacsim /mount/Data2/saswata/isaac_sim_storage/IsaacLab/_isaac_sim

# Verify:
ls -la /mount/Data2/saswata/isaac_sim_storage/IsaacLab/_isaac_sim
# /root/isaacsim  (CORRECT!)
```

### Q: "Read-only file system" error when using IsaacLab

This is **expected and safe**. IsaacLab source is protected.

```bash
# Inside container, trying to write to IsaacLab:
cp /workspace/my_config /root/IsaacLab/
# Read-only file system

# FIX: Write to /workspace (not /root/IsaacLab)
cp /workspace/my_config /workspace/
```

---

## Multi-Container Example

With the ro-mount symlink approach, multiple containers work seamlessly:

```bash
# Launch 3 users simultaneously
./launch_user.sh alice 8081 9091 &
./launch_user.sh bob 8082 9092 &
./launch_user.sh charlie 8083 9093 &

# Each container:
# Sees the same /root/IsaacLab (ro)
# Sees the same /root/isaacsim (ro)
# Sees the shared _isaac_sim symlink (ro)
# Has its own /workspace (rw)
# Has its own ~/.nvidia-omniverse (rw)
```

No conflicts, no race conditions, no data corruption.

---

## Summary

| Aspect | Value |
| --- | --- |
| **Symlink location** | `/mount/Data2/saswata/isaac_sim_storage/IsaacLab/_isaac_sim` |
| **Symlink target** | `/root/isaacsim` |
| **When created** | Once on host, before first container |
| **Mount type** | Read-only (:ro) |
| **Risk of corruption** | Zero (immutable) |
| **Multi-container safety** | Yes |
| **Performance overhead** | Minimal (symlink, no per-container creation) |

---

**For questions**, see [DEPLOYMENT.md](DEPLOYMENT.md) or [PRODUCTION_FIXES.md](PRODUCTION_FIXES.md)
