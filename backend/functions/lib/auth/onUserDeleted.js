"use strict";
// functions/src/auth/onUserDeleted.ts
//
// Cloud Function trigger: Runs when a user is deleted from Firebase Auth.
// Cleans up associated Firestore data to prevent "ghost" profiles/pulses.
Object.defineProperty(exports, "__esModule", { value: true });
exports.onUserDeleted = void 0;
const functions = require("firebase-functions");
const firebaseAdmin_1 = require("../firebaseAdmin");
exports.onUserDeleted = functions.auth.user().onDelete(async (user) => {
    const uid = user.uid;
    console.log(`Cleaning up data for deleted user: ${uid}`);
    const db = (0, firebaseAdmin_1.getFirestore)();
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
    }
    catch (error) {
        console.error(`Error cleaning up data for user ${uid}:`, error);
    }
});
//# sourceMappingURL=onUserDeleted.js.map