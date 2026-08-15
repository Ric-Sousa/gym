import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/config/student_theme.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/config/app_strings.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../data/models/app_notification_model.dart';
import '../../../../data/models/diary_model.dart';
import '../../../../data/models/workout_plan_model.dart';
import '../../../../data/models/nutrition_plan_model.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../shared/providers/global_providers.dart';
import '../../../../shared/providers/chat_notification_providers.dart';
import '../../../../shared/widgets/star_rating.dart';
import '../../../aluno/agenda/screens/calendar_screen.dart';
import '../../../../shared/widgets/offline_banner.dart';
import '../../../../shared/widgets/app_design_system.dart';

/// Provider que monitora mensagens nao lidas do aluno para o contador visual.
/// A reprodução sonora usa os providers estáveis de
/// `chat_notification_providers.dart`.
/// Observa as subcoleções de cada sala; o documento pai é atualizado antes da
/// mensagem e, por isso, não é uma fonte suficiente para detetar novas mensagens.
final alunoUnreadCountProvider = StreamProvider.family<int, String>((
  ref,
  userId,
) {
  if (userId.isEmpty) return Stream.value(0);

  final firestore = FirebaseFirestore.instance;
  final controller = StreamController<int>();
  final counts = <String, int>{};
  final initializedRooms = <String>{};
  final roomSubscriptions =
      <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? roomsSubscription;
  var activeRoomIds = <String>{};
  var initialRoomsDiscovered = false;
  var initialValueEmitted = false;

  void emitTotal() {
    if (!controller.isClosed) {
      controller.add(
        counts.values.fold<int>(0, (total, value) => total + value),
      );
    }
  }

  void emitWhenReady() {
    if (!initialRoomsDiscovered ||
        !activeRoomIds.every(initializedRooms.contains)) {
      return;
    }
    initialValueEmitted = true;
    emitTotal();
  }

  void watchRoom(String roomId) {
    if (roomSubscriptions.containsKey(roomId)) return;
    roomSubscriptions[roomId] = firestore
        .collection(AppConstants.chatCollection)
        .doc(roomId)
        .collection(AppConstants.messagesSubcollection)
        .snapshots()
        .listen(
          (snap) {
            initializedRooms.add(roomId);
            counts[roomId] = snap.docs.where((message) {
              final data = message.data();
              return data['lida'] != true && data['remetenteId'] != userId;
            }).length;
            if (initialValueEmitted) {
              emitTotal();
            } else {
              emitWhenReady();
            }
          },
          onError: (_) {
            initializedRooms.add(roomId);
            counts[roomId] = 0;
            if (initialValueEmitted) {
              emitTotal();
            } else {
              emitWhenReady();
            }
          },
        );
  }

  roomsSubscription = firestore
      .collection(AppConstants.chatCollection)
      .where(FieldPath.documentId, isGreaterThanOrEqualTo: 'chat_')
      .where(FieldPath.documentId, isLessThanOrEqualTo: 'chat_\uf8ff')
      .snapshots()
      .listen(
        (snap) {
          final currentIds = snap.docs
              .where((doc) => doc.id.contains(userId))
              .map((doc) => doc.id)
              .toSet();
          activeRoomIds = currentIds;

          for (final oldId in roomSubscriptions.keys.toList()) {
            if (!currentIds.contains(oldId)) {
              roomSubscriptions.remove(oldId)?.cancel();
              counts.remove(oldId);
              initializedRooms.remove(oldId);
            }
          }
          for (final roomId in currentIds) {
            watchRoom(roomId);
          }

          if (!initialRoomsDiscovered) {
            initialRoomsDiscovered = true;
            if (currentIds.isEmpty) {
              initialValueEmitted = true;
              emitTotal();
            } else {
              emitWhenReady();
            }
          } else if (initialValueEmitted) {
            emitTotal();
          }
        },
        onError: (_) {
          if (!initialRoomsDiscovered) {
            initialRoomsDiscovered = true;
            initialValueEmitted = true;
          }
          emitTotal();
        },
      );

  ref.onDispose(() {
    roomsSubscription?.cancel();
    for (final subscription in roomSubscriptions.values) {
      subscription.cancel();
    }
    controller.close();
  });

  return controller.stream;
});

