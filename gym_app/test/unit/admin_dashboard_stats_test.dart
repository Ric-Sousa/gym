import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/shared/providers/admin_providers.dart';

void main() {
  final now = DateTime(2026, 8, 20, 12);

  test('calcula clientes e sessoes a partir dos dados disponiveis', () {
    final stats = calculateAdminDashboardStats(
      now: now,
      alunos: [
        {'ultimaAtividade': DateTime(2026, 8, 19)},
        {'ultimaAtividade': DateTime(2026, 6, 1)},
        <String, dynamic>{},
      ],
      aggregate: {
        'sessoesTotal': 42,
        'sessionsByMonth': {'2026-08': 7},
      },
    );

    expect(stats.totalAlunos, 3);
    expect(stats.activeAlunos, 1);
    expect(stats.sessoesMes, 7);
    expect(stats.sessoesTotal, 42);
  });

  test('mantem metricas de clientes sem o agregado opcional', () {
    final stats = calculateAdminDashboardStats(
      now: now,
      alunos: [
        {'ultimaAtividade': DateTime(2026, 8, 10)},
        <String, dynamic>{},
      ],
      aggregate: const {},
    );

    expect(stats.totalAlunos, 2);
    expect(stats.activeAlunos, 1);
    expect(stats.sessoesMes, 0);
    expect(stats.sessoesTotal, 0);
  });
}
