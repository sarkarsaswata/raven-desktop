# Quick Reference: User-Agnostic Container Commands

## One-Liner: Start Container

```bash
docker run -d --name raven \
  -e HOST_UID=$(id -u) -e HOST_GID=$(id -g) -e HOST_USER=$(whoami) \
  -v /path/to/codebase:/workspace \
  -p 80:80 -p 5900:5900 \
  --shm-size=2g \
  sarkarsaswata001/raven-desktop:cuda-11.8
```

## One-Liner: Interactive Bash (Correct)

```bash
docker exec -it --user $(whoami) raven bash
```

---

## Inside the Container (These Preserve Ownership)

```bash
# Create virtual environment
uv venv

# Initialize new project
uv init my-project

# Clone a repository
git clone https://github.com/user/repo.git

# Edit files (no sudo required on host afterward)
nano file.txt

# Install dependencies
uv pip install package-name

# Run Python scripts
python script.py
```

---

## Verify Ownership Is Correct

```bash
# On host machine
ls -la /path/to/codebase/

# Expected output:
# -rw-r--r--  yourname  yourgroup  1234  Jan  2 10:30 file.txt
# drwxr-xr-x  yourname  yourgroup  4096  Jan  2 10:30 .venv/
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Files show `root:root` ownership | Did you forget `-e HOST_UID=$(id -u) -e HOST_GID=$(id -g)` when running container? |
| Can't edit files in VS Code | Did you exec as root instead of `--user $(whoami)`? |
| `bash: sudo: command not found` | Development user doesn't need sudo inside container; use `docker exec --user root` for system access if needed |
| Files are `1000:1000` but you're `1001:1001` | Your UID doesn't match; regenerate container with correct `HOST_UID=$(id -u)` |

---

## Environment Variables Summary

| Variable | Example | Purpose |
|----------|---------|---------|
| `HOST_UID` | `1000` | Your user ID (from `id -u`) |
| `HOST_GID` | `1000` | Your group ID (from `id -g`) |
| `HOST_USER` | `saswata` | Your username (from `whoami`) |
| `VNC_PASSWORD` | `secure123` | Password for remote desktop access |

---

## Advanced: Multiple Containers

```bash
# Container 1 (port 80)
docker run -d --name raven1 \
  -e HOST_UID=$(id -u) -e HOST_GID=$(id -g) -e HOST_USER=$(whoami) \
  -p 80:80 \
  -v /workspace1:/workspace \
  raven-desktop:latest

# Container 2 (port 8082)
docker run -d --name raven2 \
  -e HOST_UID=$(id -u) -e HOST_GID=$(id -g) -e HOST_USER=$(whoami) \
  -p 8082:80 \
  -v /workspace2:/workspace \
  raven-desktop:latest

# Access each
docker exec -it --user $(whoami) raven1 bash
docker exec -it --user $(whoami) raven2 bash
```

---

## Access Remote Desktop

1. **Web Browser:** `http://localhost` (or `http://localhost:8082` for port 8082)
2. **VNC Client:** `localhost:5900` (or configured port)
3. **Inside Desktop:** Open terminal → Bash commands work with correct ownership
