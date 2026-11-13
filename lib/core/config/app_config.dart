/// Configuração pública do Supabase injetada em tempo de build.
///
/// Use `flutter run --dart-define-from-file=env.json` (e o mesmo em builds).
/// O `env.json` local é ignorado pelo Git; veja `env.example.json`.
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  final String supabaseUrl;
  final String supabaseAnonKey;

  /// Valores lidos do ambiente de compilação.
  static const fromEnvironment = AppConfig(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Falha cedo quando faltam as credenciais públicas do Supabase.
  void assertConfigured() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Credenciais ausentes. Rode com '
        '--dart-define-from-file=env.json (veja env.example.json).',
      );
    }
  }
}
