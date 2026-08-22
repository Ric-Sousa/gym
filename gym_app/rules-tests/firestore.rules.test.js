const fs = require('node:fs');
const path = require('node:path');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  collection,
  doc,
  getDocs,
  getDoc,
  query,
  setDoc,
  where,
  updateDoc,
  writeBatch,
  Timestamp,
} = require('firebase/firestore');

const rules = fs.readFileSync(
  path.join(__dirname, '..', 'firestore.rules'),
  'utf8',
);

const PROJECT_ID = 'gymbt-rules-test';
const ADMIN_ID = 'admin-1';
const STUDENT_A = 'student-a';
const STUDENT_B = 'student-b';
const ROOM_A = 'chat_admin-1_student-a';
const GROUP_ID = 'group-1';

let testEnv;

function userData(uid, overrides = {}) {
  return {
    role: uid === ADMIN_ID ? 'admin' : 'aluno',
    isActive: true,
    nome: uid,
    ...(uid === STUDENT_A || uid === STUDENT_B
      ? { personalId: ADMIN_ID }
      : {}),
    ...overrides,
  };
}

function directMessage(senderId, overrides = {}) {
  return {
    remetenteId: senderId,
    texto: 'Mensagem de teste',
    timestamp: Timestamp.now(),
    lida: false,
    ...overrides,
  };
}

async function seedBaseData() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const batch = writeBatch(db);
  batch.set(doc(db, 'users', ADMIN_ID), userData(ADMIN_ID));
  batch.set(doc(db, 'users', STUDENT_A), userData(STUDENT_A));
  batch.set(doc(db, 'users', STUDENT_B), userData(STUDENT_B));
  batch.set(doc(db, 'chat', ROOM_A), {
    participantIds: [ADMIN_ID, STUDENT_A],
    lastMessage: 'Mensagem de teste',
    lastTimestamp: Timestamp.now(),
    lastSenderId: ADMIN_ID,
    lastMessageId: 'message-1',
    typing: '',
  });
  batch.set(doc(db, 'chat', ROOM_A, 'mensagens', 'message-1'), {
    ...directMessage(ADMIN_ID),
    lida: false,
  });
  batch.set(doc(db, 'grupos', GROUP_ID), {
    membros: [STUDENT_A],
    nome: 'Grupo de teste',
    criadoPor: ADMIN_ID,
    createdAt: Timestamp.now(),
  });
  batch.set(doc(db, 'agenda', 'booking-1'), {
    studentId: STUDENT_A,
    trainerId: ADMIN_ID,
    data: Timestamp.fromMillis(Date.now() + 60 * 60 * 1000),
    duracaoMinutos: 60,
    status: 'pending',
    tipo: 'presencial',
  });
    await batch.commit();
  });
}

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules },
  });
});

afterEach(async () => {
  if (testEnv) await testEnv.clearFirestore();
});

afterAll(async () => {
  if (testEnv) await testEnv.cleanup();
});

describe('Firestore Rules — isolamento de chat direto', () => {
  beforeEach(seedBaseData);

  test('um aluno só lê a própria sala', async () => {
    const studentA = testEnv.authenticatedContext(STUDENT_A).firestore();
    const studentB = testEnv.authenticatedContext(STUDENT_B).firestore();

    await assertSucceeds(getDoc(doc(studentA, 'chat', ROOM_A)));
    await assertSucceeds(
      getDoc(doc(studentA, 'chat', ROOM_A, 'mensagens', 'message-1')),
    );
    await assertFails(getDoc(doc(studentB, 'chat', ROOM_A)));
    await assertFails(
      getDoc(doc(studentB, 'chat', ROOM_A, 'mensagens', 'message-1')),
    );
  });

  test('um aluno não pode enviar mensagem numa sala alheia nem falsificar o remetente', async () => {
    const studentB = testEnv.authenticatedContext(STUDENT_B).firestore();
    const foreignMessage = doc(
      studentB,
      'chat',
      ROOM_A,
      'mensagens',
      'forbidden-message',
    );

    await assertFails(setDoc(foreignMessage, directMessage(STUDENT_B)));

    const studentA = testEnv.authenticatedContext(STUDENT_A).firestore();
    await assertFails(
      setDoc(
        doc(studentA, 'chat', ROOM_A, 'mensagens', 'spoofed-message'),
        directMessage(ADMIN_ID),
      ),
    );
  });

  test('um admin pode migrar uma sala legada adicionando participantes uma única vez', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'chat', 'legacy-room'), {
        lastMessage: 'Legada',
      });
    });
    const admin = testEnv.authenticatedContext(ADMIN_ID).firestore();
    await assertSucceeds(
      updateDoc(doc(admin, 'chat', 'legacy-room'), {
        participantIds: [ADMIN_ID, STUDENT_A],
      }),
    );
  });

  test('o aluno pode criar a sala própria e a primeira mensagem numa batch atómica', async () => {
    const studentA = testEnv.authenticatedContext(STUDENT_A).firestore();
    const roomRef = doc(studentA, 'chat', 'chat_admin-1_student-a-new');
    const messageRef = doc(roomRef, 'mensagens', 'message-new');
    const batch = writeBatch(studentA);

    batch.set(roomRef, {
      participantIds: [STUDENT_A, ADMIN_ID],
      lastMessage: 'Olá',
      lastTimestamp: Timestamp.now(),
      lastSenderId: STUDENT_A,
      lastMessageId: 'message-new',
      typing: '',
    });
    batch.set(messageRef, directMessage(STUDENT_A, { texto: 'Olá' }));

    await assertSucceeds(batch.commit());
  });
});

