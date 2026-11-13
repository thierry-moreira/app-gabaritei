import 'dart:math';

import '../core/auth/auth_gateway.dart';
import '../core/data/database.dart';
import '../core/data/repository_helpers.dart';
import '../core/errors/app_exception.dart';
import '../core/validation/validators.dart';
import '../../models/user_profile.dart';

/// Página pública usada nos e-mails de confirmação/recuperação do Auth.
const urlPosEmail = 'https://thierry-moreira.github.io/gabaritei-questoes/';

class CadastroResultado {
  const CadastroResultado({
    required this.pendenteConfirmacao,
    this.perfil,
    this.email,
  });

  final bool pendenteConfirmacao;
  final UserProfile? perfil;
  final String? email;
}

class AuthRepository {
  AuthRepository({required this._auth, required this._db});

  final AuthGateway _auth;
  final GabariteiDatabase _db;
  final Random _random = Random.secure();

  AuthUser? get usuarioAtual => _auth.currentUser;

  Future<UserProfile> entrar({
    required String email,
    required String password,
  }) async {
    final normalizado = email.trim().toLowerCase();
    final session = await mapDatabaseErrors(
      () => _auth.signIn(email: normalizado, password: password),
    );
    if (session == null) {
      throw AuthException('E-mail ou senha incorretos.');
    }
    final perfil = await _garantirPerfil(
      usernameSugerido: Validators.usernameFromEmail(normalizado),
      email: normalizado,
    );
    if (perfil == null) {
      throw AuthException(
        'Não foi possível carregar seu perfil. Tente novamente.',
      );
    }
    return perfil;
  }

  Future<CadastroResultado> cadastrar({
    required String username,
    required String email,
    required String password,
    required String confirmacao,
  }) async {
    final usernameValidado = Validators.username(username);
    if (!usernameValidado.isValid) {
      throw ValidationException(usernameValidado.error!);
    }
    final emailErro = Validators.email(email);
    if (emailErro != null) throw ValidationException(emailErro);
    final senhaErro = Validators.password(password);
    if (senhaErro != null) throw ValidationException(senhaErro);
    final confirmacaoErro = Validators.passwordConfirmation(
      password,
      confirmacao,
    );
    if (confirmacaoErro != null) throw ValidationException(confirmacaoErro);

    final normalizado = email.trim().toLowerCase();
    try {
      final session = await mapDatabaseErrors(
        () => _auth.signUp(
          email: normalizado,
          password: password,
          emailRedirectTo: urlPosEmail,
        ),
      );
      if (session == null || session.pendingConfirmation) {
        return CadastroResultado(
          pendenteConfirmacao: true,
          email: normalizado,
        );
      }
      final perfil = await _garantirPerfil(
        usernameSugerido: usernameValidado.value!,
        email: normalizado,
      );
      return CadastroResultado(
        pendenteConfirmacao: false,
        perfil: perfil,
        email: normalizado,
      );
    } on AuthException catch (error) {
      final texto = error.message.toLowerCase();
      if (texto.contains('já tem conta') ||
          texto.contains('already') ||
          texto.contains('registered') ||
          texto.contains('exists')) {
        throw AuthException(
          'Este e-mail já tem conta. Faça login ou recupere a senha.',
        );
      }
      rethrow;
    }
  }

  Future<void> recuperarSenha(String email) async {
    final normalizado = email.trim().toLowerCase();
    if (Validators.email(normalizado) != null) {
      throw ValidationException('Informe um e-mail válido.');
    }
    await mapDatabaseErrors(
      () => _auth.resetPassword(normalizado, redirectTo: urlPosEmail),
    );
  }

  Future<void> sair() => _auth.signOut();

  Future<UserProfile?> perfilAtual() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return mapDatabaseErrors(() async {
      final row = await _db
          .from('usuarios')
          .select('*')
          .eq('auth_id', user.id)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return UserProfile.fromMap(row);
    });
  }

  /// Garante a linha `usuarios` da conta Auth logada.
  ///
  /// 1. procura por `auth_id`;
  /// 2. tenta adotar perfil legado sem vínculo (RLS valida o e-mail do JWT);
  /// 3. cria uma linha nova — em colisão de username, tenta sufixo `_hex`.
  Future<UserProfile?> _garantirPerfil({
    required String usernameSugerido,
    required String email,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    return mapDatabaseErrors(() async {
      final existente = await _db
          .from('usuarios')
          .select('*')
          .eq('auth_id', user.id)
          .limit(1)
          .maybeSingle();
      if (existente != null) return UserProfile.fromMap(existente);

      try {
        final relink = await _db
            .from('usuarios')
            .update({'auth_id': user.id})
            .isNull('auth_id')
            .eq('email', email)
            .execute();
        if (relink.isNotEmpty) {
          return UserProfile.fromMap(relink.first);
        }
      } on AppException {
        // Re-link é melhor esforço: a criação do perfil continua.
      }

      final base = Validators.usernameBase(usernameSugerido);
      final sufixo = '_${_tokenHex(2)}';
      final candidatos = <String>[
        base,
        if (base.length + sufixo.length <= Validators.usernameMax)
          '$base$sufixo'
        else
          '${base.substring(0, Validators.usernameMax - sufixo.length).trim()}$sufixo',
      ];

      for (var i = 0; i < candidatos.length; i++) {
        try {
          final linhas = await _db
              .from('usuarios')
              .insert({
                'auth_id': user.id,
                'username': candidatos[i],
                'email': email,
              });
          if (linhas.isEmpty) continue;
          return UserProfile.fromMap(linhas.first);
        } on AppException catch (error) {
          if (i == 0 && error.code == '23505') continue;
          rethrow;
        }
      }
      return null;
    });
  }

  String _tokenHex(int bytes) {
    final buffer = StringBuffer();
    for (var i = 0; i < bytes; i++) {
      buffer.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
