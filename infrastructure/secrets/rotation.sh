#!/usr/bin/env bash
set -euo pipefail

APP_NAME=""
HEALTH_URL="http://127.0.0.1:3000/health/firebase"
SECRETS_DIR="/etc/secrets"
SECRET_PREFIX="firebase_key_v"
CURRENT_LINK="${SECRETS_DIR}/firebase_key_current"
PREVIOUS_LINK="${SECRETS_DIR}/firebase_key_previous"
AUDIT_LOG="/var/log/xparq-secret-rotation.log"
OPERATOR="${USER:-unknown}"
SERVICE_USER=""
SERVICE_GROUP=""
JSON_FILE=""
BASE64_FILE=""
GRACE_PERIOD_SECONDS="300"
REVOKE_COMMAND=""

usage() {
  cat <<'EOF'
Usage:
  rotation.sh --app <pm2-app> [--json-file path | --base64-file path] [options]

Options:
  --app NAME                  PM2 application name (required)
  --json-file PATH            Raw Firebase service-account JSON to encode
  --base64-file PATH          File already containing base64 JSON
  --health-url URL            Health endpoint to verify after reload
  --secrets-dir PATH          Secret directory (default: /etc/secrets)
  --service-user USER         Owner for secret files
  --service-group GROUP       Group for secret files
  --operator NAME             Operator or automation identity
  --grace-period SECONDS      Delay before optional revoke hook (default: 300)
  --revoke-command CMD        Optional command run after success and grace period
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app) APP_NAME="$2"; shift 2 ;;
    --json-file) JSON_FILE="$2"; shift 2 ;;
    --base64-file) BASE64_FILE="$2"; shift 2 ;;
    --health-url) HEALTH_URL="$2"; shift 2 ;;
    --secrets-dir)
      SECRETS_DIR="$2"
      CURRENT_LINK="${SECRETS_DIR}/firebase_key_current"
      PREVIOUS_LINK="${SECRETS_DIR}/firebase_key_previous"
      shift 2
      ;;
    --service-user) SERVICE_USER="$2"; shift 2 ;;
    --service-group) SERVICE_GROUP="$2"; shift 2 ;;
    --operator) OPERATOR="$2"; shift 2 ;;
    --grace-period) GRACE_PERIOD_SECONDS="$2"; shift 2 ;;
    --revoke-command) REVOKE_COMMAND="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "${APP_NAME}" ]]; then
  echo "Missing required --app argument." >&2
  usage
  exit 1
fi

if [[ -z "${JSON_FILE}" && -z "${BASE64_FILE}" ]]; then
  echo "Provide --json-file or --base64-file." >&2
  exit 1
fi

if [[ -n "${JSON_FILE}" && -n "${BASE64_FILE}" ]]; then
  echo "Use either --json-file or --base64-file, not both." >&2
  exit 1
fi

mkdir -p "${SECRETS_DIR}"
chmod 0700 "${SECRETS_DIR}"
touch "${AUDIT_LOG}"
chmod 0600 "${AUDIT_LOG}"

if [[ -n "${JSON_FILE}" ]]; then
  NEW_BASE64="$(base64 -w 0 "${JSON_FILE}")"
else
  NEW_BASE64="$(tr -d '\n' < "${BASE64_FILE}")"
fi

if [[ -z "${NEW_BASE64}" ]]; then
  echo "The new secret payload is empty." >&2
  exit 1
fi

CURRENT_TARGET=""
if [[ -L "${CURRENT_LINK}" ]]; then
  CURRENT_TARGET="$(readlink -f "${CURRENT_LINK}")"
fi

if [[ -n "${CURRENT_TARGET}" ]] && [[ -f "${CURRENT_TARGET}" ]]; then
  CURRENT_BASE64="$(tr -d '\n' < "${CURRENT_TARGET}")"
  if [[ "${CURRENT_BASE64}" == "${NEW_BASE64}" ]]; then
    echo "Rotation skipped: current secret already matches the supplied credential."
    exit 0
  fi
fi