describe('Firestore Rules — grupos', () => {
  beforeEach(seedBaseData);

  test('a consulta do aluno devolve apenas grupos onde é membro', async () => {
    const studentA = testEnv.authenticatedContext(STUDENT_A).firestore();
    const groups = await assertSucceeds(
      getDocs(
        query(
          collection(studentA, 'grupos'),
          where('membros', 'array-contains', STUDENT_A),
        ),
      ),
    );

    expect(groups.docs.map((group) => group.id)).toEqual([GROUP_ID]);
  });

  test('um membro não pode adicionar-se, remover membros ou alterar a composição', async () => {
    const studentA = testEnv.authenticatedContext(STUDENT_A).firestore();
    await assertFails(
      updateDoc(doc(studentA, 'grupos', GROUP_ID), {
        membros: [STUDENT_A, STUDENT_B],
      }),
    );
  });

  test('um membro lê e escreve mensagens apenas como si próprio', async () => {
    const studentA = testEnv.authenticatedContext(STUDENT_A).firestore();
    const studentB = testEnv.authenticatedContext(STUDENT_B).firestore();

    await assertSucceeds(
      setDoc(
        doc(studentA, 'grupos', GROUP_ID, 'mensagens', 'message-a'),
        {
          remetenteId: STUDENT_A,
          texto: 'Olá grupo',
          timestamp: Timestamp.now(),
          lida: false,
        },
      ),
    );
    await assertFails(
      setDoc(
        doc(studentA, 'grupos', GROUP_ID, 'mensagens', 'message-spoof'),
        directMessage(STUDENT_B),
      ),
    );
    await assertFails(getDoc(doc(studentB, 'grupos', GROUP_ID)));
  });

  test('um membro só pode atualizar o próprio cursor de leitura', async () => {
    const studentA = testEnv.authenticatedContext(STUDENT_A).firestore();
    await assertSucceeds(
      updateDoc(doc(studentA, 'grupos', GROUP_ID), {
        'lastReadAtByUser.student-a': Timestamp.now(),
      }),
    );
    await assertFails(
      updateDoc(doc(studentA, 'grupos', GROUP_ID), {
        'lastReadAtByUser.student-b': Timestamp.now(),
      }),
    );
  });
});

