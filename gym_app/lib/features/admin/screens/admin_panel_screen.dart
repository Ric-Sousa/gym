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
import '../../../core/config/app_colors.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/utils/progress_photo_resolver.dart';
import '../../../core/utils/storage_resource.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/food_model.dart';
import '../../../data/models/progress_model.dart';
import '../../../data/models/payment_model.dart';
import '../../../data/models/questionnaire_response_model.dart';
import '../../../data/models/questionnaire_config_model.dart';
import '../../../data/models/exercise_catalog_model.dart';
import '../../../data/models/booking_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/providers/global_providers.dart';
import '../../../shared/widgets/admin_responsive_dialog.dart';
import '../../../shared/widgets/admin_design_system.dart';
import '../../../shared/widgets/app_design_system.dart';
import '../../../shared/providers/admin_providers.dart';
import '../../../shared/utils/booking_notifications.dart';
import '../../../shared/widgets/image_comparison_slider.dart';
import '../../../shared/widgets/app_notification.dart';
import 'global_workout_plans_screen.dart';
import 'questionnaire_management_screen.dart';
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
  nutrition,
  messages,
  payments,
  agenda,
  questionnaire,
  settings,
}

final alunosListProvider = StreamProvider<List<UserModel>>((ref) {
  return ref.read(userRepositoryProvider).watchAllAlunos();
});

final alunosSearchProvider = StreamProvider.family<List<UserModel>, String>((
  ref,
  query,
) {
  final alunos = ref.watch(alunosListProvider);
  return alunos.when(
    data: (items) {
      if (query.trim().isEmpty) return Stream.value(items);
      final lower = query.trim().toLowerCase();
      return Stream.value(
        items
            .where(
              (aluno) =>
                  aluno.nome.toLowerCase().contains(lower) ||
                  aluno.email.toLowerCase().contains(lower),
            )
            .toList(),
      );
    },
    loading: () => const Stream.empty(),
    error: (error, stack) => Stream.error(error, stack),
  );
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
      fcmService.onForegroundMessage = (message) {
        if (mounted) FCMService.showLocalNotification(context, message);
      };
      fcmService.onNotificationOpened = (message) {
        if (!mounted) return;
        if (message.data['type'] == 'chat') {
          _navigate(AdminView.messages);
        }
      };
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
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: _selectedClient != null
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
                  : Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: double.infinity,
                        child: _buildView(),
                      ),
                    ),
            ),
            if (_selectedClient == null)
              FloatingChatButton(
                onViewProfile: (aluno) {
                  setState(() {
                    _selectedClient = aluno;
                    _openSelectedClientChat = false;
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
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(
                        child: _selectedClient != null
                            ? _ClientDetailView(
                                client: _selectedClient!,
                                initialTab: _openSelectedClientChat
                                    ? 'chat'
                                    : 'overview',
                                isMobile: false,
                                onBack: () {
                                  ref
                                          .read(isAdminInChatProvider.notifier)
                                          .state =
                                      false;
                                  setState(() {
                                    _selectedClient = null;
                                    _openSelectedClientChat = false;
                                  });
                                },
                              )
                            : Align(
                                alignment: Alignment.topCenter,
                                child: SizedBox(
                                  width: double.infinity,
                                  child: _buildView(),
                                ),
                              ),
                      ),
                      if (_selectedClient == null)
                        FloatingChatButton(
                          onViewProfile: (aluno) {
                            setState(() {
                              _selectedClient = aluno;
                              _openSelectedClientChat = false;
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
      case AdminView.nutrition:
        return const _AdminNutritionView();
      case AdminView.payments:
        return const _AdminPaymentsView();
      case AdminView.agenda:
        return const _AdminAgendaView();
      case AdminView.questionnaire:
        return const QuestionnaireManagementScreen();
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
      decoration: BoxDecoration(color: colors.surface),
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
                  _NavItem(
                    icon: Icons.assignment_outlined,
                    activeIcon: Icons.assignment,
                    label: 'Questionário',
                    active: currentView == AdminView.questionnaire,
                    onTap: () => onNavigate(AdminView.questionnaire),
                  ),
                  _NavCategory(label: 'PLANO'),
                  _NavItem(
                    icon: Icons.restaurant_menu_outlined,
                    activeIcon: Icons.restaurant_menu,
                    label: 'Nutrições',
                    active: currentView == AdminView.nutrition,
                    onTap: () => onNavigate(AdminView.nutrition),
                  ),
                  _NavItem(
                    icon: Icons.fitness_center_outlined,
                    activeIcon: Icons.fitness_center,
                    label: 'Treinos',
                    active: currentView == AdminView.workouts,
                    onTap: () => onNavigate(AdminView.workouts),
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
    final colors = AdminThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: colors.muted,
            ),
          ),
        ],
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
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      color: active
                          ? AdminThemeColors.of(context).text
                          : AdminThemeColors.of(context).muted,
                    ),
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
        // No mobile os indicadores ficam compactos e 2x2 para evitar
        // demasiado espaço vertical. No desktop mantêm a altura original.
        final isMobile = MediaQuery.sizeOf(context).width < 900;
        final columns = constraints.maxWidth >= 900 ? 4 : 2;
        final width = (constraints.maxWidth - 14 * (columns - 1)) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: isMobile
                      ? SizedBox(
                          height: 132,
                          child: AdminMetric(
                            label: item.$1,
                            value: item.$2,
                            icon: item.$3,
                            accent: item.$4,
                          ),
                        )
                      : AdminMetric(
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
        final isMobile = MediaQuery.sizeOf(context).width < 900;
        final cols = constraints.maxWidth >= 900 ? 4 : 2;
        final width = (constraints.maxWidth - 14 * (cols - 1)) / cols;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: items.map((s) {
            final card = _statCard(s.$1, s.$2, s.$3, s.$4);
            return SizedBox(
              width: width,
              child: isMobile ? SizedBox(height: 132, child: card) : card,
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
    return SizedBox(
      width: double.infinity,
      child: LayoutBuilder(
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
      ),
    );
  }

  Widget _clientsCard(List<UserModel> alunos) {
    return Container(
      decoration: BoxDecoration(
        color: AdminThemeColors.of(context).surface,
        borderRadius: BorderRadius.circular(18),
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
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
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
                        textAlign: TextAlign.left,
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.03,
                          color: AdminThemeColors.of(context).text,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (alunos.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 48,
                      color: AdminThemeColors.of(context).muted,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nenhum aluno cadastrado',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: AdminThemeColors.of(context).muted,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Clique em "Clientes" para adicionar o primeiro.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: AdminThemeColors.of(context).muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
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
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AdminThemeColors.of(context).surface2,
              child: Text(
                aluno.nome.isNotEmpty ? aluno.nome[0].toUpperCase() : '?',
                style: GoogleFonts.montserrat(
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
    final namesAsync = ref.watch(adminStudentNamesProvider(trainerId));
    final studentNames = namesAsync.asData?.value ?? const <String, String>{};
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminThemeColors.of(context).surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AdminThemeColors.of(context).shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'AGENDA DA SEMANA',
            textAlign: TextAlign.left,
            style: GoogleFonts.montserrat(
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
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 36,
                          color: AdminThemeColors.of(context).muted,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nenhuma aula esta semana',
                          textAlign: TextAlign.center,
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: weekBookings.take(5).map((b) {
                  final dateStr = DateFormat('EEE d/M', 'pt').format(b.data);
                  final studentName = studentNames[b.studentId] ?? 'Aluno';
                  final isOnline = b.tipo == 'online';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AdminThemeColors.of(context).surface2,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 70,
                            height: 54,
                            decoration: BoxDecoration(
                              color: AdminThemeColors.of(context).limeDim,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  b.horaFormatada,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AdminThemeColors.of(context).lime,
                                  ),
                                ),
                                Text(
                                  'até ${b.fimFormatado}',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    color: AdminThemeColors.of(context).muted,
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
                                  studentName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AdminThemeColors.of(context).text,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 4,
                                  children: [
                                    _agendaDetail(
                                      Icons.calendar_today_outlined,
                                      dateStr,
                                    ),
                                    _agendaDetail(
                                      isOnline
                                          ? Icons.videocam_outlined
                                          : Icons.fitness_center_outlined,
                                      isOnline ? 'Online' : 'Presencial',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _statusBadge(b.status),
                        ],
                      ),
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

  Widget _agendaDetail(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AdminThemeColors.of(context).muted),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AdminThemeColors.of(context).muted,
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(String status) {
    final normalizedStatus = status
        .trim()
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('-', '_');
    final colors = {
      'confirmed': AdminThemeColors.of(context).lime,
      'approved': AdminThemeColors.of(context).lime,
      'accepted': AdminThemeColors.of(context).lime,
      'pending': Colors.orange,
      'completed': AdminThemeColors.of(context).blue,
      'cancelled': Colors.red,
      'canceled': Colors.red,
      'rejected': Colors.red,
    };
    final labels = {
      'confirmed': 'OK',
      'approved': 'OK',
      'accepted': 'OK',
      'pending': 'Pendente',
      'completed': 'Concluída',
      'cancelled': 'Cancelada',
      'canceled': 'Cancelada',
      'rejected': 'Recusada',
    };
    final color =
        colors[normalizedStatus] ?? AdminThemeColors.of(context).muted;
    final label = labels[normalizedStatus] ?? status;
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminThemeColors.of(context).surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AdminThemeColors.of(context).shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'MÉTRICAS',
            textAlign: TextAlign.left,
            style: GoogleFonts.montserrat(
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    g.$1,
                    textAlign: TextAlign.left,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AdminThemeColors.of(context).muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${g.$2}',
                    textAlign: TextAlign.left,
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: AdminThemeColors.of(context).text,
                    ),
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

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final isMobile = MediaQuery.sizeOf(context).width < 900;
    final studentsPager = ref.watch(adminStudentsPagerProvider);
    final search = _search.trim().toLowerCase();
    final loadedStudents = search.isEmpty
        ? studentsPager.items
        : studentsPager.items
              .where(
                (student) =>
                    student.nome.toLowerCase().contains(search) ||
                    student.email.toLowerCase().contains(search),
              )
              .toList();
    final AsyncValue<List<UserModel>> alunosAsync =
        studentsPager.isLoading && studentsPager.items.isEmpty
        ? const AsyncLoading<List<UserModel>>()
        : studentsPager.error != null
        ? AsyncError<List<UserModel>>(studentsPager.error!, StackTrace.current)
        : AsyncData<List<UserModel>>(loadedStudents);

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
          _buildNewClientsToolbar(isMobile, colors),
          const SizedBox(height: 16),
          alunosAsync.when(
            data: (alunos) => _buildNewClientDirectory(alunos, colors),
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(vertical: 72),
              child: Center(
                child: CircularProgressIndicator(color: colors.lime),
              ),
            ),
            error: (_, __) => _clientsErrorState(colors),
          ),
          if (studentsPager.hasMore) ...[
            const SizedBox(height: 18),
            Center(
              child: OutlinedButton.icon(
                onPressed: studentsPager.isLoading
                    ? null
                    : studentsPager.loadMore,
                icon: studentsPager.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded, size: 18),
                label: Text(
                  studentsPager.isLoading
                      ? 'A carregar...'
                      : 'Carregar mais clientes',
                ),
              ),
            ),
          ],
          if (isMobile) ...[
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: _newClientButton()),
          ],
        ],
      ),
    );
  }

  Widget _buildNewClientsToolbar(bool isMobile, AdminThemeColors colors) {
    final search = SizedBox(
      height: 44,
      child: TextField(
        onChanged: (value) => setState(() => _search = value),
        style: GoogleFonts.inter(fontSize: 13, color: colors.text),
        decoration: InputDecoration(
          hintText: 'Pesquisar clientes',
          hintStyle: GoogleFonts.inter(fontSize: 12, color: colors.muted),
          prefixIcon: Icon(Icons.search_rounded, size: 19, color: colors.muted),
          suffixIcon: _search.isEmpty
              ? null
              : IconButton(
                  onPressed: () => setState(() => _search = ''),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 17,
                    color: colors.muted,
                  ),
                ),
          filled: true,
          fillColor: colors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(color: colors.lime, width: 1.2),
          ),
        ),
      ),
    );
    final filter = SizedBox(
      width: 190,
      child: AppMenuDropdown<String>(
        value: _filter,
        options: const ['all', 'active', 'inactive'],
        labelBuilder: (value) => switch (value) {
          'active' => 'Apenas ativos',
          'inactive' => 'Apenas inativos',
          _ => 'Todos os clientes',
        },
        onChanged: (value) => setState(() => _filter = value),
        label: 'Filtrar clientes',
        accentColor: colors.lime,
        fieldColor: colors.surface,
        menuColor: colors.surface2,
        textColor: colors.text,
        labelColor: colors.muted,
      ),
    );

    final content = isMobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: filter),
            ],
          )
        : Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 8),
              filter,
            ],
          );

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(16),
      ),
      child: content,
    );
  }

  List<UserModel> _filteredClients(List<UserModel> alunos) {
    final search = _search.trim().toLowerCase();
    return alunos.where((aluno) {
      final matchesSearch = search.isEmpty ||
          aluno.nome.toLowerCase().contains(search) ||
          aluno.email.toLowerCase().contains(search);
      final matchesFilter = switch (_filter) {
        'active' => aluno.isAccessAllowed,
        'inactive' => !aluno.isAccessAllowed,
        _ => true,
      };
      return matchesSearch && matchesFilter;
    }).toList();
  }

  String _accessDateLabel(UserModel aluno) {
    final endsAt = aluno.contractEndsAt;
    if (endsAt == null) return aluno.isActive ? 'Sem data' : 'Bloqueado';
    return DateFormat('dd/MM/yyyy').format(endsAt);
  }

  Widget _buildNewClientDirectory(
    List<UserModel> alunos,
    AdminThemeColors colors,
  ) {
    final filtered = _filteredClients(alunos);
    if (filtered.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 58, horizontal: 24),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Icon(Icons.person_search_outlined, size: 42, color: colors.muted),
            const SizedBox(height: 10),
            Text(
              'Nenhum cliente encontrado',
              style: GoogleFonts.inter(
                color: colors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Experimenta alterar a pesquisa ou o filtro.',
              style: GoogleFonts.inter(fontSize: 12, color: colors.muted),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 3
            : (constraints.maxWidth >= 650 ? 2 : 1);
        final gap = 12.0;
        final cardWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: filtered
              .map(
                (aluno) =>
                    SizedBox(width: cardWidth, child: _newClientCard(aluno)),
              )
              .toList(),
        );
      },
    );
  }

  Widget _newClientCard(UserModel aluno) {
    final colors = AdminThemeColors.of(context);
    final photo = aluno.fotoPerfil?.trim();
    final active = aluno.isAccessAllowed;
    final typeLabel = aluno.tipoCliente == 'online' ? 'Online' : 'Presencial';

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => widget.onSelect(aluno),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StorageAvatar(
                    resource: photo,
                    radius: 25,
                    backgroundColor: colors.limeDim,
                    fallback: Text(
                      aluno.nome.trim().isEmpty
                          ? '?'
                          : aluno.nome.trim()[0].toUpperCase(),
                      style: GoogleFonts.montserrat(
                        color: colors.lime,
                        fontSize: 17,
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
                            color: colors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          aluno.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: colors.muted,
                            fontSize: 11,
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
                            Icon(
                              Icons.delete_outline,
                              size: 17,
                              color: Colors.red,
                            ),
                            SizedBox(width: 8),
                            Text('Eliminar cliente'),
                          ],
                        ),
                      ),
                    ],
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      size: 20,
                      color: colors.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _clientInfoPill(
                    Icons.circle,
                    active ? 'Ativo' : 'Bloqueado',
                    active ? colors.lime : colors.danger,
                  ),
                  _clientInfoPill(
                    aluno.tipoCliente == 'online'
                        ? Icons.wifi_rounded
                        : Icons.fitness_center_outlined,
                    typeLabel,
                    colors.muted,
                  ),
                  if (aluno.contractEndsAt != null)
                    _clientInfoPill(
                      Icons.event_outlined,
                      _accessDateLabel(aluno),
                      colors.muted,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: colors.border),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Ver perfil',
                    style: GoogleFonts.inter(
                      color: colors.lime,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: colors.lime,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _clientInfoPill(IconData icon, String label, Color color) {
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color == colors.muted ? colors.text : color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
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

  // ─── Create Student Dialog ──────────────────────────────────────

  Future<void> _showCreateStudentDialog() async {
    final nomeCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AdminThemeColors.of(context).bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 18,
                        color: AdminThemeColors.of(context).lime,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Acesso inicial ativo por 1 mês. O término é calculado no momento da criação.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AdminThemeColors.of(context).muted,
                          ),
                        ),
                      ),
                    ],
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
                        };
                        if (pw.isNotEmpty) body['password'] = pw;

                        final response = await http.post(
                          Uri.parse(
                            'https://europe-west1-gymbt-4ef87.cloudfunctions.net/createStudentHttp',
                          ),
                          headers: {
                            'Content-Type': 'application/json',
                            'Authorization': 'Bearer ${token ?? ''}',
                          },
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
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token ?? ''}',
        },
        body: json.encode({'userId': aluno.uid}),
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

