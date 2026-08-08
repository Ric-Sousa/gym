import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:typed_data';
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
import '../../../shared/widgets/admin_responsive_dialog.dart';
import '../../../shared/widgets/admin_design_system.dart';
import '../../../shared/providers/admin_providers.dart';
import '../../../shared/utils/booking_notifications.dart';
import '../../../shared/widgets/image_comparison_slider.dart';
import '../../../shared/widgets/app_notification.dart';
import 'global_workout_plans_screen.dart';
import '../../admin/widgets/nutrition_editor.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/sound_service.dart';
import '../../../core/config/notification_sounds.dart';
import '../../admin/widgets/floating_chat_button.dart';
import '../../admin/widgets/admin_messages_view.dart';
import '../../../features/aluno/chat/screens/chat_screen.dart';
import '../../../features/aluno/perfil/screens/profile_screen.dart';

// ─── Enums & Local Providers ──────────────────────────────────────

enum AdminView {
  dashboard,
  clients,
  workouts,
  exercises,
  foods,
  messages,
  payments,
  agenda,
  settings,
}

final alunosListProvider = FutureProvider<List<UserModel>>((ref) {
  return ref.read(userRepositoryProvider).getAllAlunos();
});

final alunosSearchProvider = FutureProvider.family<List<UserModel>, String>((
  ref,
  query,
) {
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
  bool _openSelectedClientChat = false;
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
    ref.read(isAdminInChatProvider.notifier).state = false;
    setState(() {
      _view = v;
      _selectedClient = null;
      _openSelectedClientChat = false;
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
        ref
            .read(adminThemeModeProvider.notifier)
            .state = ref.read(adminThemeModeProvider) == ThemeMode.dark
            ? ThemeMode.light
            : ThemeMode.dark;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final baseTheme = Theme.of(context);
    return Theme(
      data: buildWorkspaceTheme(baseTheme, colors),
      child: _buildAdminShell(),
    );
  }

  Widget _buildAdminShell() {
    if (_isMobile) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: AdminThemeColors.of(context).bg,
        appBar: AppBar(
          backgroundColor: AdminThemeColors.of(context).surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.menu, color: AdminThemeColors.of(context).text),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          title: Text(
            'GYMBT',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AdminThemeColors.of(context).text,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Theme.of(context).brightness == Brightness.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                color: AdminThemeColors.of(context).muted,
              ),
              onPressed: () {
                ref
                    .read(adminThemeModeProvider.notifier)
                    .state = ref.read(adminThemeModeProvider) == ThemeMode.dark
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
                    icon: Icon(
                      Icons.close,
                      color: AdminThemeColors.of(context).muted,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                    padding: const EdgeInsets.all(16),
                  ),
                ),
                Expanded(child: _buildSidebar()),
              ],
            ),
          ),
        ),
        body: Stack(
          children: [
            _selectedClient != null
                ? _ClientDetailView(
                    client: _selectedClient!,
                    initialTab: _openSelectedClientChat ? 'chat' : 'overview',
                    isMobile: true,
                    onBack: () {
                      ref.read(isAdminInChatProvider.notifier).state = false;
                      setState(() {
                        _selectedClient = null;
                        _openSelectedClientChat = false;
                      });
                    },
                  )
                : _buildView(),
            FloatingChatButton(
              onViewProfile: (aluno) {
                setState(() {
                  _selectedClient = aluno;
                  _view = AdminView.clients;
                });
              },
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AdminThemeColors.of(context).bg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      _selectedClient != null
                          ? _ClientDetailView(
                              client: _selectedClient!,
                              initialTab: _openSelectedClientChat
                                  ? 'chat'
                                  : 'overview',
                              isMobile: false,
                              onBack: () {
                                ref.read(isAdminInChatProvider.notifier).state =
                                    false;
                                setState(() {
                                  _selectedClient = null;
                                  _openSelectedClientChat = false;
                                });
                              },
                            )
                          : _buildView(),
                      FloatingChatButton(
                        onViewProfile: (aluno) {
                          setState(() {
                            _selectedClient = aluno;
                            _view = AdminView.clients;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildView() {
    switch (_view) {
      case AdminView.dashboard:
        return _AdminDashboard(
          onSelectClient: (c) => setState(() {
            _selectedClient = c;
            _view = AdminView.clients;
          }),
        );
      case AdminView.clients:
        return _AdminClientsList(
          onSelect: (c) => setState(() => _selectedClient = c),
        );
      case AdminView.workouts:
        return const GlobalWorkoutPlansScreen();
      case AdminView.exercises:
        return const _AdminExerciseLibrary();
      case AdminView.foods:
        return const _AdminFoodLibrary();
      case AdminView.payments:
        return const _AdminPaymentsView();
      case AdminView.agenda:
        return const _AdminAgendaView();
      case AdminView.messages:
        return AdminMessagesView(
          onSelect: (aluno) => setState(() {
            _selectedClient = aluno;
            _openSelectedClientChat = true;
            _view = AdminView.clients;
          }),
        );
      case AdminView.settings:
        return const _AdminSettingsView();
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
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AdminThemeColors.of(context).limeDim,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AdminThemeColors.of(
                      context,
                    ).lime.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  Icons.fitness_center,
                  color: AdminThemeColors.of(context).lime,
                  size: 16,
                ),
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
        const SizedBox(height: 12),
      ],
    );

    final colors = AdminThemeColors.of(context);
    return Container(
      width: isMobile ? double.infinity : 224,
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: colors.surface,
        border: isMobile
            ? null
            : Border(
                right: BorderSide(color: colors.border.withValues(alpha: 0.7)),
              ),
      ),
      child: Column(
        children: [
          logoSection,
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  // Nav items
                  _NavItem(
                    icon: Icons.dashboard_outlined,
                    activeIcon: Icons.dashboard,
                    label: 'Dashboard',
                    active:
                        currentView == AdminView.dashboard && !isClientDetail,
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
                    label: 'Treinos',
                    active: currentView == AdminView.workouts,
                    onTap: () => onNavigate(AdminView.workouts),
                  ),
                  _NavItem(
                    icon: Icons.library_books_outlined,
                    activeIcon: Icons.library_books,
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
                  _NavCategory(label: 'AGENDA'),
                  _NavItem(
                    icon: Icons.calendar_today_outlined,
                    activeIcon: Icons.calendar_today,
                    label: 'Agenda',
                    active: currentView == AdminView.agenda,
                    onTap: () => onNavigate(AdminView.agenda),
                  ),
                  _NavCategory(label: 'DEFINIÇÕES'),
                  _NavItem(
                    icon: Icons.settings_outlined,
                    activeIcon: Icons.settings,
                    label: 'Definições',
                    active: currentView == AdminView.settings,
                    onTap: () => onNavigate(AdminView.settings),
                  ),
                ],
              ),
            ),
          ),
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
                    Icon(
                      Icons.logout,
                      color: AdminThemeColors.of(context).muted,
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Sair',
                      style: GoogleFonts.inter(
                        color: AdminThemeColors.of(context).muted,
                        fontSize: 13,
                      ),
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
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
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
        color: active
            ? AdminThemeColors.of(context).limeDim
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  active ? activeIcon : icon,
                  size: 18,
                  color: active
                      ? AdminThemeColors.of(context).lime
                      : AdminThemeColors.of(context).muted,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active
                        ? AdminThemeColors.of(context).text
                        : AdminThemeColors.of(context).muted,
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

    final colors = AdminThemeColors.of(context);
    return AdminPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: 'DASHBOARD',
            subtitle: DateFormat(
              'EEEE, d MMMM yyyy',
              'pt',
            ).format(DateTime.now()),
            icon: Icons.space_dashboard_outlined,
          ),
          const SizedBox(height: 24),
          statsAsync.when(
            data: (stats) => _buildStats(stats),
            loading: () => _buildStatsLoading(),
            error: (_, __) => _buildStatsLoading(),
          ),
          const SizedBox(height: 24),
          alunosAsync.when(
            data: (alunos) => _buildDashboardColumns(alunos),
            loading: () =>
                Center(child: CircularProgressIndicator(color: colors.lime)),
            error: (_, __) => Text(
              'Não foi possível carregar os dados.',
              style: GoogleFonts.inter(color: colors.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(AdminDashboardStats stats) {
    final colors = AdminThemeColors.of(context);
    final items = [
      (
        'Clientes',
        stats.totalAlunos.toString(),
        Icons.people_outline,
        colors.lime,
      ),
      (
        'Ativos 30d',
        stats.activeAlunos.toString(),
        Icons.trending_up_rounded,
        colors.blue,
      ),
      (
        'Sessões mês',
        stats.sessoesMes.toString(),
        Icons.calendar_today_outlined,
        colors.orange,
      ),
      (
        'Sessões totais',
        stats.sessoesTotal.toString(),
        Icons.insights_rounded,
        colors.purple,
      ),
    ];
    return LayoutBuilder(
      builder: (_, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : (constraints.maxWidth >= 520 ? 2 : 1);
        final width = (constraints.maxWidth - 14 * (columns - 1)) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: AdminMetric(
                    label: item.$1,
                    value: item.$2,
                    icon: item.$3,
                    accent: item.$4,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildStatsLoading() {
    final items = [
      (
        'Clientes Totais',
        '...',
        Icons.people,
        AdminThemeColors.of(context).lime,
      ),
      (
        'Ativos (30d)',
        '...',
        Icons.trending_up,
        AdminThemeColors.of(context).blue,
      ),
      (
        'Sessões Mês',
        '...',
        Icons.calendar_today,
        AdminThemeColors.of(context).orange,
      ),
      (
        'Sessões Totais',
        '...',
        Icons.emoji_events,
        AdminThemeColors.of(context).purple,
      ),
    ];
    return LayoutBuilder(
      builder: (_, constraints) {
        final cols = constraints.maxWidth > 800
            ? 4
            : (constraints.maxWidth > 450 ? 2 : 1);
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: items.map((s) {
            final width = (constraints.maxWidth - 14 * (cols - 1)) / cols;
            return SizedBox(
              width: width,
              child: _statCard(s.$1, s.$2, s.$3, s.$4),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return AdminMetric(label: label, value: value, icon: icon, accent: color);
  }

  Widget _buildDashboardColumns(List<UserModel> alunos) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final isWide = constraints.maxWidth > 800;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _clientsCard(alunos)),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _agendaCard(),
                    const SizedBox(height: 20),
                    _goalsCard(alunos),
                  ],
                ),
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
      },
    );
  }

  Widget _clientsCard(List<UserModel> alunos) {
    return Container(
      decoration: BoxDecoration(
        color: AdminThemeColors.of(context).surface,
        borderRadius: BorderRadius.circular(18),
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 280;
                final heading = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people,
                      color: AdminThemeColors.of(context).lime,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CLIENTES',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.03,
                        color: AdminThemeColors.of(context).text,
                      ),
                    ),
                  ],
                );
                final action = TextButton(
                  onPressed: () {},
                  child: Text(
                    'Ver todos',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
                  ),
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [heading, action],
                  );
                }
                return Row(children: [heading, const Spacer(), action]);
              },
            ),
          ),
          Divider(height: 1, color: AdminThemeColors.of(context).border),
          if (alunos.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 48,
                    color: AdminThemeColors.of(context).muted,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nenhum aluno cadastrado',
                    style: GoogleFonts.inter(
                      color: AdminThemeColors.of(context).muted,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Clique em "Clientes" para adicionar o primeiro.',
                    style: GoogleFonts.inter(
                      color: AdminThemeColors.of(context).muted,
                      fontSize: 12,
                    ),
                  ),
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
          border: Border(
            bottom: BorderSide(color: AdminThemeColors.of(context).border),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AdminThemeColors.of(context).surface2,
              child: Text(
                aluno.nome.isNotEmpty ? aluno.nome[0].toUpperCase() : '?',
                style: GoogleFonts.barlowCondensed(
                  color: AdminThemeColors.of(context).lime,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    aluno.nome,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AdminThemeColors.of(context).text,
                    ),
                  ),
                  Text(
                    aluno.email,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AdminThemeColors.of(context).muted,
                    ),
                  ),
                ],
              ),
            ),
            if (weight != null) ...[
              Text(
                '${weight.toStringAsFixed(0)}kg',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  color: AdminThemeColors.of(context).text,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(
              Icons.chevron_right,
              size: 14,
              color: AdminThemeColors.of(context).muted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _agendaCard() {
    final trainerId = ref.read(authProvider).user?.uid ?? '';
    final bookingsAsync = ref.watch(adminTrainerBookingsProvider(trainerId));
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminThemeColors.of(context).surface,
        borderRadius: BorderRadius.circular(18),
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
          Text(
            'AGENDA DA SEMANA',
            style: GoogleFonts.barlowCondensed(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.03,
              color: AdminThemeColors.of(context).text,
            ),
          ),
          const SizedBox(height: 16),
          bookingsAsync.when(
            data: (bookings) {
              final weekBookings =
                  bookings
                      .where(
                        (b) =>
                            !b.isCancelled &&
                            b.data.isAfter(weekStart) &&
                            b.data.isBefore(weekEnd),
                      )
                      .toList()
                    ..sort((a, b) => a.data.compareTo(b.data));

              if (weekBookings.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 36,
                        color: AdminThemeColors.of(context).muted,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Nenhuma aula esta semana',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AdminThemeColors.of(context).muted,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: weekBookings.take(5).map((b) {
                  final dateStr = DateFormat('EEE d/M', 'pt').format(b.data);
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
                              Text(
                                b.horaFormatada,
                                style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AdminThemeColors.of(context).lime,
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
                                dateStr,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AdminThemeColors.of(context).muted,
                                ),
                              ),
                              Text(
                                b.tipo == 'online'
                                    ? '💻 Online'
                                    : '🏋️ Presencial',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AdminThemeColors.of(context).text,
                                ),
                              ),
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
                color: AdminThemeColors.of(context).lime,
              ),
            ),
            error: (e, __) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Erro: ${e.toString()}',
                style: GoogleFonts.inter(
                  color: AdminThemeColors.of(context).muted,
                  fontSize: 12,
                ),
              ),
            ),
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
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _goalsCard(List<UserModel> alunos) {
    final ativosSemana = alunos
        .where(
          (a) =>
              a.ultimaAtividade != null &&
              DateTime.now().difference(a.ultimaAtividade!).inDays <= 7,
        )
        .length;
    final totalAlunos = alunos.length;
    final goals = [
      ('Ativos esta semana', ativosSemana, AdminThemeColors.of(context).blue),
      ('Total de alunos', totalAlunos, AdminThemeColors.of(context).lime),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminThemeColors.of(context).surface,
        borderRadius: BorderRadius.circular(18),
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
          Text(
            'MÉTRICAS',
            style: GoogleFonts.barlowCondensed(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.03,
              color: AdminThemeColors.of(context).text,
            ),
          ),
          const SizedBox(height: 16),
          ...goals.map(
            (g) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        g.$1,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AdminThemeColors.of(context).muted,
                        ),
                      ),
                      Text(
                        '${g.$2}',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: AdminThemeColors.of(context).text,
                        ),
                      ),
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
            ),
          ),
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
  String _viewMode = 'list';

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final isMobile = MediaQuery.sizeOf(context).width < 900;
    final alunosAsync = ref.watch(alunosSearchProvider(_search));

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 28,
        isMobile ? 16 : 24,
        isMobile ? 16 : 28,
        isMobile ? 24 : 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Clientes',
                      style: GoogleFonts.inter(
                        fontSize: isMobile ? 24 : 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${alunosAsync.asData?.value.length ?? 0} perfis na tua base de clientes',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: colors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isMobile) _newClientButton(compact: true),
            ],
          ),
          const SizedBox(height: 20),
          _buildClientsToolbar(isMobile, colors),
          const SizedBox(height: 16),
          alunosAsync.when(
            data: (alunos) =>
                _viewMode == 'list' ? _buildList(alunos) : _buildGrid(alunos),
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(vertical: 72),
              child: Center(
                child: CircularProgressIndicator(color: colors.lime),
              ),
            ),
            error: (_, __) => _clientsErrorState(colors),
          ),
          if (isMobile) ...[
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: _newClientButton()),
          ],
        ],
      ),
    );
  }

  Widget _newClientButton({bool compact = false}) {
    final colors = AdminThemeColors.of(context);
    return ElevatedButton.icon(
      onPressed: _showCreateStudentDialog,
      icon: const Icon(Icons.add_rounded, size: 17),
      label: Text(compact ? 'Novo cliente' : 'Adicionar cliente'),
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.lime,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 18,
          vertical: compact ? 10 : 13,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildClientsToolbar(bool isMobile, AdminThemeColors colors) {
    final filterLabel = switch (_filter) {
      'active' => 'Ativos',
      'inactive' => 'Inativos',
      _ => 'Todos',
    };
    final search = SizedBox(
      height: 42,
      child: TextField(
        onChanged: (value) => setState(() => _search = value),
        style: GoogleFonts.inter(fontSize: 13, color: colors.text),
        decoration: InputDecoration(
          hintText: 'Pesquisar por nome ou email',
          hintStyle: GoogleFonts.inter(fontSize: 12, color: colors.muted),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: colors.muted),
          filled: true,
          fillColor: colors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: BorderSide(color: colors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: BorderSide(color: colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: BorderSide(color: colors.lime, width: 1.2),
          ),
        ),
      ),
    );
    final filter = PopupMenuButton<String>(
      tooltip: 'Filtrar clientes',
      onSelected: (value) => setState(() => _filter = value),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'all', child: Text('Todos os clientes')),
        PopupMenuItem(value: 'active', child: Text('Apenas ativos')),
        PopupMenuItem(value: 'inactive', child: Text('Apenas inativos')),
      ],
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list_rounded, size: 17, color: colors.muted),
            const SizedBox(width: 7),
            Text(
              filterLabel,
              style: GoogleFonts.inter(fontSize: 12, color: colors.text),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 17,
              color: colors.muted,
            ),
          ],
        ),
      ),
    );
    final view = _viewToggle();

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          search,
          const SizedBox(height: 8),
          filter,
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: view),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: search),
        const SizedBox(width: 8),
        filter,
        const SizedBox(width: 8),
        view,
      ],
    );
  }

  Widget _clientsErrorState(AdminThemeColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, size: 32, color: colors.muted),
          const SizedBox(height: 10),
          Text(
            'Não foi possível carregar os clientes',
            style: GoogleFonts.inter(
              color: colors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tenta atualizar a página novamente.',
            style: GoogleFonts.inter(fontSize: 12, color: colors.muted),
          ),
        ],
      ),
    );
  }

  Widget _viewToggle() {
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _viewToggleButton(Icons.grid_view_rounded, 'Cartões', 'cards'),
          _viewToggleButton(Icons.view_list_rounded, 'Lista', 'list'),
        ],
      ),
    );
  }

  Widget _viewToggleButton(IconData icon, String label, String mode) {
    final colors = AdminThemeColors.of(context);
    final selected = _viewMode == mode;
    return InkWell(
      onTap: () => setState(() => _viewMode = mode),
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colors.surface2 : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? colors.text : colors.muted),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? colors.text : colors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<UserModel> _filteredClients(List<UserModel> alunos) {
    return alunos.where((a) {
      if (_filter == 'active') return a.isAccessAllowed;
      if (_filter == 'inactive') return !a.isAccessAllowed;
      return true;
    }).toList();
  }

  Widget _buildGrid(List<UserModel> alunos) {
    final filtered = _filteredClients(alunos);

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.person_search,
                size: 48,
                color: AdminThemeColors.of(context).muted,
              ),
              const SizedBox(height: 8),
              Text(
                'Nenhum cliente encontrado',
                style: GoogleFonts.inter(
                  color: AdminThemeColors.of(context).muted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (_, constraints) {
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
      },
    );
  }

  Widget _buildList(List<UserModel> alunos) {
    final filtered = _filteredClients(alunos);
    final colors = AdminThemeColors.of(context);

    if (filtered.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 58, horizontal: 24),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          children: [
            Icon(Icons.person_outline_rounded, size: 34, color: colors.muted),
            const SizedBox(height: 10),
            Text(
              'Nenhum cliente encontrado',
              style: GoogleFonts.inter(
                color: colors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Altera a pesquisa ou o filtro selecionado.',
              style: GoogleFonts.inter(fontSize: 12, color: colors.muted),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: filtered.asMap().entries.map((entry) {
                return _clientListCompactRow(
                  entry.value,
                  entry.key == filtered.length - 1,
                );
              }).toList(),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _clientListHeader(),
              ...filtered.asMap().entries.map((entry) {
                return _clientListRow(
                  entry.value,
                  entry.key == filtered.length - 1,
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _clientListCompactRow(UserModel aluno, bool isLast) {
    final colors = AdminThemeColors.of(context);
    final date = aluno.createdAt == null
        ? 'Data de entrada: —'
        : 'Entrada: ${DateFormat('dd/MM/yyyy').format(aluno.createdAt!)}';
    final plan = aluno.tipoCliente == 'online' ? 'Online' : 'Presencial';
    final accessLabel = aluno.accessStatus;

    return Material(
      color: colors.surface,
      child: InkWell(
        onTap: () => widget.onSelect(aluno),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: colors.surface2,
                child: Text(
                  aluno.nome.isNotEmpty ? aluno.nome[0].toUpperCase() : '?',
                  style: GoogleFonts.inter(
                    color: colors.lime,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      aluno.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$date · Plano: $plan · $accessLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: colors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Ações do cliente',
                onSelected: (action) {
                  if (action == 'delete') _confirmDeleteStudent(aluno);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 17, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Eliminar cliente'),
                      ],
                    ),
                  ),
                ],
                icon: Icon(
                  Icons.more_horiz_rounded,
                  size: 19,
                  color: colors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _clientListHeader() {
    final colors = AdminThemeColors.of(context);
    return Container(
      color: colors.surface2.withValues(alpha: 0.45),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          const SizedBox(width: 36),
          Expanded(child: _listHeaderText('CLIENTE')),
          SizedBox(width: 118, child: _listHeaderText('ENTRADA')),
          SizedBox(width: 160, child: _listHeaderText('PLANO / ACESSO')),
          const SizedBox(width: 42),
        ],
      ),
    );
  }

  Widget _listHeaderText(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: AdminThemeColors.of(context).muted,
      ),
    );
  }

  Widget _clientListRow(UserModel aluno, bool isLast) {
    final colors = AdminThemeColors.of(context);
    final date = aluno.createdAt == null
        ? '—'
        : DateFormat('dd/MM/yyyy').format(aluno.createdAt!);
    final isOnline = aluno.tipoCliente == 'online';
    final accessColor = aluno.accessStatus == 'Ativo'
        ? colors.lime
        : aluno.accessStatus == 'Termina em breve'
        ? colors.orange
        : colors.danger;

    return Material(
      color: colors.surface,
      child: InkWell(
        onTap: () => widget.onSelect(aluno),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: colors.surface2,
                child: Text(
                  aluno.nome.isNotEmpty ? aluno.nome[0].toUpperCase() : '?',
                  style: GoogleFonts.inter(
                    color: colors.lime,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      aluno.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      aluno.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: colors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 118,
                child: Text(
                  date,
                  style: GoogleFonts.inter(fontSize: 12, color: colors.muted),
                ),
              ),
              SizedBox(
                width: 160,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isOnline
                              ? colors.lime.withValues(alpha: 0.12)
                              : colors.surface2,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isOnline ? 'Online' : 'Presencial',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isOnline ? colors.lime : colors.text,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: accessColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          aluno.accessStatus,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: accessColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Ações do cliente',
                onSelected: (action) {
                  if (action == 'delete') _confirmDeleteStudent(aluno);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 17, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Eliminar cliente'),
                      ],
                    ),
                  ),
                ],
                icon: Icon(
                  Icons.more_horiz_rounded,
                  size: 19,
                  color: colors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                      aluno.nome.isNotEmpty ? aluno.nome[0].toUpperCase() : '?',
                      style: GoogleFonts.barlowCondensed(
                        color: AdminThemeColors.of(context).lime,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          aluno.nome,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AdminThemeColors.of(context).text,
                          ),
                        ),
                        Text(
                          '${aluno.pesoAtual?.toStringAsFixed(1) ?? '--'} kg',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AdminThemeColors.of(context).muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Botão de excluir
                  GestureDetector(
                    onTap: () => _confirmDeleteStudent(aluno),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _miniStat(
                    'PESO',
                    '${aluno.pesoAtual?.toStringAsFixed(0) ?? '--'}kg',
                  ),
                  const SizedBox(width: 8),
                  _miniStat(
                    'ALTURA',
                    '${aluno.altura?.toStringAsFixed(0) ?? '--'}cm',
                  ),
                  const SizedBox(width: 8),
                  _miniStat('IMC', aluno.imc?.toStringAsFixed(1) ?? '--'),
                ].map((e) => Expanded(child: e)).toList(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.email_outlined,
                    size: 12,
                    color: AdminThemeColors.of(context).muted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      aluno.email,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AdminThemeColors.of(context).muted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: AdminThemeColors.of(context).muted,
                  ),
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
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: AdminThemeColors.of(context).muted,
              letterSpacing: 0.06,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AdminThemeColors.of(context).text,
            ),
          ),
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
    bool isActive = true;
    bool obscurePassword = true;
    bool loading = false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AdminResponsiveAlertDialog(
          backgroundColor: AdminThemeColors.of(context).surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AdminThemeColors.of(context).border),
          ),
          title: Text(
            'Novo Cliente',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: AdminThemeColors.of(context).text,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomeCtrl,
                  style: GoogleFonts.inter(
                    color: AdminThemeColors.of(context).text,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Nome completo',
                    labelStyle: GoogleFonts.inter(
                      color: AdminThemeColors.of(context).muted,
                    ),
                    filled: true,
                    fillColor: AdminThemeColors.of(context).bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: AdminThemeColors.of(context).border,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.inter(
                    color: AdminThemeColors.of(context).text,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: GoogleFonts.inter(
                      color: AdminThemeColors.of(context).muted,
                    ),
                    filled: true,
                    fillColor: AdminThemeColors.of(context).bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: AdminThemeColors.of(context).border,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Password
                TextField(
                  controller: passwordCtrl,
                  obscureText: obscurePassword,
                  style: GoogleFonts.inter(
                    color: AdminThemeColors.of(context).text,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Senha (opcional)',
                    labelStyle: GoogleFonts.inter(
                      color: AdminThemeColors.of(context).muted,
                    ),
                    filled: true,
                    fillColor: AdminThemeColors.of(context).bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: AdminThemeColors.of(context).border,
                      ),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 18,
                        color: AdminThemeColors.of(context).muted,
                      ),
                      onPressed: () => setDialogState(
                        () => obscurePassword = !obscurePassword,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: genero,
                  decoration: InputDecoration(
                    labelText: 'Género',
                    labelStyle: GoogleFonts.inter(
                      color: AdminThemeColors.of(context).muted,
                    ),
                    filled: true,
                    fillColor: AdminThemeColors.of(context).bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: AdminThemeColors.of(context).border,
                      ),
                    ),
                  ),
                  dropdownColor: AdminThemeColors.of(context).surface,
                  style: GoogleFonts.inter(
                    color: AdminThemeColors.of(context).text,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'feminino',
                      child: Text('🌸 Feminino'),
                    ),
                    DropdownMenuItem(
                      value: 'masculino',
                      child: Text('💪 Masculino'),
                    ),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => genero = v ?? 'feminino'),
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: isActive,
                  activeColor: AdminThemeColors.of(context).lime,
                  title: Text(
                    'Perfil ativo',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AdminThemeColors.of(context).text,
                    ),
                  ),
                  subtitle: Text(
                    isActive
                        ? 'O cliente poderá entrar na aplicação.'
                        : 'O acesso ficará bloqueado até ser reativado.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AdminThemeColors.of(context).muted,
                    ),
                  ),
                  onChanged: (value) => setDialogState(() => isActive = value),
                ),
                if (loading) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    color: AdminThemeColors.of(context).lime,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading
                  ? null
                  : () => Future.microtask(() => Navigator.pop(ctx)),
              child: Text(
                'Cancelar',
                style: GoogleFonts.inter(
                  color: AdminThemeColors.of(context).muted,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (nomeCtrl.text.trim().isEmpty ||
                          emailCtrl.text.trim().isEmpty)
                        return;
                      final pw = passwordCtrl.text.trim();
                      if (pw.isNotEmpty && pw.length < 6) {
                        showAppNotification(
                          context,
                          'A password deve ter pelo menos 6 caracteres.',
                          type: NotificationType.error,
                        );
                        return;
                      }
                      setDialogState(() => loading = true);
                      try {
                        // Obtém token fresco para verificação manual na Cloud Function
                        final token = await FirebaseAuth.instance.currentUser
                            ?.getIdToken(true);
                        final adminId =
                            FirebaseAuth.instance.currentUser?.uid ?? '';
                        final body = <String, dynamic>{
                          'nome': nomeCtrl.text.trim(),
                          'email': emailCtrl.text.trim(),
                          'personalId': adminId,
                          'genero': genero,
                          'isActive': isActive,
                          'authToken': token ?? '',
                        };
                        if (pw.isNotEmpty) body['password'] = pw;

                        final response = await http.post(
                          Uri.parse(
                            'https://europe-west1-gymbt-4ef87.cloudfunctions.net/createStudentHttp',
                          ),
                          headers: {'Content-Type': 'application/json'},
                          body: json.encode(body),
                        );
                        if (!mounted) return;
                        if (response.statusCode != 200) {
                          final errData =
                              json.decode(response.body)
                                  as Map<String, dynamic>;
                          final err = errData['error'] as Map<String, dynamic>?;
                          final msg =
                              err?['message'] as String? ?? 'Erro desconhecido';
                          setDialogState(() => loading = false);
                          if (msg.contains('unauthenticated') ||
                              msg.contains('Login necessário') ||
                              msg.contains('Token inválido')) {
                            showAppNotification(
                              context,
                              'Erro de autenticação. Tenta sair e entrar novamente.',
                              type: NotificationType.error,
                            );
                          } else if (msg.contains('weak-password') ||
                              msg.contains('Password should be')) {
                            showAppNotification(
                              context,
                              'Password muito fraca. Usa pelo menos 6 caracteres.',
                              type: NotificationType.error,
                            );
                          } else {
                            showAppNotification(
                              context,
                              'Erro ao criar aluno: $msg',
                              type: NotificationType.error,
                            );
                          }
                          return;
                        }
                        final data =
                            json.decode(response.body) as Map<String, dynamic>;
                        setDialogState(() => loading = false);
                        Future.microtask(
                          () => Navigator.pop(ctx, {
                            'uid': data['uid'] as String,
                            'email': data['email'] as String,
                            'password': data['temporaryPassword'] as String?,
                            'alreadyExists': data['alreadyExists'] == true,
                            'created': data['created'] == true,
                          }),
                        );
                      } catch (e) {
                        setDialogState(() => loading = false);
                        showAppNotification(
                          context,
                          'Erro ao criar aluno: $e',
                          type: NotificationType.error,
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminThemeColors.of(context).lime,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Criar',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
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
      builder: (ctx) => AdminResponsiveAlertDialog(
        backgroundColor: AdminThemeColors.of(context).surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Eliminar aluno',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: AdminThemeColors.of(context).text,
          ),
        ),
        content: Text(
          'Tens a certeza que queres eliminar "${aluno.nome}"?\n\nEsta ação é irreversível e remove todos os dados do aluno.',
          style: GoogleFonts.inter(color: AdminThemeColors.of(context).muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.inter(
                color: AdminThemeColors.of(context).muted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              'Eliminar',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
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
        Uri.parse(
          'https://europe-west1-gymbt-4ef87.cloudfunctions.net/deleteStudentHttp',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': aluno.uid, 'authToken': token ?? ''}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        ref.invalidate(alunosListProvider);
        showAppNotification(
          context,
          'Aluno "${aluno.nome}" eliminado.',
          type: NotificationType.success,
        );
      } else {
        final errData = json.decode(response.body) as Map<String, dynamic>;
        final err = errData['error'] as Map<String, dynamic>?;
        showAppNotification(
          context,
          err?['message'] ?? 'Erro ao eliminar.',
          type: NotificationType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        showAppNotification(
          context,
          'Erro ao eliminar: $e',
          type: NotificationType.error,
        );
      }
    }
  }
}

// ─── Client Detail View ───────────────────────────────────────────

class _ClientDetailView extends ConsumerStatefulWidget {
  final UserModel client;
  final VoidCallback onBack;
  final String initialTab;
  final bool isMobile;
  const _ClientDetailView({
    required this.client,
    required this.onBack,
    this.initialTab = 'overview',
    this.isMobile = false,
  });

  @override
  ConsumerState<_ClientDetailView> createState() => _ClientDetailViewState();
}

class _ClientDetailViewState extends ConsumerState<_ClientDetailView> {
  late String _tab;
  bool _requestingProgress = false;
  bool _personalIdSet = false;
  late bool _isActive;
  DateTime? _contractEndsAt;
  String _adminNote = '';
  bool _loadingAccountAction = false;
  bool _loadingNote = true;
  bool _savingNote = false;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _isActive = widget.client.isActive;
    _contractEndsAt = widget.client.contractEndsAt;
    _noteController = TextEditingController();
    // Garante que o personalId é definido assim que o admin abre o perfil do aluno.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensurePersonalId();
      _loadAdminNote();
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminNote() async {
    try {
      final note = await ref
          .read(userRepositoryProvider)
          .getAdminNote(widget.client.uid);
      if (!mounted) return;
      setState(() {
        _adminNote = note;
        _noteController.text = note;
        _loadingNote = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingNote = false);
    }
  }

  Future<void> _saveAdminNote() async {
    setState(() => _savingNote = true);
    try {
      final adminId = FirebaseAuth.instance.currentUser?.uid;
      await ref
          .read(userRepositoryProvider)
          .setAdminNote(
            widget.client.uid,
            _noteController.text.trim(),
            adminId: adminId,
          );
      if (!mounted) return;
      setState(() {
        _adminNote = _noteController.text.trim();
        _savingNote = false;
      });
      showAppNotification(
        context,
        'Nota guardada.',
        type: NotificationType.success,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingNote = false);
      showAppNotification(
        context,
        'Não foi possível guardar a nota.',
        type: NotificationType.error,
      );
    }
  }

  Future<void> _setProfileActive(bool value) async {
    setState(() => _loadingAccountAction = true);
    try {
      await ref.read(userRepositoryProvider).updateUser(widget.client.uid, {
        'isActive': value,
        if (value) ...{
          'deactivatedAt': FieldValue.delete(),
          'contractEndsAt': FieldValue.delete(),
        },
        if (!value) 'deactivatedAt': DateTime.now(),
      });
      if (!mounted) return;
      ref.invalidate(alunosListProvider);
      ref.invalidate(alunosSearchProvider(''));
      setState(() {
        _isActive = value;
        if (value) _contractEndsAt = null;
        _loadingAccountAction = false;
      });
      showAppNotification(
        context,
        value
            ? 'Perfil ativado.'
            : 'Perfil desativado. O acesso foi bloqueado.',
        type: NotificationType.success,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingAccountAction = false);
      showAppNotification(
        context,
        'Não foi possível atualizar o perfil.',
        type: NotificationType.error,
      );
    }
  }

  bool get _hasScheduledContract =>
      _isActive && _contractEndsAt?.isAfter(DateTime.now()) == true;

  Future<void> _handleAccessAction() async {
    if (_hasScheduledContract) {
      await _cancelScheduledContract();
      return;
    }
    await _setProfileActive(!_isActive);
  }

  Future<void> _cancelScheduledContract() async {
    setState(() => _loadingAccountAction = true);
    try {
      await ref.read(userRepositoryProvider).updateUser(widget.client.uid, {
        'contractEndsAt': FieldValue.delete(),
        'deactivatedAt': FieldValue.delete(),
        'isActive': true,
      });
      if (!mounted) return;
      ref.invalidate(alunosListProvider);
      ref.invalidate(alunosSearchProvider(''));
      setState(() {
        _contractEndsAt = null;
        _isActive = true;
        _loadingAccountAction = false;
      });
      showAppNotification(
        context,
        'Término agendado cancelado. O perfil continua ativo.',
        type: NotificationType.success,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingAccountAction = false);
      showAppNotification(
        context,
        'Não foi possível cancelar o término agendado.',
        type: NotificationType.error,
      );
    }
  }

  Future<void> _terminateContract() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AdminResponsiveAlertDialog(
        backgroundColor: AdminThemeColors.of(context).surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AdminThemeColors.of(context).border),
        ),
        title: Text(
          'Terminar contrato',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: AdminThemeColors.of(context).text,
          ),
        ),
        content: Text(
          'Escolhe quando o acesso de ${widget.client.nome} deve terminar. Os dados do cliente serão mantidos.',
          style: GoogleFonts.inter(color: AdminThemeColors.of(context).muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'cancel'),
            child: const Text('Cancelar'),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(dialogContext, 'now'),
                icon: const Icon(Icons.block_outlined, size: 17),
                label: const Text('Terminar agora'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(dialogContext, 'later'),
                icon: const Icon(Icons.schedule, size: 17),
                label: const Text('Escolher data'),
              ),
            ],
          ),
        ],
      ),
    );

    if (!mounted || choice == null || choice == 'cancel') return;
    DateTime? endsAt;
    if (choice == 'later') {
      final today = DateTime.now();
      final date = await showDatePicker(
        context: context,
        firstDate: DateTime(today.year, today.month, today.day),
        lastDate: DateTime(today.year + 5),
        initialDate: _contractEndsAt?.isAfter(today) == true
            ? _contractEndsAt!
            : today.add(const Duration(days: 30)),
        helpText: 'Escolher dia de término',
        cancelText: 'Cancelar',
        confirmText: 'Continuar',
      );
      if (!mounted || date == null) return;
      final time = await showTimePicker(
        context: context,
        initialTime: _contractEndsAt != null
            ? TimeOfDay.fromDateTime(_contractEndsAt!)
            : TimeOfDay.now(),
        helpText: 'Escolher hora de término',
        cancelText: 'Cancelar',
        confirmText: 'Confirmar',
      );
      if (!mounted || time == null) return;
      endsAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (!endsAt.isAfter(DateTime.now())) {
        showAppNotification(
          context,
          'Escolhe uma data e hora futuras.',
          type: NotificationType.error,
        );
        return;
      }
    } else {
      endsAt = DateTime.now();
    }

    setState(() => _loadingAccountAction = true);
    try {
      await ref.read(userRepositoryProvider).updateUser(widget.client.uid, {
        'contractEndsAt': endsAt,
        'isActive': choice == 'later',
        if (choice != 'later') 'deactivatedAt': endsAt,
      });
      if (!mounted) return;
      ref.invalidate(alunosListProvider);
      ref.invalidate(alunosSearchProvider(''));
      setState(() {
        _contractEndsAt = endsAt;
        _isActive = choice == 'later';
        _loadingAccountAction = false;
      });
      showAppNotification(
        context,
        choice == 'later'
            ? 'Contrato agendado para ${DateFormat('dd/MM/yyyy HH:mm').format(endsAt!)}.'
            : 'Contrato terminado. O acesso foi bloqueado.',
        type: NotificationType.success,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingAccountAction = false);
      showAppNotification(
        context,
        'Não foi possível terminar o contrato.',
        type: NotificationType.error,
      );
    }
  }

  /// Garante que o aluno tem o personalId definido para o chat funcionar.
  Future<void> _ensurePersonalId() async {
    if (_personalIdSet) return;
    if (widget.client.personalId != null &&
        widget.client.personalId!.isNotEmpty) {
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

  EdgeInsets get _pad => EdgeInsets.fromLTRB(
    widget.isMobile ? 12 : 22,
    widget.isMobile ? 12 : 16,
    widget.isMobile ? 12 : 22,
    widget.isMobile ? 20 : 28,
  );

  BorderRadius get _detailRadius =>
      BorderRadius.circular(widget.isMobile ? 14 : 16);

  BoxShadow _detailShadow(AdminThemeColors colors) => BoxShadow(
    color: colors.shadow.withValues(alpha: 0.26),
    blurRadius: 10,
    offset: const Offset(0, 3),
  );

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
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 12,
          vertical: isMobile ? 6 : 8,
        ),
      ),
    );
  }

  Future<void> _requestProgress(UserModel client) async {
    setState(() => _requestingProgress = true);
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
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
                Icon(
                  Icons.arrow_back,
                  size: 14,
                  color: AdminThemeColors.of(context).muted,
                ),
                const SizedBox(width: 6),
                Text(
                  'Clientes',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AdminThemeColors.of(context).muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildClientProfileStrip(c),
          const SizedBox(height: 8),
          _buildAccountSummary(c),
          const SizedBox(height: 10),
          _buildTabs(),
          const SizedBox(height: 10),
          if (_tab == 'overview') _buildOverview(),
          if (_tab == 'progresso') _buildProgressTab(),
          if (_tab == 'workout') ...[
            _buildLoadProgressionChart(),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AdminThemeColors.of(context).surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AdminThemeColors.of(context).border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AdminThemeColors.of(context).lime,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Os planos são criados na área global “Treinos”. Aí podes adicionar exercícios, escolher os dias e atribuir o plano a este aluno.',
                      style: GoogleFonts.inter(
                        color: AdminThemeColors.of(context).muted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_tab == 'nutrition')
            SizedBox(height: 600, child: NutritionEditor(aluno: widget.client)),
          if (_tab == 'chat')
            SizedBox(
              height: 600,
              child: ChatScreen(
                trackChatPresence: false,
                chatPartnerId: widget.client.uid,
                chatPartnerName: widget.client.nome,
                chatPartnerPhoto: widget.client.fotoPerfil,
                key: ValueKey('admin_chat_${widget.client.uid}'),
              ),
            ),
          if (_tab == 'agenda') _buildAgendaTab(c),
        ],
      ),
    );
  }

  Widget _buildAccountManagement(UserModel c) {
    final colors = AdminThemeColors.of(context);
    final scheduled =
        _contractEndsAt != null &&
        _contractEndsAt!.isAfter(DateTime.now()) &&
        _isActive;
    final statusColor = !_isActive
        ? colors.danger
        : scheduled
        ? colors.orange
        : colors.lime;

    Widget statusPill() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: statusColor.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            scheduled
                ? Icons.schedule
                : (_isActive ? Icons.check_circle : Icons.block),
            size: 14,
            color: statusColor,
          ),
          const SizedBox(width: 6),
          Text(
            scheduled
                ? 'Termina ${DateFormat('dd/MM HH:mm').format(_contractEndsAt!)}'
                : (_isActive ? 'Perfil ativo' : 'Perfil inativo'),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: statusColor,
            ),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(widget.isMobile ? 14 : 18),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'GESTÃO DO CLIENTE',
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: colors.text,
                          letterSpacing: 0.04,
                        ),
                      ),
                      statusPill(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Flex(
                    direction: compact ? Axis.vertical : Axis.horizontal,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: compact ? 0 : 1,
                        child: _loadingNote
                            ? Text(
                                'A carregar nota privada...',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: colors.muted,
                                ),
                              )
                            : TextField(
                                controller: _noteController,
                                minLines: 2,
                                maxLines: 4,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: colors.text,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Nota interna',
                                  hintText:
                                      'Adiciona uma observação privada sobre este cliente...',
                                  prefixIcon: const Icon(
                                    Icons.sticky_note_2_outlined,
                                    size: 18,
                                  ),
                                  filled: true,
                                  fillColor: colors.bg,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: colors.border,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                      SizedBox(
                        width: compact ? 0 : 12,
                        height: compact ? 10 : 0,
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _savingNote || _loadingNote
                                ? null
                                : _saveAdminNote,
                            icon: _savingNote
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined, size: 16),
                            label: const Text('Guardar nota'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _loadingAccountAction
                                ? null
                                : _handleAccessAction,
                            icon: Icon(
                              _hasScheduledContract
                                  ? Icons.event_busy_outlined
                                  : (_isActive
                                        ? Icons.pause_circle_outline
                                        : Icons.play_circle_outline),
                              size: 17,
                            ),
                            label: Text(
                              _hasScheduledContract
                                  ? 'Cancelar término'
                                  : (_isActive
                                        ? 'Desativar perfil'
                                        : 'Ativar perfil'),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _loadingAccountAction
                                ? null
                                : _terminateContract,
                            icon: const Icon(
                              Icons.assignment_late_outlined,
                              size: 17,
                            ),
                            label: const Text('Terminar contrato'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_adminNote.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Nota privada guardada',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: colors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildClientProfileStrip(UserModel c) {
    final colors = AdminThemeColors.of(context);
    final isMobile = widget.isMobile;
    final initials = c.nome.trim().isEmpty
        ? '?'
        : c.nome
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((part) => part[0])
              .join()
              .toUpperCase();
    final statusColor = c.isAccessAllowed ? colors.lime : colors.danger;

    Widget metric(String label, String value) => Padding(
      padding: const EdgeInsets.only(right: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: colors.muted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colors.text,
            ),
          ),
        ],
      ),
    );

    final identity = Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: colors.limeDim,
          child: Text(
            initials,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: colors.lime,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.nome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.35,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                c.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 11, color: colors.muted),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  Text(
                    c.isOnline ? 'ONLINE' : 'PRESENCIAL',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                      color: colors.muted,
                    ),
                  ),
                  Text('•', style: TextStyle(fontSize: 9, color: colors.muted)),
                  Text(
                    c.accessStatus.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    final metrics = Wrap(
      spacing: 0,
      runSpacing: 10,
      children: [
        metric('Peso', '${c.pesoAtual?.toStringAsFixed(1) ?? '--'} kg'),
        metric('Altura', '${c.altura?.toStringAsFixed(0) ?? '--'} cm'),
        metric('IMC', c.imc?.toStringAsFixed(1) ?? '--'),
      ],
    );

    final actions = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _requestProgressButton(c),
        IconButton(
          tooltip: 'Reset password',
          onPressed: () => _resetStudentPassword(c),
          icon: Icon(Icons.lock_reset_rounded, size: 18, color: colors.orange),
          style: IconButton.styleFrom(
            backgroundColor: colors.orange.withValues(alpha: 0.1),
            minimumSize: const Size(38, 38),
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = isMobile || constraints.maxWidth < 980;
        return Container(
          padding: EdgeInsets.all(isMobile ? 14 : 16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    identity,
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: metrics),
                        const SizedBox(width: 10),
                        actions,
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(flex: 5, child: identity),
                    Container(width: 1, height: 38, color: colors.border),
                    const SizedBox(width: 18),
                    Expanded(flex: 4, child: metrics),
                    const SizedBox(width: 12),
                    actions,
                  ],
                ),
        );
      },
    );
  }

  Widget _buildAccountSummary(UserModel c) {
    final colors = AdminThemeColors.of(context);
    final scheduled =
        _contractEndsAt != null &&
        _contractEndsAt!.isAfter(DateTime.now()) &&
        _isActive;
    final statusColor = !_isActive
        ? colors.danger
        : scheduled
        ? colors.orange
        : colors.lime;
    final statusText = scheduled
        ? 'Termina ${DateFormat('dd/MM HH:mm').format(_contractEndsAt!)}'
        : (_isActive ? 'Acesso ativo' : 'Acesso bloqueado');

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 980;
          final note = _loadingNote
              ? Text(
                  'A carregar nota...',
                  style: GoogleFonts.inter(fontSize: 11, color: colors.muted),
                )
              : TextField(
                  controller: _noteController,
                  minLines: narrow ? 2 : 1,
                  maxLines: narrow ? 3 : 1,
                  style: GoogleFonts.inter(fontSize: 11, color: colors.text),
                  decoration: InputDecoration(
                    hintText: 'Nota interna privada',
                    prefixIcon: Icon(
                      Icons.sticky_note_2_outlined,
                      size: 16,
                      color: colors.muted,
                    ),
                    filled: true,
                    fillColor: colors.bg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: colors.border),
                    ),
                  ),
                );
          final actions = Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: _savingNote || _loadingNote ? null : _saveAdminNote,
                icon: _savingNote
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 14),
                label: const Text('Guardar nota'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.light
                      ? colors.text.withValues(alpha: 0.68)
                      : colors.surface2.withValues(alpha: 0.18),
                  side: BorderSide(color: Colors.transparent),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  minimumSize: const Size(0, 48),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _loadingAccountAction ? null : _handleAccessAction,
                icon: Icon(
                  _hasScheduledContract
                      ? Icons.event_busy_outlined
                      : (_isActive
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline),
                  size: 15,
                ),
                label: Text(
                  _hasScheduledContract
                      ? 'Cancelar término'
                      : (_isActive ? 'Desativar' : 'Ativar'),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.light
                      ? colors.text.withValues(alpha: 0.68)
                      : colors.surface2.withValues(alpha: 0.18),
                  side: BorderSide(color: Colors.transparent),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  minimumSize: const Size(0, 48),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _loadingAccountAction ? null : _terminateContract,
                icon: const Icon(Icons.assignment_late_outlined, size: 15),
                label: const Text('Terminar contrato'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.orange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  minimumSize: const Size(0, 46),
                ),
              ),
            ],
          );
          final status = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                statusText,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ],
          );
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune_rounded, size: 16, color: colors.muted),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Gestão do cliente',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: colors.text,
                        ),
                      ),
                    ),
                    status,
                  ],
                ),
                const SizedBox(height: 10),
                note,
                const SizedBox(height: 8),
                actions,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.tune_rounded, size: 16, color: colors.muted),
              const SizedBox(width: 7),
              Text(
                'Gestão',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: colors.text,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: note),
              const SizedBox(width: 10),
              status,
              const SizedBox(width: 10),
              actions,
            ],
          );
        },
      ),
    );
  }

  Widget _buildCompactClientHeader(UserModel c) {
    final colors = AdminThemeColors.of(context);
    final isCompact = widget.isMobile;
    final initials = c.nome.trim().isEmpty
        ? '?'
        : c.nome
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((part) => part[0])
              .join()
              .toUpperCase();

    Widget badge(String label, Color color, IconData icon) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: _detailRadius,
        border: Border.all(color: colors.border),
        boxShadow: [_detailShadow(colors)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: isCompact ? 22 : 25,
                backgroundColor: colors.limeDim,
                child: Text(
                  initials,
                  style: GoogleFonts.inter(
                    fontSize: isCompact ? 13 : 15,
                    fontWeight: FontWeight.w800,
                    color: colors.lime,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: isCompact ? 17 : 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      c.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: colors.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        badge(
                          c.isOnline ? 'Online' : 'Presencial',
                          c.isOnline ? colors.blue : colors.lime,
                          c.isOnline ? Icons.wifi : Icons.fitness_center,
                        ),
                        badge(
                          c.accessStatus,
                          c.isAccessAllowed ? colors.lime : colors.danger,
                          c.isAccessAllowed ? Icons.check_circle : Icons.block,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colors.bg.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(12),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final metrics = Row(
                  children: [
                    Expanded(
                      child: _compactClientMetric(
                        colors,
                        'Peso',
                        '${c.pesoAtual?.toStringAsFixed(1) ?? '--'} kg',
                      ),
                    ),
                    _compactMetricDivider(colors),
                    Expanded(
                      child: _compactClientMetric(
                        colors,
                        'Altura',
                        '${c.altura?.toStringAsFixed(0) ?? '--'} cm',
                      ),
                    ),
                    _compactMetricDivider(colors),
                    Expanded(
                      child: _compactClientMetric(
                        colors,
                        'IMC',
                        c.imc?.toStringAsFixed(1) ?? '--',
                      ),
                    ),
                  ],
                );
                if (isCompact || constraints.maxWidth < 560) return metrics;
                return Row(
                  children: [
                    Expanded(child: metrics),
                    const SizedBox(width: 12),
                    _requestProgressButton(c),
                  ],
                );
              },
            ),
          ),
          if (isCompact) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _requestProgressButton(c),
                TextButton.icon(
                  onPressed: () => _resetStudentPassword(c),
                  icon: Icon(Icons.lock_reset, size: 14, color: colors.orange),
                  label: const Text('Reset password'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 42),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _resetStudentPassword(c),
                icon: Icon(Icons.lock_reset, size: 14, color: colors.orange),
                label: Text(
                  'Reset password',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  minimumSize: const Size(0, 42),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _compactClientMetric(dynamic colors, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: colors.muted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
        ),
      ],
    );
  }

  Widget _compactMetricDivider(dynamic colors) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: colors.border,
    );
  }

  Widget _buildCompactAccountManagement(UserModel c) {
    final colors = AdminThemeColors.of(context);
    final scheduled =
        _contractEndsAt != null &&
        _contractEndsAt!.isAfter(DateTime.now()) &&
        _isActive;
    final statusColor = !_isActive
        ? colors.danger
        : scheduled
        ? colors.orange
        : colors.lime;
    final statusText = scheduled
        ? 'Termina ${DateFormat('dd/MM HH:mm').format(_contractEndsAt!)}'
        : (_isActive ? 'Acesso ativo' : 'Acesso bloqueado');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: _detailRadius,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 16, color: colors.muted),
              const SizedBox(width: 7),
              Text(
                'Gestão rápida',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: colors.text,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusText,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 760;
              final note = _loadingNote
                  ? Text(
                      'A carregar nota...',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: colors.muted,
                      ),
                    )
                  : TextField(
                      controller: _noteController,
                      minLines: stacked ? 2 : 1,
                      maxLines: stacked ? 3 : 2,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: colors.text,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Nota interna privada...',
                        prefixIcon: const Icon(
                          Icons.sticky_note_2_outlined,
                          size: 16,
                        ),
                        filled: true,
                        fillColor: colors.bg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: colors.border),
                        ),
                      ),
                    );
              final actions = Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  OutlinedButton.icon(
                    onPressed: _savingNote || _loadingNote
                        ? null
                        : _saveAdminNote,
                    icon: _savingNote
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined, size: 14),
                    label: const Text('Guardar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.light
                          ? colors.text.withValues(alpha: 0.68)
                          : colors.surface2.withValues(alpha: 0.18),
                      side: BorderSide(color: Colors.transparent),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loadingAccountAction
                        ? null
                        : _handleAccessAction,
                    icon: Icon(
                      _hasScheduledContract
                          ? Icons.event_busy_outlined
                          : (_isActive
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline),
                      size: 15,
                    ),
                    label: Text(
                      _hasScheduledContract
                          ? 'Cancelar término'
                          : (_isActive ? 'Desativar' : 'Ativar'),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.light
                          ? colors.text.withValues(alpha: 0.68)
                          : colors.surface2.withValues(alpha: 0.18),
                      side: BorderSide(color: Colors.transparent),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _loadingAccountAction
                        ? null
                        : _terminateContract,
                    icon: const Icon(Icons.assignment_late_outlined, size: 15),
                    label: const Text('Terminar contrato'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                ],
              );
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [note, const SizedBox(height: 8), actions],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: note),
                  const SizedBox(width: 10),
                  actions,
                ],
              );
            },
          ),
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
                          color: AdminThemeColors.of(context).lime,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        c.nome.toUpperCase(),
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.01,
                          color: AdminThemeColors.of(context).text,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: c.isOnline
                        ? AdminThemeColors.of(
                            context,
                          ).blue.withValues(alpha: 0.12)
                        : AdminThemeColors.of(context).limeDim,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    c.tipoClienteDisplay,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.isOnline
                          ? AdminThemeColors.of(context).blue
                          : AdminThemeColors.of(context).lime,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${c.pesoAtual?.toStringAsFixed(1) ?? '-'}kg · ${c.altura?.toStringAsFixed(0) ?? '-'}cm · IMC: ${c.imc?.toStringAsFixed(1) ?? '-'}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AdminThemeColors.of(context).muted,
                        ),
                      ),
                    ),
                    _requestProgressButton(c),
                    TextButton.icon(
                      onPressed: () => _resetStudentPassword(c),
                      icon: Icon(
                        Icons.lock_reset,
                        size: 13,
                        color: AdminThemeColors.of(context).orange,
                      ),
                      label: Text(
                        'Reset Password',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: AdminThemeColors.of(
                          context,
                        ).surface2.withValues(alpha: 0.18),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        minimumSize: const Size(0, 44),
                      ),
                    ),
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
                      color: AdminThemeColors.of(context).lime,
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.nome.toUpperCase(),
                              style: GoogleFonts.barlowCondensed(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.01,
                                color: AdminThemeColors.of(context).text,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: c.isOnline
                                  ? AdminThemeColors.of(
                                      context,
                                    ).blue.withValues(alpha: 0.12)
                                  : AdminThemeColors.of(context).limeDim,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: c.isOnline
                                    ? AdminThemeColors.of(
                                        context,
                                      ).blue.withValues(alpha: 0.3)
                                    : AdminThemeColors.of(
                                        context,
                                      ).lime.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              c.tipoClienteDisplay,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: c.isOnline
                                    ? AdminThemeColors.of(context).blue
                                    : AdminThemeColors.of(context).lime,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${c.pesoAtual?.toStringAsFixed(1) ?? '-'}kg · ${c.altura?.toStringAsFixed(0) ?? '-'}cm · IMC: ${c.imc?.toStringAsFixed(1) ?? '-'}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AdminThemeColors.of(context).muted,
                        ),
                      ),
                    ],
                  ),
                ),
                _requestProgressButton(c),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _resetStudentPassword(c),
                  icon: Icon(
                    Icons.lock_reset,
                    size: 14,
                    color: AdminThemeColors.of(context).orange,
                  ),
                  label: Text(
                    'Reset Password',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AdminThemeColors.of(context).orange,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _resetStudentPassword(UserModel c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AdminResponsiveAlertDialog(
        backgroundColor: AdminThemeColors.of(context).surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AdminThemeColors.of(context).border),
        ),
        title: Text(
          'Reset Password',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: AdminThemeColors.of(context).text,
          ),
        ),
        content: Text(
          'Vai ser enviado um email para ${c.email} com um link para redefinir a palavra-passe. Continuar?',
          style: GoogleFonts.inter(color: AdminThemeColors.of(context).muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.inter(
                color: AdminThemeColors.of(context).muted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminThemeColors.of(context).orange,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Enviar',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await ref.read(authProvider.notifier).sendPasswordResetEmail(c.email);
        if (mounted) {
          showAppNotification(
            context,
            'Email de redefinição enviado para ${c.email}.',
            type: NotificationType.success,
          );
        }
      } catch (_) {
        if (mounted) {
          showAppNotification(
            context,
            'Erro ao enviar email de redefinição.',
            type: NotificationType.error,
          );
        }
      }
    }
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
          _tabBtn(
            t.$1,
            widget.isMobile && t.$2 != 'Visão Geral' ? '' : t.$2,
            t.$3,
          ),
          const SizedBox(width: 4),
        ],
      ],
    );
    if (widget.isMobile) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: row,
      );
    }
    return row;
  }

  Widget _tabBtn(String id, String label, IconData icon) {
    final active = _tab == id;
    final isMobile = widget.isMobile;
    final tabWidget = GestureDetector(
      onTap: () {
        setState(() => _tab = id);
        ref.read(isAdminInChatProvider.notifier).state = id == 'chat';
        if (id == 'chat') _ensurePersonalId();
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 10,
          vertical: isMobile ? 6 : 7,
        ),
        decoration: BoxDecoration(
          color: active
              ? AdminThemeColors.of(context).limeDim
              : AdminThemeColors.of(context).surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? AdminThemeColors.of(context).lime
                : AdminThemeColors.of(context).border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: isMobile ? 18 : 14,
              color: active
                  ? AdminThemeColors.of(context).lime
                  : AdminThemeColors.of(context).muted,
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: isMobile ? 10 : 12,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active
                      ? AdminThemeColors.of(context).lime
                      : AdminThemeColors.of(context).muted,
                ),
              ),
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
                  Icon(
                    Icons.trending_up,
                    size: 16,
                    color: AdminThemeColors.of(context).blue,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'PROGRESSÃO (ONLINE)',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.03,
                      color: AdminThemeColors.of(context).text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...prog.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.exerciseName,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AdminThemeColors.of(context).text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${p.cargaAnterior?.toStringAsFixed(1) ?? '-'} → ${p.cargaAtual?.toStringAsFixed(1) ?? '-'} kg',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AdminThemeColors.of(context).muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (p.progrediu)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AdminThemeColors.of(
                              context,
                            ).lime.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '+${p.aumentoKg!.toStringAsFixed(1)}kg',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AdminThemeColors.of(context).lime,
                            ),
                          ),
                        )
                      else if (p.manteve)
                        Text(
                          '= manteve',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AdminThemeColors.of(context).muted,
                          ),
                        )
                      else
                        Text(
                          'novo',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AdminThemeColors.of(context).blue,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
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
        LayoutBuilder(
          builder: (_, constraints) {
            final wide = constraints.maxWidth > 700;
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildWeightChart()),
                  const SizedBox(width: 14),
                  SizedBox(width: 250, child: _buildInfoCards(c)),
                ],
              );
            }
            return Column(
              children: [
                _buildWeightChart(),
                const SizedBox(height: 12),
                _buildInfoCards(c),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildWeightChart() {
    final progressAsync = ref.watch(adminProgressProvider(widget.client.uid));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminThemeColors.of(context).surface,
        borderRadius: BorderRadius.circular(18),
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
          Text(
            'EVOLUÇÃO DE PESO',
            style: GoogleFonts.barlowCondensed(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.03,
              color: AdminThemeColors.of(context).text,
            ),
          ),
          const SizedBox(height: 16),
          progressAsync.when(
            data: (progressList) {
              final weightEntries =
                  progressList.where((p) => p.peso != null).toList()
                    ..sort((a, b) => a.data.compareTo(b.data));

              if (weightEntries.isEmpty) {
                return SizedBox(
                  height: 180,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.show_chart,
                          size: 40,
                          color: AdminThemeColors.of(context).muted,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sem dados de peso registados',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AdminThemeColors.of(context).muted,
                          ),
                        ),
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
                            .map((e) => FlSpot(e.key.toDouble(), e.value.peso!))
                            .toList(),
                        isCurved: true,
                        color: AdminThemeColors.of(context).lime,
                        barWidth: 2,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AdminThemeColors.of(
                            context,
                          ).lime.withValues(alpha: 0.08),
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
                  color: AdminThemeColors.of(context).lime,
                ),
              ),
            ),
            error: (_, __) => SizedBox(
              height: 180,
              child: Center(
                child: Text(
                  'Erro ao carregar dados',
                  style: GoogleFonts.inter(
                    color: AdminThemeColors.of(context).muted,
                  ),
                ),
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
                  Icon(
                    Icons.trending_up,
                    size: 48,
                    color: AdminThemeColors.of(context).muted,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nenhum registo de progresso',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AdminThemeColors.of(context).muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Solicita uma avaliação ao aluno',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AdminThemeColors.of(context).muted,
                    ),
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
        child: CircularProgressIndicator(
          color: AdminThemeColors.of(context).lime,
        ),
      ),
      error: (_, __) => Center(
        child: Text(
          'Erro ao carregar progresso',
          style: GoogleFonts.inter(color: AdminThemeColors.of(context).muted),
        ),
      ),
    );
  }

  Widget _buildProgressCard(ProgressModel progress) {
    final dateFormatted = DateFormat('d MMM yyyy', 'pt').format(progress.data);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminThemeColors.of(context).surface,
        borderRadius: BorderRadius.circular(18),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
            const SizedBox(height: 8),
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
            const SizedBox(height: 8),
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
                      child: Icon(
                        Icons.broken_image,
                        color: AdminThemeColors.of(context).muted,
                      ),
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
        label: Text(
          'COMPARAR ANTES / DEPOIS',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.03,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(
            color: AdminThemeColors.of(context).lime.withValues(alpha: 0.5),
          ),
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
        builder: (ctx, setDialogState) => AdminResponsiveAlertDialog(
          backgroundColor: AdminThemeColors.of(context).surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AdminThemeColors.of(context).border),
          ),
          title: Row(
            children: [
              Icon(
                Icons.compare,
                color: AdminThemeColors.of(context).lime,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Comparação Antes / Depois',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AdminThemeColors.of(context).text,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ImageComparisonSlider(
                  beforeImage: withPhotos[beforeIdx].fotos.first,
                  afterImage: withPhotos[afterIdx].fotos.first,
                  width: (MediaQuery.sizeOf(context).width -
                          (MediaQuery.sizeOf(context).width < 600 ? 60 : 108))
                      .clamp(1.0, 560.0)
                      .toDouble(),
                  height: 360,
                  dividerColor: AdminThemeColors.of(context).lime,
                  beforeLabel: 'Inicial',
                  afterLabel: 'Atual',
                  beforeDate: DateFormat(
                    'dd/MM/yyyy',
                  ).format(withPhotos[beforeIdx].data),
                  afterDate: DateFormat(
                    'dd/MM/yyyy',
                  ).format(withPhotos[afterIdx].data),
                  beforeDetail: withPhotos[beforeIdx].peso == null
                      ? null
                      : '${withPhotos[beforeIdx].peso!.toStringAsFixed(1)} kg',
                  afterDetail: withPhotos[afterIdx].peso == null
                      ? null
                      : '${withPhotos[afterIdx].peso!.toStringAsFixed(1)} kg',
                  cardColor: AdminThemeColors.of(context).surface,
                  handleColor: Colors.white,
                ),
                const SizedBox(height: 8),
                // Seletores
                Text(
                  'Seleciona as datas:',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AdminThemeColors.of(context).muted,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: beforeIdx,
                        decoration: InputDecoration(
                          labelText: 'Antes',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: withPhotos
                            .asMap()
                            .entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(
                                  DateFormat('dd/MM/yy').format(e.value.data),
                                  style: GoogleFonts.inter(fontSize: 12),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setDialogState(() => beforeIdx = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: afterIdx,
                        decoration: InputDecoration(
                          labelText: 'Depois',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: withPhotos
                            .asMap()
                            .entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(
                                  DateFormat('dd/MM/yy').format(e.value.data),
                                  style: GoogleFonts.inter(fontSize: 12),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setDialogState(() => afterIdx = v!),
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
                      color: AdminThemeColors.of(context).lime,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Fechar',
                style: GoogleFonts.inter(
                  color: AdminThemeColors.of(context).muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgendaTab(UserModel c) {
    final bookingsAsync = ref.watch(
      adminTrainerBookingsProvider(
        FirebaseAuth.instance.currentUser?.uid ?? '',
      ),
    );
    final isMobile = widget.isMobile;

    return bookingsAsync.when(
      data: (bookings) {
        final clientBookings =
            bookings.where((b) => b.studentId == c.uid).toList()
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
                  Icon(
                    Icons.calendar_today,
                    size: 48,
                    color: AdminThemeColors.of(context).muted,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nenhuma aula marcada',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AdminThemeColors.of(context).muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'O aluno ainda não marcou sessões.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AdminThemeColors.of(context).muted,
                    ),
                  ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AdminThemeColors.of(context).limeDim,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${clientBookings.length} marcações',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AdminThemeColors.of(context).lime,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ...clientBookings.map((b) => _buildBookingCard(b)),
          ],
        );
      },
      loading: () => Center(
        child: CircularProgressIndicator(
          color: AdminThemeColors.of(context).lime,
        ),
      ),
      error: (_, __) => Center(
        child: Text(
          'Erro',
          style: GoogleFonts.inter(color: AdminThemeColors.of(context).muted),
        ),
      ),
    );
  }

  Widget _buildBookingCard(BookingModel booking) {
    final dateFormatted = DateFormat(
      'EEE, d MMM yyyy',
      'pt',
    ).format(booking.data);
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
    final color =
        statusColors[booking.status] ?? AdminThemeColors.of(context).muted;
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
                Text(
                  booking.horaFormatada,
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: color,
                  ),
                ),
                Text(
                  booking.fimFormatado,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: color.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateFormatted.toUpperCase(),
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AdminThemeColors.of(context).text,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      booking.tipo == 'online'
                          ? Icons.videocam
                          : Icons.fitness_center,
                      size: 12,
                      color: AdminThemeColors.of(context).muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${booking.tipo == "online" ? "Online" : "Presencial"} · ${booking.duracaoMinutos}min',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AdminThemeColors.of(context).muted,
                      ),
                    ),
                  ],
                ),
                if (booking.notas != null && booking.notas!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      booking.notas!,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AdminThemeColors.of(context).muted,
                      ),
                    ),
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
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
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
                          color: AdminThemeColors.of(
                            context,
                          ).lime.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.check,
                          size: 14,
                          color: AdminThemeColors.of(context).lime,
                        ),
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
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.red,
                        ),
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
      await ref.read(bookingRepositoryProvider).updateBooking(booking.id, {
        'status': status,
      });
      ref.invalidate(
        adminTrainerBookingsProvider(
          FirebaseAuth.instance.currentUser?.uid ?? '',
        ),
      );
      // Notificar o aluno (só para confirm/cancel)
      if (status == 'confirmed' || status == 'cancelled') {
        fireBookingNotification(booking, status);
      }
      if (mounted) {
        showAppNotification(
          context,
          status == 'confirmed'
              ? 'Aula confirmada!'
              : status == 'cancelled'
              ? 'Aula cancelada.'
              : 'Aula atualizada.',
          type: NotificationType.success,
        );
      }
    } catch (_) {
      if (mounted)
        showAppNotification(
          context,
          'Erro ao atualizar.',
          type: NotificationType.error,
        );
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
        const SizedBox(height: 10),
        _infoCard('Contacto', [
          ('Email', c.email),
          ('ID', '${c.uid.substring(0, 8)}...'),
        ]),
      ],
    );
  }

  Widget _infoCard(String title, List<(String, String)> rows) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminThemeColors.of(context).surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AdminThemeColors.of(context).border),
        boxShadow: [_detailShadow(AdminThemeColors.of(context))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.barlowCondensed(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.05,
              color: AdminThemeColors.of(context).muted,
            ),
          ),
          const SizedBox(height: 8),
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    r.$1,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AdminThemeColors.of(context).muted,
                    ),
                  ),
                  Text(
                    r.$2,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AdminThemeColors.of(context).text,
                    ),
                  ),
                ],
              ),
            ),
          ),
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

