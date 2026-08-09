"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.shouldDeactivateExpiredContract = shouldDeactivateExpiredContract;
function asDate(value) {
    if (value instanceof Date)
        return value;
    if (typeof value === 'object' &&
        value !== null &&
        'toDate' in value &&
        typeof value.toDate === 'function') {
        const date = value.toDate();
        return date instanceof Date ? date : null;
    }
    if (typeof value === 'string') {
        const date = new Date(value);
        return Number.isNaN(date.getTime()) ? null : date;
    }
    return null;
}
/**
 * Returns whether a Firestore user profile should be deactivated now.
 * Administrators and already inactive profiles are intentionally excluded.
 */
function shouldDeactivateExpiredContract(data, now) {
    if (data.role === 'admin' || data.isActive === false)
        return false;
    const contractEndsAt = asDate(data.contractEndsAt);
    return contractEndsAt !== null && contractEndsAt.getTime() <= now.getTime();
}
//# sourceMappingURL=contract_expiry.js.map