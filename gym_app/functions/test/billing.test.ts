import {
  billingInterval,
  calculateBillingPeriod,
  isBillingType,
} from '../src/billing';

describe('billing', () => {
  test('accepts the three supported billing types', () => {
    expect(isBillingType('mensal')).toBe(true);
    expect(isBillingType('trimestral')).toBe(true);
    expect(isBillingType('anual')).toBe(true);
    expect(isBillingType('weekly')).toBe(false);
  });

  test('maps billing types to Stripe recurring intervals', () => {
    expect(billingInterval('mensal')).toEqual({ interval: 'month', interval_count: 1 });
    expect(billingInterval('trimestral')).toEqual({ interval: 'month', interval_count: 3 });
    expect(billingInterval('anual')).toEqual({ interval: 'year', interval_count: 1 });
  });

  test('sets a new student activation on the same calendar day next month', () => {
    const start = new Date('2026-08-15T10:30:00.000Z');
    const period = calculateBillingPeriod(start, 'mensal');

    expect(period.start).toEqual(start);
    expect(period.end).toEqual(new Date('2026-09-15T10:29:59.999Z'));
  });


  test('handles month ends when calculating a quarterly period', () => {
    const start = new Date('2026-01-31T00:00:00.000Z');
    const period = calculateBillingPeriod(start, 'trimestral');

    expect(period.end).toEqual(new Date('2026-04-29T23:59:59.999Z'));
  });
});
