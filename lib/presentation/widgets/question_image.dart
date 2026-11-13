import 'dart:convert';

import 'package:flutter/material.dart';

/// Extrai e renderiza imagens de questões em URL ou em data URI base64.
///
/// Algumas questões (por exemplo, tabelas e gráficos) trazem a imagem embutida
/// no HTML como `data:image/png;base64,...`, enquanto outras usam URL remota.
/// O desktop exibe ambos diretamente em `<img>`; no Flutter cada origem precisa
/// ser convertida para o provider correspondente.
class QuestionImage extends StatelessWidget {
  const QuestionImage({super.key, required this.source});

  final String source;

  static final _src = RegExp(
    r'''<img\b[^>]*\bsrc\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))''',
    caseSensitive: false,
  );

  static final _dataUri = RegExp(
    r'^data:image/[^;,]+;base64,([\s\S]*)$',
    caseSensitive: false,
  );

  /// Junta a coluna `url_imagem` e as imagens declaradas no HTML, removendo
  /// duplicatas e preservando tanto URLs quanto data URIs de imagem.
  static List<String> extrair({String? urlImagem, required String html}) {
    final imagens = <String>{};
    void adicionar(String? valor) {
      final src = _decodificarEntidades(valor ?? '').trim();
      if (_suportada(src)) imagens.add(src);
    }

    adicionar(urlImagem);
    for (final match in _src.allMatches(html)) {
      adicionar(match.group(1) ?? match.group(2) ?? match.group(3));
    }
    return imagens.toList(growable: false);
  }

  static bool _suportada(String src) {
    if (_dataUri.hasMatch(src)) return true;
    final uri = Uri.tryParse(src);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  static String _decodificarEntidades(String value) => value
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'");

  @override
  Widget build(BuildContext context) {
    final data = _dataUri.firstMatch(source);
    ImageProvider<Object>? provider;
    if (data != null) {
      try {
        final encoded = data.group(1)!.replaceAll(RegExp(r'\s'), '');
        provider = MemoryImage(base64.decode(base64.normalize(encoded)));
      } on FormatException {
        provider = null;
      }
    } else {
      provider = NetworkImage(source);
    }

    final tema = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tema.brightness == Brightness.dark
              ? const Color(0xFF334155)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 450),
          child: provider == null
              ? const _ImagemIndisponivel()
              : Image(
                  image: provider,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const _ImagemIndisponivel(),
                ),
        ),
      ),
    );
  }
}

class _ImagemIndisponivel extends StatelessWidget {
  const _ImagemIndisponivel();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(20),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.broken_image_outlined, size: 18, color: Color(0xFF64748B)),
        SizedBox(width: 8),
        Text(
          'Não foi possível carregar esta imagem.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
      ],
    ),
  );
}
