import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../errors/app_exception.dart';

/// Executa uma operação de banco traduzindo falhas técnicas para o domínio.
Future<T> mapDatabaseErrors<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on AppException {
    rethrow;
  } on sb.PostgrestException catch (error) {
    throw AppException(
      _mensagemPostgrest(error),
      code: error.code,
    );
  } on sb.AuthException catch (error) {
    throw AuthException(_mensagemAuth(error), code: error.statusCode);
  } on TimeoutException {
    throw NetworkException('Tempo esgotado. Tente novamente.');
  } on SocketException {
    throw NetworkException('Sem conexão com a internet.');
  } on http.ClientException {
    throw NetworkException('Falha de conexão. Verifique sua internet.');
  }
}

String _mensagemPostgrest(sb.PostgrestException error) {
  final mensagem = error.message;
  if (mensagem.contains('duplicate key')) {
    return 'Este registro já existe.';
  }
  if (error.code == '42501') {
    return 'Você não tem permissão para esta ação.';
  }
  if (error.code == '23503') {
    return 'O registro referenciado não existe mais.';
  }
  return mensagem;
}

/// Traduz as mensagens mais comuns do GoTrue para o português.
String _mensagemAuth(sb.AuthException error) {
  final mensagem = error.message.toLowerCase();
  if (mensagem.contains('invalid login credentials') ||
      mensagem.contains('invalid credentials')) {
    return 'E-mail ou senha incorretos.';
  }
  if (mensagem.contains('email not confirmed')) {
    return 'Confirme seu e-mail antes de entrar.';
  }
  if (mensagem.contains('already registered') ||
      mensagem.contains('user already') ||
      mensagem.contains('email address is already')) {
    return 'Este e-mail já tem conta. Faça login ou recupere a senha.';
  }
  if (mensagem.contains('rate limit') || mensagem.contains('too many')) {
    return 'Muitas tentativas. Aguarde alguns minutos e tente novamente.';
  }
  if (mensagem.contains('password should be at least')) {
    return 'A senha é curta demais. Use pelo menos 8 caracteres.';
  }
  if (mensagem.contains('unable to validate email') ||
      mensagem.contains('invalid email')) {
    return 'Informe um e-mail válido.';
  }
  return error.message;
}
