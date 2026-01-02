# Architecture: User-Agnostic Permission Model

## Problem This Solves

```bash
❌ BEFORE (Root Ownership Issue):
   docker run ... raven-desktop
   docker exec raven bash
   root@container# uv init myproject
   root@container# exit
   
   $ ls -la /workspace/
   drwxr-xr-x root root myproject/  ← CAN'T EDIT IN VS CODE
   
   Editing in VS Code:
   ⛔ Permission denied when trying to save

✅ AFTER (User-Matched Ownership):
   docker run ... -e HOST_UID=$(id -u) -e HOST_GID=$(id -g) ... raven-desktop
   docker exec --user $(whoami) raven bash
   saswata@container# uv init myproject
   saswata@container# exit
   
   $ ls -la /workspace/
   drwxr-xr-x saswata saswata myproject/  ← FULLY EDITABLE IN VS CODE
   
   Editing in VS Code:
   ✅ Full read/write access, no sudo needed
```

---

## Architecture Overview

### Container Startup Sequence

```bash
┌─────────────────────────────────────────────────────────────────┐
│                    Docker Container Boot                         │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ ENTRYPOINT: /usr/bin/tini --                                     │
│            /usr/local/bin/entrypoint-user.sh                     │
│                                                                   │
│ This is a lightweight signal handler that ensures proper         │
│ cleanup when container stops. It then calls entrypoint-user.sh  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ PHASE 1: entrypoint-user.sh                                      │
│                                                                   │
│ 1. Read HOST_UID from -e HOST_UID=1000                          │
│ 2. Read HOST_GID from -e HOST_GID=1000                          │
│ 3. Read HOST_USER from -e HOST_USER=saswata                     │
│                                                                   │
│ 4. Create group (GID 1000) if it doesn't exist                  │
│ 5. Create user (UID 1000, GID 1000) if it doesn't exist         │
│ 6. Execute CMD /startup.sh                                       │
│                                                                   │
│ Result: Container now has a user matching your host UID/GID     │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ PHASE 2: startup.sh (runs as root)                              │
│                                                                   │
│ 1. Detect HOST_UID=${HOST_UID} and HOST_GID=${HOST_GID}        │
│ 2. Run: chown -R ${HOST_UID}:${HOST_GID} /workspace             │
│    └─ Claims /workspace for the host user                       │
│                                                                   │
│ 3. Set: umask 0002                                               │
│    └─ Ensures new files are group-writable                      │
│                                                                   │
│ 4. Set up system services:                                       │
│    - X11 virtual display (Xvfb)                                  │
│    - D-Bus for IPC                                               │
│    - VNC server                                                  │
│    - Websocket bridge (noVNC)                                    │
│    - Nginx reverse proxy                                         │
│                                                                   │
│ 5. Launch supervisord to manage all services                     │
│                                                                   │
│ Result: Desktop is ready, /workspace owned by host user          │
└─────────────────────────────────────────────────────────────────┘
```

---

## File Ownership Flow

### When Container Starts

```bash
Host Machine:
  /codebase/ (owned by saswata:saswata, UID:GID 1000:1000)
      ↓
  docker run ... -e HOST_UID=1000 -e HOST_GID=1000 ... -v /codebase:/workspace
      ↓
Container /workspace/ (initially shows as 1000:1000 in container)
      ↓
  startup.sh detects HOST_UID=1000, HOST_GID=1000
      ↓
  chown -R 1000:1000 /workspace (re-claims for the matched user)
      ↓
Container /workspace/ (now owned by created user saswata:saswata)
```

### When User Creates Files Inside Container

```bash
docker exec --user saswata raven bash
saswata@container# uv init myproject
    ↓
Files created with owner: saswata (UID 1000)
Files created with group: saswata (GID 1000)
    ↓
docker exec raven ls -la /workspace/myproject/
    ↓
Container sees: saswata saswata (because UID:GID 1000:1000 matches)
    ↓
Host sees: saswata saswata (because UID:GID 1000:1000 matches)
    ↓
VS Code can edit without permission issues!
```

---

## Key Components

### 1. **entrypoint-user.sh**

- **Purpose:** Create a matching user inside the container
- **Input:** `HOST_UID`, `HOST_GID`, `HOST_USER` environment variables
- **Output:** User account that matches host UID/GID
- **Why:** Allows `docker exec --user $(whoami)` to work

