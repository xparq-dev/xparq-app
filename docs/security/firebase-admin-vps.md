# Firebase Admin On VPS

This backend must not store a Firebase service-account JSON file in the repository.

## 1. Store The Secret Outside The Project

Use a temporary local copy of the Firebase service-account JSON and upload only the base64 form to the VPS:

```bash
base64 -w 0 ./firebase-admin.json > /tmp/firebase-admin.b64
sudo install -d -m 0700 /etc/secrets
sudo install -m 0600 /tmp/firebase-admin.b64 /etc/secrets/firebase_admin_sdk.b64
shred -u /tmp/firebase-admin.b64
```

## 2. Inject At Runtime

Systemd example:

```bash
sudo tee /etc/systemd/system/xparq-backend.service >/dev/null <<'EOF'
[Unit]
Description=XPARQ Backend
After=network.target

[Service]
User=xparq
Group=xparq
WorkingDirectory=/srv/xparq/current
Environment=NODE_ENV=production
Environment=FIREBASE_ADMIN_SDK_BASE64_FILE=/etc/secrets/firebase_admin_sdk.b64
ExecStart=/usr/bin/bash -lc 'export FIREBASE_ADMIN_SDK_BASE64="$(cat "$FIREBASE_ADMIN_SDK_BASE64_FILE")"; exec /usr/bin/node backend/functions/lib/index.js'
Restart=always
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadOnlyPaths=/srv/xparq/current
ReadWritePaths=/var/log/xparq

[Install]
WantedBy=multi-user.target
EOF
```

PM2 example:

```js
module.exports = {
  apps: [{
    name: "xparq-backend",
    script: "backend/functions/lib/index.js",
    cwd: "/srv/xparq/current",
    interpreter: "/usr/bin/node",
    env: {
      NODE_ENV: "production",
      FIREBASE_ADMIN_SDK_BASE64: require("fs")
        .readFileSync("/etc/secrets/firebase_admin_sdk.b64", "utf8")
        .trim(),
    },
  }],
};
```

## 3. Runtime Variables

- `FIREBASE_ADMIN_SDK_BASE64`
- `SUPABASE_SERVICE_ROLE_KEY`

## 4. Rotation

1. Create a new service-account key in Firebase or GCP IAM.
2. Replace `/etc/secrets/firebase_admin_sdk.b64`.
3. Restart the process manager.
4. Verify health checks and notification delivery.
5. Revoke the old key immediately.
