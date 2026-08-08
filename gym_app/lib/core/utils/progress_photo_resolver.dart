/// Ângulos mostrados no comparador de progresso do perfil, por esta ordem.
const progressAngleLabels = <String>['Frente', 'Costas', 'Lado 1', 'Lado 2'];

/// Normaliza uma chave de posição para 'frente', 'costas', 'lado1', 'lado2'
/// ou '' quando não é reconhecida. Aceita variações como 'frente', 'Lado-1',
/// 'lado_esquerdo' ou 'Costas'.
String normalizeProgressPositionKey(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('â', 'a')
      .replaceAll('é', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[\s_-]+'), '');

  switch (normalized) {
    case 'frente':
      return 'frente';
    case 'costas':
    case 'traseira':
    case 'posterior':
      return 'costas';
    case 'lado1':
    case 'lateral1':
    case 'ladoesquerdo':
      return 'lado1';
    case 'lado2':
    case 'lateral2':
    case 'ladodireito':
      return 'lado2';
    default:
      return '';
  }
}

/// Procura no mapa `fotosPorPosicao` a foto de uma posição, com chaves
/// normalizadas. Devolve null quando não existe ou está vazia.
String? explicitProgressPhotoAt(
  Map<String, String> photosByPosition,
  String position,
) {
  final target = normalizeProgressPositionKey(position);
  for (final entry in photosByPosition.entries) {
    if (normalizeProgressPositionKey(entry.key) != target) continue;
    final url = entry.value.trim();
    if (url.isNotEmpty) return url;
  }
  return null;
}

/// Indica se o mapa tem pelo menos uma posição reconhecida preenchida.
bool hasRecognizedProgressPositionPhoto(Map<String, String> photosByPosition) {
  return photosByPosition.entries.any((entry) {
    return normalizeProgressPositionKey(entry.key).isNotEmpty &&
        entry.value.trim().isNotEmpty;
  });
}

/// Indica se o registo tem alguma foto utilizável, na lista ou no mapa.
bool hasAnyProgressPhoto(
  List<String> fotos,
  Map<String, String> fotosPorPosicao,
) {
  return fotos.any((url) => url.trim().isNotEmpty) ||
      hasRecognizedProgressPositionPhoto(fotosPorPosicao);
}

/// Resolve a URL da foto de um registo para [angleIndex] (índice em
/// [progressAngleLabels]).
///
/// Ordem de resolução:
/// 1. Mapa explícito `fotosPorPosicao` (formato novo, com chaves livres).
/// 2. Lista `fotos` com 4 slots fixos (formato novo, ordem Frente, Lado 1,
///    Lado 2, Costas) — identificado por placeholders vazios ou pela
///    existência do mapa.
/// 3. Lista compacta de registos antigos sem mapa (formulário "frente, lado,
///    costas, opcional"): 1 foto = Frente; 2 = Frente, Lado 1; 3 = Frente,
///    Lado 1, Costas; 4 = Frente, Lado 1, Costas, Lado 2.
///
/// Quando o mapa existe mas é parcial e a lista é compacta (< 4), as
/// posições que faltam são incertas e não são adivinhadas.
String? resolveProgressPhotoAt({
  required List<String> fotos,
  required Map<String, String> fotosPorPosicao,
  required int angleIndex,
}) {
  if (angleIndex < 0 || angleIndex >= progressAngleLabels.length) return null;

  final explicitUrl = explicitProgressPhotoAt(
    fotosPorPosicao,
    progressAngleLabels[angleIndex],
  );
  if (explicitUrl != null) return explicitUrl;

  final legacyIndex = legacyProgressPhotoIndex(
    angleIndex,
    fotos,
    fotosPorPosicao,
  );
  if (legacyIndex == null || legacyIndex >= fotos.length) return null;

  final legacyUrl = fotos[legacyIndex].trim();
  return legacyUrl.isEmpty ? null : legacyUrl;
}

/// Índice na lista `fotos` que corresponde a [angleIndex], ou null quando a
/// posição não pode ser determinada com segurança. Ver
/// [resolveProgressPhotoAt] para as regras de cada formato.
int? legacyProgressPhotoIndex(
  int angleIndex,
  List<String> fotos,
  Map<String, String> fotosPorPosicao,
) {
  if (angleIndex < 0 || angleIndex >= progressAngleLabels.length) return null;
  final count = fotos.length;
  if (count == 0) return null;

  final hasMap = hasRecognizedProgressPositionPhoto(fotosPorPosicao);
  final hasPlaceholders = fotos.any((url) => url.trim().isEmpty);

  // Índice da lista por ângulo [Frente, Costas, Lado 1, Lado 2].
  if (count < 4) {
    // Mapa parcial + lista compacta: as posições em falta são incertas.
    if (hasMap) return null;
    // Registos antigos: Frente, Lado 1, Costas (a 4.ª posição nunca existe
    // numa lista compacta com menos de 4 fotos).
    const compactIndexes = <int>[0, 2, 1, 3];
    final index = compactIndexes[angleIndex];
    return index < count ? index : null;
  }

  if (hasPlaceholders || hasMap) {
    // Formato novo: 4 slots fixos na ordem Frente, Lado 1, Lado 2, Costas.
    const slotIndexes = <int>[0, 3, 1, 2];
    return slotIndexes[angleIndex];
  }

  // Lista antiga completa sem mapa: Frente, Lado 1, Costas e a 4.ª foto
  // opcional tratada como Lado 2.
  const compactIndexes = <int>[0, 2, 1, 3];
  return compactIndexes[angleIndex];
}
