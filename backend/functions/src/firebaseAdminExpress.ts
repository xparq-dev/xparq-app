import {
    getFirebaseAdminStatus,
    installFirebaseAdminSignalHandlers,
    reloadFirebaseAdminCredentials,
    verifyFirebaseAdminHealth,
} from "./firebaseAdmin";

type ExpressLikeApp = {
    get: (
        path: string,
        handler: (
            req: unknown,
            res: {
                status: (code: number) => { json: (body: unknown) => void };
                json: (body: unknown) => void;
            }
        ) => void | Promise<void>
    ) => void;
};

export function registerFirebaseAdminHealthRoute(
    app: ExpressLikeApp,
    path = "/health/firebase"
): void {
    app.get(path, async (_req, res) => {
        const health = await verifyFirebaseAdminHealth();
        const status = getFirebaseAdminStatus();
        const response = {
            ...health,
            status,
        };

        if (!health.ok) {
            res.status(503).json(response);
            return;
        }

        res.json(response);
    });
}

export function registerFirebaseAdminReloadRoute(
    app: ExpressLikeApp,
    path = "/internal/firebase/reload"
): void {
    app.get(path, async (_req, res) => {
        const result = await reloadFirebaseAdminCredentials("http-reload");
        const health = await verifyFirebaseAdminHealth();
        res.status(health.ok ? 200 : 503).json({
            ...result,
            health,
        });
    });
}

export function installFirebaseAdminRuntimeHooks(): void {
    installFirebaseAdminSignalHandlers();
}
