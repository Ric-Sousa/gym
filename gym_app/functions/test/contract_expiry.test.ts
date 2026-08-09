import { shouldDeactivateExpiredContract } from '../src/contract_expiry';

describe('shouldDeactivateExpiredContract', () => {
  const now = new Date('2026-08-09T12:00:00.000Z');

  test('deactivates an active student whose contract has ended', () => {
    expect(
      shouldDeactivateExpiredContract(
        {
          role: 'aluno',
          isActive: true,
          contractEndsAt: new Date('2026-08-09T11:59:59.000Z'),
        },
        now,
      ),
    ).toBe(true);
  });

  test('keeps a future contract active', () => {
    expect(
      shouldDeactivateExpiredContract(
        {
          role: 'aluno',
          isActive: true,
          contractEndsAt: new Date('2026-08-09T12:00:01.000Z'),
        },
        now,
      ),
    ).toBe(false);
  });

  test('does not deactivate administrators', () => {
    expect(
      shouldDeactivateExpiredContract(
        {
          role: 'admin',
          isActive: true,
          contractEndsAt: new Date('2020-01-01T00:00:00.000Z'),
        },
        now,
      ),
    ).toBe(false);
  });

  test('does not rewrite profiles already inactive', () => {
    expect(
      shouldDeactivateExpiredContract(
        {
          role: 'aluno',
          isActive: false,
          contractEndsAt: new Date('2020-01-01T00:00:00.000Z'),
        },
        now,
      ),
    ).toBe(false);
  });

  test('supports Firestore-like timestamps', () => {
    expect(
      shouldDeactivateExpiredContract(
        {
          role: 'aluno',
          isActive: true,
          contractEndsAt: {
            toDate: () => new Date('2026-08-09T12:00:00.000Z'),
          },
        },
        now,
      ),
    ).toBe(true);
  });
});
