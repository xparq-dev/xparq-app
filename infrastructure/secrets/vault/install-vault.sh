#!/usr/bin/env bash
set -euo pipefail

VAULT_VERSION="${VAULT_VERSION:-1.18.3}"
VAULT_ZIP="vault_${VAULT_VERSION}_linux_amd64.zip"

curl -fsSLo "/tmp/${VAULT_ZIP}" "https://releases.hashicorp.com/vault/${VAULT_VERSION}/${VAULT_ZIP}"
unzip -o "/tmp/${VAULT_ZIP}" -d /tmp
sudo install -m 0755 /tmp/vault /usr/local/bin/vault
sudo useradd --system --home /etc/vault.d --shell /bin/false vault 2>/dev/null || true
sudo install -d -o vault -g vault -m 0750 /etc/vault.d /opt/vault/data /var/log/vault

cat <<'EOF'
Vault binary installed.
Next steps:
1. Create /etc/vault.d/vault.hcl
2. Start Vault
3. Initialize and unseal
EOF
