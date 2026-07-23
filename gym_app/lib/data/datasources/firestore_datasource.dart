import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/exceptions.dart';
import '../models/user_model.dart';
import '../models/diary_model.dart';
import '../models/nutrition_plan_model.dart';
import '../models/workout_plan_model.dart';
import '../models/message_model.dart';
import '../models/progress_model.dart';
import '../models/food_model.dart';
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
          message: e.message ?? 'Erro ao atualizar utilizador');
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
          message: e.message ?? 'Erro ao obter registo diário');
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
      String userId, String date, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.diarySubcollection)
          .doc(date)
          .set(data, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(
          message: e.message ?? 'Erro ao guardar registo diário');
    }
  }

  /// Incrementa um campo numérico do diário.
  Future<void> incrementDiaryField(
      String userId, String date, String field, num value) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.diarySubcollection)
          .doc(date)
          .set({field: FieldValue.increment(value)}, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(
          message: e.message ?? 'Erro ao incrementar campo');
    }
  }

  /// Adiciona uma refeição à lista no diário.
  Future<void> addMealToDiary(
      String userId, String date, Map<String, dynamic> mealMap) async {
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
      throw ServerException(
          message: e.message ?? 'Erro ao adicionar refeição');
    }
  }

  /// Obtém histórico de diários (para progresso).
  Future<List<DiaryModel>> getDiaryHistory(String userId,
      {int limit = 90}) async {
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
      throw ServerException(
          message: e.message ?? 'Erro ao obter histórico');
    }
  }

  // ───────────────────── NUTRITION PLAN ─────────────────────

  /// Obtém plano nutricional para um dia da semana.
  Future<NutritionPlanModel?> getNutritionPlan(
      String userId, String diaSemana) async {
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
          message: e.message ?? 'Erro ao obter plano nutricional');
    }
  }

  /// Guarda plano nutricional.
  Future<void> setNutritionPlan(
      String userId, String diaSemana, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.nutritionPlanSubcollection)
          .doc(diaSemana)
          .set(data, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(
          message: e.message ?? 'Erro ao guardar plano nutricional');
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
          message: e.message ?? 'Erro ao obter plano de treino');
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
          message: e.message ?? 'Erro ao listar planos de treino');
    }
  }

  /// Guarda plano de treino.
  Future<void> setWorkoutPlan(
      String userId, String nome, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.workoutPlanSubcollection)
          .doc(nome)
          .set(data, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(
          message: e.message ?? 'Erro ao guardar plano de treino');
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
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Envia uma mensagem.
  Future<void> sendMessage(
      String salaId, Map<String, dynamic> messageMap) async {
    try {
      await _firestore
          .collection(AppConstants.chatCollection)
          .doc(salaId)
          .collection(AppConstants.messagesSubcollection)
          .add(messageMap);
    } on FirebaseException catch (e) {
      throw ServerException(
          message: e.message ?? 'Erro ao enviar mensagem');
    }
  }

  // ───────────────────── PROGRESS ─────────────────────

  /// Obtém registos de progresso.
  Future<List<ProgressModel>> getProgressHistory(String userId,
      {int limit = 50}) async {
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
      throw ServerException(
          message: e.message ?? 'Erro ao obter progresso');
    }
  }

  /// Adiciona registo de progresso.
  Future<void> addProgressEntry(
      String userId, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.progressSubcollection)
          .add(data);
    } on FirebaseException catch (e) {
      throw ServerException(
          message: e.message ?? 'Erro ao guardar progresso');
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
          message: e.message ?? 'Erro ao pesquisar alimentos');
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

  // ───────────────────── EXERCISES ─────────────────────

  /// Lista todos os exercícios ou filtra por grupo muscular.
  Future<List<Map<String, dynamic>>> getExercises({String? grupoMuscular}) async {
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
      throw ServerException(
          message: e.message ?? 'Erro ao listar exercícios');
    }
  }
}
