"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.registerFirebaseAdminHealthRoute = registerFirebaseAdminHealthRoute;
exports.registerFirebaseAdminReloadRoute = registerFirebaseAdminReloadRoute;
exports.installFirebaseAdminRuntimeHooks = installFirebaseAdminRuntimeHooks;
const firebaseAdmin_1 = require("./firebaseAdmin");
function registerFirebaseAdminHealthRoute(app, path = "/health/firebase") {
    app.get(path, async (_req, res) => {
        const health = await (0, firebaseAdmin_1.verifyFirebaseAdminHealth)();
        const status = (0, firebaseAdmin_1.getFirebaseAdminStatus)();
        const response = Object.assign(Object.assign({}, health), { status });
        if (!health.ok) {
            res.status(503).json(response);
            return;
        }
        res.json(response);
    });
}
function registerFirebaseAdminReloadRoute(app, path = "/internal/firebase/reload") {
    app.get(path, async (_req, res) => {
        const result = await (0, firebaseAdmin_1.reloadFirebaseAdminCredentials)("http-reload");
        const health = await (0, firebaseAdmin_1.verifyFirebaseAdminHealth)();
        res.status(health.ok ? 200 : 503).json(Object.assign(Object.assign({}, result), { health }));
    });
}
function installFirebaseAdminRuntimeHooks() {
    (0, firebaseAdmin_1.installFirebaseAdminSignalHandlers)();
}
//# sourceMappingURL=firebaseAdminExpress.js.map