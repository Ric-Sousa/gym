import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:typed_data';
import '../../../../core/config/app_colors.dart';
import '../../../../core/config/student_theme.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/config/app_strings.dart';
import '../../../../data/models/progress_model.dart';
import '../../../../data/models/payment_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../shared/providers/global_providers.dart';
import '../../../../shared/widgets/app_notification.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/config/notification_sounds.dart';
import '../../../../core/utils/progress_photo_normalizer.dart';
import '../../../../core/utils/progress_photo_resolver.dart';
import '../../../../shared/widgets/image_comparison_slider.dart';
import 'progress_submission_screen.dart';
import 'video_progress_screen.dart';

final userProfileProvider = StreamProvider.family<UserModel, String>((
  ref,
  uid,
) {
  return ref.read(userRepositoryProvider).userStream(uid);
});

final progressHistoryProvider =
    StreamProvider.family<List<ProgressModel>, String>((ref, userId) {
  return ref.read(progressRepositoryProvider).watchHistory(userId);
});

/// Ecrã de perfil — Kinetic Dark.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _picker = ImagePicker();
  Timer? _previewRestoreTimer;
  String? _selectedBeforeProgressKey;
  String? _selectedAfterProgressKey;
  int _selectedAngle = 0;
  String? _angleFeedback;
  String? _paymentLoadingId;

  // A resolução das fotos por ângulo (mapa explícito e fallback legado)
  // está em core/utils/progress_photo_resolver.dart.
  static const _progressAngles = progressAngleLabels;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userId = authState.user?.uid ?? '';
    final userAsync = ref.watch(userProfileProvider(userId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          AppStrings.profile,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).signOut(),
            tooltip: AppStrings.logout,
          ),
        ],
      ),
      body: userAsync.when(
        data: (user) {
          // Configura o som de notificação com a preferência do utilizador
          SoundService().setSound(user.notificationSound ?? defaultSoundAsset);
          return Column(
            children: [Expanded(child: _buildProfileContent(user))],
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(
            color: StudentThemeColors.of(context).primary,
          ),
        ),
        error: (_, __) => const Center(
          child: Text(
            'Erro ao carregar perfil',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileContent(UserModel user) {
    final progressAsync = ref.watch(progressHistoryProvider(user.uid));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(userProfileProvider(user.uid));
        ref.invalidate(progressHistoryProvider(user.uid));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildProfileHeader(user),
            if (user.hasPendingProgress) _buildPendingProgressBanner(user),
            const SizedBox(height: 24),
            // Ordem principal do perfil: informações, comparação e som.
            _buildEditableFields(user),
            const SizedBox(height: 20),
            _buildProgressComparisonCard(user, progressAsync),
            const SizedBox(height: 20),
            _buildSoundPicker(user),
            if (user.isOnline) ...[
              const SizedBox(height: 20),
              _buildVideoProgressEntry(user),
            ],
            const SizedBox(height: 24),
            _buildPaymentsSection(user.uid),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingProgressBanner(UserModel user) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              StudentThemeColors.of(context).primary,
              Color.lerp(
                StudentThemeColors.of(context).primary,
                Colors.black,
                0.35,
              )!,
            ],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 430;
            final info = Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Avaliação Pendente!',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'O teu personal trainer pediu a tua avaliação mensal.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
            final submitButton = ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProgressSubmissionScreen(
                      onSubmitComplete: () {
                        ref.invalidate(userProfileProvider(user.uid));
                        ref.invalidate(progressHistoryProvider(user.uid));
                      },
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: StudentThemeColors.of(context).primary,
                minimumSize: const Size(0, 50),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              child: Text(
                'Submeter',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  info,
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: submitButton),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: info),
                const SizedBox(width: 12),
                submitButton,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileHeader(UserModel user) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: StudentThemeColors.of(
            context,
          ).primary.withValues(alpha: 0.15),
          backgroundImage: user.fotoPerfil != null
              ? NetworkImage(user.fotoPerfil!)
              : null,
          child: user.fotoPerfil == null
              ? Text(
                  user.nome.isNotEmpty ? user.nome[0].toUpperCase() : '?',
                  style: GoogleFonts.montserrat(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: StudentThemeColors.of(context).primary,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          user.nome,
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          user.email,
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickMetrics(UserModel user) {
    final metrics = [
      (
        label: 'Peso',
        value: user.pesoAtual != null ? '${user.pesoAtual} kg' : '--',
        icon: Icons.monitor_weight,
      ),
      (
        label: 'Altura',
        value: user.altura != null ? '${user.altura} cm' : '--',
        icon: Icons.height,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 2;
        final gap = 12.0;
        final itemWidth = columns == 2
            ? (constraints.maxWidth - gap) / columns
            : (constraints.maxWidth - (gap * 2)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: itemWidth,
                child: _metricCard(metric.label, metric.value, metric.icon),
              ),
          ],
        );
      },
    );
  }

  Widget _metricCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          Icon(icon, color: StudentThemeColors.of(context).primary, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableFields(UserModel user) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Informações',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _editProfile(user),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Editar'),
                ),
              ],
            ),
            const Divider(color: AppColors.outline),
            _buildQuickMetrics(user),
            const SizedBox(height: 14),
            _infoRow('Nome', user.nome),
            _infoRow('E-mail', user.email),
            _infoRow('Género', user.generoDisplay),
            _infoRow(
              'Peso',
              user.pesoAtual != null ? '${user.pesoAtual} kg' : 'Não definido',
            ),
            _infoRow(
              'Altura',
              user.altura != null ? '${user.altura} cm' : 'Não definida',
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                color: AppColors.onSurface,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Compara a foto inicial com a última foto de progresso diretamente no
  /// perfil. O comparador fica sempre visível, sem depender de um modal ou de
  /// uma ação extra do aluno.
  Widget _buildProgressComparisonCard(
    UserModel user,
    AsyncValue<List<ProgressModel>> progressAsync,
  ) {
    return progressAsync.when(
      loading: _buildProgressComparisonLoading,
      error: (_, __) => _buildProgressComparisonState(
        icon: Icons.sync_problem_outlined,
        message: 'Não foi possível carregar a comparação agora.',
        actionLabel: 'Tentar novamente',
        onAction: () => ref.invalidate(progressHistoryProvider(user.uid)),
      ),
      data: (progressList) {
        final withPhotos =
            progressList
                .where(
                  (progress) => hasAnyProgressPhoto(
                    progress.fotos,
                    progress.fotosPorPosicao,
                  ),
                )
                .toList()
              ..sort((a, b) => a.data.compareTo(b.data));

        if (withPhotos.length < 2) {
          return _buildProgressComparisonState(
            icon: Icons.photo_camera_back_outlined,
            message:
                'Envia pelo menos duas fotos de progresso para poderes escolher as datas da comparação.',
          );
        }

        // Par inicial: a maior amplitude de datas que partilha pelo menos um
        // ângulo. Evita abrir o comparador num estado de erro quando os
        // registos antigos não têm todos os ângulos.
        final bestPair = _bestComparisonPair(withPhotos);
        final defaultBeforeKey = _progressKey(bestPair.before);
        final defaultAfterKey = _progressKey(bestPair.after);
        final beforeProgress =
            _progressByKey(withPhotos, _selectedBeforeProgressKey) ??
            bestPair.before;
        final afterProgress =
            _progressByKey(withPhotos, _selectedAfterProgressKey) ??
            bestPair.after;

        _queueProgressSelectionSync(
          options: withPhotos,
          defaultBeforeKey: defaultBeforeKey,
          defaultAfterKey: defaultAfterKey,
        );

        final selectedAngle = _safeSharedAngleIndex(
          beforeProgress,
          afterProgress,
          _selectedAngle,
        );
        final beforeImage = _photoAt(beforeProgress, selectedAngle);
        final afterImage = _photoAt(afterProgress, selectedAngle);
        final isSameSelection =
            _progressKey(beforeProgress) == _progressKey(afterProgress);

        // Os dropdowns ficam sempre visíveis — mesmo quando o par escolhido
        // não tem um ângulo em comum ou é a mesma data — para o aluno nunca
        // ficar preso num estado sem ação.
        return _buildInlineProgressComparison(
          progressOptions: withPhotos,
          beforeProgress: beforeProgress,
          afterProgress: afterProgress,
          beforeImage: beforeImage,
          afterImage: afterImage,
          beforeDate: DateFormat('dd/MM/yyyy').format(beforeProgress.data),
          afterDate: DateFormat('dd/MM/yyyy').format(afterProgress.data),
          beforeDetail: null,
          afterDetail: null,
          selectedAngle: selectedAngle,
          showSelectionError: isSameSelection,
        );
      },
    );
  }

  int _safeSharedAngleIndex(
    ProgressModel before,
    ProgressModel after,
    int preferred,
  ) {
    if (_angleAvailable(before, after, preferred)) return preferred;
    for (var index = 0; index < _progressAngles.length; index++) {
      if (_angleAvailable(before, after, index)) return index;
    }
    return 0;
  }

  bool _angleAvailable(
    ProgressModel before,
    ProgressModel after,
    int angleIndex,
  ) {
    return _photoAt(before, angleIndex) != null &&
        _photoAt(after, angleIndex) != null;
  }

  String? _photoAt(ProgressModel progress, int angleIndex) {
    return resolveProgressPhotoAt(
      fotos: progress.fotos,
      fotosPorPosicao: progress.fotosPorPosicao,
      angleIndex: angleIndex,
    );
  }

  /// Escolhe o par (antes, depois) com a maior amplitude de datas que
  /// partilha pelo menos um ângulo. Sem par válido, devolve o primeiro e o
  /// último registo — a UI trata desse caso com uma mensagem e ações.
  ({ProgressModel before, ProgressModel after}) _bestComparisonPair(
    List<ProgressModel> sortedOptions,
  ) {
    for (
      var afterIndex = sortedOptions.length - 1;
      afterIndex > 0;
      afterIndex--
    ) {
      for (var beforeIndex = 0; beforeIndex < afterIndex; beforeIndex++) {
        if (_sharesAnyAngle(
          sortedOptions[beforeIndex],
          sortedOptions[afterIndex],
        )) {
          return (
            before: sortedOptions[beforeIndex],
            after: sortedOptions[afterIndex],
          );
        }
      }
    }
    return (before: sortedOptions.first, after: sortedOptions.last);
  }

  bool _sharesAnyAngle(ProgressModel before, ProgressModel after) {
    for (var index = 0; index < _progressAngles.length; index++) {
      if (_angleAvailable(before, after, index)) return true;
    }
    return false;
  }

  String _progressKey(ProgressModel progress) {
    return '${progress.id}|${progress.data.microsecondsSinceEpoch}';
  }

  ProgressModel? _progressByKey(List<ProgressModel> progressList, String? key) {
    if (key == null) return null;
    for (final progress in progressList) {
      if (_progressKey(progress) == key) return progress;
    }
    return null;
  }

  void _queueProgressSelectionSync({
    required List<ProgressModel> options,
    required String defaultBeforeKey,
    required String defaultAfterKey,
  }) {
    final currentBefore = _progressByKey(options, _selectedBeforeProgressKey);
    final currentAfter = _progressByKey(options, _selectedAfterProgressKey);
    final nextBeforeKey = currentBefore == null
        ? defaultBeforeKey
        : _selectedBeforeProgressKey!;
    final nextAfterKey = currentAfter == null
        ? defaultAfterKey
        : _selectedAfterProgressKey!;

    if (_selectedBeforeProgressKey == nextBeforeKey &&
        _selectedAfterProgressKey == nextAfterKey) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_selectedBeforeProgressKey == nextBeforeKey &&
          _selectedAfterProgressKey == nextAfterKey) {
        return;
      }
      setState(() {
        _selectedBeforeProgressKey = nextBeforeKey;
        _selectedAfterProgressKey = nextAfterKey;
        _angleFeedback = null;
      });
    });
  }

  void _selectComparisonDates({
    required String beforeKey,
    required String afterKey,
  }) {
    // Os valores são validados pelas opções dos dois seletores antes do callback.
    // A atualização local faz o slider reagir imediatamente.
    setState(() {
      _selectedBeforeProgressKey = beforeKey;
      _selectedAfterProgressKey = afterKey;
      _angleFeedback = null;
    });
  }

  /// Os botões de ângulo estão sempre clicáveis: um ângulo disponível é
  /// selecionado; um ângulo indisponível explica o que falta e em que data,
  /// em vez de ficar "morto" sem resposta ao toque.
  void _onAngleTapped(
    int index, {
    required ProgressModel beforeProgress,
    required ProgressModel afterProgress,
  }) {
    if (_angleAvailable(beforeProgress, afterProgress, index)) {
      setState(() {
        _selectedAngle = index;
        _angleFeedback = null;
      });
      return;
    }

    final angle = _progressAngles[index];
    final hasBefore = _photoAt(beforeProgress, index) != null;
    final hasAfter = _photoAt(afterProgress, index) != null;
    final dateFormat = DateFormat('dd/MM/yyyy');

    final String feedback;
    if (!hasBefore && !hasAfter) {
      feedback = 'Nenhuma das datas selecionadas tem foto de $angle.';
    } else if (!hasBefore) {
      feedback =
          'Sem foto de $angle na data inicial '
          '(${dateFormat.format(beforeProgress.data)}).';
    } else {
      feedback =
          'Sem foto de $angle na data final '
          '(${dateFormat.format(afterProgress.data)}).';
    }

    setState(() => _angleFeedback = feedback);
  }

  Widget _buildProgressComparisonLoading() {
    return _buildProgressComparisonShell(
      child: SizedBox(
        height: 260,
        child: Center(
          child: CircularProgressIndicator(
            color: StudentThemeColors.of(context).primary,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressComparisonState({
    required IconData icon,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return _buildProgressComparisonShell(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          children: [
            Icon(icon, size: 34, color: AppColors.textSecondary),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: StudentThemeColors.of(context).primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  minimumSize: const Size(0, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  actionLabel,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInlineProgressComparison({
    required List<ProgressModel> progressOptions,
    required ProgressModel beforeProgress,
    required ProgressModel afterProgress,
    required String? beforeImage,
    required String? afterImage,
    required String beforeDate,
    required String? afterDate,
    required String? beforeDetail,
    required String? afterDetail,
    required int selectedAngle,
    bool showSelectionError = false,
  }) {
    final beforeKey = _progressKey(beforeProgress);
    final afterKey = _progressKey(afterProgress);
    final beforeOptions = progressOptions
        .where((progress) => !progress.data.isAfter(afterProgress.data))
        .toList();
    final afterOptions = progressOptions
        .where((progress) => !progress.data.isBefore(beforeProgress.data))
        .toList();

    return _buildProgressComparisonShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 460;
              final selectors = [
                _comparisonDateDropdown(
                  label: 'Data inicial',
                  selectedKey: beforeKey,
                  options: beforeOptions,
                  onChanged: (key) {
                    if (key == null) return;
                    final selected = _progressByKey(progressOptions, key);
                    if (selected == null) return;
                    var nextAfterKey = _selectedAfterProgressKey ?? afterKey;
                    final currentAfter = _progressByKey(
                      progressOptions,
                      nextAfterKey,
                    );
                    if (currentAfter == null ||
                        selected.data.isAfter(currentAfter.data)) {
                      nextAfterKey = _progressKey(progressOptions.last);
                    }
                    _selectComparisonDates(
                      beforeKey: key,
                      afterKey: nextAfterKey,
                    );
                  },
                ),
                _comparisonDateDropdown(
                  label: 'Data final',
                  selectedKey: afterKey,
                  options: afterOptions,
                  onChanged: (key) {
                    if (key == null) return;
                    final selected = _progressByKey(progressOptions, key);
                    if (selected == null) return;
                    var nextBeforeKey = _selectedBeforeProgressKey ?? beforeKey;
                    final currentBefore = _progressByKey(
                      progressOptions,
                      nextBeforeKey,
                    );
                    if (currentBefore == null ||
                        selected.data.isBefore(currentBefore.data)) {
                      nextBeforeKey = _progressKey(progressOptions.first);
                    }
                    _selectComparisonDates(
                      beforeKey: nextBeforeKey,
                      afterKey: key,
                    );
                  },
                ),
              ];
              final angleSelector = _comparisonAngleButtons(
                selectedIndex: selectedAngle,
                beforeProgress: beforeProgress,
                afterProgress: afterProgress,
                feedback: _angleFeedback,
                onChanged: (index) {
                  _onAngleTapped(
                    index,
                    beforeProgress: beforeProgress,
                    afterProgress: afterProgress,
                  );
                },
              );
              final dateRow = compact
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
                children: [dateRow, const SizedBox(height: 10), angleSelector],
              );
            },
          ),
          const SizedBox(height: 14),
          if (showSelectionError) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.20),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.error,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Escolhe duas datas diferentes para comparar.',
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final bestPair = _bestComparisonPair(progressOptions);
                      _selectComparisonDates(
                        beforeKey: _progressKey(bestPair.before),
                        afterKey: _progressKey(bestPair.after),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: StudentThemeColors.of(context).primary,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Corrigir'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (beforeImage != null && afterImage != null)
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                // As novas fotos são normalizadas para 4:5. O painel usa a
                // mesma proporção para que a imagem ocupe toda a largura sem
                // barras laterais, blur, distorção ou recorte.
                final height = (width * 1.25 + 52)
                    .clamp(320.0, 760.0)
                    .toDouble();
                return ImageComparisonSlider(
                  beforeImage: beforeImage,
                  afterImage: afterImage,
                  width: width,
                  height: height,
                  dividerColor: StudentThemeColors.of(context).primary,
                  imageFit: BoxFit.cover,
                  edgeToEdge: true,
                  beforeLabel: '',
                  afterLabel: '',
                  beforeDate: beforeDate,
                  afterDate: afterDate,
                  beforeDetail: beforeDetail,
                  afterDetail: afterDetail,
                  cardColor: AppColors.surfaceHigh,
                );
              },
            )
          else
            _buildNoSharedAnglePanel(progressOptions),
        ],
      ),
    );
  }

  /// Mostrado no lugar do slider quando as datas escolhidas não partilham
  /// nenhum ângulo. Mantém uma ação disponível para o aluno nunca ficar
  /// preso: escolher automaticamente o melhor par de datas.
  Widget _buildNoSharedAnglePanel(List<ProgressModel> progressOptions) {
    final bestPair = _bestComparisonPair(progressOptions);
    final canAutoSelect =
        _progressKey(bestPair.before) != _progressKey(bestPair.after) &&
        _sharesAnyAngle(bestPair.before, bestPair.after);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.photo_library_outlined,
            size: 30,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 10),
          Text(
            'As fotos destas datas não têm um ângulo em comum para comparar.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (canAutoSelect) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                _selectComparisonDates(
                  beforeKey: _progressKey(bestPair.before),
                  afterKey: _progressKey(bestPair.after),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: StudentThemeColors.of(context).primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                minimumSize: const Size(0, 40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Escolher datas automaticamente',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _comparisonAngleButtons({
    required int selectedIndex,
    required ProgressModel beforeProgress,
    required ProgressModel afterProgress,
    required ValueChanged<int> onChanged,
    String? feedback,
  }) {
    final availability = [
      for (var index = 0; index < _progressAngles.length; index++)
        _angleAvailable(beforeProgress, afterProgress, index),
    ];
    final anyUnavailable = availability.any((available) => !available);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ângulo',
          style: GoogleFonts.inter(
            color: AppColors.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < _progressAngles.length; index++) ...[
                _angleButton(
                  label: _progressAngles[index],
                  selected: selectedIndex == index,
                  available: availability[index],
                  onPressed: () => onChanged(index),
                ),
                if (index < _progressAngles.length - 1)
                  const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        if (anyUnavailable) ...[
          const SizedBox(height: 7),
          Text(
            'Só é possível comparar ângulos com fotos nas duas datas.',
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ],
        if (feedback != null) ...[
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.textSecondary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    feedback,
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _angleButton({
    required String label,
    required bool selected,
    required bool available,
    required VoidCallback onPressed,
  }) {
    // O botão nunca fica desativado: quando o ângulo não existe nas duas
    // datas, o toque mostra uma explicação em vez de não fazer nada.
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: selected
            ? Colors.white
            : available
            ? AppColors.onSurface
            : AppColors.textSecondary.withValues(alpha: 0.45),
        backgroundColor: selected
            ? StudentThemeColors.of(context).primary
            : available
            ? AppColors.surfaceHighest
            : AppColors.surfaceHighest.withValues(alpha: 0.35),
        side: BorderSide(
          color: selected
              ? StudentThemeColors.of(context).primary
              : AppColors.outline.withValues(alpha: available ? 1 : 0.35),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        minimumSize: const Size(0, 42),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    );
  }

  Widget _comparisonDateDropdown({
    required String label,
    required String selectedKey,
    required List<ProgressModel> options,
    required ValueChanged<String?> onChanged,
  }) {
    final safeKey =
        options.any((progress) => _progressKey(progress) == selectedKey)
        ? selectedKey
        : _progressKey(options.first);
    return DropdownButtonFormField<String>(
      isDense: true,
      menuMaxHeight: 320,
      elevation: 2,
      borderRadius: BorderRadius.circular(14),
      initialValue: safeKey,
      isExpanded: true,
      dropdownColor: AppColors.surfaceHigh,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: AppColors.onSurfaceVariant),
        filled: true,
        fillColor: AppColors.surfaceHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: StudentThemeColors.of(context).primary,
            width: 1.5,
          ),
        ),
      ),
      style: GoogleFonts.inter(color: AppColors.onSurface, fontSize: 13),
      items: [
        for (final progress in options)
          DropdownMenuItem<String>(
            value: _progressKey(progress),
            child: Text(
              DateFormat('dd/MM/yyyy').format(progress.data),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildProgressComparisonShell({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: StudentThemeColors.of(
                    context,
                  ).primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.compare_arrows_rounded,
                  color: StudentThemeColors.of(context).primary,
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
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Arrasta o divisor para veres a evolução em tempo real.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildWeightChart(List<ProgressModel> progressList) {
    final sorted = List<ProgressModel>.from(progressList)
      ..sort((a, b) => a.data.compareTo(b.data));
    final weightEntries = sorted.where((p) => p.peso != null).toList();

    if (weightEntries.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (weightEntries.length - 1).toDouble(),
          minY:
              weightEntries
                  .map((e) => e.peso!)
                  .reduce((a, b) => a < b ? a : b) -
              5,
          maxY:
              weightEntries
                  .map((e) => e.peso!)
                  .reduce((a, b) => a > b ? a : b) +
              5,
          lineBarsData: [
            LineChartBarData(
              spots: weightEntries
                  .asMap()
                  .entries
                  .map((e) => FlSpot(e.key.toDouble(), e.value.peso!))
                  .toList(),
              isCurved: true,
              color: StudentThemeColors.of(context).primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: StudentThemeColors.of(
                  context,
                ).primary.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressPhotos(
    String userId,
    AsyncValue<List<ProgressModel>> progressAsync,
  ) {
    final photos = progressAsync.maybeWhen(
      data: (list) => list
          .expand((p) => p.fotos.map((f) => (foto: f, data: p.data)))
          .toList(),
      orElse: () => <({String foto, DateTime data})>[],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.photo_library_outlined,
                color: StudentThemeColors.of(context).primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                AppStrings.progressPhotos,
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            photos.isEmpty
                ? 'As tuas fotos de evolução aparecerão aqui.'
                : 'Toca numa foto para a veres em detalhe.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          if (photos.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.outline.withValues(alpha: 0.7),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.photo_camera_back_outlined,
                    size: 30,
                    color: AppColors.textSecondary.withValues(alpha: 0.45),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ainda não existem fotos de progresso.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: photos.length,
              itemBuilder: (_, index) {
                final photo = photos[index];
                return GestureDetector(
                  onTap: () => _openPhotoViewer(photos, index),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      photo.foto,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: AppColors.surfaceHigh,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: StudentThemeColors.of(context).primary,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.surfaceHigh,
                        child: const Icon(
                          Icons.broken_image,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// Abre o visualizador de fotos em full-screen com zoom e navegação.
  void _openPhotoViewer(
    List<({String foto, DateTime data})> photos,
    int initialIndex,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _PhotoViewer(photos: photos, initialIndex: initialIndex),
      ),
    );
  }

  Widget _buildSoundPicker(UserModel user) {
    final currentSound = user.notificationSound ?? defaultSoundAsset;
    final selectedOption = getSoundOption(currentSound);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
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
                  color: StudentThemeColors.of(
                    context,
                  ).primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.notifications_none_rounded,
                  color: StudentThemeColors.of(context).primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Som de notificação',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Escolhe o som usado nos avisos da aplicação.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceHighest,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: StudentThemeColors.of(
                  context,
                ).primary.withValues(alpha: 0.28),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: StudentThemeColors.of(context).primary,
                  size: 18,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Som atual',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selectedOption.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _previewSound(selectedOption, currentSound),
                  tooltip: 'Ouvir som atual',
                  icon: const Icon(Icons.play_arrow_rounded),
                  color: StudentThemeColors.of(context).primary,
                  style: IconButton.styleFrom(
                    backgroundColor: StudentThemeColors.of(
                      context,
                    ).primary.withValues(alpha: 0.12),
                    minimumSize: const Size(38, 38),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Opções disponíveis',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          ...notificationSoundOptions.map((option) {
            final isSelected = option.asset == currentSound;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Material(
                color: isSelected
                    ? StudentThemeColors.of(
                        context,
                      ).primary.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => _selectSound(user, option),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: isSelected
                              ? StudentThemeColors.of(context).primary
                              : AppColors.textSecondary,
                          size: 19,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            option.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _previewSound(option, currentSound),
                          tooltip: 'Ouvir ${option.name}',
                          icon: const Icon(Icons.volume_up_outlined, size: 18),
                          color: AppColors.textSecondary,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 34,
                            minHeight: 34,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _previewSound(SoundOption option, String currentSound) {
    _previewRestoreTimer?.cancel();
    SoundService().setSound(option.asset);
    SoundService().playNotificationChime();
    _previewRestoreTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) SoundService().setSound(currentSound);
    });
  }

  Future<void> _selectSound(UserModel user, SoundOption option) async {
    // Cancela qualquer restore pendente de preview
    _previewRestoreTimer?.cancel();
    // Configura imediatamente o som no serviço
    SoundService().setSound(option.asset);

    // Guarda no Firestore
    try {
      await ref.read(userRepositoryProvider).updateUser(user.uid, {
        'notificationSound': option.asset,
      });
      ref.invalidate(userProfileProvider(user.uid));
    } catch (_) {
      // Se falhar, reverte para o anterior
      SoundService().setSound(user.notificationSound ?? defaultSoundAsset);
    }
  }

  @override
  void dispose() {
    _previewRestoreTimer?.cancel();
    super.dispose();
  }

  Future<void> _changeProfilePhoto(String userId) async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Alterar foto',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            child: Row(
              children: [
                Icon(
                  Icons.camera_alt,
                  color: StudentThemeColors.of(context).primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Câmara',
                  style: GoogleFonts.inter(color: AppColors.onSurface),
                ),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            child: Row(
              children: [
                Icon(
                  Icons.photo_library,
                  color: StudentThemeColors.of(context).primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Galeria',
                  style: GoogleFonts.inter(color: AppColors.onSurface),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (source == null) return;

    final picked = await _picker.pickImage(
      source: source,
      imageQuality: AppConstants.imageQuality,
      maxWidth: AppConstants.maxImageWidth.toDouble(),
      maxHeight: AppConstants.maxImageHeight.toDouble(),
    );

    if (picked == null) return;

    try {
      final bytes = await picked.readAsBytes();
      final url = await ref
          .read(progressRepositoryProvider)
          .uploadProfilePhoto(userId, Uint8List.fromList(bytes));
      await ref.read(userRepositoryProvider).updateUser(userId, {
        'fotoPerfil': url,
      });
    } catch (_) {
      if (mounted) {
        showAppNotification(
          context,
          AppStrings.uploadError,
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _addProgressPhoto(String userId) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: AppConstants.imageQuality,
    );

    if (picked == null) return;

    try {
      final bytes = await picked.readAsBytes();
      final normalized = await normalizeProgressPhoto(
        Uint8List.fromList(bytes),
      );
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final url = await ref
          .read(progressRepositoryProvider)
          .uploadProgressPhoto(userId, timestamp, normalized);

      await ref.read(progressRepositoryProvider).addProgress(userId, {
        'data': DateTime.now(),
        'fotos': [url],
      });
    } catch (_) {
      if (mounted) {
        showAppNotification(
          context,
          AppStrings.uploadError,
          type: NotificationType.error,
        );
      }
    }
  }

  Widget _buildVideoProgressEntry(UserModel user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          const Icon(Icons.videocam_outlined, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Progressão em vídeo',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Envia e acompanha vídeos da tua execução.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VideoProgressScreen(userId: user.uid),
              ),
            ),
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsSection(String userId) {
    // Usa provider estável (module-level) — nunca inline StreamProvider no build()!
    final paymentsAsync = ref.watch(paymentsStreamProvider(userId));

    return paymentsAsync.when(
      data: (payments) {
        if (payments.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pagamentos e Faturas',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            ...payments.map((p) => _paymentCard(p)),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outline),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Não foi possível carregar as cobranças.'),
            ),
            TextButton(
              onPressed: () => ref.invalidate(paymentsStreamProvider(userId)),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentCard(PaymentModel payment) {
    final statusColors = {
      'paid': StudentThemeColors.of(context).primary,
      'pending': AppColors.calories,
      'scheduled': AppColors.primary,
      'overdue': AppColors.error,
      'failed': AppColors.error,
      'refunded': AppColors.textSecondary,
      'cancelled': AppColors.textSecondary,
    };
    final statusLabels = {
      'paid': 'PAGO',
      'pending': 'PENDENTE',
      'scheduled': 'AGENDADO',
      'overdue': 'EM ATRASO',
      'failed': 'FALHOU',
      'refunded': 'REEMBOLSADO',
      'cancelled': 'CANCELADO',
    };
    final statusColor =
        statusColors[payment.effectiveStatus] ?? AppColors.textSecondary;
    final statusLabel =
        statusLabels[payment.effectiveStatus] ?? payment.status.toUpperCase();
    final periodLabel = payment.periodoInicio != null && payment.periodoFim != null
        ? '${DateFormat('dd/MM/yyyy').format(payment.periodoInicio!)} – '
            '${DateFormat('dd/MM/yyyy').format(payment.periodoFim!)}'
        : DateFormat('d MMM yyyy', 'pt').format(payment.data);
    final loading = _paymentLoadingId == payment.id;
    final startsInFuture = payment.periodoInicio?.isAfter(DateTime.now()) == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              payment.isPaid ? Icons.receipt : Icons.payment_outlined,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.descricao ?? payment.tipoMensalidadeLabel,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${payment.tipoMensalidadeLabel} · $periodLabel',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                payment.valorFormatado,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
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
              if (!payment.isPaid && payment.stripeHostedInvoiceUrl != null) ...[
                const SizedBox(height: 4),
                TextButton(
                  onPressed: loading ? null : () => _payPayment(payment),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(
                    'Pagar agora',
                    style: GoogleFonts.inter(
                      color: AppColors.error,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ] else if (payment.canStartCheckout) ...[
                const SizedBox(height: 4),
                TextButton(
                  onPressed: loading ? null : () => _payPayment(payment),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          startsInFuture ? 'Ativar automático' : 'Pagar',
                          style: GoogleFonts.inter(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ],
            ],
          ),
          if (payment.faturaUrl != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.picture_as_pdf,
                color: StudentThemeColors.of(context).primary,
                size: 22,
              ),
              onPressed: () => launchUrl(
                Uri.parse(payment.faturaUrl!),
                mode: LaunchMode.externalApplication,
              ),
              tooltip: 'Ver fatura',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _payPayment(PaymentModel payment) async {
    if (_paymentLoadingId != null) return;
    setState(() => _paymentLoadingId = payment.id);
    try {
      final url = payment.stripeHostedInvoiceUrl ??
          await ref.read(paymentRepositoryProvider).createPaymentCheckoutSession(
                paymentId: payment.id,
              );
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        showAppNotification(
          context,
          'Não foi possível abrir o pagamento.',
          type: NotificationType.error,
        );
      }
    } catch (error) {
      debugPrint('createPaymentCheckoutSession failed: $error');
      if (mounted) {
        showAppNotification(
          context,
          'Não foi possível iniciar o pagamento. Consulta os logs para mais detalhes.',
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _paymentLoadingId = null);
    }
  }

  Future<void> _editProfile(UserModel user) async {
    final nomeController = TextEditingController(text: user.nome);
    final pesoController = TextEditingController(
      text: user.pesoAtual?.toString() ?? '',
    );
    final alturaController = TextEditingController(
      text: user.altura?.toString() ?? '',
    );
    String genero = user.genero ?? 'feminino';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppStrings.editProfile,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeController,
                decoration: InputDecoration(
                  labelText: 'Nome',
                  labelStyle: GoogleFonts.inter(
                    color: AppColors.onSurfaceVariant,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: StudentThemeColors.of(context).primary,
                      width: 1.5,
                    ),
                  ),
                ),
                style: GoogleFonts.inter(color: AppColors.onSurface),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pesoController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Peso (kg)',
                  labelStyle: GoogleFonts.inter(
                    color: AppColors.onSurfaceVariant,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: StudentThemeColors.of(context).primary,
                      width: 1.5,
                    ),
                  ),
                ),
                style: GoogleFonts.inter(color: AppColors.onSurface),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: alturaController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Altura (cm)',
                  labelStyle: GoogleFonts.inter(
                    color: AppColors.onSurfaceVariant,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: StudentThemeColors.of(context).primary,
                      width: 1.5,
                    ),
                  ),
                ),
                style: GoogleFonts.inter(color: AppColors.onSurface),
              ),
              const SizedBox(height: 12),
              // Seletor de género
              DropdownButtonFormField<String>(
                isDense: true,
                menuMaxHeight: 320,
                elevation: 2,
                borderRadius: BorderRadius.circular(14),
                initialValue: genero,
                decoration: InputDecoration(
                  labelText: 'Género',
                  labelStyle: GoogleFonts.inter(
                    color: AppColors.onSurfaceVariant,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: StudentThemeColors.of(context).primary,
                      width: 1.5,
                    ),
                  ),
                ),
                dropdownColor: AppColors.surfaceHigh,
                style: GoogleFonts.inter(color: AppColors.onSurface),
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
                onChanged: (v) => genero = v ?? 'feminino',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: AppColors.surfaceHighest.withValues(alpha: 0.42),
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            child: Text(
              AppStrings.cancel,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: StudentThemeColors.of(context).primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 50),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            child: Text(
              AppStrings.save,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      final updates = <String, dynamic>{};
      if (nomeController.text.trim() != user.nome) {
        updates['nome'] = nomeController.text.trim();
      }
      final novoPeso = double.tryParse(
        pesoController.text.replaceAll(',', '.'),
      );
      if (novoPeso != null && novoPeso != user.pesoAtual) {
        updates['pesoAtual'] = novoPeso;
        await ref.read(progressRepositoryProvider).addProgress(user.uid, {
          'data': DateTime.now(),
          'peso': novoPeso,
          'fotos': <String>[],
          'medidas': <String, double>{},
        });
      }
      final novaAltura = double.tryParse(
        alturaController.text.replaceAll(',', '.'),
      );
      if (novaAltura != null && novaAltura != user.altura) {
        updates['altura'] = novaAltura;
      }
      if (genero != (user.genero ?? 'feminino')) {
        updates['genero'] = genero;
      }

      if (updates.isNotEmpty) {
        await ref.read(userRepositoryProvider).updateUser(user.uid, updates);
        // Força refresh para atualizar cores do tema
        ref.invalidate(userProfileProvider(user.uid));
        if (mounted) {
          showAppNotification(
            context,
            'Perfil atualizado!',
            type: NotificationType.success,
          );
        }
      }
    }
  }
}

/// Visualizador de fotos full-screen com zoom (pinch) e navegação (swipe).
class _PhotoViewer extends StatefulWidget {
  final List<({String foto, DateTime data})> photos;
  final int initialIndex;

  const _PhotoViewer({required this.photos, required this.initialIndex});

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_currentIndex + 1} / ${widget.photos.length}',
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          if (widget.photos.length > 1) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: _currentIndex > 0 ? _goToPrevious : null,
              color: _currentIndex > 0 ? Colors.white : Colors.white24,
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 18),
              onPressed: _currentIndex < widget.photos.length - 1
                  ? _goToNext
                  : null,
              color: _currentIndex < widget.photos.length - 1
                  ? Colors.white
                  : Colors.white24,
            ),
          ],
        ],
      ),
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.photos.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (_, index) {
                  final photo = widget.photos[index];
                  return InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    boundaryMargin: const EdgeInsets.all(60),
                    child: Center(
                      child: Image.network(
                        photo.foto,
                        fit: BoxFit.contain,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded /
                                        progress.expectedTotalBytes!
                                  : null,
                              color: StudentThemeColors.of(context).primary,
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image,
                                color: Colors.white38,
                                size: 48,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Erro ao carregar imagem',
                                style: TextStyle(color: Colors.white38),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Data da foto
            Padding(
              padding: const EdgeInsets.only(bottom: 32, top: 8),
              child: Text(
                _formatPhotoDate(widget.photos[_currentIndex].data),
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      _pageController.animateToPage(
        _currentIndex - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _goToNext() {
    if (_currentIndex < widget.photos.length - 1) {
      _pageController.animateToPage(
        _currentIndex + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatPhotoDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Hoje';
    if (diff.inDays == 1) return 'Ontem';
    if (diff.inDays < 7) return 'Há ${diff.inDays} dias';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
