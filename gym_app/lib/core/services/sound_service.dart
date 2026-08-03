// Conditional import: use web version on web, no-op stub elsewhere.
import 'sound_service_io.dart'
    if (dart.library.html) 'sound_service_web.dart'
    as impl;

/// Serviço de som para notificações.
///
/// Toca um chime suave — arpejo ascendente C5→E5→G5→C6
/// com timbre de sino e decaimento natural.
/// No web usa HTML Audio, no mobile/desktop usa just_audio.
///
/// O som pode ser alterado com [setSound].
class SoundService {
  static final SoundService _instance = SoundService._();
  factory SoundService() => _instance;
  SoundService._();

  /// Regista os listeners de interação Web antes da primeira notificação.
  /// Em plataformas nativas é uma operação sem efeito.
  void prepare() {
    impl.SoundService().prepare();
  }

  /// Define o ficheiro de som a usar (ex: 'assets/sounds/chime.wav').
  void setSound(String assetPath) {
    impl.SoundService().setSound(assetPath);
  }

  /// Toca o som de notificação configurado.
  void playNotificationChime() {
    impl.SoundService().playNotificationChime();
  }

  /// Toca o som específico de erro.
  void playErrorSound() {
    impl.SoundService().playErrorSound();
  }
}
