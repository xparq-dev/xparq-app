import { createHash } from "node:crypto";
import {
    existsSync,
    readFileSync,
    realpathSync,
} from "node:fs";
import { basename } from "node:path";

import * as admin from "firebase-admin";

type ServiceAccountShape = {
    project_id: string;
    client_email: string;
    private_key: string;
} & admin.ServiceAccount;

type SecretDescriptor = {
    slot: "primary" | "secondary";
    source: "env" | "file";
    encoded: string;
    fingerprint: string;
    version: string;
    filePath?: string;
    serviceAccount: ServiceAccountShape;
};

type ActiveCredentialState = {
    descriptor: SecretDescriptor;
    app: admin.app.App;
    loadedAt: string;
};

const DEFAULT_GRACE_MS = Number.parseInt(
    process.env.FIREBASE_ADMIN_RELOAD_GRACE_MS || "300000",
    10
);
const HEALTH_CHECK_UID =
    process.env.FIREBASE_ADMIN_HEALTHCHECK_UID || "firebase-admin-healthcheck";

let missingConfigLogged = false;
let signalHandlersInstalled = false;
let activeState: ActiveCredentialState | null = null;
let secondaryDescriptor: SecretDescriptor | null = null;
let standbyCleanupTimer: NodeJS.Timeout | null = null;
let reloadInProgress = false;

function resolveEnv(names: string[]): string | null {
    for (const name of names) {
        const value = process.env[name];
        if (value && value.trim()) {
            return value.trim();
        }
    }

    return null;
}

function normalizeVersion(rawVersion: string | null, fallback: string): string {
    if (!rawVersion || !rawVersion.trim()) {
        return fallback;
    }

    return rawVersion.trim();
}

function fingerprintSecret(encoded: string): string {
    return createHash("sha256").update(encoded).digest("hex").slice(0, 16);
}

function parseServiceAccount(encoded: string): ServiceAccountShape {
    const json = Buffer.from(encoded, "base64").toString("utf8");
    const parsed = JSON.parse(json) as Partial<ServiceAccountShape>;

    if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
        throw new Error("Service account JSON is missing required fields.");
    }

    return {
        project_id: parsed.project_id,
        client_email: parsed.client_email,
        private_key: parsed.private_key,
    };
}

function readBase64FromFile(filePath: string): {
    encoded: string;
    version: string;
    resolvedPath: string;
} {
    const resolvedPath = realpathSync(filePath);
    const encoded = readFileSync(resolvedPath, "utf8").trim();
    if (!encoded) {
        throw new Error(`Secret file ${resolvedPath} is empty.`);
    }

    return {
        encoded,
        version: basename(resolvedPath),
        resolvedPath,
    };
}

function loadDescriptor(slot: "primary" | "secondary"): SecretDescriptor | null {
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
            console.warn(
                "[FirebaseAdmin] No primary Firebase Admin credential source is configured. " +
                "Expected one of FIREBASE_ADMIN_KEY_FILE, FIREBASE_ADMIN_SDK_BASE64, or FIREBASE_KEY_BASE64."
            );
            missingConfigLogged = true;
        }
        return null;
    }

    if (!existsSync(filePath)) {
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

function createNamedApp(descriptor: SecretDescriptor): admin.app.App {
    const appName = `firebase-admin:${descriptor.version}:${Date.now()}`;
    return admin.initializeApp({
        credential: admin.credential.cert(descriptor.serviceAccount),
        projectId: descriptor.serviceAccount.project_id,
    }, appName);
}

function scheduleStandbyCleanup(app: admin.app.App | null) {
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

async function verifyApp(app: admin.app.App): Promise<void> {
    await admin.auth(app).createCustomToken(HEALTH_CHECK_UID);
}

export async function reloadFirebaseAdminCredentials(
    reason = "manual"
): Promise<{
    reloaded: boolean;
    activeVersion: string | null;
    activeFingerprint: string | null;
    fallbackUsed: boolean;
}> {
    if (reloadInProgress) {
        return {
            reloaded: false,
            activeVersion: activeState?.descriptor.version || null,
            activeFingerprint: activeState?.descriptor.fingerprint || null,
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
                activeVersion: activeState?.descriptor.version || null,
                activeFingerprint: activeState?.descriptor.fingerprint || null,
                fallbackUsed: false,
            };
        }

        if (activeState?.descriptor.fingerprint === primary.fingerprint) {
            console.info(
                `[FirebaseAdmin] Reload skipped; credential unchanged (${primary.version}) via ${reason}.`
            );
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
        } catch (primaryError) {
            await nextApp.delete().catch(() => undefined);
            if (!secondary) {
                throw primaryError;
            }

            console.warn(
                `[FirebaseAdmin] Primary credential ${primary.version} failed verification; falling back to ${secondary.version}.`
            );
            nextDescriptor = secondary;
            nextApp = createNamedApp(secondary);
            await verifyApp(nextApp);
            fallbackUsed = true;
        }

        const previousApp = activeState?.app || null;
        activeState = {
            descriptor: nextDescriptor,
            app: nextApp,
            loadedAt: new Date().toISOString(),
        };

        scheduleStandbyCleanup(previousApp);
        console.info(
            `[FirebaseAdmin] Active credential is now ${nextDescriptor.version} ` +
            `(${nextDescriptor.fingerprint}) via ${reason}.`
        );

        return {
            reloaded: true,
            activeVersion: nextDescriptor.version,
            activeFingerprint: nextDescriptor.fingerprint,
            fallbackUsed,
        };
    } finally {
        reloadInProgress = false;
    }
}

function ensureInitialized(): admin.app.App | null {
    if (activeState?.app) {
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
        console.info(
            `[FirebaseAdmin] Initialized active credential ${primary.version} (${primary.fingerprint}).`
        );
        return app;
    } catch (error) {
        console.error("[FirebaseAdmin] Initialization failed:", error);
        return null;
    }
}

export function getFirebaseAdminApp(): admin.app.App | null {
    return ensureInitialized();
}

export function getFirestore(): admin.firestore.Firestore | null {
    const app = ensureInitialized();
    return app ? admin.firestore(app) : null;
}

export function getMessaging(): admin.messaging.Messaging | null {
    const app = ensureInitialized();
    return app ? admin.messaging(app) : null;
}

export function getAuth(): admin.auth.Auth | null {
    const app = ensureInitialized();
    return app ? admin.auth(app) : null;
}

export async function verifyFirebaseAdminHealth(): Promise<{
    ok: boolean;
    version: string | null;
    fingerprint: string | null;
    projectId: string | null;
    checkedAt: string;
    error?: string;
}> {
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
    } catch (error) {
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

export function getFirebaseAdminStatus(): {
    active: {
        version: string | null;
        fingerprint: string | null;
        source: string | null;
        loadedAt: string | null;
    };
    secondary: {
        version: string | null;
        fingerprint: string | null;
        source: string | null;
    };
    reloadInProgress: boolean;
} {
    return {
        active: {
            version: activeState?.descriptor.version || null,
            fingerprint: activeState?.descriptor.fingerprint || null,
            source: activeState?.descriptor.source || null,
            loadedAt: activeState?.loadedAt || null,
        },
        secondary: {
            version: secondaryDescriptor?.version || null,
            fingerprint: secondaryDescriptor?.fingerprint || null,
            source: secondaryDescriptor?.source || null,
        },
        reloadInProgress,
    };
}

export function installFirebaseAdminSignalHandlers(): void {
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

export { admin };
