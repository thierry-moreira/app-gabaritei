/// Erros de domínio do app.
///
/// A UI nunca precisa conhecer detalhes do PostgREST/Supabase: os repositórios
/// traduzem falhas para estas classes e exibem [message].
class AppException implements Exception {
  AppException(this.message, {this.code});

  final String message;
  final String? code;

  bool get isConflict => code == '23505';
  bool get isForbidden => code == '42501';
  bool get isUnauthorized => code == '401';

  @override
  String toString() => 'AppException($code): $message';
}

class ValidationException extends AppException {
  ValidationException(super.message) : super(code: 'validacao');
}

class AuthException extends AppException {
  AuthException(super.message, {super.code});
}

class NotFoundException extends AppException {
  NotFoundException(super.message) : super(code: 'nao_encontrado');
}

class ConflictException extends AppException {
  ConflictException(super.message) : super(code: '23505');
}

class NetworkException extends AppException {
  NetworkException(super.message) : super(code: 'rede');
}

class IaException extends AppException {
  IaException(super.message, {super.code});
}
