import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/exceptions.dart';
import '../models/user_model.dart';
import '../models/diary_model.dart';
import '../models/nutrition_plan_model.dart';
import '../models/workout_plan_model.dart';
import '../models/message_model.dart';
import '../models/progress_model.dart';
import '../models/food_model.dart';
import '../models/workout_log_model.dart';
import '../models/payment_model.dart';
import '../models/booking_model.dart';
import '../models/group_model.dart';
import '../../core/config/app_constants.dart';

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
          .limit(limit)
          .get();
      return snapshot.docs
          .map((doc) => DiaryModel.fromMap(doc.id, userId, doc.data()))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao obter histórico');
    }
  }

  // ───────────────────── NUTRITION PLAN ─────────────────────

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

  /// Stream de mensagens da sala de chat.
  Stream<List<MessageModel>> messagesStream(String salaId) {
    return _firestore
        .collection(AppConstants.chatCollection)
        .doc(salaId)
        .collection(AppConstants.messagesSubcollection)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MessageModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Envia a mensagem e atualiza a sala numa única operação atómica.
  ///
  /// O admin observa o documento pai para atualizar a lista de conversas.
  /// Se estas escritas fossem separadas, o listener podia ler a sala antes
  /// de a mensagem existir na subcoleção e perder a notificação sonora.
  Future<void> sendMessage(
    String salaId,
    Map<String, dynamic> messageMap,
  ) async {
    try {
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
        'lastMessage': (messageMap['texto'] as String?)?.isNotEmpty == true
            ? messageMap['texto']
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
    bool isTyping,
  ) async {
    try {
      if (isTyping) {
        await _firestore
            .collection(AppConstants.chatCollection)
            .doc(salaId)
            .set({
              'typing': userId,
              'typingAt': DateTime.now(),
            }, SetOptions(merge: true));
      } else {
        // Usa set-merge com '' em vez de FieldValue.delete(),
        // para evitar problemas de permissões no Firestore.
        await _firestore
            .collection(AppConstants.chatCollection)
            .doc(salaId)
            .set({'typing': ''}, SetOptions(merge: true));
      }
    } on FirebaseException catch (_) {
      // Falha silenciosa — o indicador de digitação não é crítico
    }
  }

  // ───────────────────── PROGRESS ─────────────────────

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
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.progressSubcollection)
          .add(data);
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao guardar progresso');
    }
  }

  // ───────────────────── FOODS ─────────────────────

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
      final lowerQuery = query.toLowerCase();
      return allFoods
          .where((f) => f.nome.toLowerCase().contains(lowerQuery))
          .toList();
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

  // ───────────────────── WORKOUT LOGS ─────────────────────

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
      return WorkoutLogModel.fromMap(doc.id, userId, doc.data()!);
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

  /// Obtém pagamentos de um utilizador.
  Future<List<PaymentModel>> getPayments(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.paymentsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('data', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => PaymentModel.fromMap(doc.id, doc.data()))
          .toList();
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
        })
        .handleError((_) => <BookingModel>[]);
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
        })
        .handleError((_) => <BookingModel>[]);
  }

  // ─── Grupos ──────────────────────────────────────────────────

  /// Obtém grupos onde o utilizador é membro.
  Future<List<GroupModel>> getMyGroups(String userId) async {
    try {
      final snap = await _firestore
          .collection(AppConstants.groupsCollection)
          .where('membros', arrayContains: userId)
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs
          .map((doc) => GroupModel.fromMap(doc.id, doc.data()))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao obter grupos');
    }
  }

  /// Obtém todos os grupos (admin).
  Future<List<GroupModel>> getAllGroups() async {
    try {
      final snap = await _firestore
          .collection(AppConstants.groupsCollection)
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs
          .map((doc) => GroupModel.fromMap(doc.id, doc.data()))
          .toList();
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

      batch.set(
        groupRef,
        {
          'lastMessage': (data['texto'] as String?)?.isNotEmpty == true
              ? data['texto']
              : 'Mensagem de áudio',
          'lastTimestamp': timestamp,
          'lastSenderId': data['remetenteId'] ?? '',
          'lastMessageId': messageRef.id,
        },
        SetOptions(merge: true),
      );
      batch.set(messageRef, data);
      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? 'Erro ao enviar mensagem');
    }
  }

  /// Stream de mensagens de um grupo.
  Stream<List<MessageModel>> watchGroupMessages(String groupId) {
    return _firestore
        .collection(AppConstants.groupsCollection)
        .doc(groupId)
        .collection(AppConstants.groupMessagesSubcollection)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => MessageModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  // ───────────────────── EXERCISES ─────────────────────

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
}
