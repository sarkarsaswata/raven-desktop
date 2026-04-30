# Volume Mounts and mounts.conf

**docker_ubuntu — Per-user flexible volume mount system**

---

## Overview

Each container always receives one fixed workspace mount defined in
`compose.yaml`. Beyond that, users can declare any number of additional
host directories to mount into their container by editing a simple
`mounts.conf` file in their data directory.

```
Host                                    Container
─────────────────────────────────────────────────────
/mount/Data2/<user>/workspace    →  /root/workspace   (rw, always)
/mount/Data2/<user>/mounts.conf  →  (read by launcher, not mounted)

Entries from mounts.conf:
/mount/Data2/shared/datasets     →  /root/datasets    (ro, optional)
/mount/Data2/<user>/codebase     →  /root/codebase    (rw, optional)
```

The additional mounts are injected at launch time via an ephemeral Docker
Compose override file. No permanent configuration change is needed.

---

## Fixed Mount (always present)

Defined in `compose.yaml` and cannot be overridden:

```yaml
volumes:
  - ${HOST_WORKSPACE}:/root/workspace:rw
```

`HOST_WORKSPACE` resolves to `/mount/Data2/<username>/workspace` and is set
by `launch_user.sh`. The workspace is created automatically on first launch
if it does not exist.

---

## mounts.conf Location

```
/mount/Data2/<username>/mounts.conf
```

A template file is created automatically by `launch_user.sh` on the first
launch for a given user if the file does not already exist.

---

## File Format

```
# This is a comment. Blank lines are also ignored.

host_path:container_path:mode
```

- `host_path` -- absolute path on the host machine
- `container_path` -- absolute path inside the container
- `mode` -- `ro` (read-only) or `rw` (read-write)

Each non-comment, non-blank line must have exactly this three-part format.
Entries that fail validation are skipped with a warning; the container still
starts with the remaining valid entries.

### Example mounts.conf

```
# Shared dataset directory (read-only so no user can delete shared data)
/mount/Data2/shared/datasets:/root/datasets:ro

# Personal codebase (read-write for active development)
/mount/Data2/alice/codebase:/root/codebase:rw

# Shared model checkpoints (read-only)
/mount/Data2/shared/checkpoints:/root/checkpoints:ro

# Scratch space for large outputs (read-write)
/mount/Data2/alice/scratch:/root/scratch:rw
```

---

## Validation Rules (applied by launch_user.sh)

| Condition | Behaviour |
|-----------|-----------|
| Line starts with `#` | Silently skipped |
| Blank line | Silently skipped |
| Fewer than 2 colons | WARN, skipped |
| `mode` is not `ro` or `rw` | WARN, skipped |
| `container_path` is `/root/workspace` | WARN, skipped (reserved) |
| `host_path` does not exist on host | WARN, skipped |
| All other entries | Added to compose override |

The container is always launched even if all `mounts.conf` entries are
invalid. A missing or entirely commented-out file means no extra mounts.

---

## How the Override is Generated

`launch_user.sh` collects the valid entries from `mounts.conf` and writes
a temporary YAML file to `/tmp/<username>_compose_override.yml`:

```yaml
services:
  ubuntu-desktop:
    volumes:
      - /mount/Data2/shared/datasets:/root/datasets:ro
      - /mount/Data2/alice/codebase:/root/codebase:rw
```

It is then passed to Docker Compose as a second `-f` argument:

```bash
docker compose \
  -p alice_project \
  -f compose.yaml \
  -f /tmp/alice_compose_override.yml \
  up -d
```

The override file is automatically removed by a `trap` when `launch_user.sh`
exits, whether the launch succeeded or failed.

---

## Applying Changes

Compose volumes are set at container creation time. To apply changes to
`mounts.conf` you must stop and re-launch the container:

```bash
# Stop
docker compose -p alice_project down

# Edit mounts.conf
nano /mount/Data2/alice/mounts.conf

# Re-launch
./launch_user.sh alice 8080 9090
```

---

## Recommended Mount Layout

The table below describes a typical multi-user setup on a shared machine.

| Host path | Container path | Mode | Purpose |
|-----------|---------------|------|---------|
| `/mount/Data2/<user>/workspace` | `/root/workspace` | rw | Personal workspace (fixed) |
| `/mount/Data2/<user>/codebase` | `/root/codebase` | rw | Personal code repo |
| `/mount/Data2/<user>/scratch` | `/root/scratch` | rw | Large temporary outputs |
| `/mount/Data2/shared/datasets` | `/root/datasets` | ro | Shared datasets |
| `/mount/Data2/shared/models` | `/root/models` | ro | Shared pre-trained models |

Using `ro` for shared directories prevents any single user from corrupting
data that other users depend on.

---

## Notes on Paths with Spaces

`launch_user.sh` uses `cut -d':'` to parse entries. Host or container paths
that contain colons or spaces will be parsed incorrectly. Avoid spaces and
colons in mount paths. If your paths require them, quote them and test
carefully.

---

## Reserved Container Paths

The following paths are managed by `compose.yaml` or startup scripts and
must not be declared in `mounts.conf`:

| Path | Reason |
|------|--------|
| `/root/workspace` | Fixed workspace mount (compose.yaml) |
| `/dev/shm` | Shared memory mount (compose.yaml) |
| `/run/udev` | Device event socket (compose.yaml) |
| `/tmp/.X11-unix` | X11 socket (compose.yaml) |
