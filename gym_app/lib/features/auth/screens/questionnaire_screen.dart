import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/config/app_colors.dart';
import '../../../data/models/questionnaire_response_model.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/providers/global_providers.dart';
import '../providers/auth_provider.dart';

class QuestionnaireScreen extends ConsumerStatefulWidget {
  final UserModel user;
  const QuestionnaireScreen({super.key, required this.user});

  static const version = QuestionnaireResponse.currentVersion;

  @override
  ConsumerState<QuestionnaireScreen> createState() =>
      _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends ConsumerState<QuestionnaireScreen> {
  static const _choiceOptions = <String, List<String>>{
    'activity': ['Sim, regularmente', 'Às vezes', 'Ainda não'],
    'sedentary': ['Sim', 'Não', 'Não sei'],
    'meals': ['1–2', '3', '4–5', '6 ou mais'],
    'water': ['Menos de 1 L', '1–2 L', '2–3 L', 'Mais de 3 L'],
    'sleep': ['Menos de 5 h', '5–6 h', '7–8 h', 'Mais de 8 h'],
    'objective': [
      'Perder gordura',
      'Ganhar massa muscular',
      'Melhorar a condição física',
      'Reeducação alimentar',
      'Outro',
    ],
  };

  static const _textIds = [
    'profession',
    'pathologies',
    'familyPathologies',
    'surgery',
    'medication',
    'allergies',
    'dislikedFoods',
    'preferredFoods',
    'outsideMeals',
  ];

  late final Map<String, TextEditingController> _controllers;
  final Map<String, String> _choices = {};
  int _step = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final id in _textIds) id: TextEditingController(),
      'birthDate': TextEditingController(),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(1920),
      lastDate: now,
      initialDate: DateTime(now.year - 25),
      helpText: 'Seleciona a data de nascimento',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );
    if (!mounted || date == null) return;
    _controllers['birthDate']!.text =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    setState(() {});
  }

  bool _validateStep() {
    final required = switch (_step) {
      0 => [
          'birthDate',
          'profession',
          'activity',
          'sedentary',
          'meals',
          'water',
          'sleep',
        ],
      1 => ['pathologies', 'familyPathologies', 'surgery', 'medication'],
      _ => [
          'allergies',
          'dislikedFoods',
          'preferredFoods',
          'outsideMeals',
          'objective',
        ],
    };
    final missing = required.where((id) {
      final value = _choices[id] ?? _controllers[id]?.text ?? '';
      return value.trim().isEmpty;
    }).toList();
    if (missing.isEmpty) return true;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preenche todos os campos desta etapa.')),
    );
    return false;
  }

  void _next() {
    if (!_validateStep()) return;
    if (_step < 2) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    if (!_validateStep()) return;
    setState(() => _saving = true);
    final answers = <String, String>{
      for (final id in _textIds) id: _controllers[id]!.text.trim(),
      'birthDate': _controllers['birthDate']!.text.trim(),
      ..._choices,
    };
    try {
      await ref.read(userRepositoryProvider).saveQuestionnaire(
            widget.user.uid,
            QuestionnaireResponse(
              version: QuestionnaireResponse.currentVersion,
              completedAt: DateTime.now(),
              answers: answers,
            ),
          );
      await ref.read(authProvider.notifier).refreshUser();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível guardar as respostas. Tenta novamente.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide.none,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.assignment_turned_in_outlined,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Vamos conhecer-te melhor',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Antes de começares, responde a esta ficha rápida. As respostas ficam disponíveis apenas para a equipa que te acompanha.',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    height: 1.45,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      _buildProgress(colors),
                      const SizedBox(height: 24),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: _buildStepContent(),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          if (_step > 0)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _saving
                                    ? null
                                    : () => setState(() => _step--),
                                child: const Text('Anterior'),
                              ),
                            ),
                          if (_step > 0) const SizedBox(width: 10),
                          Expanded(
                            flex: _step == 0 ? 1 : 2,
                            child: ElevatedButton(
                              onPressed: _saving ? null : _next,
                              child: _saving
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(_step == 2 ? 'Concluir ficha' : 'Continuar'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Esta etapa é necessária para desbloquear o início.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgress(ColorScheme colors) {
    final labels = ['Perfil', 'Saúde', 'Objetivos'];
    return Row(
      children: [
        for (var index = 0; index < labels.length; index++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: index <= _step
                        ? colors.primary
                        : colors.primaryContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  labels[index],
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: index == _step ? FontWeight.w700 : FontWeight.w500,
                    color: index <= _step
                        ? colors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (index < labels.length - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }

  Widget _buildStepContent() {
    return KeyedSubtree(
      key: ValueKey(_step),
      child: switch (_step) {
        0 => _buildProfileStep(),
        1 => _buildHealthStep(),
        _ => _buildGoalsStep(),
      },
    );
  }

  Widget _buildProfileStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Sobre ti', 'Informação básica para personalizar o acompanhamento.'),
        const SizedBox(height: 16),
        _textField('birthDate', 'Data de nascimento', readOnly: true, onTap: _pickBirthDate),
        const SizedBox(height: 12),
        _textField('profession', 'Profissão', hint: 'Ex.: estudante, professora, motorista'),
        const SizedBox(height: 18),
        _choiceField('activity', 'Já praticas ginásio ou algum desporto?'),
        _choiceField('sedentary', 'Consideras-te uma pessoa sedentária?'),
        _choiceField('meals', 'Quantas refeições costumas fazer por dia?'),
        _choiceField('water', 'Que quantidade de água bebes diariamente?'),
        _choiceField('sleep', 'Em média, quantas horas dormes?'),
      ],
    );
  }

  Widget _buildHealthStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Saúde e rotina', 'Responde com transparência. Se não se aplicar, escreve “Nenhum”.'),
        const SizedBox(height: 16),
        _textField('pathologies', 'Tens alguma patologia, lesão ou limitação?', multiline: true),
        const SizedBox(height: 12),
        _textField('familyPathologies', 'Existe histórico familiar relevante?', multiline: true),
        const SizedBox(height: 12),
        _textField('surgery', 'Foste operado/a nos últimos 5 anos? Se sim, porquê?', multiline: true),
        const SizedBox(height: 12),
        _textField('medication', 'Fazes alguma medicação ou tomas suplementos?', multiline: true),
      ],
    );
  }

  Widget _buildGoalsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Alimentação e objetivo', 'Estas respostas ajudam a preparar um plano realista para ti.'),
        const SizedBox(height: 16),
        _textField('allergies', 'Tens alergias ou intolerâncias alimentares?', multiline: true),
        const SizedBox(height: 12),
        _textField('dislikedFoods', 'Que alimentos não gostas ou preferes evitar?', multiline: true),
        const SizedBox(height: 12),
        _textField('preferredFoods', 'Que alimentos gostas e tens facilidade em comer?', multiline: true),
        const SizedBox(height: 12),
        _textField('outsideMeals', 'Quantas vezes por semana comes fora, fast food ou doces?', multiline: true),
        const SizedBox(height: 16),
        _choiceField('objective', 'Qual é o teu objetivo principal?'),
      ],
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _textField(
    String id,
    String label, {
    String? hint,
    bool readOnly = false,
    bool multiline = false,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: _controllers[id],
      readOnly: readOnly,
      onTap: onTap,
      minLines: multiline ? 2 : 1,
      maxLines: multiline ? 4 : 1,
      textInputAction: multiline ? TextInputAction.newline : TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: readOnly ? const Icon(Icons.calendar_today_outlined, size: 18) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _choiceField(String id, String label) {
    final options = _choiceOptions[id]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        initialValue: _choices[id],
        isDense: true,
        menuMaxHeight: 320,
        elevation: 2,
        borderRadius: BorderRadius.circular(14),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        items: options
            .map(
              (option) => DropdownMenuItem(
                value: option,
                child: Text(
                  option,
                  style: GoogleFonts.inter(fontSize: 13),
                ),
              ),
            )
            .toList(),
        onChanged: _saving ? null : (value) => setState(() => _choices[id] = value ?? ''),
      ),
    );
  }
}
