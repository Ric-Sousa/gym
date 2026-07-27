import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:typed_data';
import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/config/app_strings.dart';
import '../../../../data/models/progress_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../shared/providers/global_providers.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/app_notification.dart';
import 'progress_submission_screen.dart';

final userProfileProvider =
    StreamProvider.family<UserModel, String>((ref, uid) {
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
        data: (user) => _buildProfileContent(user),
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => const Center(
          child: Text('Erro ao carregar perfil',
              style: TextStyle(color: AppColors.textSecondary)),
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
            _buildEditableFields(user),
            const SizedBox(height: 24),
            Text(
              AppStrings.weightEvolution,
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            progressAsync.when(
              data: (progressList) {
                if (progressList.isEmpty) {
                  return const EmptyState(
                    icon: Icons.show_chart,
                    title: AppStrings.noProgressData,
                  );
                }
                return _buildWeightChart(progressList);
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (_, __) => const Text(
                'Erro ao carregar dados de progresso',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 24),
            _buildProgressPhotos(user.uid, progressAsync),
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
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
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
            ElevatedButton(
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
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Submeter',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(UserModel user) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _changeProfilePhoto(user.uid),
          child: Stack(
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
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
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
    return Row(
      children: [
        Expanded(
          child: _metricCard(
            'Peso',
            user.pesoAtual != null ? '${user.pesoAtual} kg' : '--',
            Icons.monitor_weight,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricCard(
            'Altura',
            user.altura != null ? '${user.altura} cm' : '--',
            Icons.height,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricCard(
            'IMC',
            user.imc != null ? user.imc!.toStringAsFixed(1) : '--',
            Icons.calculate,
          ),
        ),
      ],
    );
  }

  Widget _metricCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
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
        borderRadius: BorderRadius.circular(8),
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
            _infoRow(
              'Peso',
              user.pesoAtual != null ? '${user.pesoAtual} kg' : 'Não definido',
            ),
            _infoRow(
              'Altura',
              user.altura != null ? '${user.altura} cm' : 'Não definida',
            ),
            if (user.imcCategory != null)
              _infoRow('Categoria IMC', user.imcCategory!),
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
          Text(
            value,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w500,
              color: AppColors.onSurface,
              fontSize: 14,
            ),
          ),
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outline),
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(
            show: false,
          ),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (weightEntries.length - 1).toDouble(),
          minY: weightEntries.map((e) => e.peso!).reduce((a, b) => a < b ? a : b) - 5,
          maxY: weightEntries.map((e) => e.peso!).reduce((a, b) => a > b ? a : b) + 5,
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
      String userId, AsyncValue<List<ProgressModel>> progressAsync) {
    final photos = progressAsync.maybeWhen(
      data: (list) => list
          .expand((p) => p.fotos.map((f) => (foto: f, data: p.data)))
          .toList(),
      orElse: () => <({String foto, DateTime data})>[],
    );

    if (photos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.progressPhotos,
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: photos.length + 1,
          itemBuilder: (_, index) {
            if (index == photos.length) {
              return GestureDetector(
                onTap: () => _addProgressPhoto(userId),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.add_a_photo,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
              );
            }
            final photo = photos[index];
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                photo.foto,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: AppColors.surfaceHigh,
                    child: const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.surfaceHigh,
                  child: const Icon(Icons.broken_image, color: AppColors.error),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _changeProfilePhoto(String userId) async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.surfaceHigh,
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
                Text('Câmara',
                    style: GoogleFonts.inter(color: AppColors.onSurface)),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            child: Row(
              children: [
                const Icon(Icons.photo_library, color: AppColors.primary),
                const SizedBox(width: 12),
                Text('Galeria',
                    style: GoogleFonts.inter(color: AppColors.onSurface)),
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
      await ref
          .read(userRepositoryProvider)
          .updateUser(userId, {'fotoPerfil': url});
    } catch (_) {
      if (mounted) {
        showAppNotification(context, AppStrings.uploadError, type: NotificationType.error);
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
        showAppNotification(context, AppStrings.uploadError, type: NotificationType.error);
      }
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

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
                decoration: const InputDecoration(labelText: 'Nome'),
                style: GoogleFonts.inter(color: AppColors.onSurface),
              ),
              TextField(
                controller: pesoController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Peso (kg)'),
                style: GoogleFonts.inter(color: AppColors.onSurface),
              ),
              TextField(
                controller: alturaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Altura (cm)'),
                style: GoogleFonts.inter(color: AppColors.onSurface),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );

    if (result == true) {
      final updates = <String, dynamic>{};
      if (nomeController.text.trim() != user.nome) {
        updates['nome'] = nomeController.text.trim();
      }
      final novoPeso = double.tryParse(pesoController.text.replaceAll(',', '.'));
      if (novoPeso != null && novoPeso != user.pesoAtual) {
        updates['pesoAtual'] = novoPeso;
        await ref.read(progressRepositoryProvider).addProgress(user.uid, {
          'data': DateTime.now(),
          'peso': novoPeso,
          'fotos': <String>[],
          'medidas': <String, double>{},
        });
      }
      final novaAltura =
          double.tryParse(alturaController.text.replaceAll(',', '.'));
      if (novaAltura != null && novaAltura != user.altura) {
        updates['altura'] = novaAltura;
      }

      if (updates.isNotEmpty) {
        await ref.read(userRepositoryProvider).updateUser(user.uid, updates);
      }
    }
  }
}
