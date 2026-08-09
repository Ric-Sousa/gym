type TimestampLike = {
  toDate: () => Date;
};

function asDate(value: unknown): Date | null {
  if (value instanceof Date) return value;
  if (
    typeof value === 'object' &&
    value !== null &&
    'toDate' in value &&
    typeof (value as TimestampLike).toDate === 'function'
  ) {
    const date = (value as TimestampLike).toDate();
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
export function shouldDeactivateExpiredContract(
  data: Record<string, unknown>,
  now: Date,
): boolean {
  if (data.role === 'admin' || data.isActive === false) return false;

  const contractEndsAt = asDate(data.contractEndsAt);
  return contractEndsAt !== null && contractEndsAt.getTime() <= now.getTime();
}