/// Conta mensagens novas dos grupos do aluno.
/// Cada subcoleção mantém o seu listener, para que uma mensagem nova altere
/// o contador mesmo quando o documento pai do grupo não muda.
final alunoGroupUnreadCountProvider = StreamProvider.family<int, String>((
  ref,
  userId,
) {
  if (userId.isEmpty) return Stream.value(0);

  final firestore = FirebaseFirestore.instance;
  final controller = StreamController<int>();
  final counts = <String, int>{};
  final initializedGroups = <String>{};
  var activeGroupIds = <String>{};
  final messageSubscriptions =
      <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? groupsSubscription;

  void emitTotal() {
    if (!controller.isClosed) {
      controller.add(
        counts.values.fold<int>(0, (total, value) => total + value),
      );
    }
  }

  void watchGroup(String groupId) {
    if (messageSubscriptions.containsKey(groupId)) return;
    messageSubscriptions[groupId] = firestore
        .collection(AppConstants.groupsCollection)
        .doc(groupId)
        .collection(AppConstants.groupMessagesSubcollection)
        .snapshots()
        .listen(
          (snap) {
            initializedGroups.add(groupId);
            counts[groupId] = snap.docs.where((message) {
              final data = message.data();
              return data['lida'] != true && data['remetenteId'] != userId;
            }).length;
            if (activeGroupIds.every(initializedGroups.contains)) {
              emitTotal();
            }
          },
          onError: (_) {
            initializedGroups.add(groupId);
            counts[groupId] = 0;
            emitTotal();
          },
        );
  }

  groupsSubscription = firestore
      .collection(AppConstants.groupsCollection)
      .where('membros', arrayContains: userId)
      .snapshots()
      .listen((snap) {
        final currentIds = snap.docs.map((doc) => doc.id).toSet();
        activeGroupIds = currentIds;
        for (final oldId in messageSubscriptions.keys.toList()) {
          if (!currentIds.contains(oldId)) {
            messageSubscriptions.remove(oldId)?.cancel();
            counts.remove(oldId);
          }
        }
        initializedGroups.removeWhere((id) => !currentIds.contains(id));
        for (final groupId in currentIds) {
          watchGroup(groupId);
        }
        // Só emite depois de todos os grupos existentes terem entregue a sua
        // primeira fotografia. Assim o contador inicial não parece uma mensagem
        // nova quando o Home é montado.
        if (currentIds.isEmpty ||
            currentIds.every(initializedGroups.contains)) {
          emitTotal();
        }
      }, onError: (_) => emitTotal());

  ref.onDispose(() {
    groupsSubscription?.cancel();
    for (final subscription in messageSubscriptions.values) {
      subscription.cancel();
    }
    controller.close();
  });

  return controller.stream;
});

/// Provider do plano de treino de hoje (se existir).
final todayWorkoutPlanProvider =
    StreamProvider.family<WorkoutDay?, String>((ref, userId) {
  final weekday = DateTime.now().weekday - 1;
  final diaSemana = AppStrings.daysOfWeek[weekday];
  return ref.read(workoutRepositoryProvider).watchAllPlans(userId).map((plans) {
    for (final plan in plans) {
      final workout = plan.getWorkoutForDay(diaSemana);
      if (workout != null && workout.exercicios.isNotEmpty) return workout;
    }
    return null;
  });
});

/// Provider do histórico semanal (últimos 7 dias).
final weeklyHistoryProvider =
    StreamProvider.family<List<DiaryModel>, String>((ref, userId) {
  return ref.read(diaryRepositoryProvider).watchHistory(userId, limit: 7).map(
    (history) {
      final sorted = [...history];
      sorted.sort((a, b) => a.data.compareTo(b.data));
      return sorted;
    },
  );
});

final todayDateProvider = Provider<String>((ref) {
  return DateFormat(AppConstants.dateFormat).format(DateTime.now());
});

/// Meta de água do plano nutricional do dia atual.
final todayNutritionPlanProvider =
    StreamProvider.family<NutritionPlanModel?, String>((ref, userId) {
  final diaSemana = AppStrings.daysOfWeek[DateTime.now().weekday - 1];
  return ref.read(nutritionRepositoryProvider).watchPlan(userId, diaSemana);
});

final todayDiaryProvider = StreamProvider.family<DiaryModel?, String>((
  ref,
  userId,
) {
  final repo = ref.watch(diaryRepositoryProvider);
  final today = DateFormat(AppConstants.dateFormat).format(DateTime.now());
  return repo.diaryEntryStream(userId, today);
});

