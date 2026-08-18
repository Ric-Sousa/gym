import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../config/notification_sounds.dart';

/// Implementação Web do serviço de som.
///
/// O browser só permite áudio automático depois de uma interação do utilizador.
/// Os elementos são criados uma vez, anexados ao DOM e reutilizados para que
/// uma mensagem posterior não dependa de criar um novo elemento bloqueado.
class SoundService {
  static final SoundService _instance = SoundService._();
  factory SoundService() => _instance;
  SoundService._() {
    _listenForInteraction('mousedown');
    _listenForInteraction('touchstart');
    _listenForInteraction('keydown');
  }

  static const _audioPoolSize = 4;
  static const _silentWavDataUri =
      'data:audio/wav;base64,UklGRigAAABXQVZFZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YQAAAAA=';

  final Map<String, web.EventListener> _interactionListeners = {};
  final List<web.HTMLAudioElement> _audioPool = [];
  web.HTMLAudioElement? _unlockAudio;
  final List<String> _pendingAssets = [];
  String _currentAsset = defaultSoundAsset;
  bool _isUnlocked = false;
  int _nextAudioIndex = 0;

  /// Prepara os elementos antes de os listeners de Firestore começarem.
  void prepare() {
    _ensureAudioPool();
  }

  /// Define o ficheiro de som a usar nas notificações.
  void setSound(String assetPath) {
    if (assetPath.trim().isNotEmpty) _currentAsset = assetPath;
  }

  /// Desbloqueia a reprodução de áudio após o primeiro gesto do utilizador.
  void unlock() => _markAsUnlocked();

  void playNotificationChime() {
    _play(_currentAsset);
  }

  void playErrorSound() {
    _play(errorSoundAsset);
  }

  /// Mantido para compatibilidade com versões anteriores do serviço.
  void discardPendingNotificationSounds() {
    _pendingAssets.clear();
  }

  void _listenForInteraction(String eventType) {
    final listener = ((web.Event _) => _markAsUnlocked()).toJS;
    _interactionListeners[eventType] = listener;
    web.document.addEventListener(eventType, listener);
  }

  void _markAsUnlocked() {
    if (_isUnlocked) return;
    _isUnlocked = true;
    _ensureAudioPool();

    // Usa um elemento dedicado para o desbloqueio. Nunca interrompemos um
    // elemento do pool que possa estar a reproduzir uma notificação real.
    final unlockAudio = _unlockAudio ??= web.HTMLAudioElement()
      ..preload = 'auto'
      ..muted = true
      ..volume = 0;
    unlockAudio.style.display = 'none';
    unlockAudio.src = _silentWavDataUri;
    final body = web.document.body;
    if (body != null && unlockAudio.parentElement == null) {
      body.append(unlockAudio);
    }
    unawaited(_safePlay(unlockAudio));

    // Uma notificação pendente é suficiente: não reproduzir histórico inteiro
    // ao desbloquear uma aba que ficou inativa.
    final pendingAsset = _pendingAssets.isEmpty ? null : _pendingAssets.last;
    _pendingAssets.clear();
    if (pendingAsset != null) _play(pendingAsset);
  }

  String _assetUrl(String asset) => 'assets/$asset';

  void _ensureAudioPool() {
    while (_audioPool.length < _audioPoolSize) {
      final audio = web.HTMLAudioElement()
        ..preload = 'auto'
        ..muted = false
        ..volume = 1.0;
      audio.style.display = 'none';
      audio.setAttribute('aria-hidden', 'true');
      _audioPool.add(audio);
    }

    // `prepare()` pode correr antes de Flutter anexar o body. Anexamos os
    // elementos existentes em cada acesso para que o pool não fique desligado.
    final body = web.document.body;
    if (body != null) {
      for (final audio in _audioPool) {
        if (audio.parentElement == null) body.append(audio);
      }
    }
  }

  web.HTMLAudioElement _audioForPlayback() {
    _ensureAudioPool();
    final audio = _audioPool[_nextAudioIndex % _audioPool.length];
    _nextAudioIndex++;
    audio.pause();
    try {
      audio.currentTime = 0;
    } catch (_) {}
    return audio;
  }

  void _play(String asset) {
    if (asset.trim().isEmpty) return;

    if (!_isUnlocked) {
      // O browser ainda não pode reproduzir. Mantém apenas uma fila pequena.
      if (_pendingAssets.length >= 8) _pendingAssets.removeAt(0);
      _pendingAssets.add(asset);
      return;
    }

    final audio = _audioForPlayback()
      ..muted = false
      ..volume = 1.0
      ..preload = 'auto'
      ..src = _assetUrl(asset);

    // Não chamar load() imediatamente: em alguns browsers isso aborta o
    // carregamento iniciado ao definir src.
    unawaited(_safePlay(audio));
  }

  Future<void> _safePlay(web.HTMLAudioElement audio) async {
    try {
      await audio.play().toDart;
    } catch (_) {
      // Erros de autoplay/rede/media são opcionais e não devem derrubar a app.
    }
  }
}
