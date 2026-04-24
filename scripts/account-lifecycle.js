#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");

function printUsage() {
  console.log(`Usage:
  node scripts/account-lifecycle.js purge-user <uid>
  node scripts/account-lifecycle.js purge-pending [graceDays] [limit]

Environment:
  SUPABASE_URL
  ACCOUNT_PURGE_ADMIN_TOKEN
  SUPABASE_ANON_KEY (optional if present in lib/shared/config/supabase_config.dart)`);
}

function readAnonKeyFallback() {
  try {
    const configPath = path.join(
      process.cwd(),
      "lib",
      "shared",
      "config",
      "supabase_config.dart",
    );
    const content = fs.readFileSync(configPath, "utf8");
    const match = content.match(/static const String anonKey = '([^']+)'/);
    return match ? match[1] : null;
  } catch {
    return null;
  }
}

async function invoke(body) {
  const supabaseUrl = process.env.SUPABASE_URL;
  const adminToken = process.env.ACCOUNT_PURGE_ADMIN_TOKEN;
  const anonKey = process.env.SUPABASE_ANON_KEY || readAnonKeyFallback();

  if (!supabaseUrl) {
    console.error("Missing SUPABASE_URL");
    process.exit(1);
  }

  if (!adminToken) {
    console.error("Missing ACCOUNT_PURGE_ADMIN_TOKEN");
    process.exit(1);
  }

  if (!anonKey) {
    console.error("Missing SUPABASE_ANON_KEY");
    process.exit(1);
  }

  const endpoint = `${supabaseUrl.replace(/\/$/, "")}/functions/v1/account-lifecycle`;
  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: anonKey,
      Authorization: `Bearer ${anonKey}`,
      "x-account-admin-token": adminToken,
    },
    body: JSON.stringify(body),
  });

  const text = await response.text();
  let data;
  try {
    data = text ? JSON.parse(text) : {};
  } catch {
    data = { raw: text };
  }

  if (!response.ok) {
    throw new Error(JSON.stringify(data, null, 2));
  }

  console.log(JSON.stringify(data, null, 2));
}

async function main() {
  const action = process.argv[2];
  const arg1 = process.argv[3];
  const arg2 = process.argv[4];

  switch (action) {
    case "purge-user":
      if (!arg1) {
        printUsage();
        process.exit(1);
      }
      await invoke({ action: "purge_user", uid: arg1 });
      break;

    case "purge-pending":
      await invoke({
        action: "purge_pending",
        graceDays: arg1 ? Number(arg1) : 30,
        limit: arg2 ? Number(arg2) : 100,
      });
      break;

    default:
      printUsage();
      process.exit(1);
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
