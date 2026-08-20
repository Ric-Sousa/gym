import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/data/datasources/firestore_datasource.dart';
import 'package:gym_app/shared/providers/admin_providers.dart';

void main() {
  test('carrega páginas uma vez e impede carregamento depois do fim', () async {
    var calls = 0;
    final pager = AdminPagedList<String>(
      pageSize: 2,
      loadPage: (_, limit) async {
        calls++;
        expect(limit, 2);
        return FirestorePage<String>(
          items: calls == 1 ? const ['a', 'b'] : const ['c'],
          cursor: null,
          hasMore: calls == 1,
        );
      },
    );

    await pager.loadMore();
    expect(pager.items, ['a', 'b']);
    expect(pager.hasMore, isTrue);

    await pager.loadMore();
    expect(pager.items, ['a', 'b', 'c']);
    expect(pager.hasMore, isFalse);

    await pager.loadMore();
    expect(calls, 2);
  });

  test('expõe erro e permite retry na mesma página', () async {
    var shouldFail = true;
    final pager = AdminPagedList<String>(
      loadPage: (_, __) async {
        if (shouldFail) throw StateError('temporary');
        return const FirestorePage<String>(
          items: ['ok'],
          cursor: null,
          hasMore: false,
        );
      },
    );

    await pager.loadMore();
    expect(pager.error, isA<StateError>());
    expect(pager.items, isEmpty);

    shouldFail = false;
    await pager.loadMore();
    expect(pager.error, isNull);
    expect(pager.items, ['ok']);
  });

  test('mantem a ordenacao local ao acrescentar paginas', () async {
    var calls = 0;
    final pager = AdminPagedList<String>(
      pageSize: 2,
      comparator: (a, b) => a.compareTo(b),
      loadPage: (_, _) async {
        calls++;
        return FirestorePage<String>(
          items: calls == 1 ? const ['Marta', 'Ana'] : const ['Bruno'],
          cursor: null,
          hasMore: calls == 1,
        );
      },
    );

    await pager.loadMore();
    expect(pager.items, ['Ana', 'Marta']);

    await pager.loadMore();
    expect(pager.items, ['Ana', 'Bruno', 'Marta']);
  });
}
