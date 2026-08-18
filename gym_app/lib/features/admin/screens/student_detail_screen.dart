import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/config/admin_theme.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/config/app_strings.dart';
import '../../../../core/utils/storage_resource.dart';
import '../../../../data/models/user_model.dart';
import '../../../../shared/providers/admin_providers.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/app_page_frame.dart';
import '../widgets/report_generator.dart';
import '../../aluno/chat/screens/chat_screen.dart';
import '../../aluno/perfil/screens/video_progress_screen.dart';

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

  final tabs = const ['Resumo', 'Progresso', 'Vídeos', 'Chat'];

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

    final adminColors = AdminThemeColors.of(context);

    return Scaffold(
      backgroundColor: adminColors.bg,
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
          labelColor: adminColors.lime,
          unselectedLabelColor: adminColors.muted,
          indicatorColor: adminColors.lime,
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
          _buildProgresso(aluno),
          VideoProgressScreen(userId: aluno.uid, isAdmin: true, student: aluno),
          ChatScreen(
            trackChatPresence: false,
            chatPartnerId: aluno.uid,
            chatPartnerName: aluno.nome,
            chatPartnerPhoto: aluno.fotoPerfil,
            key: ValueKey('chat_${aluno.uid}'),
          ),
        ],
      ),
    );
  }

  Widget _buildResumo(UserModel aluno) {
    final initials = aluno.nome.trim().isEmpty
        ? '?'
        : aluno.nome.trim()[0].toUpperCase();
    final imc = aluno.imc;
    final adminColors = AdminThemeColors.of(context);

    return AppPageFrame(
      maxWidth: 1100,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: ListView(
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 560;
                  final identity = Row(
                    children: [
                      StorageAvatar(
                        resource: aluno.fotoPerfil,
                        radius: 30,
                        backgroundColor: adminColors.lime.withValues(alpha: 0.14),
                        fallback: Text(
                          initials,
                          style: GoogleFonts.montserrat(
                            color: adminColors.lime,
                            fontSize: 22,
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
                              aluno.nome,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              aluno.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );

                  final status = Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: aluno.hasPendingProgress
                          ? AppColors.warning.withValues(alpha: 0.12)
                          : adminColors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: aluno.hasPendingProgress
                            ? AppColors.warning.withValues(alpha: 0.3)
                            : adminColors.green.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          aluno.hasPendingProgress
                              ? Icons.pending_actions_outlined
                              : Icons.check_circle_outline,
                          size: 16,
                          color: aluno.hasPendingProgress
                              ? AppColors.warning
                              : adminColors.green,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          aluno.hasPendingProgress
                              ? 'Progresso pendente'
                              : 'Acompanhamento em dia',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: aluno.hasPendingProgress
                                ? AppColors.warning
                                : adminColors.green,
                          ),
                        ),
                      ],
                    ),
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [identity, const SizedBox(height: 16), status],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: identity),
                      const SizedBox(width: 16),
                      status,
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 760 ? 4 : 2;
              final spacing = 12.0;
              final itemWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  _summaryMetric(
                    width: itemWidth,
                    icon: Icons.monitor_weight_outlined,
                    label: 'Peso atual',
                    value: aluno.pesoAtual == null
                        ? '—'
                        : '${aluno.pesoAtual!.toStringAsFixed(1)} kg',
                  ),
                  _summaryMetric(
                    width: itemWidth,
                    icon: Icons.height,
                    label: 'Altura',
                    value: aluno.altura == null
                        ? '—'
                        : '${aluno.altura!.toStringAsFixed(0)} cm',
                  ),
                  _summaryMetric(
                    width: itemWidth,
                    icon: Icons.insights_outlined,
                    label: 'IMC',
                    value: imc == null ? '—' : imc.toStringAsFixed(1),
                    caption: aluno.imcCategory,
                  ),
                  _summaryMetric(
                    width: itemWidth,
                    icon: Icons.calendar_today_outlined,
                    label: 'Última atividade',
                    value: aluno.ultimaAtividade == null
                        ? 'Sem registo'
                        : DateFormat(
                            'dd/MM/yyyy',
                          ).format(aluno.ultimaAtividade!),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informação do cliente',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _summaryInfoRow(
                    Icons.fitness_center_outlined,
                    'Modalidade',
                    aluno.tipoClienteDisplay,
                  ),
                  const SizedBox(height: 12),
                  _summaryInfoRow(
                    Icons.person_outline,
                    'Género',
                    aluno.generoDisplay,
                  ),
                  const SizedBox(height: 12),
                  _summaryInfoRow(
                    Icons.email_outlined,
                    'Contacto',
                    aluno.email,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryMetric({
    required double width,
    required IconData icon,
    required String label,
    required String value,
    String? caption,
  }) {
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AdminThemeColors.of(context).lime, size: 20),
              const SizedBox(height: 14),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AdminThemeColors.of(context).muted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AdminThemeColors.of(context).text,
                ),
              ),
              if (caption != null) ...[
                const SizedBox(height: 3),
                Text(
                  caption,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AdminThemeColors.of(context).muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 19, color: AdminThemeColors.of(context).lime),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AdminThemeColors.of(context).muted,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AdminThemeColors.of(context).text,
            ),
          ),
        ),
      ],
    );
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
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AdminThemeColors.of(context).border),
              ),
              child: Material(
                color: AdminThemeColors.of(context).surface,
                borderRadius: BorderRadius.circular(16),
                child: ListTile(
                  title: Text(
                    DateFormat(AppConstants.displayDateFormat).format(p.data),
                    style: GoogleFonts.inter(
                      color: AdminThemeColors.of(context).text,
                    ),
                  ),
                  subtitle: p.peso != null
                      ? Text(
                          '${p.peso} kg',
                          style: GoogleFonts.inter(
                            color: AdminThemeColors.of(context).muted,
                          ),
                        )
                      : null,
                  trailing: p.fotos.isNotEmpty
                      ? Icon(
                          Icons.photo,
                          color: AdminThemeColors.of(context).lime,
                        )
                      : null,
                ),
              ),
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
          'Erro ao carregar dados',
          style: TextStyle(color: AdminThemeColors.of(context).muted),
        ),
      ),
    );
  }

  Future<void> _exportPDF(UserModel aluno) async {
    final generator = ReportGenerator(ref: ref, aluno: aluno);
    await generator.generatePDF(context);
  }
}
