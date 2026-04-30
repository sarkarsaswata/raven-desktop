# Troubleshooting

**docker_ubuntu — Common failures and how to fix them**

---

## GPU Not Visible

**Symptom:** `nvidia-smi` inside the container returns "command not found" or
"No devices were found".

**Diagnosis:**

```bash
# On the host
nvidia-smi
docker run --rm --runtime=nvidia nvidia/cuda:12.8.0-runtime-ubuntu22.04 nvidia-smi
```

**Fixes:**

1. NVIDIA driver not installed or not loaded:

```bash
sudo apt-get install -y nvidia-driver-535
sudo reboot
```

2. NVIDIA Container Toolkit not installed:

```bash
distribution=$(. /etc/os-release; echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/libnvidia-container/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

3. Docker daemon not configured to use nvidia runtime:

```bash
# Check
cat /etc/docker/daemon.json
# Should contain: "default-runtime": "nvidia"  or the container must use runtime: nvidia

sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

---

## noVNC Browser Page Loads but is Black / Desktop Doesn't Appear

**Symptom:** The browser shows the noVNC connection panel and connects, but
the screen is black.

**Diagnosis:**

```bash
docker exec <user>_desktop supervisorctl status
docker exec <user>_desktop cat /var/log/supervisor/xvfb.err.log
docker exec <user>_desktop cat /var/log/supervisor/openbox.err.log
docker exec <user>_desktop cat /var/log/supervisor/pcmanfm.err.log
```

**Fixes:**

1. Xvfb failed to start -- check display dimensions:

```bash
docker exec <user>_desktop supervisorctl restart xvfb
```

2. PCManFM (desktop renderer) crashed -- restart it:

```bash
docker exec <user>_desktop supervisorctl restart pcmanfm
```

3. Compositor conflict -- try disabling xcompmgr:

```bash
docker exec <user>_desktop supervisorctl stop xcompmgr
```

---

## VNC Connection Refused / Cannot Connect on Port 5900

**Symptom:** VNC client fails to connect; `Connection refused` on the VNC port.

**Diagnosis:**

```bash
# Check if x11vnc is running
docker exec <user>_desktop supervisorctl status x11vnc

# Check if the port is exposed on the host
ss -tlnp | grep <vnc_port>
```

**Fixes:**

1. x11vnc not started yet -- it waits 3 seconds for Xvfb:

```bash
docker exec <user>_desktop supervisorctl restart x11vnc
```

2. Wrong VNC password file -- regenerate it:

```bash
docker exec <user>_desktop x11vnc -storepasswd newpassword /root/.vnc/passwd
docker exec <user>_desktop supervisorctl restart x11vnc
```

3. Port conflict on host -- check if another container is already using that
   port and choose a different `vnc_port` for this user.

---

## Container Fails to Start: HOST_WORKSPACE is Not Set

**Symptom:** `docker compose up` fails with `variable is not set`.

**Cause:** You ran `docker compose up` directly instead of via `launch_user.sh`.
`HOST_WORKSPACE` is required and has no fallback default.

**Fix:** Always use `launch_user.sh` to start containers:

```bash
./launch_user.sh alice 8080 9090
```

---

## Files in /root/workspace Are Owned by Root on the Host

**Symptom:** After creating files inside the container, the files on the host
at `/mount/Data2/<user>/workspace` are owned by `root` (uid 0).

**Cause:** The container was launched without `HOST_UID` / `HOST_GID` being
set correctly, or the host caller is root.

**Diagnosis:**

```bash
# Check who launched the container
docker inspect <user>_desktop | grep -A5 Env | grep HOST_UID
```

**Fix:** Ensure `launch_user.sh` is called by the user whose UID should own
the files (not by root). The script reads `id -u` and `id -g` from the
calling shell.

```bash
# Correct the ownership after the fact
sudo chown -R $(id -u):$(id -g) /mount/Data2/<user>/workspace
```

---

## mounts.conf Entries Are Silently Ignored

**Symptom:** A directory listed in `mounts.conf` does not appear inside the
container.

**Diagnosis:** Check the output of `launch_user.sh` -- it prints WARN lines for
every skipped entry. Common reasons:

```
WARN: Host path does not exist, skipping: /mount/Data2/shared/datasets
```

```
WARN: Skipping entry with unknown mode 'RO' (use ro or rw): ...
```

```
WARN: Skipping invalid mounts.conf entry (expected host:container:mode): ...
```

**Fixes:**

1. Host path does not exist -- create the directory on the host before launching:

```bash
mkdir -p /mount/Data2/shared/datasets
./launch_user.sh alice 8080 9090
```

2. Mode is uppercase -- use lowercase `ro` or `rw`.

3. Path contains spaces -- avoid spaces in host and container paths.

4. Two-colon format violated -- verify the entry has exactly two colons:

```
/host/path:/container/path:ro    # correct
/host/path /container/path ro    # wrong (spaces instead of colons)
```

---

## Container Exits Immediately After Starting

**Symptom:** `docker ps` shows the container briefly then it disappears.
`docker ps -a` shows it in `Exited` state.

**Diagnosis:**

```bash
docker logs <user>_desktop
```

Common causes:

| Log message | Cause | Fix |
|-------------|-------|-----|
| `supervisord: error: ...` | supervisord.conf syntax error | Check `/etc/supervisor/supervisord.conf` inside image |
| `x11vnc -storepasswd failed` | VNC password too short | Use a password of at least 6 characters |
| `chown: cannot access '/root/workspace'` | `HOST_WORKSPACE` path doesn't exist on host | Create the directory before launching |

---

## Clipboard Copy-Paste Not Working in Browser

**Symptom:** Copying text in the browser noVNC window does not paste into
desktop applications, or vice versa.

**Diagnosis:**

```bash
docker exec <user>_desktop supervisorctl status autocutsel
```

**Fix:** Restart autocutsel:

```bash
docker exec <user>_desktop supervisorctl restart autocutsel
```

If the issue persists, open a terminal inside the container and run:

```bash
autocutsel -fork
autocutsel -selection PRIMARY -fork
```

---

## Checking All Service Logs at Once

```bash
docker exec <user>_desktop bash -c "
  for f in /var/log/supervisor/*.err.log; do
    echo \"=== \$f ===\"
    tail -5 \"\$f\"
  done
"
```

---

## Useful Diagnostic Commands

```bash
# Container status
docker ps | grep desktop

# Supervisor service status
docker exec <user>_desktop supervisorctl status

# Container resource usage
docker stats <user>_desktop --no-stream

# Check GPU from inside container
docker exec <user>_desktop nvidia-smi

# Check workspace ownership
docker exec <user>_desktop stat -c "%U %G %a %n" /root/workspace

# Check exposed ports
docker port <user>_desktop

# Tail supervisor master log
docker exec <user>_desktop tail -50 /var/log/supervisor/supervisord.log
```
