import 'package:equatable/equatable.dart';

/// Falhas mapeadas para a camada de apresentação.
abstract class Failure extends Equatable {
  final String message;
  const Failure({required this.message});

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  final int? statusCode;
  const ServerFailure({required super.message, this.statusCode});
}

class CacheFailure extends Failure {
  const CacheFailure({super.message = 'Erro de cache'});
}

class AuthFailure extends Failure {
  final String code;
  const AuthFailure({required super.message, required this.code});

  @override
  List<Object?> get props => [message, code];
}

class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'Sem ligação à internet'});
}

class PermissionFailure extends Failure {
  const PermissionFailure({super.message = 'Permissão negada'});
}

class ValidationFailure extends Failure {
  final String? field;
  const ValidationFailure({required super.message, this.field});

  @override
  List<Object?> get props => [message, field];
}

class DocumentNotFoundFailure extends Failure {
  const DocumentNotFoundFailure({super.message = 'Documento não encontrado'});
}
