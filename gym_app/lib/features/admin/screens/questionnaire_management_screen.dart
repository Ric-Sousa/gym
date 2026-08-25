import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/config/admin_theme.dart';
import '../../../data/models/questionnaire_config_model.dart';
import '../../../shared/providers/admin_providers.dart';
import '../../../shared/providers/global_providers.dart';
import '../../../shared/widgets/admin_design_system.dart';
import '../../../shared/widgets/admin_responsive_dialog.dart';
import '../../../shared/widgets/app_design_system.dart';
import '../../../shared/widgets/focused_text_field.dart';

class QuestionnaireManagementScreen extends ConsumerWidget {
  const QuestionnaireManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(questionnaireConfigProvider);
    return AdminPageFrame(
      child: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErrorState(
          onRetry: () => ref.invalidate(questionnaireConfigProvider),
        ),
        data: (config) => _QuestionnaireEditor(config: config),
      ),
    );
  }
}

class _QuestionnaireEditor extends ConsumerStatefulWidget {
  final QuestionnaireConfig config;

  const _QuestionnaireEditor({required this.config});

  @override
  ConsumerState<_QuestionnaireEditor> createState() =>
      _QuestionnaireEditorState();
}

class _QuestionnaireEditorState extends ConsumerState<_QuestionnaireEditor> {
  bool _saving = false;

