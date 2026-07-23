import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Provider do perfil do utilizador.
final userProfileProvider =
    StreamProvider.family<UserModel, String>((ref, uid) {
  return ref.read(userRepositoryProvider).userStream(uid);
});

/// Provider do histórico de progresso.
final progressHistoryProvider =
    FutureProvider.family<List<ProgressModel>, String>((ref, userId) {
  return ref.read(progressRepositoryProvider).getHistory(userId);
});

/// Ecrã de perfil do aluno.
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
      appBar: AppBar(
        title: const Text(AppStrings.profile),
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Erro ao carregar perfil')),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header com foto
            _buildProfileHeader(user),
            const SizedBox(height: 24),

            // Métricas rápidas
            _buildQuickMetrics(user),
            const SizedBox(height: 24),

            // Campos editáveis
            _buildEditableFields(user),
            const SizedBox(height: 24),

            // Progresso
            Text(
              AppStrings.weightEvolution,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
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
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) =>
                  const Text('Erro ao carregar dados de progresso'),
            ),
            const SizedBox(height: 24),

            // Fotos de progresso
            _buildProgressPhotos(user.uid, progressAsync),
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
                backgroundColor: AppColors.primaryLight,
                backgroundImage: user.fotoPerfil != null
                    ? NetworkImage(user.fotoPerfil!)
                    : null,
                child: user.fotoPerfil == null
                    ? Text(
                        user.nome.isNotEmpty
                            ? user.nome[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontSize: 36, color: Colors.white),
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
                  child: const Icon(Icons.camera_alt,
                      size: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          user.nome,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          user.email,
          style: const TextStyle(color: AppColors.textSecondary),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(
            label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableFields(UserModel user) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Informações',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _editProfile(user),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Editar'),
                ),
              ],
            ),
            const Divider(),
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
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildWeightChart(List<ProgressModel> progressList) {
    final sorted = List<ProgressModel>.from(progressList)
      ..sort((a, b) => a.data.compareTo(b.data));
    final weightEntries =
        sorted.where((p) => p.peso != null).toList();

    if (weightEntries.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (weightEntries.length - 1).toDouble(),
          minY: weightEntries.map((e) => e.peso!).reduce(
                (a, b) => a < b ? a : b,
              ) -
              5,
          maxY: weightEntries.map((e) => e.peso!).reduce(
                (a, b) => a > b ? a : b,
              ) +
              5,
          lineBarsData: [
            LineChartBarData(
              spots: weightEntries
                  .asMap()
                  .entries
                  .map((e) => FlSpot(
                        e.key.toDouble(),
                        e.value.peso!,
                      ))
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
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
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
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                  child: const Icon(
                    Icons.add_a_photo,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
              );
            }
            final photo = photos[index];
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                photo.foto,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: AppColors.backgroundLight,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.backgroundLight,
                  child:
                      const Icon(Icons.broken_image, color: AppColors.error),
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
        title: const Text('Alterar foto'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            child: const Row(
              children: [
                Icon(Icons.camera_alt),
                SizedBox(width: 12),
                Text('Câmara'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            child: const Row(
              children: [
                Icon(Icons.photo_library),
                SizedBox(width: 12),
                Text('Galeria'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.uploadError),
            backgroundColor: AppColors.error,
          ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.uploadError),
            backgroundColor: AppColors.error,
          ),
        );
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
        title: const Text(AppStrings.editProfile),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeController,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              TextField(
                controller: pesoController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Peso (kg)'),
              ),
              TextField(
                controller: alturaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Altura (cm)'),
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
        // Guarda também como entrada de progresso
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