describe('Firestore Rules — agenda e schema de dados', () => {
  beforeEach(seedBaseData);

  test('o aluno não cria bookings diretamente nem altera campos protegidos', async () => {
    const studentA = testEnv.authenticatedContext(STUDENT_A).firestore();
    await assertFails(setDoc(doc(studentA, 'agenda', 'direct-create'), {
      studentId: STUDENT_A,
      trainerId: ADMIN_ID,
      data: Timestamp.fromMillis(Date.now() + 3600000),
      duracaoMinutos: 60,
      status: 'pending',
    }));
    await assertFails(updateDoc(doc(studentA, 'agenda', 'booking-1'), {
      trainerId: STUDENT_B,
    }));
    await assertSucceeds(updateDoc(doc(studentA, 'agenda', 'booking-1'), {
      status: 'cancelled',
    }));
  });

  test('diário rejeita valores absurdos e aceita schema mínimo', async () => {
    const studentA = testEnv.authenticatedContext(STUDENT_A).firestore();
    const diary = doc(studentA, 'users', STUDENT_A, 'diario', '2026-08-18');
    await assertFails(setDoc(diary, { agua: -1, passos: 0, avaliacao: 0, refeicoes: [] }));
    await assertSucceeds(setDoc(diary, {
      agua: 500,
      passos: 1000,
      avaliacao: 4,
      treinoConcluido: false,
      refeicoes: [],
    }));
  });

  test('fcmToken e consentimento não podem ser escritos diretamente pelo aluno', async () => {
    const studentA = testEnv.authenticatedContext(STUDENT_A).firestore();
    await assertFails(updateDoc(doc(studentA, 'users', STUDENT_A), {
      fcmToken: 'token-arbitrario-que-nao-deve-ser-aceite',
    }));
    await assertFails(updateDoc(doc(studentA, 'users', STUDENT_A), {
      privacyPolicyVersion: 'privacy-2026-08-draft',
      privacyPolicyAcceptedAt: Timestamp.now(),
    }));
    await assertFails(setDoc(doc(
      studentA,
      'users',
      STUDENT_A,
      'privacyConsentAudit',
      'privacy-2026-08-draft',
    ), {
      version: 'privacy-2026-08-draft',
      acceptedAt: Timestamp.now(),
    }));
  });
});

describe('Firestore Rules — dados administrativos', () => {
  beforeEach(seedBaseData);

  test('o agregado do dashboard é apenas de leitura para admins', async () => {
    const admin = testEnv.authenticatedContext(ADMIN_ID).firestore();
    const studentA = testEnv.authenticatedContext(STUDENT_A).firestore();
    const aggregate = doc(admin, 'adminAggregates', 'dashboard');

    await assertSucceeds(getDoc(aggregate));
    await assertFails(getDoc(doc(studentA, 'adminAggregates', 'dashboard')));
    await assertFails(setDoc(aggregate, { sessoesTotal: 999 }));
  });
});

describe('Firestore Rules — questionário', () => {
  beforeEach(seedBaseData);

  const answers = {
    birthDate: '01/01/1990',
    nome: 'Aluno A',
    genero: 'feminino',
    peso: '70',
    altura: '170',
    profession: 'Professora',
    activity: 'Às vezes',
    sedentary: 'não',
    meals: '3',
    water: '1–2 L',
    sleep: '7–8 h',
    pathologiesHas: 'não',
    familyPathologiesHas: 'não',
    surgeryHas: 'não',
    medicationHas: 'não',
    supplementsHas: 'não',
    allergiesHas: 'não',
    dislikedFoods: 'Nenhum',
    preferredFoods: 'Fruta',
    outsideMeals: '1',
    objective: 'Melhorar a condição física',
  };

  test('não é possível marcar o perfil como concluído sem uma resposta válida', async () => {
    const studentA = testEnv.authenticatedContext(STUDENT_A).firestore();
    await assertFails(
      updateDoc(doc(studentA, 'users', STUDENT_A), {
        questionnaireVersion: 'questionnaire-2026-08-health-v2',
        questionnaireCompletedAt: Timestamp.now(),
      }),
    );
  });

  test('resposta e conclusão válida são aceites na mesma batch', async () => {
    const studentA = testEnv.authenticatedContext(STUDENT_A).firestore();
    const completedAt = Timestamp.now();
    const batch = writeBatch(studentA);
    batch.set(doc(studentA, 'users', STUDENT_A, 'questionario', 'resposta'), {
      version: 'questionnaire-2026-08-health-v2',
      completedAt,
      answers,
    });
    batch.update(doc(studentA, 'users', STUDENT_A), {
      questionnaireVersion: 'questionnaire-2026-08-health-v2',
      questionnaireCompletedAt: completedAt,
      nome: 'Aluno A',
      genero: 'feminino',
      pesoAtual: 70,
      altura: 170,
    });

    await assertSucceeds(batch.commit());
  });

  test('respostas incompletas são rejeitadas', async () => {
    const studentA = testEnv.authenticatedContext(STUDENT_A).firestore();
    await assertFails(
      setDoc(
        doc(studentA, 'users', STUDENT_A, 'questionario', 'resposta'),
        {
          version: 'questionnaire-2026-08-health-v2',
          completedAt: Timestamp.now(),
          answers: { nome: 'Aluno A' },
        },
      ),
    );
  });
});
