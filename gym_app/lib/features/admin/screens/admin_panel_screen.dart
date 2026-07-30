import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/config/admin_theme.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/food_model.dart';
import '../../../data/models/progress_model.dart';
import '../../../data/models/payment_model.dart';
import '../../../data/models/booking_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/providers/global_providers.dart';
import '../../../shared/providers/admin_providers.dart';
import '../../../shared/utils/booking_notifications.dart';
import '../../../shared/widgets/image_comparison_slider.dart';
import '../../../shared/widgets/app_notification.dart';
import '../../admin/widgets/workout_editor.dart';
import '../../admin/widgets/nutrition_editor.dart';
import '../../admin/widgets/admin_messages_view.dart';
import '../../../features/aluno/chat/screens/chat_screen.dart';

// ─── Enums & Local Providers ──────────────────────────────────────

enum AdminView { dashboard, clients, exercises, foods, messages, payments, agenda }

final alunosListProvider = FutureProvider<List<UserModel>>((ref) {
  return ref.read(userRepositoryProvider).getAllAlunos();
});

final alunosSearchProvider =
    FutureProvider.family<List<UserModel>, String>((ref, query) {
  if (query.isEmpty) return ref.read(userRepositoryProvider).getAllAlunos();
  return ref.read(userRepositoryProvider).searchAlunos(query);
});

// ─── Main Admin Panel ────────────────────────────────────────────

class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen> {
  AdminView _view = AdminView.dashboard;
  UserModel? _selectedClient;
  bool _fcmInitialized = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _initFCMIfNeeded();
  }

  void _initFCMIfNeeded() {
    if (_fcmInitialized) return;
    final authState = ref.read(authProvider);
    final userId = authState.user?.uid;
    if (userId != null && userId.isNotEmpty) {
      _fcmInitialized = true;
      final fcmService = ref.read(fcmServiceProvider);
      fcmService.initialize(userId);
    }
  }

  void _navigate(AdminView v) {
    setState(() {
      _view = v;
      _selectedClient = null;
    });
    // Fecha drawer em mobile
    if (_isMobile && _scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.pop(context);
    }
  }

  bool get _isMobile => MediaQuery.of(context).size.width < 900;

  Widget _buildSidebar() {
    return _AdminSidebar(
      currentView: _view,
      isClientDetail: _selectedClient != null,
      isMobile: _isMobile,
      onNavigate: _navigate,
      onLogout: () => ref.read(authProvider.notifier).signOut(),
      onToggleTheme: () {
        ref.read(adminThemeModeProvider.notifier).state =
            ref.read(adminThemeModeProvider) == ThemeMode.dark
                ? ThemeMode.light
                : ThemeMode.dark;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isMobile) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: AdminThemeColors.of(context).bg,
        appBar: AppBar(
          backgroundColor: AdminThemeColors.of(context).surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.menu, color: AdminThemeColors.of(context).text),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          title: Text('GYMBT',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AdminThemeColors.of(context).text)),
          actions: [
            IconButton(
              icon: Icon(
                Theme.of(context).brightness == Brightness.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                color: AdminThemeColors.of(context).muted,
              ),
              onPressed: () {
                ref.read(adminThemeModeProvider.notifier).state =
                    ref.read(adminThemeModeProvider) == ThemeMode.dark
                        ? ThemeMode.light
                        : ThemeMode.dark;
              },
            ),
          ],
        ),
        drawer: Drawer(
          backgroundColor: AdminThemeColors.of(context).surface,
          child: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: Icon(Icons.close,
                        color: AdminThemeColors.of(context).muted,
                        size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: const EdgeInsets.all(16),
                  ),
                ),
                Expanded(child: _buildSidebar()),
              ],
            ),
          ),
        ),
        body: _selectedClient != null
            ? _ClientDetailView(
                client: _selectedClient!,
                isMobile: true,
                onBack: () => setState(() => _selectedClient = null),
              )
            : _buildView(),
      );
    }

    return Scaffold(
      backgroundColor: AdminThemeColors.of(context).bg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSidebar(),
          Expanded(
            child: _selectedClient != null
                ? _ClientDetailView(
                    client: _selectedClient!,
                    isMobile: false,
                    onBack: () => setState(() => _selectedClient = null),
                  )
                : _buildView(),
          ),
        ],
      ),
    );
  }

  Widget _buildView() {
    switch (_view) {
      case AdminView.dashboard:
        return _AdminDashboard(onSelectClient: (c) => setState(() {
              _selectedClient = c;
              _view = AdminView.clients;
            }));
      case AdminView.clients:
        return _AdminClientsList(onSelect: (c) => setState(() => _selectedClient = c));
      case AdminView.exercises:
        return const _AdminExerciseLibrary();
      case AdminView.foods:
        return const _AdminFoodLibrary();
      case AdminView.messages:
        {
          return AdminMessagesView(onSelect: (c) => setState(() => _selectedClient = c));
        }
      case AdminView.payments:
        return const _AdminPaymentsView();
      case AdminView.agenda:
        return const _AdminAgendaView();
    }
  }
}

// ─── Sidebar ──────────────────────────────────────────────────────

class _AdminSidebar extends StatelessWidget {
  final AdminView currentView;
  final bool isClientDetail;
  final bool isMobile;
  final Function(AdminView) onNavigate;
  final VoidCallback onLogout;

