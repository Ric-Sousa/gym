import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/config/app_colors.dart';
import '../../../core/config/student_theme.dart';
import '../../../data/models/questionnaire_response_model.dart';
import '../../../data/models/questionnaire_config_model.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/providers/admin_providers.dart';
import '../../../shared/widgets/app_design_system.dart';
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
    'genero': {'masculino': 'Masculino', 'feminino': 'Feminino'},
  };

  static const _textIds = [
    'profession',
    'pathologies',
    'familyPathologies',
    'surgery',
    'medication',
    'supplements',
    'allergies',
    'dislikedFoods',
    'preferredFoods',
    'outsideMeals',
  ];

  static const _profileBinaryQuestions = <String, String>{
    'sedentary': 'Consideras-te uma pessoa sedentária?',
  };

  static const _healthBinaryQuestions = <String, String>{
    'pathologiesHas': 'Tens alguma patologia, lesão ou limitação?',
    'familyPathologiesHas': 'Existe histórico familiar relevante?',
    'surgeryHas': 'Foste operado/a nos últimos 5 anos?',
    'medicationHas': 'Tomas alguma medicação?',
    'supplementsHas': 'Tomas algum suplemento?',
    'allergiesHas': 'Tens alergias ou intolerâncias alimentares?',
  };

  late final Map<String, TextEditingController> _controllers;
  final Map<String, TextEditingController> _dynamicControllers = {};
  final Map<String, String> _choices = {};
  QuestionnaireConfig? _activeConfig;
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
    for (final controller in _dynamicControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final date = await showAppDatePicker(
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

  TextEditingController _controllerFor(String id) {
    final existing = _controllers[id] ?? _dynamicControllers[id];
    if (existing != null) return existing;
    return _dynamicControllers.putIfAbsent(id, TextEditingController.new);
  }

  void _syncConfiguredControllers(QuestionnaireConfig config) {
    for (final topic in config.topics) {
      for (final question in topic.questions) {
        final controller = _controllerFor(question.id);
        if (question.id == 'nome' &&
            controller.text.isEmpty &&
            widget.user.nome.trim().isNotEmpty) {
          controller.text = widget.user.nome.trim();
        }
        if (question.id == 'peso' &&
            controller.text.isEmpty &&
            widget.user.pesoAtual != null) {
          controller.text = widget.user.pesoAtual!.toString();
        }
        if (question.id == 'altura' &&
            controller.text.isEmpty &&
            widget.user.altura != null) {
          controller.text = widget.user.altura!.toString();
        }
        if (question.id == 'genero' &&
            _choices[question.id] == null &&
            widget.user.genero != null) {
          _choices[question.id] = widget.user.genero!;
        }
        if (question.id == 'birthDate' &&
            controller.text.isEmpty &&
            widget.user.dataNascimento != null) {
          final date = widget.user.dataNascimento!;
          controller.text =
              '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
        }
        if (question.hasDetail) _controllerFor(question.resolvedDetailId);
      }
    }
  }

  bool _validateConfiguredStep(QuestionnaireConfig config) {
    if (_step >= config.topics.length) return false;
    final missing = <String>[];
    for (final question in config.topics[_step].questions) {
      final value = question.type == 'text' || question.type == 'date'
          ? _controllerFor(question.id).text
          : _choices[question.id] ?? '';
      if (question.required && value.trim().isEmpty) missing.add(question.id);
      if (question.isBinary &&
          _choices[question.id] == 'sim' &&
          question.hasDetail &&
          _controllerFor(question.resolvedDetailId).text.trim().isEmpty) {
        missing.add(question.resolvedDetailId);
      }
    }
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preenche todos os campos desta etapa.')),
      );
      return false;
    }
    return true;
  }

  bool _validateStep() {
    if (_activeConfig != null) return _validateConfiguredStep(_activeConfig!);
    final required = switch (_step) {
      0 => [
        'birthDate',
        'genero',
        'profession',
        'activity',
        ..._profileBinaryQuestions.keys,
        'meals',
        'water',
        'sleep',
      ],
      1 => _healthBinaryQuestions.keys.toList(),
      _ => ['dislikedFoods', 'preferredFoods', 'outsideMeals', 'objective'],
    };
    final missing = <String>[];
    for (final id in required) {
      final value = _choices[id] ?? _controllers[id]?.text ?? '';
      if (value.trim().isEmpty) missing.add(id);
    }

    if (_step == 1) {
      const details = <String, String>{
        'pathologiesHas': 'pathologies',
        'familyPathologiesHas': 'familyPathologies',
        'surgeryHas': 'surgery',
        'medicationHas': 'medication',
        'supplementsHas': 'supplements',
        'allergiesHas': 'allergies',
      };
      for (final entry in details.entries) {
        if (_choices[entry.key] == 'sim' &&
            (_controllers[entry.value]?.text.trim().isEmpty ?? true)) {
          missing.add(entry.value);
        }
      }
    }

    if (missing.isEmpty) return true;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preenche todos os campos desta etapa.')),
    );
    return false;
  }

  void _next() {
    if (!_validateStep()) return;
    final lastStep = (_activeConfig?.topics.length ?? 3) - 1;
    if (_step < lastStep) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    if (!_validateStep()) return;
    setState(() => _saving = true);
    final answers = _activeConfig == null
        ? <String, String>{
            for (final id in _textIds) id: _controllers[id]!.text.trim(),
            'birthDate': _controllers['birthDate']!.text.trim(),
            ..._choices,
          }
        : <String, String>{
            for (final entry in _controllers.entries)
              entry.key: entry.value.text.trim(),
            for (final entry in _dynamicControllers.entries)
              entry.key: entry.value.text.trim(),
            ..._choices,
          };
    final config = _activeConfig;
    try {
      final version = config?.versionId ?? QuestionnaireResponse.currentVersion;
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) throw StateError('Sem sessão ativa.');

      // A callable pode reutilizar uma instância criada antes do login. Forçar
      // a renovação aqui não basta se o SDK ainda não terminou de propagar o
      // token; passar o token explicitamente torna a autenticação determinística
      // no Flutter Web e mantém a verificação no servidor.
      final idToken = await firebaseUser.getIdToken(true);
      final authNotifier = ref.read(authProvider.notifier);
      await FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('submitQuestionnaire').call({
        'version': version,
        'answers': answers,
        if (idToken != null && idToken.isNotEmpty) 'authToken': idToken,
      });
      authNotifier.markQuestionnaireCompleted(version);
      if (mounted) {
        setState(() => _saving = false);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      final message =
          error is FirebaseFunctionsException &&
              error.message != null &&
              error.message!.trim().isNotEmpty
          ? error.message!
          : 'Não foi possível guardar as respostas. Tenta novamente.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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
    final configured = ref.watch(questionnaireConfigProvider).asData?.value;
    if (configured != null) {
      _activeConfig = configured.topics.isEmpty ? null : configured;
      if (_activeConfig != null) _syncConfiguredControllers(_activeConfig!);
    }
    final questionnaireTheme = _buildQuestionnaireTheme(
      Theme.of(context),
      _choices['genero'],
    );
    final colors = questionnaireTheme.colorScheme;
    final topicCount = _activeConfig?.topics.length ?? 3;
    final lastStep = topicCount - 1;
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
                        _buildProgress(colors, _activeConfig),
                        SizedBox(height: compact ? 18 : 24),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: _buildStepContent(_activeConfig),
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
                                    : Text(
                                        _step == lastStep
                                            ? 'Concluir ficha'
                                            : 'Continuar',
                                      ),
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

  Widget _buildProgress(ColorScheme colors, QuestionnaireConfig? config) {
    final labels =
        config?.topics.map((topic) => topic.title).toList() ??
        ['Perfil', 'Saúde', 'Objetivos'];
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
                    fontWeight: index == _step
                        ? FontWeight.w700
                        : FontWeight.w500,
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

  Widget _buildStepContent(QuestionnaireConfig? config) {
    final safeConfig =
        config != null &&
            config.topics.isNotEmpty &&
            _step < config.topics.length
        ? config
        : null;
    return KeyedSubtree(
      key: ValueKey(_step),
      child: safeConfig == null
          ? switch (_step) {
              0 => _buildProfileStep(),
              1 => _buildHealthStep(),
              _ => _buildGoalsStep(),
            }
          : _buildConfiguredStep(safeConfig.topics[_step]),
    );
  }

  Widget _buildConfiguredStep(QuestionnaireTopic topic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(topic.title, topic.description),
        const SizedBox(height: 16),
        ...topic.questions.expand((question) sync* {
          yield _buildConfiguredQuestion(question);
          if (question.isBinary &&
              _choices[question.id] == 'sim' &&
              question.hasDetail) {
            yield const SizedBox(height: 8);
            yield _textField(
              question.resolvedDetailId,
              question.detailLabel!,
              multiline: true,
              detail: true,
            );
          }
          // Os menus já têm espaçamento inferior próprio. Evita somar
          // outro intervalo aqui, especialmente entre Sexo e Peso.
          yield SizedBox(height: question.type == 'choice' ? 0 : 12);
        }),
      ],
    );
  }

  Widget _buildConfiguredQuestion(QuestionnaireQuestion question) {
    return switch (question.type) {
      'choice' => _choiceField(
        question.id,
        question.label,
        options: question.options,
      ),
      'binary' => _choiceField(
        question.id,
        question.label,
        options: question.options.isEmpty
            ? const ['sim', 'não']
            : question.options,
      ),
      'date' => _textField(
        question.id,
        question.label,
        readOnly: true,
        onTap: () => _pickConfiguredDate(question.id),
      ),
      _ => _textField(
        question.id,
        question.label,
        hint: question.hint,
        multiline: question.multiline,
      ),
    };
  }

  Future<void> _pickConfiguredDate(String id) async {
    final now = DateTime.now();
    final date = await showAppDatePicker(
      context: context,
      firstDate: DateTime(1920),
      lastDate: now,
      initialDate: DateTime(now.year - 25),
      helpText: 'Seleciona a data',
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
    _controllerFor(id).text =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    setState(() {});
  }

  Widget _buildProfileStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Sobre ti',
          'Informação básica para personalizar o acompanhamento.',
        ),
        SizedBox(height: MediaQuery.sizeOf(context).width < 480 ? 12 : 16),
        _textField(
          'birthDate',
          'Data de nascimento',
          readOnly: true,
          onTap: _pickBirthDate,
        ),
        const SizedBox(height: 12),
        _choiceField('genero', 'Qual é o teu sexo?'),
        _textField(
          'profession',
          'Profissão',
          hint: 'Ex.: estudante, professora, motorista',
        ),
        SizedBox(height: MediaQuery.sizeOf(context).width < 480 ? 12 : 18),
        _choiceField('activity', 'Já praticas ginásio ou algum desporto?'),
        _binaryField('sedentary', _profileBinaryQuestions['sedentary']!),
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
        _sectionTitle(
          'Saúde e rotina',
          'Assinala Sim ou Não. Se responderes Sim, descreve a situação.',
        ),
        const SizedBox(height: 16),
        _binaryField(
          'pathologiesHas',
          _healthBinaryQuestions['pathologiesHas']!,
        ),
        if (_choices['pathologiesHas'] == 'sim') ...[
          const SizedBox(height: 8),
          _textField(
            'pathologies',
            'Descreve a patologia, lesão ou limitação',
            multiline: true,
            detail: true,
          ),
        ],
        const SizedBox(height: 12),
        _binaryField(
          'familyPathologiesHas',
          _healthBinaryQuestions['familyPathologiesHas']!,
        ),
        if (_choices['familyPathologiesHas'] == 'sim') ...[
          const SizedBox(height: 8),
          _textField(
            'familyPathologies',
            'Descreve o histórico familiar relevante',
            multiline: true,
            detail: true,
          ),
        ],
        const SizedBox(height: 12),
        _binaryField('surgeryHas', _healthBinaryQuestions['surgeryHas']!),
        if (_choices['surgeryHas'] == 'sim') ...[
          const SizedBox(height: 8),
          _textField(
            'surgery',
            'Indica qual foi a cirurgia e quando aconteceu',
            multiline: true,
            detail: true,
          ),
        ],
        const SizedBox(height: 12),
        _binaryField('medicationHas', _healthBinaryQuestions['medicationHas']!),
        if (_choices['medicationHas'] == 'sim') ...[
          const SizedBox(height: 8),
          _textField(
            'medication',
            'Qual medicação tomas?',
            multiline: true,
            detail: true,
          ),
        ],
        const SizedBox(height: 12),
        _binaryField(
          'supplementsHas',
          _healthBinaryQuestions['supplementsHas']!,
        ),
        if (_choices['supplementsHas'] == 'sim') ...[
          const SizedBox(height: 8),
          _textField(
            'supplements',
            'Quais suplementos tomas?',
            multiline: true,
            detail: true,
          ),
        ],
        const SizedBox(height: 12),
        _binaryField('allergiesHas', _healthBinaryQuestions['allergiesHas']!),
        if (_choices['allergiesHas'] == 'sim') ...[
          const SizedBox(height: 8),
          _textField(
            'allergies',
            'Indica as alergias ou intolerâncias',
            multiline: true,
            detail: true,
          ),
        ],
      ],
    );
  }

  Widget _buildGoalsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Alimentação e objetivo',
          'Estas respostas ajudam a preparar um plano realista para ti.',
        ),
        const SizedBox(height: 16),
        _textField(
          'dislikedFoods',
          'Que alimentos não gostas ou preferes evitar?',
          multiline: true,
        ),
        const SizedBox(height: 12),
        _textField(
          'preferredFoods',
          'Que alimentos gostas e tens facilidade em comer?',
          multiline: true,
        ),
        const SizedBox(height: 12),
        _textField(
          'outsideMeals',
          'Quantas vezes por semana comes fora, fast food ou doces?',
          multiline: true,
        ),
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
    bool detail = false,
    VoidCallback? onTap,
  }) {
    final compact = MediaQuery.sizeOf(context).width < 480;
    final field = TextField(
      controller: _controllerFor(id),
      cursorColor: Colors.white,
      style: GoogleFonts.inter(
        fontSize: compact ? 12 : 13,
        color: AppColors.onSurface,
      ),
      readOnly: readOnly,
      onTap: onTap,
      minLines: multiline ? (detail ? 1 : 2) : 1,
      maxLines: multiline ? (detail ? 3 : 4) : 1,
      textInputAction: multiline
          ? TextInputAction.newline
          : TextInputAction.next,
      textAlign: TextAlign.center,
      // Mantém o texto no centro do campo mesmo quando o label flutua.
      // O alinhamento anterior com y positivo fazia o conteúdo parecer colado
      // à parte superior do input destacado.
      textAlignVertical: TextAlignVertical.center,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint ?? (detail ? 'Descreve aqui...' : null),
        contentPadding: EdgeInsets.symmetric(
          horizontal: detail ? 12 : 14,
          vertical: detail ? 12 : 12,
        ),
        alignLabelWithHint: false,
        filled: true,
        fillColor: detail ? AppColors.surfaceHigh : AppColors.surface,
        suffixIcon: readOnly
            ? const Icon(Icons.calendar_today_outlined, size: 18)
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: detail
              ? BorderSide(color: _questionnairePrimary.withValues(alpha: 0.35))
              : BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: detail
              ? BorderSide(color: _questionnairePrimary.withValues(alpha: 0.35))
              : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: detail ? _questionnairePrimary : Colors.transparent,
            width: detail ? 1.2 : 0,
          ),
        ),
        labelStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: compact ? 12 : 14,
        ),
        floatingLabelStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: detail ? (compact ? 11 : 12) : (compact ? 12 : 14),
        ),
      ),
    );

    if (!detail) return field;
    return Align(
      alignment: Alignment.center,
      child: FractionallySizedBox(
        widthFactor: compact ? 0.86 : 0.82,
        child: field,
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

  Widget _binaryField(String id, String label) {
    return _choiceField(id, label, options: const ['sim', 'não']);
  }

  String _choiceDisplayLabel(String id, String value) {
    return _choiceLabels[id]?[value] ??
        switch (value) {
          'sim' => 'Sim',
          'não' => 'Não',
          _ => value,
        };
  }

  Widget _choiceField(String id, String label, {List<String>? options}) {
    final resolvedOptions = options ?? _choiceOptions[id]!;
    final selected = _choices[id];
    final primary = _questionnairePrimary;

    final compact = MediaQuery.sizeOf(context).width < 480;
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 10 : 14),
      child: AppMenuDropdown<String>(
        value: selected,
        options: resolvedOptions,
        labelBuilder: (option) => _choiceDisplayLabel(id, option),
        onChanged: (option) => setState(() => _choices[id] = option),
        label: label,
        accentColor: primary,
        fieldColor: AppColors.surface,
        menuColor: AppColors.surfaceHighest,
        textColor: AppColors.onSurface,
        labelColor: Colors.white,
        enabled: !_saving,
      ),
    );
  }
}
