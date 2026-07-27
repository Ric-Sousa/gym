import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/config/app_colors.dart';
import '../../../core/config/admin_theme.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/food_model.dart';
import '../../../data/models/progress_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/providers/global_providers.dart';
import '../../../shared/providers/admin_providers.dart';
import '../../../shared/widgets/app_notification.dart';
import '../../admin/widgets/workout_editor.dart';
import '../../admin/widgets/nutrition_editor.dart';
import '../../admin/widgets/admin_messages_view.dart';
import '../../../features/aluno/chat/screens/chat_screen.dart';

// ─── Enums & Local Providers ──────────────────────────────────────

enum AdminView { dashboard, clients, exercises, foods, messages }

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminThemeColors.of(context).bg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AdminSidebar(
            currentView: _view,
            isClientDetail: _selectedClient != null,
            onNavigate: _navigate,
            onLogout: () => ref.read(authProvider.notifier).signOut(),
            onToggleTheme: () {
              ref.read(adminThemeModeProvider.notifier).state =
                  ref.read(adminThemeModeProvider) == ThemeMode.dark
                      ? ThemeMode.light
                      : ThemeMode.dark;
            },
          ),
          Expanded(
            child: _selectedClient != null
                ? _ClientDetailView(
                    client: _selectedClient!,
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
    }
  }
}

// ─── Sidebar ──────────────────────────────────────────────────────

class _AdminSidebar extends StatelessWidget {
  final AdminView currentView;
  final bool isClientDetail;
  final Function(AdminView) onNavigate;
  final VoidCallback onLogout;

