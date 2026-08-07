import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../shared/providers/global_providers.dart';
import '../../../../shared/widgets/app_notification.dart';

/// Ecrã para o aluno submeter progresso (fotos + peso).
/// Aberto quando a personal trainer solicita avaliação mensal.
class ProgressSubmissionScreen extends ConsumerStatefulWidget {
  final VoidCallback? onSubmitComplete;
  const ProgressSubmissionScreen({super.key, this.onSubmitComplete});

  @override
  ConsumerState<ProgressSubmissionScreen> createState() =>
      _ProgressSubmissionScreenState();
}

class _ProgressSubmissionScreenState
    extends ConsumerState<ProgressSubmissionScreen> {
  final _picker = ImagePicker();
  final _pesoController = TextEditingController();
  final _cinturaController = TextEditingController();
  final _abdomenController = TextEditingController();
  final _quadrilController = TextEditingController();
  final _bracoDController = TextEditingController();
  final _bracoEController = TextEditingController();
  final _coxaDController = TextEditingController();
  final _coxaEController = TextEditingController();
  final _peitoController = TextEditingController();
  final _gorduraController = TextEditingController();
  final List<Uint8List> _photos = [];
  int _currentStep = 0;
  bool _saving = false;

  @override
  void dispose() {
    _pesoController.dispose();
    _cinturaController.dispose();
    _abdomenController.dispose();
    _quadrilController.dispose();
    _bracoDController.dispose();
    _bracoEController.dispose();
    _coxaDController.dispose();
    _coxaEController.dispose();
    _peitoController.dispose();
    _gorduraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Avaliação de Progresso',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: _onStepContinue,
        onStepCancel: _currentStep > 0
            ? () => setState(() => _currentStep--)
            : () => Navigator.pop(context),
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: details.onStepContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _currentStep < 2 ? 'Continuar' : 'Submeter',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: details.onStepCancel,
                  child: Text(
                    _currentStep > 0 ? 'Voltar' : 'Cancelar',
                    style: GoogleFonts.inter(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: Text(
              'Fotos de Progresso',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
            subtitle: Text(
              'Tira fotos de frente, lado e costas',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            isActive: _currentStep >= 0,
            state: _currentStep > 0
                ? StepState.complete
                : (_currentStep == 0 ? StepState.editing : StepState.indexed),
            content: _buildPhotoStep(),
          ),
          Step(
            title: Text(
              'Peso e Medidas',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
            subtitle: Text(
              'Regista o teu peso atual e medidas',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            isActive: _currentStep >= 1,
            state: _currentStep > 1
                ? StepState.complete
                : (_currentStep == 1 ? StepState.editing : StepState.indexed),
            content: _buildMeasurementsStep(),
          ),
          Step(
            title: Text(
              'Confirmar e Submeter',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
            isActive: _currentStep >= 2,
            state: _currentStep == 2 ? StepState.editing : StepState.indexed,
            content: _buildConfirmStep(),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Adiciona até 4 fotos (frente, lado, costas, opcional)',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._photos.asMap().entries.map((entry) {
              final index = entry.key;
              final bytes = entry.value;
              return Stack(
                children: [
                  Container(
                    width: 100,
                    height: 130,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.outline),
                      image: DecorationImage(
                        image: MemoryImage(bytes),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => setState(() => _photos.removeAt(index)),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
            if (_photos.length < 4)
              GestureDetector(
                onTap: _addPhoto,
                child: Container(
                  width: 100,
                  height: 130,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Adicionar',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMeasurementsStep() {
    return Column(
      children: [
        TextField(
          controller: _pesoController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.inter(color: AppColors.onSurface),
          decoration: InputDecoration(
            labelText: 'Peso (kg)',
            hintText: 'Ex: 75.5',
            suffixText: 'kg',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Medidas corporais (opcional)',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _medidaField(_cinturaController, 'Cintura')),
            const SizedBox(width: 8),
            Expanded(child: _medidaField(_abdomenController, 'Abdómen')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _medidaField(_quadrilController, 'Quadril')),
            const SizedBox(width: 8),
            Expanded(child: _medidaField(_peitoController, 'Peito')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _medidaField(_bracoDController, 'Braço D')),
            const SizedBox(width: 8),
            Expanded(child: _medidaField(_bracoEController, 'Braço E')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _medidaField(_coxaDController, 'Coxa D')),
            const SizedBox(width: 8),
            Expanded(child: _medidaField(_coxaEController, 'Coxa E')),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _gorduraController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.inter(color: AppColors.onSurface),
          decoration: const InputDecoration(
            labelText: '% Gordura Corporal',
            suffixText: '%',
          ),
        ),
      ],
    );
  }

  Widget _medidaField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: GoogleFonts.inter(color: AppColors.onSurface),
      decoration: InputDecoration(labelText: label, suffixText: 'cm'),
    );
  }

  Widget _buildConfirmStep() {
    final peso = _pesoController.text.isNotEmpty
        ? '${_pesoController.text} kg'
        : 'Não definido';
    final temMedidas =
        _cinturaController.text.isNotEmpty ||
        _abdomenController.text.isNotEmpty ||
        _quadrilController.text.isNotEmpty ||
        _peitoController.text.isNotEmpty ||
        _bracoDController.text.isNotEmpty ||
        _bracoEController.text.isNotEmpty ||
        _coxaDController.text.isNotEmpty ||
        _coxaEController.text.isNotEmpty ||
        _gorduraController.text.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Resumo da Avaliação',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const Divider(color: AppColors.outline, height: 24),
          _confirmRow('Fotos', '${_photos.length} foto(s)'),
          _confirmRow('Peso', peso),
          if (temMedidas) ...[
            const SizedBox(height: 8),
            Text(
              'Medidas:',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            if (_cinturaController.text.isNotEmpty)
              _confirmRow('  Cintura', '${_cinturaController.text} cm'),
            if (_abdomenController.text.isNotEmpty)
              _confirmRow('  Abdómen', '${_abdomenController.text} cm'),
            if (_quadrilController.text.isNotEmpty)
              _confirmRow('  Quadril', '${_quadrilController.text} cm'),
            if (_peitoController.text.isNotEmpty)
              _confirmRow('  Peito', '${_peitoController.text} cm'),
            if (_bracoDController.text.isNotEmpty)
              _confirmRow('  Braço D', '${_bracoDController.text} cm'),
            if (_bracoEController.text.isNotEmpty)
              _confirmRow('  Braço E', '${_bracoEController.text} cm'),
            if (_coxaDController.text.isNotEmpty)
              _confirmRow('  Coxa D', '${_coxaDController.text} cm'),
            if (_coxaEController.text.isNotEmpty)
              _confirmRow('  Coxa E', '${_coxaEController.text} cm'),
            if (_gorduraController.text.isNotEmpty)
              _confirmRow('  % Gordura', '${_gorduraController.text}%'),
          ],
          if (_saving) ...[
            const SizedBox(height: 16),
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _confirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  void _onStepContinue() {
    if (_currentStep == 2) {
      _submitProgress();
      return;
    }

    if (_currentStep == 1) {
      // Validar peso
      final peso = _pesoController.text.trim();
      if (peso.isEmpty) {
        showAppNotification(
          context,
          'O peso é obrigatório.',
          type: NotificationType.error,
        );
        return;
      }
      if (double.tryParse(peso.replaceAll(',', '.')) == null) {
        showAppNotification(
          context,
          'Peso inválido.',
          type: NotificationType.error,
        );
        return;
      }
    }

    setState(() => _currentStep++);
  }

  Future<void> _addPhoto() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: Text(
          'Adicionar foto',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            child: const Row(
              children: [
                Icon(Icons.camera_alt, color: AppColors.primary),
                SizedBox(width: 12),
                Text('Câmara', style: TextStyle(color: AppColors.onSurface)),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            child: const Row(
              children: [
                Icon(Icons.photo_library, color: AppColors.primary),
                SizedBox(width: 12),
                Text('Galeria', style: TextStyle(color: AppColors.onSurface)),
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
    );

    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() => _photos.add(Uint8List.fromList(bytes)));
  }

  Future<void> _submitProgress() async {
    setState(() => _saving = true);

    try {
      final authState = ref.read(authProvider);
      final userId = authState.user?.uid ?? '';
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      // Upload das fotos
      final progressRepo = ref.read(progressRepositoryProvider);
      final fotoUrls = <String>[];
      for (int i = 0; i < _photos.length; i++) {
        final url = await progressRepo.uploadProgressPhoto(
          userId,
          '${timestamp}_$i',
          _photos[i],
        );
        fotoUrls.add(url);
      }

      // Construir medidas
      final medidas = <String, double>{};
      void addMedida(String key, TextEditingController ctrl) {
        final v = double.tryParse(ctrl.text.replaceAll(',', '.'));
        if (v != null) medidas[key] = v;
      }

      addMedida('cintura', _cinturaController);
      addMedida('abdomen', _abdomenController);
      addMedida('quadril', _quadrilController);
      addMedida('peito', _peitoController);
      addMedida('bracoD', _bracoDController);
      addMedida('bracoE', _bracoEController);
      addMedida('coxaD', _coxaDController);
      addMedida('coxaE', _coxaEController);
      addMedida('gordura', _gorduraController);

      // Peso
      final peso = double.tryParse(_pesoController.text.replaceAll(',', '.'));

      // Guardar entrada de progresso
      await progressRepo.addProgress(userId, {
        'data': DateTime.now(),
        'peso': peso,
        'medidas': medidas,
        'fotos': fotoUrls,
      });

      // Atualizar peso no perfil
      final userRepo = ref.read(userRepositoryProvider);
      if (peso != null) {
        await userRepo.updateUser(userId, {
          'pesoAtual': peso,
          'hasPendingProgress': false,
        });
      } else {
        await userRepo.updateUser(userId, {'hasPendingProgress': false});
      }

      if (mounted) {
        showAppNotification(
          context,
          'Progresso registado com sucesso! 💪',
          type: NotificationType.success,
        );
        widget.onSubmitComplete?.call();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showAppNotification(
          context,
          'Erro ao guardar progresso. Tenta novamente.',
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