  const _AdminSidebar({
    required this.currentView,
    required this.isClientDetail,
    required this.isMobile,
    required this.onNavigate,
    required this.onLogout,
    required this.onToggleTheme,
  });

  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final logoSection = Column(
      children: [
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AdminThemeColors.of(context).limeDim,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AdminThemeColors.of(context).lime.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.fitness_center,
                    color: AdminThemeColors.of(context).lime, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                'GYMBT',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AdminThemeColors.of(context).text,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        if (!isMobile)
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              color: AdminThemeColors.of(context).muted,
              size: 18,
            ),
            onPressed: onToggleTheme,
            tooltip: 'Alternar tema',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        const SizedBox(height: 16),
      ],
    );

    return Container(
      width: isMobile ? 260 : 220,
      decoration: BoxDecoration(
        color: AdminThemeColors.of(context).surface,
        boxShadow: [
          BoxShadow(
            color: AdminThemeColors.of(context).shadow,
            blurRadius: 12,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          logoSection,
          // Nav items
          _NavItem(
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard,
            label: 'Dashboard',
            active: currentView == AdminView.dashboard && !isClientDetail,
            onTap: () => onNavigate(AdminView.dashboard),
          ),
          _NavCategory(label: 'GESTÃO'),
          _NavItem(
            icon: Icons.people_outline,
            activeIcon: Icons.people,
            label: 'Clientes',
            active: currentView == AdminView.clients && !isClientDetail,
            onTap: () => onNavigate(AdminView.clients),
          ),
          _NavItem(
            icon: Icons.fitness_center_outlined,
            activeIcon: Icons.fitness_center,
            label: 'Exercícios',
            active: currentView == AdminView.exercises,
            onTap: () => onNavigate(AdminView.exercises),
          ),
          _NavItem(
            icon: Icons.restaurant_outlined,
            activeIcon: Icons.restaurant,
            label: 'Alimentos',
            active: currentView == AdminView.foods,
            onTap: () => onNavigate(AdminView.foods),
          ),
          _NavCategory(label: 'FINANÇAS'),
          _NavItem(
            icon: Icons.payment_outlined,
            activeIcon: Icons.payment,
            label: 'Pagamentos',
            active: currentView == AdminView.payments,
            onTap: () => onNavigate(AdminView.payments),
          ),
          _NavCategory(label: 'COMUNICAÇÃO'),
          _NavItem(
            icon: Icons.chat_outlined,
            activeIcon: Icons.chat,
            label: 'Mensagens',
            active: currentView == AdminView.messages && !isClientDetail,
            onTap: () => onNavigate(AdminView.messages),
          ),
          _NavCategory(label: 'AGENDA'),
          _NavItem(
            icon: Icons.calendar_today_outlined,
            activeIcon: Icons.calendar_today,
            label: 'Agenda',
            active: currentView == AdminView.agenda,
            onTap: () => onNavigate(AdminView.agenda),
          ),
          const Spacer(),
          // Logout
          Padding(
            padding: const EdgeInsets.all(16),
            child: InkWell(
              onTap: onLogout,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Icon(Icons.logout,
                        color: AdminThemeColors.of(context).muted, size: 16),
                    const SizedBox(width: 10),
                    Text(
                      'Sair',
                      style: GoogleFonts.inter(
                          color: AdminThemeColors.of(context).muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _NavCategory extends StatelessWidget {
  final String label;
  const _NavCategory({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(
        label,
        style: GoogleFonts.barlowCondensed(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.12,
          color: AdminThemeColors.of(context).muted,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: active ? AdminThemeColors.of(context).limeDim : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  active ? activeIcon : icon,
                  size: 18,
                  color: active ? AdminThemeColors.of(context).lime : AdminThemeColors.of(context).muted,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active ? AdminThemeColors.of(context).text : AdminThemeColors.of(context).muted,
                  ),
                ),
                if (active)
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(left: 6),
                    decoration: BoxDecoration(
                      color: AdminThemeColors.of(context).lime,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Dashboard View ───────────────────────────────────────────────

class _AdminDashboard extends ConsumerStatefulWidget {
  final Function(UserModel) onSelectClient;
  const _AdminDashboard({required this.onSelectClient});

  @override
  ConsumerState<_AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<_AdminDashboard> {
  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(adminDashboardStatsProvider);
    final alunosAsync = ref.watch(alunosListProvider);

    final isMobile = MediaQuery.of(context).size.width < 900;
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DASHBOARD', style: _adminDisplay(context, isMobile ? 28 : 40)),
          const SizedBox(height: 4),
          Text(
            DateFormat('EEEE, d MMMM yyyy', 'pt').format(DateTime.now()),
            style:
                GoogleFonts.inter(fontSize: 14, color: AdminThemeColors.of(context).muted),
          ),
          const SizedBox(height: 32),
          statsAsync.when(
            data: (stats) => _buildStats(stats),
            loading: () => _buildStatsLoading(),
            error: (_, __) => _buildStatsLoading(),
          ),
          const SizedBox(height: 32),
          alunosAsync.when(
            data: (alunos) => _buildDashboardColumns(alunos),
            loading: () => Center(
                child:
                    CircularProgressIndicator(color: AdminThemeColors.of(context).lime)),
            error: (_, __) => Text('Erro',
                style: GoogleFonts.inter(color: AdminThemeColors.of(context).muted)),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(AdminDashboardStats stats) {
    final items = [
      ('Clientes Totais', stats.totalAlunos, Icons.people, AdminThemeColors.of(context).lime),
      ('Ativos (30d)', stats.activeAlunos, Icons.trending_up, AdminThemeColors.of(context).blue),
      ('Sessões Mês', stats.sessoesMes, Icons.calendar_today, AdminThemeColors.of(context).orange),
      ('Sessões Totais', stats.sessoesTotal, Icons.emoji_events, AdminThemeColors.of(context).purple),
    ];
    return LayoutBuilder(builder: (_, constraints) {
      final cols = constraints.maxWidth > 800
          ? 4
          : (constraints.maxWidth > 450 ? 2 : 1);
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: items.map((s) {
          final width = (constraints.maxWidth - 14 * (cols - 1)) / cols;
          return SizedBox(width: width, child: _statCard(s.$1, s.$2.toString(), s.$3, s.$4));
        }).toList(),
      );
    });
  }

  Widget _buildStatsLoading() {
    final items = [
      ('Clientes Totais', '...', Icons.people, AdminThemeColors.of(context).lime),
      ('Ativos (30d)', '...', Icons.trending_up, AdminThemeColors.of(context).blue),
      ('Sessões Mês', '...', Icons.calendar_today, AdminThemeColors.of(context).orange),
      ('Sessões Totais', '...', Icons.emoji_events, AdminThemeColors.of(context).purple),
    ];
    return LayoutBuilder(builder: (_, constraints) {
      final cols = constraints.maxWidth > 800
          ? 4
          : (constraints.maxWidth > 450 ? 2 : 1);
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: items.map((s) {
          final width = (constraints.maxWidth - 14 * (cols - 1)) / cols;
          return SizedBox(width: width, child: _statCard(s.$1, s.$2, s.$3, s.$4));
        }).toList(),
      );
    });
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AdminThemeColors.of(context).surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminThemeColors.of(context).border),
        boxShadow: [
          BoxShadow(
            color: AdminThemeColors.of(context).shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label.toUpperCase(),
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AdminThemeColors.of(context).muted,
                      letterSpacing: 0.04)),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: GoogleFonts.barlowCondensed(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: AdminThemeColors.of(context).text,
                  height: 1)),
        ],
      ),
    );
  }

  Widget _buildDashboardColumns(List<UserModel> alunos) {
    return LayoutBuilder(builder: (_, constraints) {
      final isWide = constraints.maxWidth > 800;
      if (isWide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _clientsCard(alunos)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(children: [
                _agendaCard(),
                const SizedBox(height: 20),
                _goalsCard(alunos),
              ]),
            ),
          ],
        );
      }
      return Column(
        children: [
          _clientsCard(alunos),
          const SizedBox(height: 20),
          _agendaCard(),
          const SizedBox(height: 20),
          _goalsCard(alunos),
        ],
      );
    });
  }

  Widget _clientsCard(List<UserModel> alunos) {
    return Container(
      decoration: BoxDecoration(
        color: AdminThemeColors.of(context).surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminThemeColors.of(context).border),
        boxShadow: [
          BoxShadow(
            color: AdminThemeColors.of(context).shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.people, color: AdminThemeColors.of(context).lime, size: 16),
                const SizedBox(width: 8),
                Text('CLIENTES',
                    style: GoogleFonts.barlowCondensed(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.03,
                        color: AdminThemeColors.of(context).text)),
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  child: Text('Ver todos',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AdminThemeColors.of(context).lime)),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AdminThemeColors.of(context).border),
          if (alunos.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.people_outline,
                      size: 48, color: AdminThemeColors.of(context).muted),
                  const SizedBox(height: 12),
                  Text('Nenhum aluno cadastrado',
                      style: GoogleFonts.inter(
                          color: AdminThemeColors.of(context).muted, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('Clique em "Clientes" para adicionar o primeiro.',
                      style: GoogleFonts.inter(
                          color: AdminThemeColors.of(context).muted, fontSize: 12)),
                ],
              ),
            )
          else
            ...alunos.take(5).map((a) => _clientRow(a)),
        ],
      ),
    );
  }

  Widget _clientRow(UserModel aluno) {
    final weight = aluno.pesoAtual;
    return InkWell(
      onTap: () => widget.onSelectClient(aluno),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AdminThemeColors.of(context).border))),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AdminThemeColors.of(context).surface2,
              child: Text(
                aluno.nome.isNotEmpty
                    ? aluno.nome[0].toUpperCase()
                    : '?',
                style: GoogleFonts.barlowCondensed(
                    color: AdminThemeColors.of(context).lime,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(aluno.nome,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AdminThemeColors.of(context).text)),
                  Text(aluno.email,
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AdminThemeColors.of(context).muted)),
                ],
              ),
            ),
            if (weight != null) ...[
              Text('${weight.toStringAsFixed(0)}kg',
                  style: GoogleFonts.montserrat(
                      fontSize: 13, color: AdminThemeColors.of(context).text)),
              const SizedBox(width: 8),
            ],
            Icon(Icons.chevron_right,
                size: 14, color: AdminThemeColors.of(context).muted),
          ],
        ),
      ),
    );
  }

  Widget _agendaCard() {
    final trainerId = ref.read(authProvider).user?.uid ?? '';
    final bookingsAsync = ref.watch(
      adminTrainerBookingsProvider(trainerId),
    );
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminThemeColors.of(context).surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminThemeColors.of(context).border),
        boxShadow: [
          BoxShadow(
            color: AdminThemeColors.of(context).shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AGENDA DA SEMANA',
              style: GoogleFonts.barlowCondensed(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.03,
                  color: AdminThemeColors.of(context).text)),
          const SizedBox(height: 16),
          bookingsAsync.when(
            data: (bookings) {
              final weekBookings = bookings
                  .where((b) =>
                      !b.isCancelled &&
                      b.data.isAfter(weekStart) &&
                      b.data.isBefore(weekEnd))
                  .toList()
                ..sort((a, b) => a.data.compareTo(b.data));

              if (weekBookings.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Icon(Icons.event_busy,
                          size: 36,
                          color: AdminThemeColors.of(context).muted),
                      const SizedBox(height: 8),
                      Text('Nenhuma aula esta semana',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AdminThemeColors.of(context).muted)),
                    ],
                  ),
                );
              }

              return Column(
                children: weekBookings.take(5).map((b) {
                  final dateStr =
                      DateFormat('EEE d/M', 'pt').format(b.data);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AdminThemeColors.of(context).limeDim,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(b.horaFormatada,
                                  style: GoogleFonts.montserrat(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AdminThemeColors.of(context)
                                          .lime)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(dateStr,
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AdminThemeColors.of(context)
                                          .muted)),
                              Text(b.tipo == 'online' ? '💻 Online' : '🏋️ Presencial',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AdminThemeColors.of(context)
                                          .text)),
                            ],
                          ),
                        ),
                        _statusBadge(b.status),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => Center(
              child: CircularProgressIndicator(
                  color: AdminThemeColors.of(context).lime),
            ),
            error: (_, __) => Text('Erro',
                style: GoogleFonts.inter(
                    color: AdminThemeColors.of(context).muted)),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final colors = {
      'confirmed': AdminThemeColors.of(context).lime,
      'pending': Colors.orange,
      'completed': AdminThemeColors.of(context).blue,
      'cancelled': Colors.red,
    };
    final labels = {
      'confirmed': 'OK',
      'pending': 'Pend.',
      'completed': 'Feito',
      'cancelled': 'Canc.',
    };
    final color = colors[status] ?? AdminThemeColors.of(context).muted;
    final label = labels[status] ?? status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 9, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _goalsCard(List<UserModel> alunos) {
    final ativosSemana = alunos.where((a) => a.ultimaAtividade != null && DateTime.now().difference(a.ultimaAtividade!).inDays <= 7).length;
    final totalAlunos = alunos.length;
    final goals = [
      ('Ativos esta semana', ativosSemana, AdminThemeColors.of(context).blue),
      ('Total de alunos', totalAlunos, AdminThemeColors.of(context).lime),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminThemeColors.of(context).surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminThemeColors.of(context).border),
        boxShadow: [
          BoxShadow(
            color: AdminThemeColors.of(context).shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MÉTRICAS',
              style: GoogleFonts.barlowCondensed(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.03,
                  color: AdminThemeColors.of(context).text)),
          const SizedBox(height: 16),
          ...goals.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(g.$1,
                            style: GoogleFonts.inter(
                                fontSize: 12, color: AdminThemeColors.of(context).muted)),
                        Text('${g.$2}',
                            style: GoogleFonts.montserrat(
                                fontSize: 12, color: AdminThemeColors.of(context).text)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: alunos.isEmpty
                            ? 0.0
                            : (g.$2 / alunos.length).clamp(0.0, 1.0),
                        backgroundColor: AdminThemeColors.of(context).surface2,
                        valueColor: AlwaysStoppedAnimation(g.$3),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

}

// ─── Clients List View ────────────────────────────────────────────

class _AdminClientsList extends ConsumerStatefulWidget {
  final Function(UserModel) onSelect;
  const _AdminClientsList({required this.onSelect});

  @override
  ConsumerState<_AdminClientsList> createState() => _AdminClientsListState();
}

class _AdminClientsListState extends ConsumerState<_AdminClientsList> {
  String _search = '';
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final alunosAsync = ref.watch(alunosSearchProvider(_search));

    final isMobile = MediaQuery.of(context).size.width < 900;
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) ...[
            Text('CLIENTES', style: _adminDisplay(context, 28)),
            Text(
                '${alunosAsync.valueOrNull?.length ?? 0} clientes cadastrados',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AdminThemeColors.of(context).muted)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showCreateStudentDialog,
                icon: const Icon(Icons.add, size: 16),
                label: Text('NOVO CLIENTE',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.02)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminThemeColors.of(context).lime,
                  foregroundColor: AdminThemeColors.of(context).bg,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CLIENTES', style: _adminDisplay(context, 40)),
                      Text(
                          '${alunosAsync.valueOrNull?.length ?? 0} clientes cadastrados',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AdminThemeColors.of(context).muted)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showCreateStudentDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text('NOVO CLIENTE',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.02)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminThemeColors.of(context).lime,
                    foregroundColor: AdminThemeColors.of(context).bg,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          // Search + filters
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 40,
                  child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AdminThemeColors.of(context).text),
                      decoration: InputDecoration(
                        hintText: 'Buscar cliente...',
                        hintStyle: GoogleFonts.inter(
                            fontSize: 13,
                            color: AdminThemeColors.of(context).muted),
                        prefixIcon: Icon(Icons.search,
                            size: 16,
                            color: AdminThemeColors.of(context).muted),
                        filled: true,
                        fillColor: AdminThemeColors.of(context).surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                              color: AdminThemeColors.of(context).border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                              color: AdminThemeColors.of(context).border),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                    ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ['all', 'active', 'inactive'].map((f) {
                    final active = _filter == f;
                    final labels = {
                      'all': 'Todos',
                      'active': 'Ativo',
                      'inactive': 'Inativo'
                    };
                    return GestureDetector(
                      onTap: () => setState(() => _filter = f),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: active
                              ? AdminThemeColors.of(context).surface2
                              : AdminThemeColors.of(context).surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AdminThemeColors.of(context).border),
                        ),
                        child: Text(labels[f]!,
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: active
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: active
                                    ? AdminThemeColors.of(context).text
                                    : AdminThemeColors.of(context).muted)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 280,
                  height: 40,
                  child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AdminThemeColors.of(context).text),
                      decoration: InputDecoration(
                        hintText: 'Buscar cliente...',
                        hintStyle: GoogleFonts.inter(
                            fontSize: 13,
                            color: AdminThemeColors.of(context).muted),
                        prefixIcon: Icon(Icons.search,
                            size: 16,
                            color: AdminThemeColors.of(context).muted),
                        filled: true,
                        fillColor: AdminThemeColors.of(context).surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                              color: AdminThemeColors.of(context).border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                              color: AdminThemeColors.of(context).border),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                    ),
                ),
                ...['all', 'active', 'inactive'].map((f) {
                  final active = _filter == f;
                  final labels = {
                    'all': 'Todos',
                    'active': 'Ativo',
                    'inactive': 'Inativo'
                  };
                  return GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: active
                            ? AdminThemeColors.of(context).surface2
                            : AdminThemeColors.of(context).surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AdminThemeColors.of(context).border),
                      ),
                      child: Text(labels[f]!,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: active
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: active
                                  ? AdminThemeColors.of(context).text
                                  : AdminThemeColors.of(context).muted)),
                    ),
                  );
                }),
              ],
            ),
          const SizedBox(height: 24),
          alunosAsync.when(
            data: (alunos) => _buildGrid(alunos),
            loading: () => Center(
                child: CircularProgressIndicator(
                    color: AdminThemeColors.of(context).lime)),
            error: (_, __) => Text('Erro',
                style: GoogleFonts.inter(color: AdminThemeColors.of(context).muted)),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<UserModel> alunos) {
    final filtered = alunos.where((a) {
      if (_filter == 'active') {
        return a.ultimaAtividade != null &&
            DateTime.now().difference(a.ultimaAtividade!).inDays < 30;
      }
      if (_filter == 'inactive') {
        return a.ultimaAtividade == null ||
            DateTime.now().difference(a.ultimaAtividade!).inDays >= 30;
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.person_search, size: 48, color: AdminThemeColors.of(context).muted),
              const SizedBox(height: 12),
              Text('Nenhum cliente encontrado',
                  style: GoogleFonts.inter(color: AdminThemeColors.of(context).muted)),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(builder: (_, constraints) {
      final cols = constraints.maxWidth > 900
          ? 3
          : (constraints.maxWidth > 500 ? 2 : 1);
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: filtered.map((a) {
          final w = (constraints.maxWidth - 16 * (cols - 1)) / cols;
          return SizedBox(width: w, child: _clientCard(a));
        }).toList(),
      );
    });
  }

  Widget _clientCard(UserModel aluno) {
    return Material(
      color: AdminThemeColors.of(context).surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => widget.onSelect(aluno),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AdminThemeColors.of(context).border),
            boxShadow: [
              BoxShadow(
                color: AdminThemeColors.of(context).shadow,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AdminThemeColors.of(context).surface2,
                    child: Text(
                      aluno.nome.isNotEmpty
                          ? aluno.nome[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.barlowCondensed(
                          color: AdminThemeColors.of(context).lime,
                          fontWeight: FontWeight.w700,
                          fontSize: 15),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(aluno.nome,
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AdminThemeColors.of(context).text)),
                        Text(
                            '${aluno.pesoAtual?.toStringAsFixed(1) ?? '--'} kg',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AdminThemeColors.of(context).muted)),
                      ],
                    ),
                  ),
                  // Botão de excluir
                  GestureDetector(
                    onTap: () => _confirmDeleteStudent(aluno),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _miniStat(
                      'PESO', '${aluno.pesoAtual?.toStringAsFixed(0) ?? '--'}kg'),
                  const SizedBox(width: 8),
                  _miniStat(
                      'ALTURA', '${aluno.altura?.toStringAsFixed(0) ?? '--'}cm'),
                  const SizedBox(width: 8),
                  _miniStat('IMC',
                      aluno.imc?.toStringAsFixed(1) ?? '--'),
                ].map((e) => Expanded(child: e)).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.email_outlined,
                      size: 12, color: AdminThemeColors.of(context).muted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(aluno.email,
                        style: GoogleFonts.inter(
                            fontSize: 11, color: AdminThemeColors.of(context).muted),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Icon(Icons.chevron_right,
                      size: 14, color: AdminThemeColors.of(context).muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AdminThemeColors.of(context).bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AdminThemeColors.of(context).muted,
                  letterSpacing: 0.06)),
          Text(value,
              style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AdminThemeColors.of(context).text)),
        ],
      ),
    );
  }

  // ─── Create Student Dialog ──────────────────────────────────────

  Future<void> _showCreateStudentDialog() async {
    final nomeCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String genero = 'feminino';
    bool obscurePassword = true;
    bool loading = false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AdminThemeColors.of(context).surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: AdminThemeColors.of(context).border)),
          title: Text('Novo Cliente',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, color: AdminThemeColors.of(context).text)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeCtrl,
                style: GoogleFonts.inter(color: AdminThemeColors.of(context).text),
                decoration: InputDecoration(
                  labelText: 'Nome completo',
                  labelStyle: GoogleFonts.inter(color: AdminThemeColors.of(context).muted),
                  filled: true,
                  fillColor: AdminThemeColors.of(context).bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),                        borderSide:
                            BorderSide(color: AdminThemeColors.of(context).border),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.inter(color: AdminThemeColors.of(context).text),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: GoogleFonts.inter(color: AdminThemeColors.of(context).muted),
                  filled: true,
                  fillColor: AdminThemeColors.of(context).bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),                        borderSide:
                            BorderSide(color: AdminThemeColors.of(context).border),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Password
              TextField(
                controller: passwordCtrl,
                obscureText: obscurePassword,
                style: GoogleFonts.inter(color: AdminThemeColors.of(context).text),
                decoration: InputDecoration(
                  labelText: 'Senha (opcional)',
                  labelStyle: GoogleFonts.inter(color: AdminThemeColors.of(context).muted),
                  filled: true,
                  fillColor: AdminThemeColors.of(context).bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AdminThemeColors.of(context).border),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                      color: AdminThemeColors.of(context).muted,
                    ),
                    onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: genero,
                decoration: InputDecoration(
                  labelText: 'Género',
                  labelStyle: GoogleFonts.inter(color: AdminThemeColors.of(context).muted),
                  filled: true,
                  fillColor: AdminThemeColors.of(context).bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AdminThemeColors.of(context).border),
                  ),
                ),
                dropdownColor: AdminThemeColors.of(context).surface,
                style: GoogleFonts.inter(color: AdminThemeColors.of(context).text),
                items: const [
                  DropdownMenuItem(value: 'feminino', child: Text('🌸 Feminino')),
                  DropdownMenuItem(value: 'masculino', child: Text('💪 Masculino')),
                ],
                onChanged: (v) => setDialogState(() => genero = v ?? 'feminino'),
              ),
              if (loading) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(color: AdminThemeColors.of(context).lime),
            ],
            ],
          ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Future.microtask(() => Navigator.pop(ctx)),
              child: Text('Cancelar',
                  style: GoogleFonts.inter(color: AdminThemeColors.of(context).muted)),
            ),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (nomeCtrl.text.trim().isEmpty ||
                          emailCtrl.text.trim().isEmpty) return;
                      final pw = passwordCtrl.text.trim();
                      if (pw.isNotEmpty && pw.length < 6) {
                        showAppNotification(context,
                            'A password deve ter pelo menos 6 caracteres.',
                            type: NotificationType.error);
                        return;
                      }
                      setDialogState(() => loading = true);
                      try {
                        // Obtém token fresco para verificação manual na Cloud Function
                        final token = await FirebaseAuth.instance.currentUser?.getIdToken(true);
                        final adminId = FirebaseAuth.instance.currentUser?.uid ?? '';
                        final body = <String, dynamic>{
                          'nome': nomeCtrl.text.trim(),
                          'email': emailCtrl.text.trim(),
                          'personalId': adminId,
                          'genero': genero,
                          'authToken': token ?? '',
                        };
                        if (pw.isNotEmpty) body['password'] = pw;

                        final response = await http.post(
                          Uri.parse('https://europe-west1-gymbt-4ef87.cloudfunctions.net/createStudentHttp'),
                          headers: {'Content-Type': 'application/json'},
                          body: json.encode(body),
                        );
                        if (!mounted) return;
                        if (response.statusCode != 200) {
                          final errData = json.decode(response.body) as Map<String, dynamic>;
                          final err = errData['error'] as Map<String, dynamic>?;
                          final msg = err?['message'] as String? ?? 'Erro desconhecido';
                          setDialogState(() => loading = false);
                          if (msg.contains('unauthenticated') || msg.contains('Login necessário') || msg.contains('Token inválido')) {
                            showAppNotification(context, 'Erro de autenticação. Tenta sair e entrar novamente.', type: NotificationType.error);
                          } else if (msg.contains('weak-password') || msg.contains('Password should be')) {
                            showAppNotification(context, 'Password muito fraca. Usa pelo menos 6 caracteres.', type: NotificationType.error);
                          } else {
                            showAppNotification(context, 'Erro ao criar aluno: $msg', type: NotificationType.error);
                          }
                          return;
                        }
                        final data = json.decode(response.body) as Map<String, dynamic>;
                        setDialogState(() => loading = false);
                        Future.microtask(() => Navigator.pop(ctx, {
                          'uid': data['uid'] as String,
                          'email': data['email'] as String,
                          'password': data['temporaryPassword'] as String?,
                          'alreadyExists': data['alreadyExists'] == true,
                          'created': data['created'] == true,
                        }));
                      } catch (e) {
                        setDialogState(() => loading = false);
                        showAppNotification(context, 'Erro ao criar aluno: $e', type: NotificationType.error);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminThemeColors.of(context).lime,
                foregroundColor: AdminThemeColors.of(context).bg,
              ),
              child: Text('Criar',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      ref.invalidate(alunosListProvider);
      // Espera o diálogo fechar antes de mostrar notificação
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final alreadyExists = result['alreadyExists'] == true;
        final hasPassword = result['password'] != null;
        if (alreadyExists) {
          showAppNotification(
            context,
            'Aluno "${result['email']}" já existia. Documento atualizado.',
            type: NotificationType.success,
          );
        } else if (hasPassword) {
          showAppNotification(
            context,
            'Aluno criado! Password: ${result['password']}',
            type: NotificationType.success,
            duration: const Duration(seconds: 8),
          );
        } else {
          showAppNotification(
            context,
            'Aluno "${result['email']}" criado com sucesso!',
            type: NotificationType.success,
          );
        }
      });
    }
  }

  Future<void> _confirmDeleteStudent(UserModel aluno) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminThemeColors.of(context).surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Eliminar aluno',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AdminThemeColors.of(context).text)),
        content: Text('Tens a certeza que queres eliminar "${aluno.nome}"?\n\nEsta ação é irreversível e remove todos os dados do aluno.',
            style: GoogleFonts.inter(color: AdminThemeColors.of(context).muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: GoogleFonts.inter(color: AdminThemeColors.of(context).muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Eliminar', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _deleteStudent(aluno);
    }
  }

  Future<void> _deleteStudent(UserModel aluno) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken(true);
      final response = await http.post(
        Uri.parse('https://europe-west1-gymbt-4ef87.cloudfunctions.net/deleteStudentHttp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': aluno.uid,
          'authToken': token ?? '',
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        ref.invalidate(alunosListProvider);
        showAppNotification(context, 'Aluno "${aluno.nome}" eliminado.', type: NotificationType.success);
      } else {
        final errData = json.decode(response.body) as Map<String, dynamic>;
        final err = errData['error'] as Map<String, dynamic>?;
        showAppNotification(context, err?['message'] ?? 'Erro ao eliminar.', type: NotificationType.error);
      }
    } catch (e) {
      if (mounted) {
        showAppNotification(context, 'Erro ao eliminar: $e', type: NotificationType.error);
      }
    }
  }
}

