import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'core/services/sound_service.dart';

/// Handler de mensagens em background.
/// Deve ser uma função top-level (não pode ser método de classe).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Em background, o sistema mostra automaticamente a notificação.
  // Este handler serve apenas para processamento adicional (ex: atualizar badge).
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Regista o handler de mensagens em background (apenas mobile)
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Instancia o serviço antes dos listeners de notificações. No Web isto
  // regista os eventos de clique/toque/teclado desde o arranque; assim o
  // primeiro gesto normal do utilizador desbloqueia o áudio sem exigir abrir
  // o menu de seleção de sons.
  SoundService().prepare();

  // Ativar Firestore offline persistence
  // FirebaseFirestore.instance.settings =
  //     const Settings(persistenceEnabled: true);

  runApp(const ProviderScope(child: PersonalFitApp()));
}
