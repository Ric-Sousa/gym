import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/config/app_strings.dart';
import '../../../../data/models/user_model.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../shared/providers/global_providers.dart';
import '../../../../shared/providers/admin_providers.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../widgets/nutrition_editor.dart';
import '../widgets/workout_editor.dart';
import '../widgets/report_generator.dart';
import '../../aluno/chat/screens/chat_screen.dart';

/// Ecrã de detalhe do aluno (admin).
class StudentDetailScreen extends ConsumerStatefulWidget {
  final UserModel aluno;
  const StudentDetailScreen({super.key, required this.aluno});

  @override
  ConsumerState<StudentDetailScreen> createState() =>
      _StudentDetailScreenState();
}

class _StudentDetailScreenState extends ConsumerState<StudentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final tabs = const [
    'Resumo',
    'Nutrição',
    'Treino',
    'Progresso',
    'Chat',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aluno = widget.aluno;

    return Scaffold(
      appBar: AppBar(
        title: Text(aluno.nome),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => _exportPDF(aluno),
            tooltip: AppStrings.exportReport,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: tabs.map((t) => Tab(text: t)).toList(),
          labelColor: AppColors.textOnPrimary,
          unselectedLabelColor: AppColors.textOnPrimary.withValues(alpha: 0.7),
          indicatorColor: Colors.white,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildResumo(aluno),
          _buildNutricao(aluno),
          _buildTreino(aluno),
          _buildProgresso(aluno),
          ChatScreen(
              chatPartnerId: aluno.uid,
              key: ValueKey('chat_${aluno.uid}')),
        ],
      ),
    );
  }

  Widget _buildResumo(UserModel aluno) {
    return const Center(child: Text('Dashboard do aluno (admin)'));
  }

  Widget _buildNutricao(UserModel aluno) {
    return NutritionEditor(aluno: aluno);
  }

  Widget _buildTreino(UserModel aluno) {
    return WorkoutEditor(aluno: aluno);
  }

  Widget _buildProgresso(UserModel aluno) {
    final progressAsync = ref.watch(adminProgressProvider(aluno.uid));

    return progressAsync.when(
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.show_chart,
            title: AppStrings.noProgressData,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final p = list[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  DateFormat(AppConstants.displayDateFormat).format(p.data),
                ),
                subtitle: p.peso != null ? Text('${p.peso} kg') : null,
                trailing: p.fotos.isNotEmpty
                    ? const Icon(Icons.photo, color: AppColors.primary)
                    : null,
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Erro ao carregar dados')),
    );
  }

  Future<void> _exportPDF(UserModel aluno) async {
    final generator = ReportGenerator(ref: ref, aluno: aluno);
    await generator.generatePDF(context);
  }
}
