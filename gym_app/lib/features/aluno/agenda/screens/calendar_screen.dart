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
import '../../../../features/auth/providers/auth_provider.dart';

/// Ecrã de calendário/agenda para o aluno marcar e ver aulas com PT.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _booking = false;
  TimeOfDay? _selectedTime;
  int _duracao = 60;
  String _tipo = 'presencial';
  final _notasCtrl = TextEditingController();

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(
      StreamProvider<List<BookingModel>>((ref) {
        if (_userId.isEmpty) return Stream.value([]);
        return ref.read(bookingRepositoryProvider).watchStudentBookings(_userId);
      }),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Agenda', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => setState(() => _booking = !_booking),
            tooltip: 'Marcar aula',
          ),
        ],
      ),
      body: bookingsAsync.when(
        data: (bookings) => Column(
          children: [
            // ── Seletor de semana ──
            _buildWeekSelector(),
            // ── Painel de marcação ──
            if (_booking) _buildBookingPanel(bookings),
            // ── Lista de marcações do dia ──
            Expanded(child: _buildDayBookings(bookings)),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => const Center(child: Text('Erro ao carregar agenda', style: TextStyle(color: AppColors.textSecondary))),
      ),
    );
  }

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
            final isSelected = _selectedDate.year == d.year &&
                _selectedDate.month == d.month &&
                _selectedDate.day == d.day;
            final isToday = today.year == d.year &&
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
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isToday && !isSelected ? AppColors.primary : AppColors.outline,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'][d.weekday - 1],
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppColors.textSecondary,
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

  Widget _buildBookingPanel(List<BookingModel> existingBookings) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Nova Marcação', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: AppColors.onSurface)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _booking = false),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Data
          Text(DateFormat('EEEE, d MMMM yyyy', 'pt').format(_selectedDate),
              style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          // Hora
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(hour: 9, minute: 0),
                    );
                    if (t != null) setState(() => _selectedTime = t);
                  },
                  icon: const Icon(Icons.access_time, size: 16),
                  label: Text(_selectedTime?.format(context) ?? 'Hora',
                      style: GoogleFonts.inter(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.onSurface,
                    side: BorderSide(color: AppColors.outline),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Duração
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _duracao,
                  dropdownColor: AppColors.surfaceHigh,
                  style: GoogleFonts.inter(color: AppColors.onSurface, fontSize: 13),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.outline),
                    ),
                  ),
                  items: [30, 45, 60, 90, 120].map((m) => DropdownMenuItem(value: m, child: Text('${m}min'))).toList(),
                  onChanged: (v) => setState(() => _duracao = v ?? 60),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Tipo
          Row(
            children: ['presencial', 'online'].map((t) {
              final active = _tipo == t;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: t == 'presencial' ? 4 : 0, left: t == 'online' ? 4 : 0),
                  child: GestureDetector(
                    onTap: () => setState(() => _tipo = t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: active ? AppColors.primary : AppColors.outline),
                      ),
                      child: Text(
                        t == 'presencial' ? '🏋️ Presencial' : '💻 Online',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                          color: active ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notasCtrl,
            style: GoogleFonts.inter(color: AppColors.onSurface, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Notas (opcional)',
              hintStyle: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.outline),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedTime == null ? null : () => _submitBooking(existingBookings),
              icon: const Icon(Icons.check, size: 16),
              label: Text('Confirmar Marcação', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitBooking(List<BookingModel> existing) async {
    if (_selectedTime == null) return;

    final bookingDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    // Verifica conflito de horário
    final conflito = existing.any((b) {
      if (b.isCancelled) return false;
      final bStart = b.data;
      final bEnd = b.data.add(Duration(minutes: b.duracaoMinutos));
      final myEnd = bookingDate.add(Duration(minutes: _duracao));
      return bookingDate.isBefore(bEnd) && myEnd.isAfter(bStart);
    });

    if (conflito) {
      showAppNotification(context, 'Já tens uma aula nesse horário.', type: NotificationType.error);
      return;
    }

    // Obtém o trainerId do perfil do aluno (personalId)
    final authState = ref.read(authProvider);
    final trainerId = authState.user?.personalId ?? '';

    try {
      await ref.read(bookingRepositoryProvider).addBooking({
        'studentId': _userId,
        'trainerId': trainerId,
        'data': bookingDate,
        'duracaoMinutos': _duracao,
        'status': 'pending',
        'tipo': _tipo,
        if (_notasCtrl.text.trim().isNotEmpty) 'notas': _notasCtrl.text.trim(),
        'createdAt': DateTime.now(),
      });

      // Notificar o PT (fire-and-forget, sem bloquear)
      _notifyBooking(_userId, trainerId, bookingDate, _tipo);

      if (mounted) {
        showAppNotification(context, 'Aula marcada com sucesso!', type: NotificationType.success);
        setState(() {
          _booking = false;
          _selectedTime = null;
          _notasCtrl.clear();
        });
      }
    } catch (_) {
      if (mounted) showAppNotification(context, 'Erro ao marcar aula.', type: NotificationType.error);
    }
  }

  Widget _buildDayBookings(List<BookingModel> bookings) {
    final dayBookings = bookings
        .where((b) =>
            b.data.year == _selectedDate.year &&
            b.data.month == _selectedDate.month &&
            b.data.day == _selectedDate.day)
        .toList()
      ..sort((a, b) => a.data.compareTo(b.data));

    if (dayBookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text('Nenhuma aula marcada', style: GoogleFonts.inter(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text('para ${DateFormat('d MMMM', 'pt').format(_selectedDate)}',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.6))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: dayBookings.length,
      itemBuilder: (_, i) => _bookingCard(dayBookings[i]),
    );
  }

  Widget _bookingCard(BookingModel booking) {
    final statusColors = {
      'confirmed': AppColors.primary,
      'pending': AppColors.calories,
      'cancelled': AppColors.error,
      'completed': AppColors.protein,
    };
    final statusLabels = {
      'confirmed': 'Confirmada',
      'pending': 'Pendente',
      'cancelled': 'Cancelada',
      'completed': 'Concluída',
    };

    final color = statusColors[booking.status] ?? AppColors.textSecondary;
    final label = statusLabels[booking.status] ?? booking.status;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(booking.horaFormatada,
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 16, color: color)),
                  Text(booking.fimFormatado,
                      style: GoogleFonts.inter(fontSize: 10, color: color.withValues(alpha: 0.7))),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        booking.tipo == 'online' ? Icons.videocam : Icons.fitness_center,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        booking.tipo == 'online' ? 'Online' : 'Presencial',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      Text('${booking.duracaoMinutos}min',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (booking.notas != null && booking.notas!.isNotEmpty)
                    Text(booking.notas!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
            ),
            if (booking.isPending) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: AppColors.error),
                onPressed: () => _cancelBooking(booking),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Cancelar',
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Envia notificação ao PT sobre nova marcação (best-effort).
  void _notifyBooking(String studentId, String trainerId, DateTime bookingDate, String tipo) {
    FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('notifyNewBooking')
        .call({
      'studentId': studentId,
      'trainerId': trainerId,
      'bookingDate': bookingDate.toIso8601String(),
      'tipo': tipo,
    }).catchError((_) {}); // silencioso — a Cloud Function trata o envio
  }

  Future<void> _cancelBooking(BookingModel booking) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Cancelar aula?', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: AppColors.onSurface)),
        content: Text('${booking.horaFormatada} - ${DateFormat('d MMM', 'pt').format(booking.data)}',
            style: GoogleFonts.inter(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Voltar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(bookingRepositoryProvider).updateBooking(booking.id, {'status': 'cancelled'});
        if (mounted) showAppNotification(context, 'Aula cancelada.', type: NotificationType.success);
      } catch (_) {
        if (mounted) showAppNotification(context, 'Erro ao cancelar.', type: NotificationType.error);
      }
    }
  }
}
