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

// createStudent foi substituída pela rota HTTP createStudentHttp. O teste
// callable antigo não podia validar uma função onRequest e falhava por usar
// uma exportação inexistente.
// eslint-disable-next-line @typescript-eslint/no-require-imports
const index = require('../lib/index');
// eslint-disable-next-line @typescript-eslint/no-require-imports
const seedFoods = testEnv.wrap(index.seedFoods);

describe('function exports', () => {
  test('exports the current HTTP student creation function', () => {
    expect(typeof index.createStudentHttp).toBe('function');
    expect(typeof index.deleteStudentHttp).toBe('function');
  });
});

describe('seedFoods', () => {
  test('rejects unauthenticated calls (no auth context)', async () => {
    try {
      await seedFoods({ alimentos: [] });
      throw new Error('Should have thrown');
    } catch (e: any) {
      expect(e.code).toBe('unauthenticated');
      expect(e.message).toBe('Login necessário.');
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
