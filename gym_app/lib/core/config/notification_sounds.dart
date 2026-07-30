/// Opção de som de notificação.
class SoundOption {
  final String name; // Nome visível
  final String asset; // Caminho do asset (ex: 'assets/sounds/chime.wav')
  final String filename; // Nome do ficheiro (para preview)

  const SoundOption({
    required this.name,
    required this.asset,
    required this.filename,
  });
}

/// Lista de sons de notificação disponíveis.
const notificationSoundOptions = [
  SoundOption(
    name: 'Som 1 (Chime suave)',
    asset: 'assets/sounds/chime.wav',
    filename: 'chime.wav',
  ),
  SoundOption(
    name: 'Som 2',
    asset: 'assets/sounds/dragon-studio-new-notification-3-398649.mp3',
    filename: 'dragon-studio-new-notification-3-398649.mp3',
  ),
  SoundOption(
    name: 'Som 3',
    asset: 'assets/sounds/universfield-new-notification-010-352755.mp3',
    filename: 'universfield-new-notification-010-352755.mp3',
  ),
  SoundOption(
    name: 'Som 4',
    asset: 'assets/sounds/universfield-new-notification-012-363675.mp3',
    filename: 'universfield-new-notification-012-363675.mp3',
  ),
  SoundOption(
    name: 'Som 5',
    asset: 'assets/sounds/universfield-new-notification-014-363678.mp3',
    filename: 'universfield-new-notification-014-363678.mp3',
  ),
  SoundOption(
    name: 'Som 6',
    asset: 'assets/sounds/universfield-new-notification-040-493469.mp3',
    filename: 'universfield-new-notification-040-493469.mp3',
  ),
  SoundOption(
    name: 'Som 7 (Bell)',
    asset: 'assets/sounds/u_3ay6aijdt2-bell1-445873.mp3',
    filename: 'u_3ay6aijdt2-bell1-445873.mp3',
  ),
];

/// Som específico para notificações de erro.
const errorSoundAsset = 'assets/sounds/universfield-error-notification-08-206492.mp3';

/// Caminho de som padrão.
const defaultSoundAsset = 'assets/sounds/chime.wav';

/// Obtém a SoundOption correspondente a um asset path.
/// Retorna a opção padrão se não encontrar.
SoundOption getSoundOption(String? assetPath) {
  if (assetPath == null) return notificationSoundOptions.first;
  return notificationSoundOptions.firstWhere(
    (o) => o.asset == assetPath,
    orElse: () => notificationSoundOptions.first,
  );
}
