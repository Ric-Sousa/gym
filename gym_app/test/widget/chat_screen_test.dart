import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/data/models/group_model.dart';
import 'package:gym_app/data/models/message_model.dart';
import 'package:gym_app/features/aluno/chat/screens/chat_screen.dart';
import 'package:gym_app/features/auth/providers/auth_provider.dart';
import 'package:gym_app/shared/providers/global_providers.dart';

import 'test_helpers.dart';

void main() {
  setUp(() async {
    await initLocaleForTests();
  });

  testWidgets(
    'mantém o grupo visível quando chegam atualizações de mensagens',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final userId = alunoAuthState.user!.uid;
      const groupId = 'group-chat-test';
      final messages = StreamController<List<MessageModel>>();
      addTearDown(messages.close);
      final group = GroupModel(
        id: groupId,
        nome: 'Grupo de teste',
        membros: [userId, 'admin-test'],
        criadoPor: 'admin-test',
        createdAt: DateTime(2026, 8, 21),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              (ref) => MockAuthNotifier(alunoAuthState),
            ),
            alunoGroupsProvider(
              userId,
            ).overrideWith((ref) => Stream.value(<GroupModel>[group])),
            groupMessagesStreamProvider(
              groupId,
            ).overrideWith((ref) => messages.stream),
          ],
          child: const MaterialApp(home: ChatScreen(trackChatPresence: false)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Grupo de teste'), findsOneWidget);
      expect(find.text('A carregar'), findsNothing);

      messages.add(const <MessageModel>[]);
      await tester.pump();
      expect(find.text('Grupo de teste'), findsOneWidget);

      messages.add([
        MessageModel(
          id: 'message-test',
          remetenteId: 'admin-test',
          texto: 'Olá grupo',
          timestamp: DateTime(2026, 8, 21, 10),
        ),
      ]);
      await tester.pump();
      expect(find.text('Grupo de teste'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
