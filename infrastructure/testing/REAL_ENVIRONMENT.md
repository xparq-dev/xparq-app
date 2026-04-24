# Real Validation Environment

This folder now supports a real production-like validation flow with:

- confirmed Supabase test users via the Admin API
- normalized `API_BASE_URL` handling for signaling HTTP calls
- derived `SOCKET_URL` defaults for Socket.IO
- an explicit `DISABLE_PROTECTION=true` bypass for controlled load tests
- Linux startup scripts for Redis, signaling, and TURN bring-up

## Required environment

Copy `.env.validation.example` to a local env file and provide:

- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_ANON_KEY`
- `SUPABASE_URL`
- `API_BASE_URL`
- `TURN_DOMAIN` or `TURN_HOST`

## Generate real tokens

```bash
cd infrastructure/testing
npm run generate-real-tokens
```

This writes `TOKENS_FILE` in the format:

```json
[
  { "userId": "...", "token": "...", "email": "..." }
]
```

## Start validation stack on Linux VPS

```bash
cd infrastructure/testing
./start-validation-stack.sh
```

This script:

- starts Redis in Docker if available
- starts coturn from `infrastructure/turn/docker-compose.yml` if its env file exists
- starts the Node signaling service with `DISABLE_PROTECTION=true`

## Verify environment

```bash
npm run check-health
npm run smoke-join
```

## Run load tests

```bash
npm run join-storm
npm run reconnect-storm
npm run forced-turn
```

## Stop validation stack

```bash
./stop-validation-stack.sh
```
