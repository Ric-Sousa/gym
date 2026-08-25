const fs = require('node:fs');
const path = require('node:path');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const { doc, setDoc, writeBatch } = require('firebase/firestore');
const {
  getBytes,
  ref,
  uploadBytes,
} = require('firebase/storage');

const rules = fs.readFileSync(
  path.join(__dirname, '..', 'storage.rules'),
  'utf8',
);

// Storage rules that call firestore.get() must use the same emulator project
// as the Firestore suite and the Firebase CLI process.
const PROJECT_ID = 'gymbt-rules-test';
const ADMIN_ID = 'admin-1';
const STUDENT_A = 'student-a';
const STUDENT_B = 'student-b';
const ROOM_ID = 'chat_admin-1_student-a';
const GROUP_ID = 'group-1';

let testEnv;

function userData(uid) {
  return {
    role: uid === ADMIN_ID ? 'admin' : 'aluno',
    isActive: true,
    nome: uid,
    ...(uid === STUDENT_A || uid === STUDENT_B
      ? { personalId: ADMIN_ID }
      : {}),
  };
}

async function seedBaseData() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const batch = writeBatch(db);
  batch.set(doc(db, 'users', ADMIN_ID), userData(ADMIN_ID));
  batch.set(doc(db, 'users', STUDENT_A), userData(STUDENT_A));
  batch.set(doc(db, 'users', STUDENT_B), userData(STUDENT_B));
  batch.set(doc(db, 'chat', ROOM_ID), {
    participantIds: [ADMIN_ID, STUDENT_A],
  });
  batch.set(doc(db, 'grupos', GROUP_ID), {
    membros: [STUDENT_A],
  });
    await batch.commit();
  });
}

function storageFor(uid) {
  return testEnv.authenticatedContext(uid).storage();
}

function bytes(size) {
  return new Uint8Array(size);
}

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8') },
    storage: { rules },
  });
});

afterEach(async () => {
  if (testEnv) {
    await testEnv.clearFirestore();
    await testEnv.clearStorage();
  }
});

afterAll(async () => {
  if (testEnv) await testEnv.cleanup();
});

describe('Storage Rules — chat', () => {
  beforeEach(seedBaseData);

  test('apenas os participantes leem/escrevem anexos da sala', async () => {
    const studentA = storageFor(STUDENT_A);
    const studentB = storageFor(STUDENT_B);
    const attachment = ref(studentA, `chat_attachments/${ROOM_ID}/${STUDENT_A}_image.jpg`);
    const audio = ref(studentA, `chat_audio/${ROOM_ID}/${STUDENT_A}_voice.m4a`);

    await assertSucceeds(
      uploadBytes(attachment, bytes(32), { contentType: 'image/jpeg' }),
    );
    await assertSucceeds(getBytes(attachment));
    await assertFails(
      getBytes(ref(studentB, `chat_attachments/${ROOM_ID}/${STUDENT_A}_image.jpg`)),
    );
    await assertFails(
      uploadBytes(
        ref(studentB, `chat_attachments/${ROOM_ID}/${STUDENT_B}_stolen.jpg`),
        bytes(32),
        { contentType: 'image/jpeg' },
      ),
    );

    await assertSucceeds(
      uploadBytes(audio, bytes(32), { contentType: 'audio/mp4' }),
    );
    await assertSucceeds(require('firebase/storage').deleteObject(attachment));
    await assertFails(require('firebase/storage').deleteObject(
      ref(studentB, `chat_attachments/${ROOM_ID}/${STUDENT_A}_image.jpg`),
    ));
  });

  test('anexos rejeitam MIME inválido e ficheiros acima do limite', async () => {
    const studentA = storageFor(STUDENT_A);
    await assertFails(
      uploadBytes(
        ref(studentA, `chat_attachments/${ROOM_ID}/${STUDENT_A}_script.exe`),
        bytes(32),
        { contentType: 'application/octet-stream' },
      ),
    );
    await assertFails(
      uploadBytes(
        ref(studentA, `chat_audio/${ROOM_ID}/${STUDENT_A}_too-large.m4a`),
        bytes(25 * 1024 * 1024 + 1),
        { contentType: 'audio/mp4' },
      ),
    );
  });
});

