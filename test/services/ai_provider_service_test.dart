import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gabaritei_app/services/ai_provider_service.dart';

void main() {
  group('testarChave usa o endpoint nativo de modelos', () {
    test('OpenAI mantém /v1/models com Bearer', () async {
      final requisicoes = <http.Request>[];
      final service = AiProviderService(
        client: MockClient((request) async {
          requisicoes.add(request);
          return http.Response('{}', 200);
        }),
      );

      final resultado = await service.testarChave(
        provedor: 'openai',
        chave: 'sk-teste',
        modelo: 'gpt-5.6-luna',
      );

      expect(resultado.ok, isTrue);
      expect(requisicoes.map((r) => r.url.toString()), [
        'https://api.openai.com/v1/models',
        'https://api.openai.com/v1/models/gpt-5.6-luna',
      ]);
      expect(requisicoes.first.headers['Authorization'], 'Bearer sk-teste');
    });

    test('Anthropic usa /v1/models com x-api-key', () async {
      final requisicoes = <http.Request>[];
      final service = AiProviderService(
        client: MockClient((request) async {
          requisicoes.add(request);
          return http.Response('{}', 200);
        }),
      );

      final resultado = await service.testarChave(
        provedor: 'anthropic',
        chave: 'sk-ant-teste',
        modelo: 'claude-sonnet-5-5',
      );

      expect(resultado.ok, isTrue);
      expect(requisicoes.map((r) => r.url.toString()), [
        'https://api.anthropic.com/v1/models',
        'https://api.anthropic.com/v1/models/claude-sonnet-5-5',
      ]);
      expect(requisicoes.first.headers['x-api-key'], 'sk-ant-teste');
      expect(requisicoes.first.headers['anthropic-version'], '2023-06-01');
    });

    test('Gemini usa o endpoint nativo com x-goog-api-key', () async {
      final requisicoes = <http.Request>[];
      final service = AiProviderService(
        client: MockClient((request) async {
          requisicoes.add(request);
          return http.Response('{}', 200);
        }),
      );

      final resultado = await service.testarChave(
        provedor: 'gemini',
        chave: 'chave-gemini',
        modelo: 'gemini-4-argon',
      );

      expect(resultado.ok, isTrue);
      expect(requisicoes.map((r) => r.url.toString()), [
        'https://generativelanguage.googleapis.com/v1beta/models',
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-4-argon',
      ]);
      expect(requisicoes.first.headers['x-goog-api-key'], 'chave-gemini');
    });
  });
}
