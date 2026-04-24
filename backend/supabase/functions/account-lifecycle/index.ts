import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";

type SupabaseClient = ReturnType<typeof createClient>;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-account-admin-token",
};

type Action =
  | "request_delete"
  | "restore"
  | "purge_self"
  | "purge_user"
  | "purge_pending";

interface RequestBody {
  action?: Action;
  uid?: string;
  graceDays?: number;
  limit?: number;
}

function json(
  body: Record<string, unknown>,
  init?: ResponseInit,
): Response {
  const headers = new Headers(init?.headers);
  headers.set("Content-Type", "application/json");
  for (const [key, value] of Object.entries(corsHeaders)) {
    headers.set(key, value);
  }

  return new Response(JSON.stringify(body), {
    ...init,
    headers,
  });
}

function getEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

async function getAuthenticatedUser(
  req: Request,
  supabaseUrl: string,
  supabaseAnonKey: string,
) {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return null;
  }

  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: {
      headers: {
        Authorization: authHeader,
      },
    },
  });

  const {
    data: { user },
    error,
  } = await userClient.auth.getUser();

  if (error) {
    if (
      error.message.includes("missing sub claim") ||
      error.message.includes("Invalid JWT")
    ) {
      return null;
    }
    throw new Error(error.message);
  }

  return user;
}

async function archiveAccountIdentifier(
  serviceClient: SupabaseClient,
  uid: string,
) {
  const { data, error } = await serviceClient.auth.admin.getUserById(uid);
  if (error) {
    console.warn("[account-lifecycle] archive lookup failed:", error.message);
    return;
  }

  const identifier = data.user?.email ?? data.user?.phone;
  if (!identifier) {
    return;
  }

  const { error: archiveError } = await serviceClient
    .from("archived_accounts")
    .upsert({
      identifier,
      permanently_deleted_at: new Date().toISOString(),
    });

  if (archiveError) {
    throw new Error(archiveError.message);
  }
}

async function hardDeleteUser(
  serviceClient: SupabaseClient,
  uid: string,
) {
  await archiveAccountIdentifier(serviceClient, uid);

  const { error: messageDeleteError } = await serviceClient
    .from("messages")
    .delete()
    .eq("sender_id", uid);

  if (messageDeleteError) {
    throw new Error(messageDeleteError.message);
  }

  const { error: chatCleanupError } = await serviceClient.rpc(
    "cleanup_deleted_user_chat_references",
    { p_uid: uid },
  );

  if (chatCleanupError) {
    throw new Error(chatCleanupError.message);
  }

  const { error: deleteError } = await serviceClient.auth.admin.deleteUser(uid);
  if (deleteError) {
    throw new Error(deleteError.message);
  }
}

async function requestDelete(
  serviceClient: SupabaseClient,
  uid: string,
) {
  const { error } = await serviceClient
    .from("profiles")
    .update({
      account_status: "pending_deletion",
      deletion_requested_at: new Date().toISOString(),
      is_online: false,
    })
    .eq("id", uid);

  if (error) {
    throw new Error(error.message);
  }
}

async function restoreDelete(
  serviceClient: SupabaseClient,
  uid: string,
) {
  const { error } = await serviceClient
    .from("profiles")
    .update({
      account_status: "active",
      deletion_requested_at: null,
      is_online: true,
    })
    .eq("id", uid);

  if (error) {
    throw new Error(error.message);
  }
}

async function purgePendingUsers(
  serviceClient: SupabaseClient,
  graceDays: number,
  limit: number,
) {
  const cutoff = new Date(Date.now() - graceDays * 24 * 60 * 60 * 1000)
    .toISOString();

  const { data: profiles, error } = await serviceClient
    .from("profiles")
    .select("id")
    .eq("account_status", "pending_deletion")
    .not("deletion_requested_at", "is", null)
    .lte("deletion_requested_at", cutoff)
    .limit(limit);

  if (error) {
    throw new Error(error.message);
  }

  const purged: string[] = [];
  for (const profile of profiles ?? []) {
    await hardDeleteUser(serviceClient, profile.id as string);
    purged.push(profile.id as string);
  }

  return purged;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = getEnv("SUPABASE_URL");
    const supabaseAnonKey = getEnv("SUPABASE_ANON_KEY");
    const supabaseServiceRoleKey = getEnv("SUPABASE_SERVICE_ROLE_KEY");
    const adminToken = Deno.env.get("ACCOUNT_PURGE_ADMIN_TOKEN");

    const serviceClient = createClient(supabaseUrl, supabaseServiceRoleKey);
    const body = (await req.json()) as RequestBody;
    const action = body.action ?? "request_delete";
    const requestAdminToken = req.headers.get("x-account-admin-token");
    const isAdminRequest =
      !!adminToken && !!requestAdminToken && adminToken === requestAdminToken;
    const needsUserSession =
      action === "request_delete" || action === "restore" || action === "purge_self";
    const user = needsUserSession
      ? await getAuthenticatedUser(req, supabaseUrl, supabaseAnonKey)
      : null;

    switch (action) {
      case "request_delete": {
        if (!user) {
          return json({ error: "Unauthorized" }, { status: 401 });
        }

        await requestDelete(serviceClient, user.id);
        return json({ success: true, uid: user.id, status: "pending_deletion" });
      }

      case "restore": {
        if (!user) {
          return json({ error: "Unauthorized" }, { status: 401 });
        }

        await restoreDelete(serviceClient, user.id);
        return json({ success: true, uid: user.id, status: "active" });
      }

      case "purge_self": {
        if (!user) {
          return json({ error: "Unauthorized" }, { status: 401 });
        }

        await hardDeleteUser(serviceClient, user.id);
        return json({ success: true, uid: user.id, purged: true });
      }

      case "purge_user": {
        if (!isAdminRequest) {
          return json({ error: "Forbidden" }, { status: 403 });
        }

        if (!body.uid) {
          return json({ error: "Missing uid" }, { status: 400 });
        }

        await hardDeleteUser(serviceClient, body.uid);
        return json({ success: true, uid: body.uid, purged: true });
      }

      case "purge_pending": {
        if (!isAdminRequest) {
          return json({ error: "Forbidden" }, { status: 403 });
        }

        const purged = await purgePendingUsers(
          serviceClient,
          body.graceDays ?? 30,
          body.limit ?? 100,
        );

        return json({ success: true, purgedCount: purged.length, purged });
      }

      default:
        return json({ error: `Unsupported action: ${action}` }, { status: 400 });
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("[account-lifecycle]", message);
    return json({ error: message }, { status: 500 });
  }
});
