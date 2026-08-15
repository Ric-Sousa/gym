import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/data/models/group_model.dart';

void main() {
  test('preserva imagem e dados reais dos membros ao ler e serializar', () {
    final group = GroupModel.fromMap('group-1', {
      'nome': 'Turma Manhã',
      'membros': ['student-1'],
      'criadoPor': 'admin-1',
      'createdAt': DateTime(2026, 8, 15),
      'imagemUrl': 'https://example.com/group.jpg',
      'membrosNomes': {'student-1': 'Ana Silva'},
      'membrosFotos': {'student-1': 'https://example.com/ana.jpg'},
      'lastReadAtByUser': {
        'student-1': DateTime(2026, 8, 15, 11),
      },
      'criadoPorNome': 'Admin Gym',
      'criadoPorFoto': 'https://example.com/admin.jpg',
    });

    expect(group.imagemUrl, 'https://example.com/group.jpg');
    expect(group.membrosNomes['student-1'], 'Ana Silva');
    expect(group.membrosFotos['student-1'], 'https://example.com/ana.jpg');
    expect(
      group.lastReadAtByUser['student-1'],
      DateTime(2026, 8, 15, 11),
    );
    expect(group.criadoPorNome, 'Admin Gym');
    expect(group.criadoPorFoto, 'https://example.com/admin.jpg');
    expect(group.toMap()['membrosFotos'], {
      'student-1': 'https://example.com/ana.jpg',
    });
  });

  test('copyWith atualiza membros sem perder os dados do grupo', () {
    final group = GroupModel(
      id: 'group-1',
      nome: 'Turma Manhã',
      membros: ['student-1'],
      criadoPor: 'admin-1',
      createdAt: DateTime(2026, 8, 15),
    );

    final updated = group.copyWith(membros: ['student-1', 'student-2']);

    expect(updated.id, group.id);
    expect(updated.nome, group.nome);
    expect(updated.criadoPor, group.criadoPor);
    expect(updated.membros, ['student-1', 'student-2']);
  });
}
