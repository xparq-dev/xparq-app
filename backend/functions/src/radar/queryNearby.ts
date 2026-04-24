// functions/src/radar/queryNearby.ts
//
// Cloud Function: queryNearby
// Receives lat/lng/radiusKm/callerAgeGroup from client.
// Queries Firestore for users within radius using geohash prefix matching.
// Applies age gating: Cadets cannot see profiles with nsfw_opt_in = true.
// Returns sorted list of nearby user profiles with distance.

import * as functions from "firebase-functions";
import { admin, getFirestore } from "../firebaseAdmin";

// ── Haversine Distance ────────────────────────────────────────────────────────

function distanceMeters(
    lat1: number, lng1: number,
    lat2: number, lng2: number
): number {
    const R = 6371000;
    const dLat = toRad(lat2 - lat1);
    const dLng = toRad(lng2 - lng1);
    const a =
        Math.sin(dLat / 2) ** 2 +
        Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function toRad(deg: number): number {
    return (deg * Math.PI) / 180;
}

// ── Geohash Prefix for Range Query ───────────────────────────────────────────

function geohashPrefix(lat: number, lng: number, precision: number): string {
    const BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz";
    let minLat = -90, maxLat = 90;
    let minLng = -180, maxLng = 180;
    let result = "";
    let bits = 0, hashValue = 0;
    let isEven = true;

    while (result.length < precision) {
        if (isEven) {
            const mid = (minLng + maxLng) / 2;
            if (lng >= mid) { hashValue = (hashValue << 1) + 1; minLng = mid; }
            else { hashValue = hashValue << 1; maxLng = mid; }
        } else {
            const mid = (minLat + maxLat) / 2;
            if (lat >= mid) { hashValue = (hashValue << 1) + 1; minLat = mid; }
            else { hashValue = hashValue << 1; maxLat = mid; }
        }
        isEven = !isEven;
        bits++;
        if (bits === 5) {
            result += BASE32[hashValue];
            bits = 0;
            hashValue = 0;
        }
    }
    return result;
}

// ── Cloud Function ────────────────────────────────────────────────────────────

export const queryNearby = functions.https.onCall(async (data, context) => {
    // Auth check
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Must be logged in.");
    }

    const db = getFirestore();
    if (!db) {
        throw new functions.https.HttpsError(
            "failed-precondition",
            "Firebase Admin is not configured on this server."
        );
    }

    const { lat, lng, radiusKm, callerAgeGroup } = data as {
        lat: number;
        lng: number;
        radiusKm: number;
        callerAgeGroup: "cadet" | "explorer";
    };

    if (!lat || !lng || !radiusKm) {
        throw new functions.https.HttpsError("invalid-argument", "lat, lng, radiusKm required.");
    }

    // Use precision 4 for ~40km cells (covers 5km–50km radius queries)
    const precision = radiusKm <= 50 ? 4 : 3;
    const prefix = geohashPrefix(lat, lng, precision);

    // Query users with matching geohash prefix
    const twoHoursAgo = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() - 2 * 60 * 60 * 1000)
    );

    const snapshot = await db
        .collection("users")
        .where("location_geohash", ">=", prefix)
        .where("location_geohash", "<", prefix + "z")
        .where("is_online", "==", true)
        .where("location_updated_at", ">=", twoHoursAgo)
        .where("ghost_mode", "==", false)
        .limit(100)
        .get();

    const results: object[] = [];

    for (const doc of snapshot.docs) {
        // Skip self
        if (doc.id === context.auth.uid) continue;

        const profile = doc.data();

        // ── Age Gating ──────────────────────────────────────────────────────────
        // Cadets cannot see profiles that have opted into NSFW content
        if (callerAgeGroup === "cadet" && profile.nsfw_opt_in === true) continue;

        // ── Distance Filter ─────────────────────────────────────────────────────
        const docLat: number = profile.location_lat ?? 0;
        const docLng: number = profile.location_lng ?? 0;
        const distance = distanceMeters(lat, lng, docLat, docLng);

        if (distance > radiusKm * 1000) continue;

        // ── Build Response (exclude sensitive fields) ───────────────────────────
        results.push({
            uid: doc.id,
            distanceMeters: Math.round(distance),
            is_online: profile.is_online ?? false,
            profile: {
                sparq_name: profile.sparq_name,
                bio: profile.bio,
                photo_url: profile.photo_url,
                age_group: profile.age_group,
                blue_orbit: profile.blue_orbit,
                constellations: profile.constellations ?? [],
                // NOTE: birth_date_encrypted is intentionally excluded
            },
        });
    }

    // Sort by distance
    results.sort((a: any, b: any) => a.distanceMeters - b.distanceMeters);

    return results;
});




