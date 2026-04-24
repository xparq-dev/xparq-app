import { setTimeout as sleep } from "node:timers/promises";

const DEFAULT_REFRESH_MS = Number.parseInt(
  process.env.VAULT_FIREBASE_REFRESH_MS || "300000",
  10,
);

export class FirebaseVaultSecretClient {
  constructor({
    vaultAddr = process.env.VAULT_ADDR,
    roleId = process.env.VAULT_ROLE_ID,
    secretId = process.env.VAULT_SECRET_ID,
    secretPath = process.env.VAULT_FIREBASE_SECRET_PATH || "secret/data/firebase/admin",
    refreshMs = DEFAULT_REFRESH_MS,
    fetchImpl = globalThis.fetch,
  } = {}) {
    this.vaultAddr = vaultAddr;
    this.roleId = roleId;
    this.secretId = secretId;
    this.secretPath = secretPath;
    this.refreshMs = refreshMs;
    this.fetchImpl = fetchImpl;
    this.clientToken = null;
    this.lastKnownGood = null;
    this.refreshTimer = null;
    this.stopped = false;
  }

  async authenticate() {
    const response = await this.fetchImpl(
      `${this.vaultAddr}/v1/auth/approle/login`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          role_id: this.roleId,
          secret_id: this.secretId,
        }),
      },
    );

    if (!response.ok) {
      throw new Error(`Vault AppRole login failed (${response.status})`);
    }

    const payload = await response.json();
    this.clientToken = payload?.auth?.client_token || null;
    return this.clientToken;
  }

  async readFirebaseSecret() {
    if (!this.clientToken) {
      await this.authenticate();
    }

    const response = await this.fetchImpl(`${this.vaultAddr}/v1/${this.secretPath}`, {
      method: "GET",
      headers: {
        "X-Vault-Token": this.clientToken,
      },
    });

    if (response.status === 403 || response.status === 401) {
      this.clientToken = null;
      await this.authenticate();
      return this.readFirebaseSecret();
    }

    if (!response.ok) {
      throw new Error(`Vault secret read failed (${response.status})`);
    }

    const payload = await response.json();
    const encoded = payload?.data?.data?.firebase_admin_base64;
    if (!encoded) {
      throw new Error("Vault secret firebase_admin_base64 is missing.");
    }

    this.lastKnownGood = {
      encoded,
      version: payload?.data?.metadata?.version || null,
      fetchedAt: new Date().toISOString(),
    };
    return this.lastKnownGood;
  }

  async start(onRefresh) {
    this.stopped = false;

    const loop = async () => {
      while (!this.stopped) {
        try {
          const secret = await this.readFirebaseSecret();
          await onRefresh(secret);
        } catch (error) {
          console.error("[VaultFirebase] Refresh failed:", error.message);
          if (this.lastKnownGood) {
            await onRefresh(this.lastKnownGood, { fallback: true });
          }
        }

        await sleep(this.refreshMs);
      }
    };

    this.refreshTimer = loop();
    return this.refreshTimer;
  }

  stop() {
    this.stopped = true;
    return this.refreshTimer;
  }
}