  const _AdminSidebar({
    required this.currentView,
    required this.isClientDetail,
    required this.onNavigate,
    required this.onLogout,
    required this.onToggleTheme,
  });

  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
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
          const SizedBox(height: 28),
          // Logo
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
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AdminThemeColors.of(context).text,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
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
          _NavCategory(label: 'COMUNICAÇÃO'),
          _NavItem(
            icon: Icons.chat_outlined,
            activeIcon: Icons.chat,
            label: 'Mensagens',
            active: currentView == AdminView.messages && !isClientDetail,
            onTap: () => onNavigate(AdminView.messages),
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
                      style: GoogleFonts.dmSans(
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
                  style: GoogleFonts.dmSans(
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DASHBOARD', style: _adminDisplay(context, 40)),
          const SizedBox(height: 4),
          Text(
            DateFormat('EEEE, d MMMM yyyy', 'pt').format(DateTime.now()),
            style:
                GoogleFonts.dmSans(fontSize: 14, color: AdminThemeColors.of(context).muted),
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
                style: GoogleFonts.dmSans(color: AdminThemeColors.of(context).muted)),
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
      final cols = constraints.maxWidth > 800 ? 4 : 2;
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
      final cols = constraints.maxWidth > 800 ? 4 : 2;
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
                  style: GoogleFonts.dmSans(
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
                      style: GoogleFonts.dmSans(
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
                      style: GoogleFonts.dmSans(
                          color: AdminThemeColors.of(context).muted, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('Clique em "Clientes" para adicionar o primeiro.',
                      style: GoogleFonts.dmSans(
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
                      style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AdminThemeColors.of(context).text)),
                  Text('${aluno.email}',
                      style: GoogleFonts.dmSans(
                          fontSize: 11, color: AdminThemeColors.of(context).muted)),
                ],
              ),
            ),
            if (weight != null) ...[
              Text('${weight.toStringAsFixed(0)}kg',
                  style: GoogleFonts.dmMono(
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
          ...['Segunda', 'Quarta', 'Sexta'].map((day) {
            final isToday = _todayWeekday() == day;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(day.toUpperCase(),
                          style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.08,
                              color: isToday
                                  ? AdminThemeColors.of(context).lime
                                  : AdminThemeColors.of(context).muted)),
                      if (isToday) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                              color: AdminThemeColors.of(context).lime,
                              borderRadius: BorderRadius.circular(20)),
                          child: Text('HOJE',
                              style: GoogleFonts.dmSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AdminThemeColors.of(context).bg)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Consulta os planos dos alunos',
                      style: GoogleFonts.dmSans(
                          fontSize: 12, color: AdminThemeColors.of(context).muted)),
                ],
              ),
            );
          }),
        ],
      ),
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
                            style: GoogleFonts.dmSans(
                                fontSize: 12, color: AdminThemeColors.of(context).muted)),
                        Text('${g.$2}',
                            style: GoogleFonts.dmMono(
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

  String _todayWeekday() {
    const days = [
      'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'
    ];
    return days[DateTime.now().weekday - 1];
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CLIENTES', style: _adminDisplay(context, 40)),
                    Text(
                        '${alunosAsync.valueOrNull?.length ?? 0} clientes cadastrados',
                        style: GoogleFonts.dmSans(
                            fontSize: 14, color: AdminThemeColors.of(context).muted)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showCreateStudentDialog,
                icon: const Icon(Icons.add, size: 16),
                label: Text('NOVO CLIENTE',
                    style: GoogleFonts.dmSans(
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
          const SizedBox(height: 28),
          // Search + filters
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    style: GoogleFonts.dmSans(
                        fontSize: 13, color: AdminThemeColors.of(context).text),
                    decoration: InputDecoration(
                      hintText: 'Buscar cliente...',
                      hintStyle: GoogleFonts.dmSans(
                          fontSize: 13, color: AdminThemeColors.of(context).muted),
                      prefixIcon: Icon(Icons.search,
                          size: 16, color: AdminThemeColors.of(context).muted),
                      filled: true,
                      fillColor: AdminThemeColors.of(context).surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: AdminThemeColors.of(context).border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: AdminThemeColors.of(context).border),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ...['all', 'active', 'inactive'].map((f) {
                final active = _filter == f;
                final labels = {
                  'all': 'Todos',
                  'active': 'Ativo',
                  'inactive': 'Inativo'
                };
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: active
                            ? AdminThemeColors.of(context).surface2
                            : AdminThemeColors.of(context).surface,
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: AdminThemeColors.of(context).border),
                      ),
                      child: Text(labels[f]!,
                          style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: active
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: active
                                  ? AdminThemeColors.of(context).text
                                  : AdminThemeColors.of(context).muted)),
                    ),
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
                style: GoogleFonts.dmSans(color: AdminThemeColors.of(context).muted)),
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
                  style: GoogleFonts.dmSans(color: AdminThemeColors.of(context).muted)),
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
                            style: GoogleFonts.dmSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AdminThemeColors.of(context).text)),
                        Text(
                            '${aluno.pesoAtual?.toStringAsFixed(1) ?? '--'} kg',
                            style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: AdminThemeColors.of(context).muted)),
                      ],
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
                      '${aluno.imc?.toStringAsFixed(1) ?? '--'}'),
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
                        style: GoogleFonts.dmSans(
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
              style: GoogleFonts.dmSans(
                  fontSize: 10,
                  color: AdminThemeColors.of(context).muted,
                  letterSpacing: 0.06)),
          Text(value,
              style: GoogleFonts.dmMono(
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
    bool loading = false;

    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AdminThemeColors.of(context).surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: AdminThemeColors.of(context).border)),
          title: Text('Novo Cliente',
              style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700, color: AdminThemeColors.of(context).text)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeCtrl,
                style: GoogleFonts.dmSans(color: AdminThemeColors.of(context).text),
                decoration: InputDecoration(
                  labelText: 'Nome completo',
                  labelStyle: GoogleFonts.dmSans(color: AdminThemeColors.of(context).muted),
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
                style: GoogleFonts.dmSans(color: AdminThemeColors.of(context).text),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: GoogleFonts.dmSans(color: AdminThemeColors.of(context).muted),
                  filled: true,
                  fillColor: AdminThemeColors.of(context).bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),                        borderSide:
                            BorderSide(color: AdminThemeColors.of(context).border),
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
              child: Text('Cancelar',
                  style: GoogleFonts.dmSans(color: AdminThemeColors.of(context).muted)),
            ),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (nomeCtrl.text.trim().isEmpty ||
                          emailCtrl.text.trim().isEmpty) return;
                      setDialogState(() => loading = true);
                      try {
                        final functions =
                            FirebaseFunctions.instanceFor(region: 'europe-west1');
                        final callable =
                            functions.httpsCallable('createStudent');
                        final response = await callable.call(<String, dynamic>{
                          'nome': nomeCtrl.text.trim(),
                          'email': emailCtrl.text.trim(),
                        });
                        final data = response.data as Map<String, dynamic>;
                        setDialogState(() => loading = false);
                        Navigator.pop(ctx, {
                          'uid': data['uid'] as String,
                          'email': data['email'] as String,
                          'password': data['temporaryPassword'] as String?,
                        });
                      } catch (e) {
                        setDialogState(() => loading = false);
                        showAppNotification(context, 'Erro: ${e.toString()}', type: NotificationType.error);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminThemeColors.of(context).lime,
                foregroundColor: AdminThemeColors.of(context).bg,
              ),
              child: Text('Criar',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      ref.invalidate(alunosListProvider);
      if (mounted) {
        final hasPassword = result['password'] != null;
        showAppNotification(
          context,
          hasPassword
              ? 'Aluno criado! Password temporária: ${result['password']}'
              : 'Aluno "${result['email']}" já existia. Documento atualizado.',
          type: NotificationType.success,
          duration: const Duration(seconds: 8),
        );
      }
    }
  }
}