LAST_VERSION="0"
shopt -s nullglob
for file in "${SECRETS_DIR}/${SECRET_PREFIX}"*; do
  name="$(basename "${file}")"
  version="${name#${SECRET_PREFIX}}"
  if [[ "${version}" =~ ^[0-9]+$ ]] && (( version > LAST_VERSION )); then
    LAST_VERSION="${version}"
  fi
done
shopt -u nullglob

NEXT_VERSION=$((LAST_VERSION + 1))
NEW_FILE="${SECRETS_DIR}/${SECRET_PREFIX}${NEXT_VERSION}"
TMP_FILE="${NEW_FILE}.tmp"
printf '%s' "${NEW_BASE64}" > "${TMP_FILE}"
chmod 0600 "${TMP_FILE}"

if [[ -n "${SERVICE_USER}" ]]; then
  chown "${SERVICE_USER}${SERVICE_GROUP:+:${SERVICE_GROUP}}" "${TMP_FILE}"
fi

mv -f "${TMP_FILE}" "${NEW_FILE}"

PREVIOUS_TARGET=""
if [[ -L "${PREVIOUS_LINK}" ]]; then
  PREVIOUS_TARGET="$(readlink -f "${PREVIOUS_LINK}")"
fi

ln -sfn "${NEW_FILE}" "${CURRENT_LINK}"
if [[ -n "${CURRENT_TARGET}" ]]; then
  ln -sfn "${CURRENT_TARGET}" "${PREVIOUS_LINK}"
fi

echo "[$(date -Is)] operator=${OPERATOR} action=rotate_prepare app=${APP_NAME} version=${NEXT_VERSION}" >> "${AUDIT_LOG}"

if ! pm2 sendSignal SIGHUP "${APP_NAME}" >/dev/null; then
  echo "PM2 reload signal failed; rolling back symlink." >&2
  [[ -n "${CURRENT_TARGET}" ]] && ln -sfn "${CURRENT_TARGET}" "${CURRENT_LINK}"
  [[ -n "${PREVIOUS_TARGET}" ]] && ln -sfn "${PREVIOUS_TARGET}" "${PREVIOUS_LINK}"
  exit 1
fi

HEALTH_OK="false"
for _ in $(seq 1 20); do
  if curl --fail --silent --show-error "${HEALTH_URL}" >/dev/null; then
    HEALTH_OK="true"
    break
  fi
  sleep 2
done

if [[ "${HEALTH_OK}" != "true" ]]; then
  echo "Health verification failed; rolling back to previous secret." >&2
  [[ -n "${CURRENT_TARGET}" ]] && ln -sfn "${CURRENT_TARGET}" "${CURRENT_LINK}"
  if [[ -n "${PREVIOUS_TARGET}" ]]; then
    ln -sfn "${PREVIOUS_TARGET}" "${PREVIOUS_LINK}"
  elif [[ -n "${CURRENT_TARGET}" ]]; then
    ln -sfn "${CURRENT_TARGET}" "${PREVIOUS_LINK}"
  fi
  pm2 sendSignal SIGHUP "${APP_NAME}" >/dev/null || true
  echo "[$(date -Is)] operator=${OPERATOR} action=rotate_rollback app=${APP_NAME} target_version=${NEXT_VERSION}" >> "${AUDIT_LOG}"
  exit 1
fi

echo "[$(date -Is)] operator=${OPERATOR} action=rotate_success app=${APP_NAME} version=${NEXT_VERSION}" >> "${AUDIT_LOG}"

if [[ -n "${REVOKE_COMMAND}" ]] && [[ -n "${CURRENT_TARGET}" ]]; then
  sleep "${GRACE_PERIOD_SECONDS}"
  ROTATION_OLD_FILE="${CURRENT_TARGET}" \
  ROTATION_NEW_FILE="${NEW_FILE}" \
  ROTATION_VERSION="${NEXT_VERSION}" \
  bash -lc "${REVOKE_COMMAND}"
fi

echo "Rotation complete: version ${NEXT_VERSION} is now active."
