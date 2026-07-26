/**
 * Testes unitários para Cloud Functions.
 *
 * NOTA: Estes testes correm OFFLINE (sem Firebase Emulator).
 * O `firebase-functions-test` em modo offline não consegue injetar
 * corretamente o contexto `auth` nas funções callable.
 *
 * Testes que precisam de contexto auth (admin check, validação de dados)
 * devem ser executados com o Firebase Emulator:
 *   npm run serve    # inicia emuladores
 *   npm test         # corre com firebase emulator
 */

const functionsTest = require('firebase-functions-test') as (
  options?: any
) => any;

const testEnv = functionsTest({
  projectId: 'gymbt-4ef87',
  region: 'europe-west1',
});

// eslint-disable-next-line @typescript-eslint/no-require-imports
const createStudent = testEnv.wrap(require('../lib/index').createStudent);
// eslint-disable-next-line @typescript-eslint/no-require-imports
const seedFoods = testEnv.wrap(require('../lib/index').seedFoods);

describe('createStudent', () => {
  test('rejects unauthenticated calls (no auth context)', async () => {
    try {
      await createStudent({ nome: 'Test', email: 'test@test.com' });
      throw new Error('Should have thrown');
    } catch (e: any) {
      expect(e.code).toBe('unauthenticated');
      expect(e.message).toBe('Tens de iniciar sessão para criar alunos.');
    }
  });
});

describe('seedFoods', () => {
  test('rejects unauthenticated calls (no auth context)', async () => {
    try {
      await seedFoods({ alimentos: [] });
      throw new Error('Should have thrown');
    } catch (e: any) {
      expect(e.code).toBe('unauthenticated');
      expect(e.message).toBe('Tens de iniciar sessão.');
    }
  });
});

// Testes que precisam do Firebase Emulator (auth + Firestore):
// - createStudent: admin check, existing user, new user creation
// - seedFoods: admin check, duplicate foods, batch add
// Para correr estes testes, inicia os emuladores com `npm run serve`
// e configura a variável FIREBASE_FUNCTIONS_EMULATOR=true

afterAll(() => {
  testEnv.cleanup();
});
