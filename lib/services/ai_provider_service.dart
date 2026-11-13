import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/errors/app_exception.dart';

class AiProviderInfo {
  const AiProviderInfo({
    required this.id,
    required this.nome,
    required this.modelos,
    required this.modeloPadrao,
    required this.linkChave,
    required this.apiBase,
    required this.apiBaseModelos,
  });

  final String id;
  final String nome;
  final List<String> modelos;
  final String modeloPadrao;
  final String linkChave;

  /// Base usada para gerar texto (no Gemini, o endpoint OpenAI-compatível).
  final String apiBase;

  /// Base do endpoint nativo de listagem/consulta de modelos, usado só para
  /// validar a chave e o modelo sem gastar tokens.
  final String apiBaseModelos;
}

class AiConfig {
  const AiConfig({
    required this.provedor,
    required this.modelo,
    required this.chave,
  });

  final String provedor;
  final String modelo;
  final String chave;

  Map<String, dynamic> toJson() => {
    'provedor': provedor,
    'modelo': modelo,
    'chave': chave,
  };

  factory AiConfig.fromJson(Map<String, dynamic> json) => AiConfig(
    provedor: (json['provedor'] ?? '').toString(),
    modelo: (json['modelo'] ?? '').toString(),
    chave: (json['chave'] ?? '').toString(),
  );

  AiConfig copyWith({String? modelo, String? chave}) => AiConfig(
    provedor: provedor,
    modelo: modelo ?? this.modelo,
    chave: chave ?? this.chave,
  );
}

class AiContentPart {
  const AiContentPart._(this.type, {this.text, this.url});

  factory AiContentPart.text(String text) =>
      AiContentPart._('text', text: text);

  factory AiContentPart.imageUrl(String url) =>
      AiContentPart._('image_url', url: url);

  final String type;
  final String? text;
  final String? url;

  Map<String, dynamic> toOpenAiJson() {
    if (type == 'text') return {'type': 'text', 'text': text ?? ''};
    return {
      'type': 'image_url',
      'image_url': {'url': url ?? ''},
    };
  }
}

class AiKeyTest {
  const AiKeyTest(this.ok, this.motivo);

  final bool ok;
  final String motivo;
}

