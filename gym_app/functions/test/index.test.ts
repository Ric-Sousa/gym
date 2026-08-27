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

// O cliente atual usa a callable createStudent para o SDK anexar a sessão
// Firebase. A rota HTTP mantém compatibilidade com versões anteriores.
const index = require('../lib/index');
const createStudent = testEnv.wrap(index.createStudent);
const submitQuestionnaire = testEnv.wrap(index.submitQuestionnaire);
const seedFoods = testEnv.wrap(index.seedFoods);

describe('function exports', () => {
  test('exports callable and legacy HTTP student creation functions', () => {
    expect(typeof index.createStudent).toBe('function');
    expect(typeof index.createStudentHttp).toBe('function');
    expect(typeof index.deleteStudentHttp).toBe('function');
    expect(typeof index.aggregateDiaryStats).toBe('function');
    expect(typeof index.submitQuestionnaire).toBe('function');
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

describe('createStudent', () => {
  test('rejects unauthenticated calls', async () => {
    await expect(createStudent({
      nome: 'Aluno Teste',
      email: 'aluno@example.com',
      tipoCliente: 'online',
    })).rejects.toMatchObject({
      code: 'unauthenticated',
      message: 'Login necessário.',
    });
  });
});

describe('submitQuestionnaire', () => {
  test('rejects unauthenticated calls', async () => {
    await expect(submitQuestionnaire({
      version: 'questionnaire-2026-08-health-v2',
      answers: { nome: 'Aluno Teste' },
    })).rejects.toMatchObject({
      code: 'unauthenticated',
      message: 'Login necessÃ¡rio.',
    });
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
