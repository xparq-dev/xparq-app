import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';

import 'dotenv/config';
import { createClient } from '@supabase/supabase-js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

function env(name, fallback = undefined) {
  const value = process.env[name];
  if (value == null || value === '') {
    if (fallback !== undefined) {
      return fallback;
    }

    throw new Error(`Missing required environment variable: ${name}`);
  }

  return value;
}

function numberEnv(name, fallback) {
  const value = process.env[name];
  if (value == null || value === '') {
    return fallback;
  }

  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed)) {
    throw new Error(`Environment variable ${name} must be an integer.`);
  }

  return parsed;
}

function resolveOutputPath() {
  const configuredPath = process.env.TOKENS_FILE || './tokens.json';
  if (path.isAbsolute(configuredPath)) {
    return configuredPath;
  }

  return path.resolve(process.cwd(), configuredPath);
}

async function main() {
  const supabaseUrl = env('SUPABASE_URL');
  const supabaseAnonKey = env('SUPABASE_ANON_KEY');
  const supabaseServiceRoleKey = env('SUPABASE_SERVICE_ROLE_KEY');
  const userCount = numberEnv('TOKEN_USER_COUNT', 20);
  const password = env('TOKEN_USER_PASSWORD', `LoadTest!${Date.now()}Aa1`);
  const batchId = process.env.TOKEN_BATCH_ID || Date.now().toString();
  const emailPrefix = process.env.TOKEN_EMAIL_PREFIX || 'loadtest';
  const outputPath = resolveOutputPath();

  const adminClient = createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  const users = [];

  for (let index = 0; index < userCount; index += 1) {
    const email = `${emailPrefix}.${batchId}.${index + 1}@example.com`;
    const createResponse = await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        loadTest: true,
        batchId,
      },
    });

    if (createResponse.error || !createResponse.data.user) {
      throw new Error(
        `Failed to create confirmed user ${email}: ${createResponse.error?.message || 'unknown error'}`,
      );
    }

    const authClient = createClient(supabaseUrl, supabaseAnonKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
      global: {
        headers: {
          'x-client-info': `xparq-load-validation/${randomUUID()}`,
        },
      },
    });

    const signInResponse = await authClient.auth.signInWithPassword({
      email,
      password,
    });

    if (signInResponse.error || !signInResponse.data.session) {
      throw new Error(
        `Failed to sign in confirmed user ${email}: ${signInResponse.error?.message || 'missing session'}`,
      );
    }

    users.push({
      userId: signInResponse.data.user.id,
      token: signInResponse.data.session.access_token,
      email,
    });
  }

  await fs.mkdir(path.dirname(outputPath), { recursive: true });
  await fs.writeFile(outputPath, JSON.stringify(users, null, 2), 'utf8');

  console.log(
    JSON.stringify(
      {
        ok: true,
        outputPath,
        userCount: users.length,
        batchId,
        passwordLength: password.length,
      },
      null,
      2,
    ),
  );
}

main().catch((error) => {
  console.error(
    JSON.stringify(
      {
        ok: false,
        error: error.message,
      },
      null,
      2,
    ),
  );
  process.exitCode = 1;
});
