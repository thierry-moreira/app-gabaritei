import 'package:supabase_flutter/supabase_flutter.dart';

/// Identidade autenticada exposta ao domínio.
class AuthUser {
  const AuthUser({required this.id, this.email});

  final String id;
  final String? email;
}

/// Sessão devolvida pelo login/cadastro.
class AuthSession {
  const AuthSession({
    required this.user,
    this.accessToken,
    this.refreshToken,
    this.pendingConfirmation = false,
  });

  final AuthUser user;
  final String? accessToken;
  final String? refreshToken;

  /// `true` quando o projeto exige confirmação de e-mail e o cadastro ainda
  /// não criou sessão (o backend Flask trata esse caso com uma mensagem).
  final bool pendingConfirmation;
}

/// Porta de autenticação: permite fake nos testes sem tocar no GoTrue.
abstract class AuthGateway {
  AuthUser? get currentUser;

  Future<AuthSession?> signIn({
    required String email,
    required String password,
  });

  Future<AuthSession?> signUp({
    required String email,
    required String password,
    String? emailRedirectTo,
  });

  Future<void> signOut();

  Future<void> resetPassword(String email, {String? redirectTo});
}

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this.client);

  final SupabaseClient client;

  @override
  AuthUser? get currentUser {
    final user = client.auth.currentUser;
    return user == null ? null : AuthUser(id: user.id, email: user.email);
  }

  @override
  Future<AuthSession?> signIn({
    required String email,
    required String password,
  }) async {
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return _sessionFrom(response);
  }

  @override
  Future<AuthSession?> signUp({
    required String email,
    required String password,
    String? emailRedirectTo,
  }) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: emailRedirectTo,
    );
    final session = _sessionFrom(response);
    if (session != null) return session;
    final user = response.user;
    if (user == null) return null;
    return AuthSession(
      user: AuthUser(id: user.id, email: user.email),
      pendingConfirmation: true,
    );
  }

  @override
  Future<void> signOut() => client.auth.signOut();

  @override
  Future<void> resetPassword(String email, {String? redirectTo}) {
    return client.auth.resetPasswordForEmail(email, redirectTo: redirectTo);
  }

  AuthSession? _sessionFrom(AuthResponse response) {
    final session = response.session;
    final user = response.user;
    if (session == null || user == null) return null;
    return AuthSession(
      user: AuthUser(id: user.id, email: user.email),
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
  }
}
