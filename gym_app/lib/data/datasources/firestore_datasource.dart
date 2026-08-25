import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/exceptions.dart';
import '../../core/utils/food_search.dart';
import '../models/user_model.dart';
import '../models/diary_model.dart';
import '../models/nutrition_plan_model.dart';
import '../models/workout_plan_model.dart';
import '../models/exercise_catalog_model.dart';
import '../models/message_model.dart';
import '../models/progress_model.dart';
import '../models/progress_video_model.dart';
import '../models/food_model.dart';
import '../models/workout_log_model.dart';
import '../models/payment_model.dart';
import '../models/app_notification_model.dart';
import '../models/booking_model.dart';
import '../models/group_model.dart';
import '../models/questionnaire_response_model.dart';
import '../models/questionnaire_config_model.dart';
import '../../core/config/app_constants.dart';

/// Página de resultados Firestore com cursor para a próxima leitura.
class FirestorePage<T> {
  final List<T> items;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;

  const FirestorePage({
    required this.items,
    required this.cursor,
    required this.hasMore,
  });
}

/// Data source para operações no Cloud Firestore.
class FirestoreDataSource {
  final FirebaseFirestore _firestore;

  FirestoreDataSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  // ───────────────────── USERS ─────────────────────

  /// Obtém modelo de utilizador pelo UID.
  Future<UserModel> getUser(String uid) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();
      if (!doc.exists) {
        throw DocumentNotFoundException();
      }
      return UserModel.fromMap(uid, doc.data()!);
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao obter utilizador');
    }
  }

  /// Atualiza campos do utilizador.
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .update(data);
    } on FirebaseException catch (e) {
      throw ServerException(
        message: e.message ?? 'Erro ao atualizar utilizador',
      );
    }
  }

  /// Obtém a nota privada do administrador para um cliente.
  Future<String> getAdminNote(String uid) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .collection('adminData')
          .doc('profile')
          .get();
      return (doc.data()?['note'] as String?) ?? '';
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao obter nota');
    }
  }

  /// Guarda a nota privada do administrador para um cliente.
  Future<void> setAdminNote(String uid, String note, {String? adminId}) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .collection('adminData')
          .doc('profile')
          .set({
            'note': note,
            'updatedAt': DateTime.now(),
            if (adminId != null) 'updatedBy': adminId,
          }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao guardar nota');
    }
  }

  /// Obtém a ficha inicial de anamnese do aluno.
  Future<QuestionnaireResponse?> getQuestionnaire(String uid) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .collection('questionario')
          .doc('resposta')
          .get();
      if (!doc.exists || doc.data() == null) return null;
      return QuestionnaireResponse.fromMap(doc.data()!);
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao obter questionário');
    }
  }

  /// Guarda as respostas e marca o perfil como concluído numa operação lógica.
  Future<void> saveQuestionnaire(
    String uid,
    QuestionnaireResponse response, {
    String? nome,
    String? genero,
    double? peso,
    double? altura,
    DateTime? dataNascimento,
  }) async {
    try {
      final userRef = _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid);
      final responseRef = userRef.collection('questionario').doc('resposta');
      final batch = _firestore.batch();
      batch.set(responseRef, response.toMap());
      // A versão é gravada no mesmo batch e funciona como o marcador
      // atómico de conclusão; a data fica com a hora oficial do servidor.
      batch.update(userRef, {
        'questionnaireCompletedAt': FieldValue.serverTimestamp(),
        'questionnaireVersion': response.version,
        if (nome != null && nome.trim().isNotEmpty) 'nome': nome.trim(),
        if (genero != null && genero.trim().isNotEmpty) 'genero': genero,
        if (peso != null) 'pesoAtual': peso,
        if (altura != null) 'altura': altura,
        if (dataNascimento != null) 'dataNascimento': dataNascimento,
      });
      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException(
        message: e.message ?? 'Erro ao guardar questionário',
      );
    }
  }

  /// Obtém a configuração editável do questionário. Quando ainda não existe,
  /// devolve a ficha padrão para não interromper o primeiro acesso do aluno.
  Future<QuestionnaireConfig> getQuestionnaireConfig() async {
    try {
      final doc = await _firestore
          .collection(AppConstants.questionnaireConfigCollection)
          .doc(QuestionnaireConfig.documentId)
          .get();
      if (!doc.exists || doc.data() == null) {
        return QuestionnaireConfig.defaultConfig();
      }
      return QuestionnaireConfig.fromMap(doc.data()!);
    } on FirebaseException catch (e) {
      throw ServerException(
        message: e.message ?? 'Erro ao obter configuração do questionário',
      );
    }
  }

  /// Stream da configuração do questionário para admin e aluno.
  Stream<QuestionnaireConfig> questionnaireConfigStream() {
    return _firestore
        .collection(AppConstants.questionnaireConfigCollection)
        .doc(QuestionnaireConfig.documentId)
        .snapshots()
        .map(
          (doc) => !doc.exists || doc.data() == null
              ? QuestionnaireConfig.defaultConfig()
              : QuestionnaireConfig.fromMap(doc.data()!),
        );
  }

  /// Guarda a configuração criada pelo administrador.
  Future<void> saveQuestionnaireConfig(QuestionnaireConfig config) async {
    try {
      await _firestore
          .collection(AppConstants.questionnaireConfigCollection)
          .doc(QuestionnaireConfig.documentId)
          .set(config.toMap());
    } on FirebaseException catch (e) {
      throw ServerException(
        message: e.message ?? 'Erro ao guardar configuração do questionário',
      );
    }
  }

  /// Stream da ficha inicial do aluno.
  Stream<QuestionnaireResponse?> questionnaireStream(String uid) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .collection('questionario')
        .doc('resposta')
        .snapshots()
        .map(
          (doc) => doc.exists && doc.data() != null
              ? QuestionnaireResponse.fromMap(doc.data()!)
              : null,
        );
  }

  /// Stream de um utilizador.
  Stream<UserModel> userStream(String uid) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .snapshots()
        .map((doc) {
          if (!doc.exists) throw DocumentNotFoundException();
          return UserModel.fromMap(uid, doc.data()!);
        });
  }

  /// Stream de todos os alunos. Atualiza criação, edição e remoção sem refresh.
  Stream<List<UserModel>> watchAllAlunos() {
    return _firestore
        .collection(AppConstants.usersCollection)
        .where('role', isEqualTo: AppConstants.roleAluno)
        .snapshots()
        .map((snapshot) {
          final alunos = snapshot.docs
              .map((doc) => UserModel.fromMap(doc.id, doc.data()))
              .toList();
          // Ordenar no cliente evita que esta leitura essencial dependa do
          // índice composto `role + nome` estar já criado/ativo no Firestore.
          alunos.sort(
            (a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()),
          );
          return alunos;
        });
  }

  /// Lê uma página de alunos com cursor estável.
  Future<FirestorePage<UserModel>> getAlunosPage({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 25,
  }) async {
    try {
      final pageSize = limit.clamp(1, 100);
      Query<Map<String, dynamic>> query = _firestore
          .collection(AppConstants.usersCollection)
          .where('role', isEqualTo: AppConstants.roleAluno)
          .limit(pageSize);
      if (startAfter != null) query = query.startAfterDocument(startAfter);
      final snapshot = await query.get();
      return FirestorePage(
        items: snapshot.docs
            .map((doc) => UserModel.fromMap(doc.id, doc.data()))
            .toList(),
        cursor: snapshot.docs.isEmpty ? startAfter : snapshot.docs.last,
        hasMore: snapshot.docs.length == pageSize,
      );
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao listar alunos');
    }
  }

  /// Lista todos os alunos.
  Future<List<UserModel>> getAllAlunos() async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('role', isEqualTo: AppConstants.roleAluno)
          .get();
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.id, doc.data()))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao listar alunos');
    }
  }

  /// Pesquisa alunos por nome.
  Future<List<UserModel>> searchAlunos(String query) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('role', isEqualTo: AppConstants.roleAluno)
          .get();
      final lowerQuery = query.toLowerCase();
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.id, doc.data()))
          .where((user) => user.nome.toLowerCase().contains(lowerQuery))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao pesquisar alunos');
    }
  }

  // ───────────────────── DIARY ─────────────────────

  /// Obtém o diário de um dia específico.
  Future<DiaryModel?> getDiaryEntry(String userId, String date) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.diarySubcollection)
          .doc(date)
          .get();
      if (!doc.exists) return null;
      return DiaryModel.fromMap(date, userId, doc.data()!);
    } on FirebaseException catch (e) {
      throw ServerException(
        message: e.message ?? 'Erro ao obter registo diário',
      );
    }
  }

  /// Stream do documento diário.
  Stream<DiaryModel?> diaryEntryStream(String userId, String date) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.diarySubcollection)
        .doc(date)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return DiaryModel.fromMap(date, userId, doc.data()!);
        });
  }

  /// Cria ou atualiza documento diário.
  Future<void> setDiaryEntry(
    String userId,
    String date,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.diarySubcollection)
          .doc(date)
          .set(data, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(
        message: e.message ?? 'Erro ao guardar registo diário',
      );
    }
  }

  /// Incrementa um campo numérico do diário.
  Future<void> incrementDiaryField(
    String userId,
    String date,
    String field,
    num value,
  ) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.diarySubcollection)
          .doc(date)
          .set({field: FieldValue.increment(value)}, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao incrementar campo');
    }
  }

  /// Adiciona uma refeição à lista no diário.
  Future<void> addMealToDiary(
    String userId,
    String date,
    Map<String, dynamic> mealMap,
  ) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.diarySubcollection)
          .doc(date)
          .set({
            'refeicoes': FieldValue.arrayUnion([mealMap]),
          }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao adicionar refeição');
    }
  }

  /// Stream do histórico de diários (para o dashboard do aluno).
  Stream<List<DiaryModel>> watchDiaryHistory(String userId, {int limit = 90}) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.diarySubcollection)
        .orderBy('data', descending: true)
        .limit(limit.clamp(1, 365))
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => DiaryModel.fromMap(doc.id, userId, doc.data()))
              .toList();
        });
  }

  /// Obtém histórico de diários (para progresso).
  Future<List<DiaryModel>> getDiaryHistory(
    String userId, {
    int limit = 90,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.diarySubcollection)
          .orderBy('data', descending: true)
          .limit(limit.clamp(1, 365))
          .get();
      return snapshot.docs
          .map((doc) => DiaryModel.fromMap(doc.id, userId, doc.data()))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao obter histórico');
    }
  }

  // ───────────────────── NUTRITION PLAN ─────────────────────

  /// Stream do plano nutricional de um dia da semana.
  Stream<NutritionPlanModel?> nutritionPlanStream(
    String userId,
    String diaSemana,
  ) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.nutritionPlanSubcollection)
        .doc(diaSemana)
        .snapshots()
        .map(
          (doc) => doc.exists && doc.data() != null
              ? NutritionPlanModel.fromMap(diaSemana, userId, doc.data()!)
              : null,
        );
  }

  /// Obtém plano nutricional para um dia da semana.
  Future<NutritionPlanModel?> getNutritionPlan(
    String userId,
    String diaSemana,
  ) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.nutritionPlanSubcollection)
          .doc(diaSemana)
          .get();
      if (!doc.exists) return null;
      return NutritionPlanModel.fromMap(diaSemana, userId, doc.data()!);
    } on FirebaseException catch (e) {
      throw ServerException(
        message: e.message ?? 'Erro ao obter plano nutricional',
      );
    }
  }

  /// Guarda plano nutricional.
  Future<void> setNutritionPlan(
    String userId,
    String diaSemana,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.nutritionPlanSubcollection)
          .doc(diaSemana)
          .set(data, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(
        message: e.message ?? 'Erro ao guardar plano nutricional',
      );
    }
  }

  // ───────────────────── GLOBAL WORKOUT PLANS ─────────────────────

  /// Stream dos planos globais criados pelo administrador.
  Stream<List<WorkoutPlanModel>> watchGlobalWorkoutPlans() {
    return _firestore
        .collection(AppConstants.globalWorkoutPlansCollection)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => WorkoutPlanModel.fromMap(doc.id, '', doc.data()))
              .toList(),
        );
  }

  /// Lista os planos globais criados pelo administrador.
  Future<List<WorkoutPlanModel>> getGlobalWorkoutPlans() async {
    try {
      // Não usamos orderBy aqui porque planos antigos podem não ter
      // `createdAt`. A ordenação da biblioteca é feita na interface.
      final snapshot = await _firestore
          .collection(AppConstants.globalWorkoutPlansCollection)
          .get();
      return snapshot.docs
          .map((doc) => WorkoutPlanModel.fromMap(doc.id, '', doc.data()))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException(
        message: e.message ?? 'Erro ao listar planos globais',
      );
    }
  }

  /// Elimina um plano global.
  Future<void> deleteGlobalWorkoutPlan(String planId) async {
    try {
      await _firestore
          .collection(AppConstants.globalWorkoutPlansCollection)
          .doc(planId)
          .delete();
    } on FirebaseException catch (e) {
      throw ServerException(
        message: e.message ?? 'Erro ao eliminar plano global',
      );
    }
  }

  /// Cria ou atualiza um plano global.
  Future<void> setGlobalWorkoutPlan(
    String planId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore
          .collection(AppConstants.globalWorkoutPlansCollection)
          .doc(planId)
          .set(data, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(
        message: e.message ?? 'Erro ao guardar plano global',
      );
    }
  }

  // ───────────────────── WORKOUT PLAN ─────────────────────

  /// Obtém plano de treino por nome.
  Future<WorkoutPlanModel?> getWorkoutPlan(String userId, String nome) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.workoutPlanSubcollection)
          .doc(nome)
          .get();
      if (!doc.exists) return null;
      return WorkoutPlanModel.fromMap(nome, userId, doc.data()!);
    } on FirebaseException catch (e) {
      throw ServerException(
        message: e.message ?? 'Erro ao obter plano de treino',
      );
    }
  }

  /// Verifica se o plano do aluno foi atribuído a partir de um plano global.
  /// Dados antigos sem marcador continuam compatíveis quando o documento
  /// coincide com o identificador/nome legado recebido pelo chamador.
  Future<DateTime?> getWorkoutPlanAssignedAt(
    String userId,
    String planId,
  ) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.workoutPlanSubcollection)
          .doc(planId)
          .get();
      if (!doc.exists) return null;
      final value = doc.data()?['assignedAt'];
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value != null) return DateTime.tryParse(value.toString());
      return null;
    } on FirebaseException catch (e) {
      throw ServerException(
        message: e.message ?? 'Erro ao obter data de atribuição',
      );
    }
  }

  /// Verifica se o plano do aluno foi atribuído a partir de um plano global.
  Future<bool> isGlobalWorkoutPlanAssigned(String userId, String planId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.workoutPlanSubcollection)
          .doc(planId)
          .get();
      if (!doc.exists) return false;
      final data = doc.data() ?? <String, dynamic>{};
      return data['assignedPlanId'] == planId || data['assignedAt'] != null;
    } on FirebaseException catch (e) {
      throw ServerException(
        message: e.message ?? 'Erro ao verificar atribuição do plano',
      );
    }
  }

  /// Stream de todos os planos de treino do aluno.
  Stream<List<WorkoutPlanModel>> watchAllWorkoutPlans(String userId) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.workoutPlanSubcollection)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => WorkoutPlanModel.fromMap(doc.id, userId, doc.data()),
              )
              .toList(),
        );
  }

  /// Lista todos os planos de treino do aluno.
  Future<List<WorkoutPlanModel>> getAllWorkoutPlans(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.workoutPlanSubcollection)
          .get();
      return snapshot.docs
          .map((doc) => WorkoutPlanModel.fromMap(doc.id, userId, doc.data()))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException(
        message: e.message ?? 'Erro ao listar planos de treino',
      );
    }
  }

  /// Elimina um plano atribuído a um aluno.
  Future<void> deleteWorkoutPlan(String userId, String nome) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.workoutPlanSubcollection)
          .doc(nome)
          .delete();
    } on FirebaseException catch (e) {
      throw ServerException(
        message: e.message ?? 'Erro ao eliminar plano atribuído',
      );
    }
  }

  /// Guarda plano de treino.
  Future<void> setWorkoutPlan(
    String userId,
    String nome,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.workoutPlanSubcollection)
          .doc(nome)
          .set(data, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(
        message: e.message ?? 'Erro ao guardar plano de treino',
      );
    }
  }

  // ───────────────────── CHAT ─────────────────────

  /// Obtém a sala de chat.
  String getChatRoomId(String alunoId, String personalId) {
    final ids = [alunoId, personalId]..sort();
    return '${AppConstants.chatRoomPrefix}_${ids[0]}_${ids[1]}';
  }

  /// Garante que a sala existe com a lista imutável de participantes.
  /// Deve ser chamado antes de carregar anexos/áudio, porque as Storage Rules
  /// consultam este documento antes de aceitar o upload.
  Future<void> ensureChatRoom(
    String salaId,
    List<String> participantIds,
  ) async {
    try {
      final normalizedParticipants = [...participantIds]..sort();
      await _firestore.collection(AppConstants.chatCollection).doc(salaId).set({
        'participantIds': normalizedParticipants,
        'typing': '',
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao preparar conversa');
    }
  }

  /// Stream de mensagens da sala de chat.
  Stream<List<MessageModel>> messagesStream(String salaId) {
    return _firestore
        .collection(AppConstants.chatCollection)
        .doc(salaId)
        .collection(AppConstants.messagesSubcollection)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MessageModel.fromMap(doc.id, doc.data()))
              .toList()
              .reversed
              .toList(),
        );
  }

  /// Marca como lidas as mensagens recebidas numa conversa direta.
  Future<void> markMessagesAsRead(
    String salaId,
    String userId,
    DateTime readAt, {
    bool persistConversationCursor = false,
  }) async {
    try {
      final roomRef = _firestore
          .collection(AppConstants.chatCollection)
          .doc(salaId);
      final snapshot = await roomRef
          .collection(AppConstants.messagesSubcollection)
          .orderBy('timestamp', descending: true)
          .limit(500)
          .get();
      final unread = snapshot.docs.where((doc) {
        final data = doc.data();
        final timestamp = MessageModel.fromMap(doc.id, data).timestamp;
        return data['lida'] != true &&
            data['remetenteId'] != userId &&
            !timestamp.isAfter(readAt);
      }).toList();

      for (var offset = 0; offset < unread.length; offset += 499) {
        final end = offset + 499 < unread.length ? offset + 499 : unread.length;
        final batch = _firestore.batch();
        for (final doc in unread.sublist(offset, end)) {
          batch.update(doc.reference, {'lida': true});
        }
        await batch.commit();
      }

      // O cursor no documento pai é específico da leitura do admin. O aluno
      // continua a usar apenas `lida`, que é compatível com os dados legados.
      if (persistConversationCursor) {
        await roomRef.set({'lastReadAt': readAt}, SetOptions(merge: true));
      }
    } on FirebaseException catch (e) {
      throw ServerException(
        message: e.message ?? 'Erro ao marcar mensagens como lidas',
      );
    }
  }

  /// Envia a mensagem e atualiza a sala numa única operação atómica.
  ///
  /// O admin observa o documento pai para atualizar a lista de conversas.
  /// Se estas escritas fossem separadas, o listener podia ler a sala antes
  /// de a mensagem existir na subcoleção e perder a notificação sonora.
  Future<void> sendMessage(
    String salaId,
    Map<String, dynamic> messageMap, {
    List<String>? participantIds,
  }) async {
    try {
      final normalizedParticipants = participantIds == null
          ? null
          : ([...participantIds]..sort());
      final roomRef = _firestore
          .collection(AppConstants.chatCollection)
          .doc(salaId);
      final messageRef = roomRef
          .collection(AppConstants.messagesSubcollection)
          .doc();
      final batch = _firestore.batch();

      // Usa DateTime.now() em vez de FieldValue.serverTimestamp() para
      // manter o mesmo formato esperado pelos modelos e pelas queries Web.
      batch.set(roomRef, {
        if (normalizedParticipants != null)
          'participantIds': normalizedParticipants,
        'lastMessage': (messageMap['texto'] as String?)?.isNotEmpty == true
            ? messageMap['texto']
            : messageMap['attachmentUrl'] != null
            ? 'Imagem anexada'
            : 'Mensagem de áudio',

        'lastTimestamp': DateTime.now(),
        'lastSenderId': messageMap['remetenteId'] ?? '',
        'lastMessageId': messageRef.id,
        'typing': '',
      }, SetOptions(merge: true));
      batch.set(messageRef, messageMap);
      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao enviar mensagem');
    }
  }

  /// Stream que indica se o outro participante está a digitar.
  /// Retorna o userId de quem está a digitar, ou null se ninguém.
  Stream<String?> typingStream(String salaId, String myUserId) {
    return _firestore
        .collection(AppConstants.chatCollection)
        .doc(salaId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          final data = doc.data();
          if (data == null) return null;
          final typing = data['typing'] as String?;
          if (typing == null || typing.isEmpty || typing == myUserId)
            return null;
          // Verifica se o timestamp de digitação ainda é recente (< 10 segundos)
          final typingAt = data['typingAt'];
          if (typingAt != null) {
            try {
              final ts = (typingAt as dynamic).toDate() as DateTime;
              if (DateTime.now().difference(ts).inSeconds > 10) return null;
            } catch (_) {}
          }
          return typing;
        });
  }

  /// Define ou remove o estado de digitação do utilizador atual.
  Future<void> setTypingStatus(
    String salaId,
    String userId,
    bool isTyping, {
    List<String>? participantIds,
  }) async {
    try {
      final normalizedParticipants = participantIds == null
          ? null
          : ([...participantIds]..sort());
      if (isTyping) {
        await _firestore
            .collection(AppConstants.chatCollection)
            .doc(salaId)
            .set({
              if (normalizedParticipants != null)
                'participantIds': normalizedParticipants,
              'typing': userId,
              'typingAt': DateTime.now(),
            }, SetOptions(merge: true));
      } else {
        // Usa set-merge com '' em vez de FieldValue.delete(),
        // para evitar problemas de permissões no Firestore.
        await _firestore
            .collection(AppConstants.chatCollection)
            .doc(salaId)
            .set({
              if (normalizedParticipants != null)
                'participantIds': normalizedParticipants,
              'typing': '',
            }, SetOptions(merge: true));
      }
    } on FirebaseException catch (_) {
      // Falha silenciosa — o indicador de digitação não é crítico
    }
  }

  // ───────────────────── PROGRESS ─────────────────────

  /// Stream de registos de progresso.
  Stream<List<ProgressModel>> watchProgressHistory(
    String userId, {
    int limit = 50,
  }) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.progressSubcollection)
        .orderBy('data', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ProgressModel.fromMap(doc.id, userId, doc.data()))
              .toList(),
        );
  }

  /// Obtém registos de progresso.
  Future<List<ProgressModel>> getProgressHistory(
    String userId, {
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.progressSubcollection)
          .orderBy('data', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs
          .map((doc) => ProgressModel.fromMap(doc.id, userId, doc.data()))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao obter progresso');
    }
  }

  /// Adiciona registo de progresso.
  Future<void> addProgressEntry(
    String userId,
    Map<String, dynamic> data, {
    String? entryId,
  }) async {
    try {
      final collection = _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.progressSubcollection);
      final payload = {...data, 'userId': userId};
      if (entryId == null || entryId.trim().isEmpty) {
        await collection.add(payload);
      } else {
        await collection.doc(entryId).set(payload, SetOptions(merge: true));
      }
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao guardar progresso');
    }
  }

  // ───────────────────── PROGRESS VIDEOS ─────────────────────

  Stream<List<ProgressVideoModel>> watchProgressVideos(String userId) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection('progressVideos')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ProgressVideoModel.fromMap(doc.id, userId, doc.data()),
              )
              .toList(),
        );
  }

  Future<List<ProgressVideoModel>> getProgressVideos(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection('progressVideos')
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => ProgressVideoModel.fromMap(doc.id, userId, doc.data()))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException(
        message: e.message ?? 'Erro ao obter vídeos de progresso',
      );
    }
  }

  Future<void> addProgressVideo(
    String userId,
    String videoId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection('progressVideos')
          .doc(videoId)
          .set(data);
    } on FirebaseException catch (e) {
      throw ServerException(
        message: e.message ?? 'Erro ao guardar vídeo de progresso',
      );
    }
  }

  Future<void> updateProgressVideo(
    String userId,
    String videoId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection('progressVideos')
          .doc(videoId)
          .update(data);
    } on FirebaseException catch (e) {
      throw ServerException(
        message: e.message ?? 'Erro ao atualizar vídeo de progresso',
      );
    }
  }

  // ───────────────────── FOODS ─────────────────────

  /// Lê uma página de alimentos com cursor por nome.
  Future<FirestorePage<FoodModel>> getFoodsPage({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 30,
  }) async {
    try {
      final pageSize = limit.clamp(1, 100);
      Query<Map<String, dynamic>> query = _firestore
          .collection(AppConstants.foodsCollection)
          .orderBy('nome')
          .limit(pageSize);
      if (startAfter != null) query = query.startAfterDocument(startAfter);
      final snapshot = await query.get();
      return FirestorePage(
        items: snapshot.docs
            .map((doc) => FoodModel.fromMap(doc.id, doc.data()))
            .toList(),
        cursor: snapshot.docs.isEmpty ? startAfter : snapshot.docs.last,
        hasMore: snapshot.docs.length == pageSize,
      );
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao listar alimentos');
    }
  }

  /// Stream de todos os alimentos.
  Stream<List<FoodModel>> watchAllFoods() {
    return _firestore
        .collection(AppConstants.foodsCollection)
        .orderBy('nome')
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => FoodModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Lista todos os alimentos.
  Future<List<FoodModel>> getAllFoods() async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.foodsCollection)
          .orderBy('nome')
          .get();
      return snapshot.docs
          .map((doc) => FoodModel.fromMap(doc.id, doc.data()))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao listar alimentos');
    }
  }

  /// Pesquisa alimentos por nome.
  Future<List<FoodModel>> searchFoods(String query) async {
    try {
      final allFoods = await getAllFoods();
      return FoodSearch.filterAndRank(allFoods, query);
    } on FirebaseException catch (e) {
      throw ServerException(
        message: e.message ?? 'Erro ao pesquisar alimentos',
      );
    }
  }

  /// Adiciona um alimento.
  Future<void> addFood(Map<String, dynamic> data) async {
    try {
      await _firestore.collection(AppConstants.foodsCollection).add(data);
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao adicionar alimento');
    }
  }

  /// Remove um alimento da biblioteca.
  Future<void> deleteFood(String foodId) async {
    try {
      await _firestore
          .collection(AppConstants.foodsCollection)
          .doc(foodId)
          .delete();
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao remover alimento');
    }
  }

  // ───────────────────── WORKOUT LOGS ─────────────────────

  /// Stream do registo de treino de um dia específico.
  Stream<WorkoutLogModel?> workoutLogStream(String userId, String date) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.workoutLogSubcollection)
        .doc(date)
        .snapshots()
        .map(
          (doc) => doc.exists && doc.data() != null
              ? WorkoutLogModel.fromMap(doc.id, userId, doc.data()!)
              : null,
        );
  }

  /// Obtém registo de treino de um dia específico.
  Future<WorkoutLogModel?> getWorkoutLog(String userId, String date) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.workoutLogSubcollection)
          .doc(date)
          .get();
      if (!doc.exists) return null;
      try {
        return WorkoutLogModel.fromMap(doc.id, userId, doc.data()!);
      } on FormatException {
        // Um log antigo/corrompido não deve bloquear a execução do treino.
        return null;
      }
    } on FirebaseException catch (e) {
      throw ServerException(
        message: e.message ?? 'Erro ao obter registo de treino',
      );
    }
  }

  /// Guarda ou atualiza registo de treino.
  Future<void> setWorkoutLog(
    String userId,
    String date,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.workoutLogSubcollection)
          .doc(date)
          .set(data, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(
        message: e.message ?? 'Erro ao guardar registo de treino',
      );
    }
  }

  /// Stream de histórico de registos de treino.
  Stream<List<WorkoutLogModel>> watchWorkoutLogHistory(
    String userId, {
    int limit = 30,
  }) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.workoutLogSubcollection)
        .orderBy('data', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => WorkoutLogModel.fromMap(doc.id, userId, doc.data()))
              .toList(),
        );
  }

  /// Obtém histórico de registos de treino.
  Future<List<WorkoutLogModel>> getWorkoutLogHistory(
    String userId, {
    int limit = 30,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.workoutLogSubcollection)
          .orderBy('data', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs
          .map((doc) => WorkoutLogModel.fromMap(doc.id, userId, doc.data()))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException(
        message: e.message ?? 'Erro ao obter histórico de treinos',
      );
    }
  }

  // ───────────────────── PAYMENTS ─────────────────────

  /// Lê uma página de pagamentos administrativos.
  Future<FirestorePage<PaymentModel>> getPaymentsPage({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 30,
  }) async {
    try {
      final pageSize = limit.clamp(1, 100);
      Query<Map<String, dynamic>> query = _firestore
          .collection(AppConstants.paymentsCollection)
          .orderBy('data', descending: true)
          .limit(pageSize);
      if (startAfter != null) query = query.startAfterDocument(startAfter);
      final snapshot = await query.get();
      return FirestorePage(
        items: snapshot.docs
            .map((doc) => PaymentModel.fromMap(doc.id, doc.data()))
            .toList(),
        cursor: snapshot.docs.isEmpty ? startAfter : snapshot.docs.last,
        hasMore: snapshot.docs.length == pageSize,
      );
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao listar pagamentos');
    }
  }

  /// Stream de pagamentos de um utilizador.
  Stream<List<PaymentModel>> watchPayments(String userId) {
    if (userId.isEmpty) return Stream.value(const []);
    return _firestore
        .collection(AppConstants.paymentsCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final payments = snapshot.docs
              .map((doc) => PaymentModel.fromMap(doc.id, doc.data()))
              .toList();
          payments.sort((a, b) => b.data.compareTo(a.data));
          return payments;
        });
  }

  /// Stream de todos os pagamentos para o painel administrativo.
  Stream<List<PaymentModel>> watchAllPayments() {
    return _firestore
        .collection(AppConstants.paymentsCollection)
        .orderBy('data', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PaymentModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Obtém pagamentos de um utilizador.
  Future<List<PaymentModel>> getPayments(String userId) async {
    try {
      // Ordenamos localmente para evitar um índice composto obrigatório
      // (where userId + orderBy data), que pode fazer o Web SDK repetir a
      // tentativa de leitura quando o índice ainda não existe.
      final snapshot = await _firestore
          .collection(AppConstants.paymentsCollection)
          .where('userId', isEqualTo: userId)
          .get();
      final payments = snapshot.docs
          .map((doc) => PaymentModel.fromMap(doc.id, doc.data()))
          .toList();
      payments.sort((a, b) => b.data.compareTo(a.data));
      return payments;
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao obter pagamentos');
    }
  }

  /// Obtém todos os pagamentos (admin).
  Future<List<PaymentModel>> getAllPayments() async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.paymentsCollection)
          .orderBy('data', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => PaymentModel.fromMap(doc.id, doc.data()))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao listar pagamentos');
    }
  }

  /// Adiciona um pagamento.
  Future<void> addPayment(Map<String, dynamic> data) async {
    try {
      await _firestore.collection(AppConstants.paymentsCollection).add(data);
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao guardar pagamento');
    }
  }

  /// Atualiza estado de pagamento.
  Future<void> updatePayment(String id, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection(AppConstants.paymentsCollection)
          .doc(id)
          .update(data);
    } on FirebaseException catch (e) {
      throw ServerException(
        message: e.message ?? 'Erro ao atualizar pagamento',
      );
    }
  }

  // ───────────────────── NOTIFICATIONS ─────────────────────

  Stream<List<AppNotificationModel>> watchNotifications(String userId) {
    if (userId.isEmpty) return Stream.value(const []);
    return _firestore
        .collection(AppConstants.notificationsCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs
              .map((doc) => AppNotificationModel.fromMap(doc.id, doc.data()))
              .toList();
          notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return notifications.take(100).toList(growable: false);
        });
  }

  Future<void> markNotificationRead(
    String userId,
    String notificationId,
  ) async {
    if (userId.isEmpty || notificationId.isEmpty) return;
    try {
      final ref = _firestore
          .collection(AppConstants.notificationsCollection)
          .doc(notificationId);
      final doc = await ref.get();
      if (!doc.exists || doc.data()?['userId'] != userId) return;
      await ref.update({'read': true, 'readAt': FieldValue.serverTimestamp()});
    } on FirebaseException catch (e) {
      throw ServerException(
        message: e.message ?? 'Erro ao marcar aviso como lido',
      );
    }
  }

  Future<void> markChatNotificationsRead(String userId, String salaId) async {
    if (userId.isEmpty || salaId.isEmpty) return;
    try {
      final snapshot = await _firestore
          .collection(AppConstants.notificationsCollection)
          .where('userId', isEqualTo: userId)
          .get();
      final matchingDocs = snapshot.docs.where((doc) {
        final metadata = doc.data()['metadata'];
        return metadata is Map &&
            metadata['salaId'] == salaId &&
            doc.data()['read'] != true;
      }).toList();
      for (var offset = 0; offset < matchingDocs.length; offset += 450) {
        final end = (offset + 450).clamp(0, matchingDocs.length);
        final batch = _firestore.batch();
        for (final doc in matchingDocs.sublist(offset, end)) {
          batch.update(doc.reference, {
            'read': true,
            'readAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }
    } on FirebaseException catch (e) {
      throw ServerException(
        message: e.message ?? 'Erro ao marcar mensagens como lidas',
      );
    }
  }

  Future<void> markNotificationsRead(String userId) async {
    final snapshot = await _firestore
        .collection(AppConstants.notificationsCollection)
        .where('userId', isEqualTo: userId)
        .get();
    final unreadDocs = snapshot.docs
        .where((doc) => doc.data()['read'] != true)
        .toList();
    if (unreadDocs.isEmpty) return;
    for (var offset = 0; offset < unreadDocs.length; offset += 450) {
      final end = (offset + 450).clamp(0, unreadDocs.length);
      final batch = _firestore.batch();
      for (final doc in unreadDocs.sublist(offset, end)) {
        batch.update(doc.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  // ─── User Names (batch) ──────────────────────────────────────

  /// Obtém nome + email para uma lista de UIDs (batch).
  Future<Map<String, String>> getUserNames(List<String> uids) async {
    try {
      if (uids.isEmpty) return {};
      final uniqueUids = uids.toSet().toList();
      final result = <String, String>{};
      // Firestore 'in' query supports até 30 itens; fazemos batches
      for (int i = 0; i < uniqueUids.length; i += 30) {
        final batch = uniqueUids.sublist(
          i,
          i + 30 > uniqueUids.length ? uniqueUids.length : i + 30,
        );
        final snap = await _firestore
            .collection(AppConstants.usersCollection)
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        for (final doc in snap.docs) {
          final data = doc.data();
          result[doc.id] = (data['nome'] as String?) ?? 'Aluno';
        }
      }
      return result;
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao obter nomes');
    }
  }

  // ─── Agenda / Bookings ───────────────────────────────────────

  /// Obtém marcações de um aluno.
  /// Ordenação feita client-side para evitar necessidade de índice composto Firestore.
  Future<List<BookingModel>> getStudentBookings(String studentId) async {
    try {
      final snap = await _firestore
          .collection(AppConstants.agendaCollection)
          .where('studentId', isEqualTo: studentId)
          .get();
      final bookings = snap.docs
          .map((doc) => BookingModel.fromMap(doc.id, doc.data()))
          .toList();
      bookings.sort((a, b) => b.data.compareTo(a.data));
      return bookings;
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao obter agenda');
    }
  }

  /// Obtém marcações de um trainer (admin).
  /// Ordenação feita client-side para evitar necessidade de índice composto Firestore.
  Future<List<BookingModel>> getTrainerBookings(String trainerId) async {
    try {
      final snap = await _firestore
          .collection(AppConstants.agendaCollection)
          .where('trainerId', isEqualTo: trainerId)
          .get();
      final bookings = snap.docs
          .map((doc) => BookingModel.fromMap(doc.id, doc.data()))
          .toList();
      bookings.sort((a, b) => b.data.compareTo(a.data));
      return bookings;
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao obter agenda');
    }
  }

  /// Adiciona uma marcação.
  Future<void> addBooking(Map<String, dynamic> data) async {
    try {
      await _firestore.collection(AppConstants.agendaCollection).add(data);
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao guardar marcação');
    }
  }

  /// Atualiza uma marcação.
  Future<void> updateBooking(String id, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection(AppConstants.agendaCollection)
          .doc(id)
          .update(data);
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao atualizar marcação');
    }
  }

  /// Atualiza apenas o estado de uma marcação (conveniência).
  Future<void> updateBookingStatus(String id, String newStatus) async {
    return updateBooking(id, {'status': newStatus});
  }

  /// Stream de marcações de um aluno (ordenado client-side — sem índice composto).
  Stream<List<BookingModel>> watchStudentBookings(String studentId) {
    if (studentId.isEmpty) return Stream.value([]);
    return _firestore
        .collection(AppConstants.agendaCollection)
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => BookingModel.fromMap(doc.id, doc.data()))
              .toList();
          list.sort((a, b) => a.data.compareTo(b.data));
          return list;
        });
  }

  /// Stream de marcações confirmadas/pending do trainer (ordenado client-side — sem índice composto).
  Stream<List<BookingModel>> watchTrainerBookings(String trainerId) {
    if (trainerId.isEmpty) return Stream.value([]);
    return _firestore
        .collection(AppConstants.agendaCollection)
        .where('trainerId', isEqualTo: trainerId)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => BookingModel.fromMap(doc.id, doc.data()))
              .where((b) => b.isConfirmed || b.isPending)
              .toList();
          list.sort((a, b) => a.data.compareTo(b.data));
          return list;
        });
  }

  // ─── Grupos ──────────────────────────────────────────────────

  /// Stream dos grupos onde o utilizador é membro.
  Stream<List<GroupModel>> watchMyGroups(String userId) {
    if (userId.trim().isEmpty) {
      return Stream.value(const <GroupModel>[]);
    }
    return _firestore
        .collection(AppConstants.groupsCollection)
        .where('membros', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          final groups = snapshot.docs
              .map((doc) => GroupModel.fromMap(doc.id, doc.data()))
              .toList();
          groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return groups;
        });
  }

  /// Lê uma página de grupos administrativos com cursor por data.
  Future<FirestorePage<GroupModel>> getGroupsPage({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 25,
  }) async {
    try {
      final pageSize = limit.clamp(1, 100);
      Query<Map<String, dynamic>> query = _firestore
          .collection(AppConstants.groupsCollection)
          .limit(pageSize);
      if (startAfter != null) query = query.startAfterDocument(startAfter);
      final snapshot = await query.get();
      return FirestorePage(
        items: snapshot.docs
            .map((doc) => GroupModel.fromMap(doc.id, doc.data()))
            .toList(),
        cursor: snapshot.docs.isEmpty ? startAfter : snapshot.docs.last,
        hasMore: snapshot.docs.length == pageSize,
      );
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao listar grupos');
    }
  }

  /// Stream de todos os grupos para o admin.
  Stream<List<GroupModel>> watchAllGroups() {
    return _firestore
        .collection(AppConstants.groupsCollection)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          final groups = snapshot.docs
              .map((doc) => GroupModel.fromMap(doc.id, doc.data()))
              .toList();
          groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return groups;
        });
  }

  /// Obtém grupos onde o utilizador é membro.
  Future<List<GroupModel>> getMyGroups(String userId) async {
    try {
      final snap = await _firestore
          .collection(AppConstants.groupsCollection)
          .where('membros', arrayContains: userId)
          .get();
      final groups = snap.docs
          .map((doc) => GroupModel.fromMap(doc.id, doc.data()))
          .toList();
      groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return groups;
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao obter grupos');
    }
  }

  /// Obtém todos os grupos (admin).
  Future<List<GroupModel>> getAllGroups() async {
    try {
      final snap = await _firestore
          .collection(AppConstants.groupsCollection)
          .get();
      final groups = snap.docs
          .map((doc) => GroupModel.fromMap(doc.id, doc.data()))
          .toList();
      groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return groups;
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao listar grupos');
    }
  }

  /// Cria um novo grupo.
  Future<String> createGroup(Map<String, dynamic> data) async {
    try {
      final ref = await _firestore
          .collection(AppConstants.groupsCollection)
          .add(data);
      return ref.id;
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao criar grupo');
    }
  }

  /// Atualiza os dados de um grupo (admin).
  Future<void> updateGroup(String groupId, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection(AppConstants.groupsCollection)
          .doc(groupId)
          .update(data);
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao atualizar grupo');
    }
  }

  /// Envia mensagem para um grupo e atualiza o preview no documento pai.
  ///
  /// As duas escritas usam o mesmo batch. Assim, o listener do documento do
  /// grupo não consegue observar o preview antes de a mensagem existir na
  /// subcoleção — situação que fazia o contador/som perder a primeira mensagem.
  Future<void> sendGroupMessage(
    String groupId,
    Map<String, dynamic> data,
  ) async {
    try {
      final groupRef = _firestore
          .collection(AppConstants.groupsCollection)
          .doc(groupId);
      final messageRef = groupRef
          .collection(AppConstants.groupMessagesSubcollection)
          .doc();
      final timestamp = data['timestamp'] ?? DateTime.now();
      final batch = _firestore.batch();

      batch.set(groupRef, {
        'lastMessage': (data['texto'] as String?)?.isNotEmpty == true
            ? data['texto']
            : (data['attachmentUrl'] != null ? 'Imagem' : 'Mensagem de áudio'),
        'lastTimestamp': timestamp,
        'lastSenderId': data['remetenteId'] ?? '',
        'lastMessageId': messageRef.id,
      }, SetOptions(merge: true));
      batch.set(messageRef, data);
      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao enviar mensagem');
    }
  }

  /// Marca como lidas, para um utilizador, as mensagens visíveis do grupo.
  /// Usa um cursor por utilizador para não marcar as mensagens como lidas para
  /// os restantes participantes.
  Future<void> markGroupAsRead(
    String groupId,
    String userId,
    DateTime readAt,
  ) async {
    try {
      await _firestore
          .collection(AppConstants.groupsCollection)
          .doc(groupId)
          .update({'lastReadAtByUser.$userId': readAt});
    } on FirebaseException catch (e) {
      throw ServerException(
        message: e.message ?? 'Erro ao marcar grupo como lido',
      );
    }
  }

  /// Stream de mensagens de um grupo.
  Stream<List<MessageModel>> watchGroupMessages(String groupId) {
    return _firestore
        .collection(AppConstants.groupsCollection)
        .doc(groupId)
        .collection(AppConstants.groupMessagesSubcollection)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => MessageModel.fromMap(doc.id, doc.data()))
              .toList()
              .reversed
              .toList(),
        );
  }

  // ───────────────────── EXERCISES ─────────────────────

  /// Stream de todos os exercícios ou filtrado por grupo muscular.
  Stream<List<Map<String, dynamic>>> watchExercises({String? grupoMuscular}) {
    Query<Map<String, dynamic>> query = _firestore.collection(
      AppConstants.exercisesCollection,
    );
    if (grupoMuscular != null) {
      query = query.where('grupoMuscular', isEqualTo: grupoMuscular);
    }
    return query
        .orderBy('nome')
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            return data;
          }).toList(),
        );
  }

  /// Lista todos os exercícios ou filtra por grupo muscular.
  Future<List<Map<String, dynamic>>> getExercises({
    String? grupoMuscular,
  }) async {
    try {
      Query query = _firestore.collection(AppConstants.exercisesCollection);
      if (grupoMuscular != null) {
        query = query.where('grupoMuscular', isEqualTo: grupoMuscular);
      }
      final snapshot = await query.orderBy('nome').get();
      return snapshot.docs.map((doc) {
        final raw = doc.data();
        final data = Map<String, dynamic>.from(raw as Map? ?? {});
        data['id'] = doc.id;
        return data;
      }).toList();
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao listar exercícios');
    }
  }

  /// Stream do catálogo completo de exercícios.
  Stream<List<ExerciseCatalogModel>> watchExerciseCatalog({
    bool includeInactive = true,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection(
      AppConstants.exercisesCollection,
    );
    if (!includeInactive) {
      query = query.where('ativo', isEqualTo: true);
    }
    return query
        .orderBy('nome')
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ExerciseCatalogModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Cria um exercício manual no catálogo.
  Future<void> createExerciseCatalog(ExerciseCatalogModel exercise) async {
    try {
      await _firestore
          .collection(AppConstants.exercisesCollection)
          .doc(exercise.id.isEmpty ? null : exercise.id)
          .set(exercise.toMap(now: DateTime.now()));
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao criar exercício');
    }
  }

  /// Atualiza os dados editáveis de um exercício.
  Future<void> updateExerciseCatalog(ExerciseCatalogModel exercise) async {
    try {
      await _firestore
          .collection(AppConstants.exercisesCollection)
          .doc(exercise.id)
          .set(exercise.toMap(now: DateTime.now()), SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(
        message: e.message ?? 'Erro ao atualizar exercício',
      );
    }
  }

  /// Desativa o exercício sem quebrar planos que já o utilizam.
  Future<void> deactivateExerciseCatalog(String exerciseId) async {
    try {
      await _firestore
          .collection(AppConstants.exercisesCollection)
          .doc(exerciseId)
          .set({
            'ativo': false,
            'atualizadoEm': DateTime.now(),
          }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(
        message: e.message ?? 'Erro ao desativar exercício',
      );
    }
  }

  /// Importa o catálogo em lotes e usa IDs determinísticos para não duplicar.
  Future<void> importExerciseCatalog(
    List<ExerciseCatalogModel> exercises,
  ) async {
    try {
      for (var offset = 0; offset < exercises.length; offset += 450) {
        final end = (offset + 450).clamp(0, exercises.length);
        final batch = _firestore.batch();
        for (final exercise in exercises.sublist(offset, end)) {
          final documentId = _exerciseDocumentId(exercise);
          final reference = _firestore
              .collection(AppConstants.exercisesCollection)
              .doc(documentId);
          batch.set(
            reference,
            exercise.toMap(now: DateTime.now()),
            SetOptions(merge: true),
          );
        }
        await batch.commit();
      }
    } on FirebaseException catch (e) {
      throw ServerException(
        message: e.message ?? 'Erro ao importar exercícios',
      );
    }
  }

  String _exerciseDocumentId(ExerciseCatalogModel exercise) {
    final sourceId = exercise.origemId?.trim();
    if (sourceId != null && sourceId.isNotEmpty) {
      return sourceId.replaceAll('/', '_');
    }
    if (exercise.id.trim().isNotEmpty) return exercise.id.trim();
    return _firestore.collection(AppConstants.exercisesCollection).doc().id;
  }
}