/// Camada BYOK: chamadas diretas aos provedores com a chave do aluno.
class AiProviderService {
  AiProviderService({
    http.Client? client,
    this.timeout = const Duration(seconds: 120),
    this.pingTimeout = const Duration(seconds: 15),
    this.imageTimeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;
  final Duration pingTimeout;
  final Duration imageTimeout;

  static const maxTokensAnthropic = 8192;
  static const maxBytesImagem = 8 * 1024 * 1024;

  static const provedores = <String, AiProviderInfo>{
    'openai': AiProviderInfo(
      id: 'openai',
      nome: 'OpenAI',
      modelos: [
        'gpt-6.1-sol',
        'gpt-5.6-luna',
        'gpt-5.6-terra',
        'gpt-6-sol',
        'gpt-5.2-2025-12-11',
        'gpt-5-2025-08-07',
        'gpt-5.4-2026-03-05',
      ],
      modeloPadrao: 'gpt-5.6-luna',
      linkChave: 'https://platform.openai.com/api-keys',
      apiBase: 'https://api.openai.com/v1',
      apiBaseModelos: 'https://api.openai.com/v1',
    ),
    'gemini': AiProviderInfo(
      id: 'gemini',
      nome: 'Google Gemini',
      modelos: [
        'gemini-4-argon',
        'gemini-3.8-flash',
        'gemini-3.1-pro-preview',
        'gemini-3.5-flash-lite',
      ],
      modeloPadrao: 'gemini-4-argon',
      linkChave: 'https://aistudio.google.com/apikey',
      apiBase: 'https://generativelanguage.googleapis.com/v1beta/openai',
      apiBaseModelos: 'https://generativelanguage.googleapis.com/v1beta',
    ),
    'anthropic': AiProviderInfo(
      id: 'anthropic',
      nome: 'Anthropic Claude',
      modelos: ['claude-haiku-5-5', 'claude-sonnet-5-5'],
      modeloPadrao: 'claude-sonnet-5-5',
      linkChave: 'https://console.anthropic.com/settings/keys',
      apiBase: 'https://api.anthropic.com',
      apiBaseModelos: 'https://api.anthropic.com/v1',
    ),
  };

  static const _parametrosSuportados = <String, Set<String>>{
    'openai': {'temperature', 'top_p', 'presence_penalty', 'frequency_penalty'},
    'gemini': {'temperature', 'top_p'},
    'anthropic': {'temperature', 'top_p'},
  };

  Future<String> chamar({
    required AiConfig config,
    required String systemPrompt,
    required List<AiContentPart> conteudo,
    double temperature = 0.3,
    double? topP,
    double? presencePenalty,
    double? frequencyPenalty,
  }) async {
    final ponto = provedores[config.provedor];
    if (ponto == null) {
      throw IaException(
        'Provedor de IA desconhecido: ${config.provedor}',
        code: 'sem_config',
      );
    }

    final parametros = _filtrarParametros(config.provedor, {
      'temperature': temperature,
      'top_p': topP,
      'presence_penalty': presencePenalty,
      'frequency_penalty': frequencyPenalty,
    });

    if (config.provedor == 'anthropic') {
      return _chamarAnthropic(config, systemPrompt, conteudo, parametros);
    }
    return _chamarOpenAiCompat(
      config,
      systemPrompt,
      conteudo,
      parametros,
      roleSystem: config.provedor == 'openai' ? 'developer' : 'system',
      baseUrl: config.provedor == 'gemini'
          ? '${ponto.apiBase}/'
          : ponto.apiBase,
    );
  }

  Map<String, dynamic> _filtrarParametros(
    String provedor,
    Map<String, dynamic> valores,
  ) {
    final suportados = _parametrosSuportados[provedor] ?? const <String>{};
    return {
      for (final entry in valores.entries)
        if (suportados.contains(entry.key) && entry.value != null)
          entry.key: entry.value,
    };
  }

  Future<String> _chamarOpenAiCompat(
    AiConfig config,
    String systemPrompt,
    List<AiContentPart> conteudo,
    Map<String, dynamic> parametros, {
    required String roleSystem,
    required String baseUrl,
  }) async {
    final tentativas = Map<String, dynamic>.of(parametros);
    for (var tentativa = 0; tentativa < 3; tentativa++) {
      final response = await _postJson(
        Uri.parse('$baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer ${config.chave}',
          'Content-Type': 'application/json',
        },
        body: {
          'model': config.modelo,
          'messages': [
            {'role': roleSystem, 'content': systemPrompt},
            {
              'role': 'user',
              'content': conteudo
                  .map((parte) => parte.toOpenAiJson())
                  .toList(growable: false),
            },
          ],
          ...tentativas,
        },
      );

      if (response.statusCode == 400) {
        final param = _paramRejeitado(response.body);
        if (param != null && tentativas.containsKey(param)) {
          tentativas.remove(param);
          continue;
        }
        throw _erroHttp(response.statusCode, response.body, 'OpenAI/Gemini');
      }
      if (response.statusCode >= 400) {
        throw _erroHttp(response.statusCode, response.body, 'OpenAI/Gemini');
      }
      final dados = _decode(response.body);
      final choices = dados['choices'];
      if (choices is! List || choices.isEmpty) {
        throw IaException('Resposta inválida do provedor.', code: 'falha_ia');
      }
      final message = (choices.first as Map)['message'];
      final content = message is Map ? message['content'] : null;
      return content?.toString() ?? '';
    }
    throw IaException(
      'O modelo rejeitou os parâmetros de geração.',
      code: 'param_invalido',
    );
  }

  Future<String> _chamarAnthropic(
    AiConfig config,
    String systemPrompt,
    List<AiContentPart> conteudo,
    Map<String, dynamic> parametros,
  ) async {
    final blocos = <Map<String, dynamic>>[];
    for (final parte in conteudo) {
      if (parte.type == 'text') {
        blocos.add({'type': 'text', 'text': parte.text ?? ''});
      } else if (parte.type == 'image_url') {
        final bloco = await _baixarImagem(parte.url ?? '');
        if (bloco != null) blocos.add(bloco);
      }
    }

    final tentativas = Map<String, dynamic>.of(parametros);
    for (var tentativa = 0; tentativa < 3; tentativa++) {
      final response = await _postJson(
        Uri.parse('${provedores['anthropic']!.apiBase}/v1/messages'),
        headers: {
          'x-api-key': config.chave,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
        },
        body: {
          'model': config.modelo,
          'max_tokens': maxTokensAnthropic,
          'system': systemPrompt,
          'messages': [
            {
              'role': 'user',
              'content': blocos.isEmpty
                  ? [
                      {'type': 'text', 'text': ''},
                    ]
                  : blocos,
            },
          ],
          ...tentativas,
        },
      );

      if (response.statusCode == 400) {
        final detalhe = _decodeOuVazio(response.body);
        final erro = detalhe['error'];
        final param = erro is Map ? erro['param'] : null;
        if (param is String && tentativas.containsKey(param)) {
          tentativas.remove(param);
          continue;
        }
        throw IaException(
          'Erro da Anthropic (HTTP 400): '
          '${erro is Map ? erro['message'] ?? '' : ''}',
          code: 'falha_ia',
        );
      }
      if (response.statusCode >= 400) {
        throw _erroHttp(response.statusCode, response.body, 'Anthropic');
      }

      final dados = _decode(response.body);
      final partes = dados['content'];
      if (partes is! List) {
        throw IaException('Resposta inválida da Anthropic.', code: 'falha_ia');
      }
      final texto = partes
          .whereType<Map>()
          .where((parte) => parte['type'] == 'text')
          .map((parte) => parte['text']?.toString() ?? '')
          .join();
      if (texto.trim().isEmpty) {
        throw IaException(
          'O provedor devolveu uma resposta vazia.',
          code: 'resposta_vazia',
        );
      }
      return texto;
    }
    throw IaException(
      'O modelo rejeitou os parâmetros de geração.',
      code: 'param_invalido',
    );
  }

  Future<Map<String, dynamic>?> _baixarImagem(String url) async {
    if (url.isEmpty) return null;
    try {
      final response = await _client.get(Uri.parse(url)).timeout(imageTimeout);
      if (response.statusCode != 200) return null;
      if (response.bodyBytes.length > maxBytesImagem) return null;
      var mediaType = response.headers['content-type']?.split(';').first.trim();
      if (mediaType == null ||
          mediaType.isEmpty ||
          mediaType == 'application/octet-stream' ||
          mediaType == 'binary/octet-stream') {
        final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
        mediaType = path.endsWith('.jpg') || path.endsWith('.jpeg')
            ? 'image/jpeg'
            : path.endsWith('.gif')
            ? 'image/gif'
            : path.endsWith('.webp')
            ? 'image/webp'
            : 'image/png';
      }
      const permitidos = {'image/jpeg', 'image/png', 'image/gif', 'image/webp'};
      if (!permitidos.contains(mediaType)) return null;
      return {
        'type': 'image',
        'source': {
          'type': 'base64',
          'media_type': mediaType,
          'data': base64Encode(response.bodyBytes),
        },
      };
    } catch (_) {
      return null;
    }
  }

  Future<AiKeyTest> testarChave({
    required String provedor,
    required String chave,
    required String modelo,
  }) async {
    final info = provedores[provedor];
    if (info == null) return const AiKeyTest(false, 'Provedor não suportado.');
    final headers = switch (provedor) {
      'anthropic' => {'x-api-key': chave, 'anthropic-version': '2023-06-01'},
      // O endpoint nativo do Gemini autentica por header, não por Bearer.
      'gemini' => {'x-goog-api-key': chave},
      _ => {'Authorization': 'Bearer $chave'},
    };

    final base = info.apiBaseModelos;
    final primeiro = await _ping(Uri.parse('$base/models'), headers);
    if (!primeiro.ok) return primeiro;
    return _ping(Uri.parse('$base/models/$modelo'), headers);
  }

  Future<AiKeyTest> _ping(Uri url, Map<String, String> headers) async {
    try {
      final response = await _client
          .get(url, headers: headers)
          .timeout(pingTimeout);
      if (response.statusCode == 401 || response.statusCode == 403) {
        return const AiKeyTest(false, 'Chave de API inválida.');
      }
      if (response.statusCode == 404) {
        return const AiKeyTest(false, 'Modelo não encontrado no provedor.');
      }
      if (response.statusCode == 402) {
        return const AiKeyTest(
          false,
          'Sua conta no provedor não tem créditos/billing ativo. '
          'Adicione créditos e tente novamente.',
        );
      }
      if (response.statusCode != 200) {
        return AiKeyTest(
          false,
          'Erro ao validar no provedor (HTTP ${response.statusCode}).',
        );
      }
      return const AiKeyTest(true, '');
    } on TimeoutException {
      return const AiKeyTest(
        false,
        'Não foi possível contatar o provedor. Verifique sua internet.',
      );
    } catch (_) {
      return const AiKeyTest(
        false,
        'Não foi possível contatar o provedor. Verifique sua internet.',
      );
    }
  }

  Future<http.Response> _postJson(
    Uri url, {
    required Map<String, String> headers,
    required Map<String, dynamic> body,
  }) async {
    try {
      return await _client
          .post(url, headers: headers, body: jsonEncode(body))
          .timeout(timeout);
    } on TimeoutException {
      throw IaException(
        'Tempo esgotado ao contatar o provedor de IA. Tente novamente.',
        code: 'falha_rede',
      );
    } catch (e) {
      throw IaException(
        'Falha de conexão com o provedor de IA. Verifique sua internet.',
        code: 'falha_rede',
      );
    }
  }

  String? _paramRejeitado(String body) {
    final dados = _decodeOuVazio(body);
    final erro = dados['error'];
    if (erro is Map) {
      final code = erro['code']?.toString() ?? '';
      final param = erro['param'];
      if (param != null &&
          (code == 'unsupported_value' || code == 'unsupported_parameter')) {
        return param.toString();
      }
      final details = erro['details'];
      if (details is List) {
        for (final detalhe in details.whereType<Map>()) {
          final violacoes = detalhe['fieldViolations'];
          if (violacoes is! List) continue;
          for (final violacao in violacoes.whereType<Map>()) {
            final nome = _extrairUnknownName(
              violacao['description']?.toString() ?? '',
            );
            if (nome != null) return nome;
          }
        }
      }
    }
    final texto = body;
    if (texto.contains('unsupported_value') ||
        texto.contains('unsupported_parameter')) {
      final match = RegExp(r"'param':\s*'([^']+)'").firstMatch(texto);
      if (match != null) return match.group(1);
    }
    return _extrairUnknownName(texto);
  }

  String? _extrairUnknownName(String texto) {
    final match = RegExp(r'Unknown name\s+"([^"]+)"').firstMatch(texto);
    return match?.group(1);
  }

  AppException _erroHttp(int status, String body, String provedor) {
    final dados = _decodeOuVazio(body);
    final erro = dados['error'];
    final mensagem = erro is Map ? (erro['message']?.toString() ?? '') : body;
    if (status == 401 || status == 403) {
      return IaException(
        'Chave de API inválida para o provedor escolhido.',
        code: 'chave_invalida',
      );
    }
    if (status == 404) {
      return IaException(
        'Modelo não encontrado no provedor. Ajuste em Configurações da conta.',
        code: 'modelo_invalido',
      );
    }
    if (status == 402) {
      return IaException(
        'Sua conta no provedor está sem créditos/billing ativo (saldo zerado '
        'ou limite de gastos atingido). Adicione créditos e tente novamente.',
        code: 'sem_credito',
      );
    }
    if (status == 429) {
      return IaException(
        'Limite de requisições da sua chave de IA atingido. Tente em instantes.',
        code: 'rate_limit',
      );
    }
    return IaException(
      'Erro do provedor $provedor (HTTP $status): $mensagem',
      code: 'falha_ia',
    );
  }

  Map<String, dynamic> _decode(String body) {
    try {
      final value = jsonDecode(body);
      if (value is Map) {
        return value.map((key, item) => MapEntry(key.toString(), item));
      }
    } catch (_) {}
    throw IaException('Resposta inválida do provedor.', code: 'falha_ia');
  }

  Map<String, dynamic> _decodeOuVazio(String body) {
    try {
      final value = jsonDecode(body);
      if (value is Map) {
        return value.map((key, item) => MapEntry(key.toString(), item));
      }
    } catch (_) {}
    return const {};
  }
}
