import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../data/models/booking_model.dart';
import '../../../../shared/providers/global_providers.dart';
import '../../../../shared/widgets/app_notification.dart';
import '../../../../shared/widgets/app_design_system.dart';
import '../../../../features/auth/providers/auth_provider.dart';

/// Horários disponíveis para marcação (8h às 18h, blocos de 60 min).
const _kAvailableHours = [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18];
const _kSlotDurationMin = 60;

/// Estado visual de cada bloco horário.
enum _SlotState {
  available, // cinzento — livre para marcar
  pending, // amarelo — pedido pendente do próprio aluno
  confirmedMine, // verde — confirmado (meu)
  confirmedOther, // verde escuro — ocupado por outro aluno
  cancelled, // vermelho claro — recusado/cancelado
}

/// Ecrã de agenda do aluno — grelha horária com blocos coloridos.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final trainerId = authState.user?.personalId ?? '';

    final bookingsAsync = ref.watch(studentBookingsStreamProvider(_userId));
    final trainerBookingsAsync = ref.watch(
      trainerBookingsStreamProvider(trainerId),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            child: AppPageIntro(
              eyebrow: 'Planeamento',
              title: 'A tua agenda',
              subtitle: 'Escolhe o melhor momento para manteres o ritmo.',
            ),
          ),
          Expanded(
            child: bookingsAsync.when(
              data: (myBookings) {
                final allTrainerBookings =
                    trainerBookingsAsync.asData?.value ?? [];
                return Column(
                  children: [
                    _buildWeekSelector(),
                    Expanded(
                      child: _buildTimeGrid(myBookings, allTrainerBookings),
                    ),
                  ],
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Erro ao carregar agenda',
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        e.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textSecondary.withAlpha(150),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // WEEK SELECTOR
  // ═══════════════════════════════════════════════════════════════

  Widget _buildWeekSelector() {
    final today = DateTime.now();
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final days = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outline)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: days.map((d) {
            final isSelected =
                _selectedDate.year == d.year &&
                _selectedDate.month == d.month &&
                _selectedDate.day == d.day;
            final isToday =
                today.year == d.year &&
                today.month == d.month &&
                today.day == d.day;
            return GestureDetector(
              onTap: () => setState(() => _selectedDate = d),
              child: Container(
                width: 52,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isToday && !isSelected
                        ? AppColors.primary
                        : AppColors.outline,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      [
                        'Seg',
                        'Ter',
                        'Qua',
                        'Qui',
                        'Sex',
                        'Sáb',
                        'Dom',
                      ][d.weekday - 1],
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${d.day}',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TIME GRID
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTimeGrid(
    List<BookingModel> myBookings,
    List<BookingModel> allTrainerBookings,
  ) {
    final now = DateTime.now();
    final isToday =
        _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _kAvailableHours.length,
      itemBuilder: (_, i) {
        final hour = _kAvailableHours[i];
        final slotStart = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          hour,
          0,
        );
        final slotEnd = slotStart.add(
          const Duration(minutes: _kSlotDurationMin),
        );

        final slotState = _getSlotState(
          slotStart,
          slotEnd,
          myBookings,
          allTrainerBookings,
        );
        final isPast = isToday && slotEnd.isBefore(now);

        return _buildSlotTile(hour, slotState, slotStart, isPast, myBookings);
      },
    );
  }

  _SlotState _getSlotState(
    DateTime slotStart,
    DateTime slotEnd,
    List<BookingModel> myBookings,
    List<BookingModel> allTrainerBookings,
  ) {
    // 1. Verifica se há um booking confirmado que se sobrepõe (de qualquer aluno)
    final confirmedOverlap = allTrainerBookings.where((b) => b.isConfirmed).any(
      (b) {
        return _overlaps(
          slotStart,
          slotEnd,
          b.data,
          b.data.add(Duration(minutes: b.duracaoMinutos)),
        );
      },
    );
    if (confirmedOverlap) {
      final myConfirmed = myBookings.where((b) => b.isConfirmed).any((b) {
        return _overlaps(
          slotStart,
          slotEnd,
          b.data,
          b.data.add(Duration(minutes: b.duracaoMinutos)),
        );
      });
      return myConfirmed ? _SlotState.confirmedMine : _SlotState.confirmedOther;
    }

    // 2. Pendentes do próprio aluno
    final myPending = myBookings.where((b) => b.isPending).any((b) {
      return _overlaps(
        slotStart,
        slotEnd,
        b.data,
        b.data.add(Duration(minutes: b.duracaoMinutos)),
      );
    });
    if (myPending) return _SlotState.pending;

    // 3. Cancelados do próprio aluno
    final myCancelled = myBookings.where((b) => b.isCancelled).any((b) {
      return _overlaps(
        slotStart,
        slotEnd,
        b.data,
        b.data.add(Duration(minutes: b.duracaoMinutos)),
      );
    });
    if (myCancelled) return _SlotState.cancelled;

    return _SlotState.available;
  }

  bool _overlaps(DateTime s1, DateTime e1, DateTime s2, DateTime e2) {
    return s1.isBefore(e2) && e1.isAfter(s2);
  }

  Widget _buildSlotTile(
    int hour,
    _SlotState state,
    DateTime slotStart,
    bool isPast,
    List<BookingModel> myBookings,
  ) {
    final (
      Color bgColor,
      Color textColor,
      IconData? icon,
      String label,
    ) = switch (state) {
      _SlotState.available => (
        AppColors.surface,
        AppColors.onSurface,
        null,
        'Disponível',
      ),
      _SlotState.pending => (
        AppColors.calories.withValues(alpha: 0.2),
        AppColors.calories,
        Icons.hourglass_bottom,
        'Aguardando',
      ),
      _SlotState.confirmedMine => (
        AppColors.primary.withValues(alpha: 0.2),
        AppColors.primary,
        Icons.check_circle,
        'Confirmada',
      ),
      _SlotState.confirmedOther => (
        AppColors.error.withValues(alpha: 0.12),
        AppColors.error,
        Icons.lock,
        'Ocupado',
      ),
      _SlotState.cancelled => (
        AppColors.error.withValues(alpha: 0.08),
        AppColors.error.withValues(alpha: 0.5),
        Icons.cancel,
        'Recusada',
      ),
    };

    final isAvailable = state == _SlotState.available && !isPast;
    final isMyPending = state == _SlotState.pending;
    final isMyConfirmed = state == _SlotState.confirmedMine;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isAvailable
              ? () => _confirmBooking(slotStart)
              : isMyPending
              ? () => _cancelMyPending(slotStart, myBookings)
              : isMyConfirmed
              ? () => _cancelConfirmed(slotStart, myBookings)
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isAvailable ? AppColors.outline : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text(
                    '${hour.toString().padLeft(2, '0')}:00',
                    style: GoogleFonts.montserrat(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isPast
                          ? AppColors.textSecondary.withValues(alpha: 0.4)
                          : textColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(hour + 1).toString().padLeft(2, '0')}:00',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: textColor.withValues(alpha: 0.5),
                  ),
                ),
                const Spacer(),
                if (icon != null) ...[
                  Icon(icon, size: 16, color: textColor),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
                if (isAvailable) ...[
                  const Icon(
                    Icons.add_circle_outline,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Marcar',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════════════

  Future<void> _confirmBooking(DateTime slotStart) async {
    final authState = ref.read(authProvider);
    final trainerId = authState.user?.personalId ?? '';

    if (trainerId.isEmpty) {
      if (mounted)
        showAppNotification(
          context,
          'Ainda não tens um Personal Trainer associado.',
          type: NotificationType.info,
        );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Marcar aula?',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        content: Text(
          '${DateFormat('EEEE, d MMMM', 'pt').format(slotStart)}\n'
          '${slotStart.hour.toString().padLeft(2, '0')}:00 - ${(slotStart.hour + 1).toString().padLeft(2, '0')}:00\n\n'
          'O teu PT será notificado e poderá confirmar ou recusar.',
          style: GoogleFonts.inter(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 50),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            child: const Text('Marcar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(bookingRepositoryProvider).addBooking({
        'studentId': _userId,
        'trainerId': trainerId,
        'data': slotStart,
        'duracaoMinutos': _kSlotDurationMin,
        'status': 'pending',
        'tipo': 'presencial',
        'createdAt': DateTime.now(),
      });

      // Notificar PT (fire-and-forget), sem deixar rejeições assíncronas no
      // console quando o token expirou ou a rede está indisponível.
      _notifyNewBooking(trainerId, slotStart);

      if (mounted)
        showAppNotification(
          context,
          'Aula marcada! Aguarda confirmação do PT.',
          type: NotificationType.success,
        );
    } catch (_) {
      if (mounted)
        showAppNotification(
          context,
          'Erro ao marcar aula.',
          type: NotificationType.error,
        );
    }
  }

  Future<void> _notifyNewBooking(String trainerId, DateTime date) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final token = await user.getIdToken(true);
      if (token == null || token.isEmpty) return;
      await FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('notifyNewBooking').call({
        'studentId': _userId,
        'trainerId': trainerId,
        'bookingDate': date.toIso8601String(),
        'tipo': 'presencial',
        'authToken': token,
      });
    } catch (_) {
      // Push é best-effort; a aula já foi guardada no Firestore.
    }
  }

  Future<void> _notifyBookingCancelled(BookingModel booking) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final token = await user.getIdToken(true);
      if (token == null || token.isEmpty) return;
      await FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('notifyBookingCancelled').call({
        'bookingId': booking.id,
        'studentId': _userId,
        'trainerId': booking.trainerId,
        'bookingDate': booking.data.toIso8601String(),
        'tipo': booking.tipo,
        'authToken': token,
      });
    } catch (_) {
      // Push é best-effort; o cancelamento já foi guardado no Firestore.
    }
  }

  /// Cancela uma marcação pending do próprio aluno neste slot.
  Future<void> _cancelMyPending(
    DateTime slotStart,
    List<BookingModel> myBookings,
  ) async {
    final pendingBooking = myBookings.where((b) => b.isPending).firstWhere(
      (b) {
        final bEnd = b.data.add(Duration(minutes: b.duracaoMinutos));
        return _overlaps(
          slotStart,
          slotStart.add(const Duration(minutes: _kSlotDurationMin)),
          b.data,
          bEnd,
        );
      },
      orElse: () => BookingModel(
        id: '',
        studentId: '',
        trainerId: '',
        data: DateTime.now(),
      ),
    );

    if (pendingBooking.id.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Cancelar pedido?',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        content: Text(
          'O pedido para ${pendingBooking.horaFormatada} será cancelado.',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 50),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            child: const Text('Cancelar Pedido'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(bookingRepositoryProvider).updateBooking(
          pendingBooking.id,
          {'status': 'cancelled'},
        );
        if (mounted)
          showAppNotification(
            context,
            'Pedido cancelado.',
            type: NotificationType.success,
          );
      } catch (_) {
        if (mounted)
          showAppNotification(
            context,
            'Erro ao cancelar.',
            type: NotificationType.error,
          );
      }
    }
  }

  /// Cancela uma aula confirmada.
  Future<void> _cancelConfirmed(
    DateTime slotStart,
    List<BookingModel> myBookings,
  ) async {
    final confirmedBooking = myBookings.where((b) => b.isConfirmed).firstWhere(
      (b) {
        final bEnd = b.data.add(Duration(minutes: b.duracaoMinutos));
        return _overlaps(
          slotStart,
          slotStart.add(const Duration(minutes: _kSlotDurationMin)),
          b.data,
          bEnd,
        );
      },
      orElse: () => BookingModel(
        id: '',
        studentId: '',
        trainerId: '',
        data: DateTime.now(),
      ),
    );

    if (confirmedBooking.id.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Cancelar aula?',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        content: Text(
          'A aula de ${confirmedBooking.horaFormatada} será cancelada.',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 50),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            child: const Text('Cancelar Aula'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(bookingRepositoryProvider).updateBooking(
          confirmedBooking.id,
          {'status': 'cancelled'},
        );
        // Notificar o PT (fire-and-forget), mas trata a Future internamente.
        _notifyBookingCancelled(confirmedBooking);
        if (mounted)
          showAppNotification(
            context,
            'Aula cancelada.',
            type: NotificationType.success,
          );
      } catch (_) {
        if (mounted)
          showAppNotification(
            context,
            'Erro ao cancelar.',
            type: NotificationType.error,
          );
      }
    }
  }
}
