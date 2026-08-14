import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import '../../core/utils/connectivity_service.dart';
import '../../core/services/fcm_service.dart';
import '../../data/datasources/auth_datasource.dart';
import '../../data/datasources/firestore_datasource.dart';
import '../../data/datasources/storage_datasource.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/payment_model.dart';
import '../../data/repositories/progress_video_repository.dart';
import '../../data/models/message_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/diary_repository.dart';
import '../../data/repositories/nutrition_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/workout_repository.dart';
import '../../data/repositories/workout_log_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/booking_repository.dart';
import '../../data/repositories/group_repository.dart';
import '../../features/auth/providers/auth_provider.dart';

// ──────────── SERVICES ────────────

/// Provider para ConnectivityService (singleton).
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Tracks whether the aluno is currently inside a chat screen.
/// Used to suppress notification sounds when the user is actively chatting.
final isAlunoInChatProvider = StateProvider<bool>((ref) => false);

/// Tracks whether the admin is actively viewing an embedded chat.
/// The admin chat popover and the client-detail chat share this state so
/// unread updates never produce a sound over the conversation being viewed.
final isAdminInChatProvider = StateProvider<bool>((ref) => false);

/// Provider para FCMService (singleton).
final fcmServiceProvider = Provider<FCMService>((ref) {
  final userRepo = ref.watch(userRepositoryProvider);
  final service = FCMService(userRepository: userRepo);
  ref.onDispose(() => service.dispose());
  return service;
});

/// Stream de estado de conectividade.
final connectivityStreamProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.onConnectivityChanged;
});

// ──────────── DATASOURCES ────────────

final authDataSourceProvider = Provider<AuthDataSource>((ref) {
  return AuthDataSource();
});

final firestoreDataSourceProvider = Provider<FirestoreDataSource>((ref) {
  return FirestoreDataSource();
});

final storageDataSourceProvider = Provider<StorageDataSource>((ref) {
  return StorageDataSource();
});

// ──────────── REPOSITORIES ────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    authDataSource: ref.watch(authDataSourceProvider),
    connectivityService: ref.watch(connectivityServiceProvider),
    paymentRepository: ref.watch(paymentRepositoryProvider),
  );
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(
    firestoreDataSource: ref.watch(firestoreDataSourceProvider),
  );
});

final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  return DiaryRepository(
    firestoreDataSource: ref.watch(firestoreDataSourceProvider),
    connectivityService: ref.watch(connectivityServiceProvider),
  );
});

final nutritionRepositoryProvider = Provider<NutritionRepository>((ref) {
  return NutritionRepository(
    firestoreDataSource: ref.watch(firestoreDataSourceProvider),
  );
});

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepository(
    firestoreDataSource: ref.watch(firestoreDataSourceProvider),
  );
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    firestoreDataSource: ref.watch(firestoreDataSourceProvider),
    connectivityService: ref.watch(connectivityServiceProvider),
  );
});

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository(
    firestoreDataSource: ref.watch(firestoreDataSourceProvider),
    storageDataSource: ref.watch(storageDataSourceProvider),
  );
});

final workoutLogRepositoryProvider = Provider<WorkoutLogRepository>((ref) {
  return WorkoutLogRepository(
    firestoreDataSource: ref.watch(firestoreDataSourceProvider),
  );
});

final progressVideoRepositoryProvider = Provider<ProgressVideoRepository>((
  ref,
) {
  return ProgressVideoRepository(
    firestore: ref.watch(firestoreDataSourceProvider),
    storage: ref.watch(storageDataSourceProvider),
  );
});

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(
    firestoreDataSource: ref.watch(firestoreDataSourceProvider),
  );
});

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepository(
    firestoreDataSource: ref.watch(firestoreDataSourceProvider),
  );
});

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepository(
    firestoreDataSource: ref.watch(firestoreDataSourceProvider),
  );
});