// ─── Client Detail View ───────────────────────────────────────────

class _ClientDetailView extends ConsumerStatefulWidget {
  final UserModel client;
  final VoidCallback onBack;
  const _ClientDetailView({required this.client, required this.onBack});

  @override
  ConsumerState<_ClientDetailView> createState() => _ClientDetailViewState();
}

class _ClientDetailViewState extends ConsumerState<_ClientDetailView> {
  String _tab = 'overview';
  bool _requestingProgress = false;

  Widget _requestProgressButton(UserModel client) {
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
        style: GoogleFonts.dmSans(
          fontSize: 11,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Future<void> _requestProgress(UserModel client) async {
    setState(() => _requestingProgress = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          showAppNotification(context, 'Sessão expirada. Faz login novamente.',
              type: NotificationType.error);
        }
        return;
      }
      final idToken = await user.getIdToken();
      final functions =
          FirebaseFunctions.instanceFor(region: 'europe-west1');
      final callable = functions.httpsCallable('requestProgress');
      await callable.call(<String, dynamic>{
        'userId': client.uid,
        'authToken': idToken,
      });
      if (mounted) {
        showAppNotification(
          context,
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
      padding: const EdgeInsets.all(36),
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
                    style: GoogleFonts.dmSans(
                        fontSize: 13, color: AdminThemeColors.of(context).muted)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Header
          Container(
            padding: const EdgeInsets.all(24),
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
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AdminThemeColors.of(context).surface2,
                  child: Text(
                    c.nome.isNotEmpty
                        ? c.nome.substring(
                            0, c.nome.length >= 2 ? 2 : 1).toUpperCase()
                        : '?',
                    style: GoogleFonts.barlowCondensed(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AdminThemeColors.of(context).lime),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.nome.toUpperCase(),
                          style: GoogleFonts.barlowCondensed(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.01,
                              color: AdminThemeColors.of(context).text)),
                      Text(
                          '${c.pesoAtual?.toStringAsFixed(1) ?? '-'}kg · ${c.altura?.toStringAsFixed(0) ?? '-'}cm · IMC: ${c.imc?.toStringAsFixed(1) ?? '-'}',
                          style: GoogleFonts.dmSans(
                              fontSize: 13, color: AdminThemeColors.of(context).muted)),
                    ],
                  ),
                ),
                _requestProgressButton(c),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Tabs
          Row(
            children: [
              _tabBtn('overview', 'Visão Geral', Icons.person),
              const SizedBox(width: 4),
              _tabBtn('progresso', 'Progresso', Icons.trending_up),
              const SizedBox(width: 4),
              _tabBtn('workout', 'Plano de Treino', Icons.fitness_center),
              const SizedBox(width: 4),
              _tabBtn('nutrition', 'Nutrição', Icons.restaurant),
              const SizedBox(width: 4),
              _tabBtn('chat', 'Chat', Icons.chat),
            ],
          ),
          const SizedBox(height: 20),
          if (_tab == 'overview') _buildOverview(),
          if (_tab == 'progresso') _buildProgressTab(),
          if (_tab == 'workout')
            SizedBox(
              height: 600,
              child: WorkoutEditor(aluno: widget.client),
            ),
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
                key: ValueKey('admin_chat_${widget.client.uid}'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tabBtn(String id, String label, IconData icon) {
    final active = _tab == id;
    return GestureDetector(
      onTap: () => setState(() => _tab = id),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AdminThemeColors.of(context).limeDim : AdminThemeColors.of(context).surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active
                  ? AdminThemeColors.of(context).lime
                  : AdminThemeColors.of(context).border),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 14,
                color: active
                    ? AdminThemeColors.of(context).lime
                    : AdminThemeColors.of(context).muted),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight:
                        active ? FontWeight.w600 : FontWeight.w400,
                    color: active
                        ? AdminThemeColors.of(context).lime
                        : AdminThemeColors.of(context).muted)),
          ],
        ),
      ),
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
                            style: GoogleFonts.dmSans(
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
                    style: GoogleFonts.dmSans(
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
                      style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: AdminThemeColors.of(context).muted)),
                  const SizedBox(height: 4),
                  Text(
                    'Solicita uma avaliação ao aluno',
                    style: GoogleFonts.dmSans(
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
                GoogleFonts.dmSans(color: AdminThemeColors.of(context).muted)),
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
                  style: GoogleFonts.dmMono(
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
                  style: GoogleFonts.dmSans(
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

  Widget _buildInfoCards(UserModel c) {
    return Column(
      children: [
        _infoCard('Dados do Aluno', [
          ('Peso', '${c.pesoAtual?.toStringAsFixed(1) ?? '--'} kg'),
          ('Altura', '${c.altura?.toStringAsFixed(0) ?? '--'} cm'),
          ('IMC', '${c.imc?.toStringAsFixed(1) ?? '--'}'),
          ('Categoria', '${c.imcCategory ?? '--'}'),
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
                        style: GoogleFonts.dmSans(
                            fontSize: 12, color: AdminThemeColors.of(context).muted)),
                    Text(r.$2,
                        style: GoogleFonts.dmMono(
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

  static const _muscles = [
    'Todos', 'Peito', 'Costas', 'Quadríceps', 'Posterior',
    'Ombros', 'Bíceps', 'Tríceps', 'Core', 'Glúteos'
  ];

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(adminExercisesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                        style: GoogleFonts.dmSans(
                            fontSize: 14, color: AdminThemeColors.of(context).muted)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddExerciseDialog,
                icon: const Icon(Icons.add, size: 16),
                label: Text('NOVO EXERCÍCIO',
                    style: GoogleFonts.dmSans(
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
          const SizedBox(height: 24),
          // Search
          SizedBox(
            width: 360,
            height: 40,
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: GoogleFonts.dmSans(
                  fontSize: 13, color: AdminThemeColors.of(context).text),
              decoration: InputDecoration(
                hintText: 'Buscar exercício...',
                hintStyle: GoogleFonts.dmSans(
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
                      style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: active
                              ? AdminThemeColors.of(context).lime
                              : AdminThemeColors.of(context).muted)),
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
                final matchSearch = name.contains(_search.toLowerCase());
                final matchMuscle =
                    _muscle == 'Todos' || muscle == _muscle;
                return matchSearch && matchMuscle;
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
                            style: GoogleFonts.dmSans(
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
                                '${(i + 1).toString().padLeft(2, '0')}',
                                style: GoogleFonts.barlowCondensed(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w900,
                                    color: AdminThemeColors.of(context).text
                                        .withValues(alpha: 0.04),
                                    height: 1)),
                            const SizedBox(height: 8),
                            Text(nome,
                                style: GoogleFonts.dmSans(
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
                      style: GoogleFonts.dmSans(
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
          style: GoogleFonts.dmSans(fontSize: 11, color: color)),
    );
  }

  Future<void> _showAddExerciseDialog() async {
    final nomeCtrl = TextEditingController();
    final grupoCtrl = TextEditingController();
    final equipCtrl = TextEditingController();
    String selectedGrupo = 'Peito';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AdminThemeColors.of(context).surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: AdminThemeColors.of(context).border)),
          title: Text('Novo Exercício',
              style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  color: AdminThemeColors.of(context).text)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomeCtrl,
                  style: GoogleFonts.dmSans(color: AdminThemeColors.of(context).text),
                  decoration: InputDecoration(
                    labelText: 'Nome do exercício',
                    labelStyle: GoogleFonts.dmSans(
                        color: AdminThemeColors.of(context).muted),
                    filled: true,
                    fillColor: AdminThemeColors.of(context).bg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedGrupo,
                  dropdownColor: AdminThemeColors.of(context).surface,
                  style: GoogleFonts.dmSans(color: AdminThemeColors.of(context).text),
                  decoration: InputDecoration(
                    labelText: 'Grupo Muscular',
                    labelStyle: GoogleFonts.dmSans(
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
                              style: GoogleFonts.dmSans(
                                  color: AdminThemeColors.of(context).text))))
                      .toList(),
                  onChanged: (v) => setDialogState(
                      () => selectedGrupo = v ?? 'Peito'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: equipCtrl,
                  style: GoogleFonts.dmSans(color: AdminThemeColors.of(context).text),
                  decoration: InputDecoration(
                    hintText: 'Ex: Barra, Halter, Máquina, Polia...',
                    labelText: 'Equipamento',
                    labelStyle: GoogleFonts.dmSans(
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
                      GoogleFonts.dmSans(color: AdminThemeColors.of(context).muted)),
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
                  style: GoogleFonts.dmSans(
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                        style: GoogleFonts.dmSans(
                            fontSize: 14, color: AdminThemeColors.of(context).muted)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddFoodDialog,
                icon: const Icon(Icons.add, size: 16),
                label: Text('NOVO ALIMENTO',
                    style: GoogleFonts.dmSans(
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
          const SizedBox(height: 24),
          SizedBox(
            width: 360,
            height: 40,
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: GoogleFonts.dmSans(
                  fontSize: 13, color: AdminThemeColors.of(context).text),
              decoration: InputDecoration(
                hintText: 'Buscar alimento...',
                hintStyle: GoogleFonts.dmSans(
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
                            style: GoogleFonts.dmSans(
                                color: AdminThemeColors.of(context).muted)),
                        const SizedBox(height: 8),
                        Text(
                            'Adiciona os primeiros alimentos à biblioteca.',
                            style: GoogleFonts.dmSans(
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
                  style: GoogleFonts.dmSans(
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
                    style: GoogleFonts.dmSans(
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
                    style: GoogleFonts.dmSans(
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
              style: GoogleFonts.dmMono(
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
          style: GoogleFonts.dmSans(
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
              style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  color: AdminThemeColors.of(context).text)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomeCtrl,
                  style: GoogleFonts.dmSans(color: AdminThemeColors.of(context).text),
                  decoration: InputDecoration(
                    labelText: 'Nome do alimento',
                    labelStyle: GoogleFonts.dmSans(
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
                  style: GoogleFonts.dmSans(color: AdminThemeColors.of(context).text),
                  decoration: InputDecoration(
                    labelText: 'Calorias (por 100g/ml)',
                    labelStyle: GoogleFonts.dmSans(
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
                        style: GoogleFonts.dmSans(
                            color: AdminThemeColors.of(context).text),
                        decoration: InputDecoration(
                          labelText: 'Proteína (g)',
                          labelStyle: GoogleFonts.dmSans(
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
                        style: GoogleFonts.dmSans(
                            color: AdminThemeColors.of(context).text),
                        decoration: InputDecoration(
                          labelText: 'Hidratos (g)',
                          labelStyle: GoogleFonts.dmSans(
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
                        style: GoogleFonts.dmSans(
                            color: AdminThemeColors.of(context).text),
                        decoration: InputDecoration(
                          labelText: 'Gordura (g)',
                          labelStyle: GoogleFonts.dmSans(
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
                  value: selectedCat,
                  dropdownColor: AdminThemeColors.of(context).surface,
                  style:
                      GoogleFonts.dmSans(color: AdminThemeColors.of(context).text),
                  decoration: InputDecoration(
                    labelText: 'Categoria',
                    labelStyle: GoogleFonts.dmSans(
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
                              style: GoogleFonts.dmSans(
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
                  style: GoogleFonts.dmSans(
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
                  style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
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
