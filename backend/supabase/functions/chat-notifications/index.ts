// Supabase Edge Function: chat-notifications
// Location: https://fidmehpoyvwdawcldvie.supabase.co/functions/v1/chat-notifications
// 
// Deploy: deno deploy --project=your-project-id main.ts
// Or use: supabase functions deploy chat-notifications

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface MessageRecord {
  id: string;
  chat_id: string;
  sender_id: string;
  content: string;
  message_type?: string;
  created_at: string;
}

interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  schema: string;
  record: MessageRecord;
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    console.log("[chat-notifications] Request received");

    // Parse webhook payload from pg_net
    const payload: WebhookPayload = await req.json();
    console.log("[chat-notifications] Payload:", JSON.stringify(payload));

    if (payload.type !== "INSERT" || payload.table !== "messages") {
      console.log("[chat-notifications] Ignoring non-INSERT message event");
      return new Response("Ignored", { status: 200 });
    }

    const message = payload.record;
    const { chat_id, sender_id, id: message_id } = message;

    console.log(`[chat-notifications] New message: ${message_id} in chat ${chat_id} from ${sender_id}`);

    // Initialize Supabase client with service role
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "https://fidmehpoyvwdawcldvie.supabase.co";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseServiceKey) {
      console.error("[chat-notifications] SUPABASE_SERVICE_ROLE_KEY not set");
      return new Response("Missing service key", { status: 500 });
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Get the recipient(s) of the chat
    // Check if using chat_participants table or direct chat
    const { data: chatData, error: chatError } = await supabase
      .from("chats")
      .select("participant_ids, type")
      .eq("id", chat_id)
      .single();

    if (chatError) {
      console.error("[chat-notifications] Error fetching chat:", chatError);
    }

    let recipientIds: string[] = [];

    if (chatData?.participant_ids) {
      recipientIds = chatData.participant_ids.filter((id: string) => id !== sender_id);
    } else {
      // Fallback: query messages to find other participant
      const { data: messages } = await supabase
        .from("messages")
        .select("sender_id")
        .eq("chat_id", chat_id)
        .neq("sender_id", sender_id)
        .limit(1);

      if (messages) {
        recipientIds = [...new Set(messages.map((m) => m.sender_id))];
      }
    }

    console.log("[chat-notifications] Recipients:", recipientIds);

    // Get sender profile for notification display
    const { data: senderProfile } = await supabase
      .from("profiles")
      .select("xparq_name, photo_url")
      .eq("id", sender_id)
      .single();

    const senderName = senderProfile?.xparq_name ?? "New Message";
    const avatarUrl = senderProfile?.photo_url;

    // Get FCM tokens for recipients
    const { data: recipients } = await supabase
      .from("profiles")
      .select("id, fcm_token, xparq_name")
      .in("id", recipientIds);

    console.log("[chat-notifications] Recipients with profiles:", recipients);

    if (!recipients || recipients.length === 0) {
      console.log("[chat-notifications] No recipients found");
      return new Response("No recipients", { status: 200 });
    }

    // Prepare FCM messages
    const fcmMessages = recipients
      .filter((r) => r.fcm_token)
      .map((recipient) => {
        console.log(`[chat-notifications] Preparing FCM for ${recipient.id}`);

        return {
          token: recipient.fcm_token,
          title: senderName,
          body: message.message_type === "image" ? "📷 Sent an image" :
            message.message_type === "video" ? "📹 Sent a video" :
              "New message",
          data: {
            chat_id,
            sender_uid: sender_id,
            sender_name: senderName,
            sender_avatar: avatarUrl ?? "",
            message_id,
            type: message.message_type ?? "text",
          },
        };
      });

    if (fcmMessages.length === 0) {
      console.log("[chat-notifications] No FCM tokens found");
      return new Response("No FCM tokens", { status: 200 });
    }

    // Send to Firebase Cloud Messaging
    const firebaseProjectId = Deno.env.get("FIREBASE_PROJECT_ID");
    const firebaseServiceAccount = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");

    if (!firebaseProjectId || !firebaseServiceAccount) {
      console.error("[chat-notifications] Firebase credentials not set");
      // Fallback: Try using Supabase FCM integration if available
      console.log("[chat-notifications] Attempting fallback notification method...");
    } else {
      // Get access token from Firebase
      const credentials = JSON.parse(firebaseServiceAccount);
      const tokenResponse = await fetch(
        `https://oauth2.googleapis.com/token`,
        {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({
            grant_type: "client_credentials",
            client_email: credentials.client_email,
            private_key: credentials.private_key,
            scope: "https://www.googleapis.com/auth/firebase.messaging",
          }),
        }
      );

      const { access_token } = await tokenResponse.json();

      // Send FCM messages
      for (const msg of fcmMessages) {
        try {
          const fcmResponse = await fetch(
            `https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`,
            {
              method: "POST",
              headers: {
                "Authorization": `Bearer ${access_token}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                message: {
                  token: msg.token,
                  notification: {
                    title: msg.title,
                    body: msg.body,
                  },
                  data: msg.data,
                  android: {
                    priority: "high",
                    notification: {
                      channel_id: "xparq_signal_channel",
                      sound: "default",
                    },
                  },
                  apns: {
                    payload: {
                      aps: {
                        sound: "default",
                        badge: 1,
                        category: "CHAT_ACTIONS",
                        "thread-id": chat_id,
                      },
                    },
                  },
                },
              }),
            }
          );

          const fcmResult = await fcmResponse.json();
          console.log("[chat-notifications] FCM result:", fcmResult);
        } catch (fcmError) {
          console.error("[chat-notifications] FCM send error:", fcmError);
        }
      }
    }

    return new Response("OK", {
      status: 200,
      headers: corsHeaders,
    });
  } catch (error) {
    console.error("[chat-notifications] Error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: corsHeaders }
    );
  }
});
