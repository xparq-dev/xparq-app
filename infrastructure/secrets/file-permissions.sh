#!/usr/bin/env bash
set -euo pipefail

SERVICE_USER="${1:-xparq}"
SERVICE_GROUP="${2:-xparq}"
SECRETS_DIR="${3:-/etc/secrets}"

sudo install -d -m 0700 -o "${SERVICE_USER}" -g "${SERVICE_GROUP}" "${SECRETS_DIR}"
sudo touch "${SECRETS_DIR}/.keep"
sudo chown "${SERVICE_USER}:${SERVICE_GROUP}" "${SECRETS_DIR}/.keep"
sudo chmod 0600 "${SECRETS_DIR}/.keep"

echo "Secret directory prepared at ${SECRETS_DIR} for ${SERVICE_USER}:${SERVICE_GROUP}"