/// Provider de todos os planos de treino (para cruzar com o grafico semanal).
final weeklyWorkoutPlansProvider =
    StreamProvider.family<List<WorkoutPlanModel>, String>((ref, userId) {
  return ref.read(workoutRepositoryProvider).watchAllPlans(userId);
});

final ensureDiaryProvider = FutureProvider.family<void, String>((
  ref,
  userId,
) async {
  final today = DateFormat(AppConstants.dateFormat).format(DateTime.now());
  return ref.read(diaryRepositoryProvider).ensureDiaryExists(userId, today);
});

/// Dashboard do aluno — Kinetic Dark + Glassmorphism (Stitch).
class AlunoHomeScreen extends ConsumerStatefulWidget {
  final ValueChanged<int>? onNavigate;

  const AlunoHomeScreen({super.key, this.onNavigate});

  @override
  ConsumerState<AlunoHomeScreen> createState() => _AlunoHomeScreenState();
}

class _AlunoHomeScreenState extends ConsumerState<AlunoHomeScreen> {
  final LayerLink _notificationLayerLink = LayerLink();
  OverlayEntry? _notificationOverlay;

  void _closeNotificationOverlay() {
    _notificationOverlay?.remove();
    _notificationOverlay = null;
  }

  @override
  void dispose() {
    _closeNotificationOverlay();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authProvider);
      final userId = authState.user?.uid ?? '';
      if (userId.isNotEmpty) ref.read(ensureDiaryProvider(userId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userId = authState.user?.uid ?? '';
    final isOffline = ref.watch(connectivityStreamProvider).value ?? false;
    final paymentNotificationCount = ref.watch(
      paymentNotificationCountProvider(userId),
    );

    // O som reage a documentos adicionados, não a alterações de contador.
    // Assim a primeira mensagem e mensagens consecutivas com o mesmo horário
    // são tratadas exatamente uma vez.
    ref.listen(stableAlunoChatNotificationProvider(userId), (_, next) {
      next.whenData((_) => _playIncomingSound());
    });
    ref.listen(stableAlunoGroupNotificationProvider(userId), (_, next) {
      next.whenData((_) => _playIncomingSound());
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(userId, paymentNotificationCount),
      body: Column(
        children: [
          OfflineBanner(isOffline: isOffline),
          Expanded(child: _buildDiaryContent(isOffline)),
        ],
      ),
    );
  }

  void _playIncomingSound() {
    if (!mounted || ref.read(isAlunoInChatProvider)) return;
    if (!(ref.read(authProvider).user?.soundEnabled ?? true)) return;
    SoundService().playNotificationChime();
  }

  void _showPaymentNotifications(BuildContext context, String userId) {
    final payments = ref
        .read(paymentsStreamProvider(userId))
        .asData
        ?.value
        .where((payment) =>
            !payment.isPaid &&
            !payment.isCancelled &&
            payment.status != 'refunded')
        .toList() ??
        [];
    final notifications = ref
            .read(notificationsStreamProvider(userId))
            .asData
            ?.value ??
        [];
    unawaited(
      ref.read(notificationRepositoryProvider).markAllAsRead(userId),
    );

    if (_notificationOverlay != null) {
      _closeNotificationOverlay();
      return;
    }

    final overlay = Overlay.of(context);
    late OverlayEntry notificationEntry;

    notificationEntry = OverlayEntry(
      builder: (dialogContext) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closeNotificationOverlay,
              child: const SizedBox.expand(),
            ),
          ),
          CompositedTransformFollower(
            link: _notificationLayerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(0, 10),
            child: Material(
              color: AppColors.surface,
              elevation: 8,
              shadowColor: Colors.black.withValues(alpha: 0.18),
              surfaceTintColor: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: (MediaQuery.sizeOf(dialogContext).width - 24)
                .clamp(280.0, 400.0)
                .toDouble(),
            maxWidth: (MediaQuery.sizeOf(dialogContext).width - 24)
                .clamp(280.0, 400.0)
                .toDouble(),
            maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.78,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: payments.isEmpty && notifications.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 34),
                  child: Column(
                    children: [
                      Icon(
                        Icons.mark_email_read_outlined,
                        color: AppColors.textSecondary,
                        size: 34,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Não tens avisos pendentes.',
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: StudentThemeColors.of(context)
                                .primary
                                .withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.notifications_none_rounded,
                            color: StudentThemeColors.of(context).primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Avisos',
                            style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _closeNotificationOverlay,
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Fechar',
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Toca num aviso para abrir a área correspondente.',
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...notifications.map(
                      (notification) => ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        onTap: () => _openNotification(dialogContext, notification),
                        tileColor: AppColors.surfaceHigh.withValues(alpha: 0.72),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: StudentThemeColors.of(context)
                              .primaryContainer,
                          child: Icon(
                            Icons.notifications_outlined,
                            color: StudentThemeColors.of(context).primary,
                          ),
                        ),
                        title: Text(
                          notification.title,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          notification.body,
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    if (payments.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Pagamentos pendentes',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    ...payments.map(
                      (payment) => ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        onTap: () {
                          _closeNotificationOverlay();
                          widget.onNavigate?.call(5);
                        },
                        tileColor: AppColors.surfaceHigh.withValues(alpha: 0.72),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: StudentThemeColors.of(context)
                              .primaryContainer,
                          child: Icon(
                            Icons.payment_outlined,
                            color: StudentThemeColors.of(context).primary,
                          ),
                        ),
                        title: Text(
                          payment.descricao ?? payment.tipoMensalidadeLabel,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          '${payment.tipoMensalidadeLabel} · ${payment.valorFormatado}',
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
          ),
        ),
      ),
      ),
    ],
  ),
    );

    _notificationOverlay = notificationEntry;
    overlay.insert(notificationEntry);
  }