class _AdminExerciseLibraryState extends ConsumerState<_AdminExerciseLibrary> {
  String _search = '';
  String _muscle = 'Todos';
  String _categoria = 'Todas';

  static const _muscles = [
    'Todos',
    'Peito',
    'Costas',
    'Quadríceps',
    'Posterior',
    'Ombros',
    'Bíceps',
    'Tríceps',
    'Core',
    'Glúteos',
  ];
  static const _categorias = ['Todas', 'musculação', 'funcional', 'cardio'];

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(adminExercisesProvider);
    final isMobile = MediaQuery.sizeOf(context).width < 900;

    return AdminPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: 'Exercícios',
            subtitle:
                '${exercisesAsync.asData?.value.length ?? 0} exercícios na biblioteca',
            icon: Icons.fitness_center_outlined,
            action: ElevatedButton.icon(
              onPressed: _showAddExerciseDialog,
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Novo exercício'),
            ),
          ),
          const SizedBox(height: 20),
          // Search
          SizedBox(
            width: isMobile ? double.infinity : 360,
            height: 40,
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AdminThemeColors.of(context).text,
              ),
              decoration: InputDecoration(
                hintText: 'Buscar exercício...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 13,
                  color: AdminThemeColors.of(context).muted,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 16,
                  color: AdminThemeColors.of(context).muted,
                ),
                filled: true,
                fillColor: AdminThemeColors.of(context).surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: AdminThemeColors.of(context).border,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: AdminThemeColors.of(context).border,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
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
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? AdminThemeColors.of(context).limeDim
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active
                          ? AdminThemeColors.of(context).lime
                          : AdminThemeColors.of(context).border,
                    ),
                  ),
                  child: Text(
                    m,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: active
                          ? AdminThemeColors.of(context).lime
                          : AdminThemeColors.of(context).muted,
                    ),
                  ),
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
              final labels = {
                'Todas': 'Todas',
                'musculação': 'Musculação',
                'funcional': 'Funcional',
                'cardio': 'Cardio',
              };
              return GestureDetector(
                onTap: () => setState(() => _categoria = c),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? AdminThemeColors.of(
                            context,
                          ).blue.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active
                          ? AdminThemeColors.of(context).blue
                          : AdminThemeColors.of(context).border,
                    ),
                  ),
                  child: Text(
                    labels[c]!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: active
                          ? AdminThemeColors.of(context).blue
                          : AdminThemeColors.of(context).muted,
                    ),
                  ),
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
                final matchCategoria =
                    _categoria == 'Todas' ||
                    cat.toLowerCase() == _categoria.toLowerCase();
                return matchSearch && matchMuscle && matchCategoria;
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(60),
                    child: Column(
                      children: [
                        Icon(
                          Icons.fitness_center,
                          size: 48,
                          color: AdminThemeColors.of(context).muted,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nenhum exercício encontrado',
                          style: GoogleFonts.inter(
                            color: AdminThemeColors.of(context).muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return LayoutBuilder(
                builder: (_, constraints) {
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
                      final grupo = e['grupoMuscular'] as String? ?? 'Geral';
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
                              color: AdminThemeColors.of(context).border,
                            ),
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
                                  color: AdminThemeColors.of(
                                    context,
                                  ).text.withValues(alpha: 0.04),
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                nome,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AdminThemeColors.of(context).text,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _exChip(
                                    grupo,
                                    AdminThemeColors.of(context).blue,
                                  ),
                                  const SizedBox(width: 6),
                                  _exChip(
                                    equipamento,
                                    AdminThemeColors.of(context).muted,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              );
            },
            loading: () => Center(
              child: CircularProgressIndicator(
                color: AdminThemeColors.of(context).lime,
              ),
            ),
            error: (_, __) => Center(
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 32,
                    color: AdminThemeColors.of(context).muted,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Erro ao carregar exercícios',
                    style: GoogleFonts.inter(
                      color: AdminThemeColors.of(context).muted,
                    ),
                  ),
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
      child: Text(label, style: GoogleFonts.inter(fontSize: 11, color: color)),
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
        builder: (ctx, setDialogState) => AdminResponsiveAlertDialog(
          backgroundColor: AdminThemeColors.of(context).surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AdminThemeColors.of(context).border),
          ),
          title: Text(
            'Novo Exercício',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: AdminThemeColors.of(context).text,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomeCtrl,
                  style: GoogleFonts.inter(
                    color: AdminThemeColors.of(context).text,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Nome do exercício',
                    labelStyle: GoogleFonts.inter(
                      color: AdminThemeColors.of(context).muted,
                    ),
                    filled: true,
                    fillColor: AdminThemeColors.of(context).bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedGrupo,
                  dropdownColor: AdminThemeColors.of(context).surface,
                  style: GoogleFonts.inter(
                    color: AdminThemeColors.of(context).text,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Grupo Muscular',
                    labelStyle: GoogleFonts.inter(
                      color: AdminThemeColors.of(context).muted,
                    ),
                    filled: true,
                    fillColor: AdminThemeColors.of(context).bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: _muscles
                      .where((m) => m != 'Todos')
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text(
                            m,
                            style: GoogleFonts.inter(
                              color: AdminThemeColors.of(context).text,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedGrupo = v ?? 'Peito'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategoria,
                  dropdownColor: AdminThemeColors.of(context).surface,
                  style: GoogleFonts.inter(
                    color: AdminThemeColors.of(context).text,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Categoria',
                    labelStyle: GoogleFonts.inter(
                      color: AdminThemeColors.of(context).muted,
                    ),
                    filled: true,
                    fillColor: AdminThemeColors.of(context).bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'musculação',
                      child: Text('Musculação'),
                    ),
                    DropdownMenuItem(
                      value: 'funcional',
                      child: Text('Funcional'),
                    ),
                    DropdownMenuItem(value: 'cardio', child: Text('Cardio')),
                  ],
                  onChanged: (v) => setDialogState(
                    () => selectedCategoria = v ?? 'musculação',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: equipCtrl,
                  style: GoogleFonts.inter(
                    color: AdminThemeColors.of(context).text,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ex: Barra, Halter, Máquina, Polia...',
                    labelText: 'Equipamento',
                    labelStyle: GoogleFonts.inter(
                      color: AdminThemeColors.of(context).muted,
                    ),
                    filled: true,
                    fillColor: AdminThemeColors.of(context).bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancelar',
                style: GoogleFonts.inter(
                  color: AdminThemeColors.of(context).muted,
                ),
              ),
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
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Adicionar',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
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
  ConsumerState<_AdminFoodLibrary> createState() => _AdminFoodLibraryState();
}

class _AdminFoodLibraryState extends ConsumerState<_AdminFoodLibrary> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final foodsAsync = ref.watch(adminFoodsSearchProvider(_search));

    return AdminPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: 'Alimentos',
            subtitle:
                '${foodsAsync.asData?.value.length ?? 0} alimentos na biblioteca',
            icon: Icons.restaurant_outlined,
            action: ElevatedButton.icon(
              onPressed: _showAddFoodDialog,
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Novo alimento'),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 360,
            height: 40,
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AdminThemeColors.of(context).text,
              ),
              decoration: InputDecoration(
                hintText: 'Buscar alimento...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 13,
                  color: AdminThemeColors.of(context).muted,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 16,
                  color: AdminThemeColors.of(context).muted,
                ),
                filled: true,
                fillColor: AdminThemeColors.of(context).surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: AdminThemeColors.of(context).border,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: AdminThemeColors.of(context).border,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
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
                        Icon(
                          Icons.restaurant,
                          size: 48,
                          color: AdminThemeColors.of(context).muted,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nenhum alimento encontrado',
                          style: GoogleFonts.inter(
                            color: AdminThemeColors.of(context).muted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Adiciona os primeiros alimentos à biblioteca.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AdminThemeColors.of(context).muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return LayoutBuilder(
                builder: (_, constraints) {
                  final cols = constraints.maxWidth > 900
                      ? 4
                      : (constraints.maxWidth > 600
                            ? 3
                            : (constraints.maxWidth > 400 ? 2 : 1));
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: foods.map((food) {
                      final w = (constraints.maxWidth - 14 * (cols - 1)) / cols;
                      return SizedBox(width: w, child: _foodCard(food));
                    }).toList(),
                  );
                },
              );
            },
            loading: () => Center(
              child: CircularProgressIndicator(
                color: AdminThemeColors.of(context).lime,
              ),
            ),
            error: (_, __) => Center(
              child: Text(
                'Erro',
                style: GoogleFonts.inter(
                  color: AdminThemeColors.of(context).muted,
                ),
              ),
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
        borderRadius: BorderRadius.circular(18),
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
                child: Text(
                  food.nome,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AdminThemeColors.of(context).text,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  catLabel.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: catColor,
                    letterSpacing: 0.06,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${food.caloriasPor100g.toStringAsFixed(0)} kcal / 100g',
            style: GoogleFonts.montserrat(
              fontSize: 13,
              color: AdminThemeColors.of(context).lime,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (food.proteinasPor100g != null)
                _macroChip(
                  'P: ${food.proteinasPor100g!.toStringAsFixed(1)}g',
                  AdminThemeColors.of(context).blue,
                ),
              if (food.hidratosPor100g != null) ...[
                const SizedBox(width: 4),
                _macroChip(
                  'C: ${food.hidratosPor100g!.toStringAsFixed(1)}g',
                  AdminThemeColors.of(context).orange,
                ),
              ],
              if (food.gordurasPor100g != null) ...[
                const SizedBox(width: 4),
                _macroChip(
                  'G: ${food.gordurasPor100g!.toStringAsFixed(1)}g',
                  AdminThemeColors.of(context).purple,
                ),
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
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
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
      'proteina',
      'hidrato',
      'gordura',
      'vegetal',
      'laticinio',
      'fruta',
      'bebida',
      'outro',
    ];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AdminResponsiveAlertDialog(
          backgroundColor: AdminThemeColors.of(context).surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AdminThemeColors.of(context).border),
          ),
          title: Text(
            'Novo Alimento',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: AdminThemeColors.of(context).text,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomeCtrl,
                  style: GoogleFonts.inter(
                    color: AdminThemeColors.of(context).text,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Nome do alimento',
                    labelStyle: GoogleFonts.inter(
                      color: AdminThemeColors.of(context).muted,
                    ),
                    filled: true,
                    fillColor: AdminThemeColors.of(context).bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: calCtrl,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.inter(
                    color: AdminThemeColors.of(context).text,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Calorias (por 100g/ml)',
                    labelStyle: GoogleFonts.inter(
                      color: AdminThemeColors.of(context).muted,
                    ),
                    filled: true,
                    fillColor: AdminThemeColors.of(context).bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: protCtrl,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.inter(
                          color: AdminThemeColors.of(context).text,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Proteína (g)',
                          labelStyle: GoogleFonts.inter(
                            color: AdminThemeColors.of(context).muted,
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: AdminThemeColors.of(context).bg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: carbCtrl,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.inter(
                          color: AdminThemeColors.of(context).text,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Hidratos (g)',
                          labelStyle: GoogleFonts.inter(
                            color: AdminThemeColors.of(context).muted,
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: AdminThemeColors.of(context).bg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: gordCtrl,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.inter(
                          color: AdminThemeColors.of(context).text,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Gordura (g)',
                          labelStyle: GoogleFonts.inter(
                            color: AdminThemeColors.of(context).muted,
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: AdminThemeColors.of(context).bg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedCat,
                  dropdownColor: AdminThemeColors.of(context).surface,
                  style: GoogleFonts.inter(
                    color: AdminThemeColors.of(context).text,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Categoria',
                    labelStyle: GoogleFonts.inter(
                      color: AdminThemeColors.of(context).muted,
                    ),
                    filled: true,
                    fillColor: AdminThemeColors.of(context).bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: categories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(
                            c,
                            style: GoogleFonts.inter(
                              color: AdminThemeColors.of(context).text,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedCat = v ?? 'proteina'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancelar',
                style: GoogleFonts.inter(
                  color: AdminThemeColors.of(context).muted,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nomeCtrl.text.trim().isEmpty) return;
                try {
                  await ref.read(nutritionRepositoryProvider).addFood({
                    'nome': nomeCtrl.text.trim(),
                    'caloriasPor100g':
                        double.tryParse(calCtrl.text.replaceAll(',', '.')) ?? 0,
                    'proteinasPor100g': double.tryParse(
                      protCtrl.text.replaceAll(',', '.'),
                    ),
                    'hidratosPor100g': double.tryParse(
                      carbCtrl.text.replaceAll(',', '.'),
                    ),
                    'gordurasPor100g': double.tryParse(
                      gordCtrl.text.replaceAll(',', '.'),
                    ),
                    'categoria': selectedCat,
                  });
                  ref.invalidate(adminFoodsProvider);
                  if (mounted) Navigator.pop(ctx);
                } catch (_) {}
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminThemeColors.of(context).lime,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Adicionar',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
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
    return AdminPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: 'Pagamentos',
            subtitle: 'Gestão de pagamentos e faturas via Stripe',
            icon: Icons.payments_outlined,
            action: ElevatedButton.icon(
              onPressed: _creating ? null : () => _showCreatePaymentDialog(),
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Novo pagamento'),
            ),
          ),
          const SizedBox(height: 20),
          paymentsAsync.when(
            data: (payments) => _buildPaymentsTable(payments),
            loading: () => Center(
              child: CircularProgressIndicator(
                color: AdminThemeColors.of(context).lime,
              ),
            ),
            error: (e, _) => Center(
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 40,
                    color: AdminThemeColors.of(context).muted,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Erro ao carregar pagamentos',
                    style: GoogleFonts.inter(
                      color: AdminThemeColors.of(context).muted,
                    ),
                  ),
                  Text(
                    e.toString(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AdminThemeColors.of(context).muted,
                    ),
                  ),
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
              Icon(
                Icons.payment,
                size: 48,
                color: AdminThemeColors.of(context).muted,
              ),
              const SizedBox(height: 8),
              Text(
                'Nenhum pagamento registado',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AdminThemeColors.of(context).muted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Clica em "Novo Pagamento" para criar uma sessão de checkout',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AdminThemeColors.of(context).muted,
                ),
              ),
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
              border: Border(
                bottom: BorderSide(color: AdminThemeColors.of(context).border),
              ),
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
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.06,
          color: AdminThemeColors.of(context).muted,
        ),
      ),
    );
  }

  Widget _paymentRow(PaymentModel payment) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final userAsync = ref.watch(
      FutureProvider<UserModel?>((ref) async {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(payment.userId)
              .get();
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

    final statusColor =
        statusColors[payment.status] ?? AdminThemeColors.of(context).muted;
    final statusLabel =
        statusLabels[payment.status] ?? payment.status.toUpperCase();

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AdminThemeColors.of(context).border),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: userAsync.when(
                    data: (u) => Text(
                      u?.nome ?? 'Aluno',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: AdminThemeColors.of(context).text,
                      ),
                    ),
                    loading: () => Text(
                      '...',
                      style: GoogleFonts.inter(
                        color: AdminThemeColors.of(context).muted,
                      ),
                    ),
                    error: (_, __) => Text(
                      'Aluno',
                      style: GoogleFonts.inter(
                        color: AdminThemeColors.of(context).muted,
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              payment.descricao ?? 'Mensalidade',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AdminThemeColors.of(context).muted,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  payment.valorFormatado,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AdminThemeColors.of(context).text,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('d MMM yyyy', 'pt').format(payment.data),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AdminThemeColors.of(context).muted,
                  ),
                ),
              ],
            ),
            if (payment.faturaUrl != null) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _openInvoice(payment.faturaUrl!),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.picture_as_pdf,
                      size: 14,
                      color: AdminThemeColors.of(context).lime,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Ver fatura',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AdminThemeColors.of(context).lime,
                      ),
                    ),
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
        border: Border(
          bottom: BorderSide(color: AdminThemeColors.of(context).border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: userAsync.when(
              data: (u) => Text(
                u?.nome ?? 'Aluno',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: AdminThemeColors.of(context).text,
                ),
              ),
              loading: () => Text(
                '...',
                style: GoogleFonts.inter(
                  color: AdminThemeColors.of(context).muted,
                ),
              ),
              error: (_, __) => Text(
                'Aluno',
                style: GoogleFonts.inter(
                  color: AdminThemeColors.of(context).muted,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              payment.descricao ?? 'Mensalidade',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AdminThemeColors.of(context).muted,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              payment.valorFormatado,
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AdminThemeColors.of(context).text,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              DateFormat('d MMM yyyy', 'pt').format(payment.data),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AdminThemeColors.of(context).muted,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                statusLabel,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: payment.faturaUrl != null
                ? IconButton(
                    icon: Icon(
                      Icons.picture_as_pdf,
                      color: AdminThemeColors.of(context).lime,
                      size: 18,
                    ),
                    onPressed: () => _openInvoice(payment.faturaUrl!),
                    tooltip: 'Ver fatura',
                  )
                : (payment.status == 'pending' &&
                          payment.stripeSessionId != null
                      ? IconButton(
                          icon: Icon(
                            Icons.refresh,
                            color: AdminThemeColors.of(context).orange,
                            size: 18,
                          ),
                          onPressed: () =>
                              ref.invalidate(adminAllPaymentsProvider),
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
        BoxShadow(
          color: AdminThemeColors.of(context).shadow,
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  void _openInvoice(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _showCreatePaymentDialog() async {
    final alunosAsync = ref.read(alunosListProvider);
    final alunos = alunosAsync.asData?.value ?? [];

    if (alunos.isEmpty) {
      showAppNotification(
        context,
        'Nenhum aluno disponível.',
        type: NotificationType.error,
      );
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
        builder: (ctx, setDialogState) => AdminResponsiveAlertDialog(
          backgroundColor: AdminThemeColors.of(context).surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AdminThemeColors.of(context).border),
          ),
          title: Text(
            'Novo Pagamento',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: AdminThemeColors.of(context).text,
            ),
          ),
          content: checkoutUrl != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 48,
                      color: AdminThemeColors.of(context).lime,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sessão de checkout criada!',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: AdminThemeColors.of(context).text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'URL de pagamento:',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AdminThemeColors.of(context).muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AdminThemeColors.of(context).bg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: SelectableText(
                        checkoutUrl!,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AdminThemeColors.of(context).lime,
                        ),
                      ),
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
                      style: GoogleFonts.inter(
                        color: AdminThemeColors.of(context).text,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Aluno',
                        labelStyle: GoogleFonts.inter(
                          color: AdminThemeColors.of(context).muted,
                        ),
                        filled: true,
                        fillColor: AdminThemeColors.of(context).bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: AdminThemeColors.of(context).border,
                          ),
                        ),
                      ),
                      items: alunos
                          .map(
                            (a) =>
                                DropdownMenuItem(value: a, child: Text(a.nome)),
                          )
                          .toList(),
                      onChanged: (v) => setDialogState(() => selectedAluno = v),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: valorCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: GoogleFonts.inter(
                        color: AdminThemeColors.of(context).text,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Valor (€)',
                        hintText: 'Ex: 29.99',
                        labelStyle: GoogleFonts.inter(
                          color: AdminThemeColors.of(context).muted,
                        ),
                        filled: true,
                        fillColor: AdminThemeColors.of(context).bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: AdminThemeColors.of(context).border,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descCtrl,
                      style: GoogleFonts.inter(
                        color: AdminThemeColors.of(context).text,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Descrição',
                        labelStyle: GoogleFonts.inter(
                          color: AdminThemeColors.of(context).muted,
                        ),
                        filled: true,
                        fillColor: AdminThemeColors.of(context).bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: AdminThemeColors.of(context).border,
                          ),
                        ),
                      ),
                    ),
                    if (loading) ...[
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        color: AdminThemeColors.of(context).lime,
                      ),
                    ],
                  ],
                ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx),
              child: Text(
                checkoutUrl != null ? 'Fechar' : 'Cancelar',
                style: GoogleFonts.inter(
                  color: AdminThemeColors.of(context).muted,
                ),
              ),
            ),
            if (checkoutUrl == null)
              ElevatedButton(
                onPressed:
                    loading ||
                        selectedAluno == null ||
                        valorCtrl.text.trim().isEmpty
                    ? null
                    : () async {
                        final valor = double.tryParse(
                          valorCtrl.text.trim().replaceAll(',', '.'),
                        );
                        if (valor == null || valor <= 0) return;
                        setDialogState(() => loading = true);
                        try {
                          final repo = ref.read(paymentRepositoryProvider);
                          final url = await repo.createCheckoutSession(
                            userId: selectedAluno!.uid,
                            valor: valor,
                            descricao: descCtrl.text.trim().isEmpty
                                ? 'Mensalidade'
                                : descCtrl.text.trim(),
                          );
                          setDialogState(() {
                            loading = false;
                            checkoutUrl = url;
                          });
                          ref.invalidate(adminAllPaymentsProvider);
                        } catch (e) {
                          setDialogState(() => loading = false);
                          showAppNotification(
                            ctx,
                            'Erro: ${e.toString()}',
                            type: NotificationType.error,
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminThemeColors.of(context).lime,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  'Criar Sessão',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
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
    final isMobile = MediaQuery.sizeOf(context).width < 900;

    return AdminPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: 'Agenda',
            subtitle: 'Planeia e acompanha as sessões da semana',
            icon: Icons.calendar_month_outlined,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.chevron_left,
                  color: AdminThemeColors.of(context).muted,
                ),
                onPressed: () => setState(() {
                  _selectedDate = _selectedDate.subtract(
                    const Duration(days: 7),
                  );
                }),
                tooltip: 'Semana anterior',
              ),
              GestureDetector(
                onTap: () => _pickMonth(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('MMMM yyyy', 'pt').format(_selectedDate),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AdminThemeColors.of(context).text,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down,
                      size: 20,
                      color: AdminThemeColors.of(context).muted,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.chevron_right,
                  color: AdminThemeColors.of(context).muted,
                ),
                onPressed: () => setState(() {
                  _selectedDate = _selectedDate.add(const Duration(days: 7));
                }),
                tooltip: 'Próxima semana',
              ),
            ],
          ),
          const SizedBox(height: 24),
          bookingsAsync.when(
            data: (bookings) {
              final names = namesAsync.asData?.value ?? {};
              return _buildWeeklyGrid(bookings, names, isMobile);
            },
            loading: () => Center(
              child: CircularProgressIndicator(
                color: AdminThemeColors.of(context).lime,
              ),
            ),
            error: (e, __) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Erro: ${e.toString()}',
                style: GoogleFonts.inter(
                  color: AdminThemeColors.of(context).muted,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyGrid(
    List<BookingModel> bookings,
    Map<String, String> studentNames,
    bool isMobile,
  ) {
    final monday = _selectedDate.subtract(
      Duration(days: _selectedDate.weekday - 1),
    );
    final weekDays = List.generate(7, (i) => monday.add(Duration(days: i)));
    final today = DateTime.now();
    const hours = [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18];

    final Map<int, List<BookingModel>> bookingsByDay = {};
    for (int i = 0; i < 7; i++) {
      final d = weekDays[i];
      bookingsByDay[i] = bookings
          .where(
            (b) =>
                b.data.year == d.year &&
                b.data.month == d.month &&
                b.data.day == d.day,
          )
          .toList();
    }

    const kTimeCol = 48.0;
    final gridWidth = isMobile
        ? 700.0
        : (MediaQuery.of(context).size.width * 0.75).clamp(300.0, 1200.0);
    final colWidth = (gridWidth - kTimeCol) / 7.0;

    final gridBody = Column(
      children: hours
          .map(
            (hour) => _buildGridRow(
              hour,
              weekDays,
              today,
              bookingsByDay,
              studentNames,
              colWidth,
            ),
          )
          .toList(),
    );

    return Container(
      decoration: BoxDecoration(
        color: AdminThemeColors.of(context).surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminThemeColors.of(context).border),
      ),
      child: isMobile
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: gridWidth,
                child: Column(
                  children: [
                    _buildWeekHeader(weekDays, today, true, colWidth),
                    gridBody,
                  ],
                ),
              ),
            )
          : Column(
              children: [
                _buildWeekHeader(weekDays, today, false, colWidth),
                gridBody,
              ],
            ),
    );
  }

  Widget _buildWeekHeader(
    List<DateTime> weekDays,
    DateTime today,
    bool isMobile,
    double colWidth,
  ) {
    const dayLabels = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AdminThemeColors.of(context).border),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 48),
          ...List.generate(7, (i) {
            final d = weekDays[i];
            final isToday =
                d.year == today.year &&
                d.month == today.month &&
                d.day == today.day;
            final isSelected =
                d.year == _selectedDate.year &&
                d.month == _selectedDate.month &&
                d.day == _selectedDate.day;
            return SizedBox(
              width: colWidth,
              child: GestureDetector(
                onTap: () => setState(() => _selectedDate = d),
                child: Column(
                  children: [
                    Text(
                      dayLabels[i],
                      style: GoogleFonts.inter(
                        fontSize: isMobile ? 10 : 11,
                        fontWeight: FontWeight.w600,
                        color: AdminThemeColors.of(context).muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: isToday || isSelected ? 30 : null,
                      height: isToday || isSelected ? 30 : null,
                      alignment: Alignment.center,
                      decoration: (isToday || isSelected)
                          ? BoxDecoration(
                              color: isSelected
                                  ? AdminThemeColors.of(context).lime
                                  : AdminThemeColors.of(
                                      context,
                                    ).orange.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            )
                          : null,
                      child: Text(
                        '${d.day}',
                        style: GoogleFonts.montserrat(
                          fontSize: isMobile ? 13 : 15,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? AdminThemeColors.of(context).bg
                              : AdminThemeColors.of(context).text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGridRow(
    int hour,
    List<DateTime> weekDays,
    DateTime today,
    Map<int, List<BookingModel>> bookingsByDay,
    Map<String, String> studentNames,
    double colWidth,
  ) {
    final now = DateTime.now();

    return Container(
      height: 52,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AdminThemeColors.of(context).border.withValues(alpha: 0.25),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            padding: const EdgeInsets.only(right: 8, top: 2),
            alignment: Alignment.topRight,
            child: Text(
              '${hour.toString().padLeft(2, '0')}:00',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: AdminThemeColors.of(
                  context,
                ).muted.withValues(alpha: 0.4),
              ),
            ),
          ),
          ...List.generate(7, (dayIndex) {
            final d = weekDays[dayIndex];
            final slotStart = DateTime(d.year, d.month, d.day, hour, 0);
            final slotEnd = slotStart.add(const Duration(minutes: 60));
            final isToday =
                d.year == today.year &&
                d.month == today.month &&
                d.day == today.day;
            final isPast = isToday && slotEnd.isBefore(now);

            final dayBookings = bookingsByDay[dayIndex] ?? [];
            BookingModel? booking;
            for (final b in dayBookings) {
              final bEnd = b.data.add(Duration(minutes: b.duracaoMinutos));
              if (slotStart.isBefore(bEnd) && slotEnd.isAfter(b.data)) {
                booking = b;
                break;
              }
            }

            return SizedBox(
              width: colWidth,
              child: Container(
                margin: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: booking != null
                      ? _cellColor(booking)
                      : (isPast
                            ? AdminThemeColors.of(
                                context,
                              ).bg.withValues(alpha: 0.3)
                            : Colors.transparent),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: booking != null
                    ? _buildCell(booking, studentNames)
                    : null,
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _cellColor(BookingModel b) {
    if (b.isPending) {
      return AdminThemeColors.of(context).orange.withValues(alpha: 0.18);
    }
    if (b.isConfirmed) {
      return AdminThemeColors.of(context).lime.withValues(alpha: 0.22);
    }
    return Colors.red.withValues(alpha: 0.06);
  }

  Widget _buildCell(BookingModel b, Map<String, String> studentNames) {
    final studentName =
        studentNames[b.studentId] ??
        (b.studentId.length > 6
            ? '${b.studentId.substring(0, 6)}'
            : b.studentId);
    final accent = b.isPending
        ? AdminThemeColors.of(context).orange
        : b.isConfirmed
        ? AdminThemeColors.of(context).lime
        : Colors.red.withValues(alpha: 0.5);

    return GestureDetector(
      onTap: () => _showBookingPopup(b, studentName),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              b.horaFormatada,
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              studentName,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AdminThemeColors.of(context).text,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showBookingPopup(BookingModel b, String studentName) {
    showDialog(
      context: context,
      builder: (ctx) => AdminResponsiveAlertDialog(
        backgroundColor: AdminThemeColors.of(context).surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          '${b.horaFormatada} — $studentName',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            color: AdminThemeColors.of(context).text,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _popupRow(
              'Estado',
              b.isPending
                  ? 'Pendente'
                  : b.isConfirmed
                  ? 'Confirmada'
                  : 'Cancelada',
            ),
            _popupRow('Tipo', b.tipo == 'online' ? 'Online' : 'Presencial'),
            _popupRow('Duração', '${b.duracaoMinutos}min'),
            _popupRow('Data', DateFormat('dd/MM/yyyy', 'pt').format(b.data)),
          ],
        ),
        actions: [
          if (b.isPending) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _updateStatus(b, 'cancelled');
              },
              child: const Text('Recusar', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _updateStatus(b, 'confirmed');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminThemeColors.of(context).lime,
              ),
              child: Text(
                'Aceitar',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
          if (b.isConfirmed) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _updateStatus(b, 'cancelled');
              },
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.red),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _updateStatus(b, 'completed');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminThemeColors.of(context).blue,
              ),
              child: const Text(
                'Concluir',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
          if (!b.isPending && !b.isConfirmed)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fechar'),
            ),
        ],
      ),
    );
  }

  Widget _popupRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: AdminThemeColors.of(context).text,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: AdminThemeColors.of(context).muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDatePickerMode: DatePickerMode.year,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AdminThemeColors.of(context).lime,
            onPrimary: AdminThemeColors.of(context).bg,
            surface: AdminThemeColors.of(context).surface,
            onSurface: AdminThemeColors.of(context).text,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _updateStatus(BookingModel booking, String status) async {
    try {
      await ref.read(bookingRepositoryProvider).updateBooking(booking.id, {
        'status': status,
      });
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
        showAppNotification(
          context,
          'Aula ${msgs[status] ?? status}!',
          type: NotificationType.success,
        );
      }
    } catch (_) {
      if (mounted) {
        showAppNotification(
          context,
          'Erro ao atualizar.',
          type: NotificationType.error,
        );
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

// ═══════════════════════════════════════════════════════════════════
// Admin Settings View
// ═══════════════════════════════════════════════════════════════════

class _AdminSettingsView extends ConsumerWidget {
  const _AdminSettingsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final userId = authState.user?.uid ?? '';
    final userAsync = ref.watch(userProfileProvider(userId));

    return userAsync.when(
      data: (user) {
        SoundService().setSound(user.notificationSound ?? defaultSoundAsset);
        return AdminPageFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminPageHeader(
                title: 'Definições',
                subtitle: 'Configura o teu perfil e preferências',
                icon: Icons.tune_outlined,
              ),
              const SizedBox(height: 22),
              _buildProfileCard(context, ref, user),
              const SizedBox(height: 24),
              _buildSoundPicker(context, ref, user),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Erro ao carregar perfil')),
    );
  }

  Widget _buildProfileCard(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminThemeColors.of(context).surface,
        borderRadius: BorderRadius.circular(18),
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
              Icon(
                Icons.person,
                color: AdminThemeColors.of(context).lime,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'PERFIL',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.03,
                  color: AdminThemeColors.of(context).text,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _editAdminProfile(context, ref, user),
                icon: Icon(
                  Icons.edit,
                  size: 14,
                  color: AdminThemeColors.of(context).lime,
                ),
                label: Text(
                  'Editar',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AdminThemeColors.of(context).lime,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _changeAdminPassword(context, ref, user),
                icon: Icon(
                  Icons.lock_reset,
                  size: 14,
                  color: AdminThemeColors.of(context).orange,
                ),
                label: Text(
                  'Senha',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              GestureDetector(
                onTap: () => _changePhoto(context, ref, user),
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AdminThemeColors.of(context).surface2,
                      backgroundImage: user.fotoPerfil != null
                          ? NetworkImage(user.fotoPerfil!)
                          : null,
                      child: user.fotoPerfil == null
                          ? Text(
                              user.nome.isNotEmpty
                                  ? user.nome[0].toUpperCase()
                                  : '?',
                              style: GoogleFonts.barlowCondensed(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AdminThemeColors.of(context).lime,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AdminThemeColors.of(context).lime,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.nome,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AdminThemeColors.of(context).text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AdminThemeColors.of(context).muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.role == 'admin' ? 'Administrador' : 'Aluno',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSoundPicker(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
  ) {
    final currentSound = user.notificationSound ?? defaultSoundAsset;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminThemeColors.of(context).surface,
        borderRadius: BorderRadius.circular(18),
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
              Icon(
                Icons.music_note,
                color: AdminThemeColors.of(context).lime,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'SOM DE NOTIFICAÇÃO',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.03,
                  color: AdminThemeColors.of(context).text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Escolhe o som que toca nas notificações',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AdminThemeColors.of(context).muted,
            ),
          ),
          const SizedBox(height: 16),
          ...notificationSoundOptions.map((option) {
            final isSelected = option.asset == currentSound;
            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AdminThemeColors.of(context).lime.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: InkWell(
                onTap: () async {
                  SoundService().setSound(option.asset);
                  try {
                    await ref.read(userRepositoryProvider).updateUser(
                      user.uid,
                      {'notificationSound': option.asset},
                    );
                    ref.invalidate(userProfileProvider(user.uid));
                  } catch (_) {
                    SoundService().setSound(currentSound);
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isSelected
                            ? AdminThemeColors.of(context).lime
                            : AdminThemeColors.of(context).muted,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          option.name,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: AdminThemeColors.of(context).text,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          SoundService().setSound(option.asset);
                          SoundService().playNotificationChime();
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AdminThemeColors.of(
                              context,
                            ).lime.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: AdminThemeColors.of(context).lime,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _changeAdminPassword(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AdminResponsiveAlertDialog(
        backgroundColor: AdminThemeColors.of(context).surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AdminThemeColors.of(context).border),
        ),
        title: Text(
          'Alterar palavra-passe',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: AdminThemeColors.of(context).text,
          ),
        ),
        content: Text(
          'Vai ser enviado um email para ${user.email} com um link para redefinir a tua palavra-passe. Continuar?',
          style: GoogleFonts.inter(color: AdminThemeColors.of(context).muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.inter(
                color: AdminThemeColors.of(context).muted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminThemeColors.of(context).orange,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Enviar',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await ref
            .read(authProvider.notifier)
            .sendPasswordResetEmail(user.email);
        if (context.mounted) {
          showAppNotification(
            context,
            'Email de redefinição enviado para ${user.email}.',
            type: NotificationType.success,
          );
        }
      } catch (_) {
        if (context.mounted) {
          showAppNotification(
            context,
            'Erro ao enviar email de redefinição.',
            type: NotificationType.error,
          );
        }
      }
    }
  }

  Future<void> _editAdminProfile(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
  ) async {
    final nomeCtrl = TextEditingController(text: user.nome);
    final emailCtrl = TextEditingController(text: user.email);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AdminResponsiveAlertDialog(
        backgroundColor: AdminThemeColors.of(context).surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AdminThemeColors.of(context).border),
        ),
        title: Text(
          'Editar Perfil',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: AdminThemeColors.of(context).text,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeCtrl,
                style: GoogleFonts.inter(
                  color: AdminThemeColors.of(context).text,
                ),
                decoration: InputDecoration(
                  labelText: 'Nome',
                  labelStyle: GoogleFonts.inter(
                    color: AdminThemeColors.of(context).muted,
                  ),
                  filled: true,
                  fillColor: AdminThemeColors.of(context).bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: AdminThemeColors.of(context).border,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.inter(
                  color: AdminThemeColors.of(context).text,
                ),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: GoogleFonts.inter(
                    color: AdminThemeColors.of(context).muted,
                  ),
                  filled: true,
                  fillColor: AdminThemeColors.of(context).bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: AdminThemeColors.of(context).border,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.inter(
                color: AdminThemeColors.of(context).muted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminThemeColors.of(context).lime,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Guardar',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      final updates = <String, dynamic>{};
      final novoNome = nomeCtrl.text.trim();
      final novoEmail = emailCtrl.text.trim();
      if (novoNome.isNotEmpty && novoNome != user.nome)
        updates['nome'] = novoNome;
      if (novoEmail.isNotEmpty && novoEmail != user.email)
        updates['email'] = novoEmail;
      if (updates.isNotEmpty) {
        try {
          await ref.read(userRepositoryProvider).updateUser(user.uid, updates);
          ref.invalidate(userProfileProvider(user.uid));
          if (context.mounted) {
            showAppNotification(
              context,
              'Perfil atualizado!',
              type: NotificationType.success,
            );
          }
        } catch (_) {
          if (context.mounted) {
            showAppNotification(
              context,
              'Erro ao atualizar perfil.',
              type: NotificationType.error,
            );
          }
        }
      }
    }
  }

  Future<void> _changePhoto(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
  ) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked == null) return;
    try {
      final bytes = await picked.readAsBytes();
      final url = await ref
          .read(progressRepositoryProvider)
          .uploadProfilePhoto(user.uid, Uint8List.fromList(bytes));
      await ref.read(userRepositoryProvider).updateUser(user.uid, {
        'fotoPerfil': url,
      });
      ref.invalidate(userProfileProvider(user.uid));
    } catch (_) {}
  }
}
