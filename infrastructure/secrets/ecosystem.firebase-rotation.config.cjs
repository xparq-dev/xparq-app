module.exports = {
  apps: [
    {
      name: "xparq-backend",
      script: "backend/functions/lib/index.js",
      cwd: "/srv/xparq/current",
      interpreter: "/usr/bin/node",
      instances: 1,
      exec_mode: "fork",
      wait_ready: false,
      listen_timeout: 10000,
      kill_timeout: 30000,
      env: {
        NODE_ENV: "production",
        FIREBASE_ADMIN_KEY_FILE: "/etc/secrets/firebase_key_current",
        FIREBASE_ADMIN_SECONDARY_KEY_FILE: "/etc/secrets/firebase_key_previous",
        FIREBASE_ADMIN_RELOAD_GRACE_MS: "300000",
        SUPABASE_SERVICE_ROLE_KEY: process.env.SUPABASE_SERVICE_ROLE_KEY,
      },
    },
  ],
};
