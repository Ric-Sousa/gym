import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'app.dart';

/// Handler de mensagens em background.
/// Deve ser uma função top-level (não pode ser método de classe).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Em background, o sistema mostra automaticamente a notificação.
  // Este handler serve apenas para processamento adicional (ex: atualizar badge).
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt');

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Regista o handler de mensagens em background (apenas mobile)
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Ativar Firestore offline persistence
  // FirebaseFirestore.instance.settings =
  //     const Settings(persistenceEnabled: true);

  runApp(
    const ProviderScope(
      child: PersonalFitApp(),
    ),
  );
}
