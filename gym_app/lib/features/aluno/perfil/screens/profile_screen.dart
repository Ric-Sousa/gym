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
import '../../../../shared/widgets/image_comparison_slider.dart';
import 'progress_submission_screen.dart';

final userProfileProvider = StreamProvider.family<UserModel, String>((
  ref,
  uid,
) {
  return ref.read(userRepositoryProvider).userStream(uid);
});

final progressHistoryProvider =
    FutureProvider.family<List<ProgressModel>, String>((ref, userId) {
      return ref.read(progressRepositoryProvider).getHistory(userId);
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
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
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
            _buildQuickMetrics(user),
            const SizedBox(height: 24),
            // A evolução fica logo após as métricas para não ficar escondida
            // no fim do perfil. O comparador continua disponível ao tocar.
            _buildProgressComparisonCard(user, progressAsync),
            const SizedBox(height: 18),
            _buildProgressPhotos(user.uid, progressAsync),
            const SizedBox(height: 24),
            _buildEditableFields(user),
            const SizedBox(height: 24),
            _buildSoundPicker(user),
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
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFF8A0060)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
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
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
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
                          color: Colors.white.withValues(alpha: 0.9),
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
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
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
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          backgroundImage: user.fotoPerfil != null
              ? NetworkImage(user.fotoPerfil!)
              : null,
          child: user.fotoPerfil == null
              ? Text(
                  user.nome.isNotEmpty ? user.nome[0].toUpperCase() : '?',
                  style: GoogleFonts.montserrat(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
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
          Icon(icon, color: AppColors.primary, size: 22),
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

  Widget _buildProgressComparisonCard(
    UserModel user,
    AsyncValue<List<ProgressModel>> progressAsync,
  ) {
    final comparisonUrls = progressAsync.maybeWhen(
      data: (list) {
        final withPhotos =
            list
                .where(
                  (progress) =>
                      progress.fotos.any((url) => url.trim().isNotEmpty),
                )
                .toList()
              ..sort((a, b) => a.data.compareTo(b.data));

        String? firstPhoto(ProgressModel progress) {
          for (final url in progress.fotos) {
            final trimmed = url.trim();
            if (trimmed.isNotEmpty) return trimmed;
          }
          return null;
        }

        if (withPhotos.length >= 2) {
          return (
            before: firstPhoto(withPhotos.first),
            after: firstPhoto(withPhotos.last),
          );
        }

        // Mantém o comportamento anterior quando existe apenas um registo de
        // progresso: a foto do perfil funciona como imagem inicial.
        final progressPhoto = withPhotos.isEmpty
            ? null
            : firstPhoto(withPhotos.first);
        final profilePhoto = user.fotoPerfil?.trim();
        return (
          before: profilePhoto == null || profilePhoto.isEmpty
              ? null
              : profilePhoto,
          after: progressPhoto,
        );
      },
      orElse: () => (before: null, after: null),
    );
    final initialUrl = comparisonUrls.before;
    final latestUrl = comparisonUrls.after;
    final hasPhotos =
        initialUrl != null &&
        initialUrl.isNotEmpty &&
        latestUrl != null &&
        latestUrl.isNotEmpty &&
        initialUrl != latestUrl;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: hasPhotos
            ? () => _showProgressComparison(initialUrl!, latestUrl!)
            : null,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hasPhotos
                  ? AppColors.primary.withValues(alpha: 0.34)
                  : AppColors.outline,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.compare_arrows_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progresso',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasPhotos
                          ? 'Compara as fotos e acompanha a tua evolução.'
                          : 'O comparador ficará disponível após a primeira foto de progresso.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: hasPhotos
                          ? () =>
                                _showProgressComparison(initialUrl!, latestUrl!)
                          : null,
                      icon: const Icon(Icons.compare_arrows_rounded, size: 17),
                      label: const Text('Comparar progresso'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                hasPhotos
                    ? Icons.arrow_forward_ios_rounded
                    : Icons.lock_outline_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
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
              color: AppColors.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.1),
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
              const Icon(
                Icons.photo_library_outlined,
                color: AppColors.primary,
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
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
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
                Icon(Icons.music_note, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Som de Notificação',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Escolhe o som que toca nas notificações',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const Divider(color: AppColors.outline),
            ...notificationSoundOptions.map((option) {
              final isSelected = option.asset == currentSound;
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: InkWell(
                  onTap: () => _selectSound(user, option),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
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
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                        // Botão de preview
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              _previewRestoreTimer?.cancel();
                              SoundService().setSound(option.asset);
                              SoundService().playNotificationChime();
                              // Restaura a seleção após o preview
                              _previewRestoreTimer = Timer(
                                const Duration(milliseconds: 600),
                                () {
                                  if (mounted) {
                                    SoundService().setSound(currentSound);
                                  }
                                },
                              );
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
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
      ),
    );
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
                const Icon(Icons.camera_alt, color: AppColors.primary),
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
                const Icon(Icons.photo_library, color: AppColors.primary),
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
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final url = await ref
          .read(progressRepositoryProvider)
          .uploadProgressPhoto(userId, timestamp, Uint8List.fromList(bytes));

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

  Widget _buildComparisonButton(
    String userId,
    AsyncValue<List<ProgressModel>> progressAsync,
  ) {
    // Mantido apenas para compatibilidade interna; a comparação agora é
    // apresentada diretamente no cartão de evolução visual.
    return const SizedBox.shrink();
  }

  void _showProgressComparison(String initialUrl, String latestUrl) {
    // O AlertDialog faz uma passagem de dimensões intrínsecas. Um
    // LayoutBuilder diretamente no conteúdo não é compatível com essa
    // passagem no Flutter Web, por isso calculamos o tamanho antes de abrir
    // o diálogo e passamos limites concretos ao slider.
    final screenSize = MediaQuery.sizeOf(context);
    // O AlertDialog reserva cerca de 40 px de cada lado por defeito.
    // Descontamos esse espaço para evitar overflow em ecrãs estreitos.
    final availableWidth = (screenSize.width - 80).clamp(1.0, double.infinity);
    final dialogWidth = availableWidth.clamp(1.0, 560.0).toDouble();
    final sliderHeight = (dialogWidth * 1.08).clamp(220.0, 420.0).toDouble();

    showDialog(
      context: context,
      animationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 260),
        reverseDuration: Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.compare, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Comparação Antes / Depois',
                style: GoogleFonts.montserrat(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: dialogWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'ANTES',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'DEPOIS',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: dialogWidth,
                height: sliderHeight,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: ImageComparisonSlider(
                    beforeImage: initialUrl,
                    afterImage: latestUrl,
                    height: sliderHeight,
                    dividerColor: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
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
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _paymentCard(PaymentModel payment) {
    final statusColors = {
      'paid': AppColors.primary,
      'pending': AppColors.calories,
      'failed': AppColors.error,
      'refunded': AppColors.textSecondary,
    };
    final statusLabels = {
      'paid': 'PAGO',
      'pending': 'PENDENTE',
      'failed': 'FALHOU',
      'refunded': 'REEMBOLSADO',
    };

    final statusColor = statusColors[payment.status] ?? AppColors.textSecondary;
    final statusLabel =
        statusLabels[payment.status] ?? payment.status.toUpperCase();

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
              payment.isPaid ? Icons.receipt : Icons.pending,
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
                  payment.descricao ?? 'Mensalidade',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('d MMM yyyy', 'pt').format(payment.data),
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
            ],
          ),
          if (payment.faturaUrl != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(
                Icons.picture_as_pdf,
                color: AppColors.primary,
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
                    borderSide: const BorderSide(
                      color: AppColors.primary,
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
                    borderSide: const BorderSide(
                      color: AppColors.primary,
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
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
                style: GoogleFonts.inter(color: AppColors.onSurface),
              ),
              const SizedBox(height: 12),
              // Seletor de género
              DropdownButtonFormField<String>(
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
                    borderSide: const BorderSide(
                      color: AppColors.primary,
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
              backgroundColor: AppColors.primary,
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
                              color: AppColors.primary,
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
