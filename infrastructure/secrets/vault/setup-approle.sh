#!/usr/bin/env bash
set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:?VAULT_ADDR is required}"
VAULT_TOKEN="${VAULT_TOKEN:?VAULT_TOKEN is required}"

vault login "${VAULT_TOKEN}"
vault secrets enable -path=secret kv-v2 || true
vault auth enable approle || true
vault policy write firebase-admin-read infrastructure/secrets/vault/policy.hcl
vault write auth/approle/role/xparq-backend \
  token_policies="firebase-admin-read" \
  token_ttl="15m" \
  token_max_ttl="1h" \
  secret_id_ttl="24h" \
  secret_id_num_uses="10"

echo "Role ID:"
vault read -field=role_id auth/approle/role/xparq-backend/role-id
echo
echo "Secret ID:"
vault write -field=secret_id -f auth/approle/role/xparq-backend/secret-id
