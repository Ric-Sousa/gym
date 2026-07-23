/// Utilitários de validação.
class Validators {
  Validators._();

  /// Valida formato de e-mail.
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'O e-mail é obrigatório.';
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'E-mail inválido.';
    }
    return null;
  }

  /// Valida palavra-passe (mínimo 6 caracteres).
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'A palavra-passe é obrigatória.';
    }
    if (value.length < 6) {
      return 'A palavra-passe deve ter pelo menos 6 caracteres.';
    }
    return null;
  }

  /// Valida nome (não vazio).
  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'O nome é obrigatório.';
    }
    if (value.trim().length < 2) {
      return 'O nome deve ter pelo menos 2 caracteres.';
    }
    return null;
  }

  /// Valida número positivo.
  static String? positiveNumber(String? value, {String fieldName = 'Valor'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName é obrigatório.';
    }
    final number = double.tryParse(value.replaceAll(',', '.'));
    if (number == null) {
      return '$fieldName deve ser um número.';
    }
    if (number <= 0) {
      return '$fieldName deve ser maior que zero.';
    }
    return null;
  }

  /// Valida número de série de exercício.
  static String? exerciseSeries(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Obrigatório';
    }
    final number = int.tryParse(value);
    if (number == null || number < 1 || number > 10) {
      return '1-10 séries';
    }
    return null;
  }

  /// Valida repetições.
  static String? exerciseReps(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Obrigatório';
    }
    final number = int.tryParse(value);
    if (number == null || number < 1 || number > 100) {
      return '1-100 reps';
    }
    return null;
  }

  /// Valida calorias (número positivo).
  static String? calories(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Obrigatório';
    }
    final number = double.tryParse(value.replaceAll(',', '.'));
    if (number == null || number < 0) {
      return 'Calorias inválidas';
    }
    return null;
  }
}
