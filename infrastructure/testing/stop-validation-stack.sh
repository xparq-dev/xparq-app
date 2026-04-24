#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="${ROOT_DIR}/infrastructure/testing/logs"
PID_FILE="${LOG_DIR}/signaling.pid"
REDIS_CONTAINER_NAME="${REDIS_CONTAINER_NAME:-xparq-redis-validation}"
TURN_COMPOSE_FILE="${TURN_COMPOSE_FILE:-${ROOT_DIR}/infrastructure/turn/docker-compose.yml}"
TURN_ENV_FILE="${TURN_ENV_FILE:-${ROOT_DIR}/infrastructure/turn/.env}"

if [[ -f "${PID_FILE}" ]]; then
  pid="$(cat "${PID_FILE}")"
  if kill -0 "${pid}" >/dev/null 2>&1; then
    kill "${pid}"
  fi
  rm -f "${PID_FILE}"
fi

if command -v docker >/dev/null 2>&1; then
  if docker ps -a --format '{{.Names}}' | grep -Fxq "${REDIS_CONTAINER_NAME}"; then
    docker stop "${REDIS_CONTAINER_NAME}" >/dev/null || true
  fi

  if [[ -f "${TURN_COMPOSE_FILE}" && -f "${TURN_ENV_FILE}" ]]; then
    docker compose \
      --env-file "${TURN_ENV_FILE}" \
      -f "${TURN_COMPOSE_FILE}" \
      down >/dev/null || true
  fi
fi

echo "Validation stack stopped."
