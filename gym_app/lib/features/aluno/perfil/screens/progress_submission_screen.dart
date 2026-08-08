import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/utils/progress_photo_normalizer.dart';
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

  // Ordem persistida no campo `fotos`: Frente, Lado 1, Lado 2, Costas.
  // Os slots vazios são mantidos para que cada posição continue identificável
  // no comparador do perfil, mesmo quando o aluno não envia todas as fotos.
  static const _photoPositions = <String>[
    'Frente',
    'Lado 1',
    'Lado 2',
    'Costas',
  ];
  final List<Uint8List?> _photos = List<Uint8List?>.filled(4, null);
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
      body: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppColors.primary,
            secondary: AppColors.primary,
          ),
        ),
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: _onStepContinue,
          onStepCancel: _currentStep > 0
              ? () => setState(() => _currentStep--)
              : () => Navigator.pop(context),
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  ElevatedButton(
                    onPressed: details.onStepContinue,
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
                      _currentStep < 2 ? 'Continuar' : 'Submeter',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: details.onStepCancel,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    child: Text(
                      _currentStep > 0 ? 'Voltar' : 'Cancelar',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
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
      ),
    );
  }

  Widget _buildPhotoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Adiciona uma foto para cada posição. Podes enviar apenas as posições disponíveis.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 560 ? 4 : 2;
            final gap = 10.0;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var index = 0; index < _photoPositions.length; index++)
                  SizedBox(width: width, child: _photoSlot(index)),
              ],
            );
          },
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
          _confirmRow(
            'Fotos',
            '${_photos.where((photo) => photo != null).length} foto(s)',
          ),
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

  Widget _photoSlot(int index) {
    final bytes = _photos[index];
    final hasPhoto = bytes != null;

    return GestureDetector(
      onTap: () => _addPhoto(index),
      child: Container(
        height: 166,
        decoration: BoxDecoration(
          color: hasPhoto ? AppColors.surfaceHigh : AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bytes != null)
              Image.memory(bytes, fit: BoxFit.cover)
            else
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo_outlined,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Adicionar foto',
                    style: GoogleFonts.inter(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            Positioned(
              left: 1,
              right: 1,
              bottom: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(15),
                  ),
                  border: const Border(
                    top: BorderSide(color: AppColors.outline),
                  ),
                ),
                child: Text(
                  _photoPositions[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (hasPhoto)
              Positioned(
                top: 7,
                right: 7,
                child: Material(
                  color: AppColors.error,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _photos[index] = null),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _addPhoto(int slotIndex) async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Adicionar foto',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            child: const Row(
              children: [
                Icon(Icons.camera_alt, color: AppColors.textSecondary),
                SizedBox(width: 12),
                Text('Câmara', style: TextStyle(color: AppColors.onSurface)),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            child: const Row(
              children: [
                Icon(Icons.photo_library, color: AppColors.textSecondary),
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

    try {
      final bytes = await picked.readAsBytes();
      final normalized = await normalizeProgressPhoto(
        Uint8List.fromList(bytes),
      );
      if (!mounted) return;
      setState(() => _photos[slotIndex] = normalized);
    } catch (_) {
      if (!mounted) return;
      showAppNotification(
        context,
        'Não foi possível preparar essa fotografia.',
        type: NotificationType.error,
      );
    }
  }

  Future<void> _submitProgress() async {
    setState(() => _saving = true);

    try {
      final authState = ref.read(authProvider);
      final userId = authState.user?.uid ?? '';
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      // Upload das fotos
      final progressRepo = ref.read(progressRepositoryProvider);
      // Mantém os quatro índices para que o comparador saiba qual URL
      // corresponde a Frente, Lado 1, Lado 2 e Costas. Um slot não enviado
      // fica vazio, sem deslocar as posições seguintes.
      final fotoUrls = List<String>.filled(_photos.length, '');
      for (int i = 0; i < _photos.length; i++) {
        final photo = _photos[i];
        if (photo == null) continue;
        final url = await progressRepo.uploadProgressPhoto(
          userId,
          '${timestamp}_$i',
          photo,
        );
        fotoUrls[i] = url;
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
      final fotosPorPosicao = <String, String>{};
      for (var index = 0; index < fotoUrls.length; index++) {
        if (fotoUrls[index].isNotEmpty) {
          fotosPorPosicao[_photoPositions[index]] = fotoUrls[index];
        }
      }

      await progressRepo.addProgress(userId, {
        'data': DateTime.now(),
        'peso': peso,
        'medidas': medidas,
        'fotos': fotoUrls,
        'fotosPorPosicao': fotosPorPosicao,
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
