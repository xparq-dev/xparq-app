# Secret Rotation And Vault

## Files

- `rotation.sh`: zero-downtime blue/green rotation script for PM2-managed services
- `ecosystem.firebase-rotation.config.cjs`: PM2 sample config using versioned secret symlinks
- `file-permissions.sh`: prepares `/etc/secrets` with restrictive permissions
- `vault/`: Vault install, policy, and AppRole setup
- `node/firebaseAdminVaultClient.mjs`: Vault client with periodic refresh and last-known-good fallback

## Symlink Layout

- `/etc/secrets/firebase_key_current`
- `/etc/secrets/firebase_key_previous`

Both files contain base64-encoded service-account JSON, never raw JSON.
