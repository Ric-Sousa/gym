import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/config/app_strings.dart';
import '../../../../data/models/user_model.dart';
import '../../../../shared/providers/admin_providers.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../widgets/nutrition_editor.dart';
import '../widgets/workout_editor.dart';
import '../widgets/report_generator.dart';
import '../../aluno/chat/screens/chat_screen.dart';

/// Ecrã de detalhe do aluno (admin) — Kinetic Dark.
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          aluno.nome,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
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
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
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
            trackChatPresence: false,
              chatPartnerId: aluno.uid,
              chatPartnerName: aluno.nome,
              chatPartnerPhoto: aluno.fotoPerfil,
              key: ValueKey('chat_${aluno.uid}')),
        ],
      ),
    );
  }

  Widget _buildResumo(UserModel aluno) {
    return Center(
      child: Text(
        'Dashboard do aluno (admin)',
        style: GoogleFonts.inter(color: AppColors.textSecondary),
      ),
    );
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
          padding: const EdgeInsets.all(20),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final p = list[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.outline),
              ),
              child: Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                child: ListTile(
                  title: Text(
                    DateFormat(AppConstants.displayDateFormat).format(p.data),
                    style: GoogleFonts.inter(color: AppColors.onSurface),
                  ),
                  subtitle: p.peso != null
                      ? Text(
                          '${p.peso} kg',
                          style: GoogleFonts.inter(color: AppColors.textSecondary),
                        )
                      : null,
                  trailing: p.fotos.isNotEmpty
                      ? const Icon(Icons.photo, color: AppColors.primary)
                      : null,
                ),
              ),
            );
          },
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (_, __) => const Center(
        child: Text('Erro ao carregar dados',
            style: TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }

  Future<void> _exportPDF(UserModel aluno) async {
    final generator = ReportGenerator(ref: ref, aluno: aluno);
    await generator.generatePDF(context);
  }
}
