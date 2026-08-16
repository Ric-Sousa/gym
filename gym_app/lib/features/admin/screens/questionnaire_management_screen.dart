import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/config/admin_theme.dart';
import '../../../data/models/questionnaire_config_model.dart';
import '../../../shared/providers/admin_providers.dart';
import '../../../shared/providers/global_providers.dart';
import '../../../shared/widgets/admin_design_system.dart';
import '../../../shared/widgets/admin_responsive_dialog.dart';

class QuestionnaireManagementScreen extends ConsumerWidget {
  const QuestionnaireManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(questionnaireConfigProvider);
    return AdminPageFrame(
      child: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErrorState(onRetry: () => ref.invalidate(questionnaireConfigProvider)),
        data: (config) => _QuestionnaireEditor(config: config),
      ),
    );
  }
}

class _QuestionnaireEditor extends ConsumerStatefulWidget {
  final QuestionnaireConfig config;

  const _QuestionnaireEditor({required this.config});

  @override
  ConsumerState<_QuestionnaireEditor> createState() => _QuestionnaireEditorState();
}

class _QuestionnaireEditorState extends ConsumerState<_QuestionnaireEditor> {
  bool _saving = false;

  Future<void> _save(QuestionnaireConfig config) async {
    setState(() => _saving = true);
    try {
      await ref.read(userRepositoryProvider).saveQuestionnaireConfig(config);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Questionário atualizado para novos acessos.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível guardar o questionário.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addTopic() async {
    final topic = await _showTopicDialog(context);
    if (topic == null) return;
    await _save(widget.config.copyWith(topics: [...widget.config.topics, topic]));
  }

  Future<void> _editTopic(int index) async {
    final topic = await _showTopicDialog(context, initial: widget.config.topics[index]);
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
        content: Text('As ${topic.questions.length} perguntas de “${topic.title}” também serão removidas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AdminThemeColors.of(context).danger),
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
        content: Text('“${question.label}” deixará de aparecer para novos alunos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AdminThemeColors.of(context).danger),
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
          subtitle: 'Organiza os tópicos e as perguntas que o aluno responde no primeiro acesso.',
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
                    onEdit: _saving ? null : () => _editTopic(entry.key),
                    onDelete: _saving ? null : () => _deleteTopic(entry.key),
                    onAddQuestion: _saving ? null : () => _addQuestion(entry.key),
                    onEditQuestion: (questionIndex) =>
                        _saving ? null : _editQuestion(entry.key, questionIndex),
                    onDeleteQuestion: (questionIndex) =>
                        _saving ? null : _deleteQuestion(entry.key, questionIndex),
                  ),
                ),
              ),
        if (_saving)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colors.lime)),
                const SizedBox(width: 10),
                Text('A guardar alterações...', style: GoogleFonts.inter(fontSize: 12, color: colors.muted)),
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
  final ValueChanged<int> onEditQuestion;
  final ValueChanged<int> onDeleteQuestion;

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
                decoration: BoxDecoration(color: colors.limeDim, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.topic_outlined, color: colors.lime, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(topic.title, style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w800, color: colors.text)),
                    if (topic.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(topic.description, style: GoogleFonts.inter(fontSize: 12, color: colors.muted)),
                    ],
                  ],
                ),
              ),
              IconButton(onPressed: onEdit, tooltip: 'Editar tópico', icon: Icon(Icons.edit_outlined, color: colors.muted, size: 19)),
              IconButton(onPressed: onDelete, tooltip: 'Eliminar tópico', icon: Icon(Icons.delete_outline, color: colors.danger, size: 19)),
            ],
          ),
          const SizedBox(height: 16),
          if (topic.questions.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('Ainda não existem perguntas neste tópico.', style: GoogleFonts.inter(fontSize: 12, color: colors.muted)),
            )
          else
            ...topic.questions.asMap().entries.map(
                  (entry) => _QuestionRow(
                    question: entry.value,
                    onEdit: () => onEditQuestion(entry.key),
                    onDelete: () => onDeleteQuestion(entry.key),
                  ),
                ),
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
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _QuestionRow({required this.question, required this.onEdit, required this.onDelete});

  String get typeLabel => switch (question.type) {
        'choice' => 'Dropdown',
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
        decoration: BoxDecoration(color: colors.surface2.withValues(alpha: 0.38), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(question.isBinary ? Icons.toggle_on_outlined : Icons.help_outline, size: 18, color: colors.lime),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(question.label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: colors.text)),
                  const SizedBox(height: 3),
                  Text(
                    '${typeLabel}${question.hasDetail ? ' · abre campo de detalhe ao escolher Sim' : ''}',
                    style: GoogleFonts.inter(fontSize: 11, color: colors.muted),
                  ),
                ],
              ),
            ),
            IconButton(onPressed: onEdit, tooltip: 'Editar pergunta', icon: Icon(Icons.edit_outlined, size: 18, color: colors.muted)),
            IconButton(onPressed: onDelete, tooltip: 'Eliminar pergunta', icon: Icon(Icons.delete_outline, size: 18, color: colors.danger)),
          ],
        ),
      ),
    );
  }
}

