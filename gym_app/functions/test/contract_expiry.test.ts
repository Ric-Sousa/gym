import { shouldDeactivateExpiredContract } from '../src/contract_expiry';

describe('contract expiry', () => {
  test('deactivates an active student at the monthly end date', () => {
    const now = new Date('2026-09-15T10:30:00.000Z');

    expect(
      shouldDeactivateExpiredContract(
        {
          role: 'aluno',
          isActive: true,
          contractEndsAt: new Date('2026-09-15T10:29:59.999Z'),
        },
        now,
      ),
    ).toBe(true);
  });

  test('does not deactivate an active student before the end date', () => {
    expect(
      shouldDeactivateExpiredContract(
        {
          role: 'aluno',
          isActive: true,
          contractEndsAt: new Date('2026-09-15T10:30:00.000Z'),
        },
        new Date('2026-09-15T10:29:59.999Z'),
      ),
    ).toBe(false);
  });
});
