#!/bin/bash
set -e
USER_NAME="${HOST_USER:-dev}"
USER_ID="${HOST_UID:-1000}"
GROUP_ID="${HOST_GID:-1000}"

# Create group if it doesn't exist (by GID)
if ! getent group "${GROUP_ID}" >/dev/null; then
  groupadd -g "${GROUP_ID}" "${USER_NAME}"
fi

# Create user if it doesn't exist (by UID)
if ! getent passwd "${USER_ID}" >/dev/null; then
  useradd -m -u "${USER_ID}" -g "${GROUP_ID}" -s /bin/bash "${USER_NAME}"
fi

exec "$@"
