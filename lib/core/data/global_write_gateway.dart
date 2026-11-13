import 'package:supabase_flutter/supabase_flutter.dart'
    show FunctionException, SupabaseClient;

import '../errors/app_exception.dart';

/// Porta para escritas globais autorizadas no servidor.
abstract interface class GlobalWriteGateway {
  Future<void> submit(Map<String, dynamic> payload);
}

class SupabaseGlobalWriteGateway implements GlobalWriteGateway {
  SupabaseGlobalWriteGateway(this._client);

  static const _functionName = 'secure-global-write';

  final SupabaseClient _client;

  @override
  Future<void> submit(Map<String, dynamic> payload) async {
    try {
      final response = await _client.functions.invoke(
        _functionName,
        body: payload,
      );
      if (response.status < 200 || response.status >= 300) {
        throw _globalWriteFailure(response.status, response.data);
      }
    } on FunctionException catch (error) {
      throw _globalWriteFailure(error.status, error.details);
    }
  }
}

AppException globalWriteFailure(FunctionException error) =>
    _globalWriteFailure(error.status, error.details);

AppException _globalWriteFailure(int status, Object? details) {
  final retryAfter = details is Map
      ? int.tryParse('${details['retry_after_seconds']}')
      : null;

  return switch (status) {
    400 => ValidationException('Os dados enviados são inválidos.'),
    401 => AuthException(
      'Sua sessão expirou. Entre novamente para continuar.',
      code: '401',
    ),
    403 => AppException(
      'Sua conta não tem autorização para esta ação.',
      code: '42501',
    ),
    404 => NotFoundException('A questão não está mais disponível.'),
    409 => ConflictException('Este conteúdo já foi registrado.'),
    429 => AppException(
      'Muitas solicitações. Aguarde ${retryAfter ?? 60} segundos e tente novamente.',
      code: '429',
    ),
    0 => NetworkException('Sem conexão com o servidor. Tente novamente.'),
    _ => AppException(
      'Não foi possível concluir a operação. Tente novamente.',
      code: '$status',
    ),
  };
}
