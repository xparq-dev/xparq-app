"use strict";
// functions/src/index.ts
// Entry point for all Cloud Functions
Object.defineProperty(exports, "__esModule", { value: true });
exports.onMessageCreated = exports.onUserDeleted = exports.queryNearby = void 0;
var queryNearby_1 = require("./radar/queryNearby");
Object.defineProperty(exports, "queryNearby", { enumerable: true, get: function () { return queryNearby_1.queryNearby; } });
var onUserDeleted_1 = require("./auth/onUserDeleted");
Object.defineProperty(exports, "onUserDeleted", { enumerable: true, get: function () { return onUserDeleted_1.onUserDeleted; } });
var onMessageCreated_1 = require("./chat/onMessageCreated");
Object.defineProperty(exports, "onMessageCreated", { enumerable: true, get: function () { return onMessageCreated_1.onMessageCreated; } });
//# sourceMappingURL=index.js.map