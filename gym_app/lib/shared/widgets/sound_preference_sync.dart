import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/notification_sounds.dart';
import '../../core/services/sound_service.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../providers/global_providers.dart';

/// Sincroniza o som de notificação com a preferência do utilizador
/// autenticado e desbloqueia o áudio no primeiro gesto em qualquer parte
/// da app (não apenas no chat).
///
/// O [SoundService] é um singleton partilhado entre utilizadores na mesma
/// sessão do browser. Antes, a preferência só era aplicada quando o
/// utilizador abria as Definições/Perfil, o que fazia o admin ouvir um som
/// "preso" de outra sessão (um som aparentemente aleatório). Este widget
/// aplica a preferência assim que o perfil carrega e sempre que ele muda.
class SoundPreferenceSync extends ConsumerWidget {
  const SoundPreferenceSync({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ao mudar de utilizador (login/logout), nunca deixar o som de uma
    // sessão anterior "preso" enquanto o perfil do novo utilizador carrega.
    ref.listen<String>(authProvider.select((s) => s.user?.uid ?? ''), (
      prev,
      next,
    ) {
      if (prev != next) SoundService().setSound(defaultSoundAsset);
    });

    final user = ref.watch(currentUserStreamProvider).asData?.value;
    if (user != null) {
      SoundService().setSound(user.notificationSound ?? defaultSoundAsset);
    }

    // Listener passivo no topo da árvore: qualquer clique/toque em qualquer
    // ecrã (incluindo modais e overlays) desbloqueia o áudio do browser.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => SoundService().unlock(),
      child: child,
    );
  }
}
