# Production Secret Rotation

This repository previously contained a tracked Firebase admin service-account key.
Treat that credential as compromised and complete this rotation before launch.

## Immediate Actions

1. Disable and delete the leaked Firebase admin key for `firebase-adminsdk-fbsvc@iXPARQ-app.iam.gserviceaccount.com`.
2. Create a replacement key only if a JSON key is still required.
3. Prefer workload identity or runtime secret injection instead of committing service-account JSON files.

## Secrets That Must Be Runtime-Injected

- `TURN_AUTH_SECRET`
- `ICE_POLICY_TOKEN_SECRET`
- `SUPABASE_SERVICE_ROLE_KEY`
- `CHAT_SECRET`
- Firebase admin credentials

## Deployment Rules

- Never commit service-account JSON files.
- Keep `.env` files out of git. Use `.env.example` for non-secret placeholders only.
- Inject Flutter secrets with `--dart-define` in CI/CD.
- Inject backend secrets through the runtime environment or your secret manager.

## Launch Gate

Production launch remains blocked until the leaked Firebase admin key has been rotated in the live project.