  Future<void> _save(QuestionnaireConfig config) async {
    setState(() => _saving = true);
    try {
      await ref.read(userRepositoryProvider).saveQuestionnaireConfig(config);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Questionário atualizado para novos acessos.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível guardar o questionário.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addTopic() async {
    final topic = await _showTopicDialog(context);
    if (topic == null) return;
    await _save(
      widget.config.copyWith(topics: [...widget.config.topics, topic]),
    );
  }

  Future<void> _editTopic(int index) async {
    final topic = await _showTopicDialog(
      context,
      initial: widget.config.topics[index],
    );
    if (topic == null) return;
    final topics = [...widget.config.topics]..[index] = topic;
    await _save(widget.config.copyWith(topics: topics));
  }

  Future<void> _deleteTopic(int index) async {
    final topic = widget.config.topics[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar tópico?'),
        content: Text(
          'As ${topic.questions.length} perguntas de “${topic.title}” também serão removidas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AdminThemeColors.of(context).danger,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final topics = [...widget.config.topics]..removeAt(index);
    await _save(widget.config.copyWith(topics: topics));
  }

  Future<void> _addQuestion(int topicIndex) async {
    final question = await _showQuestionDialog(context);
    if (question == null) return;
    final topics = [...widget.config.topics];
    topics[topicIndex] = topics[topicIndex].copyWith(
      questions: [...topics[topicIndex].questions, question],
    );
    await _save(widget.config.copyWith(topics: topics));
  }

  Future<void> _editQuestion(int topicIndex, int questionIndex) async {
    final topic = widget.config.topics[topicIndex];
    final question = await _showQuestionDialog(
      context,
      initial: topic.questions[questionIndex],
    );
    if (question == null) return;
    final questions = [...topic.questions]..[questionIndex] = question;
    final topics = [...widget.config.topics]
      ..[topicIndex] = topic.copyWith(questions: questions);
    await _save(widget.config.copyWith(topics: topics));
  }

  Future<void> _deleteQuestion(int topicIndex, int questionIndex) async {
    final topic = widget.config.topics[topicIndex];
    final question = topic.questions[questionIndex];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar pergunta?'),
        content: Text(
          '“${question.label}” deixará de aparecer para novos alunos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AdminThemeColors.of(context).danger,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final questions = [...topic.questions]..removeAt(questionIndex);
    final topics = [...widget.config.topics]
      ..[topicIndex] = topic.copyWith(questions: questions);
    await _save(widget.config.copyWith(topics: topics));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminPageHeader(
          title: 'QUESTIONÁRIO INICIAL',
          subtitle:
              'Organiza os tópicos e as perguntas que o aluno responde no primeiro acesso.',
          icon: Icons.assignment_outlined,
          action: FilledButton.icon(
            onPressed: _saving ? null : _addTopic,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Novo tópico'),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'O aluno mantém o layout atual da ficha. As alterações aplicam-se à próxima ficha apresentada.',
          style: GoogleFonts.inter(fontSize: 12, color: colors.muted),
        ),
        const SizedBox(height: 22),
        if (widget.config.topics.isEmpty)
          _EmptyState(onAdd: _addTopic)
        else
          ...widget.config.topics.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _TopicCard(
                topic: entry.value,
                onEdit: entry.value.isProtected || _saving
                    ? null
                    : () => _editTopic(entry.key),
                onDelete: entry.value.isProtected || _saving
                    ? null
                    : () => _deleteTopic(entry.key),
                onAddQuestion: entry.value.isProtected || _saving
                    ? null
                    : () => _addQuestion(entry.key),
                onEditQuestion: entry.value.isProtected || _saving
                    ? null
                    : (questionIndex) =>
                          _editQuestion(entry.key, questionIndex),
                onDeleteQuestion: entry.value.isProtected || _saving
                    ? null
                    : (questionIndex) =>
                          _deleteQuestion(entry.key, questionIndex),
              ),
            ),
          ),
        if (_saving)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.lime,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'A guardar alterações...',
                  style: GoogleFonts.inter(fontSize: 12, color: colors.muted),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TopicCard extends StatelessWidget {
  final QuestionnaireTopic topic;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddQuestion;
  final ValueChanged<int>? onEditQuestion;
  final ValueChanged<int>? onDeleteQuestion;

  const _TopicCard({
    required this.topic,
    required this.onEdit,
    required this.onDelete,
    required this.onAddQuestion,
    required this.onEditQuestion,
    required this.onDeleteQuestion,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
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
                  color: colors.limeDim,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.topic_outlined, color: colors.lime, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.title,
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: colors.text,
                      ),
                    ),
                    if (topic.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        topic.description,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: colors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (topic.isProtected)
                Tooltip(
                  message: 'Tópico obrigatório e protegido',
                  child: Icon(Icons.lock_outline, color: colors.lime, size: 19),
                )
              else ...[
                IconButton(
                  onPressed: onEdit,
                  tooltip: 'Editar tópico',
                  icon: Icon(
                    Icons.edit_outlined,
                    color: colors.muted,
                    size: 19,
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'Eliminar tópico',
                  icon: Icon(
                    Icons.delete_outline,
                    color: colors.danger,
                    size: 19,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (topic.questions.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Ainda não existem perguntas neste tópico.',
                style: GoogleFonts.inter(fontSize: 12, color: colors.muted),
              ),
            )
          else
            ...topic.questions.asMap().entries.map(
              (entry) => _QuestionRow(
                question: entry.value,
                protected: topic.isProtected,
                onEdit: onEditQuestion == null
                    ? null
                    : () => onEditQuestion!(entry.key),
                onDelete: onDeleteQuestion == null
                    ? null
                    : () => onDeleteQuestion!(entry.key),
              ),
            ),
          if (topic.isProtected)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: colors.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Este tópico é obrigatório e não pode ser alterado.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: colors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: onAddQuestion,
                icon: const Icon(Icons.add, size: 17),
                label: const Text('Adicionar pergunta'),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuestionRow extends StatelessWidget {
  final QuestionnaireQuestion question;
  final bool protected;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _QuestionRow({
    required this.question,
    required this.protected,
    required this.onEdit,
    required this.onDelete,
  });

  String get typeLabel => switch (question.type) {
    'choice' => 'Menu com opções',
    'binary' => 'Sim / Não',
    'date' => 'Data',
    _ => 'Texto',
  };

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          color: colors.surface2.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              question.isBinary ? Icons.toggle_on_outlined : Icons.help_outline,
              size: 18,
              color: colors.lime,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question.label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${typeLabel}${question.hasDetail ? ' · abre campo de detalhe ao escolher Sim' : ''}',
                    style: GoogleFonts.inter(fontSize: 11, color: colors.muted),
                  ),
                ],
              ),
            ),
            if (protected)
              Tooltip(
                message: 'Campo obrigatório do aluno',
                child: Icon(Icons.lock_outline, size: 18, color: colors.lime),
              )
            else ...[
              IconButton(
                onPressed: onEdit,
                tooltip: 'Editar pergunta',
                icon: Icon(Icons.edit_outlined, size: 18, color: colors.muted),
              ),
              IconButton(
                onPressed: onDelete,
                tooltip: 'Eliminar pergunta',
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: colors.danger,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<QuestionnaireTopic?> _showTopicDialog(
  BuildContext context, {
  QuestionnaireTopic? initial,
}) {
  return showDialog<QuestionnaireTopic>(
    context: context,
    builder: (_) => _TopicDialog(initial: initial),
  );
}

class _TopicDialog extends StatefulWidget {
  final QuestionnaireTopic? initial;

  const _TopicDialog({this.initial});

  @override
  State<_TopicDialog> createState() => _TopicDialogState();
}

class _TopicDialogState extends State<_TopicDialog> {
  late String _title;
  late String _description;

  @override
  void initState() {
    super.initState();
    _title = widget.initial?.title ?? '';
    _description = widget.initial?.description ?? '';
  }

  void _save() {
    final title = _title.trim();
    if (title.isEmpty) return;
    final initial = widget.initial;
    Navigator.of(context).pop(
      QuestionnaireTopic(
        id: initial?.id ?? 'topic-${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        description: _description.trim(),
        questions: initial?.questions ?? const [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminResponsiveDialog(
      title: widget.initial == null ? 'Novo tópico' : 'Editar tópico',
      subtitle: 'Agrupa perguntas relacionadas para o aluno.',
      icon: Icons.topic_outlined,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
      child: Column(
        children: [
          FocusedTextFormField(
            initialValue: _title,
            autofocus: true,
            onChanged: (value) => _title = value,
            focusedFillColor: AdminThemeColors.of(context).surface2,
            decoration: const InputDecoration(
              labelText: 'Nome do tópico',
              hintText: 'Ex.: Saúde e rotina',
            ),
          ),
          const SizedBox(height: 14),
          FocusedTextFormField(
            key: const ValueKey('admin-topic-description-field'),
            initialValue: _description,
            maxLines: 2,
            onChanged: (value) => _description = value,
            focusedFillColor: AdminThemeColors.of(context).surface2,
            decoration: const InputDecoration(
              labelText: 'Descrição (opcional)',
            ),
          ),
        ],
      ),
    );
  }
}

Future<QuestionnaireQuestion?> _showQuestionDialog(
  BuildContext context, {
  QuestionnaireQuestion? initial,
}) {
  return showDialog<QuestionnaireQuestion>(
    context: context,
    builder: (_) => _QuestionDialog(initial: initial),
  );
}

class _OptionDraft {
  final int id;
  String text;

  _OptionDraft({required this.id, this.text = ''});
}

class _QuestionDialog extends StatefulWidget {
  final QuestionnaireQuestion? initial;

  const _QuestionDialog({this.initial});

  @override
  State<_QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<_QuestionDialog> {
  late String _label;
  late String _hint;
  late String _detail;
  late String _type;
  late bool _required;
  late List<_OptionDraft> _optionDrafts;
  String? _optionsError;
  String? _previewChoice;
  DateTime? _previewDate;
  int _nextOptionId = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _label = initial?.label ?? '';
    _hint = initial?.hint ?? '';
    _detail = initial?.detailLabel ?? '';
    _type = initial?.type ?? 'text';
    _required = initial?.required ?? true;
    _optionDrafts = [
      for (final option in initial?.options ?? const <String>[])
        _newOptionDraft(option),
    ];
    if (_type == 'choice' && _optionDrafts.isEmpty) {
      _optionDrafts.add(_newOptionDraft());
    }
  }

  _OptionDraft _newOptionDraft([String text = '']) {
    return _OptionDraft(id: _nextOptionId++, text: text);
  }

  void _ensureChoiceOption() {
    if (_optionDrafts.isEmpty) {
      _optionDrafts.add(_newOptionDraft());
    }
  }

  List<String> get _choiceOptions => _optionDrafts
      .map((draft) => draft.text.trim())
      .where((option) => option.isNotEmpty)
      .toList();

  void _selectType(String value) {
    setState(() {
      _type = value;
      _optionsError = null;
      if (_type == 'choice') _ensureChoiceOption();
      if (_type != 'choice') _previewChoice = null;
    });
  }

  void _save() {
    final label = _label.trim();
    if (label.isEmpty) return;
    final initial = widget.initial;
    final id =
        initial?.id ?? 'question-${DateTime.now().millisecondsSinceEpoch}';
    final options = _type == 'binary' ? const ['sim', 'não'] : _choiceOptions;
    if (_type == 'choice' && options.isEmpty) {
      setState(() => _optionsError = 'Adiciona pelo menos uma opção.');
      return;
    }
    final detail = _detail.trim();

    Navigator.of(context).pop(
      QuestionnaireQuestion(
        id: id,
        label: label,
        type: _type,
        options: options,
        required: _required,
        hint: _hint.trim().isEmpty ? null : _hint.trim(),
        detailId: _type == 'binary' && detail.isNotEmpty
            ? (initial?.detailId ?? '${id}_details')
            : null,
        detailLabel: _type == 'binary' && detail.isNotEmpty ? detail : null,
      ),
    );
  }

  Widget _buildOptionsEditor(AdminThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Opções do menu',
                style: TextStyle(
                  color: colors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${_choiceOptions.length} ${_choiceOptions.length == 1 ? 'opção' : 'opções'}',
              style: TextStyle(color: colors.muted, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._optionDrafts.asMap().entries.map((entry) {
          final index = entry.key;
          final draft = entry.value;
          return Padding(
            key: ValueKey('question-option-${draft.id}'),
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 13, right: 8),
                  child: Text(
                    '${index + 1}.',
                    style: TextStyle(color: colors.muted, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: FocusedTextFormField(
                    fieldKey: ValueKey('question-option-field-${draft.id}'),
                    initialValue: draft.text,
                    focusedFillColor: colors.surface2,
                    onChanged: (value) {
                      draft.text = value;
                      if (_optionsError != null) {
                        setState(() => _optionsError = null);
                      } else {
                        setState(() {});
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Opção ${index + 1}',
                      hintText: 'Ex.: Às vezes',
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remover opção',
                  onPressed: _optionDrafts.length == 1
                      ? null
                      : () => setState(() {
                          _optionDrafts.removeAt(index);
                          if (_previewChoice != null &&
                              !_choiceOptions.contains(_previewChoice)) {
                            _previewChoice = null;
                          }
                        }),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              ],
            ),
          );
        }),
        if (_optionsError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _optionsError!,
              style: TextStyle(color: colors.danger, fontSize: 11),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => setState(() => _optionDrafts.add(_newOptionDraft())),
          icon: const Icon(Icons.add, size: 17),
          label: const Text('Adicionar opção'),
        ),
      ],
    );
  }

  Future<void> _pickPreviewDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      initialDate: _previewDate ?? DateTime(2000),
      helpText: 'Pré-visualização da data',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );
    if (mounted && date != null) setState(() => _previewDate = date);
  }

  Widget _buildPreviewChoiceField(
    AdminThemeColors colors,
    List<String> options,
  ) {
    final selected = options.contains(_previewChoice) ? _previewChoice : null;
    return AppMenuDropdown<String>(
      key: const ValueKey('admin-question-preview-menu'),
      value: selected,
      options: options,
      labelBuilder: (option) => option,
      onChanged: (option) => setState(() => _previewChoice = option),
      label: 'Seleciona uma opção',
      accentColor: colors.lime,
      fieldColor: colors.surface,
      menuColor: colors.surface2,
      textColor: colors.text,
      labelColor: colors.muted,
    );
  }

  Widget _buildPreview(AdminThemeColors colors) {
    final title = _label.trim().isEmpty ? 'Exemplo de pergunta' : _label.trim();
    final options = _choiceOptions;
    Widget field;

    switch (_type) {
      case 'choice':
        field = _buildPreviewChoiceField(colors, options);
        break;
      case 'binary':
        final selected = _previewChoice;
        field = Wrap(
          spacing: 8,
          children: ['sim', 'não'].map((option) {
            final label = option == 'sim' ? 'Sim' : 'Não';
            return ChoiceChip(
              label: Text(label),
              selected: selected == option,
              onSelected: (_) => setState(() => _previewChoice = option),
            );
          }).toList(),
        );
        break;
      case 'date':
        final date = _previewDate;
        field = TextFormField(
          readOnly: true,
          controller: null,
          onTap: _pickPreviewDate,
          decoration: InputDecoration(
            labelText: 'Data',
            hintText: date == null
                ? 'Clica para escolher uma data'
                : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
            suffixIcon: const Icon(Icons.calendar_today_outlined),
          ),
        );
        break;
      default:
        field = TextFormField(
          readOnly: true,
          decoration: InputDecoration(
            labelText: 'Resposta',
            hintText: _hint.trim().isEmpty
                ? 'Escreve a tua resposta'
                : _hint.trim(),
          ),
        );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface2.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_outlined, size: 17, color: colors.lime),
              const SizedBox(width: 8),
              Text(
                'Pré-visualização para o aluno',
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Interage abaixo para veres como este campo será apresentado.',
            style: TextStyle(color: colors.muted, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: colors.text,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          field,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminResponsiveDialog(
      title: widget.initial == null ? 'Nova pergunta' : 'Editar pergunta',
      subtitle: 'O mesmo campo será apresentado na ficha inicial do aluno.',
      icon: Icons.help_outline,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
      child: Column(
        children: [
          FocusedTextFormField(
            initialValue: _label,
            autofocus: true,
            onChanged: (value) => setState(() => _label = value),
            focusedFillColor: AdminThemeColors.of(context).surface2,
            decoration: const InputDecoration(labelText: 'Pergunta'),
          ),
          const SizedBox(height: 14),
          AppMenuDropdown<String>(
            value: _type,
            options: const ['text', 'choice', 'binary', 'date'],
            labelBuilder: (v) => switch (v) {
              'text' => 'Texto livre',
              'choice' => 'Menu com opções',
              'binary' => 'Sim / Não',
              _ => 'Data',
            },
            onChanged: _selectType,
            label: 'Tipo de resposta',
            accentColor: AdminThemeColors.of(context).lime,
            fieldColor: AdminThemeColors.of(context).surface,
            menuColor: AdminThemeColors.of(context).surface2,
            textColor: AdminThemeColors.of(context).text,
            labelColor: AdminThemeColors.of(context).muted,
          ),
          if (_type == 'choice') ...[
            const SizedBox(height: 14),
            _buildOptionsEditor(AdminThemeColors.of(context)),
          ],
          if (_type == 'binary') ...[
            const SizedBox(height: 14),
            FocusedTextFormField(
              initialValue: _detail,
              onChanged: (value) => _detail = value,
              focusedFillColor: AdminThemeColors.of(context).surface2,
              decoration: const InputDecoration(
                labelText: 'Campo extra quando responder Sim (opcional)',
                hintText: 'Descreve aqui...',
              ),
            ),
          ],
          if (_type == 'text') ...[
            const SizedBox(height: 14),
            FocusedTextFormField(
              initialValue: _hint,
              onChanged: (value) => setState(() => _hint = value),
              focusedFillColor: AdminThemeColors.of(context).surface2,
              decoration: const InputDecoration(
                labelText: 'Texto de ajuda (opcional)',
              ),
            ),
          ],
          const SizedBox(height: 16),
          _buildPreview(AdminThemeColors.of(context)),
          const SizedBox(height: 4),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _required,
            onChanged: (value) => setState(() => _required = value ?? true),
            title: const Text('Resposta obrigatória'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 42,
            color: AdminThemeColors.of(context).muted,
          ),
          const SizedBox(height: 12),
          const Text('Ainda não existem tópicos.'),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Criar primeiro tópico'),
          ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Não foi possível carregar a configuração.'),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onRetry,
          child: const Text('Tentar novamente'),
        ),
      ],
    ),
  );
}
