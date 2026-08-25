import '../../data/models/food_model.dart';

enum FoodKind {
  simple('simples', 'Simples'),
  compound('composto', 'Composto');

  const FoodKind(this.value, this.label);

  final String value;
  final String label;
}

/// Pesquisa e classificação local do catálogo de alimentos.
///
/// A pesquisa ignora acentos e diferenças simples de plural, atribuindo maior
/// relevância ao alimento-base. Assim, por exemplo, `ovos` encontra `Ovo` e
/// `arroz` apresenta os arrozes simples antes dos pratos compostos.
class FoodSearch {
  const FoodSearch._();

  static const _compoundConnectors = <String>{
    'com',
    'e',
    'recheado',
    'recheada',
    'mistura',
    'misto',
    'mista',
  };

  static const _compoundHeadsWithDe = <String>{
    'arroz',
    'massa',
    'salada',
    'sopa',
    'empada',
    'empadao',
    'acorda',
    'caldeirada',
    'ensopado',
    'esparguete',
    'lasanha',
  };

  static const _irregularSingular = <String, String>{
    'ovos': 'ovo',
    'arrozes': 'arroz',
    'paes': 'pao',
    'cereais': 'cereal',
    'vegetais': 'vegetal',
    'animais': 'animal',
    'pasteis': 'pastel',
  };

  static String normalize(String value) {
    var result = value.trim().toLowerCase();
    const accents = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const plain = 'aaaaaeeeeiiiiooooouuuuc';
    for (var index = 0; index < accents.length; index++) {
      result = result.replaceAll(accents[index], plain[index]);
    }
    return result
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static List<String> canonicalTokens(String value) => normalize(value)
      .split(' ')
      .where((token) => token.isNotEmpty)
      .map(_singularToken)
      .toList(growable: false);

  static String _singularToken(String token) {
    final irregular = _irregularSingular[token];
    if (irregular != null) return irregular;
    if (token.length > 4 && token.endsWith('oes')) {
      return '${token.substring(0, token.length - 3)}ao';
    }
    if (token.length > 4 && token.endsWith('ais')) {
      return '${token.substring(0, token.length - 3)}al';
    }
    if (token.length > 4 && token.endsWith('eis')) {
      return '${token.substring(0, token.length - 3)}el';
    }
    if (token.length > 3 && token.endsWith('s')) {
      return token.substring(0, token.length - 1);
    }
    return token;
  }

  static FoodKind kindOf(FoodModel food) {
    final explicit = normalize(food.tipo ?? '');
    if (explicit == 'composto' || explicit == 'composta') {
      return FoodKind.compound;
    }
    if (explicit == 'simples' || explicit == 'simple') {
      return FoodKind.simple;
    }

    final tokens = canonicalTokens(food.nome);
    if (tokens.any(_compoundConnectors.contains)) return FoodKind.compound;
    if (tokens.length >= 3 &&
        tokens.length > 1 &&
        tokens[1] == 'de' &&
        _compoundHeadsWithDe.contains(tokens.first)) {
      return FoodKind.compound;
    }
    return FoodKind.simple;
  }

  static List<FoodModel> filterAndRank(
    Iterable<FoodModel> foods,
    String query,
  ) {
    final queryTokens = canonicalTokens(query);
    if (queryTokens.isEmpty) return foods.toList(growable: false);

    final ranked = <({FoodModel food, int score})>[];
    for (final food in foods) {
      final score = _score(food, queryTokens);
      if (score != null) ranked.add((food: food, score: score));
    }
    ranked.sort((a, b) {
      final byScore = a.score.compareTo(b.score);
      if (byScore != 0) return byScore;
      return normalize(a.food.nome).compareTo(normalize(b.food.nome));
    });
    return ranked.map((item) => item.food).toList(growable: false);
  }

  static int? _score(FoodModel food, List<String> queryTokens) {
    final foodTokens = canonicalTokens(food.nome);
    if (foodTokens.isEmpty) return null;

    final queryPhrase = queryTokens.join(' ');
    final foodPhrase = foodTokens.join(' ');
    int? score;
    if (foodPhrase == queryPhrase) {
      score = 0;
    } else if (foodTokens.first == queryTokens.first &&
        queryTokens.every(foodTokens.contains)) {
      score = 10 + foodTokens.length;
    } else if (foodPhrase.startsWith(queryPhrase)) {
      score = 20 + foodTokens.length;
    } else {
      final allTokensMatch = queryTokens.every(
        (queryToken) => foodTokens.any(
          (foodToken) =>
              foodToken == queryToken || foodToken.startsWith(queryToken),
        ),
      );
      if (allTokensMatch) score = 40 + foodTokens.length;
    }
    if (score == null) return null;
    if (kindOf(food) == FoodKind.compound) score += 100;
    return score;
  }
}