// ─── Client Detail View ───────────────────────────────────────────

class _ClientDetailView extends ConsumerStatefulWidget {
  final UserModel client;
  final VoidCallback onBack;
  final bool isMobile;
  const _ClientDetailView({required this.client, required this.onBack, this.isMobile = false});

  @override
  ConsumerState<_ClientDetailView> createState() => _ClientDetailViewState();
}

class _ClientDetailViewState extends ConsumerState<_ClientDetailView> {
  String _tab = 'overview';
  bool _requestingProgress = false;
  bool _personalIdSet = false;

  @override
  void initState() {
    super.initState();
    // Garante que o personalId é definido assim que o admin abre o perfil do aluno.
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensurePersonalId());
  }

  /// Garante que o aluno tem o personalId definido para o chat funcionar.
  Future<void> _ensurePersonalId() async {
    if (_personalIdSet) return;
    if (widget.client.personalId != null && widget.client.personalId!.isNotEmpty) {
      _personalIdSet = true;
      return;
    }
    final adminId = FirebaseAuth.instance.currentUser?.uid;
    if (adminId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.client.uid)
          .set({'personalId': adminId}, SetOptions(merge: true));
      _personalIdSet = true;
    } catch (_) {}
  }

  EdgeInsets get _pad => EdgeInsets.all(widget.isMobile ? 16 : 36);

  Widget _requestProgressButton(UserModel client) {
    final isMobile = widget.isMobile;
    return ElevatedButton.icon(
      onPressed: _requestingProgress ? null : () => _requestProgress(client),
      icon: _requestingProgress
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.add_chart, size: 14),
      label: Text(
        _requestingProgress ? 'A enviar...' : 'SOLICITAR PROGRESSO',
        style: GoogleFonts.inter(
          fontSize: isMobile ? 9 : 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.04,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AdminThemeColors.of(context).lime,
        foregroundColor: AdminThemeColors.of(context).bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 8 : 12, vertical: isMobile ? 6 : 8),
      ),
    );
  }

  Future<void> _requestProgress(UserModel client) async {
    setState(() => _requestingProgress = true);
    try {
      final functions =
          FirebaseFunctions.instanceFor(region: 'europe-west1');
      final callable = functions.httpsCallable('requestProgress');
      final result = await callable.call<Map<String, dynamic>>({
        'userId': client.uid,
      });
      if (mounted) {
        showAppNotification(
          context,
          (result.data['message'] as String?) ??
              'Pedido de progresso enviado para ${client.nome}',
          type: NotificationType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showAppNotification(
          context,
          'Erro ao solicitar progresso. Tenta novamente.',
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _requestingProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.client;
    return SingleChildScrollView(
      padding: _pad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: widget.onBack,
            child: Row(
              children: [
                Icon(Icons.arrow_back,
                    size: 14, color: AdminThemeColors.of(context).muted),
                const SizedBox(width: 6),
                Text('Clientes',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AdminThemeColors.of(context).muted)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Header
          _buildClientHeader(c),
          const SizedBox(height: 20),
          // Tabs — scrollable on mobile
          _buildTabs(),
          const SizedBox(height: 20),
          if (_tab == 'overview') _buildOverview(),
          if (_tab == 'progresso') _buildProgressTab(),
          if (_tab == 'workout') ...[
            _buildLoadProgressionChart(),
            const SizedBox(height: 20),
            SizedBox(
              height: 600,
              child: WorkoutEditor(aluno: widget.client),
            ),
          ],
          if (_tab == 'nutrition')
            SizedBox(
              height: 600,
              child: NutritionEditor(aluno: widget.client),
            ),
          if (_tab == 'chat')
            SizedBox(
              height: 600,
              child: ChatScreen(
                chatPartnerId: widget.client.uid,
                chatPartnerName: widget.client.nome,
                key: ValueKey('admin_chat_${widget.client.uid}'),
              ),
            ),
          if (_tab == 'agenda') _buildAgendaTab(c),
        ],
      ),
    );
  }

  Widget _buildClientHeader(UserModel c) {
    final isMobile = widget.isMobile;
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: AdminThemeColors.of(context).surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminThemeColors.of(context).border),
        boxShadow: [
          BoxShadow(
            color: AdminThemeColors.of(context).shadow,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AdminThemeColors.of(context).surface2,
                      child: Text(
                        c.nome.isNotEmpty
                            ? c.nome
                                .substring(0, c.nome.length >= 2 ? 2 : 1)
                                .toUpperCase()
                            : '?',
                        style: GoogleFonts.barlowCondensed(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AdminThemeColors.of(context).lime),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(c.nome.toUpperCase(),
                          style: GoogleFonts.barlowCondensed(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.01,
                              color: AdminThemeColors.of(context).text)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.isOnline
                        ? AdminThemeColors.of(context).blue.withValues(alpha: 0.12)
                        : AdminThemeColors.of(context).limeDim,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(c.tipoClienteDisplay,
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: c.isOnline
                              ? AdminThemeColors.of(context).blue
                              : AdminThemeColors.of(context).lime)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                          '${c.pesoAtual?.toStringAsFixed(1) ?? '-'}kg · ${c.altura?.toStringAsFixed(0) ?? '-'}cm · IMC: ${c.imc?.toStringAsFixed(1) ?? '-'}',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AdminThemeColors.of(context).muted)),
                    ),
                    _requestProgressButton(c),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AdminThemeColors.of(context).surface2,
                  child: Text(
                    c.nome.isNotEmpty
                        ? c.nome
                            .substring(0, c.nome.length >= 2 ? 2 : 1)
                            .toUpperCase()
                        : '?',
                    style: GoogleFonts.barlowCondensed(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AdminThemeColors.of(context).lime),
                  ),
                ),
                const SizedBox(width: 18),                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(c.nome.toUpperCase(),
                                  style: GoogleFonts.barlowCondensed(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.01,
                                      color: AdminThemeColors.of(context).text)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: c.isOnline
                                    ? AdminThemeColors.of(context).blue.withValues(alpha: 0.12)
                                    : AdminThemeColors.of(context).limeDim,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: c.isOnline
                                      ? AdminThemeColors.of(context).blue.withValues(alpha: 0.3)
                                      : AdminThemeColors.of(context).lime.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(c.tipoClienteDisplay,
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: c.isOnline
                                          ? AdminThemeColors.of(context).blue
                                          : AdminThemeColors.of(context).lime)),
                            ),
                          ],
                        ),
                        Text(
                          '${c.pesoAtual?.toStringAsFixed(1) ?? '-'}kg · ${c.altura?.toStringAsFixed(0) ?? '-'}cm · IMC: ${c.imc?.toStringAsFixed(1) ?? '-'}',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AdminThemeColors.of(context).muted)),
                    ],
                  ),
                ),
                _requestProgressButton(c),
              ],
            ),
    );
  }

  Widget _buildTabs() {
    final tabs = [
      ('overview', 'Visão Geral', Icons.person),
      ('progresso', 'Progresso', Icons.trending_up),
      ('workout', 'Treino', Icons.fitness_center),
      ('nutrition', 'Nutrição', Icons.restaurant),
      ('chat', 'Chat', Icons.chat),
      ('agenda', 'Agenda', Icons.calendar_today),
    ];
    final row = Row(
      children: [
        for (final t in tabs) ...[
          _tabBtn(t.$1, widget.isMobile && t.$2 != 'Visão Geral' ? '' : t.$2, t.$3),
          const SizedBox(width: 4),
        ],
      ],
    );
    if (widget.isMobile) {
      return SingleChildScrollView(scrollDirection: Axis.horizontal, child: row);
    }
    return row;
  }

  Widget _tabBtn(String id, String label, IconData icon) {
    final active = _tab == id;
    final isMobile = widget.isMobile;
    final tabWidget = GestureDetector(
      onTap: () {
        setState(() => _tab = id);
        if (id == 'chat') _ensurePersonalId();
      },
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 16, vertical: isMobile ? 8 : 10),
        decoration: BoxDecoration(
          color: active
              ? AdminThemeColors.of(context).limeDim
              : AdminThemeColors.of(context).surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active
                  ? AdminThemeColors.of(context).lime
                  : AdminThemeColors.of(context).border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: isMobile ? 18 : 14,
                color: active
                    ? AdminThemeColors.of(context).lime
                    : AdminThemeColors.of(context).muted),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: isMobile ? 11 : 13,
                      fontWeight:
                          active ? FontWeight.w600 : FontWeight.w400,
                      color: active
                          ? AdminThemeColors.of(context).lime
                          : AdminThemeColors.of(context).muted)),
            ],
          ],
        ),
      ),
    );
    if (label.isEmpty) {
      final tooltipLabels = {
        'overview': 'Visão Geral',
        'progresso': 'Progresso',
        'workout': 'Treino',
        'nutrition': 'Nutrição',
        'chat': 'Chat',
        'agenda': 'Agenda',
      };
      return Tooltip(message: tooltipLabels[id] ?? id, child: tabWidget);
    }
    return tabWidget;
  }

  Widget _buildLoadProgressionChart() {
    final c = widget.client;
    if (!c.isOnline) return const SizedBox.shrink();

    final progressionAsync = ref.watch(onlineProgressionProvider(c.uid));

    return progressionAsync.when(
      data: (prog) {
        if (prog.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: AdminThemeColors.of(context).surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AdminThemeColors.of(context).border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.trending_up, size: 16, color: AdminThemeColors.of(context).blue),
                  const SizedBox(width: 6),
                  Text('PROGRESSÃO (ONLINE)',
                      style: GoogleFonts.barlowCondensed(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.03,
                          color: AdminThemeColors.of(context).text)),
                ],
              ),
              const SizedBox(height: 12),
              ...prog.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.exerciseName,
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AdminThemeColors.of(context).text)),
                              const SizedBox(height: 2),
                              Text(
                                '${p.cargaAnterior?.toStringAsFixed(1) ?? '-'} → ${p.cargaAtual?.toStringAsFixed(1) ?? '-'} kg',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AdminThemeColors.of(context).muted),
                              ),
                            ],
                          ),
                        ),
                        if (p.progrediu)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AdminThemeColors.of(context).lime.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('+${p.aumentoKg!.toStringAsFixed(1)}kg',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AdminThemeColors.of(context).lime)),
                          )
                        else if (p.manteve)
                          Text('= manteve',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AdminThemeColors.of(context).muted))
                        else
                          Text('novo',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AdminThemeColors.of(context).blue)),
                      ],
                    ),
                  )),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildOverview() {
    final c = widget.client;
    return Column(
      children: [
        LayoutBuilder(builder: (_, constraints) {
          final wide = constraints.maxWidth > 700;
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _buildWeightChart(),
                ),
                const SizedBox(width: 20),
                SizedBox(width: 280, child: _buildInfoCards(c)),
              ],
            );
          }
          return Column(
            children: [
              _buildWeightChart(),
              const SizedBox(height: 16),
              _buildInfoCards(c),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildWeightChart() {
    final progressAsync = ref.watch(adminProgressProvider(widget.client.uid));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminThemeColors.of(context).surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminThemeColors.of(context).border),
        boxShadow: [
          BoxShadow(
            color: AdminThemeColors.of(context).shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('EVOLUÇÃO DE PESO',
              style: GoogleFonts.barlowCondensed(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.03,
                  color: AdminThemeColors.of(context).text)),
          const SizedBox(height: 16),
          progressAsync.when(
            data: (progressList) {
              final weightEntries = progressList
                  .where((p) => p.peso != null)
                  .toList()
                ..sort((a, b) => a.data.compareTo(b.data));

              if (weightEntries.isEmpty) {
                return SizedBox(
                  height: 180,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.show_chart,
                            size: 40, color: AdminThemeColors.of(context).muted),
                        const SizedBox(height: 8),
                        Text('Sem dados de peso registados',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AdminThemeColors.of(context).muted)),
                      ],
                    ),
                  ),
                );
              }

              return SizedBox(
                height: 180,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: weightEntries
                            .asMap()
                            .entries
                            .map((e) => FlSpot(
                                e.key.toDouble(), e.value.peso!))
                            .toList(),
                        isCurved: true,
                        color: AdminThemeColors.of(context).lime,
                        barWidth: 2,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AdminThemeColors.of(context).lime
                              .withValues(alpha: 0.08),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => SizedBox(
              height: 180,
              child: Center(
                child: CircularProgressIndicator(
                    color: AdminThemeColors.of(context).lime),
              ),
            ),
            error: (_, __) => SizedBox(
              height: 180,
              child: Center(
                child: Text('Erro ao carregar dados',
                    style: GoogleFonts.inter(
                        color: AdminThemeColors.of(context).muted)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTab() {
    final progressAsync = ref.watch(adminProgressProvider(widget.client.uid));

    return progressAsync.when(
      data: (progressList) {
        if (progressList.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(60),
            decoration: BoxDecoration(
              color: AdminThemeColors.of(context).surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AdminThemeColors.of(context).border),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.trending_up,
                      size: 48, color: AdminThemeColors.of(context).muted),
                  const SizedBox(height: 12),
                  Text('Nenhum registo de progresso',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AdminThemeColors.of(context).muted)),
                  const SizedBox(height: 4),
                  Text(
                    'Solicita uma avaliação ao aluno',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AdminThemeColors.of(context).muted),
                  ),
                ],
              ),
            ),
          );
        }

        final sorted = List<ProgressModel>.from(progressList)
          ..sort((a, b) => b.data.compareTo(a.data)); // mais recente primeiro

        return Column(
          children: [
            // ── Gráfico de Peso ──
            _buildWeightChart(),
            const SizedBox(height: 20),
            // ── Comparação Antes/Depois ──
            if (sorted.where((p) => p.fotos.isNotEmpty).length >= 2)
              _buildComparisonButton(sorted),
            const SizedBox(height: 20),
            // ── Timeline de avaliações ──
            ...sorted.map((p) => _buildProgressCard(p)),
          ],
        );
      },
      loading: () => Center(
        child:
            CircularProgressIndicator(color: AdminThemeColors.of(context).lime),
      ),
      error: (_, __) => Center(
        child: Text('Erro ao carregar progresso',
            style:
                GoogleFonts.inter(color: AdminThemeColors.of(context).muted)),
      ),
    );
  }

  Widget _buildProgressCard(ProgressModel progress) {
    final dateFormatted =
        DateFormat('d MMM yyyy', 'pt').format(progress.data);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminThemeColors.of(context).surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminThemeColors.of(context).border),
        boxShadow: [
          BoxShadow(
            color: AdminThemeColors.of(context).shadow,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Data + Peso
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AdminThemeColors.of(context).limeDim,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  dateFormatted.toUpperCase(),
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AdminThemeColors.of(context).lime,
                  ),
                ),
              ),
              const Spacer(),
              if (progress.peso != null)
                Text(
                  '${progress.peso!.toStringAsFixed(1)} kg',
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AdminThemeColors.of(context).text,
                  ),
                ),
            ],
          ),
          // Medidas
          if (progress.medidas.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: progress.medidas.entries.map((e) {
                return Text(
                  '${e.key}: ${e.value.toStringAsFixed(1)} cm',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AdminThemeColors.of(context).muted,
                  ),
                );
              }).toList(),
            ),
          ],
          // Fotos
          if (progress.fotos.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: progress.fotos.map((foto) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    foto,
                    width: 120,
                    height: 150,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 120,
                        height: 150,
                        color: AdminThemeColors.of(context).surface2,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AdminThemeColors.of(context).lime,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      width: 120,
                      height: 150,
                      color: AdminThemeColors.of(context).surface2,
                      child: Icon(Icons.broken_image,
                          color: AdminThemeColors.of(context).muted),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComparisonButton(List<ProgressModel> sorted) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showComparison(sorted),
        icon: const Icon(Icons.compare, size: 16),
        label: Text('COMPARAR ANTES / DEPOIS',
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.03)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AdminThemeColors.of(context).lime,
          side: BorderSide(color: AdminThemeColors.of(context).lime.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  void _showComparison(List<ProgressModel> sorted) {
    final withPhotos = sorted.where((p) => p.fotos.isNotEmpty).toList();
    if (withPhotos.length < 2) return;

    int beforeIdx = withPhotos.length - 1; // mais antigo
    int afterIdx = 0; // mais recente

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AdminThemeColors.of(context).surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: AdminThemeColors.of(context).border)),
          title: Row(
            children: [
              Icon(Icons.compare,
                  color: AdminThemeColors.of(context).lime, size: 20),
              const SizedBox(width: 8),
              Text('Comparação Antes / Depois',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AdminThemeColors.of(context).text)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Legendas
                Row(
                  children: [
                    Expanded(
                      child: Text('ANTES',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.barlowCondensed(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AdminThemeColors.of(context).muted))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('DEPOIS',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.barlowCondensed(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AdminThemeColors.of(context).lime))),
                  ],
                ),
                const SizedBox(height: 8),
                // Slider Antes/Depois
                ImageComparisonSlider(
                  beforeImage: withPhotos[beforeIdx].fotos.first,
                  afterImage: withPhotos[afterIdx].fotos.first,
                  height: 280,
                  dividerColor: AdminThemeColors.of(context).lime,
                ),
                const SizedBox(height: 8),
                // Datas e pesos abaixo do slider
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(DateFormat('d MMM yyyy', 'pt').format(withPhotos[beforeIdx].data),
                              style: GoogleFonts.inter(fontSize: 10, color: AdminThemeColors.of(context).muted)),
                          if (withPhotos[beforeIdx].peso != null)
                            Text('${withPhotos[beforeIdx].peso!.toStringAsFixed(1)} kg',
                                style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: AdminThemeColors.of(context).muted)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(DateFormat('d MMM yyyy', 'pt').format(withPhotos[afterIdx].data),
                              style: GoogleFonts.inter(fontSize: 10, color: AdminThemeColors.of(context).lime)),
                          if (withPhotos[afterIdx].peso != null)
                            Text('${withPhotos[afterIdx].peso!.toStringAsFixed(1)} kg',
                                style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: AdminThemeColors.of(context).lime)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Seletores
                Text('Seleciona as datas:',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AdminThemeColors.of(context).muted)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: beforeIdx,
                        decoration: InputDecoration(
                          labelText: 'Antes',
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        items: withPhotos
                            .asMap()
                            .entries
                            .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(
                                    DateFormat('dd/MM/yy')
                                        .format(e.value.data),
                                    style: GoogleFonts.inter(fontSize: 12))))
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => beforeIdx = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: afterIdx,
                        decoration: InputDecoration(
                          labelText: 'Depois',
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        items: withPhotos
                            .asMap()
                            .entries
                            .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(
                                    DateFormat('dd/MM/yy')
                                        .format(e.value.data),
                                    style: GoogleFonts.inter(fontSize: 12))))
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => afterIdx = v!),
                      ),
                    ),
                  ],
                ),
                // Delta peso
                if (withPhotos[beforeIdx].peso != null &&
                    withPhotos[afterIdx].peso != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Diferença: ${(withPhotos[afterIdx].peso! - withPhotos[beforeIdx].peso!).toStringAsFixed(1)} kg',
                    style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AdminThemeColors.of(context).lime),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Fechar',
                  style: GoogleFonts.inter(
                      color: AdminThemeColors.of(context).muted)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgendaTab(UserModel c) {
    final bookingsAsync = ref.watch(adminTrainerBookingsProvider(FirebaseAuth.instance.currentUser?.uid ?? ''));
    final isMobile = widget.isMobile;

    return bookingsAsync.when(
      data: (bookings) {
        final clientBookings = bookings
            .where((b) => b.studentId == c.uid)
            .toList()
          ..sort((a, b) => b.data.compareTo(a.data));

        if (clientBookings.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: AdminThemeColors.of(context).surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AdminThemeColors.of(context).border),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.calendar_today, size: 48, color: AdminThemeColors.of(context).muted),
                  const SizedBox(height: 12),
                  Text('Nenhuma aula marcada',
                      style: GoogleFonts.inter(fontSize: 14, color: AdminThemeColors.of(context).muted)),
                  const SizedBox(height: 4),
                  Text('O aluno ainda não marcou sessões.',
                      style: GoogleFonts.inter(fontSize: 12, color: AdminThemeColors.of(context).muted)),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            if (isMobile)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AdminThemeColors.of(context).limeDim,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${clientBookings.length} marcações',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AdminThemeColors.of(context).lime)),
                    ),
                  ],
                ),
              ),
            ...clientBookings.map((b) => _buildBookingCard(b)),
          ],
        );
      },
      loading: () => Center(child: CircularProgressIndicator(color: AdminThemeColors.of(context).lime)),
      error: (_, __) => Center(child: Text('Erro', style: GoogleFonts.inter(color: AdminThemeColors.of(context).muted))),
    );
  }

  Widget _buildBookingCard(BookingModel booking) {
    final dateFormatted = DateFormat('EEE, d MMM yyyy', 'pt').format(booking.data);
    final statusColors = {
      'confirmed': AdminThemeColors.of(context).lime,
      'pending': AdminThemeColors.of(context).orange,
      'cancelled': Colors.red,
      'completed': AdminThemeColors.of(context).purple,
    };
    final statusLabels = {
      'confirmed': 'Confirmada',
      'pending': 'Pendente',
      'cancelled': 'Cancelada',
      'completed': 'Concluída',
    };
    final color = statusColors[booking.status] ?? AdminThemeColors.of(context).muted;
    final label = statusLabels[booking.status] ?? booking.status;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminThemeColors.of(context).surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminThemeColors.of(context).border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(booking.horaFormatada,
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 14, color: color)),
                Text(booking.fimFormatado,
                    style: GoogleFonts.inter(fontSize: 9, color: color.withValues(alpha: 0.7))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateFormatted.toUpperCase(),
                    style: GoogleFonts.barlowCondensed(fontSize: 13, fontWeight: FontWeight.w700, color: AdminThemeColors.of(context).text)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(booking.tipo == 'online' ? Icons.videocam : Icons.fitness_center,
                        size: 12, color: AdminThemeColors.of(context).muted),
                    const SizedBox(width: 4),
                    Text('${booking.tipo == "online" ? "Online" : "Presencial"} · ${booking.duracaoMinutos}min',
                        style: GoogleFonts.inter(fontSize: 11, color: AdminThemeColors.of(context).muted)),
                  ],
                ),
                if (booking.notas != null && booking.notas!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(booking.notas!,
                        style: GoogleFonts.inter(fontSize: 11, color: AdminThemeColors.of(context).muted)),
                  ),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
              ),
              if (booking.isPending) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _updateBookingStatus(booking, 'confirmed'),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AdminThemeColors.of(context).lime.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.check, size: 14, color: AdminThemeColors.of(context).lime),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _updateBookingStatus(booking, 'cancelled'),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.close, size: 14, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _updateBookingStatus(BookingModel booking, String status) async {
    try {
      await ref.read(bookingRepositoryProvider).updateBooking(booking.id, {'status': status});
      ref.invalidate(adminTrainerBookingsProvider(FirebaseAuth.instance.currentUser?.uid ?? ''));
      // Notificar o aluno (só para confirm/cancel)
      if (status == 'confirmed' || status == 'cancelled') {
        fireBookingNotification(booking, status);
      }
      if (mounted) {
        showAppNotification(context,
            status == 'confirmed' ? 'Aula confirmada!' : status == 'cancelled' ? 'Aula cancelada.' : 'Aula atualizada.',
            type: NotificationType.success);
      }
    } catch (_) {
      if (mounted) showAppNotification(context, 'Erro ao atualizar.', type: NotificationType.error);
    }
  }

  Widget _buildInfoCards(UserModel c) {
    return Column(
      children: [
        _infoCard('Dados do Aluno', [
          ('Peso', '${c.pesoAtual?.toStringAsFixed(1) ?? '--'} kg'),
          ('Altura', '${c.altura?.toStringAsFixed(0) ?? '--'} cm'),
          ('IMC', c.imc?.toStringAsFixed(1) ?? '--'),
          ('Categoria', c.imcCategory ?? '--'),
        ]),
        const SizedBox(height: 16),
        _infoCard('Contacto', [
          ('Email', c.email),
          ('ID', '${c.uid.substring(0, 8)}...'),
        ]),
      ],
    );
  }

  Widget _infoCard(String title, List<(String, String)> rows) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AdminThemeColors.of(context).surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminThemeColors.of(context).border),
        boxShadow: [
          BoxShadow(
            color: AdminThemeColors.of(context).shadow,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: GoogleFonts.barlowCondensed(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.05,
                  color: AdminThemeColors.of(context).muted)),
          const SizedBox(height: 12),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(r.$1,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AdminThemeColors.of(context).muted)),
                    Text(r.$2,
                        style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AdminThemeColors.of(context).text)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

}

