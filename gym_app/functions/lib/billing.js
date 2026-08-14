"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.billingTypeLabels = void 0;
exports.isBillingType = isBillingType;
exports.billingInterval = billingInterval;
exports.calculateBillingPeriod = calculateBillingPeriod;
exports.billingTypeLabels = {
    mensal: 'Mensal',
    trimestral: 'Trimestral',
    anual: 'Anual',
};
function isBillingType(value) {
    return value === 'mensal' || value === 'trimestral' || value === 'anual';
}
function billingInterval(type) {
    switch (type) {
        case 'mensal':
            return { interval: 'month', interval_count: 1 };
        case 'trimestral':
            return { interval: 'month', interval_count: 3 };
        case 'anual':
            return { interval: 'year', interval_count: 1 };
    }
}
/**
 * Calculates a period using calendar months/years and an exclusive end date.
 * The returned end is one millisecond before the next billing boundary so the
 * access period remains continuous when another period starts afterwards.
 */
function calculateBillingPeriod(start, type) {
    const months = type === 'mensal' ? 1 : type === 'trimestral' ? 3 : 12;
    const year = start.getUTCFullYear();
    const month = start.getUTCMonth();
    const day = start.getUTCDate();
    const targetMonthStart = Date.UTC(year, month + months, 1);
    const targetYear = new Date(targetMonthStart).getUTCFullYear();
    const targetMonth = new Date(targetMonthStart).getUTCMonth();
    const daysInTargetMonth = new Date(Date.UTC(targetYear, targetMonth + 1, 0)).getUTCDate();
    const targetDay = Math.min(day, daysInTargetMonth);
    const exclusiveEnd = new Date(Date.UTC(targetYear, targetMonth, targetDay, start.getUTCHours(), start.getUTCMinutes(), start.getUTCSeconds(), start.getUTCMilliseconds()));
    return {
        start,
        end: new Date(exclusiveEnd.getTime() - 1),
    };
}
//# sourceMappingURL=billing.js.map