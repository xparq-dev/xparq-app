#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="${ROOT_DIR}/infrastructure/testing/logs"
PID_FILE="${LOG_DIR}/signaling.pid"
SIGNALING_LOG="${LOG_DIR}/signaling.log"

SIGNALING_PORT="${SIGNALING_PORT:-8080}"
SIGNALING_HOST="${SIGNALING_HOST:-127.0.0.1}"
SIGNALING_PUBLIC_ENDPOINT="${SIGNALING_PUBLIC_ENDPOINT:-http://${SIGNALING_HOST}:${SIGNALING_PORT}}"
REDIS_URL="${REDIS_URL:-redis://127.0.0.1:6379}"
DISABLE_PROTECTION="${DISABLE_PROTECTION:-true}"
REDIS_CONTAINER_NAME="${REDIS_CONTAINER_NAME:-xparq-redis-validation}"
TURN_COMPOSE_FILE="${TURN_COMPOSE_FILE:-${ROOT_DIR}/infrastructure/turn/docker-compose.yml}"
TURN_ENV_FILE="${TURN_ENV_FILE:-${ROOT_DIR}/infrastructure/turn/.env}"

mkdir -p "${LOG_DIR}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_cmd node
require_cmd curl

if command -v docker >/dev/null 2>&1; then
  if ! docker ps --format '{{.Names}}' | grep -Fxq "${REDIS_CONTAINER_NAME}"; then
    if docker ps -a --format '{{.Names}}' | grep -Fxq "${REDIS_CONTAINER_NAME}"; then
      docker start "${REDIS_CONTAINER_NAME}" >/dev/null
    else
      docker run -d \
        --name "${REDIS_CONTAINER_NAME}" \
        -p 6379:6379 \
        --health-cmd='redis-cli ping' \
        --health-interval=5s \
        --health-timeout=3s \
        --health-retries=10 \
        redis:7-alpine >/dev/null
    fi
  fi

  if [[ -f "${TURN_COMPOSE_FILE}" && -f "${TURN_ENV_FILE}" ]]; then
    docker compose \
      --env-file "${TURN_ENV_FILE}" \
      -f "${TURN_COMPOSE_FILE}" \
      up -d >/dev/null
  else
    echo "TURN compose skipped because ${TURN_COMPOSE_FILE} or ${TURN_ENV_FILE} is missing." >&2
  fi
else
  echo "Docker not found; Redis and TURN must already be running." >&2
fi

if [[ -f "${PID_FILE}" ]]; then
  existing_pid="$(cat "${PID_FILE}")"
  if kill -0 "${existing_pid}" >/dev/null 2>&1; then
    echo "Signaling already running with PID ${existing_pid}."
  else
    rm -f "${PID_FILE}"
  fi
fi

if [[ ! -f "${PID_FILE}" ]]; then
  (
    cd "${ROOT_DIR}/backend/signaling"
    PORT="${SIGNALING_PORT}" \
    REDIS_URL="${REDIS_URL}" \
    SIGNALING_PUBLIC_ENDPOINT="${SIGNALING_PUBLIC_ENDPOINT}" \
    DISABLE_PROTECTION="${DISABLE_PROTECTION}" \
    nohup node index.js >>"${SIGNALING_LOG}" 2>&1 &
    echo $! >"${PID_FILE}"
  )
fi

for _ in $(seq 1 30); do
  if curl -fsS "${SIGNALING_PUBLIC_ENDPOINT}/health" >/dev/null; then
    break
  fi
  sleep 1
done

echo "Validation stack ready."
echo "  SIGNALING_PUBLIC_ENDPOINT=${SIGNALING_PUBLIC_ENDPOINT}"
echo "  REDIS_URL=${REDIS_URL}"
echo "  DISABLE_PROTECTION=${DISABLE_PROTECTION}"
echo "  SIGNALING_PID=$(cat "${PID_FILE}")"