  void _openNotification(
    BuildContext dialogContext,
    AppNotificationModel notification,
  ) {
    _closeNotificationOverlay();
    final destination = _notificationDestination(
      action: notification.action,
      type: notification.type,
    );
    if (destination != null) widget.onNavigate?.call(destination);
  }

  int? _notificationDestination({String? action, required String type}) {
    if (action == 'payment' ||
        action == 'payment_recovery' ||
        type.startsWith('payment_')) {
      return 5; // Perfil
    }
    if (action == 'agenda' || type == 'booking_update') return 3;
    if (action == 'chat' || type == 'chat') return 4;
    if (action == 'profile' || type == 'progress_request') return 5;
    return null;
  }

  PreferredSizeWidget _buildAppBar(
    String userId,
    int paymentNotificationCount,
  ) {
    final authState = ref.watch(authProvider);
    final nome = authState.user?.nome ?? 'Aluno';
    final foto = authState.user?.fotoPerfil;

    return AppBar(
      backgroundColor: AppColors.surfaceLow.withValues(alpha: 0.8),
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                border: Border.all(
                  color: StudentThemeColors.of(
                    context,
                  ).primaryFixed.withValues(alpha: 0.3),
                  width: 2,
                ),
                shape: BoxShape.circle,
              ),
              child: foto != null
                  ? Image.network(foto, fit: BoxFit.cover)
                  : Center(
                      child: Text(
                        nome.isNotEmpty ? nome[0].toUpperCase() : '?',
                        style: GoogleFonts.montserrat(
                          color: StudentThemeColors.of(context).primaryFixed,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Bem-vindo de volta,',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                Text(
                  'Olá, $nome!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.montserrat(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        CompositedTransformTarget(
          link: _notificationLayerLink,
          child: IconButton(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.notifications_outlined,
                color: StudentThemeColors.of(context).primaryFixed,
                size: 22,
              ),
              if (paymentNotificationCount > 0)
                Positioned(
                  top: -8,
                  right: -9,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 17),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.surfaceLow,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      paymentNotificationCount > 99
                          ? '99+'
                          : '$paymentNotificationCount',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          tooltip: 'Notificações de pagamentos',
          onPressed: () => _showPaymentNotifications(context, userId),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildDiaryContent(bool isOffline) {
    final authState = ref.watch(authProvider);
    final userId = authState.user?.uid ?? '';
    final todayDiary = ref.watch(todayDiaryProvider(userId));
    return todayDiary.when(
      data: (diary) => diary == null
          ? Center(
              child: CircularProgressIndicator(
                color: StudentThemeColors.of(context).primary,
              ),
            )
          : _buildDashboard(userId, diary, isOffline),
      loading: () => Center(
        child: CircularProgressIndicator(
          color: StudentThemeColors.of(context).primary,
        ),
      ),
      error: (_, __) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Erro ao carregar dados',
              style: GoogleFonts.inter(color: AppColors.textSecondary),
            ),
            ElevatedButton(
              onPressed: () => ref.invalidate(todayDiaryProvider(userId)),
              child: const Text(AppStrings.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(String userId, DiaryModel diary, bool isOffline) {
    final nutritionPlanAsync = ref.watch(todayNutritionPlanProvider(userId));
    final metaAgua =
        nutritionPlanAsync.value?.metaAgua ??
        AppConstants.dailyWaterGoalMl.toDouble();
    final safeMetaAgua = metaAgua > 0
        ? metaAgua
        : AppConstants.dailyWaterGoalMl.toDouble();
    final waterPct = (diary.agua / safeMetaAgua).clamp(0.0, 1.0);
    final nome = ref.read(authProvider).user?.nome.split(' ').first ?? 'Aluno';
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(todayDiaryProvider(userId));
        ref.invalidate(weeklyHistoryProvider(userId));
        ref.invalidate(todayWorkoutPlanProvider(userId));
        ref.invalidate(weeklyWorkoutPlansProvider(userId));
      },
      color: StudentThemeColors.of(context).primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 42),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppPageIntro(
              eyebrow: DateFormat('EEEE, d MMMM', 'pt').format(DateTime.now()),
              title: 'O teu foco, $nome',
              subtitle:
                  'Um passo consistente hoje vale mais do que a perfeição amanhã.',
            ),
            const SizedBox(height: AppDesignTokens.sectionGap),
            _buildHeroCard(userId),
            const SizedBox(height: AppDesignTokens.pageGap),
            _buildBentoGrid(diary, waterPct, safeMetaAgua, isOffline, userId),
            const SizedBox(height: AppDesignTokens.pageGap),
            _buildWeeklyActivity(userId),
            const SizedBox(height: AppDesignTokens.pageGap),
            _buildUpcomingSessions(userId),
            const SizedBox(height: AppDesignTokens.pageGap),
            _buildBottomSection(userId, diary),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HERO SESSION CARD
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHeroCard(String userId) {
    final workoutAsync = ref.watch(todayWorkoutPlanProvider(userId));

    return workoutAsync.when(
      data: (todayWorkout) {
        final hasWorkout =
            todayWorkout != null && todayWorkout.exercicios.isNotEmpty;
        final workoutName = hasWorkout
            ? todayWorkout.foco.isNotEmpty
                  ? todayWorkout.foco.toUpperCase()
                  : 'TREINO DE HOJE'
            : null;
        final exerciseCount = hasWorkout ? todayWorkout.exercicios.length : 0;
        final compact = MediaQuery.sizeOf(context).width < 380;

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.outline.withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: StudentThemeColors.of(
                    context,
                  ).primary.withValues(alpha: 0.15),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border(
                  left: BorderSide(
                    color: hasWorkout
                        ? StudentThemeColors.of(context).primaryFixed
                        : AppColors.onSurfaceVariant,
                    width: 4,
                  ),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (hasWorkout
                                      ? StudentThemeColors.of(
                                          context,
                                        ).primaryFixed
                                      : AppColors.onSurfaceVariant)
                                  .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                (hasWorkout
                                        ? StudentThemeColors.of(
                                            context,
                                          ).primaryFixed
                                        : AppColors.onSurfaceVariant)
                                    .withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          'HOJE',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                            color: hasWorkout
                                ? StudentThemeColors.of(context).primaryFixed
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        hasWorkout
                            ? Icons.fitness_center
                            : Icons.self_improvement,
                        color:
                            (hasWorkout
                                    ? StudentThemeColors.of(
                                        context,
                                      ).primaryFixed
                                    : AppColors.onSurfaceVariant)
                                .withValues(alpha: 0.3),
                        size: compact ? 48 : 60,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasWorkout ? workoutName! : 'DIA DE DESCANSO',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      fontSize: compact ? 28 : 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.02,
                      color: Colors.white,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasWorkout
                        ? '$exerciseCount exercícios • Foco em ${todayWorkout.foco.isNotEmpty ? todayWorkout.foco.toLowerCase() : 'força'}.'
                        : 'Aproveita para alongar e recuperar.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (hasWorkout)
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: Text(
                            'INICIAR TREINO',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.03,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: StudentThemeColors.of(
                              context,
                            ).primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 50),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 15,
                            ),
                          ),
                        ),
                        _muscleChip('${todayWorkout.exercicios.length} ex.'),
                        _muscleChip(todayWorkout.diaSemana),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => _buildHeroCardSkeleton(),
      error: (_, __) => _buildHeroCardSkeleton(),
    );
  }

  Widget _buildHeroCardSkeleton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outline.withValues(alpha: 0.5)),
        ),
        child: Center(
          child: CircularProgressIndicator(
            color: StudentThemeColors.of(context).primary,
          ),
        ),
      ),
    );
  }