Future<QuestionnaireTopic?> _showTopicDialog(BuildContext context, {QuestionnaireTopic? initial}) async {
  final titleController = TextEditingController(text: initial?.title ?? '');
  final descriptionController = TextEditingController(text: initial?.description ?? '');
  final result = await showDialog<QuestionnaireTopic>(
    context: context,
    builder: (dialogContext) => AdminResponsiveDialog(
      title: initial == null ? 'Novo tópico' : 'Editar tópico',
      subtitle: 'Agrupa perguntas relacionadas para o aluno.',
      icon: Icons.topic_outlined,
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final title = titleController.text.trim();
            if (title.isEmpty) return;
            Navigator.pop(
              dialogContext,
              QuestionnaireTopic(
                id: initial?.id ?? 'topic-${DateTime.now().millisecondsSinceEpoch}',
                title: title,
                description: descriptionController.text.trim(),
                questions: initial?.questions ?? const [],
              ),
            );
          },
          child: const Text('Guardar'),
        ),
      ],
      child: Column(
        children: [
          TextField(controller: titleController, autofocus: true, decoration: const InputDecoration(labelText: 'Nome do tópico', hintText: 'Ex.: Saúde e rotina')),
          const SizedBox(height: 14),
          TextField(controller: descriptionController, maxLines: 2, decoration: const InputDecoration(labelText: 'Descrição (opcional)')),
        ],
      ),
    ),
  );
  titleController.dispose();
  descriptionController.dispose();
  return result;
}

Future<QuestionnaireQuestion?> _showQuestionDialog(BuildContext context, {QuestionnaireQuestion? initial}) async {
  final labelController = TextEditingController(text: initial?.label ?? '');
  final hintController = TextEditingController(text: initial?.hint ?? '');
  final optionsController = TextEditingController(text: initial?.options.join(', ') ?? '');
  final detailController = TextEditingController(text: initial?.detailLabel ?? '');
  var type = initial?.type ?? 'text';
  var required = initial?.required ?? true;

  final result = await showDialog<QuestionnaireQuestion>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AdminResponsiveDialog(
        title: initial == null ? 'Nova pergunta' : 'Editar pergunta',
        subtitle: 'O mesmo campo será apresentado na ficha inicial do aluno.',
        icon: Icons.help_outline,
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final label = labelController.text.trim();
              if (label.isEmpty) return;
              final id = initial?.id ?? 'question-${DateTime.now().millisecondsSinceEpoch}';
              final options = type == 'binary'
                  ? const ['sim', 'não']
                  : optionsController.text.split(',').map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
              if ((type == 'choice' || type == 'binary') && options.isEmpty) return;
              Navigator.pop(
                dialogContext,
                QuestionnaireQuestion(
                  id: id,
                  label: label,
                  type: type,
                  options: options,
                  required: required,
                  hint: hintController.text.trim().isEmpty ? null : hintController.text.trim(),
                  detailId: type == 'binary' && detailController.text.trim().isNotEmpty
                      ? (initial?.detailId ?? '${id}_details')
                      : null,
                  detailLabel: type == 'binary' && detailController.text.trim().isNotEmpty
                      ? detailController.text.trim()
                      : null,
                ),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
        child: Column(
          children: [
            TextField(controller: labelController, autofocus: true, decoration: const InputDecoration(labelText: 'Pergunta')),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: type,
              decoration: const InputDecoration(labelText: 'Tipo de resposta'),
              items: const [
                DropdownMenuItem(value: 'text', child: Text('Texto livre')),
                DropdownMenuItem(value: 'choice', child: Text('Dropdown com opções')),
                DropdownMenuItem(value: 'binary', child: Text('Sim / Não')),
                DropdownMenuItem(value: 'date', child: Text('Data')),
              ],
              onChanged: (value) => setState(() => type = value ?? 'text'),
            ),
            if (type == 'choice') ...[
              const SizedBox(height: 14),
              TextField(controller: optionsController, decoration: const InputDecoration(labelText: 'Opções', hintText: 'Opção 1, Opção 2, Opção 3')),
            ],
            if (type == 'binary') ...[
              const SizedBox(height: 14),
              TextField(controller: detailController, decoration: const InputDecoration(labelText: 'Campo extra quando responder Sim (opcional)', hintText: 'Descreve aqui...')),
            ],
            if (type == 'text') ...[
              const SizedBox(height: 14),
              TextField(controller: hintController, decoration: const InputDecoration(labelText: 'Texto de ajuda (opcional)')),
            ],
            const SizedBox(height: 4),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: required,
              onChanged: (value) => setState(() => required = value ?? true),
              title: const Text('Resposta obrigatória'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
    ),
  );
  labelController.dispose();
  hintController.dispose();
  optionsController.dispose();
  detailController.dispose();
  return result;
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
              Icon(Icons.assignment_outlined, size: 42, color: AdminThemeColors.of(context).muted),
              const SizedBox(height: 12),
              const Text('Ainda não existem tópicos.'),
              const SizedBox(height: 14),
              OutlinedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Criar primeiro tópico')),
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
            OutlinedButton(onPressed: onRetry, child: const Text('Tentar novamente')),
          ],
        ),
      );
}