### 2. **startup.sh** (Root Execution)

- **Purpose:** Configure system and claim workspace ownership
- **Key action:** `chown -R $HOST_UID:$HOST_GID /workspace`
- **Runs on:** Every container boot
- **Why:** Ensures consistent ownership even if `/workspace` is remounted

### 3. **umask 0002**

- **Purpose:** Make new files group-writable
- **Effect:** Files created as `rw-rw-r--` (0664) instead of `rw-r--r--` (0644)
- **Why:** Allows both host and container users to edit files (if in same group)

---

## Environment Variables Deep Dive

### **HOST_UID** (User ID)

```bash
# On your host machine:
$ id -u
1000

# Pass to container:
docker run -e HOST_UID=$(id -u) ...

# Inside container:
$ echo $HOST_UID
1000

# Effect: Container user gets UID 1000
# Result: Files appear as owned by your user on host
```

### **HOST_GID** (Group ID)

```bash
# On your host machine:
$ id -g
1000

# Pass to container:
docker run -e HOST_GID=$(id -g) ...

# Inside container:
$ echo $HOST_GID
1000

# Effect: Container user gets GID 1000
# Result: Files appear as owned by your group on host
```

### **HOST_USER** (Username)

```bash
# On your host machine:
$ whoami
saswata

# Pass to container:
docker run -e HOST_USER=$(whoami) ...

# Inside container:
$ echo $HOST_USER
saswata
$ whoami  # (if exec'd as that user)
saswata

# Effect: Container user is named 'saswata'
# Result: `docker exec --user saswata` works
```

---

## Why This Is Important

### UID/GID Mapping

```bash
Host Side              Container Side         File Result
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
saswata (UID 1000)  →  saswata (UID 1000)  →  ✅ MATCHES
saswata (GID 1000)  →  saswata (GID 1000)  →  ✅ MATCHES

Result: File created inside container appears as saswata:saswata on host
        ✅ Full permissions, no sudo needed
```

### If UIDs Don't Match

```bash
Host Side              Container Side         File Result
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
saswata (UID 1000)  →  Container uses UID 1000 differently
                       OR file created as root
                                            →  ❌ MISMATCH

Result: File appears as root:root or wrong:wrong on host
        ⛔ Permission denied when editing in VS Code
        ⛔ Need sudo to modify
```

---

## Visual Summary

```bash
┌───────────────────────────────────────────────────────────────┐
│                     Host Machine                              │
│  /workspace → /home/saswata/myproject (saswata:saswata)      │
└───────────┬───────────────────────────────────────────────────┘
            │
            │ docker run -e HOST_UID=1000 -e HOST_GID=1000
            │
            ↓
┌───────────────────────────────────────────────────────────────┐
│                 Docker Container                              │
│                                                               │
│  entrypoint-user.sh                                           │
│    └─ Create user: saswata (UID 1000, GID 1000)             │
│                                                               │
│  startup.sh                                                   │
│    ├─ chown -R 1000:1000 /workspace                          │
│    ├─ umask 0002                                             │
│    └─ Launch desktop services                                │
│                                                               │
│  /workspace ← Bind mount from host, now owned by UID 1000   │
│                                                               │
│  docker exec --user saswata raven bash                       │
│    └─ Create file: test.txt → Owned by saswata:saswata      │
│                                                               │
│  All files in /workspace → Match host ownership              │
└───────────┬───────────────────────────────────────────────────┘
            │
            ↓ Reflect back to host
┌───────────────────────────────────────────────────────────────┐
│                     Host Machine                              │
│  /workspace/test.txt → saswata:saswata (same as created!)    │
│                     ✅ Editable in VS Code                   │
│                     ✅ No sudo needed                         │
│                     ✅ Perfect permissions                    │
└───────────────────────────────────────────────────────────────┘
```

---

## Verification Checklist

- [ ] Container started with `-e HOST_UID=$(id -u)` ✓
- [ ] Container started with `-e HOST_GID=$(id -g)` ✓
- [ ] Container started with `-e HOST_USER=$(whoami)` ✓
- [ ] Exec'd into container with `--user $(whoami)` ✓
- [ ] Created test file inside container
- [ ] Checked ownership on host with `ls -la` (should match your user)
- [ ] Opened file in VS Code (should have full read/write access)
- [ ] Modified file in VS Code (no permission denied errors)

If all checks pass, the user-agnostic permission model is working correctly! ✅