/// Provider que observa o género do utilizador atual a partir do Firestore.
/// Atualiza automaticamente quando o campo 'genero' muda, propagando
/// a alteração para o tema sem necessidade de reiniciar a app.
final currentUserGeneroProvider = StreamProvider<String?>((ref) {
  // Só o UID identifica a subscrição. Alterações ao perfil (nome, som,
  // pagamentos, etc.) não devem cancelar e recriar este listener.
  final userId = ref.watch(authProvider.select((s) => s.user?.uid));
  if (userId == null) return const Stream.empty();
  return ref
      .read(userRepositoryProvider)
      .userStream(userId)
      .map((u) => u.genero);
});

/// Stream do utilizador autenticado, usado para sincronizar preferências
/// (ex: som de notificação) logo após o login, sem depender de o utilizador
/// abrir as Definições/Perfil. Stream vazio sem sessão — evita queries
/// desnecessárias no ecrã de login.
final currentUserStreamProvider = StreamProvider<UserModel?>((ref) {
  final userId = ref.watch(authProvider.select((s) => s.user?.uid ?? ''));
  if (userId.isEmpty) return const Stream.empty();
  return ref
      .read(userRepositoryProvider)
      .userStream(userId)
      .map<UserModel?>((u) => u);
});

// ──────────── AGENDA / BOOKINGS STREAMS ────────────

/// Stream de marcações do aluno (agenda).
/// Provider family estável — NUNCA criar StreamProvider inline no build(),
/// pois cada rebuild recria o listener Firestore causando loop infinito.
final studentBookingsStreamProvider =
    StreamProvider.family<List<BookingModel>, String>((ref, studentId) {
      if (studentId.isEmpty) return Stream.value([]);
      return ref
          .read(bookingRepositoryProvider)
          .watchStudentBookings(studentId);
    });

/// Stream de marcações do trainer (para deteção de conflitos).
/// Provider family estável — NUNCA criar StreamProvider inline no build().
final trainerBookingsStreamProvider =
    StreamProvider.family<List<BookingModel>, String>((ref, trainerId) {
      if (trainerId.isEmpty) return Stream.value([]);
      return ref
          .read(bookingRepositoryProvider)
          .watchTrainerBookings(trainerId);
    });

/// Stream de pagamentos do aluno.
/// Provider family estável — NUNCA criar StreamProvider inline no build().
final paymentsStreamProvider =
    StreamProvider.family<List<PaymentModel>, String>((ref, userId) {
      if (userId.isEmpty) return Stream.value([]);
      return ref.read(paymentRepositoryProvider).watchPayments(userId);
    });

/// Número de cobranças que requerem atenção do aluno.
/// Usa o mesmo stream estável do Perfil, sem abrir um segundo listener.
final paymentNotificationCountProvider = Provider.family<int, String>((
  ref,
  userId,
) {
  if (userId.isEmpty) return 0;
  final paymentsAsync = ref.watch(paymentsStreamProvider(userId));
  return paymentsAsync.maybeWhen(
    data: (payments) => payments
        .where((payment) =>
            !payment.isPaid &&
            !payment.isCancelled &&
            payment.status != 'refunded')
        .length,
    orElse: () => 0,
  );
});

/// Stream estável do estado "a escrever" de uma conversa direta.
/// O StreamBuilder recebe sempre a mesma instância para o mesmo par de IDs;
/// não criar este stream diretamente dentro de build().
final typingStreamProvider = Provider.family<Stream<String?>, ({
  String salaId,
  String userId,
})>((ref, args) {
  if (args.salaId.isEmpty || args.userId.isEmpty) return const Stream.empty();
  return ref
      .read(chatRepositoryProvider)
      .typingStream(args.salaId, args.userId);
});

/// Stream de mensagens de um grupo.
/// Provider family estável — NUNCA criar StreamProvider inline no build().
final groupMessagesStreamProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, groupId) {
      if (groupId.isEmpty) return Stream.value([]);
      return ref.read(groupRepositoryProvider).watchMessages(groupId);
    });
