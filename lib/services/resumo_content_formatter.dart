/// Formatação segura do Markdown/HTML limitado usado nos resumos da IA.
///
/// O desktop usa Marked e KaTeX. No app, convertemos a mesma sintaxe para
/// blocos nativos e texto matemático legível, sem executar HTML arbitrário.
enum ResumoBlockKind { heading, paragraph, bullet }

class ResumoTextRun {
  const ResumoTextRun(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.code = false,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool code;
}

class ResumoContentBlock {
  const ResumoContentBlock({
    required this.kind,
    required this.runs,
    required this.raw,
    this.level = 0,
  });

  final ResumoBlockKind kind;
  final List<ResumoTextRun> runs;

  /// Linha original, ainda com Markdown/LaTeX, usada pelo renderizador da
  /// interface. O PDF continua usando [runs], que são texto puro.
  final String raw;

  final int level;
}

class ResumoContentFormatter {
  const ResumoContentFormatter._();

  static final _inlinePattern = RegExp(
    r'<b>([\s\S]*?)</b>|<i>([\s\S]*?)</i>|<code>([\s\S]*?)</code>|'
    r'\*\*([\s\S]*?)\*\*|\*([^*\n]+)\*|`([^`]+)`',
    caseSensitive: false,
  );

  static List<ResumoContentBlock> parse(String content) {
    final normalizado = content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<strong>', caseSensitive: false), '<b>')
        .replaceAll(RegExp(r'</strong>', caseSensitive: false), '</b>')
        .replaceAll(RegExp(r'<em>', caseSensitive: false), '<i>')
        .replaceAll(RegExp(r'</em>', caseSensitive: false), '</i>');

    final blocos = <ResumoContentBlock>[];
    for (final rawLine in normalizado.split('\n')) {
      final linha = rawLine.trim();
      if (linha.isEmpty) continue;

      final titulo = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(linha);
      if (titulo != null) {
        blocos.add(
          ResumoContentBlock(
            kind: ResumoBlockKind.heading,
            level: titulo.group(1)!.length,
            runs: _runs(titulo.group(2)!),
            raw: titulo.group(2)!,
          ),
        );
        continue;
      }

      final bullet = RegExp(r'^(?:•|[-*])\s+(.*)$').firstMatch(linha);
      if (bullet != null) {
        blocos.add(
          ResumoContentBlock(
            kind: ResumoBlockKind.bullet,
            runs: _runs(bullet.group(1)!),
            raw: bullet.group(1)!,
          ),
        );
        continue;
      }

      blocos.add(
        ResumoContentBlock(
          kind: ResumoBlockKind.paragraph,
          runs: _runs(linha),
          raw: linha,
        ),
      );
    }
    return blocos;
  }

  static String plainText(String content) {
    return parse(content)
        .map((block) {
          final text = block.runs.map((run) => run.text).join();
          return block.kind == ResumoBlockKind.bullet ? '• $text' : text;
        })
        .join('\n\n');
  }

  static List<ResumoTextRun> _runs(String source) {
    final texto = _mathToReadable(_decodeEntities(source));
    final runs = <ResumoTextRun>[];
    var inicio = 0;

    for (final match in _inlinePattern.allMatches(texto)) {
      if (match.start > inicio) {
        runs.add(
          ResumoTextRun(_stripTags(texto.substring(inicio, match.start))),
        );
      }
      final strongTag = match.group(1);
      final italicTag = match.group(2);
      final codeTag = match.group(3);
      final markdownBold = match.group(4);
      final markdownItalic = match.group(5);
      final markdownCode = match.group(6);
      final text =
          strongTag ??
          italicTag ??
          codeTag ??
          markdownBold ??
          markdownItalic ??
          markdownCode ??
          '';
      runs.add(
        ResumoTextRun(
          _stripTags(text),
          bold: strongTag != null || markdownBold != null,
          italic: italicTag != null || markdownItalic != null,
          code: codeTag != null || markdownCode != null,
        ),
      );
      inicio = match.end;
    }
    if (inicio < texto.length) {
      runs.add(ResumoTextRun(_stripTags(texto.substring(inicio))));
    }
    return runs.where((run) => run.text.isNotEmpty).toList(growable: false);
  }

  static String _stripTags(String value) =>
      value.replaceAll(RegExp(r'<[^>]*>'), '');

  static String _decodeEntities(String value) => value
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'");

  static String _mathToReadable(String value) {
    return value
        .replaceAllMapped(
          RegExp(r'\\frac\{([^{}]*)\}\{([^{}]*)\}'),
          (match) => '${match.group(1)}/${match.group(2)}',
        )
        .replaceAllMapped(
          RegExp(r'\\text\{([^{}]*)\}'),
          (match) => match.group(1)!,
        )
        .replaceAllMapped(
          RegExp(r'\\sqrt\{([^{}]*)\}'),
          (match) => '√(${match.group(1)})',
        )
        .replaceAll(r'\times', '×')
        .replaceAll(r'\cdot', '·')
        .replaceAll(r'\div', '÷')
        .replaceAll(r'\leq', '≤')
        .replaceAll(r'\geq', '≥')
        .replaceAll(r'\neq', '≠')
        .replaceAll(r'\infty', '∞')
        .replaceAll(r'\pi', 'π')
        .replaceAll(r'\alpha', 'α')
        .replaceAll(r'\beta', 'β')
        .replaceAll(r'\sum', 'Σ')
        .replaceAll(r'\left', '')
        .replaceAll(r'\right', '')
        .replaceAll(r'\{', '{')
        .replaceAll(r'\}', '}')
        .replaceAll(RegExp(r'\\\(|\\\)|\\\[|\\\]|\$\$'), '')
        .replaceAll(RegExp(r'<(?!/?(?:b|i|code)\b)[^>]*>'), '');
  }
}
