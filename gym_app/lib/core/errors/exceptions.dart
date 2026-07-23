/// Exceções personalizadas da aplicação.
class ServerException implements Exception {
  final String message;
  final int? statusCode;
  const ServerException({this.message = 'Erro no servidor', this.statusCode});
}

class CacheException implements Exception {
  final String message;
  const CacheException({this.message = 'Erro de cache'});
}

class AuthException implements Exception {
  final String message;
  final String code;
  const AuthException({required this.message, required this.code});

  factory AuthException.fromFirebaseCode(String code) {
    switch (code) {
      case 'user-not-found':
        return AuthException(
          code: code,
          message: 'Utilizador não encontrado.',
        );
      case 'wrong-password':
        return AuthException(
          code: code,
          message: 'Palavra-passe incorreta.',
        );
      case 'email-already-in-use':
        return AuthException(
          code: code,
          message: 'Este e-mail já está registado.',
        );
      case 'invalid-email':
        return AuthException(
          code: code,
          message: 'E-mail inválido.',
        );
      case 'user-disabled':
        return AuthException(
          code: code,
          message: 'Conta desativada.',
        );
      case 'weak-password':
        return AuthException(
          code: code,
          message: 'A palavra-passe é demasiado fraca.',
        );
      case 'network-request-failed':
        return AuthException(
          code: code,
          message: 'Erro de ligação. Verifica a internet.',
        );
      case 'too-many-requests':
        return AuthException(
          code: code,
          message: 'Demasiadas tentativas. Tenta novamente mais tarde.',
        );
      default:
        return AuthException(
          code: code,
          message: 'Ocorreu um erro. Tenta novamente.',
        );
    }
  }
}

class NetworkException implements Exception {
  final String message;
  const NetworkException({this.message = 'Sem ligação à internet'});
}

class PermissionException implements Exception {
  final String message;
  const PermissionException({this.message = 'Permissão negada'});
}

class ValidationException implements Exception {
  final String message;
  final String? field;
  const ValidationException({required this.message, this.field});
}

class DocumentNotFoundException implements Exception {
  final String message;
  const DocumentNotFoundException({this.message = 'Documento não encontrado'});
}
