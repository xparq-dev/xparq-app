import * as functions from "firebase-functions";
import { createClient } from "@supabase/supabase-js";
import { admin, getMessaging } from "../firebaseAdmin";

// Configuration for Supabase (URL is public, Key should be a secret)
const SUPABASE_URL = "https://fidmehpoyvwdawcldvie.supabase.co";
// NOTE: For security, the Service Role Key should be stored in Firebase Secrets.
// Use: firebase functions:secrets:set SUPABASE_SERVICE_ROLE_KEY
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || "";

/**
 * Cloud Function: onMessageCreated
 * Triggered by a Supabase Webhook (POST request) when a new row is inserted into 'messages'.
 */
export const onMessageCreated = functions.https.onRequest(async (req, res) => {
    // 1. Method verification
    if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
    }

    // 2. Parse payload from Supabase Webhook
    // Payload format: { type: 'INSERT', table: 'messages', record: { ... }, ... }
    const payload = req.body;
    const record = payload.record;

    if (!record || payload.type !== "INSERT") {
        console.log("No new record to process.");
        res.status(200).send("No action needed");
        return;
    }

    const { chat_id, sender_id, message_type } = record;

    if (!SUPABASE_KEY) {
        console.error("SUPABASE_SERVICE_ROLE_KEY is missing.");
        res.status(500).send("Configuration Error");
        return;
    }

    try {
        const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);
        const messaging = getMessaging();
        if (!messaging) {
            console.error("Firebase Admin messaging is unavailable.");
            res.status(503).send("Firebase Admin is not configured");
            return;
        }

        // 3. Resolve chat participants
        const { data: chat, error: chatError } = await supabase
            .from("chats")
            .select("participants, name, is_group")
            .eq("id", chat_id)
            .single();

        if (chatError || !chat) {
            console.error("Error fetching chat:", chatError);
            res.status(500).send("Error fetching chat data");
            return;
        }

        const participants: string[] = chat.participants || [];
        const receiverUids = participants.filter(uid => uid !== sender_id);

        if (receiverUids.length === 0) {
            console.log("No receivers found for this message.");
            res.status(200).send("No receivers");
            return;
        }

        // 4. Fetch sender's name for notification title
        const { data: sender, error: senderError } = await supabase
            .from("profiles")
            .select("xparq_name")
            .eq("id", sender_id)
            .maybeSingle();

        if (senderError) {
            console.error(`Error fetching sender ${sender_id}:`, senderError);
        }
        const senderDisplayName = sender?.xparq_name || "An iXPARQ";

        // 5. Fetch FCM tokens for all receivers
        const { data: receivers, error: receiverError } = await supabase
            .from("profiles")
            .select("id, fcm_token")
            .in("id", receiverUids);

        if (receiverError || !receivers) {
            console.error("Error fetching receiver tokens:", receiverError);
            res.status(500).send("Error fetching receiver tokens");
            return;
        }

        // 6. Bulk send FCM notifications
        const notifications: admin.messaging.Message[] = [];
        const notificationTitle = chat.is_group ? chat.name : senderDisplayName;
        
        let bodySuffix = "New Signal received 📡";
        if (message_type === "image") bodySuffix = "Sent an image 🖼️";
        if (message_type === "video") bodySuffix = "Sent a video 📹";

        const notificationBody = chat.is_group 
            ? `${senderDisplayName}: ${bodySuffix}` 
            : bodySuffix;

        for (const r of receivers) {
            if (r.fcm_token) {
                notifications.push({
                    token: r.fcm_token,
                    notification: {
                        title: notificationTitle,
                        body: notificationBody,
                    },
                    data: {
                        chat_id: chat_id,
                        sender_uid: sender_id,
                        other_uid: chat.is_group ? "group" : sender_id,
                        type: "signal_message",
                        click_action: "FLUTTER_NOTIFICATION_CLICK",
                    },
                    android: {
                        priority: "high",
                        notification: {
                            channelId: "xparq_signal_channel",
                            // icon: "ic_stat_name", // Optional: specify a custom status icon
                        },
                    },
                    apns: {
                        payload: {
                            aps: {
                                sound: "default",
                                badge: 1,
                            },
                        },
                    },
                });
            }
        }

        if (notifications.length > 0) {
            const response = await messaging.sendEach(notifications);
            console.log(`Successfully sent ${response.successCount} notifications.`);
        } else {
            console.log("No valid tokens found to send notifications.");
        }

        res.status(200).send("Notifications processed successfully.");
    } catch (e) {
        console.error("Critical error in onMessageCreated:", e);
        res.status(500).send("Internal Server Error");
    }
});