  Widget _muscleChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          color: AppColors.secondaryFixedDim,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BENTO GRID
  // ═══════════════════════════════════════════════════════════════

  Widget _buildBentoGrid(
    DiaryModel diary,
    double waterPct,
    double metaAgua,
    bool isOffline,
    String userId,
  ) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final halfW = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _glassStatCard(
              width: halfW,
              icon: Icons.local_fire_department,
              iconColor: StudentThemeColors.of(context).primaryFixed,
              label: 'CALORIAS',
              value: diary.totalCalorias.toStringAsFixed(0),
              unit: 'kcal',
              height: 140,
            ),
            _glassStatCard(
              width: halfW,
              icon: Icons.water_drop,
              iconColor: StudentThemeColors.of(context).primaryFixed,
              label: 'HIDRATAÇÃO',
              value: (diary.agua / 1000).toStringAsFixed(1),
              unit: '/ ${(metaAgua / 1000).toStringAsFixed(1)}L',
              progress: waterPct,
              height: 140,
              // A hidratação é atualizada pelo stream do diário; o card é
              // apenas informativo e não abre nenhuma ação ao tocar.
              onTap: null,
            ),
            _glassStatCard(
              width: constraints.maxWidth,
              icon: Icons.timer,
              iconColor: StudentThemeColors.of(context).primaryFixed,
              label: 'TEMPO EM ATIVIDADE',
              value: '48',
              unit: 'minutos',
              subtitle: '+12% vs ontem',
              height: 100,
            ),
          ],
        );
      },
    );
  }

  Widget _glassStatCard({
    required double width,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String unit,
    double? progress,
    String? subtitle,
    double height = 140,
    VoidCallback? onTap,
  }) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outline.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle != null)
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 22),
                  const Spacer(),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: iconColor,
                    ),
                  ),
                ],
              )
            else
              Icon(icon, color: iconColor, size: 22),
            const Spacer(),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: AppColors.onSurfaceVariant,
                letterSpacing: 0.05,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: GoogleFonts.montserrat(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    unit,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.secondaryFixedDim,
                    ),
                  ),
                ),
              ],
            ),
            if (progress != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.surfaceHighest,
                  valueColor: AlwaysStoppedAnimation(
                    StudentThemeColors.of(context).primaryFixed,
                  ),
                  minHeight: 3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }

  // ═══════════════════════════════════════════════════════════════
  // WEEKLY ACTIVITY BARS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildWeeklyActivity(String userId) {
    final historyAsync = ref.watch(weeklyHistoryProvider(userId));
    final workoutPlansAsync = ref.watch(weeklyWorkoutPlansProvider(userId));
    final labels = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
    final today = DateTime.now().weekday - 1;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outline.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Atividade Semanal',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.bar_chart,
                  color: AppColors.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 20),
            historyAsync.when(
              data: (history) {
                final plans = workoutPlansAsync.asData?.value ?? [];

                // Map diary entries to day buckets (0=Mon..6=Sun)
                final calPerDay = List.filled(7, 0.0);
                final diaryPerDay = List<DiaryModel?>.filled(7, null);
                final now = DateTime.now();
                final weekStart = DateTime(
                  now.year,
                  now.month,
                  now.day - (now.weekday - 1),
                );

                for (final entry in history) {
                  try {
                    final date = DateTime.parse(entry.data);
                    final diff = date.difference(weekStart).inDays;
                    if (diff >= 0 && diff < 7) {
                      calPerDay[diff] += entry.totalCalorias;
                      diaryPerDay[diff] = entry;
                    }
                  } catch (_) {}
                }

                // Find workout for each day of the week
                final workoutPerDay = List<WorkoutDay?>.filled(7, null);
                for (final plan in plans) {
                  for (int i = 0; i < 7; i++) {
                    if (workoutPerDay[i] == null) {
                      final diaSemana = AppStrings.daysOfWeek[i];
                      workoutPerDay[i] = plan.getWorkoutForDay(diaSemana);
                    }
                  }
                }

                final maxCal = calPerDay.isEmpty
                    ? 1.0
                    : calPerDay
                          .reduce((a, b) => a > b ? a : b)
                          .clamp(1.0, 5000.0);

                return SizedBox(
                  height: 160,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(7, (i) {
                      final isToday = i == today;
                      final h = (calPerDay[i] / maxCal).clamp(0.04, 1.0);
                      final cals = calPerDay[i];
                      final dayDate = weekStart.add(Duration(days: i));
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: i < 6 ? 4 : 0),
                          child: GestureDetector(
                            onTap: () => _showDayDetails(
                              context,
                              dayIndex: i,
                              dayDate: dayDate,
                              diary: diaryPerDay[i],
                              workout: workoutPerDay[i],
                            ),
                            child: Column(
                              children: [
                                // Calorias no topo
                                if (cals > 0)
                                  SizedBox(
                                    height: 16,
                                    child: Center(
                                      child: Text(
                                        cals.toStringAsFixed(0),
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: isToday
                                              ? FontWeight.w700
                                              : FontWeight.w400,
                                          color: isToday
                                              ? StudentThemeColors.of(
                                                  context,
                                                ).primaryFixed
                                              : AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                // Barra com altura proporcional
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: FractionallySizedBox(
                                      heightFactor: h,
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 600,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isToday
                                              ? StudentThemeColors.of(
                                                  context,
                                                ).primaryFixed
                                              : AppColors.surfaceHighest,
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(2),
                                              ),
                                          boxShadow: isToday
                                              ? [
                                                  BoxShadow(
                                                    color: AppColors
                                                        .primaryFixed
                                                        .withValues(alpha: 0.4),
                                                    blurRadius: 12,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  labels[i],
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: isToday
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: isToday
                                        ? StudentThemeColors.of(
                                            context,
                                          ).primaryFixed
                                        : AppColors.secondaryFixedDim,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              },
              loading: () => SizedBox(
                height: 100,
                child: Center(
                  child: CircularProgressIndicator(
                    color: StudentThemeColors.of(context).primary,
                  ),
                ),
              ),
              error: (_, __) => SizedBox(
                height: 100,
                child: Center(
                  child: Text(
                    'Sem dados da semana',
                    style: GoogleFonts.inter(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Exibe um bottom sheet com detalhes do dia (refeições + treino).
  void _showDayDetails(
    BuildContext context, {
    required int dayIndex,
    required DateTime dayDate,
    DiaryModel? diary,
    WorkoutDay? workout,
  }) {
    final diaNome = AppStrings.daysOfWeek[dayIndex];
    final dateStr = DateFormat("dd 'de' MMMM", 'pt').format(dayDate);
    final isToday = dayIndex == DateTime.now().weekday - 1;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(
              color: AppColors.outline.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Scrollable content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header ─────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  diaNome,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$dateStr${isToday ? ' • Hoje' : ''}',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(
                              Icons.close,
                              color: AppColors.onSurfaceVariant,
                              size: 22,
                            ),
                          ),
                        ],
                      ),

                      if (diary == null && workout == null) ...[
                        const SizedBox(height: 32),
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 48,
                                color: AppColors.onSurfaceVariant.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Sem registos neste dia',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],

                      // ── Stats Row ───────────────────────
                      if (diary != null) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _detailStatChip(
                              Icons.local_fire_department,
                              AppColors.calories,
                              '${diary.totalCalorias.toStringAsFixed(0)} kcal',
                            ),
                            _detailStatChip(
                              Icons.water_drop,
                              StudentThemeColors.of(context).primaryFixed,
                              '${(diary.agua / 1000).toStringAsFixed(1)}L',
                            ),
                            if (diary.avaliacao > 0)
                              _detailStatChip(
                                Icons.star,
                                AppColors.starFilled,
                                '${diary.avaliacao}/5',
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Refeições ───────────────────────
                      if (diary != null && diary.refeicoes.isNotEmpty) ...[
                        _detailSectionHeader(Icons.restaurant, 'Refeições'),
                        const SizedBox(height: 8),
                        ...diary.refeicoes.map((meal) => _detailMealTile(meal)),
                        const SizedBox(height: 8),
                      ],

                      // ── Treino ──────────────────────────
                      if (workout != null && workout.exercicios.isNotEmpty) ...[
                        _detailSectionHeader(
                          Icons.fitness_center,
                          'Treino${workout.foco.isNotEmpty ? ' • ${workout.foco.toUpperCase()}' : ''}',
                        ),
                        const SizedBox(height: 8),
                        ...workout.exercicios.map(
                          (ex) => _detailExerciseTile(ex),
                        ),
                      ] else if (workout != null &&
                          workout.exercicios.isEmpty) ...[
                        _detailSectionHeader(Icons.fitness_center, 'Treino'),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Text(
                            'Dia de descanso',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailStatChip(IconData icon, Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: StudentThemeColors.of(context).primaryFixed,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: StudentThemeColors.of(context).primaryFixed,
          ),
        ),
      ],
    );
  }

  Widget _detailMealTile(MealEntry meal) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              meal.tipo,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.descricao,
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                ),
                if (meal.alimentos.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      meal.alimentos.join(', '),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${meal.calorias.toStringAsFixed(0)} kcal',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.calories,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailExerciseTile(Exercise ex) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: StudentThemeColors.of(context).primaryFixed,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ex.nome,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
          Text(
            '${ex.series}x${ex.repeticoes}',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryFixedDim,
            ),
          ),
          if (ex.cargaSugerida != null) ...[
            const SizedBox(width: 8),
            Text(
              '${ex.cargaSugerida!.toStringAsFixed(0)}kg',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // NUTRITION BRIEF
  // ═══════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════
  // BOTTOM SECTION: Rating & Workout
  // ═══════════════════════════════════════════════════════════════

  Widget _buildBottomSection(String userId, DiaryModel diary) {
    return _glassSection(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: Text(
              AppStrings.dayRating,
              textAlign: TextAlign.center,
              softWrap: true,
              style: GoogleFonts.inter(
                fontSize: 15,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 10),
          StarRating(
            rating: diary.avaliacao,
            onChanged: (rating) => _setRating(userId, rating),
          ),
        ],
      ),
    );
  }

  Widget _glassSection({required EdgeInsets padding, required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outline.withValues(alpha: 0.4)),
        ),
        child: child,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // UPCOMING SESSIONS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildUpcomingSessions(String userId) {
    // Usa provider estável (module-level) — nunca inline StreamProvider no build()!
    final bookingsAsync = ref.watch(studentBookingsStreamProvider(userId));

    return bookingsAsync.when(
      data: (bookings) {
        final upcoming =
            bookings
                .where((b) => b.isConfirmed || b.isPending)
                .where((b) => b.data.isAfter(DateTime.now()))
                .toList()
              ..sort((a, b) => a.data.compareTo(b.data));

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.outline.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: StudentThemeColors.of(context).primaryFixed,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Próximas Aulas',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CalendarScreen(),
                        ),
                      ),
                      child: Text(
                        'Ver agenda',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: StudentThemeColors.of(context).primaryFixed,
                        ),
                      ),
                    ),
                  ],
                ),
                if (upcoming.isEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 20,
                        color: AppColors.onSurfaceVariant.withValues(
                          alpha: 0.4,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Nenhuma aula marcada',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  ...upcoming
                      .take(3)
                      .map(
                        (b) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: b.isConfirmed
                                      ? StudentThemeColors.of(
                                          context,
                                        ).primary.withValues(alpha: 0.12)
                                      : AppColors.calories.withValues(
                                          alpha: 0.12,
                                        ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      b.horaFormatada,
                                      style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: b.isConfirmed
                                            ? StudentThemeColors.of(
                                                context,
                                              ).primary
                                            : AppColors.calories,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      b.tipo == 'online'
                                          ? '💻 Online'
                                          : '🏋️ Presencial',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      DateFormat(
                                        'EEE, d MMM',
                                        'pt',
                                      ).format(b.data),
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${b.duracaoMinutos}min',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════════════

  Future<void> _setRating(String userId, int rating) async {
    final today = DateFormat(AppConstants.dateFormat).format(DateTime.now());
    try {
      await ref.read(diaryRepositoryProvider).setRating(userId, today, rating);
    } catch (_) {}
  }
}