// ─── Exercise Library View ────────────────────────────────────────

class _AdminExerciseLibrary extends ConsumerStatefulWidget {
  const _AdminExerciseLibrary();

  @override
  ConsumerState<_AdminExerciseLibrary> createState() =>
      _AdminExerciseLibraryState();
}

class _AdminExerciseLibraryState
    extends ConsumerState<_AdminExerciseLibrary> {
  String _search = '';
  String _muscle = 'Todos';
  String _categoria = 'Todas';

  static const _muscles = [
    'Todos', 'Peito', 'Costas', 'Quadríceps', 'Posterior',
    'Ombros', 'Bíceps', 'Tríceps', 'Core', 'Glúteos'
  ];
  static const _categorias = ['Todas', 'musculação', 'funcional', 'cardio'];

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(adminExercisesProvider);

    final isMobile = MediaQuery.of(context).size.width < 900;
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) ...[
            Text('BIBLIOTECA DE EXERCÍCIOS',
                style: _adminDisplay(context, 28)),
            Text(
                '${exercisesAsync.valueOrNull?.length ?? 0} exercícios',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AdminThemeColors.of(context).muted)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showAddExerciseDialog,
                icon: const Icon(Icons.add, size: 16),
                label: Text('NOVO EXERCÍCIO',
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminThemeColors.of(context).lime,
                  foregroundColor: AdminThemeColors.of(context).bg,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('BIBLIOTECA DE EXERCÍCIOS',
                          style: _adminDisplay(context, 40)),
                      Text(
                          '${exercisesAsync.valueOrNull?.length ?? 0} exercícios',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AdminThemeColors.of(context).muted)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddExerciseDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text('NOVO EXERCÍCIO',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminThemeColors.of(context).lime,
                    foregroundColor: AdminThemeColors.of(context).bg,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          // Search
          SizedBox(
            width: isMobile ? double.infinity : 360,
            height: 40,
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: GoogleFonts.inter(
                  fontSize: 13, color: AdminThemeColors.of(context).text),
              decoration: InputDecoration(
                hintText: 'Buscar exercício...',
                hintStyle: GoogleFonts.inter(
                    fontSize: 13, color: AdminThemeColors.of(context).muted),
                prefixIcon: Icon(Icons.search,
                    size: 16, color: AdminThemeColors.of(context).muted),
                filled: true,
                fillColor: AdminThemeColors.of(context).surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: AdminThemeColors.of(context).border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: AdminThemeColors.of(context).border)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _muscles.map((m) {
              final active = _muscle == m;
              return GestureDetector(
                onTap: () => setState(() => _muscle = m),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: active
                        ? AdminThemeColors.of(context).limeDim
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: active
                            ? AdminThemeColors.of(context).lime
                            : AdminThemeColors.of(context).border),
                  ),
                  child: Text(m,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: active
                              ? AdminThemeColors.of(context).lime
                              : AdminThemeColors.of(context).muted)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          // ── Category Filter ──
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _categorias.map((c) {
              final active = _categoria == c;
              final labels = {'Todas': 'Todas', 'musculação': 'Musculação', 'funcional': 'Funcional', 'cardio': 'Cardio'};
              return GestureDetector(
                onTap: () => setState(() => _categoria = c),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? AdminThemeColors.of(context).blue.withValues(alpha: 0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: active ? AdminThemeColors.of(context).blue : AdminThemeColors.of(context).border),
                  ),
                  child: Text(labels[c]!,
                      style: GoogleFonts.inter(fontSize: 12, color: active ? AdminThemeColors.of(context).blue : AdminThemeColors.of(context).muted)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          exercisesAsync.when(
            data: (exercises) {
              final filtered = exercises.where((e) {
                final name = (e['nome'] as String? ?? '').toLowerCase();
                final muscle = e['grupoMuscular'] as String? ?? '';
                final cat = e['categoria'] as String? ?? 'musculação';
                final matchSearch = name.contains(_search.toLowerCase());
                final matchMuscle = _muscle == 'Todos' || muscle == _muscle;
                final matchCategoria = _categoria == 'Todas' || cat.toLowerCase() == _categoria.toLowerCase();
                return matchSearch && matchMuscle && matchCategoria;
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(60),
                    child: Column(
                      children: [
                        Icon(Icons.fitness_center,
                            size: 48, color: AdminThemeColors.of(context).muted),
                        const SizedBox(height: 12),
                        Text('Nenhum exercício encontrado',
                            style: GoogleFonts.inter(
                                color: AdminThemeColors.of(context).muted)),
                      ],
                    ),
                  ),
                );
              }

              return LayoutBuilder(builder: (_, constraints) {
                final cols = constraints.maxWidth > 700
                    ? 3
                    : (constraints.maxWidth > 400 ? 2 : 1);
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: filtered.asMap().entries.map((entry) {
                    final i = entry.key;
                    final e = entry.value;
                    final w = (constraints.maxWidth - 14 * (cols - 1)) / cols;
                    final nome = e['nome'] as String? ?? '';
                    final grupo =
                        e['grupoMuscular'] as String? ?? 'Geral';
                    final equipamento =
                        e['equipamento'] as String? ?? 'Corpo';
                    return SizedBox(
                      width: w,
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AdminThemeColors.of(context).surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AdminThemeColors.of(context).border),
                          boxShadow: [
                            BoxShadow(
                              color: AdminThemeColors.of(context).shadow,
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                (i + 1).toString().padLeft(2, '0'),
                                style: GoogleFonts.barlowCondensed(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w900,
                                    color: AdminThemeColors.of(context).text
                                        .withValues(alpha: 0.04),
                                    height: 1)),
                            const SizedBox(height: 8),
                            Text(nome,
                                style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AdminThemeColors.of(context).text)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _exChip(
                                    grupo, AdminThemeColors.of(context).blue),
                                const SizedBox(width: 6),
                                _exChip(equipamento,
                                    AdminThemeColors.of(context).muted),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              });
            },
            loading: () => Center(
                child: CircularProgressIndicator(
                    color: AdminThemeColors.of(context).lime)),
            error: (_, __) => Center(
              child: Column(
                children: [
                  Icon(Icons.error_outline,
                      size: 32, color: AdminThemeColors.of(context).muted),
                  const SizedBox(height: 8),
                  Text('Erro ao carregar exercícios',
                      style: GoogleFonts.inter(
                          color: AdminThemeColors.of(context).muted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _exChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: GoogleFonts.inter(fontSize: 11, color: color)),
    );
  }

  Future<void> _showAddExerciseDialog() async {
    final nomeCtrl = TextEditingController();
    final equipCtrl = TextEditingController();
    String selectedGrupo = 'Peito';
    String selectedCategoria = 'musculação';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AdminThemeColors.of(context).surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: AdminThemeColors.of(context).border)),
          title: Text('Novo Exercício',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: AdminThemeColors.of(context).text)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomeCtrl,
                  style: GoogleFonts.inter(color: AdminThemeColors.of(context).text),
                  decoration: InputDecoration(
                    labelText: 'Nome do exercício',
                    labelStyle: GoogleFonts.inter(
                        color: AdminThemeColors.of(context).muted),
                    filled: true,
                    fillColor: AdminThemeColors.of(context).bg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedGrupo,
                  dropdownColor: AdminThemeColors.of(context).surface,
                  style: GoogleFonts.inter(color: AdminThemeColors.of(context).text),
                  decoration: InputDecoration(
                    labelText: 'Grupo Muscular',
                    labelStyle: GoogleFonts.inter(
                        color: AdminThemeColors.of(context).muted),
                    filled: true,
                    fillColor: AdminThemeColors.of(context).bg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  items: _muscles
                      .where((m) => m != 'Todos')
                      .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(m,
                              style: GoogleFonts.inter(
                                  color: AdminThemeColors.of(context).text))))
                      .toList(),
                  onChanged: (v) => setDialogState(
                      () => selectedGrupo = v ?? 'Peito'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategoria,
                  dropdownColor: AdminThemeColors.of(context).surface,
                  style: GoogleFonts.inter(color: AdminThemeColors.of(context).text),
                  decoration: InputDecoration(
                    labelText: 'Categoria',
                    labelStyle: GoogleFonts.inter(color: AdminThemeColors.of(context).muted),
                    filled: true,
                    fillColor: AdminThemeColors.of(context).bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'musculação', child: Text('Musculação')),
                    DropdownMenuItem(value: 'funcional', child: Text('Funcional')),
                    DropdownMenuItem(value: 'cardio', child: Text('Cardio')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedCategoria = v ?? 'musculação'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: equipCtrl,
                  style: GoogleFonts.inter(color: AdminThemeColors.of(context).text),
                  decoration: InputDecoration(
                    hintText: 'Ex: Barra, Halter, Máquina, Polia...',
                    labelText: 'Equipamento',
                    labelStyle: GoogleFonts.inter(
                        color: AdminThemeColors.of(context).muted),
                    filled: true,
                    fillColor: AdminThemeColors.of(context).bg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar',
                  style:
                      GoogleFonts.inter(color: AdminThemeColors.of(context).muted)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nomeCtrl.text.trim().isEmpty) return;
                try {
                  final firestore = FirebaseFirestore.instance;
                  await firestore.collection('exercicios').add({
                    'nome': nomeCtrl.text.trim(),
                    'grupoMuscular': selectedGrupo,
                    'equipamento': equipCtrl.text.trim().isNotEmpty
                        ? equipCtrl.text.trim()
                        : 'Corpo',
                    'categoria': selectedCategoria,
                  });
                  ref.invalidate(adminExercisesProvider);
                  if (mounted) Navigator.pop(ctx);
                } catch (_) {}
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminThemeColors.of(context).lime,
                foregroundColor: AdminThemeColors.of(context).bg,
              ),
              child: Text('Adicionar',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Food Library View ────────────────────────────────────────────

class _AdminFoodLibrary extends ConsumerStatefulWidget {
  const _AdminFoodLibrary();

  @override
  ConsumerState<_AdminFoodLibrary> createState() =>
      _AdminFoodLibraryState();
}

class _AdminFoodLibraryState extends ConsumerState<_AdminFoodLibrary> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final foodsAsync = ref.watch(adminFoodsSearchProvider(_search));
    final isMobile = MediaQuery.of(context).size.width < 900;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) ...[
            Text('BIBLIOTECA DE ALIMENTOS',
                style: _adminDisplay(context, 28)),
            Text(
                '${foodsAsync.valueOrNull?.length ?? 0} alimentos',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AdminThemeColors.of(context).muted)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showAddFoodDialog,
                icon: const Icon(Icons.add, size: 16),
                label: Text('NOVO ALIMENTO',
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminThemeColors.of(context).lime,
                  foregroundColor: AdminThemeColors.of(context).bg,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('BIBLIOTECA DE ALIMENTOS',
                          style: _adminDisplay(context, 40)),
                      Text(
                          '${foodsAsync.valueOrNull?.length ?? 0} alimentos',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AdminThemeColors.of(context).muted)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddFoodDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text('NOVO ALIMENTO',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminThemeColors.of(context).lime,
                    foregroundColor: AdminThemeColors.of(context).bg,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: 360,
            height: 40,
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: GoogleFonts.inter(
                  fontSize: 13, color: AdminThemeColors.of(context).text),
              decoration: InputDecoration(
                hintText: 'Buscar alimento...',
                hintStyle: GoogleFonts.inter(
                    fontSize: 13, color: AdminThemeColors.of(context).muted),
                prefixIcon: Icon(Icons.search,
                    size: 16, color: AdminThemeColors.of(context).muted),
                filled: true,
                fillColor: AdminThemeColors.of(context).surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: AdminThemeColors.of(context).border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: AdminThemeColors.of(context).border)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 24),
          foodsAsync.when(
            data: (foods) {
              if (foods.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(60),
                    child: Column(
                      children: [
                        Icon(Icons.restaurant,
                            size: 48, color: AdminThemeColors.of(context).muted),
                        const SizedBox(height: 12),
                        Text('Nenhum alimento encontrado',
                            style: GoogleFonts.inter(
                                color: AdminThemeColors.of(context).muted)),
                        const SizedBox(height: 8),
                        Text(
                            'Adiciona os primeiros alimentos à biblioteca.',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AdminThemeColors.of(context).muted)),
                      ],
                    ),
                  ),
                );
              }

              return LayoutBuilder(builder: (_, constraints) {
                final cols = constraints.maxWidth > 900
                    ? 4
                    : (constraints.maxWidth > 600
                        ? 3
                        : (constraints.maxWidth > 400 ? 2 : 1));
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: foods.map((food) {
                    final w =
                        (constraints.maxWidth - 14 * (cols - 1)) / cols;
                    return SizedBox(
                      width: w,
                      child: _foodCard(food),
                    );
                  }).toList(),
                );
              });
            },
            loading: () => Center(
                child: CircularProgressIndicator(
                    color: AdminThemeColors.of(context).lime)),
            error: (_, __) => Center(
              child: Text('Erro',
                  style: GoogleFonts.inter(
                      color: AdminThemeColors.of(context).muted)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _foodCard(FoodModel food) {
    final categoryColors = {
      'proteina': AdminThemeColors.of(context).blue,
      'hidrato': AdminThemeColors.of(context).orange,
      'gordura': AdminThemeColors.of(context).purple,
      'vegetal': AdminThemeColors.of(context).lime,
      'laticinio': AdminThemeColors.of(context).blue,
      'fruta': AdminThemeColors.of(context).lime,
      'bebida': AdminThemeColors.of(context).text,
    };
    final catColor =
        categoryColors[food.categoria] ?? AdminThemeColors.of(context).muted;
    final catLabel = food.categoria ?? 'Geral';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminThemeColors.of(context).surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminThemeColors.of(context).border),
        boxShadow: [
          BoxShadow(
            color: AdminThemeColors.of(context).shadow,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(food.nome,
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AdminThemeColors.of(context).text)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(catLabel.toUpperCase(),
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: catColor,
                        letterSpacing: 0.06)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
              '${food.caloriasPor100g.toStringAsFixed(0)} kcal / 100g',
              style: GoogleFonts.montserrat(
                  fontSize: 13, color: AdminThemeColors.of(context).lime)),
          const SizedBox(height: 6),
          Row(
            children: [
              if (food.proteinasPor100g != null)
                _macroChip(
                    'P: ${food.proteinasPor100g!.toStringAsFixed(1)}g',
                    AdminThemeColors.of(context).blue),
              if (food.hidratosPor100g != null) ...[
                const SizedBox(width: 4),
                _macroChip(
                    'C: ${food.hidratosPor100g!.toStringAsFixed(1)}g',
                    AdminThemeColors.of(context).orange),
              ],
              if (food.gordurasPor100g != null) ...[
                const SizedBox(width: 4),
                _macroChip(
                    'G: ${food.gordurasPor100g!.toStringAsFixed(1)}g',
                    AdminThemeColors.of(context).purple),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 10, color: color, fontWeight: FontWeight.w500)),
    );
  }

  Future<void> _showAddFoodDialog() async {
    final nomeCtrl = TextEditingController();
    final calCtrl = TextEditingController();
    final protCtrl = TextEditingController();
    final carbCtrl = TextEditingController();
    final gordCtrl = TextEditingController();
    String selectedCat = 'proteina';

    final categories = [
      'proteina', 'hidrato', 'gordura', 'vegetal',
      'laticinio', 'fruta', 'bebida', 'outro'
    ];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AdminThemeColors.of(context).surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: AdminThemeColors.of(context).border)),
          title: Text('Novo Alimento',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: AdminThemeColors.of(context).text)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomeCtrl,
                  style: GoogleFonts.inter(color: AdminThemeColors.of(context).text),
                  decoration: InputDecoration(
                    labelText: 'Nome do alimento',
                    labelStyle: GoogleFonts.inter(
                        color: AdminThemeColors.of(context).muted),
                    filled: true,
                    fillColor: AdminThemeColors.of(context).bg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: calCtrl,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.inter(color: AdminThemeColors.of(context).text),
                  decoration: InputDecoration(
                    labelText: 'Calorias (por 100g/ml)',
                    labelStyle: GoogleFonts.inter(
                        color: AdminThemeColors.of(context).muted),
                    filled: true,
                    fillColor: AdminThemeColors.of(context).bg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: protCtrl,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.inter(
                            color: AdminThemeColors.of(context).text),
                        decoration: InputDecoration(
                          labelText: 'Proteína (g)',
                          labelStyle: GoogleFonts.inter(
                              color: AdminThemeColors.of(context).muted,
                              fontSize: 12),
                          filled: true,
                          fillColor: AdminThemeColors.of(context).bg,
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: carbCtrl,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.inter(
                            color: AdminThemeColors.of(context).text),
                        decoration: InputDecoration(
                          labelText: 'Hidratos (g)',
                          labelStyle: GoogleFonts.inter(
                              color: AdminThemeColors.of(context).muted,
                              fontSize: 12),
                          filled: true,
                          fillColor: AdminThemeColors.of(context).bg,
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: gordCtrl,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.inter(
                            color: AdminThemeColors.of(context).text),
                        decoration: InputDecoration(
                          labelText: 'Gordura (g)',
                          labelStyle: GoogleFonts.inter(
                              color: AdminThemeColors.of(context).muted,
                              fontSize: 12),
                          filled: true,
                          fillColor: AdminThemeColors.of(context).bg,
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedCat,
                  dropdownColor: AdminThemeColors.of(context).surface,
                  style:
                      GoogleFonts.inter(color: AdminThemeColors.of(context).text),
                  decoration: InputDecoration(
                    labelText: 'Categoria',
                    labelStyle: GoogleFonts.inter(
                        color: AdminThemeColors.of(context).muted),
                    filled: true,
                    fillColor: AdminThemeColors.of(context).bg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  items: categories
                      .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c,
                              style: GoogleFonts.inter(
                                  color:
                                      AdminThemeColors.of(context).text))))
                      .toList(),
                  onChanged: (v) => setDialogState(
                      () => selectedCat = v ?? 'proteina'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar',
                  style: GoogleFonts.inter(
                      color: AdminThemeColors.of(context).muted)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nomeCtrl.text.trim().isEmpty) return;
                try {
                  await ref
                      .read(nutritionRepositoryProvider)
                      .addFood({
                    'nome': nomeCtrl.text.trim(),
                    'caloriasPor100g':
                        double.tryParse(calCtrl.text.replaceAll(',', '.')) ?? 0,
                    'proteinasPor100g':
                        double.tryParse(protCtrl.text.replaceAll(',', '.')),
                    'hidratosPor100g':
                        double.tryParse(carbCtrl.text.replaceAll(',', '.')),
                    'gordurasPor100g':
                        double.tryParse(gordCtrl.text.replaceAll(',', '.')),
                    'categoria': selectedCat,
                  });
                  ref.invalidate(adminFoodsProvider);
                  if (mounted) Navigator.pop(ctx);
                } catch (_) {}
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminThemeColors.of(context).lime,
                foregroundColor: AdminThemeColors.of(context).bg,
              ),
              child: Text('Adicionar',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Payments View ────────────────────────────────────────────────

class _AdminPaymentsView extends ConsumerStatefulWidget {
  const _AdminPaymentsView();

  @override
  ConsumerState<_AdminPaymentsView> createState() => _AdminPaymentsViewState();
}

class _AdminPaymentsViewState extends ConsumerState<_AdminPaymentsView> {
  final bool _creating = false;

  @override
  Widget build(BuildContext context) {
    final paymentsAsync = ref.watch(adminAllPaymentsProvider);
    final isMobile = MediaQuery.of(context).size.width < 900;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PAGAMENTOS', style: _adminDisplay(context, isMobile ? 28 : 40)),
                    const SizedBox(height: 4),
                    Text('Gestão de pagamentos e faturas via Stripe',
                        style: GoogleFonts.inter(fontSize: 14, color: AdminThemeColors.of(context).muted)),
                  ],
                ),
              ),
              if (!isMobile)
                ElevatedButton.icon(
                  onPressed: _creating ? null : () => _showCreatePaymentDialog(),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text('NOVO PAGAMENTO',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.02)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminThemeColors.of(context).lime,
                    foregroundColor: AdminThemeColors.of(context).bg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
            ],
          ),
          if (isMobile) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _creating ? null : () => _showCreatePaymentDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: Text('NOVO PAGAMENTO',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.02)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminThemeColors.of(context).lime,
                  foregroundColor: AdminThemeColors.of(context).bg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          paymentsAsync.when(
            data: (payments) => _buildPaymentsTable(payments),
            loading: () => Center(
              child: CircularProgressIndicator(color: AdminThemeColors.of(context).lime),
            ),
            error: (e, _) => Center(
              child: Column(
                children: [
                  Icon(Icons.error_outline, size: 40, color: AdminThemeColors.of(context).muted),
                  const SizedBox(height: 8),
                  Text('Erro ao carregar pagamentos',
                      style: GoogleFonts.inter(color: AdminThemeColors.of(context).muted)),
                  Text(e.toString(), style: GoogleFonts.inter(fontSize: 11, color: AdminThemeColors.of(context).muted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsTable(List<PaymentModel> payments) {
    if (payments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(60),
        decoration: _cardDecoration(),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.payment, size: 48, color: AdminThemeColors.of(context).muted),
              const SizedBox(height: 12),
              Text('Nenhum pagamento registado',
                  style: GoogleFonts.inter(fontSize: 14, color: AdminThemeColors.of(context).muted)),
              const SizedBox(height: 4),
              Text('Clica em "Novo Pagamento" para criar uma sessão de checkout',
                  style: GoogleFonts.inter(fontSize: 12, color: AdminThemeColors.of(context).muted)),
            ],
          ),
        ),
      );
    }

    final sorted = List<PaymentModel>.from(payments)
      ..sort((a, b) => b.data.compareTo(a.data));

    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AdminThemeColors.of(context).surface2,
              border: Border(bottom: BorderSide(color: AdminThemeColors.of(context).border)),
            ),
            child: Row(
              children: [
                _tableHeader('Aluno', flex: 3),
                _tableHeader('Descrição', flex: 2),
                _tableHeader('Valor', flex: 1),
                _tableHeader('Data', flex: 2),
                _tableHeader('Estado', flex: 1),
                const SizedBox(width: 60),
              ],
            ),
          ),
          // Rows
          ...sorted.map((p) => _paymentRow(p)),
        ],
      ),
    );
  }

  Widget _tableHeader(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.06, color: AdminThemeColors.of(context).muted)),
    );
  }

  Widget _paymentRow(PaymentModel payment) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final userAsync = ref.watch(
      FutureProvider<UserModel?>((ref) async {
        try {
          final doc = await FirebaseFirestore.instance.collection('users').doc(payment.userId).get();
          if (doc.exists) return UserModel.fromMap(doc.id, doc.data()!);
        } catch (_) {}
        return null;
      }),
    );

    final statusColors = {
      'paid': AdminThemeColors.of(context).lime,
      'pending': AdminThemeColors.of(context).orange,
      'failed': Colors.red,
      'refunded': AdminThemeColors.of(context).muted,
    };
    final statusLabels = {
      'paid': 'PAGO',
      'pending': 'PENDENTE',
      'failed': 'FALHOU',
      'refunded': 'REEMBOLSADO',
    };

    final statusColor = statusColors[payment.status] ?? AdminThemeColors.of(context).muted;
    final statusLabel = statusLabels[payment.status] ?? payment.status.toUpperCase();

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AdminThemeColors.of(context).border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: userAsync.when(
                    data: (u) => Text(u?.nome ?? 'Aluno', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AdminThemeColors.of(context).text)),
                    loading: () => Text('...', style: GoogleFonts.inter(color: AdminThemeColors.of(context).muted)),
                    error: (_, __) => Text('Aluno', style: GoogleFonts.inter(color: AdminThemeColors.of(context).muted)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(statusLabel, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(payment.descricao ?? 'Mensalidade', style: GoogleFonts.inter(fontSize: 12, color: AdminThemeColors.of(context).muted)),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(payment.valorFormatado, style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w700, color: AdminThemeColors.of(context).text)),
                const Spacer(),
                Text(DateFormat('d MMM yyyy', 'pt').format(payment.data), style: GoogleFonts.inter(fontSize: 11, color: AdminThemeColors.of(context).muted)),
              ],
            ),
            if (payment.faturaUrl != null) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _openInvoice(payment.faturaUrl!),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.picture_as_pdf, size: 14, color: AdminThemeColors.of(context).lime),
                    const SizedBox(width: 4),
                    Text('Ver fatura', style: GoogleFonts.inter(fontSize: 11, color: AdminThemeColors.of(context).lime)),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AdminThemeColors.of(context).border)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: userAsync.when(
              data: (u) => Text(u?.nome ?? 'Aluno', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AdminThemeColors.of(context).text)),
              loading: () => Text('...', style: GoogleFonts.inter(color: AdminThemeColors.of(context).muted)),
              error: (_, __) => Text('Aluno', style: GoogleFonts.inter(color: AdminThemeColors.of(context).muted)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(payment.descricao ?? 'Mensalidade', style: GoogleFonts.inter(fontSize: 13, color: AdminThemeColors.of(context).muted)),
          ),
          Expanded(
            flex: 1,
            child: Text(payment.valorFormatado, style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: AdminThemeColors.of(context).text)),
          ),
          Expanded(
            flex: 2,
            child: Text(DateFormat('d MMM yyyy', 'pt').format(payment.data), style: GoogleFonts.inter(fontSize: 12, color: AdminThemeColors.of(context).muted)),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(statusLabel, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
            ),
          ),
          SizedBox(
            width: 60,
            child: payment.faturaUrl != null
                ? IconButton(
                    icon: Icon(Icons.picture_as_pdf, color: AdminThemeColors.of(context).lime, size: 18),
                    onPressed: () => _openInvoice(payment.faturaUrl!),
                    tooltip: 'Ver fatura',
                  )
                : (payment.status == 'pending' && payment.stripeSessionId != null
                    ? IconButton(
                        icon: Icon(Icons.refresh, color: AdminThemeColors.of(context).orange, size: 18),
                        onPressed: () => ref.invalidate(adminAllPaymentsProvider),
                        tooltip: 'Atualizar',
                      )
                    : const SizedBox.shrink()),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AdminThemeColors.of(context).surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AdminThemeColors.of(context).border),
      boxShadow: [
        BoxShadow(color: AdminThemeColors.of(context).shadow, blurRadius: 8, offset: const Offset(0, 2)),
      ],
    );
  }

  void _openInvoice(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _showCreatePaymentDialog() async {
    final alunosAsync = ref.read(alunosListProvider);
    final alunos = alunosAsync.valueOrNull ?? [];

    if (alunos.isEmpty) {
      showAppNotification(context, 'Nenhum aluno disponível.', type: NotificationType.error);
      return;
    }

    UserModel? selectedAluno;
    final valorCtrl = TextEditingController();
    final descCtrl = TextEditingController(text: 'Mensalidade');
    bool loading = false;
    String? checkoutUrl;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AdminThemeColors.of(context).surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AdminThemeColors.of(context).border),
          ),
          title: Text('Novo Pagamento',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AdminThemeColors.of(context).text)),
          content: checkoutUrl != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 48, color: AdminThemeColors.of(context).lime),
                    const SizedBox(height: 12),
                    Text('Sessão de checkout criada!',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AdminThemeColors.of(context).text)),
                    const SizedBox(height: 8),
                    Text('URL de pagamento:', style: GoogleFonts.inter(fontSize: 11, color: AdminThemeColors.of(context).muted)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AdminThemeColors.of(context).bg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: SelectableText(checkoutUrl!, style: GoogleFonts.inter(fontSize: 11, color: AdminThemeColors.of(context).lime)),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Select student
                    DropdownButtonFormField<UserModel>(
                      initialValue: selectedAluno,
                      dropdownColor: AdminThemeColors.of(context).surface,
                      style: GoogleFonts.inter(color: AdminThemeColors.of(context).text),
                      decoration: InputDecoration(
                        labelText: 'Aluno',
                        labelStyle: GoogleFonts.inter(color: AdminThemeColors.of(context).muted),
                        filled: true,
                        fillColor: AdminThemeColors.of(context).bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AdminThemeColors.of(context).border),
                        ),
                      ),
                      items: alunos.map((a) => DropdownMenuItem(value: a, child: Text(a.nome))).toList(),
                      onChanged: (v) => setDialogState(() => selectedAluno = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: valorCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.inter(color: AdminThemeColors.of(context).text),
                      decoration: InputDecoration(
                        labelText: 'Valor (€)',
                        hintText: 'Ex: 29.99',
                        labelStyle: GoogleFonts.inter(color: AdminThemeColors.of(context).muted),
                        filled: true,
                        fillColor: AdminThemeColors.of(context).bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AdminThemeColors.of(context).border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      style: GoogleFonts.inter(color: AdminThemeColors.of(context).text),
                      decoration: InputDecoration(
                        labelText: 'Descrição',
                        labelStyle: GoogleFonts.inter(color: AdminThemeColors.of(context).muted),
                        filled: true,
                        fillColor: AdminThemeColors.of(context).bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AdminThemeColors.of(context).border),
                        ),
                      ),
                    ),
                    if (loading) ...[
                      const SizedBox(height: 16),
                      LinearProgressIndicator(color: AdminThemeColors.of(context).lime),
                    ],
                  ],
                ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx),
              child: Text(checkoutUrl != null ? 'Fechar' : 'Cancelar',
                  style: GoogleFonts.inter(color: AdminThemeColors.of(context).muted)),
            ),
            if (checkoutUrl == null)
              ElevatedButton(
                onPressed: loading || selectedAluno == null || valorCtrl.text.trim().isEmpty
                    ? null
                    : () async {
                        final valor = double.tryParse(valorCtrl.text.trim().replaceAll(',', '.'));
                        if (valor == null || valor <= 0) return;
                        setDialogState(() => loading = true);
                        try {
                          final repo = ref.read(paymentRepositoryProvider);
                          final url = await repo.createCheckoutSession(
                            userId: selectedAluno!.uid,
                            valor: valor,
                            descricao: descCtrl.text.trim().isEmpty ? 'Mensalidade' : descCtrl.text.trim(),
                          );
                          setDialogState(() {
                            loading = false;
                            checkoutUrl = url;
                          });
                          ref.invalidate(adminAllPaymentsProvider);
                        } catch (e) {
                          setDialogState(() => loading = false);
                          showAppNotification(ctx, 'Erro: ${e.toString()}', type: NotificationType.error);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminThemeColors.of(context).lime,
                  foregroundColor: AdminThemeColors.of(context).bg,
                ),
                child: Text('Criar Sessão', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Admin Agenda View ────────────────────────────────────────────

class _AdminAgendaView extends ConsumerStatefulWidget {
  const _AdminAgendaView();

  @override
  ConsumerState<_AdminAgendaView> createState() => _AdminAgendaViewState();
}

class _AdminAgendaViewState extends ConsumerState<_AdminAgendaView> {
  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime.now();
  late final String _trainerId;

  @override
  void initState() {
    super.initState();
    _trainerId = ref.read(authProvider).user?.uid ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(adminTrainerBookingsProvider(_trainerId));
    final namesAsync = ref.watch(adminStudentNamesProvider(_trainerId));
    final isMobile = MediaQuery.of(context).size.width < 900;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('AGENDA', style: _adminDisplay(context, isMobile ? 28 : 40)),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.chevron_left,
                    color: AdminThemeColors.of(context).muted),
                onPressed: () => setState(() {
                  _currentMonth = DateTime(
                      _currentMonth.year, _currentMonth.month - 1, 1);
                }),
              ),
              Text(
                DateFormat('MMMM yyyy', 'pt').format(_currentMonth),
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AdminThemeColors.of(context).text),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right,
                    color: AdminThemeColors.of(context).muted),
                onPressed: () => setState(() {
                  _currentMonth = DateTime(
                      _currentMonth.year, _currentMonth.month + 1, 1);
                }),
              ),
            ],
          ),
          const SizedBox(height: 24),
          bookingsAsync.when(
            data: (bookings) => _buildCalendarGrid(isMobile, bookings),
            loading: () => _buildCalendarGrid(isMobile, const []),
            error: (_, __) => _buildCalendarGrid(isMobile, const []),
          ),
          const SizedBox(height: 24),
          Text(
            DateFormat('EEEE, d MMMM', 'pt').format(_selectedDate),
            style: GoogleFonts.barlowCondensed(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AdminThemeColors.of(context).text),
          ),
          const SizedBox(height: 12),
          bookingsAsync.when(
            data: (bookings) {
              final names = namesAsync.valueOrNull ?? {};
              return _buildDayBookings(bookings, names);
            },
            loading: () => Center(
              child: CircularProgressIndicator(
                  color: AdminThemeColors.of(context).lime),
            ),
            error: (_, __) => Text('Erro',
                style: GoogleFonts.inter(
                    color: AdminThemeColors.of(context).muted)),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(bool isMobile, List<BookingModel> bookings) {
    final daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday =
        DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;
    final today = DateTime.now();
    final weekdayLabels = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminThemeColors.of(context).surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminThemeColors.of(context).border),
      ),
      child: Column(
        children: [
          Row(
            children: weekdayLabels
                .map((l) => Expanded(
                      child: Center(
                        child: Text(l,
                            style: GoogleFonts.inter(
                                fontSize: isMobile ? 10 : 12,
                                fontWeight: FontWeight.w700,
                                color: AdminThemeColors.of(context).muted)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          ...List.generate(
              ((daysInMonth + firstWeekday - 1) / 7).ceil(), (week) {
            return Row(
              children: List.generate(7, (day) {
                final dayNum = week * 7 + day - firstWeekday + 2;
                final isInMonth = dayNum >= 1 && dayNum <= daysInMonth;
                final date = DateTime(
                    _currentMonth.year, _currentMonth.month, dayNum);
                final isSelected = isInMonth &&
                    date.year == _selectedDate.year &&
                    date.month == _selectedDate.month &&
                    date.day == _selectedDate.day;
                final isToday = isInMonth &&
                    date.year == today.year &&
                    date.month == today.month &&
                    date.day == today.day;

                return Expanded(
                  child: GestureDetector(
                    onTap: isInMonth
                        ? () => setState(() => _selectedDate = date)
                        : null,
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      padding: EdgeInsets.all(isMobile ? 4 : 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AdminThemeColors.of(context).lime
                            : isToday
                                ? AdminThemeColors.of(context).limeDim
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isInMonth)
                            Text('$dayNum',
                                style: GoogleFonts.inter(
                                    fontSize: isMobile ? 11 : 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: isSelected
                                        ? AdminThemeColors.of(context).bg
                                        : AdminThemeColors.of(context).text)),
                          if (isInMonth && _hasBooking(date, bookings))
                            Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AdminThemeColors.of(context).bg
                                        .withValues(alpha: 0.7)
                                    : AdminThemeColors.of(context).lime,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDayBookings(List<BookingModel> bookings, Map<String, String> studentNames) {
    final dayBookings = bookings
        .where((b) =>
            b.data.year == _selectedDate.year &&
            b.data.month == _selectedDate.month &&
            b.data.day == _selectedDate.day)
        .toList()
      ..sort((a, b) => a.data.compareTo(b.data));

    if (dayBookings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AdminThemeColors.of(context).surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AdminThemeColors.of(context).border),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.event_available,
                  size: 40, color: AdminThemeColors.of(context).muted),
              const SizedBox(height: 8),
              Text('Nenhuma aula neste dia',
                  style: GoogleFonts.inter(
                      color: AdminThemeColors.of(context).muted)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: dayBookings.map((b) {
        final tipoIcon =
            b.tipo == 'online' ? Icons.videocam : Icons.fitness_center;
        final tipoLabel = b.tipo == 'online' ? 'Online' : 'Presencial';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AdminThemeColors.of(context).surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AdminThemeColors.of(context).border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AdminThemeColors.of(context).limeDim,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(b.horaFormatada,
                          style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AdminThemeColors.of(context).lime)),
                      Text('${b.duracaoMinutos}min',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              color: AdminThemeColors.of(context).lime
                                  .withValues(alpha: 0.7))),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(tipoIcon,
                              size: 13,
                              color: AdminThemeColors.of(context).muted),
                          const SizedBox(width: 4),
                          Text(tipoLabel,
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AdminThemeColors.of(context).text)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                          'Aluno: ${studentNames[b.studentId] ?? (b.studentId.length > 8 ? '${b.studentId.substring(0, 8)}...' : b.studentId)}',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AdminThemeColors.of(context).muted)),
                    ],
                  ),
                ),
                if (b.isPending) ...[
                  GestureDetector(
                    onTap: () => _updateStatus(b, 'confirmed'),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AdminThemeColors.of(context).limeDim,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.check,
                          size: 16, color: AdminThemeColors.of(context).lime),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _updateStatus(b, 'cancelled'),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close, size: 16, color: Colors.red),
                    ),
                  ),
                ],
                if (b.isConfirmed) ...[
                  GestureDetector(
                    onTap: () => _updateStatus(b, 'completed'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AdminThemeColors.of(context).blue
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Concluir',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AdminThemeColors.of(context).blue)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _updateStatus(b, 'cancelled'),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close, size: 16, color: Colors.red),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  bool _hasBooking(DateTime date, List<BookingModel> bookings) {
    return bookings.any((b) =>
        b.data.year == date.year &&
        b.data.month == date.month &&
        b.data.day == date.day);
  }

  Future<void> _updateStatus(BookingModel booking, String status) async {
    try {
      await ref
          .read(bookingRepositoryProvider)
          .updateBooking(booking.id, {'status': status});
      ref.invalidate(adminTrainerBookingsProvider(_trainerId));
      // Notificar o aluno (só para confirm/cancel)
      if (status == 'confirmed' || status == 'cancelled') {
        fireBookingNotification(booking, status);
      }
      if (mounted) {
        final msgs = {
          'confirmed': 'confirmada',
          'cancelled': 'cancelada',
          'completed': 'concluída',
        };
        showAppNotification(context, 'Aula ${msgs[status] ?? status}!',
            type: NotificationType.success);
      }
    } catch (_) {
      if (mounted) {
        showAppNotification(context, 'Erro ao atualizar.',
            type: NotificationType.error);
      }
    }
    }
}

// ─── Shared Helpers ───────────────────────────────────────────────

TextStyle _adminDisplay(BuildContext context, double size) {
  return GoogleFonts.barlowCondensed(
    fontSize: size,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.01,
    color: AdminThemeColors.of(context).text,
  );
}
