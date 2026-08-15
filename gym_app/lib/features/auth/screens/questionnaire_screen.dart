import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/config/app_colors.dart';
import '../../../core/config/student_theme.dart';
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
    'genero': ['masculino', 'feminino'],
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

  static const _choiceLabels = <String, Map<String, String>>{
    'genero': {
      'masculino': 'Masculino',
      'feminino': 'Feminino',
    },
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
      builder: (dialogContext, child) => Theme(
        data: _buildQuestionnaireTheme(
          Theme.of(dialogContext),
          _choices['genero'],
        ),
        child: child!,
      ),
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
          'genero',
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
            genero: _choices['genero'],
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

  ThemeData _buildQuestionnaireTheme(ThemeData base, String? genero) {
    final hasSelectedGender = genero == 'masculino' || genero == 'feminino';
    final genderColors = hasSelectedGender
        ? StudentThemeColors.forGenero(genero)
        : null;
    final primary = genderColors?.primary ?? AppColors.surfaceHighest;
    final primaryContainer =
        genderColors?.primaryContainer ?? AppColors.surfaceHigh;
    final onPrimary = hasSelectedGender ? Colors.white : AppColors.onSurface;

    return base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: hasSelectedGender
            ? Colors.white
            : AppColors.onSurface,
        surface: AppColors.surfaceLow,
        onSurface: AppColors.onSurface,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
      ),
      cardTheme: base.cardTheme.copyWith(
        color: AppColors.surfaceLow,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide.none,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: Colors.white,
        selectionColor: Colors.white.withValues(alpha: 0.22),
        selectionHandleColor: Colors.white,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: AppColors.surface,
        labelStyle: GoogleFonts.inter(color: Colors.white),
        floatingLabelStyle: GoogleFonts.inter(color: Colors.white),
        hintStyle: GoogleFonts.inter(color: AppColors.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final questionnaireTheme = _buildQuestionnaireTheme(
      Theme.of(context),
      _choices['genero'],
    );
    final colors = questionnaireTheme.colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 480;
    return Theme(
      data: questionnaireTheme,
      child: Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(compact ? 12 : 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide.none,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 18 : 24,
                    compact ? 20 : 26,
                    compact ? 18 : 24,
                    compact ? 16 : 22,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
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
                          ),
                          SizedBox(height: compact ? 10 : 14),
                          Text(
                            'Vamos conhecer-te melhor',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(
                              fontSize: compact ? 19 : 21,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Antes de começares, responde a esta ficha rápida. As respostas ficam disponíveis apenas para a equipa que te acompanha.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: compact ? 12 : 13,
                              height: compact ? 1.35 : 1.45,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: compact ? 16 : 22),
                      _buildProgress(colors),
                      SizedBox(height: compact ? 18 : 24),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: _buildStepContent(),
                      ),
                      SizedBox(height: compact ? 16 : 22),
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
                    fontSize: MediaQuery.sizeOf(context).width < 480 ? 10 : 11,
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
        SizedBox(height: MediaQuery.sizeOf(context).width < 480 ? 12 : 16),
        _textField('birthDate', 'Data de nascimento', readOnly: true, onTap: _pickBirthDate),
        const SizedBox(height: 12),
        _choiceField('genero', 'Qual é o teu sexo?'),
        _textField('profession', 'Profissão', hint: 'Ex.: estudante, professora, motorista'),
        SizedBox(height: MediaQuery.sizeOf(context).width < 480 ? 12 : 18),
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
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            fontSize: MediaQuery.sizeOf(context).width < 480 ? 16 : 18,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: MediaQuery.sizeOf(context).width < 480 ? 11 : 12,
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
    final compact = MediaQuery.sizeOf(context).width < 480;
    return TextField(
      controller: _controllers[id],
      cursorColor: Colors.white,
      style: GoogleFonts.inter(
        fontSize: compact ? 12 : 13,
        color: AppColors.onSurface,
      ),
      readOnly: readOnly,
      onTap: onTap,
      minLines: multiline ? 2 : 1,
      maxLines: multiline ? 4 : 1,
      textInputAction: multiline ? TextInputAction.newline : TextInputAction.next,
      textAlign: TextAlign.center,
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
        labelStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: compact ? 12 : 14,
        ),
        floatingLabelStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: compact ? 12 : 14,
        ),
      ),
    );
  }

  Color get _questionnairePrimary {
    final genero = _choices['genero'];
    if (genero == 'masculino' || genero == 'feminino') {
      return StudentThemeColors.forGenero(genero).primary;
    }
    return AppColors.surfaceHighest;
  }

  Widget _choiceField(String id, String label) {
    final options = _choiceOptions[id]!;
    final selected = _choices[id];
    final selectedLabel = selected == null
        ? null
        : (_choiceLabels[id]?[selected] ?? selected);
    final primary = _questionnairePrimary;

    final compact = MediaQuery.sizeOf(context).width < 480;
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 10 : 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fieldWidth = constraints.maxWidth;
          return MenuAnchor(
            crossAxisUnconstrained: false,
            alignmentOffset: const Offset(0, 4),
            style: MenuStyle(
              backgroundColor: const WidgetStatePropertyAll(
                AppColors.surfaceHighest,
              ),
              elevation: const WidgetStatePropertyAll(3),
              minimumSize: WidgetStatePropertyAll(
                Size(fieldWidth, 0),
              ),
              maximumSize: WidgetStatePropertyAll(
                Size(fieldWidth, 320),
              ),
              shape: const WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
              ),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(vertical: 6),
              ),
            ),
            menuChildren: options
                .map(
                  (option) => MenuItemButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() => _choices[id] = option),
                    child: SizedBox(
                      width: fieldWidth - 28,
                      child: Text(
                        _choiceLabels[id]?[option] ?? option,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: compact ? 12 : 13,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
            builder: (context, controller, child) => GestureDetector(
              onTap: _saving
                  ? null
                  : () {
                      if (controller.isOpen) {
                        controller.close();
                      } else {
                        controller.open();
                      }
                    },
              child: InputDecorator(
                isFocused: controller.isOpen,
                isEmpty: selectedLabel == null,
                decoration: InputDecoration(
                  labelText: label,
                  filled: true,
                  fillColor: AppColors.surface,
                  isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 14,
          vertical: compact ? 10 : 12,
        ),
                  suffixIcon: Icon(
                    controller.isOpen
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: primary,
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
                  floatingLabelStyle: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: compact ? 12 : 14,
                  ),
                  labelStyle: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: compact ? 12 : 14,
                  ),
                ),
                child: Text(
                  selectedLabel ?? '',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: compact ? 12 : 13,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
