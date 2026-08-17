import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/config/admin_theme.dart';
import '../../data/models/exercise_catalog_model.dart';
import '../providers/admin_providers.dart';
import 'admin_responsive_dialog.dart';

Future<ExerciseCatalogModel?> showExerciseCatalogPicker(
  BuildContext context,
) {
  return showDialog<ExerciseCatalogModel>(
    context: context,
    builder: (_) => const _ExerciseCatalogPickerDialog(),
  );
}

class _ExerciseCatalogPickerDialog extends ConsumerStatefulWidget {
  const _ExerciseCatalogPickerDialog();

  @override
  ConsumerState<_ExerciseCatalogPickerDialog> createState() =>
      _ExerciseCatalogPickerDialogState();
}

class _ExerciseCatalogPickerDialogState
    extends ConsumerState<_ExerciseCatalogPickerDialog> {
  String _query = '';
  String _category = 'Todos';

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final exercisesAsync = ref.watch(adminExerciseCatalogProvider);
    return AdminResponsiveDialog(
      title: 'Escolher exercício',
      subtitle: 'Pesquisa no catálogo importado para adicionar ao plano.',
      icon: Icons.fitness_center_rounded,
      maxWidth: 720,
      child: Column(
        children: [
          TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Pesquisar por nome ou músculo...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: colors.bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colors.border),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ['Todos', 'forca', 'alongamento', 'cardio']
                  .map(
                    (category) => ChoiceChip(
                      label: Text(_label(category)),
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          exercisesAsync.when(
            loading: () => const SizedBox(
              height: 260,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SizedBox(
              height: 180,
              child: Center(child: Text('Erro ao carregar exercícios: $error')),
            ),
            data: (exercises) {
              final query = _query.trim().toLowerCase();
              final filtered = exercises.where((exercise) {
                if (!exercise.ativo) return false;
                final searchable = [
                  exercise.nome,
                  ...exercise.musculosPrimarios,
                  ...exercise.musculosSecundarios,
                ].join(' ').toLowerCase();
                return searchable.contains(query) &&
                    (_category == 'Todos' || exercise.categoria == _category);
              }).toList();
              if (filtered.isEmpty) {
                return SizedBox(
                  height: 180,
                  child: Center(
                    child: Text(
                      'Nenhum exercício encontrado.',
                      style: GoogleFonts.inter(color: colors.muted),
                    ),
                  ),
                );
              }
              return SizedBox(
                height: 390,
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => Divider(color: colors.border),
                  itemBuilder: (_, index) {
                    final exercise = filtered[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: colors.limeDim,
                        foregroundColor: colors.lime,
                        child: const Icon(Icons.fitness_center, size: 18),
                      ),
                      title: Text(
                        exercise.nome,
                        style: GoogleFonts.inter(
                          color: colors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        '${_label(exercise.categoria)} · ${_label(exercise.equipamento)}${exercise.musculosPrimarios.isEmpty ? '' : ' · ${exercise.musculosPrimarios.join(', ')}'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(color: colors.muted, fontSize: 12),
                      ),
                      trailing: const Icon(Icons.add_circle_outline),
                      onTap: () => Navigator.pop(context, exercise),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }

  String _label(String value) {
    if (value == 'Todos') return value;
    if (value.isEmpty) return 'Geral';
    return value[0].toUpperCase() + value.substring(1).replaceAll('_', ' ');
  }
}
