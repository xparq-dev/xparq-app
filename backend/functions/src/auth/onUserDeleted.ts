// functions/src/auth/onUserDeleted.ts
//
// Cloud Function trigger: Runs when a user is deleted from Firebase Auth.
// Cleans up associated Firestore data to prevent "ghost" profiles/pulses.

import * as functions from "firebase-functions";
import { getFirestore } from "../firebaseAdmin";

export const onUserDeleted = functions.auth.user().onDelete(async (user) => {
    const uid = user.uid;
    console.log(`Cleaning up data for deleted user: ${uid}`);
    const db = getFirestore();
    if (!db) {
        console.error("Firebase Admin Firestore is unavailable.");
        return;
    }

    const batch = db.batch();

    // 1. Delete user profile
    const userRef = db.collection("users").doc(uid);
    batch.delete(userRef);

    // 2. Delete user's pulses
    // Querying up to 500 pulses for deletion in a single batch
    const pulsesSnap = await db
        .collection("pulses")
        .where("uid", "==", uid)
        .limit(500)
        .get();

    pulsesSnap.forEach((doc) => {
        batch.delete(doc.ref);
    });

    try {
        await batch.commit();
        console.log(`Successfully cleaned up ${pulsesSnap.size} pulses and profile for ${uid}`);
    } catch (error) {
        console.error(`Error cleaning up data for user ${uid}:`, error);
    }
});




