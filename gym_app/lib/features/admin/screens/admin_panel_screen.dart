import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/config/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/providers/global_providers.dart';

// ─── Enums & Providers ────────────────────────────────────────────

enum AdminView { dashboard, clients, exercises }

final alunosListProvider = FutureProvider<List<UserModel>>((ref) {
  return ref.read(userRepositoryProvider).getAllAlunos();
});

final alunosSearchProvider = FutureProvider.family<List<UserModel>, String>((ref, query) {
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

  void _navigate(AdminView v) {
    setState(() {
      _view = v;
      _selectedClient = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.adminBg,
      body: Row(
        children: [
          _AdminSidebar(
            currentView: _view,
            isClientDetail: _selectedClient != null,
            onNavigate: _navigate,
            onLogout: () => ref.read(authProvider.notifier).signOut(),
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
        return _AdminExerciseLibrary();
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
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: AppColors.adminSurface,
        border: Border(
          right: BorderSide(color: AppColors.adminBorder, width: 1),
        ),
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
                    color: AppColors.adminLimeDim,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.adminLime.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.fitness_center, color: AppColors.adminLime, size: 16),
                ),
                const SizedBox(width: 10),
                Text(
                  'GYMBT',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.adminText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
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
                    const Icon(Icons.logout, color: AppColors.adminMuted, size: 16),
                    const SizedBox(width: 10),
                    Text(
                      'Sair',
                      style: GoogleFonts.dmSans(color: AppColors.adminMuted, fontSize: 13),
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
          color: AppColors.adminMuted,
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
        color: active ? AppColors.adminLimeDim : Colors.transparent,
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
                  color: active ? AppColors.adminLime : AppColors.adminMuted,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active ? AppColors.adminText : AppColors.adminMuted,
                  ),
                ),
                if (active)
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(left: 6),
                    decoration: BoxDecoration(
                      color: AppColors.adminLime,
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

class _AdminDashboard extends ConsumerWidget {
  final Function(UserModel) onSelectClient;
  const _AdminDashboard({required this.onSelectClient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alunosAsync = ref.watch(alunosListProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text('DASHBOARD', style: _adminDisplay(40)),
          const SizedBox(height: 4),
          Text(
            DateFormat('EEEE, d MMMM yyyy', 'pt').format(DateTime.now()),
            style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.adminMuted),
          ),
          const SizedBox(height: 32),
          // Stats row
          alunosAsync.when(
            data: (alunos) {
              final active = alunos.where((a) => a.ultimaAtividade != null && 
                  DateTime.now().difference(a.ultimaAtividade!).inDays < 30).length;
              return _buildStats(alunos.length, active);
            },
            loading: () => _buildStats(0, 0),
            error: (_, __) => _buildStats(0, 0),
          ),
          const SizedBox(height: 32),
          // Clients & Agenda columns
          alunosAsync.when(
            data: (alunos) => _buildDashboardColumns(alunos),
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.adminLime)),
            error: (_, __) => Text('Erro', style: GoogleFonts.dmSans(color: AppColors.adminMuted)),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(int total, int active) {
    final stats = [
      ('Clientes Totais', total, Icons.people, AppColors.adminLime),
      ('Ativos', active, Icons.trending_up, AppColors.adminBlue),
      ('Sessões Mês', 38, Icons.calendar_today, AppColors.adminOrange),
      ('Sessões Totais', 176, Icons.emoji_events, AppColors.adminPurple),
    ];
    return LayoutBuilder(builder: (_, constraints) {
      final cols = constraints.maxWidth > 800 ? 4 : 2;
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: stats.map((s) {
          final width = (constraints.maxWidth - 14 * (cols - 1)) / cols;
          return SizedBox(
            width: width,
            child: _statCard(s.$1, s.$2.toString(), s.$3, s.$4),
          );
        }).toList(),
      );
    });
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.adminSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.adminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label.toUpperCase(),
                  style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.adminMuted, letterSpacing: 0.04)),
              Container(
                width: 38, height: 38,
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
              style: GoogleFonts.barlowCondensed(fontSize: 42, fontWeight: FontWeight.w900, color: AppColors.adminText, height: 1)),
        ],
      ),
    );
  }

  Widget _buildDashboardColumns(List<UserModel> alunos) {
    return LayoutBuilder(builder: (_, constraints) {
      final isWide = constraints.maxWidth > 800;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: isWide ? 2 : 1,
            child: _clientsCard(alunos),
          ),
          if (isWide) ...[
            const SizedBox(width: 20),
            Expanded(
              child: Column(children: [_agendaCard(), const SizedBox(height: 20), _goalsCard(alunos)]),
            ),
          ] else ...[
            const SizedBox(height: 20),
            Expanded(child: _agendaCard()),
            const SizedBox(height: 20),
            Expanded(child: _goalsCard(alunos)),
          ],
        ],
      );
    });
  }

  Widget _clientsCard(List<UserModel> alunos) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.adminSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.adminBorder),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.people, color: AppColors.adminLime, size: 16),
                const SizedBox(width: 8),
                Text('CLIENTES', style: GoogleFonts.barlowCondensed(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.03, color: AppColors.adminText)),
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  child: Text('Ver todos', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.adminLime)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.adminBorder),
          ...alunos.take(5).map((a) => _clientRow(a)),
        ],
      ),
    );
  }

  Widget _clientRow(UserModel aluno) {
    final weight = aluno.pesoAtual ?? 0;
    return InkWell(
      onTap: () => onSelectClient(aluno),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.adminBorder))),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.adminSurface2,
              child: Text(
                aluno.nome.isNotEmpty ? aluno.nome[0].toUpperCase() : '?',
                style: GoogleFonts.barlowCondensed(color: AppColors.adminLime, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(aluno.nome, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.adminText)),
                  Text('${aluno.email}', style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.adminMuted)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.adminLime.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('ATIVO', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.adminLime, letterSpacing: 0.06)),
            ),
            const SizedBox(width: 12),
            Text('${weight.toStringAsFixed(0)}kg', style: GoogleFonts.dmMono(fontSize: 13, color: AppColors.adminText)),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 14, color: AppColors.adminMuted),
          ],
        ),
      ),
    );
  }

  Widget _agendaCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.adminSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.adminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AGENDA DA SEMANA', style: GoogleFonts.barlowCondensed(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.03, color: AppColors.adminText)),
          const SizedBox(height: 16),
          ...['Segunda', 'Quarta', 'Sexta'].map((day) {
            final isToday = day == 'Quarta';
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(day.toUpperCase(),
                          style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.08,
                              color: isToday ? AppColors.adminLime : AppColors.adminMuted)),
                      if (isToday) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: AppColors.adminLime, borderRadius: BorderRadius.circular(20)),
                          child: Text('HOJE', style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.adminBg)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  ...[
                    'Rafael Mendes 07:00',
                    'Fernanda Costa 08:30',
                  ].map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: BoxDecoration(
                                color: isToday ? AppColors.adminLime : AppColors.adminMuted,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(s, style: GoogleFonts.dmSans(fontSize: 12, color: isToday ? AppColors.adminText : AppColors.adminMuted)),
                          ],
                        ),
                      )),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _goalsCard(List<UserModel> alunos) {
    final goals = [
      ('Hipertrofia', 2, AppColors.adminBlue),
      ('Emagrecimento', 1, AppColors.adminLime),
      ('Condicionamento', 1, AppColors.adminOrange),
      ('Saúde geral', 1, AppColors.adminPurple),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.adminSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.adminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('OBJETIVOS', style: GoogleFonts.barlowCondensed(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.03, color: AppColors.adminText)),
          const SizedBox(height: 16),
          ...goals.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(g.$1, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.adminMuted)),
                        Text('${g.$2}', style: GoogleFonts.dmMono(fontSize: 12, color: AppColors.adminText)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: g.$2 / alunos.length,
                        backgroundColor: AppColors.adminSurface2,
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
                    Text('CLIENTES', style: _adminDisplay(40)),
                    Text('${alunosAsync.valueOrNull?.length ?? 0} clientes cadastrados',
                        style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.adminMuted)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 16),
                label: Text('NOVO CLIENTE',
                    style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.02)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.adminLime,
                  foregroundColor: AppColors.adminBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                    style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.adminText),
                    decoration: InputDecoration(
                      hintText: 'Buscar cliente ou objetivo...',
                      hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.adminMuted),
                      prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.adminMuted),
                      filled: true,
                      fillColor: AppColors.adminSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.adminBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.adminBorder),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ...['all', 'active', 'new', 'inactive'].map((f) {
                final active = _filter == f;
                final labels = {'all': 'Todos', 'active': 'Ativo', 'new': 'Novo', 'inactive': 'Inativo'};
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: active ? AppColors.adminSurface2 : AppColors.adminSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.adminBorder),
                      ),
                      child: Text(labels[f]!,
                          style: GoogleFonts.dmSans(fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                              color: active ? AppColors.adminText : AppColors.adminMuted)),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 24),
          // Clients grid
          alunosAsync.when(
            data: (alunos) => _buildGrid(alunos),
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.adminLime)),
            error: (_, __) => Text('Erro', style: GoogleFonts.dmSans(color: AppColors.adminMuted)),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<UserModel> alunos) {
    final filtered = alunos.where((a) {
      if (_filter == 'active') return a.ultimaAtividade != null;
      if (_filter == 'inactive') return a.ultimaAtividade == null;
      return true;
    }).toList();

    return LayoutBuilder(builder: (_, constraints) {
      final cols = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 500 ? 2 : 1);
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
      color: AppColors.adminSurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => widget.onSelect(aluno),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.adminBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.adminSurface2,
                    child: Text(
                      aluno.nome.isNotEmpty ? aluno.nome[0].toUpperCase() : '?',
                      style: GoogleFonts.barlowCondensed(color: AppColors.adminLime, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(aluno.nome, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.adminText)),
                        Text('${aluno.pesoAtual ?? '--'} kg', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.adminMuted)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.adminLime.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('ATIVO', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.adminLime, letterSpacing: 0.06)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _miniStat('OBJETIVO', 'Hipertrofia'),
                  const SizedBox(width: 8),
                  _miniStat('PESO', '${aluno.pesoAtual ?? '--'}kg'),
                  const SizedBox(width: 8),
                  _miniStat('SESSÕES', '${aluno.ultimaAtividade != null ? 12 : 0}'),
                ].map((e) => Expanded(child: e)).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('Desde Jan 2024', style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.adminMuted)),
                  const Spacer(),
                  const Icon(Icons.chevron_right, size: 14, color: AppColors.adminMuted),
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
        color: AppColors.adminBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.adminMuted, letterSpacing: 0.06)),
          Text(value, style: GoogleFonts.dmMono(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.adminText)),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final c = widget.client;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back
          GestureDetector(
            onTap: widget.onBack,
            child: Row(
              children: [
                const Icon(Icons.arrow_back, size: 14, color: AppColors.adminMuted),
                const SizedBox(width: 6),
                Text('Clientes', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.adminMuted)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Header card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.adminSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.adminBorder),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.adminSurface2,
                  child: Text(
                    c.nome.isNotEmpty ? c.nome.substring(0, 2).toUpperCase() : '?',
                    style: GoogleFonts.barlowCondensed(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.adminLime),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.nome.toUpperCase(),
                          style: GoogleFonts.barlowCondensed(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.01, color: AppColors.adminText)),
                      Text('${c.pesoAtual ?? '-'}kg · ${c.altura ?? '-'}cm · Objetivo: Hipertrofia',
                          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.adminMuted)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _headerStat('PESO ATUAL', '${c.pesoAtual ?? '--'}kg', AppColors.adminText),
                    const SizedBox(width: 16),
                    _headerStat('GORDURA', '14%', AppColors.adminOrange),
                    const SizedBox(width: 16),
                    _headerStat('SESSÕES', '48', AppColors.adminBlue),
                    const SizedBox(width: 16),
                    _headerStat('VARIAÇÃO', '+2.0kg', AppColors.adminLime),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Tabs
          Row(
            children: [
              _tabBtn('overview', 'Visão Geral', Icons.person),
              const SizedBox(width: 4),
              _tabBtn('workout', 'Plano de Treino', Icons.fitness_center),
              const SizedBox(width: 4),
              _tabBtn('nutrition', 'Nutrição', Icons.restaurant),
            ],
          ),
          const SizedBox(height: 20),
          // Content
          if (_tab == 'overview') _buildOverview(),
          if (_tab == 'workout') _buildWorkout(),
          if (_tab == 'nutrition') _buildNutrition(),
        ],
      ),
    );
  }

  Widget _headerStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.adminMuted, letterSpacing: 0.08)),
        Text(value, style: GoogleFonts.dmMono(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _tabBtn(String id, String label, IconData icon) {
    final active = _tab == id;
    return GestureDetector(
      onTap: () => setState(() => _tab = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.adminLimeDim : AppColors.adminSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? AppColors.adminLime : AppColors.adminBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: active ? AppColors.adminLime : AppColors.adminMuted),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.w400, color: active ? AppColors.adminLime : AppColors.adminMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildOverview() {
    return Column(
      children: [
        // Chart + info cards
        LayoutBuilder(builder: (_, constraints) {
          final wide = constraints.maxWidth > 700;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: wide ? 3 : 1,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.adminSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.adminBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('EVOLUÇÃO DE PESO (7 DIAS)',
                          style: GoogleFonts.barlowCondensed(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.03, color: AppColors.adminText)),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 180,
                        child: LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: false),
                            titlesData: const FlTitlesData(show: false),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: [0, 1, 2, 3, 4, 5, 6].asMap().entries.map((e) => FlSpot(e.key.toDouble(), [80.0, 80.5, 81.0, 81.8, 82.0, 82.3, 82.0][e.key])).toList(),
                                isCurved: true,
                                color: AppColors.adminLime,
                                barWidth: 2,
                                dotData: FlDotData(show: true, getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(radius: 3, color: AppColors.adminLime, strokeWidth: 0)),
                                belowBarData: BarAreaData(show: true, color: AppColors.adminLime.withValues(alpha: 0.08)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (wide) ...[
                const SizedBox(width: 20),
                SizedBox(
                  width: 280,
                  child: Column(
                    children: [_workoutSummary(), const SizedBox(height: 16), _nutritionSummary()],
                  ),
                ),
              ],
            ],
          );
        }),
      ],
    );
  }

  Widget _workoutSummary() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.adminSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.adminBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PLANO DE TREINO', style: GoogleFonts.barlowCondensed(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.05, color: AppColors.adminMuted)),
          const SizedBox(height: 10),
          Text('Hipertrofia ABC', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.adminText)),
          Text('3 dias por semana', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.adminMuted)),
          const SizedBox(height: 10),
          ...['Segunda - Peito + Tríceps', 'Quarta - Costas + Bíceps', 'Sexta - Pernas + Ombros'].map((d) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: d.split(' - ').map((t) => Text(t, style: GoogleFonts.dmSans(fontSize: 12, color: t.contains('-') ? AppColors.adminText : AppColors.adminMuted))).toList(),
                ),
              )),
        ],
      ),
    );
  }

  Widget _nutritionSummary() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.adminSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.adminBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NUTRIÇÃO DIÁRIA', style: GoogleFonts.barlowCondensed(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.05, color: AppColors.adminMuted)),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (_, __) {
            final macros = [
              ('Calorias', '2800 kcal', AppColors.adminOrange),
              ('Proteína', '180g', AppColors.adminBlue),
              ('Carboidrato', '320g', AppColors.adminLime),
              ('Gordura', '75g', AppColors.adminPurple),
            ];
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: macros.map((m) => SizedBox(
                    width: 120,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.adminBg, borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.$1.toUpperCase(), style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.adminMuted)),
                          Text(m.$2, style: GoogleFonts.dmMono(fontSize: 14, fontWeight: FontWeight.w600, color: m.$3)),
                        ],
                      ),
                    ),
                  )).toList(),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWorkout() {
    return Container(
      decoration: BoxDecoration(color: AppColors.adminSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.adminBorder)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.adminLimeDim, border: const Border(bottom: BorderSide(color: AppColors.adminBorder))),
            child: Row(
              children: [
                Text('SEGUNDA — PEITO + TRÍCEPS',
                    style: GoogleFonts.barlowCondensed(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 0.04, color: AppColors.adminLime)),
              ],
            ),
          ),
          ...[
            ('01', 'Supino Reto', 'Peito · Barra', '4x', '8-10', '90s'),
            ('02', 'Crucifixo', 'Peito · Halter', '3x', '12-15', '60s'),
            ('03', 'Tríceps Corda', 'Tríceps · Polia', '4x', '10-12', '60s'),
          ].map((e) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.adminBorder))),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(e.$1, style: GoogleFonts.barlowCondensed(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.adminLime.withValues(alpha: 0.2))),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.$2, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.adminText)),
                          Text(e.$3, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.adminMuted)),
                        ],
                      ),
                    ),
                    _exStat('SÉRIES', e.$4),
                    const SizedBox(width: 16),
                    _exStat('REPS', e.$5),
                    const SizedBox(width: 16),
                    _exStat('DESCANSO', e.$6),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _exStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 9, color: AppColors.adminMuted, letterSpacing: 0.08)),
        Text(value, style: GoogleFonts.dmMono(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.adminText)),
      ],
    );
  }

  Widget _buildNutrition() {
    return Column(
      children: [
        // Macro cards
        LayoutBuilder(builder: (_, constraints) {
          final macros = [
            ('Calorias Totais', '2800', 'kcal', AppColors.adminOrange, 100),
            ('Proteína', '180', 'g/dia', AppColors.adminBlue, 26.0),
            ('Carboidrato', '320', 'g/dia', AppColors.adminLime, 46.0),
            ('Gordura', '75', 'g/dia', AppColors.adminPurple, 24.0),
          ];
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: macros.map((m) {
              final w = constraints.maxWidth > 800 ? (constraints.maxWidth - 42) / 4 : (constraints.maxWidth - 14) / 2;
              return SizedBox(
                width: w,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: AppColors.adminSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.adminBorder)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.$1.toUpperCase(), style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.adminMuted, letterSpacing: 0.06)),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(m.$2, style: GoogleFonts.barlowCondensed(fontSize: 36, fontWeight: FontWeight.w900, color: m.$4, height: 1)),
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(m.$3, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.adminMuted)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: m.$5 / 100,
                          backgroundColor: AppColors.adminSurface2,
                          valueColor: AlwaysStoppedAnimation(m.$4),
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('${m.$5}% das calorias', style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.adminMuted)),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }
}

// ─── Exercise Library View ────────────────────────────────────────

class _AdminExerciseLibrary extends StatefulWidget {
  @override
  State<_AdminExerciseLibrary> createState() => _AdminExerciseLibraryState();
}

class _AdminExerciseLibraryState extends State<_AdminExerciseLibrary> {
  String _search = '';
  String _muscle = 'Todos';

  static const _exercises = [
    ('Supino Reto', 'Peito', 'Barra', 'intermediate'),
    ('Agachamento Livre', 'Quadríceps', 'Barra', 'advanced'),
    ('Levantamento Terra', 'Posterior', 'Barra', 'advanced'),
    ('Puxada Frontal', 'Costas', 'Polia', 'beginner'),
    ('Desenvolvimento', 'Ombros', 'Halter', 'intermediate'),
    ('Rosca Direta', 'Bíceps', 'Barra', 'beginner'),
    ('Tríceps Corda', 'Tríceps', 'Polia', 'beginner'),
    ('Leg Press 45°', 'Quadríceps', 'Máquina', 'beginner'),
    ('Remada Curvada', 'Costas', 'Barra', 'intermediate'),
    ('Crucifixo', 'Peito', 'Halter', 'beginner'),
  ];

  static const _muscles = ['Todos', 'Peito', 'Costas', 'Quadríceps', 'Posterior', 'Ombros', 'Bíceps', 'Tríceps', 'Core'];
  static const _diffLabels = {'beginner': 'Iniciante', 'intermediate': 'Intermediário', 'advanced': 'Avançado'};
  static const _diffColors = {'beginner': AppColors.adminLime, 'intermediate': AppColors.adminOrange, 'advanced': AppColors.adminDanger};

  @override
  Widget build(BuildContext context) {
    final filtered = _exercises.where((e) {
      final matchSearch = e.$1.toLowerCase().contains(_search.toLowerCase()) || e.$3.toLowerCase().contains(_search.toLowerCase());
      final matchMuscle = _muscle == 'Todos' || e.$2 == _muscle;
      return matchSearch && matchMuscle;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BIBLIOTECA DE EXERCÍCIOS', style: _adminDisplay(40)),
          Text('${_exercises.length} exercícios cadastrados', style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.adminMuted)),
          const SizedBox(height: 24),
          // Search
          SizedBox(
            width: 360,
            height: 40,
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.adminText),
              decoration: InputDecoration(
                hintText: 'Buscar exercício ou equipamento...',
                hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.adminMuted),
                prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.adminMuted),
                filled: true, fillColor: AppColors.adminSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.adminBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.adminBorder)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Muscle filters
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _muscles.map((m) {
              final active = _muscle == m;
              return GestureDetector(
                onTap: () => setState(() => _muscle = m),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? AppColors.adminLimeDim : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: active ? AppColors.adminLime : AppColors.adminBorder),
                  ),
                  child: Text(m, style: GoogleFonts.dmSans(fontSize: 12, color: active ? AppColors.adminLime : AppColors.adminMuted)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          // Grid
          LayoutBuilder(builder: (_, constraints) {
            final cols = constraints.maxWidth > 700 ? 3 : (constraints.maxWidth > 400 ? 2 : 1);
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: filtered.asMap().entries.map((entry) {
                final i = entry.key;
                final e = entry.value;
                final w = (constraints.maxWidth - 14 * (cols - 1)) / cols;
                return SizedBox(
                  width: w,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: AppColors.adminSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.adminBorder)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${(i + 1).toString().padLeft(2, '0')}',
                                style: GoogleFonts.barlowCondensed(fontSize: 48, fontWeight: FontWeight.w900, color: AppColors.adminText.withValues(alpha: 0.04), height: 1)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: _diffColors[e.$4]!.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(_diffLabels[e.$4]!.toUpperCase(),
                                  style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: _diffColors[e.$4], letterSpacing: 0.06)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(e.$1, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.adminText)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _exChip(e.$2, AppColors.adminBlue),
                            const SizedBox(width: 6),
                            _exChip(e.$3, AppColors.adminMuted),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  Widget _exChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: color)),
    );
  }
}

// ─── Shared Helpers ───────────────────────────────────────────────

TextStyle _adminDisplay(double size) {
  return GoogleFonts.barlowCondensed(
    fontSize: size, fontWeight: FontWeight.w900, letterSpacing: -0.01, color: AppColors.adminText,
  );
}
