import 'package:gabaritei_app/core/config/app_config.dart';
import 'package:test/test.dart';

void main() {
  test('Supabase URL and public key are sufficient for app configuration', () {
    const config = AppConfig(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'publishable-key',
    );

    expect(config.isConfigured, isTrue);
    expect(() => config.assertConfigured(), returnsNormally);
  });

  test('configuration is invalid when a Supabase credential is absent', () {
    const config = AppConfig(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: '',
    );

    expect(config.isConfigured, isFalse);
    expect(() => config.assertConfigured(), throwsStateError);
  });
}
