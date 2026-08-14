export type BillingType = 'mensal' | 'trimestral' | 'anual';

export const billingTypeLabels: Record<BillingType, string> = {
  mensal: 'Mensal',
  trimestral: 'Trimestral',
  anual: 'Anual',
};

export function isBillingType(value: unknown): value is BillingType {
  return value === 'mensal' || value === 'trimestral' || value === 'anual';
}

export function billingInterval(type: BillingType): {
  interval: 'month' | 'year';
  interval_count: number;
} {
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
export function calculateBillingPeriod(
  start: Date,
  type: BillingType,
): { start: Date; end: Date } {
  const months = type === 'mensal' ? 1 : type === 'trimestral' ? 3 : 12;
  const year = start.getUTCFullYear();
  const month = start.getUTCMonth();
  const day = start.getUTCDate();
  const targetMonthStart = Date.UTC(year, month + months, 1);
  const targetYear = new Date(targetMonthStart).getUTCFullYear();
  const targetMonth = new Date(targetMonthStart).getUTCMonth();
  const daysInTargetMonth = new Date(
    Date.UTC(targetYear, targetMonth + 1, 0),
  ).getUTCDate();
  const targetDay = Math.min(day, daysInTargetMonth);
  const exclusiveEnd = new Date(
    Date.UTC(
      targetYear,
      targetMonth,
      targetDay,
      start.getUTCHours(),
      start.getUTCMinutes(),
      start.getUTCSeconds(),
      start.getUTCMilliseconds(),
    ),
  );

  return {
    start,
    end: new Date(exclusiveEnd.getTime() - 1),
  };
}
