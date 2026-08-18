import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/models/group_model.dart';
import '../../core/utils/storage_resource.dart';

/// Mostra os participantes conhecidos de um grupo antes de o abrir.
///
/// Os nomes e fotos vêm do próprio documento do grupo para que alunos possam
/// ver os participantes sem acesso aos perfis privados dos outros alunos.
class GroupMembersPreview extends StatelessWidget {
  final GroupModel group;
  final Color textColor;
  final Color mutedColor;
  final Color accentColor;
  final bool compact;

  const GroupMembersPreview({
    required this.group,
    required this.textColor,
    required this.mutedColor,
    required this.accentColor,
    this.compact = false,
    super.key,
  });

  List<String> get _participantIds {
    final ids = <String>[];
    if (group.criadoPor.isNotEmpty) ids.add(group.criadoPor);
    for (final id in group.membros) {
      if (id != group.criadoPor && !ids.contains(id)) ids.add(id);
    }
    return ids;
  }

  String? _nameFor(String uid) {
    if (uid == group.criadoPor) return group.criadoPorNome;
    return group.membrosNomes[uid];
  }

  String? _photoFor(String uid) {
    if (uid == group.criadoPor) return group.criadoPorFoto;
    return group.membrosFotos[uid];
  }

  @override
  Widget build(BuildContext context) {
    final ids = _participantIds;
    final visibleIds = ids.take(compact ? 3 : 4).toList();
    final knownNames = ids
        .map(_nameFor)
        .whereType<String>()
        .where((name) => name.trim().isNotEmpty)
        .toList();
    final studentNames = group.membros
        .where((uid) => uid != group.criadoPor)
        .map(_nameFor)
        .whereType<String>()
        .where((name) => name.trim().isNotEmpty)
        .toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _AvatarStack(
          ids: visibleIds,
          nameFor: _nameFor,
          photoFor: _photoFor,
          accentColor: accentColor,
          diameter: compact ? 24 : 28,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                studentNames.isNotEmpty
                    ? studentNames.join(', ')
                    : '${group.membros.length} membros',
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: compact ? 10 : 11,
                  color: mutedColor,
                  height: 1.25,
                ),
              ),
              if (knownNames.length < ids.length)
                Text(
                  '${group.membros.length} alunos no grupo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: mutedColor.withValues(alpha: 0.8),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AvatarStack extends StatelessWidget {
  final List<String> ids;
  final String? Function(String) nameFor;
  final String? Function(String) photoFor;
  final Color accentColor;
  final double diameter;

  const _AvatarStack({
    required this.ids,
    required this.nameFor,
    required this.photoFor,
    required this.accentColor,
    required this.diameter,
  });

  @override
  Widget build(BuildContext context) {
    if (ids.isEmpty) {
      return Icon(Icons.people_outline, size: diameter, color: accentColor);
    }

    final overlap = diameter * 0.62;
    return SizedBox(
      width: diameter + (ids.length - 1) * overlap,
      height: diameter,
      child: Stack(
        children: [
          for (var index = 0; index < ids.length; index++)
            Positioned(
              left: index * overlap,
              child: _avatar(ids[index]),
            ),
        ],
      ),
    );
  }

  Widget _avatar(String uid) {
    final photo = photoFor(uid);
    final name = nameFor(uid) ?? '?';
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accentColor.withValues(alpha: 0.14),
        border: Border.all(color: Colors.transparent, width: 1.5),
      ),
      child: StorageAvatar(
        resource: photo,
        radius: diameter / 2,
        backgroundColor: accentColor.withValues(alpha: 0.14),
        fallback: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: GoogleFonts.inter(
            color: accentColor,
            fontSize: diameter * 0.38,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
