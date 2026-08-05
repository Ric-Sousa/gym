import 'dart:async';
import 'dart:html' as html;
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

  static const _audioPoolSize = 4;
  static const _silentWavDataUri =
      'data:audio/wav;base64,UklGRigAAABXQVZFZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YQAAAAA=';

  final List<StreamSubscription<dynamic>> _interactionSubscriptions = [];
  final List<html.AudioElement> _audioPool = [];
  html.AudioElement? _unlockAudio;
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

  /// Desbloqueia a reprodução de áudio. Chamado no primeiro gesto do
  /// utilizador em qualquer parte da app (não apenas no chat).
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

  void _markAsUnlocked() {
    if (_isUnlocked) return;
    _isUnlocked = true;
    _ensureAudioPool();

    // Usa um elemento dedicado para o desbloqueio. Nunca interrompemos um
    // elemento do pool que possa estar a reproduzir uma notificação real.
    final unlockAudio = _unlockAudio ??= html.AudioElement()
      ..preload = 'auto'
      ..muted = true
      ..volume = 0;
    unlockAudio.style.display = 'none';
    unlockAudio.src = _silentWavDataUri;
    final body = html.document.body;
    if (body != null && unlockAudio.parent == null) {
      body.children.add(unlockAudio);
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
      final audio = html.AudioElement()
        ..preload = 'auto'
        ..muted = false
        ..volume = 1.0;
      audio.style.display = 'none';
      audio.setAttribute('aria-hidden', 'true');
      _audioPool.add(audio);
    }

    // `prepare()` can run before Flutter has attached document.body. Attach
    // existing elements on every access so the pool cannot remain detached.
    final body = html.document.body;
    if (body != null) {
      for (final audio in _audioPool) {
        if (audio.parent == null) body.children.add(audio);
      }
    }
  }

  html.AudioElement _audioForPlayback() {
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
      // The browser cannot play yet. Keep only a small, latest-event queue.
      if (_pendingAssets.length >= 8) _pendingAssets.removeAt(0);
      _pendingAssets.add(asset);
      return;
    }

    final audio = _audioForPlayback()
      ..muted = false
      ..volume = 1.0
      ..preload = 'auto'
      ..src = _assetUrl(asset);

    // Setting src starts loading; calling load() immediately afterwards can
    // abort that load in some browsers. Let the browser start it naturally.
    unawaited(_safePlay(audio));
  }

  Future<void> _safePlay(html.AudioElement audio) async {
    try {
      await audio.play();
    } catch (_) {
      // Autoplay/network/media errors are non-fatal. Most importantly, never
      // let a rejected HTMLMediaElement promise crash Flutter Web.
    }
  }
}