// ─── Nutrition workspace ──────────────────────────────────────────

class _AdminNutritionView extends ConsumerStatefulWidget {
  const _AdminNutritionView();

  @override
  ConsumerState<_AdminNutritionView> createState() =>
      _AdminNutritionViewState();
}

class _AdminNutritionViewState extends ConsumerState<_AdminNutritionView> {
  UserModel? _selectedStudent;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final studentsAsync = ref.watch(alunosListProvider);
    final compact = MediaQuery.sizeOf(context).width < 700;

    return AdminPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: 'Nutrição',
            subtitle: 'Cria e acompanha planos nutricionais por aluno.',
            icon: Icons.restaurant_menu_rounded,
          ),
          const SizedBox(height: 24),
          if (_selectedStudent == null)
            studentsAsync.when(
              data: (students) => _buildStudentPicker(students, compact),
              loading: () =>
                  Center(child: CircularProgressIndicator(color: colors.lime)),
              error: (_, __) => AdminSurface(
                child: Text(
                  'Não foi possível carregar os alunos.',
                  style: GoogleFonts.inter(color: colors.muted),
                ),
              ),
            )
          else ...[
            _buildSelectedStudentHeader(_selectedStudent!, compact),
            const SizedBox(height: 16),
            SizedBox(
              height: (MediaQuery.sizeOf(context).height * 0.72)
                  .clamp(560.0, 900.0)
                  .toDouble(),
              child: NutritionEditor(aluno: _selectedStudent!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStudentPicker(List<UserModel> students, bool compact) {
    final colors = AdminThemeColors.of(context);
    final filtered = students.where((student) {
      final query = _query.trim().toLowerCase();
      return query.isEmpty ||
          student.nome.toLowerCase().contains(query) ||
          student.email.toLowerCase().contains(query);
    }).toList();

    return AdminSurface(
      padding: EdgeInsets.all(compact ? 16 : 24),
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.person_search_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Escolhe um aluno',
                      style: GoogleFonts.montserrat(
                        fontSize: compact ? 18 : 22,
                        fontWeight: FontWeight.w800,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Seleciona um perfil para criar ou editar o plano.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: colors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            onChanged: (value) => setState(() => _query = value),
            style: GoogleFonts.inter(fontSize: 13, color: colors.text),
            decoration: InputDecoration(
              hintText: 'Pesquisar por nome ou email',
              prefixIcon: Icon(Icons.search_rounded, color: colors.muted),
            ),
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'Nenhum aluno encontrado.',
                  style: GoogleFonts.inter(color: colors.muted),
                ),
              ),
            )
          else
            ...filtered.map((student) => _studentTile(student)),
        ],
      ),
    );
  }

  Widget _studentTile(UserModel student) {
    final colors = AdminThemeColors.of(context);
    final initials = student.nome.trim().isEmpty
        ? '?'
        : student.nome
              .trim()
              .split(RegExp(r'\\s+'))
              .take(2)
              .map((part) => part[0])
              .join()
              .toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colors.bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => setState(() => _selectedStudent = student),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                  child: Text(
                    initials,
                    style: GoogleFonts.inter(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.nome,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        student.email,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: colors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedStudentHeader(UserModel student, bool compact) {
    final colors = AdminThemeColors.of(context);
    final identity = Row(
      children: [
        CircleAvatar(
          radius: compact ? 21 : 22,
          backgroundColor: AppColors.primary.withValues(alpha: 0.14),
          child: Text(
            student.nome.isNotEmpty ? student.nome[0].toUpperCase() : '?',
            style: GoogleFonts.inter(
              color: AppColors.primary,
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
                student.nome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.montserrat(
                  fontSize: compact ? 16 : 19,
                  fontWeight: FontWeight.w800,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Plano nutricional',
                style: GoogleFonts.inter(fontSize: 11, color: colors.muted),
              ),
            ],
          ),
        ),
      ],
    );
    final swapButton = TextButton.icon(
      onPressed: () => setState(() => _selectedStudent = null),
      icon: const Icon(Icons.sync_alt_rounded, size: 17),
      label: const Text('Trocar'),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        backgroundColor: AppColors.primary.withValues(alpha: 0.14),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        minimumSize: const Size(0, 42),
      ),
    );

    return AdminSurface(
      padding: EdgeInsets.all(compact ? 14 : 18),
      color: colors.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = compact || constraints.maxWidth < 430;
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: swapButton),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: identity),
              const SizedBox(width: 12),
              swapButton,
            ],
          );
        },
      ),
    );
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
  bool _loadingAccountAction = false;
  bool _loadingNote = true;
  bool _savingNote = false;
  int _progressPage = 0;
  static const _progressPageSize = 3;
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
      setState(() => _savingNote = false);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
      final date = await showAppDatePicker(
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
            ? 'Contrato agendado para ${DateFormat('dd/MM/yyyy HH:mm').format(endsAt)}.'
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
    final liveClient = ref.watch(userProfileProvider(widget.client.uid));
    final c = liveClient.asData?.value ?? widget.client;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        widget.isMobile ? 14 : 28,
        widget.isMobile ? 14 : 24,
        widget.isMobile ? 14 : 28,
        widget.isMobile ? 28 : 40,
      ),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildModernBackButton(),
            const SizedBox(height: 16),
            _buildModernClientHeader(c),
            const SizedBox(height: 14),
            _buildModernAccountPanel(),
            const SizedBox(height: 18),
            _buildModernTabs(),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: switch (_tab) {
                  'overview' => _buildOverview(),
                  'progresso' => _buildProgressTab(),
                  'chat' => SizedBox(
                    key: ValueKey('chat_${c.uid}'),
                    height: 620,
                    child: ChatScreen(
                      trackChatPresence: false,
                      chatPartnerId: c.uid,
                      chatPartnerName: c.nome,
                      chatPartnerPhoto: c.fotoPerfil,
                    ),
                  ),
                  'agenda' => _buildAgendaTab(c),
                  _ => _buildOverview(),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernBackButton() {
    final colors = AdminThemeColors.of(context);
    return Semantics(
      button: true,
      label: 'Voltar para clientes',
      child: InkWell(
        onTap: widget.onBack,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back_rounded, size: 17, color: colors.muted),
              const SizedBox(width: 8),
              Text(
                'Clientes',
                style: GoogleFonts.inter(
                  color: colors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, size: 16, color: colors.border),
              const SizedBox(width: 6),
              Text(
                'Ficha do cliente',
                style: GoogleFonts.inter(fontSize: 12, color: colors.text),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernClientHeader(UserModel c) {
    final colors = AdminThemeColors.of(context);
    final photo = c.fotoPerfil?.trim();
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
    final statusLabel = c.isAccessAllowed
        ? 'Acesso autorizado'
        : 'Acesso bloqueado';

    Widget badge(String label, Color color, IconData icon) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: EdgeInsets.all(widget.isMobile ? 18 : 24),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final identity = Row(
                children: [
                  StorageAvatar(
                    resource: photo,
                    radius: widget.isMobile ? 29 : 34,
                    backgroundColor: colors.limeDim,
                    fallback: Text(
                      initials,
                      style: GoogleFonts.inter(
                        color: colors.lime,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: colors.text,
                            fontSize: widget.isMobile ? 20 : 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.7,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          c.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: colors.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            badge(
                              c.isOnline ? 'Online' : 'Presencial',
                              c.isOnline ? colors.blue : colors.lime,
                              c.isOnline
                                  ? Icons.wifi_rounded
                                  : Icons.fitness_center_rounded,
                            ),
                            badge(
                              statusLabel,
                              statusColor,
                              c.isAccessAllowed
                                  ? Icons.check_rounded
                                  : Icons.block_rounded,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _requestProgressButton(c),
                  OutlinedButton.icon(
                    onPressed: () => _resetStudentPassword(c),
                    icon: Icon(
                      Icons.lock_reset_rounded,
                      size: 16,
                      color: colors.orange,
                    ),
                    label: const Text('Redefinir palavra-passe'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.text,
                      side: BorderSide(color: colors.border),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [identity, const SizedBox(height: 16), actions],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 18),
                  actions,
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: colors.border),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final metrics = [
                (
                  'Peso atual',
                  '${c.pesoAtual?.toStringAsFixed(1) ?? '--'} kg',
                  Icons.monitor_weight_outlined,
                ),
                (
                  'Altura',
                  '${c.altura?.toStringAsFixed(0) ?? '--'} cm',
                  Icons.height_rounded,
                ),
                (
                  'IMC',
                  c.imc?.toStringAsFixed(1) ?? '--',
                  Icons.insights_outlined,
                ),
              ];
              return Wrap(
                spacing: compact ? 10 : 0,
                runSpacing: 10,
                children: metrics.map((metric) {
                  final item = Container(
                    width: compact
                        ? (constraints.maxWidth - 10) / 2
                        : constraints.maxWidth / 3,
                    padding: const EdgeInsets.only(right: 14),
                    child: Row(
                      children: [
                        Icon(metric.$3, size: 17, color: colors.muted),
                        const SizedBox(width: 9),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              metric.$1,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: colors.muted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              metric.$2,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: colors.text,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                  return item;
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModernAccountPanel() {
    final colors = AdminThemeColors.of(context);
    final statusColor = _hasScheduledContract
        ? colors.orange
        : (_isActive ? colors.lime : colors.danger);
    final status = _hasScheduledContract
        ? 'Término agendado para ${DateFormat('dd/MM/yyyy HH:mm').format(_contractEndsAt!)}'
        : (_isActive
              ? 'O cliente pode utilizar a aplicação'
              : 'O acesso do cliente está bloqueado');

    return Container(
      padding: EdgeInsets.all(widget.isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 18, color: statusColor),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Controlo de acesso',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: colors.text,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _hasScheduledContract
                      ? 'Agendado'
                      : (_isActive ? 'Ativo' : 'Bloqueado'),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            status,
            style: GoogleFonts.inter(fontSize: 11, color: colors.muted),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final note = TextField(
                controller: _noteController,
                enabled: !_loadingNote,
                minLines: compact ? 2 : 1,
                maxLines: compact ? 3 : 1,
                style: GoogleFonts.inter(fontSize: 12, color: colors.text),
                decoration: InputDecoration(
                  labelText: 'Nota interna',
                  hintText: _loadingNote
                      ? 'A carregar nota privada...'
                      : 'Observação visível apenas para a equipa',
                  prefixIcon: Icon(
                    Icons.sticky_note_2_outlined,
                    size: 18,
                    color: colors.muted,
                  ),
                  filled: true,
                  fillColor: colors.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.border),
                  ),
                ),
              );
              final actions = Wrap(
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
                            child: CircularProgressIndicator(strokeWidth: 2),
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
                      size: 16,
                    ),
                    label: Text(
                      _hasScheduledContract
                          ? 'Cancelar término'
                          : (_isActive ? 'Desativar acesso' : 'Ativar acesso'),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _loadingAccountAction
                        ? null
                        : _terminateContract,
                    icon: const Icon(Icons.assignment_late_outlined, size: 16),
                    label: const Text('Terminar contrato'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              );
              return compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [note, const SizedBox(height: 10), actions],
                    )
                  : Row(
                      children: [
                        Expanded(child: note),
                        const SizedBox(width: 12),
                        actions,
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModernTabs() {
    final colors = AdminThemeColors.of(context);
    const tabs = [
      ('overview', 'Resumo', Icons.grid_view_rounded),
      ('progresso', 'Progresso', Icons.trending_up_rounded),
      ('agenda', 'Agenda', Icons.calendar_today_rounded),
    ];
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.map((tab) {
            final active = _tab == tab.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: InkWell(
                onTap: () {
                  setState(() => _tab = tab.$1);
                  ref.read(isAdminInChatProvider.notifier).state =
                      tab.$1 == 'chat';
                  if (tab.$1 == 'chat') _ensurePersonalId();
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.isMobile ? 12 : 16,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: active ? colors.lime : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tab.$3,
                        size: 16,
                        color: active ? Colors.white : colors.muted,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        tab.$2,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.white : colors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _resetStudentPassword(UserModel c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AdminResponsiveAlertDialog(
        backgroundColor: AdminThemeColors.of(context).surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  Widget _buildOverview() {
    final c = widget.client;
    return Column(
      children: [
        _buildWeightChart(),
        const SizedBox(height: 14),
        _buildQuestionnaireCard(c),
      ],
    );
  }

  Widget _buildQuestionnaireCard(UserModel client) {
    final colors = AdminThemeColors.of(context);
    final questionnaireAsync = ref.watch(
      adminQuestionnaireProvider(client.uid),
    );
    final config = ref.watch(questionnaireConfigProvider).asData?.value;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: questionnaireAsync.when(
        loading: () => Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.lime,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'A carregar ficha inicial...',
              style: GoogleFonts.inter(color: colors.muted),
            ),
          ],
        ),
        error: (_, __) => Text(
          'Não foi possível carregar a ficha inicial.',
          style: GoogleFonts.inter(color: colors.muted),
        ),
        data: (response) {
          if (response == null ||
              !(config?.isResponseComplete(response) ?? response.isComplete)) {
            return Row(
              children: [
                Icon(Icons.assignment_late_outlined, color: colors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'O aluno ainda não concluiu a ficha inicial.',
                    style: GoogleFonts.inter(color: colors.muted),
                  ),
                ),
              ],
            );
          }

          final labels = <String, String>{
            ...QuestionnaireResponse.labels,
            for (final topic in config?.topics ?? const <QuestionnaireTopic>[])
              for (final question in topic.questions)
                question.id: question.label,
            for (final topic in config?.topics ?? const <QuestionnaireTopic>[])
              for (final question in topic.questions)
                if (question.hasDetail)
                  question.resolvedDetailId: question.detailLabel!,
          };
          final entries = labels.entries
              .where((entry) => response.answers.containsKey(entry.key))
              .map(
                (entry) => (
                  entry.key,
                  entry.value,
                  response.answers[entry.key] ?? '—',
                ),
              )
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.assignment_turned_in_outlined, color: colors.lime),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'FICHA INICIAL',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: colors.text,
                      ),
                    ),
                  ),
                  Text(
                    'Preenchida em ${DateFormat('dd/MM/yyyy').format(response.completedAt)}',
                    style: GoogleFonts.inter(fontSize: 11, color: colors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 760 ? 2 : 1;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 18) / columns;
                  return Wrap(
                    spacing: 18,
                    runSpacing: 14,
                    children: entries.map((entry) {
                      return SizedBox(
                        width: width,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.$2,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: colors.muted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.$3,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                height: 1.35,
                                color: colors.text,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWeightChart() {
    final progressAsync = ref.watch(adminProgressProvider(widget.client.uid));

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
          Text(
            'EVOLUÇÃO DE PESO',
            style: GoogleFonts.montserrat(
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
        final totalPages =
            (sorted.length + _progressPageSize - 1) ~/ _progressPageSize;
        final currentPage = _progressPage.clamp(0, totalPages - 1).toInt();
        if (_progressPage != currentPage) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _progressPage = currentPage);
          });
        }
        final firstIndex = currentPage * _progressPageSize;
        final visibleProgress = sorted
            .skip(firstIndex)
            .take(_progressPageSize)
            .toList();
        final lastIndex = firstIndex + visibleProgress.length;

        return Column(
          children: [
            // ── Gráfico de Peso ──
            _buildWeightChart(),
            const SizedBox(height: 20),
            // ── Comparação Antes/Depois ──
            if (sorted
                    .where(
                      (p) => hasAnyProgressPhoto(p.fotos, p.fotosPorPosicao),
                    )
                    .length >=
                2)
              _buildComparisonButton(sorted),
            const SizedBox(height: 20),
            // ── Timeline de avaliações ──
            ...visibleProgress.map((p) => _buildProgressCard(p)),
            if (totalPages > 1)
              _buildProgressPagination(
                currentPage: currentPage,
                totalPages: totalPages,
                firstIndex: firstIndex,
                lastIndex: lastIndex,
                totalItems: sorted.length,
              ),
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

  Widget _buildProgressPagination({
    required int currentPage,
    required int totalPages,
    required int firstIndex,
    required int lastIndex,
    required int totalItems,
  }) {
    final colors = AdminThemeColors.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${firstIndex + 1}–$lastIndex de $totalItems avaliações',
              style: GoogleFonts.inter(fontSize: 11, color: colors.muted),
            ),
          ),
          IconButton(
            tooltip: 'Página anterior',
            onPressed: currentPage > 0
                ? () => setState(() => _progressPage = currentPage - 1)
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
            color: colors.text,
            style: IconButton.styleFrom(minimumSize: const Size(36, 36)),
          ),
          Text(
            '${currentPage + 1}/$totalPages',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: colors.text,
            ),
          ),
          IconButton(
            tooltip: 'Página seguinte',
            onPressed: currentPage < totalPages - 1
                ? () => setState(() => _progressPage = currentPage + 1)
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
            color: colors.text,
            style: IconButton.styleFrom(minimumSize: const Size(36, 36)),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(ProgressModel progress) {
    final dateFormatted = DateFormat('d MMM yyyy', 'pt').format(progress.data);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
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
                  style: GoogleFonts.montserrat(
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
                  child: StorageImage(
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
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height - 32,
          ),
          child: SingleChildScrollView(
            child: _AdminProgressComparisonDialog(progress: sorted),
          ),
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
                  style: GoogleFonts.montserrat(
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
}

class _AdminProgressComparisonDialog extends StatefulWidget {
  final List<ProgressModel> progress;

  const _AdminProgressComparisonDialog({required this.progress});

  @override
  State<_AdminProgressComparisonDialog> createState() =>
      _AdminProgressComparisonDialogState();
}

class _AdminProgressComparisonDialogState
    extends State<_AdminProgressComparisonDialog> {
  late final List<ProgressModel> _options;
  late ProgressModel _before;
  late ProgressModel _after;
  int _selectedAngle = 0;
  String? _angleFeedback;

  @override
  void initState() {
    super.initState();
    _options = widget.progress.where((progress) {
      return hasAnyProgressPhoto(progress.fotos, progress.fotosPorPosicao);
    }).toList()..sort((a, b) => a.data.compareTo(b.data));

    final pair = _bestPair(_options);
    _before = pair.before;
    _after = pair.after;
    _selectedAngle = _safeAngle(_before, _after, 0);
  }

  String _key(ProgressModel progress) {
    return '${progress.id}|${progress.data.microsecondsSinceEpoch}';
  }

  ProgressModel? _byKey(String key) {
    for (final progress in _options) {
      if (_key(progress) == key) return progress;
    }
    return null;
  }

  ({ProgressModel before, ProgressModel after}) _bestPair(
    List<ProgressModel> options,
  ) {
    for (var afterIndex = options.length - 1; afterIndex > 0; afterIndex--) {
      for (var beforeIndex = 0; beforeIndex < afterIndex; beforeIndex++) {
        if (_sharesAngle(options[beforeIndex], options[afterIndex])) {
          return (before: options[beforeIndex], after: options[afterIndex]);
        }
      }
    }
    return (before: options.first, after: options.last);
  }

  String? _photoAt(ProgressModel progress, int angle) {
    return resolveProgressPhotoAt(
      fotos: progress.fotos,
      fotosPorPosicao: progress.fotosPorPosicao,
      angleIndex: angle,
    );
  }

  bool _sharesAngle(ProgressModel before, ProgressModel after) {
    for (var index = 0; index < progressAngleLabels.length; index++) {
      if (_photoAt(before, index) != null && _photoAt(after, index) != null) {
        return true;
      }
    }
    return false;
  }

  int _safeAngle(ProgressModel before, ProgressModel after, int preferred) {
    if (_photoAt(before, preferred) != null &&
        _photoAt(after, preferred) != null) {
      return preferred;
    }
    for (var index = 0; index < progressAngleLabels.length; index++) {
      if (_photoAt(before, index) != null && _photoAt(after, index) != null) {
        return index;
      }
    }
    return 0;
  }

  void _selectAngle(int index) {
    final hasBefore = _photoAt(_before, index) != null;
    final hasAfter = _photoAt(_after, index) != null;
    if (hasBefore && hasAfter) {
      setState(() {
        _selectedAngle = index;
        _angleFeedback = null;
      });
      return;
    }
    final date = DateFormat('dd/MM/yyyy');
    final label = progressAngleLabels[index];
    final message = !hasBefore && !hasAfter
        ? 'Nenhuma das datas selecionadas tem foto de $label.'
        : !hasBefore
        ? 'Sem foto de $label na data inicial (${date.format(_before.data)}).'
        : 'Sem foto de $label na data final (${date.format(_after.data)}).';
    setState(() => _angleFeedback = message);
  }

  void _selectBefore(String key) {
    final selected = _byKey(key);
    if (selected == null) return;
    var after = _after;
    if (selected.data.isAfter(after.data)) after = _options.last;
    setState(() {
      _before = selected;
      _after = after;
      _selectedAngle = _safeAngle(selected, after, _selectedAngle);
      _angleFeedback = null;
    });
  }

  void _selectAfter(String key) {
    final selected = _byKey(key);
    if (selected == null) return;
    var before = _before;
    if (selected.data.isBefore(before.data)) before = _options.first;
    setState(() {
      _before = before;
      _after = selected;
      _selectedAngle = _safeAngle(before, selected, _selectedAngle);
      _angleFeedback = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    if (_options.length < 2) {
      return _shell(
        colors,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            'São necessárias pelo menos duas avaliações com fotografias.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: colors.muted),
          ),
        ),
      );
    }

    final beforeOptions = _options
        .where((progress) => !progress.data.isAfter(_after.data))
        .toList();
    final afterOptions = _options
        .where((progress) => !progress.data.isBefore(_before.data))
        .toList();
    final beforeImage = _photoAt(_before, _selectedAngle);
    final afterImage = _photoAt(_after, _selectedAngle);
    final hasSharedPhoto = beforeImage != null && afterImage != null;

    return _shell(
      colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 500;
              final selectors = [
                _dateDropdown(
                  colors,
                  label: 'Data inicial',
                  value: _key(_before),
                  options: beforeOptions,
                  onChanged: _selectBefore,
                ),
                _dateDropdown(
                  colors,
                  label: 'Data final',
                  value: _key(_after),
                  options: afterOptions,
                  onChanged: _selectAfter,
                ),
              ];
              final dates = compact
                  ? Column(
                      children: [
                        selectors[0],
                        const SizedBox(height: 10),
                        selectors[1],
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: selectors[0]),
                        const SizedBox(width: 12),
                        Expanded(child: selectors[1]),
                      ],
                    );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  dates,
                  const SizedBox(height: 12),
                  _angleButtons(colors),
                ],
              );
            },
          ),
          if (_angleFeedback != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.surface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: colors.muted,
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _angleFeedback!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: colors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (hasSharedPhoto)
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = (width + 52).clamp(280.0, 680.0).toDouble();
                return ImageComparisonSlider(
                  beforeImage: beforeImage,
                  afterImage: afterImage,
                  width: width,
                  height: height,
                  dividerColor: colors.lime,
                  imageFit: BoxFit.cover,
                  edgeToEdge: true,
                  beforeLabel: '',
                  afterLabel: '',
                  beforeDate: DateFormat('dd/MM/yyyy').format(_before.data),
                  afterDate: DateFormat('dd/MM/yyyy').format(_after.data),
                  beforeDetail: _before.peso == null
                      ? null
                      : '${_before.peso!.toStringAsFixed(1)} kg',
                  afterDetail: _after.peso == null
                      ? null
                      : '${_after.peso!.toStringAsFixed(1)} kg',
                  cardColor: colors.surface2,
                );
              },
            )
          else
            _noSharedAngle(colors),
        ],
      ),
    );
  }

  Widget _shell(AdminThemeColors colors, {required Widget child}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.limeDim,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.compare_arrows_rounded,
                    color: colors.lime,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Comparação de progresso',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Arrasta o divisor para veres a evolução em tempo real.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: colors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: colors.muted),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _dateDropdown(
    AdminThemeColors colors, {
    required String label,
    required String value,
    required List<ProgressModel> options,
    required ValueChanged<String> onChanged,
  }) {
    return AppMenuDropdown<String>(
      value: value,
      options: options.map(_key).toList(),
      labelBuilder: (key) {
        final progress = _byKey(key);
        return progress == null
            ? 'Selecionar data'
            : DateFormat('dd/MM/yyyy').format(progress.data);
      },
      onChanged: onChanged,
      label: label,
      accentColor: colors.lime,
      fieldColor: colors.surface2,
      menuColor: colors.surface2,
      textColor: colors.text,
      labelColor: colors.muted,
    );
  }

  Widget _angleButtons(AdminThemeColors colors) {
    final availability = [
      for (var index = 0; index < progressAngleLabels.length; index++)
        _photoAt(_before, index) != null && _photoAt(_after, index) != null,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ângulo',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.muted,
          ),
        ),
        const SizedBox(height: 7),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (
                var index = 0;
                index < progressAngleLabels.length;
                index++
              ) ...[
                OutlinedButton(
                  onPressed: () => _selectAngle(index),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _selectedAngle == index
                        ? Colors.white
                        : availability[index]
                        ? colors.text
                        : colors.muted.withValues(alpha: 0.45),
                    backgroundColor: _selectedAngle == index
                        ? colors.lime
                        : colors.surface2,
                    side: BorderSide(
                      color: _selectedAngle == index
                          ? colors.lime
                          : colors.border.withValues(
                              alpha: availability[index] ? 1 : 0.35,
                            ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 11,
                    ),
                    minimumSize: const Size(0, 42),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    progressAngleLabels[index],
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (index < progressAngleLabels.length - 1)
                  const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _noSharedAngle(AdminThemeColors colors) {
    final pair = _bestPair(_options);
    final canAutoSelect =
        _key(pair.before) != _key(pair.after) &&
        _sharesAngle(pair.before, pair.after);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.photo_library_outlined, size: 30, color: colors.muted),
          const SizedBox(height: 10),
          Text(
            'As fotos destas datas não têm um ângulo em comum para comparar.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: colors.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (canAutoSelect) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                setState(() {
                  _before = pair.before;
                  _after = pair.after;
                  _selectedAngle = _safeAngle(_before, _after, 0);
                });
              },
              child: Text(
                'Escolher datas automaticamente',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.lime,
                ),
              ),
            ),
          ],
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
  bool _isImporting = false;
  bool _isRecategorizing = false;
  bool _isListView = true;
  bool _filtersOpen = false;
  static const int _exercisePageSize = 36;
  int _currentExercisePage = 0;
  final ScrollController _exerciseScrollController = ScrollController();

  @override
  void dispose() {
    _exerciseScrollController.dispose();
    super.dispose();
  }

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
    'Abdominais',
    'Glúteos',
    'Panturrilhas',
    'Adutores',
    'Abdutores',
    'Lombar',
    'Trapézio',
    'Antebraços',
    'Pescoço',
    'Geral',
  ];
  static const _categorias = [
    'Todas',
    'forca',
    'alongamento',
    'funcional',
    'cardio',
    'pliometria',
  ];

  @override
  Widget build(BuildContext context) {
    return _buildMinimalExerciseLibrary(context);
  }

  /*
    Legacy exercise-library layout kept below only as a reference while the
    new compact layout is maintained above.

  Widget _legacyBuildExerciseLibrary(BuildContext context) {
    final exercisesAsync = ref.watch(adminExerciseCatalogProvider);
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
            action: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildViewModeToggle(),
                OutlinedButton.icon(
                  onPressed: _isRecategorizing ? null : _recategorizeExerciseCatalog,
                  icon: _isRecategorizing
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.category_outlined, size: 17),
                  label: Text(
                    _isRecategorizing ? 'A categorizar...' : 'Corrigir categorias',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _isImporting ? null : _importExerciseCatalog,
                  icon: _isImporting
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_rounded, size: 17),
                  label: Text(_isImporting ? 'A importar...' : 'Importar catálogo'),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddExerciseDialog,
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('Novo exercício'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Search
          SizedBox(
            width: isMobile ? double.infinity : 360,
            height: 40,
            child: TextField(
              onChanged: (v) => setState(() {
                _search = v;
                _currentExercisePage = 0;
              }),
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
          const SizedBox(height: 16),
          Text(
            'FILTRAR POR MÚSCULO',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AdminThemeColors.of(context).muted,
            ),
          ),
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: AdminThemeColors.of(context).surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AdminThemeColors.of(context).border),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _muscles.map((m) {
              final active = _muscle == m;
              return GestureDetector(
                onTap: () => setState(() {
                  _muscle = m;
                  _currentExercisePage = 0;
                }),
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
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'FILTRAR POR TIPO',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AdminThemeColors.of(context).muted,
            ),
          ),
          const SizedBox(height: 7),
          // ── Category Filter ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: AdminThemeColors.of(context).surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AdminThemeColors.of(context).border),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categorias.map((c) {
              final active = _categoria == c;
              final labels = {
                'Todas': 'Todas',
                'forca': 'Força',
                'alongamento': 'Alongamento',
                'musculação': 'Musculação',
                'funcional': 'Funcional',
                'cardio': 'Cardio',
                'pliometria': 'Pliometria',
              };
              return GestureDetector(
                onTap: () => setState(() {
                  _categoria = c;
                  _currentExercisePage = 0;
                }),
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
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Text(
                'BIBLIOTECA',
                style: GoogleFonts.inter(
                  color: AdminThemeColors.of(context).muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Divider(color: AdminThemeColors.of(context).border),
              ),
            ],
          ),
          const SizedBox(height: 12),
          exercisesAsync.when(
            data: (exercises) {
              final filtered = exercises.where((e) {
                final name = e.nome.toLowerCase();
                final muscle = e.grupoMuscular;
                final cat = _displayCatalogValue(e.categoria);
                final matchSearch = name.contains(_search.toLowerCase());
                final matchMuscle = _muscle == 'Todos' ||
                    _sameCatalogLabel(muscle, _muscle);
                final matchCategoria = _categoria == 'Todas' ||
                    _sameCatalogLabel(cat, _displayCatalogValue(_categoria));
                return e.ativo && matchSearch && matchMuscle && matchCategoria;
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
                  final visible = filtered.take(36).toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: visible.asMap().entries.map((entry) {
                      final i = entry.key;
                      final e = entry.value;
                      final w = (constraints.maxWidth - 14 * (cols - 1)) / cols;
                      final nome = e.nome;
                      final grupo = e.grupoMuscular;
                      final equipamento = _displayCatalogValue(e.equipamento);
                      return _isListView
                          ? _buildExerciseListItem(e, i)
                          : SizedBox(
                        width: w,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AdminThemeColors.of(context).surface,
                            borderRadius: BorderRadius.circular(16),
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
                                style: GoogleFonts.montserrat(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
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
                                  Expanded(
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        _exChip(
                                          grupo,
                                          AdminThemeColors.of(context).blue,
                                        ),
                                        _exChip(
                                          equipamento,
                                          AdminThemeColors.of(context).muted,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Ver detalhes',
                                    onPressed: () => _showExerciseDetails(e),
                                    icon: const Icon(Icons.info_outline_rounded, size: 18),
                                    color: AdminThemeColors.of(context).lime,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                        }).toList(),
                      ),
                      if (visible.length < filtered.length) ...[
                        const SizedBox(height: 20),
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: () => setState(() {
                              _currentExercisePage = 0;
                            }),
                            icon: const Icon(Icons.expand_more_rounded, size: 18),
                            label: Text(
                              'Página 1',
                            ),
                          ),
                        ),
                      ],
                    ],
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

  */

  Widget _buildMinimalExerciseLibrary(BuildContext context) {
    final exercisesAsync = ref.watch(adminExerciseCatalogProvider);
    final colors = AdminThemeColors.of(context);
    final compact = MediaQuery.sizeOf(context).width < 760;

    return AdminPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EXERCÍCIOS',
                    style: GoogleFonts.inter(
                      color: colors.text,
                      fontSize: compact ? 24 : 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${exercisesAsync.asData?.value.length ?? 0} exercícios na biblioteca',
                    style: GoogleFonts.inter(color: colors.muted, fontSize: 12),
                  ),
                ],
              );
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildViewModeToggle(),
                  ElevatedButton.icon(
                    onPressed: _showAddExerciseDialog,
                    icon: const Icon(Icons.add_rounded, size: 17),
                    label: Text(compact ? 'Novo' : 'Novo exercício'),
                  ),
                  PopupMenuButton<String>(
                    enabled: !_isImporting && !_isRecategorizing,
                    tooltip: 'Mais ações',
                    onSelected: (value) {
                      if (value == 'categorize') {
                        _recategorizeExerciseCatalog();
                      } else if (value == 'import') {
                        _importExerciseCatalog();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'categorize',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.category_outlined),
                          title: Text('Corrigir categorias'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'import',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.download_rounded),
                          title: Text('Importar catálogo'),
                        ),
                      ),
                    ],
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
                ],
              );
              if (constraints.maxWidth < 620) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 14), actions],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: title),
                  actions,
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final search = SizedBox(
                  height: 42,
                  child: TextField(
                    onChanged: (value) => setState(() {
                      _search = value;
                      _currentExercisePage = 0;
                    }),
                    style: GoogleFonts.inter(color: colors.text, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Pesquisar exercícios...',
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: colors.muted,
                      ),
                      filled: true,
                      fillColor: colors.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                    ),
                  ),
                );
                final filterButton = OutlinedButton.icon(
                  onPressed: () => setState(() => _filtersOpen = !_filtersOpen),
                  icon: Icon(
                    _filtersOpen
                        ? Icons.tune_rounded
                        : Icons.filter_list_rounded,
                    size: 17,
                  ),
                  label: Text(_filtersOpen ? 'Fechar filtros' : 'Filtros'),
                );
                return constraints.maxWidth < 460
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          search,
                          const SizedBox(height: 8),
                          filterButton,
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: search),
                          const SizedBox(width: 8),
                          filterButton,
                        ],
                      );
              },
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: _filtersOpen
                ? _buildModernFilters(colors)
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                'BIBLIOTECA',
                style: GoogleFonts.inter(
                  color: colors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Divider(color: colors.border)),
            ],
          ),
          const SizedBox(height: 12),
          exercisesAsync.when(
            loading: () =>
                Center(child: CircularProgressIndicator(color: colors.lime)),
            error: (error, _) => Text(
              'Erro ao carregar exercícios: $error',
              style: GoogleFonts.inter(color: colors.muted),
            ),
            data: (exercises) => _buildModernExerciseResults(exercises, colors),
          ),
        ],
      ),
    );
  }

  Widget _buildModernFilters(AdminThemeColors colors) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: colors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final muscleButton = _buildFilterModalButton(
            label: 'Grupo muscular',
            value: _muscle == 'Todos' ? 'Todos os grupos' : _muscle,
            icon: Icons.accessibility_new_rounded,
            color: colors.blue,
            onTap: () => _showExerciseFilterModal(
              title: 'Grupo muscular',
              subtitle: 'Escolha o grupo muscular principal',
              values: _muscles,
              selectedValue: _muscle,
              allValue: 'Todos',
              icon: Icons.accessibility_new_rounded,
              onSelected: (value) => setState(() {
                _muscle = value;
                _currentExercisePage = 0;
              }),
            ),
          );
          final categoryButton = _buildFilterModalButton(
            label: 'Tipo de exercício',
            value: _categoria == 'Todas'
                ? 'Todos os tipos'
                : _displayCatalogValue(_categoria),
            icon: Icons.fitness_center_rounded,
            color: colors.lime,
            onTap: () => _showExerciseFilterModal(
              title: 'Tipo de exercício',
              subtitle: 'Escolha o tipo de exercício',
              values: _categorias,
              selectedValue: _categoria,
              allValue: 'Todas',
              icon: Icons.fitness_center_rounded,
              onSelected: (value) => setState(() {
                _categoria = value;
                _currentExercisePage = 0;
              }),
            ),
          );
          final clearButton = TextButton.icon(
            onPressed: () => setState(() {
              _search = '';
              _muscle = 'Todos';
              _categoria = 'Todas';
              _currentExercisePage = 0;
            }),
            icon: const Icon(Icons.restart_alt_rounded, size: 15),
            label: const Text('Limpar'),
          );

          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                muscleButton,
                const SizedBox(height: 7),
                categoryButton,
                Align(alignment: Alignment.centerRight, child: clearButton),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: muscleButton),
              const SizedBox(width: 7),
              Expanded(child: categoryButton),
              const SizedBox(width: 4),
              clearButton,
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterModalButton({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colors = AdminThemeColors.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: colors.bg,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 15),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        color: colors.muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: colors.text,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: colors.muted,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showExerciseFilterModal({
    required String title,
    required String subtitle,
    required List<String> values,
    required String selectedValue,
    required String allValue,
    required IconData icon,
    required ValueChanged<String> onSelected,
  }) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final colors = AdminThemeColors.of(dialogContext);
        return AdminResponsiveDialog(
          title: title,
          subtitle: subtitle,
          icon: icon,
          maxWidth: 520,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 380 ? 2 : 1;
              final itemWidth = columns == 2
                  ? (constraints.maxWidth - 8) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: values.map((value) {
                  final isSelected = selectedValue == value;
                  final displayValue = value == allValue
                      ? (allValue == 'Todos'
                            ? 'Todos os grupos'
                            : 'Todos os tipos')
                      : _displayCatalogValue(value);
                  return SizedBox(
                    width: itemWidth,
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                      child: InkWell(
                        onTap: () => Navigator.pop(dialogContext, value),
                        borderRadius: BorderRadius.circular(11),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? colors.limeDim : colors.bg,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color: isSelected ? colors.lime : colors.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  displayValue,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: isSelected
                                        ? colors.lime
                                        : colors.text,
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_rounded,
                                  color: colors.lime,
                                  size: 16,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
    if (selected != null && mounted) onSelected(selected);
  }

  List<ExerciseCatalogModel> _filteredModernExercises(
    List<ExerciseCatalogModel> exercises,
  ) {
    final query = _search.trim().toLowerCase();
    return exercises.where((exercise) {
      final searchable = [
        exercise.nome,
        exercise.grupoMuscular,
        ...exercise.musculosPrimarios,
        exercise.equipamento,
      ].join(' ').toLowerCase();
      final matchesSearch = query.isEmpty || searchable.contains(query);
      final matchesMuscle =
          _muscle == 'Todos' ||
          _sameCatalogLabel(exercise.grupoMuscular, _muscle);
      final matchesCategory =
          _categoria == 'Todas' ||
          _sameCatalogLabel(
            _displayCatalogValue(exercise.categoria),
            _displayCatalogValue(_categoria),
          );
      return exercise.ativo &&
          matchesSearch &&
          matchesMuscle &&
          matchesCategory;
    }).toList();
  }

  Widget _buildModernExerciseResults(
    List<ExerciseCatalogModel> exercises,
    AdminThemeColors colors,
  ) {
    final filtered = _filteredModernExercises(exercises);
    final totalPages = filtered.isEmpty
        ? 0
        : (filtered.length + _exercisePageSize - 1) ~/ _exercisePageSize;
    final page = totalPages == 0
        ? 0
        : (_currentExercisePage >= totalPages
              ? totalPages - 1
              : _currentExercisePage);
    final rangeStart = page * _exercisePageSize;
    final visible = filtered.skip(rangeStart).take(_exercisePageSize).toList();
    final compact = MediaQuery.sizeOf(context).width < 760;

    if (filtered.isEmpty) {
      return Container(
        width: double.infinity,
        height: compact ? 360 : 420,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 42, color: colors.muted),
            const SizedBox(height: 10),
            Text(
              'Nenhum exercício encontrado',
              style: GoogleFonts.inter(color: colors.muted),
            ),
          ],
        ),
      );
    }

    final panelHeight = compact ? 500.0 : 590.0;
    return Container(
      width: double.infinity,
      height: panelHeight,
      padding: const EdgeInsets.fromLTRB(10, 10, 6, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(
              children: [
                Text(
                  '${filtered.length} encontrados',
                  style: GoogleFonts.inter(
                    color: colors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  'a mostrar ${rangeStart + 1}–${rangeStart + visible.length} de ${filtered.length}',
                  style: GoogleFonts.inter(color: colors.muted, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Scrollbar(
              controller: _exerciseScrollController,
              // A barra aparece durante o scroll; não tentamos pintá-la antes
              // de a lista ter uma ScrollPosition (hot restart/troca de visão).
              thumbVisibility: false,
              interactive: true,
              child: _isListView
                  ? ListView.builder(
                      controller: _exerciseScrollController,
                      primary: false,
                      padding: const EdgeInsets.only(right: 5, bottom: 4),
                      itemCount: visible.length,
                      itemBuilder: (context, index) => _buildExerciseReveal(
                        exercise: visible[index],
                        index: index,
                        child: _buildModernListItem(
                          visible[index],
                          rangeStart + index,
                          colors,
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth > 760
                            ? 3
                            : (constraints.maxWidth > 430 ? 2 : 1);
                        final width =
                            (constraints.maxWidth - ((columns - 1) * 12)) /
                            columns;
                        return ListView(
                          controller: _exerciseScrollController,
                          primary: false,
                          padding: const EdgeInsets.only(right: 5, bottom: 4),
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: visible
                                  .asMap()
                                  .entries
                                  .map(
                                    (entry) => _buildExerciseReveal(
                                      exercise: entry.value,
                                      index: entry.key,
                                      child: _buildModernGridItem(
                                        entry.value,
                                        rangeStart + entry.key,
                                        width,
                                        colors,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ),
          _buildExercisePagination(
            page: page,
            totalPages: totalPages,
            colors: colors,
          ),
        ],
      ),
    );
  }

  void _goToExercisePage(int page) {
    setState(() => _currentExercisePage = page);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _exerciseScrollController.hasClients) {
        _exerciseScrollController.jumpTo(0);
      }
    });
  }

  Widget _buildExercisePagination({
    required int page,
    required int totalPages,
    required AdminThemeColors colors,
  }) {
    final canGoBack = page > 0;
    final canGoForward = page < totalPages - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: canGoBack ? () => _goToExercisePage(page - 1) : null,
              tooltip: 'Página anterior',
              icon: const Icon(Icons.chevron_left_rounded),
              color: colors.text,
              disabledColor: colors.border,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              visualDensity: VisualDensity.compact,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                'Página ${page + 1} de $totalPages',
                style: GoogleFonts.inter(
                  color: colors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              onPressed: canGoForward
                  ? () => _goToExercisePage(page + 1)
                  : null,
              tooltip: 'Página seguinte',
              icon: const Icon(Icons.chevron_right_rounded),
              color: colors.text,
              disabledColor: colors.border,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseReveal({
    required ExerciseCatalogModel exercise,
    required int index,
    required Widget child,
  }) {
    final staggerIndex = index > 5 ? 5 : index;
    return ScrollReveal(
      key: ValueKey('exercise_reveal_${exercise.id}'),
      delay: Duration(milliseconds: staggerIndex * 18),
      child: child,
    );
  }

  Widget _buildModernListItem(
    ExerciseCatalogModel exercise,
    int index,
    AdminThemeColors colors,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: () => _showExerciseDetails(exercise),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 3,
          ),
          leading: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.limeDim,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              '${index + 1}'.padLeft(2, '0'),
              style: GoogleFonts.montserrat(
                color: colors.lime,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          title: Text(
            exercise.nome,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: colors.text,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            '${exercise.grupoMuscular}  ·  ${_displayCatalogValue(exercise.equipamento)}  ·  ${_displayCatalogValue(exercise.categoria)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(color: colors.muted, fontSize: 11),
          ),
          trailing: Icon(Icons.chevron_right_rounded, color: colors.muted),
        ),
      ),
    );
  }

  Widget _buildModernGridItem(
    ExerciseCatalogModel exercise,
    int index,
    double width,
    AdminThemeColors colors,
  ) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: InkWell(
          onTap: () => _showExerciseDetails(exercise),
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.fitness_center_rounded,
                    color: colors.lime,
                    size: 18,
                  ),
                  const Spacer(),
                  Text(
                    '${index + 1}'.padLeft(2, '0'),
                    style: GoogleFonts.montserrat(
                      color: colors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                exercise.nome,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: colors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                exercise.grupoMuscular,
                style: GoogleFonts.inter(
                  color: colors.blue,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${_displayCatalogValue(exercise.equipamento)} · ${_displayCatalogValue(exercise.categoria)}',
                style: GoogleFonts.inter(color: colors.muted, fontSize: 11),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.info_outline_rounded,
                  color: colors.lime,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewModeToggle() {
    final colors = AdminThemeColors.of(context);
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _viewModeButton(
            icon: Icons.view_list_rounded,
            label: 'Lista',
            selected: _isListView,
            onTap: () => setState(() => _isListView = true),
          ),
          _viewModeButton(
            icon: Icons.grid_view_rounded,
            label: 'Quadrados',
            selected: !_isListView,
            onTap: () => setState(() => _isListView = false),
          ),
        ],
      ),
    );
  }

  Widget _viewModeButton({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colors = AdminThemeColors.of(context);
    return Tooltip(
      message: 'Ver em $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? colors.limeDim : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: 18,
            color: selected ? colors.lime : colors.muted,
          ),
        ),
      ),
    );
  }

  Future<void> _showExerciseDetails(ExerciseCatalogModel exercise) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final colors = AdminThemeColors.of(dialogContext);
        return AdminResponsiveDialog(
          title: exercise.nome,
          subtitle:
              '${exercise.grupoMuscular} · ${_displayCatalogValue(exercise.equipamento)}',
          icon: Icons.fitness_center_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _exChip(exercise.grupoMuscular, colors.blue),
                  _exChip(
                    _displayCatalogValue(exercise.categoria),
                    colors.lime,
                  ),
                  _exChip(
                    _displayCatalogValue(exercise.equipamento),
                    colors.muted,
                  ),
                  if (exercise.nivel.isNotEmpty)
                    _exChip(
                      _displayCatalogValue(exercise.nivel),
                      colors.orange,
                    ),
                ],
              ),
              if (exercise.musculosPrimarios.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'MÚSCULOS TRABALHADOS',
                  style: GoogleFonts.inter(
                    color: colors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  exercise.musculosPrimarios.join(' · '),
                  style: GoogleFonts.inter(color: colors.text, fontSize: 13),
                ),
              ],
              if (exercise.instrucoes.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'INSTRUÇÕES',
                  style: GoogleFonts.inter(
                    color: colors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                ...exercise.instrucoes.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${entry.key + 1}.',
                          style: GoogleFonts.inter(
                            color: colors.lime,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: GoogleFonts.inter(
                              color: colors.text,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fechar'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _showEditExerciseDialog(exercise);
              },
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('Editar'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _deactivateExercise(exercise);
              },
              icon: const Icon(Icons.archive_outlined, size: 17),
              label: const Text('Desativar'),
            ),
          ],
        );
      },
    );
  }

  String _displayCatalogValue(String value) {
    final normalized = value.trim().toLowerCase();
    const labels = {
      'forca': 'Força',
      'strength': 'Força',
      'alongamento': 'Alongamento',
      'stretching': 'Alongamento',
      'pliometria': 'Pliometria',
      'cardio': 'Cardio',
      'peso_corporal': 'Peso corporal',
      'barra': 'Barra',
      'haltere': 'Haltere',
      'kettlebell': 'Kettlebell',
      'maquina': 'Máquina',
      'polia': 'Polia',
      'banda': 'Banda',
      'corda': 'Corda',
      'outro': 'Outro',
    };
    if (labels.containsKey(normalized)) return labels[normalized]!;
    if (normalized.isEmpty) return 'Geral';
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  bool _sameCatalogLabel(String first, String second) {
    return first.trim().toLowerCase() == second.trim().toLowerCase();
  }

  Future<void> _showEditExerciseDialog(ExerciseCatalogModel exercise) async {
    final name = TextEditingController(text: exercise.nome);
    final instructions = TextEditingController(
      text: exercise.instrucoes.join('\\n'),
    );
    final muscles = TextEditingController(
      text: exercise.musculosPrimarios.join(', '),
    );
    final equipment = TextEditingController(text: exercise.equipamento);
    var category = exercise.categoria;
    const categories = [
      'forca',
      'alongamento',
      'cardio',
      'pliometria',
      'funcional',
    ];
    if (!categories.contains(category)) category = 'forca';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AdminResponsiveAlertDialog(
          title: Text('Editar exercício\n${exercise.nome}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: categories
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(_displayCatalogValue(item)),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => category = value ?? category),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: equipment,
                decoration: const InputDecoration(labelText: 'Equipamento'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: muscles,
                decoration: const InputDecoration(
                  labelText: 'Músculos primários',
                  hintText: 'Separar por vírgulas',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: instructions,
                minLines: 3,
                maxLines: 7,
                decoration: const InputDecoration(
                  labelText: 'Instruções',
                  hintText: 'Uma instrução por linha',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                final updated = exercise.copyWith(
                  nome: name.text.trim(),
                  categoria: category,
                  equipamento: equipment.text.trim().isEmpty
                      ? 'outro'
                      : equipment.text.trim(),
                  musculosPrimarios: muscles.text
                      .split(',')
                      .map((value) => value.trim())
                      .where((value) => value.isNotEmpty)
                      .map(ExerciseCatalogModel.canonicalMuscleGroup)
                      .toList(),
                  grupoMuscular: ExerciseCatalogModel.canonicalMuscleGroup(
                    muscles.text.split(',').first,
                  ),
                  instrucoes: instructions.text
                      .split('\\n')
                      .map((value) => value.trim())
                      .where((value) => value.isNotEmpty)
                      .toList(),
                );
                await ref
                    .read(workoutRepositoryProvider)
                    .updateExerciseCatalog(updated);
                ref.invalidate(adminExerciseCatalogProvider);
                if (mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deactivateExercise(ExerciseCatalogModel exercise) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AdminResponsiveAlertDialog(
        title: const Text('Desativar exercício?'),
        content: Text(
          '"${exercise.nome}" deixará de aparecer no catálogo, mas continuará preservado nos planos existentes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Desativar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(workoutRepositoryProvider)
        .deactivateExerciseCatalog(exercise.id);
    ref.invalidate(adminExerciseCatalogProvider);
  }

  Future<void> _recategorizeExerciseCatalog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AdminResponsiveAlertDialog(
        title: const Text('Corrigir categorias dos exercícios?'),
        content: const Text(
          'A categoria principal será recalculada para todos os exercícios com base nos músculos registados. Os planos existentes não serão alterados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Corrigir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isRecategorizing = true);
    try {
      final exercises = await ref.read(adminExerciseCatalogProvider.future);
      final normalized = exercises
          .map(
            (exercise) => exercise.copyWith(
              musculosPrimarios: exercise.musculosPrimarios
                  .map(ExerciseCatalogModel.canonicalMuscleGroup)
                  .toSet()
                  .toList(),
              musculosSecundarios: exercise.musculosSecundarios
                  .map(ExerciseCatalogModel.canonicalMuscleGroup)
                  .toSet()
                  .toList(),
              grupoMuscular: ExerciseCatalogModel.canonicalMuscleGroup(
                exercise.grupoMuscular.isEmpty
                    ? (exercise.musculosPrimarios.isEmpty
                          ? ''
                          : exercise.musculosPrimarios.first)
                    : exercise.grupoMuscular,
              ),
            ),
          )
          .toList();
      await ref
          .read(workoutRepositoryProvider)
          .importExerciseCatalog(normalized);
      ref.invalidate(adminExerciseCatalogProvider);
      if (mounted) {
        showAppNotification(
          context,
          '${normalized.length} exercícios recategorizados com sucesso.',
          type: NotificationType.success,
        );
      }
    } catch (error) {
      if (mounted) {
        showAppNotification(
          context,
          'Não foi possível corrigir as categorias: $error',
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isRecategorizing = false);
    }
  }

  Future<void> _importExerciseCatalog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AdminResponsiveAlertDialog(
        title: const Text('Importar catálogo de exercícios?'),
        content: const Text(
          'Serão importados mais de 800 exercícios em português. Exercícios com o mesmo ID serão atualizados e não serão duplicados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Importar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isImporting = true);
    try {
      const sourceUrl =
          'https://raw.githubusercontent.com/joao-gugel/exercicios-bd-ptbr/main/exercises/exercises-ptbr-full-translation.json';
      final response = await http.get(Uri.parse(sourceUrl));
      if (response.statusCode != 200) {
        throw Exception(
          'Não foi possível obter o catálogo (${response.statusCode}).',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List) throw const FormatException('Formato inválido.');
      final catalog = decoded
          .whereType<Map>()
          .map(
            (item) => ExerciseCatalogModel.fromSourceMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .where(
            (exercise) =>
                exercise.id.trim().isNotEmpty &&
                exercise.nome.trim().isNotEmpty,
          )
          .toList();
      if (catalog.isEmpty) throw const FormatException('Catálogo vazio.');

      await ref.read(workoutRepositoryProvider).importExerciseCatalog(catalog);
      ref.invalidate(adminExerciseCatalogProvider);
      if (mounted) {
        showAppNotification(
          context,
          '${catalog.length} exercícios importados com sucesso.',
          type: NotificationType.success,
        );
      }
    } catch (error) {
      if (mounted) {
        showAppNotification(
          context,
          'Não foi possível importar o catálogo: $error',
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
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
                  isDense: true,
                  menuMaxHeight: 320,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(14),
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
                  isDense: true,
                  menuMaxHeight: 320,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(14),
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
                  await ref
                      .read(workoutRepositoryProvider)
                      .createExerciseCatalog(
                        ExerciseCatalogModel(
                          id: '',
                          nome: nomeCtrl.text.trim(),
                          musculosPrimarios: [selectedGrupo],
                          equipamento: equipCtrl.text.trim().isNotEmpty
                              ? equipCtrl.text.trim()
                              : 'peso_corporal',
                          categoria: selectedCategoria,
                        ),
                      );
                  ref.invalidate(adminExerciseCatalogProvider);
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
  String _category = 'all';
  String _sort = 'name_asc';
  int _visibleFoodCount = _pageSize;

  static const _pageSize = 24;

  static const _categoryLabels = <String, String>{
    'all': 'Todas as categorias',
    'proteina': 'Proteínas',
    'hidrato': 'Carboidratos',
    'gordura': 'Gorduras',
    'vegetal': 'Vegetais',
    'laticinio': 'Laticínios',
    'fruta': 'Frutas',
    'bebida': 'Bebidas',
    'outro': 'Outros',
  };

  static const _sortLabels = <String, String>{
    'name_asc': 'Nome A–Z',
    'calories_asc': 'Menos kcal',
    'calories_desc': 'Mais kcal',
  };

  List<FoodModel> _filteredFoods(List<FoodModel> foods) {
    final query = _search.trim().toLowerCase();
    final filtered = foods.where((food) {
      final matchesQuery = query.isEmpty ||
          food.nome.toLowerCase().contains(query);
      if (!matchesQuery) return false;
      if (_category == 'all') return true;
      return food.categoria?.trim().toLowerCase() == _category;
    }).toList();

    filtered.sort((a, b) {
      switch (_sort) {
        case 'calories_asc':
          return a.caloriasPor100g.compareTo(b.caloriasPor100g);
        case 'calories_desc':
          return b.caloriasPor100g.compareTo(a.caloriasPor100g);
        default:
          return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
      }
    });
    return filtered;
  }

  String _foodCountSubtitle(AsyncValue<List<FoodModel>> foodsAsync) {
    final foods = foodsAsync.asData?.value;
    if (foods == null) return 'A carregar alimentos...';

    final filteredCount = _filteredFoods(foods).length;
    final visibleCount = _visibleFoodCount < filteredCount
        ? _visibleFoodCount
        : filteredCount;
    final completeCount = foods
        .where(
          (food) =>
              food.proteinasPor100g != null &&
              food.hidratosPor100g != null &&
              food.gordurasPor100g != null,
        )
        .length;
    final countSuffix = ' · $completeCount com dados completos';
    if (filteredCount == foods.length) {
      return '$visibleCount visíveis de $filteredCount alimentos no total$countSuffix';
    }
    return '$visibleCount visíveis · $filteredCount filtrados · ${foods.length} no total$countSuffix';
  }

  Widget _foodDropdown({
    required String value,
    required String label,
    required Map<String, String> options,
    required ValueChanged<String?> onChanged,
    required IconData icon,
  }) {
    final colors = AdminThemeColors.of(context);
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      isDense: true,
      menuMaxHeight: 320,
      elevation: 3,
      borderRadius: BorderRadius.circular(14),
      dropdownColor: colors.surface,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: colors.muted),
      style: GoogleFonts.inter(
        color: colors.text,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: colors.muted, fontSize: 11),
        prefixIcon: Icon(icon, size: 17, color: colors.lime),
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.lime.withValues(alpha: 0.45)),
        ),
      ),
      items: options.entries
          .map(
            (entry) => DropdownMenuItem<String>(
              value: entry.key,
              child: Text(
                entry.value,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: colors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _foodFilters() {
    final colors = AdminThemeColors.of(context);
    return LayoutBuilder(
      builder: (_, constraints) {
        final stacked = constraints.maxWidth < 620;
        final fieldWidth = stacked ? constraints.maxWidth : 190.0;
        final searchWidth = stacked
            ? constraints.maxWidth
            : (constraints.maxWidth < 370 ? constraints.maxWidth : 360.0);
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: searchWidth,
              height: 42,
              child: TextField(
                onChanged: (v) => setState(() {
                  _search = v;
                  _visibleFoodCount = _pageSize;
                }),
                style: GoogleFonts.inter(fontSize: 13, color: colors.text),
                decoration: InputDecoration(
                  hintText: 'Buscar alimento...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: colors.muted,
                  ),
                  prefixIcon: Icon(Icons.search, size: 17, color: colors.muted),
                  filled: true,
                  fillColor: colors.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: fieldWidth,
              child: _foodDropdown(
                value: _category,
                label: 'Categoria',
                options: _categoryLabels,
                icon: Icons.category_outlined,
                onChanged: (value) => setState(() {
                  _category = value ?? 'all';
                  _visibleFoodCount = _pageSize;
                }),
              ),
            ),
            SizedBox(
              width: fieldWidth,
              child: _foodDropdown(
                value: _sort,
                label: 'Ordenar por',
                options: _sortLabels,
                icon: Icons.swap_vert_rounded,
                onChanged: (value) => setState(() {
                  _sort = value ?? 'name_asc';
                  _visibleFoodCount = _pageSize;
                }),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final foodsPager = ref.watch(adminFoodsPagerProvider);
    final AsyncValue<List<FoodModel>> foodsAsync =
        foodsPager.isLoading && foodsPager.items.isEmpty
        ? const AsyncLoading<List<FoodModel>>()
        : foodsPager.error != null
        ? AsyncError<List<FoodModel>>(foodsPager.error!, StackTrace.current)
        : AsyncData<List<FoodModel>>(foodsPager.items);

    return AdminPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: 'Alimentos',
            subtitle: _foodCountSubtitle(foodsAsync),
            icon: Icons.restaurant_outlined,
            action: ElevatedButton.icon(
              onPressed: _showAddFoodDialog,
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Novo alimento'),
            ),
          ),
          const SizedBox(height: 20),
          _foodFilters(),
          const SizedBox(height: 24),
          foodsAsync.when(
            data: (foods) {
              final filteredFoods = _filteredFoods(foods);
              if (filteredFoods.isEmpty) {
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
                          foods.isEmpty
                              ? 'Nenhum alimento encontrado'
                              : 'Nenhum alimento corresponde aos filtros',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: AdminThemeColors.of(context).muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          foods.isEmpty
                              ? 'Adiciona os primeiros alimentos à biblioteca.'
                              : 'Altera a categoria ou a ordenação para ver outros alimentos.',
                          textAlign: TextAlign.center,
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

              final visibleFoods = filteredFoods
                  .take(_visibleFoodCount)
                  .toList();
              return LayoutBuilder(
                builder: (_, constraints) {
                  final cols = constraints.maxWidth > 900
                      ? 4
                      : (constraints.maxWidth > 600
                            ? 3
                            : (constraints.maxWidth > 400 ? 2 : 1));
                  final cards = Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: visibleFoods.map((food) {
                      final w = (constraints.maxWidth - 14 * (cols - 1)) / cols;
                      return SizedBox(width: w, child: _foodCard(food));
                    }).toList(),
                  );
                  final hasMore =
                      visibleFoods.length < filteredFoods.length ||
                      foodsPager.hasMore;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      cards,
                      if (hasMore) ...[
                        const SizedBox(height: 22),
                        Text(
                          'A mostrar ${visibleFoods.length} de ${filteredFoods.length} alimentos',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: AdminThemeColors.of(context).muted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: foodsPager.hasMore
                                ? foodsPager.loadMore
                                : () => setState(() {
                                    _visibleFoodCount += _pageSize;
                                  }),
                            icon: foodsPager.isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.expand_more_rounded,
                                    size: 18,
                                  ),
                            label: Text(
                              foodsPager.isLoading
                                  ? 'A carregar alimentos...'
                                  : 'Mostrar mais alimentos',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AdminThemeColors.of(
                                context,
                              ).lime,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
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
    final colors = AdminThemeColors.of(context);
    final categoryColors = {
      'proteina': colors.blue,
      'hidrato': colors.orange,
      'gordura': colors.purple,
      'vegetal': colors.lime,
      'laticinio': colors.blue,
      'fruta': colors.lime,
      'bebida': colors.text,
    };
    final categoryColor = categoryColors[food.categoria] ?? colors.muted;
    final category = food.categoria ?? 'Geral';

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.7),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.restaurant_rounded,
                  color: categoryColor,
                  size: 19,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  food.nome,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: colors.text,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  category.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: categoryColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  color: colors.orange,
                  size: 17,
                ),
                const SizedBox(width: 7),
                Text(
                  '${food.caloriasPor100g.toStringAsFixed(0)} kcal',
                  style: GoogleFonts.montserrat(
                    color: colors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'por 100 g',
                  style: GoogleFonts.inter(color: colors.muted, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _nutritionStat('Proteína', food.proteinasPor100g, colors.blue),
              _nutritionStat(
                'Carboidratos',
                food.hidratosPor100g,
                colors.orange,
              ),
              _nutritionStat('Gordura', food.gordurasPor100g, colors.purple),
            ],
          ),
          if (food.origem != null) ...[
            const SizedBox(height: 13),
            Row(
              children: [
                Icon(Icons.cloud_done_outlined, size: 13, color: colors.muted),
                const SizedBox(width: 5),
                Text(
                  food.origem!,
                  style: GoogleFonts.inter(color: colors.muted, fontSize: 10),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _nutritionStat(String label, double? value, Color color) {
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: colors.muted,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value == null ? '—' : '${value.toStringAsFixed(1)} g',
            style: GoogleFonts.montserrat(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
                  isDense: true,
                  menuMaxHeight: 320,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(14),
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
    final paymentsPager = ref.watch(adminPaymentsPagerProvider);
    final AsyncValue<List<PaymentModel>> paymentsAsync =
        paymentsPager.isLoading && paymentsPager.items.isEmpty
        ? const AsyncLoading<List<PaymentModel>>()
        : paymentsPager.error != null
        ? AsyncError<List<PaymentModel>>(
            paymentsPager.error!,
            StackTrace.current,
          )
        : AsyncData<List<PaymentModel>>(paymentsPager.items);
    final students =
        ref.watch(alunosListProvider).asData?.value ?? const <UserModel>[];
    final studentNames = <String, String>{
      for (final student in students) student.uid: student.nome,
    };
    return AdminPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: 'Pagamentos',
            subtitle: 'Gestão de pagamentos e faturas via Stripe',
            icon: Icons.payments_outlined,
            action: Wrap(
              spacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _creating
                      ? null
                      : () => _showCreatePaymentDialog(),
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('Nova cobrança'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          paymentsAsync.when(
            data: (payments) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPaymentSummary(payments),
                const SizedBox(height: 14),
                _AdminPaymentsCompactList(
                  payments: payments,
                  studentNames: studentNames,
                  itemBuilder: (payment, studentName) => _paymentRow(
                    payment,
                    studentName: studentName,
                    compact: true,
                  ),
                ),
                if (paymentsPager.hasMore) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: paymentsPager.isLoading
                          ? null
                          : paymentsPager.loadMore,
                      icon: paymentsPager.isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.expand_more_rounded, size: 18),
                      label: Text(
                        paymentsPager.isLoading
                            ? 'A carregar...'
                            : 'Carregar mais pagamentos',
                      ),
                    ),
                  ),
                ],
              ],
            ),
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

  Widget _buildPaymentSummary(List<PaymentModel> payments) {
    final colors = AdminThemeColors.of(context);
    final paidTotal = payments
        .where((payment) => payment.isPaid)
        .fold<double>(0, (total, payment) => total + payment.valor);
    final pendingCount = payments
        .where(
          (payment) =>
              payment.effectiveStatus == 'pending' ||
              payment.effectiveStatus == 'overdue',
        )
        .length;

    return Row(
      children: [
        Expanded(
          child: _paymentSummaryItem(
            Icons.receipt_long_outlined,
            'Total',
            '${payments.length}',
            colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _paymentSummaryItem(
            Icons.check_circle_outline,
            'Recebido',
            '${paidTotal.toStringAsFixed(2)} €',
            colors.lime,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _paymentSummaryItem(
            Icons.schedule_outlined,
            'Pendentes',
            '$pendingCount',
            colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _paymentSummaryItem(
    IconData icon,
    String label,
    String value,
    Color accent,
  ) {
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: accent),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.montserrat(
              color: colors.text,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, color: colors.muted),
          ),
        ],
      ),
    );
  }

  bool _canCancelPayment(PaymentModel payment) {
    return payment.status == 'pending' ||
        payment.status == 'scheduled' ||
        payment.status == 'failed';
  }

  bool _canCancelSubscription(PaymentModel payment) {
    return payment.stripeSubscriptionId != null &&
        payment.isPaid &&
        !payment.subscriptionCancelAtPeriodEnd;
  }

  Future<void> _cancelPaymentSubscription(PaymentModel payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AdminResponsiveAlertDialog(
        title: const Text('Desativar renovação automática?'),
        content: const Text(
          'O cliente mantém o acesso até ao fim do período pago. O Stripe não fará novas cobranças depois dessa data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Desativar renovação'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(paymentRepositoryProvider)
          .cancelPaymentSubscription(paymentId: payment.id);
      ref.read(adminPaymentsPagerProvider).refresh();
      ref.invalidate(adminAllPaymentsProvider);
      if (mounted) {
        showAppNotification(
          context,
          'Renovação automática desativada no fim do período.',
          type: NotificationType.success,
        );
      }
    } catch (error) {
      if (mounted) {
        showAppNotification(
          context,
          'Não foi possível desativar a renovação: $error',
          type: NotificationType.error,
        );
      }
    }
  }

  bool _canResendRecovery(PaymentModel payment) {
    return payment.status == 'failed' || payment.isOverdue;
  }

  Future<void> _resendRecovery(PaymentModel payment) async {
    try {
      await ref
          .read(paymentRepositoryProvider)
          .resendPaymentRecovery(paymentId: payment.id);
      if (mounted) {
        showAppNotification(
          context,
          'Link de recuperação reenviado por e-mail/push.',
          type: NotificationType.success,
        );
      }
    } catch (error) {
      if (mounted) {
        showAppNotification(
          context,
          'Não foi possível reenviar o link: $error',
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _cancelPayment(PaymentModel payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AdminResponsiveAlertDialog(
        title: const Text('Cancelar cobrança?'),
        content: Text(
          'A cobrança de ${payment.valorFormatado} deixará de aparecer para o cliente e a subscrição automática será cancelada, se já tiver sido criada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancelar cobrança'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(paymentRepositoryProvider)
          .cancelPayment(paymentId: payment.id);
      ref.read(adminPaymentsPagerProvider).refresh();
      ref.invalidate(adminAllPaymentsProvider);
      if (mounted) {
        showAppNotification(
          context,
          'Cobrança cancelada.',
          type: NotificationType.success,
        );
      }
    } catch (error) {
      if (mounted) {
        showAppNotification(
          context,
          'Não foi possível cancelar a cobrança: $error',
          type: NotificationType.error,
        );
      }
    }
  }

  Widget _paymentRow(
    PaymentModel payment, {
    String? studentName,
    bool? compact,
  }) {
    final isMobile = compact ?? MediaQuery.of(context).size.width < 600;
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
      'scheduled': AdminThemeColors.of(context).blue,
      'failed': Colors.red,
      'refunded': AdminThemeColors.of(context).muted,
      'cancelled': AdminThemeColors.of(context).muted,
      'overdue': Colors.red,
    };
    final statusLabels = {
      'paid': 'PAGO',
      'pending': 'PENDENTE',
      'scheduled': 'AGENDADO',
      'failed': 'FALHOU',
      'refunded': 'REEMBOLSADO',
      'cancelled': 'CANCELADO',
      'overdue': 'EM ATRASO',
    };

    final statusColor =
        statusColors[payment.effectiveStatus] ??
        AdminThemeColors.of(context).muted;
    final statusLabel =
        statusLabels[payment.effectiveStatus] ?? payment.status.toUpperCase();

    if (isMobile) {
      final mobileActions = <Widget>[
        if (payment.faturaUrl != null)
          TextButton.icon(
            onPressed: () => _openInvoice(payment.faturaUrl!),
            icon: Icon(
              Icons.picture_as_pdf_outlined,
              size: 15,
              color: AdminThemeColors.of(context).lime,
            ),
            label: const Text('Ver fatura'),
            style: TextButton.styleFrom(
              foregroundColor: AdminThemeColors.of(context).lime,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        if (_canResendRecovery(payment))
          TextButton.icon(
            onPressed: () => _resendRecovery(payment),
            icon: const Icon(Icons.forward_to_inbox_outlined, size: 15),
            label: const Text('Reenviar'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        if (_canCancelSubscription(payment))
          TextButton.icon(
            onPressed: () => _cancelPaymentSubscription(payment),
            icon: const Icon(Icons.event_busy_outlined, size: 15),
            label: const Text('Parar renovação'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        if (_canCancelPayment(payment))
          TextButton.icon(
            onPressed: () => _cancelPayment(payment),
            icon: const Icon(Icons.cancel_outlined, size: 15),
            label: const Text('Cancelar'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ];

      return Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AdminThemeColors.of(context).surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AdminThemeColors.of(context).border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: userAsync.when(
                    data: (u) => Text(
                      u?.nome ?? studentName ?? 'Aluno',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: AdminThemeColors.of(context).text,
                      ),
                    ),
                    loading: () => Text(
                      studentName ?? 'Aluno',
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
            if (mobileActions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 14, runSpacing: 4, children: mobileActions),
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
            width: 92,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (payment.faturaUrl != null)
                  IconButton(
                    icon: Icon(
                      Icons.picture_as_pdf,
                      color: AdminThemeColors.of(context).lime,
                      size: 18,
                    ),
                    onPressed: () => _openInvoice(payment.faturaUrl!),
                    tooltip: 'Ver fatura',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                else if (payment.status == 'pending' &&
                    payment.stripeSessionId != null)
                  IconButton(
                    icon: Icon(
                      Icons.refresh,
                      color: AdminThemeColors.of(context).orange,
                      size: 18,
                    ),
                    onPressed: () => ref.invalidate(adminAllPaymentsProvider),
                    tooltip: 'Atualizar',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                if (_canCancelPayment(payment))
                  IconButton(
                    icon: const Icon(
                      Icons.cancel_outlined,
                      color: Colors.red,
                      size: 18,
                    ),
                    onPressed: () => _cancelPayment(payment),
                    tooltip: 'Cancelar cobrança',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ],
      ),
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
    String tipoMensalidade = 'mensal';
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
          ),
          title: Text(
            'Nova cobrança',
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
                      'Cobrança criada. O cliente poderá pagar no seu Perfil.',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: AdminThemeColors.of(context).text,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Select student
                    DropdownButtonFormField<UserModel>(
                      isDense: true,
                      menuMaxHeight: 320,
                      elevation: 2,
                      borderRadius: BorderRadius.circular(14),
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
                      onChanged: (_) => setDialogState(() {}),
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
                    DropdownButtonFormField<String>(
                      isDense: true,
                      menuMaxHeight: 320,
                      elevation: 2,
                      borderRadius: BorderRadius.circular(14),
                      initialValue: tipoMensalidade,
                      dropdownColor: AdminThemeColors.of(context).surface,
                      style: GoogleFonts.inter(
                        color: AdminThemeColors.of(context).text,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Tipo de mensalidade',
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
                      items: const [
                        DropdownMenuItem(
                          value: 'mensal',
                          child: Text('Mensal'),
                        ),
                        DropdownMenuItem(
                          value: 'trimestral',
                          child: Text('Trimestral'),
                        ),
                        DropdownMenuItem(value: 'anual', child: Text('Anual')),
                      ],
                      onChanged: (value) => setDialogState(
                        () => tipoMensalidade = value ?? tipoMensalidade,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'O próximo período e a data de vencimento serão calculados automaticamente a partir do fim do período atual.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AdminThemeColors.of(context).muted,
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
                          await repo.createPaymentSchedule(
                            userId: selectedAluno!.uid,
                            valor: valor,
                            tipoMensalidade: tipoMensalidade,
                          );
                          setDialogState(() {
                            loading = false;
                            checkoutUrl = 'created';
                          });
                          ref.read(adminPaymentsPagerProvider).refresh();
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
                  'Criar cobrança',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
    valorCtrl.dispose();
  }
}

class _AdminPaymentsPanel extends StatefulWidget {
  final List<PaymentModel> payments;
  final Map<String, String> studentNames;
  final Widget Function(PaymentModel payment, String? studentName) itemBuilder;

  const _AdminPaymentsPanel({
    required this.payments,
    required this.studentNames,
    required this.itemBuilder,
  });

  @override
  State<_AdminPaymentsPanel> createState() => _AdminPaymentsPanelState();
}

class _AdminPaymentsPanelState extends State<_AdminPaymentsPanel> {
  static const _pageSize = 6;
  String _search = '';
  String _status = 'all';
  int _page = 0;

  List<PaymentModel> get _filteredPayments {
    final query = _search.trim().toLowerCase();
    return widget.payments.where((payment) {
      final matchesStatus =
          _status == 'all' || payment.effectiveStatus == _status;
      final searchable = [
        widget.studentNames[payment.userId] ?? '',
        payment.descricao ?? '',
        payment.userId,
      ].join(' ').toLowerCase();
      return matchesStatus && (query.isEmpty || searchable.contains(query));
    }).toList()..sort((a, b) => b.data.compareTo(a.data));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final modalHeight = (MediaQuery.sizeOf(context).height * 0.82)
        .clamp(360.0, 680.0)
        .toDouble();
    final filtered = _filteredPayments;
    final totalPages = filtered.isEmpty
        ? 1
        : (filtered.length + _pageSize - 1) ~/ _pageSize;
    final currentPage = _page.clamp(0, totalPages - 1);
    final firstIndex = currentPage * _pageSize;
    final visiblePayments = filtered.skip(firstIndex).take(_pageSize).toList();
    final lastIndex = filtered.isEmpty
        ? 0
        : (firstIndex + visiblePayments.length);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SizedBox(
          width: double.infinity,
          height: modalHeight,
          child: Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(isCompact ? 22 : 28),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 14, 16),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: colors.limeDim,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.receipt_long_outlined,
                          color: colors.lime,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pagamentos',
                              style: GoogleFonts.montserrat(
                                color: colors.text,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${widget.payments.length} registos · máximo de $_pageSize por página',
                              style: GoogleFonts.inter(
                                color: colors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: colors.muted,
                          size: 20,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: colors.surface2,
                          minimumSize: const Size(38, 38),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isCompact ? 18 : 22,
                    0,
                    isCompact ? 18 : 22,
                    14,
                  ),
                  child: isCompact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _searchField(colors),
                            const SizedBox(height: 9),
                            _PaymentStatusMenu(
                              value: _status,
                              onChanged: _changeStatus,
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: _searchField(colors)),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 190,
                              child: _PaymentStatusMenu(
                                value: _status,
                                onChanged: _changeStatus,
                              ),
                            ),
                          ],
                        ),
                ),
                Divider(height: 1, color: colors.border),
                Expanded(
                  child: visiblePayments.isEmpty
                      ? Center(
                          child: Text(
                            'Nenhum pagamento encontrado.',
                            style: GoogleFonts.inter(color: colors.muted),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            isCompact ? 18 : 22,
                            14,
                            isCompact ? 18 : 22,
                            14,
                          ),
                          itemCount: visiblePayments.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 9),
                          itemBuilder: (_, index) {
                            final payment = visiblePayments[index];
                            return widget.itemBuilder(
                              payment,
                              widget.studentNames[payment.userId],
                            );
                          },
                        ),
                ),
                Divider(height: 1, color: colors.border),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  child: Row(
                    children: [
                      Text(
                        filtered.isEmpty
                            ? '0 pagamentos'
                            : '${firstIndex + 1}–$lastIndex de ${filtered.length}',
                        style: GoogleFonts.inter(
                          color: colors.muted,
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Página anterior',
                        onPressed: currentPage > 0
                            ? () => setState(() => _page--)
                            : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                        color: colors.text,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(36, 36),
                        ),
                      ),
                      Text(
                        '${currentPage + 1}/$totalPages',
                        style: GoogleFonts.inter(
                          color: colors.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Página seguinte',
                        onPressed: currentPage < totalPages - 1
                            ? () => setState(() => _page++)
                            : null,
                        icon: const Icon(Icons.chevron_right_rounded),
                        color: colors.text,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(36, 36),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchField(AdminThemeColors colors) {
    return TextField(
      onChanged: (value) => setState(() {
        _search = value;
        _page = 0;
      }),
      style: GoogleFonts.inter(fontSize: 13, color: colors.text),
      decoration: InputDecoration(
        labelText: 'Pesquisar pagamentos',
        hintText: 'Aluno, descrição ou ID',
        prefixIcon: Icon(Icons.search_rounded, size: 19, color: colors.muted),
        suffixIcon: _search.isEmpty
            ? null
            : IconButton(
                onPressed: () => setState(() {
                  _search = '';
                  _page = 0;
                }),
                icon: Icon(Icons.close_rounded, size: 17, color: colors.muted),
              ),
        filled: true,
        fillColor: colors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.lime, width: 1.2),
        ),
      ),
    );
  }

  void _changeStatus(String value) {
    setState(() {
      _status = value;
      _page = 0;
    });
  }
}

class _AdminPaymentsCompactList extends StatefulWidget {
  final List<PaymentModel> payments;
  final Map<String, String> studentNames;
  final Widget Function(PaymentModel payment, String? studentName) itemBuilder;

  const _AdminPaymentsCompactList({
    required this.payments,
    required this.studentNames,
    required this.itemBuilder,
  });

  @override
  State<_AdminPaymentsCompactList> createState() =>
      _AdminPaymentsCompactListState();
}

class _AdminPaymentsCompactListState extends State<_AdminPaymentsCompactList> {
  static const _pageSize = 6;
  String _search = '';
  String _status = 'all';
  int _page = 0;

  List<PaymentModel> get _filteredPayments {
    final query = _search.trim().toLowerCase();
    return widget.payments.where((payment) {
      final statusMatches =
          _status == 'all' || payment.effectiveStatus == _status;
      final searchable = [
        widget.studentNames[payment.userId] ?? '',
        payment.descricao ?? '',
        payment.userId,
      ].join(' ').toLowerCase();
      return statusMatches && (query.isEmpty || searchable.contains(query));
    }).toList()..sort((a, b) => b.data.compareTo(a.data));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final compact = MediaQuery.sizeOf(context).width < 600;
    final filtered = _filteredPayments;
    final totalPages = filtered.isEmpty
        ? 1
        : (filtered.length + _pageSize - 1) ~/ _pageSize;
    final currentPage = _page.clamp(0, totalPages - 1);
    final firstIndex = currentPage * _pageSize;
    final visible = filtered.skip(firstIndex).take(_pageSize).toList();
    final lastIndex = firstIndex + visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Histórico de pagamentos',
                  style: GoogleFonts.inter(
                    color: colors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${filtered.length} registos',
                style: GoogleFonts.inter(fontSize: 11, color: colors.muted),
              ),
            ],
          ),
        ),
        compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _searchField(colors),
                  const SizedBox(height: 8),
                  _PaymentStatusMenu(value: _status, onChanged: _changeStatus),
                ],
              )
            : Row(
                children: [
                  Expanded(child: _searchField(colors)),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 190,
                    child: _PaymentStatusMenu(
                      value: _status,
                      onChanged: _changeStatus,
                    ),
                  ),
                ],
              ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 34),
            decoration: BoxDecoration(
              color: colors.surface2,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                'Nenhum pagamento encontrado.',
                style: GoogleFonts.inter(color: colors.muted),
              ),
            ),
          )
        else
          ...visible.map(
            (payment) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: widget.itemBuilder(
                payment,
                widget.studentNames[payment.userId],
              ),
            ),
          ),
        if (filtered.length > _pageSize) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                '${firstIndex + 1}–$lastIndex de ${filtered.length}',
                style: GoogleFonts.inter(fontSize: 11, color: colors.muted),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Página anterior',
                onPressed: currentPage > 0
                    ? () => setState(() => _page--)
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
                color: colors.text,
                style: IconButton.styleFrom(minimumSize: const Size(34, 34)),
              ),
              Text(
                '${currentPage + 1}/$totalPages',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                ),
              ),
              IconButton(
                tooltip: 'Página seguinte',
                onPressed: currentPage < totalPages - 1
                    ? () => setState(() => _page++)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
                color: colors.text,
                style: IconButton.styleFrom(minimumSize: const Size(34, 34)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _searchField(AdminThemeColors colors) {
    return TextField(
      onChanged: (value) => setState(() {
        _search = value;
        _page = 0;
      }),
      style: GoogleFonts.inter(fontSize: 13, color: colors.text),
      decoration: InputDecoration(
        labelText: 'Pesquisar pagamentos',
        hintText: 'Aluno, descrição ou ID',
        prefixIcon: Icon(Icons.search_rounded, size: 19, color: colors.muted),
        suffixIcon: _search.isEmpty
            ? null
            : IconButton(
                onPressed: () => setState(() {
                  _search = '';
                  _page = 0;
                }),
                icon: Icon(Icons.close_rounded, size: 17, color: colors.muted),
              ),
        filled: true,
        fillColor: colors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.lime, width: 1.2),
        ),
      ),
    );
  }

  void _changeStatus(String value) {
    setState(() {
      _status = value;
      _page = 0;
    });
  }
}

class _PaymentStatusMenu extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _PaymentStatusMenu({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final compact = MediaQuery.sizeOf(context).width < 600;
    const options = [
      ('all', 'Todos os estados'),
      ('paid', 'Pagos'),
      ('pending', 'Pendentes'),
      ('overdue', 'Em atraso'),
      ('scheduled', 'Agendados'),
      ('failed', 'Falhados'),
      ('cancelled', 'Cancelados'),
    ];
    final selectedLabel = options
        .firstWhere((option) => option.$1 == value, orElse: () => options.first)
        .$2;

    return LayoutBuilder(
      builder: (context, constraints) {
        final fieldWidth = constraints.maxWidth;
        return MenuAnchor(
          crossAxisUnconstrained: false,
          alignmentOffset: const Offset(0, 4),
          style: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(colors.surface2),
            elevation: const WidgetStatePropertyAll(3),
            minimumSize: WidgetStatePropertyAll(Size(fieldWidth, 0)),
            maximumSize: WidgetStatePropertyAll(Size(fieldWidth, 320)),
            shape: const WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
            ),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(vertical: 6),
            ),
          ),
          menuChildren: options
              .map(
                (option) => MenuItemButton(
                  onPressed: () => onChanged(option.$1),
                  child: SizedBox(
                    width: fieldWidth - 28,
                    child: Text(
                      option.$2,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: compact ? 12 : 13,
                        color: colors.text,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
          builder: (context, controller, child) => GestureDetector(
            onTap: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            child: InputDecorator(
              isFocused: controller.isOpen,
              isEmpty: false,
              decoration: InputDecoration(
                labelText: 'Estado',
                filled: true,
                fillColor: colors.surface,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 14,
                  vertical: compact ? 10 : 12,
                ),
                suffixIcon: Icon(
                  controller.isOpen
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: colors.lime,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                floatingLabelStyle: GoogleFonts.inter(
                  color: colors.text,
                  fontSize: compact ? 12 : 14,
                ),
                labelStyle: GoogleFonts.inter(
                  color: colors.muted,
                  fontSize: compact ? 12 : 14,
                ),
              ),
              child: Text(
                selectedLabel,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: compact ? 12 : 13,
                  color: colors.text,
                ),
              ),
            ),
          ),
        );
      },
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
  final _agendaScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _trainerId = ref.read(authProvider).user?.uid ?? '';
  }

  @override
  void dispose() {
    _agendaScrollController.dispose();
    super.dispose();
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
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(
                  minWidth: isMobile ? 34 : 40,
                  minHeight: isMobile ? 34 : 40,
                ),
              ),
              Flexible(
                child: GestureDetector(
                  onTap: () => _pickMonth(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          DateFormat('MMMM yyyy', 'pt').format(_selectedDate),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: isMobile ? 14 : 16,
                            fontWeight: FontWeight.w600,
                            color: AdminThemeColors.of(context).text,
                          ),
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
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(
                  minWidth: isMobile ? 34 : 40,
                  minHeight: isMobile ? 34 : 40,
                ),
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
    final hours = List<int>.generate(18, (index) => index + 6);

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
    final scrollableGridBody = SizedBox(
      height: isMobile ? 520 : 620,
      child: Scrollbar(
        controller: _agendaScrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _agendaScrollController,
          padding: const EdgeInsets.only(bottom: 4),
          child: gridBody,
        ),
      ),
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
                    scrollableGridBody,
                  ],
                ),
              ),
            )
          : Column(
              children: [
                _buildWeekHeader(weekDays, today, false, colWidth),
                scrollableGridBody,
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
      padding: const EdgeInsets.symmetric(vertical: 10),
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
    final studentName = studentNames[b.studentId] ?? 'Aluno';
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
    final picked = await showAppDatePicker(
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
                style: GoogleFonts.montserrat(
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
                    StorageAvatar(
                      resource: user.fotoPerfil,
                      radius: 36,
                      backgroundColor: AdminThemeColors.of(context).surface2,
                      fallback: Text(
                        user.nome.isNotEmpty ? user.nome[0].toUpperCase() : '?',
                        style: GoogleFonts.montserrat(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AdminThemeColors.of(context).lime,
                        ),
                      ),
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
                style: GoogleFonts.montserrat(
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
      final storagePath = await ref
          .read(progressRepositoryProvider)
          .uploadProfilePhoto(user.uid, Uint8List.fromList(bytes));
      await ref.read(userRepositoryProvider).updateUser(user.uid, {
        'fotoPerfil': storagePath,
      });
      ref.invalidate(userProfileProvider(user.uid));
    } catch (_) {}
  }
}
