import 'dart:async';
import 'dart:html' as html;
import '../config/notification_sounds.dart';

/// Implementação Web do serviço de som.
///
/// Os browsers bloqueiam áudio iniciado sem interação do utilizador. O serviço
/// observa a primeira interação e nunca deixa a Future de `play()` escapar,
/// evitando o Uncaught (in promise) NotAllowedError.
class SoundService {
  static final SoundService _instance = SoundService._();
  factory SoundService() => _instance;
  SoundService._() {
    _interactionSubscriptions.add(
      html.document.onMouseDown.listen((_) => _markAsUnlocked()),
    );
    _interactionSubscriptions.add(
      html.document.onTouchStart.listen((_) => _markAsUnlocked()),
    );
    _interactionSubscriptions.add(
      html.document.onKeyDown.listen((_) => _markAsUnlocked()),
    );
  }

  final List<StreamSubscription<dynamic>> _interactionSubscriptions = [];
  final List<html.AudioElement> _activeAudio = [];
  final List<String> _pendingAssets = [];
  String _currentAsset = defaultSoundAsset;
  bool _isUnlocked = false;

  // Um WAV silencioso permite chamar play() dentro do primeiro gesto normal
  // da página sem tocar uma notificação antiga nem exigir o menu de sons.
  static const _silentWavDataUri =
      'data:audio/wav;base64,UklGRigAAABXQVZFZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YQAAAAA=';

  /// Instancia o serviço cedo, antes de qualquer evento de notificação.
  void prepare() {}

  /// Define o ficheiro de som a usar nas notificações.
  void setSound(String assetPath) {
    _currentAsset = assetPath;
  }

  void playNotificationChime() {
    _play(_currentAsset);
  }

  void playErrorSound() {
    _play(errorSoundAsset);
  }

  void discardPendingNotificationSounds() {
    _pendingAssets.clear();
  }

  void _markAsUnlocked() {
    if (_isUnlocked) return;
    _isUnlocked = true;
    // Alguns browsers só registam a autorização se play() for chamado dentro
    // do próprio gesto. Este áudio é silencioso e não é uma notificação.
    final unlockAudio = html.AudioElement(_silentWavDataUri)
      ..volume = 0
      ..preload = 'auto';
    unlockAudio.play().catchError((_) {});

    // Não reproduzir notificações antigas no gesto que apenas desbloqueia
    // o áudio. Apenas mensagens posteriores ao desbloqueio são reproduzidas.
    _pendingAssets.clear();
  }

  void _play(String asset) {
    if (asset.isEmpty) return;
    // Não tentar contornar a política do browser. Guarda o som para o
    // primeiro gesto do utilizador, em vez de produzir uma rejeição ou perder
    // silenciosamente a notificação.
    if (!_isUnlocked) {
      _pendingAssets.add(asset);
      return;
    }

    final audio = html.AudioElement(asset)
      ..preload = 'auto'
      ..currentTime = 0;
    _activeAudio.add(audio);

    audio.onEnded.listen((_) => _activeAudio.remove(audio));
    audio.onError.listen((_) => _activeAudio.remove(audio));
    audio.load();

    // play() rejeita assincronamente quando o browser bloqueia autoplay;
    // try/catch sozinho não captura essa rejeição.
    audio.play().catchError((_) {
      _activeAudio.remove(audio);
    });
  }
}
