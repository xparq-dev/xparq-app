"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.admin = void 0;
exports.reloadFirebaseAdminCredentials = reloadFirebaseAdminCredentials;
exports.getFirebaseAdminApp = getFirebaseAdminApp;
exports.getFirestore = getFirestore;
exports.getMessaging = getMessaging;
exports.getAuth = getAuth;
exports.verifyFirebaseAdminHealth = verifyFirebaseAdminHealth;
exports.getFirebaseAdminStatus = getFirebaseAdminStatus;
exports.installFirebaseAdminSignalHandlers = installFirebaseAdminSignalHandlers;
const node_crypto_1 = require("node:crypto");
const node_fs_1 = require("node:fs");
const node_path_1 = require("node:path");
const admin = require("firebase-admin");
exports.admin = admin;
const DEFAULT_GRACE_MS = Number.parseInt(process.env.FIREBASE_ADMIN_RELOAD_GRACE_MS || "300000", 10);
const HEALTH_CHECK_UID = process.env.FIREBASE_ADMIN_HEALTHCHECK_UID || "firebase-admin-healthcheck";
let missingConfigLogged = false;
let signalHandlersInstalled = false;
let activeState = null;
let secondaryDescriptor = null;
let standbyCleanupTimer = null;
let reloadInProgress = false;
function resolveEnv(names) {
    for (const name of names) {
        const value = process.env[name];
        if (value && value.trim()) {
            return value.trim();
        }
    }
    return null;
}
function normalizeVersion(rawVersion, fallback) {
    if (!rawVersion || !rawVersion.trim()) {
        return fallback;
    }
    return rawVersion.trim();
}
function fingerprintSecret(encoded) {
    return (0, node_crypto_1.createHash)("sha256").update(encoded).digest("hex").slice(0, 16);
}
function parseServiceAccount(encoded) {
    const json = Buffer.from(encoded, "base64").toString("utf8");
    const parsed = JSON.parse(json);
    if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
        throw new Error("Service account JSON is missing required fields.");
    }
    return {
        project_id: parsed.project_id,
        client_email: parsed.client_email,
        private_key: parsed.private_key,
    };
}
function readBase64FromFile(filePath) {
    const resolvedPath = (0, node_fs_1.realpathSync)(filePath);
    const encoded = (0, node_fs_1.readFileSync)(resolvedPath, "utf8").trim();
    if (!encoded) {
        throw new Error(`Secret file ${resolvedPath} is empty.`);
    }
    return {
        encoded,
        version: (0, node_path_1.basename)(resolvedPath),
        resolvedPath,
    };
}
function loadDescriptor(slot) {
    const base64Names = slot === "primary"
        ? [
            "FIREBASE_ADMIN_PRIMARY_BASE64",
            "FIREBASE_ADMIN_SDK_BASE64",
            "FIREBASE_KEY_BASE64",
        ]
        : [
            "FIREBASE_ADMIN_SECONDARY_BASE64",
            "FIREBASE_KEY_SECONDARY_BASE64",
        ];
    const fileNames = slot === "primary"
        ? [
            "FIREBASE_ADMIN_PRIMARY_FILE",
            "FIREBASE_ADMIN_KEY_FILE",
            "FIREBASE_KEY_FILE",
        ]
        : [
            "FIREBASE_ADMIN_SECONDARY_FILE",
            "FIREBASE_ADMIN_SECONDARY_KEY_FILE",
            "FIREBASE_SECONDARY_KEY_FILE",
        ];
    const versionEnvNames = slot === "primary"
        ? ["FIREBASE_ADMIN_PRIMARY_VERSION", "FIREBASE_ADMIN_KEY_VERSION"]
        : ["FIREBASE_ADMIN_SECONDARY_VERSION"];
    const inlineBase64 = resolveEnv(base64Names);
    if (inlineBase64) {
        return {
            slot,
            source: "env",
            encoded: inlineBase64,
            fingerprint: fingerprintSecret(inlineBase64),
            version: normalizeVersion(resolveEnv(versionEnvNames), `${slot}-env`),
            serviceAccount: parseServiceAccount(inlineBase64),
        };
    }
    const filePath = resolveEnv(fileNames);
    if (!filePath) {
        if (slot === "primary" && !missingConfigLogged) {
            console.warn("[FirebaseAdmin] No primary Firebase Admin credential source is configured. " +
                "Expected one of FIREBASE_ADMIN_KEY_FILE, FIREBASE_ADMIN_SDK_BASE64, or FIREBASE_KEY_BASE64.");
            missingConfigLogged = true;
        }
        return null;
    }
    if (!(0, node_fs_1.existsSync)(filePath)) {
        throw new Error(`Configured secret file does not exist: ${filePath}`);
    }
    const { encoded, version, resolvedPath } = readBase64FromFile(filePath);
    return {
        slot,
        source: "file",
        encoded,
        fingerprint: fingerprintSecret(encoded),
        version: normalizeVersion(resolveEnv(versionEnvNames), version),
        filePath: resolvedPath,
        serviceAccount: parseServiceAccount(encoded),
    };
}
function createNamedApp(descriptor) {
    const appName = `firebase-admin:${descriptor.version}:${Date.now()}`;
    return admin.initializeApp({
        credential: admin.credential.cert(descriptor.serviceAccount),
        projectId: descriptor.serviceAccount.project_id,
    }, appName);
}
function scheduleStandbyCleanup(app) {
    if (!app) {
        return;
    }
    if (standbyCleanupTimer) {
        clearTimeout(standbyCleanupTimer);
    }
    standbyCleanupTimer = setTimeout(() => {
        app.delete().catch((error) => {
            console.warn("[FirebaseAdmin] Failed to delete standby app:", error);
        });
        standbyCleanupTimer = null;
    }, DEFAULT_GRACE_MS);
    if (typeof standbyCleanupTimer.unref === "function") {
        standbyCleanupTimer.unref();
    }
}
async function verifyApp(app) {
    await admin.auth(app).createCustomToken(HEALTH_CHECK_UID);
}
async function reloadFirebaseAdminCredentials(reason = "manual") {
    if (reloadInProgress) {
        return {
            reloaded: false,
            activeVersion: (activeState === null || activeState === void 0 ? void 0 : activeState.descriptor.version) || null,
            activeFingerprint: (activeState === null || activeState === void 0 ? void 0 : activeState.descriptor.fingerprint) || null,
            fallbackUsed: false,
        };
    }
    reloadInProgress = true;
    try {
        const primary = loadDescriptor("primary");
        const secondary = loadDescriptor("secondary");
        secondaryDescriptor = secondary;
        if (!primary) {
            return {
                reloaded: false,
                activeVersion: (activeState === null || activeState === void 0 ? void 0 : activeState.descriptor.version) || null,
                activeFingerprint: (activeState === null || activeState === void 0 ? void 0 : activeState.descriptor.fingerprint) || null,
                fallbackUsed: false,
            };
        }
        if ((activeState === null || activeState === void 0 ? void 0 : activeState.descriptor.fingerprint) === primary.fingerprint) {
            console.info(`[FirebaseAdmin] Reload skipped; credential unchanged (${primary.version}) via ${reason}.`);
            return {
                reloaded: false,
                activeVersion: activeState.descriptor.version,
                activeFingerprint: activeState.descriptor.fingerprint,
                fallbackUsed: false,
            };
        }
        let nextDescriptor = primary;
        let nextApp = createNamedApp(primary);
        let fallbackUsed = false;
        try {
            await verifyApp(nextApp);
        }
        catch (primaryError) {
            await nextApp.delete().catch(() => undefined);
            if (!secondary) {
                throw primaryError;
            }
            console.warn(`[FirebaseAdmin] Primary credential ${primary.version} failed verification; falling back to ${secondary.version}.`);
            nextDescriptor = secondary;
            nextApp = createNamedApp(secondary);
            await verifyApp(nextApp);
            fallbackUsed = true;
        }
        const previousApp = (activeState === null || activeState === void 0 ? void 0 : activeState.app) || null;
        activeState = {
            descriptor: nextDescriptor,
            app: nextApp,
            loadedAt: new Date().toISOString(),
        };
        scheduleStandbyCleanup(previousApp);
        console.info(`[FirebaseAdmin] Active credential is now ${nextDescriptor.version} ` +
            `(${nextDescriptor.fingerprint}) via ${reason}.`);
        return {
            reloaded: true,
            activeVersion: nextDescriptor.version,
            activeFingerprint: nextDescriptor.fingerprint,
            fallbackUsed,
        };
    }
    finally {
        reloadInProgress = false;
    }
}
function ensureInitialized() {
    if (activeState === null || activeState === void 0 ? void 0 : activeState.app) {
        return activeState.app;
    }
    const primary = loadDescriptor("primary");
    const secondary = loadDescriptor("secondary");
    secondaryDescriptor = secondary;
    if (!primary) {
        return null;
    }
    try {
        const app = createNamedApp(primary);
        activeState = {
            descriptor: primary,
            app,
            loadedAt: new Date().toISOString(),
        };
        console.info(`[FirebaseAdmin] Initialized active credential ${primary.version} (${primary.fingerprint}).`);
        return app;
    }
    catch (error) {
        console.error("[FirebaseAdmin] Initialization failed:", error);
        return null;
    }
}
function getFirebaseAdminApp() {
    return ensureInitialized();
}
function getFirestore() {
    const app = ensureInitialized();
    return app ? admin.firestore(app) : null;
}
function getMessaging() {
    const app = ensureInitialized();
    return app ? admin.messaging(app) : null;
}
function getAuth() {
    const app = ensureInitialized();
    return app ? admin.auth(app) : null;
}
async function verifyFirebaseAdminHealth() {
    const app = ensureInitialized();
    const checkedAt = new Date().toISOString();
    if (!app || !activeState) {
        return {
            ok: false,
            version: null,
            fingerprint: null,
            projectId: null,
            checkedAt,
            error: "Firebase Admin is not configured",
        };
    }
    try {
        await verifyApp(app);
        return {
            ok: true,
            version: activeState.descriptor.version,
            fingerprint: activeState.descriptor.fingerprint,
            projectId: activeState.descriptor.serviceAccount.project_id,
            checkedAt,
        };
    }
    catch (error) {
        return {
            ok: false,
            version: activeState.descriptor.version,
            fingerprint: activeState.descriptor.fingerprint,
            projectId: activeState.descriptor.serviceAccount.project_id,
            checkedAt,
            error: error instanceof Error ? error.message : String(error),
        };
    }
}
function getFirebaseAdminStatus() {
    return {
        active: {
            version: (activeState === null || activeState === void 0 ? void 0 : activeState.descriptor.version) || null,
            fingerprint: (activeState === null || activeState === void 0 ? void 0 : activeState.descriptor.fingerprint) || null,
            source: (activeState === null || activeState === void 0 ? void 0 : activeState.descriptor.source) || null,
            loadedAt: (activeState === null || activeState === void 0 ? void 0 : activeState.loadedAt) || null,
        },
        secondary: {
            version: (secondaryDescriptor === null || secondaryDescriptor === void 0 ? void 0 : secondaryDescriptor.version) || null,
            fingerprint: (secondaryDescriptor === null || secondaryDescriptor === void 0 ? void 0 : secondaryDescriptor.fingerprint) || null,
            source: (secondaryDescriptor === null || secondaryDescriptor === void 0 ? void 0 : secondaryDescriptor.source) || null,
        },
        reloadInProgress,
    };
}
function installFirebaseAdminSignalHandlers() {
    if (signalHandlersInstalled) {
        return;
    }
    process.on("SIGHUP", () => {
        void reloadFirebaseAdminCredentials("sighup").catch((error) => {
            console.error("[FirebaseAdmin] Reload on SIGHUP failed:", error);
        });
    });
    signalHandlersInstalled = true;
}
//# sourceMappingURL=firebaseAdmin.js.map