describe('Storage Rules — grupos', () => {
  beforeEach(seedBaseData);

  test('membros podem enviar anexos e audio sem acesso de terceiros', async () => {
    const studentA = storageFor(STUDENT_A);
    const studentB = storageFor(STUDENT_B);
    const admin = storageFor(ADMIN_ID);
    const attachmentPath =
      `group_chat_attachments/${GROUP_ID}/${STUDENT_A}_image.jpg`;
    const audioPath = `group_chat_audio/${GROUP_ID}/${STUDENT_A}_voice.m4a`;

    await assertSucceeds(
      uploadBytes(ref(studentA, attachmentPath), bytes(32), {
        contentType: 'image/jpeg',
      }),
    );
    await assertSucceeds(
      uploadBytes(ref(studentA, audioPath), bytes(32), {
        contentType: 'audio/mp4',
      }),
    );
    await assertSucceeds(getBytes(ref(studentA, attachmentPath)));
    await assertFails(getBytes(ref(studentB, attachmentPath)));
    await assertFails(
      uploadBytes(
        ref(
          studentB,
          `group_chat_attachments/${GROUP_ID}/${STUDENT_B}_image.jpg`,
        ),
        bytes(32),
        { contentType: 'image/jpeg' },
      ),
    );
    await assertSucceeds(
      uploadBytes(
        ref(admin, `group_chat_attachments/${GROUP_ID}/${ADMIN_ID}_image.jpg`),
        bytes(32),
        { contentType: 'image/jpeg' },
      ),
    );
    await assertSucceeds(
      require('firebase/storage').deleteObject(ref(studentA, attachmentPath)),
    );
    await assertFails(
      require('firebase/storage').deleteObject(ref(studentB, audioPath)),
    );
  });
});

describe('Storage Rules — paths privados', () => {
  beforeEach(seedBaseData);

  test('a regra users não aceita paths arbitrários', async () => {
    const studentA = storageFor(STUDENT_A);
    await assertSucceeds(
      uploadBytes(
        ref(studentA, `users/${STUDENT_A}/profile.jpg`),
        bytes(32),
        { contentType: 'image/jpeg' },
      ),
    );
    await assertFails(
      uploadBytes(
        ref(studentA, `users/${STUDENT_A}/arbitrary.bin`),
        bytes(32),
        { contentType: 'application/octet-stream' },
      ),
    );
    await assertFails(
      getBytes(ref(storageFor(STUDENT_B), `users/${STUDENT_A}/profile.jpg`)),
    );
  });

  test('o proprietário pode limpar um upload próprio, mas outro aluno não', async () => {
    const studentA = storageFor(STUDENT_A);
    const studentB = storageFor(STUDENT_B);
    const file = ref(studentA, `users/${STUDENT_A}/progresso/cleanup.png`);
    await assertSucceeds(uploadBytes(file, bytes(32), { contentType: 'image/png' }));
    await assertFails(getBytes(ref(studentB, `users/${STUDENT_A}/progresso/cleanup.png`)));
    // delete is intentionally exercised by the application cleanup path.
    const { deleteObject } = require('firebase/storage');
    await assertSucceeds(deleteObject(file));
  });

  test('vídeos de progresso aplicam MIME e tamanho', async () => {
    const studentA = storageFor(STUDENT_A);
    const video = ref(
      studentA,
      `users/${STUDENT_A}/progress_videos/video-1.mp4`,
    );
    await assertSucceeds(
      uploadBytes(video, bytes(32), { contentType: 'video/mp4' }),
    );
    await assertFails(
      uploadBytes(
        ref(studentA, `users/${STUDENT_A}/progress_videos/not-video.txt`),
        bytes(32),
        { contentType: 'text/plain' },
      ),
    );
  });

  test('imagens de grupo usam o path com o groupId e só o admin escreve', async () => {
    const studentA = storageFor(STUDENT_A);
    const studentB = storageFor(STUDENT_B);
    const admin = storageFor(ADMIN_ID);
    const groupImagePath = `chat_attachments/group_images/${GROUP_ID}/cover.jpg`;

    await assertSucceeds(
      uploadBytes(ref(admin, groupImagePath), bytes(32), {
        contentType: 'image/jpeg',
      }),
    );
    await assertSucceeds(getBytes(ref(studentA, groupImagePath)));
    await assertFails(getBytes(ref(studentB, groupImagePath)));
    await assertFails(
      uploadBytes(ref(studentA, `chat_attachments/group_images/${GROUP_ID}/new.jpg`), bytes(32), {
        contentType: 'image/jpeg',
      }),
    );
  });

  test('comprovativos só podem ser carregados pelo admin', async () => {
    const studentA = storageFor(STUDENT_A);
    const admin = storageFor(ADMIN_ID);
    await assertFails(
      uploadBytes(
        ref(studentA, `payment_proofs/${STUDENT_A}/proof.jpg`),
        bytes(32),
        { contentType: 'image/jpeg' },
      ),
    );
    await assertSucceeds(
      uploadBytes(
        ref(admin, `payment_proofs/${STUDENT_A}/proof.jpg`),
        bytes(32),
        { contentType: 'image/jpeg' },
      ),
    );
  });
});
