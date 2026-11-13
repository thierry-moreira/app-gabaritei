import 'package:flutter/material.dart';
import 'package:val_latex_flutter/val_latex_flutter.dart';

import 'blockquote_view.dart';
import 'code_block_view.dart';
import 'question_image.dart';

/// Tipo de trecho produzido por [LatexText.dividirBlocosCodigo].
enum LatexTrechoTipo { texto, codigo, citacao, imagem }

/// Trecho de texto, bloco de código ou citação produzido por [LatexText].
///
/// Telas que precisam formatar o texto linha a linha usam
/// [LatexText.dividirBlocosCodigo] para não quebrar um bloco de código ou uma
/// citação no meio.
class LatexTrecho {
  const LatexTrecho.texto(this.texto) : tipo = LatexTrechoTipo.texto;

  const LatexTrecho.codigo(this.texto) : tipo = LatexTrechoTipo.codigo;

  const LatexTrecho.citacao(this.texto) : tipo = LatexTrechoTipo.citacao;

  const LatexTrecho.imagem(this.texto) : tipo = LatexTrechoTipo.imagem;

  final String texto;
  final LatexTrechoTipo tipo;

  bool get codigo => tipo == LatexTrechoTipo.codigo;

  bool get citacao => tipo == LatexTrechoTipo.citacao;

  bool get imagem => tipo == LatexTrechoTipo.imagem;
}

/// Estado de uma lista HTML durante a conversão para texto móvel.
class _ListaHtml {
  _ListaHtml({
    required this.tag,
    required this.estilo,
    required this.proximo,
    required this.invertida,
  });

  final String tag;
  final String estilo;
  final bool invertida;
  int proximo;

  String proximoMarcador() {
    final valor = switch (estilo) {
      'upper-roman' => _romano(proximo),
      'lower-roman' => _romano(proximo).toLowerCase(),
      'upper-alpha' || 'upper-latin' => _alfabetico(proximo).toUpperCase(),
      'lower-alpha' || 'lower-latin' => _alfabetico(proximo).toLowerCase(),
      _ => '$proximo',
    };
    proximo += invertida ? -1 : 1;
    return '$valor.';
  }

  static String _romano(int valor) {
    if (valor <= 0 || valor > 3999) return '$valor';
    const numeros = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
    const simbolos = [
      'M',
      'CM',
      'D',
      'CD',
      'C',
      'XC',
      'L',
      'XL',
      'X',
      'IX',
      'V',
      'IV',
      'I',
    ];
    var restante = valor;
    final resultado = StringBuffer();
    for (var i = 0; i < numeros.length; i++) {
      while (restante >= numeros[i]) {
        resultado.write(simbolos[i]);
        restante -= numeros[i];
      }
    }
    return resultado.toString();
  }

  static String _alfabetico(int valor) {
    if (valor <= 0) return '$valor';
    final letras = StringBuffer();
    var restante = valor;
    while (restante > 0) {
      restante--;
      letras.writeCharCode(65 + restante % 26);
      restante ~/= 26;
    }
    return String.fromCharCodes(letras.toString().runes.toList().reversed);
  }
}

/// Texto com fórmulas LaTeX e toda a formatação de texto, no mesmo padrão do
/// desktop.
///
/// O desktop usa KaTeX para `$$…$$`, `$…$, `\(…\)` e `\[…\]` e o navegador
/// para as tags HTML (`<strong>`, `<i>`, `<u>`, `<s>`, `<sup>`, `<sub>`,
/// `<mark>`, `<code>`, `<a>`, `<blockquote>`, `<pre>`) e o Markdown do
/// `marked` (`**negrito**`, `*itálico*`, `__negrito__`, `_itálico_`,
/// `~~tachado~~`, `` `código` ``, `[texto](url)`).
///
/// Aqui as mesmas marcações são interpretadas nativamente, preservando
/// negrito, itálico, sublinhado, tachado, sobrescrito/subscrito, realce,
/// código, links e citações.
class LatexText extends StatelessWidget {
  const LatexText(
    this.texto, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.softWrap = true,
    this.streaming = false,
    this.displaySpacing = 6,
    this.highlightStyle,
    this.markdownBoldStyle,
  });

  final String texto;
  final TextStyle? style;
  final TextAlign textAlign;
  final TextDirection? textDirection;
  final int? maxLines;
  final TextOverflow overflow;
  final bool softWrap;

  /// Texto ainda chegando (resposta de IA em streaming): uma fórmula
  /// incompleta é desenhada até onde dá, em vez de virar erro.
  final bool streaming;

  final double displaySpacing;

  /// Estilo aplicado ao conteúdo de `<mark>…</mark>`, como o realce amarelo
  /// dos flashcards. Sem ele, as tags são removidas e o texto fica normal.
  final TextStyle? highlightStyle;

  /// Estilo do negrito Markdown legado (`**…**`), que nos flashcards usa a
  /// cor de destaque. O negrito HTML (`<b>`/`<strong>`) continua herdando a
  /// cor do texto.
  final TextStyle? markdownBoldStyle;

  static const _scanner = MathScanner(
    delimiters: MathDelimiter.standard,
    environments: true,
    markdown: false,
    spacedDollars: false,
  );

  static final _moeda = RegExp(r'(US|U|R)\$');

  // Sentinela para as tags HTML não precisarem virar Markdown e poderem ser
  // distinguidas do negrito legado (`**…**`).
  static const _abreNegrito = '\uE000';
  static const _fechaNegrito = '\uE001';
  static const _abreItalico = '\uE002';
  static const _fechaItalico = '\uE003';
  static const _abreCodigo = '\uE004';
  static const _fechaCodigo = '\uE005';
  static const _abreSublinhado = '\uE008';
  static const _fechaSublinhado = '\uE009';
  static const _abreRiscado = '\uE00A';
  static const _fechaRiscado = '\uE00B';
  static const _abreSuperior = '\uE00C';
  static const _fechaSuperior = '\uE00D';
  static const _abreInferior = '\uE018';
  static const _fechaInferior = '\uE019';
  static const _abreDestaque = '\uE01A';
  static const _fechaDestaque = '\uE01B';
  static const _abreLink = '\uE010';
  static const _fechaLink = '\uE011';
  static const _fechaTextoLink = '\uE012';
  static const _abreCodigoRender = '\uE014';
  static const _fechaCodigoRender = '\uE015';
  static const _abreCitacaoRender = '\uE016';
  static const _fechaCitacaoRender = '\uE017';
  static const _abreImagemRender = '\uE020';
  static const _fechaImagemRender = '\uE021';
  static const _abreCodigoInlineRender = '\uE022';
  static const _fechaCodigoInlineRender = '\uE023';

  /// Blocos que saem intactos da limpeza: `<blockquote>`, `<pre>`, blocos já
  /// delimitados pelo app e blocos Markdown cercados por três crases/tis.
  static final _blocosHtml = RegExp(
    '<blockquote\\b[^>]*>([\\s\\S]*?)</blockquote\\s*>|'
    '<pre\\b[^>]*>([\\s\\S]*?)</pre\\s*>|'
    '$_abreCitacaoRender([\\s\\S]*?)$_fechaCitacaoRender|'
    '$_abreCodigoRender([\\s\\S]*?)$_fechaCodigoRender|'
    r'^[ \t]*(?:```|~~~)[^\n]*\n([\s\S]*?)^[ \t]*(?:```|~~~)[ \t]*$|'
    '$_abreCodigoInlineRender([\\s\\S]*?)$_fechaCodigoInlineRender|'
    '<code\\b[^>]*>([\\s\\S]*?)</code\\s*>|'
    r'`([^`\n]+)`',
    multiLine: true,
    caseSensitive: false,
  );

  /// Trechos já renderizáveis: citação primeiro, para não cortar um bloco de
  /// código que esteja dentro dela.
  static final _trechosRender = RegExp(
    '$_abreCitacaoRender([\\s\\S]*?)$_fechaCitacaoRender|'
    '$_abreCodigoRender([\\s\\S]*?)$_fechaCodigoRender|'
    '$_abreImagemRender([\\s\\S]*?)$_fechaImagemRender',
  );

  static final _trechosCodigoInline = RegExp(
    '$_abreCodigoInlineRender([\\s\\S]*?)$_fechaCodigoInlineRender',
  );

  static final _tagConhecida = RegExp(
    r'</?(?:br|p|div|li|ul|ol|blockquote|figure|figcaption|h[1-6]|span|img|a)'
    r'(?:\s[^>]*)?>',
    caseSensitive: false,
  );

  static final _tagListaHtml = RegExp(
    r'<\s*(/?)\s*(ol|ul|li)\b([^>]*)>',
    caseSensitive: false,
  );
  static final _regiaoCodigoHtml = RegExp(
    '<pre\\b[^>]*>[\\s\\S]*?</pre\\s*>|'
    '<code\\b[^>]*>[\\s\\S]*?</code\\s*>',
    caseSensitive: false,
  );
  static final _estiloLista = RegExp(
    r'list-style-type\s*:\s*([a-z-]+)',
    caseSensitive: false,
  );
  static final _atributoTipoLista = RegExp(
    r'''\btype\s*=\s*["']?([1AaIi])["']?''',
    caseSensitive: false,
  );
  static final _atributoInicioLista = RegExp(
    r'''\bstart\s*=\s*["']?(-?\d+)["']?''',
    caseSensitive: false,
  );
  static final _atributoValorItem = RegExp(
    r'''\bvalue\s*=\s*["']?(-?\d+)["']?''',
    caseSensitive: false,
  );

  static final _markup = RegExp(
    '$_abreNegrito|$_fechaNegrito|$_abreItalico|$_fechaItalico|'
    '$_abreCodigo|$_fechaCodigo|$_abreSublinhado|$_fechaSublinhado|'
    '$_abreRiscado|$_fechaRiscado|$_abreSuperior|$_fechaSuperior|'
    '$_abreInferior|$_fechaInferior|$_abreDestaque|$_fechaDestaque|'
    '$_abreLink([^$_abreLink$_fechaLink$_fechaTextoLink]*)'
    '$_fechaLink([^$_abreLink$_fechaLink$_fechaTextoLink]*)'
    '$_fechaTextoLink|'
    r'\*\*([\s\S]*?)\*\*|__([\s\S]*?)__|'
    r'(?<!\*)\*([^*\n]+)\*(?!\*)|(?<!_)_(?!_)([^_\n]+)(?<!_)_(?!_)|'
    r'~~([^~\n]+)~~|`([^`\n]+)`',
    caseSensitive: false,
  );

  /// Divide o texto em linhas sem quebrar fórmulas de exibição que ocupam
  /// várias linhas (`\[ … \]`, `$$ … $$` ou ambientes).
  static List<String> dividirLinhas(String texto) {
    final normalizado = _protegerMoedas(texto.replaceAll('\r\n', '\n'));
    final linhas = <String>[];
    final buffer = StringBuffer();
    for (final segmento in _scanner.scan(normalizado)) {
      if (segmento is TextSegment) {
        final partes = segmento.text.split('\n');
        for (var i = 0; i < partes.length; i++) {
          buffer.write(partes[i]);
          if (i < partes.length - 1) {
            linhas.add(buffer.toString());
            buffer.clear();
          }
        }
      } else if (segmento is MathSegment) {
        buffer.write(segmento.open);
        buffer.write(segmento.tex);
        buffer.write(segmento.close);
      }
    }
    if (buffer.isNotEmpty) linhas.add(buffer.toString());
    return linhas;
  }

  /// Separa o texto em trechos normais, blocos de código e citações.
  ///
  /// Os blocos já vêm delimitados por [limparHtml]; um bloco continua sendo
  /// um único trecho mesmo quando ocupa várias linhas, para preservar a
  /// indentação e o conteúdo.
  static List<LatexTrecho> dividirBlocosCodigo(String texto) {
    final trechos = <LatexTrecho>[];
    var ultimo = 0;
    for (final match in _trechosRender.allMatches(texto)) {
      if (match.start > ultimo) {
        trechos.add(LatexTrecho.texto(texto.substring(ultimo, match.start)));
      }
      if (match.group(1) != null) {
        trechos.add(LatexTrecho.citacao(match.group(1)!));
      } else if (match.group(3) != null) {
        trechos.add(LatexTrecho.imagem(match.group(3)!));
      } else {
        trechos.add(LatexTrecho.codigo(match.group(2)!));
      }
      ultimo = match.end;
    }
    if (ultimo < texto.length) {
      trechos.add(LatexTrecho.texto(texto.substring(ultimo)));
    }
    return trechos;
  }

  /// Converte o HTML limitado em texto com toda a formatação preservada, sem
  /// destruir as fórmulas.
  ///
  /// As telas precisam remover tags e decodificar entidades antes de exibir o
  /// texto. Fazer isso com regex no HTML inteiro cortaria fórmulas como
  /// `\(x < y > z\)`; aqui o scanner identifica o LaTeX primeiro e só os
  /// trechos de texto passam pela limpeza. Tags de bloco viram quebras e
  /// listas; tags de formatação viram marcadores internos que o renderizador
  /// entende.
  static String limparHtml(String html) {
    if (html.isEmpty) return '';
    final comListasNumeradas = _converterListasForaDeCodigo(
      html.replaceAll('\r\n', '\n'),
    );
    return _processarBlocos(comListasNumeradas, _converterTextoNormal).trim();
  }

  /// Mantém os blocos de código/citação intactos antes de a tela dividir o
  /// texto em seções por linha.
  ///
  /// Sem essa preparação, um bloco de código seria cortado em várias linhas e
  /// cada linha perderia a indentação e o alinhamento.
  static String prepararBlocosCodigo(String texto) => limparHtml(texto);

  /// Mantém os blocos de código/citação intactos e processa só o texto ao
  /// redor.
  static String _processarBlocos(
    String texto,
    String Function(String) processarNormal,
  ) {
    final buffer = StringBuffer();
    var ultimo = 0;
    for (final match in _blocosHtml.allMatches(texto)) {
      if (match.start > ultimo) {
        buffer.write(processarNormal(texto.substring(ultimo, match.start)));
      }
      if (match.group(1) != null) {
        // Citação: o conteúdo interno é limpo recursivamente, para manter
        // listas, negrito e blocos de código de dentro dela.
        buffer.write(
          '$_abreCitacaoRender${limparHtml(match.group(1)!)}'
          '$_fechaCitacaoRender',
        );
      } else if (match.group(2) != null) {
        buffer.write(
          '$_abreCodigoRender${_limparCodigo(match.group(2)!)}'
          '$_fechaCodigoRender',
        );
      } else if (match.group(3) != null || match.group(4) != null) {
        // Bloco já delimitado pelo app: mantém como está.
        buffer.write(match.group(0)!);
      } else if (match.group(5) != null) {
        buffer.write(
          '$_abreCodigoRender${_apararCodigo(match.group(5)!)}'
          '$_fechaCodigoRender',
        );
      } else if (match.group(6) != null) {
        // Já isolado: deixa o conteúdo literal fora do scanner e do Markdown.
        buffer.write(match.group(0)!);
      } else if (match.group(7) != null) {
        buffer.write(
          '$_abreCodigoInlineRender${_decodificarEntidades(match.group(7)!)}'
          '$_fechaCodigoInlineRender',
        );
      } else if (match.group(8) != null) {
        buffer.write(
          '$_abreCodigoInlineRender${match.group(8)!}'
          '$_fechaCodigoInlineRender',
        );
      }
      ultimo = match.end;
    }
    if (ultimo < texto.length) {
      buffer.write(processarNormal(texto.substring(ultimo)));
    }
    return buffer.toString();
  }

  /// Processa um trecho de texto normal: protege fórmulas/moedas, converte
  /// tags de bloco e formatação e decodifica entidades.
  static String _converterTextoNormal(String texto) {
    final protegido = _protegerMoedas(texto);
    final buffer = StringBuffer();
    for (final segmento in _scanner.scan(protegido)) {
      switch (segmento) {
        case TextSegment(:final text):
          buffer.write(_converterMarcacoes(text));
        case MathSegment(:final tex, :final open, :final close):
          buffer
            ..write(open)
            ..write(tex)
            ..write(close);
      }
    }
    return buffer.toString();
  }

  /// Converte as tags HTML em marcadores internos e quebras de linha.
  ///
  /// Tags de formatação (negrito, itálico, sublinhado, tachado, código,
  /// sobrescrito, subscrito, realce e link) viram sentinela; tags de bloco
  /// viram quebras ou listas; o resto conhecido é removido. Só tags da lista
  /// são removidas, para não cortar comparações como `x < y > z`.
  static String _converterMarcacoes(String texto) {
    var limpo = texto
        // Quebras e blocos.
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n')
        .replaceAll(
          RegExp(
            r'</(?:div|h[1-6]|blockquote|figure|figcaption)\s*>',
            caseSensitive: false,
          ),
          '\n',
        )
        // Formatação inline.
        .replaceAll(
          RegExp(r'<(?:strong|b)\b[^>]*>', caseSensitive: false),
          _abreNegrito,
        )
        .replaceAll(
          RegExp(r'</(?:strong|b)\s*>', caseSensitive: false),
          _fechaNegrito,
        )
        .replaceAll(
          RegExp(r'<(?:em|i)\b[^>]*>', caseSensitive: false),
          _abreItalico,
        )
        .replaceAll(
          RegExp(r'</(?:em|i)\s*>', caseSensitive: false),
          _fechaItalico,
        )
        .replaceAll(
          RegExp(r'<(?:u|ins)\b[^>]*>', caseSensitive: false),
          _abreSublinhado,
        )
        .replaceAll(
          RegExp(r'</(?:u|ins)\s*>', caseSensitive: false),
          _fechaSublinhado,
        )
        .replaceAll(
          RegExp(r'<(?:s|strike|del)\b[^>]*>', caseSensitive: false),
          _abreRiscado,
        )
        .replaceAll(
          RegExp(r'</(?:s|strike|del)\s*>', caseSensitive: false),
          _fechaRiscado,
        )
        .replaceAll(
          RegExp(r'<sup\b[^>]*>', caseSensitive: false),
          _abreSuperior,
        )
        .replaceAll(RegExp(r'</sup\s*>', caseSensitive: false), _fechaSuperior)
        .replaceAll(
          RegExp(r'<sub\b[^>]*>', caseSensitive: false),
          _abreInferior,
        )
        .replaceAll(RegExp(r'</sub\s*>', caseSensitive: false), _fechaInferior)
        .replaceAll(RegExp(r'<code\b[^>]*>', caseSensitive: false), _abreCodigo)
        .replaceAll(RegExp(r'</code\s*>', caseSensitive: false), _fechaCodigo)
        .replaceAll(
          RegExp(r'<mark\b[^>]*>', caseSensitive: false),
          _abreDestaque,
        )
        .replaceAll(RegExp(r'</mark\s*>', caseSensitive: false), _fechaDestaque)
        // Links: mantém a URL e o texto de dentro.
        .replaceAllMapped(
          RegExp(
            r'<a\b[^>]*href\s*=\s*"([^"]*)"[^>]*>([\s\S]*?)</a\s*>',
            caseSensitive: false,
          ),
          (match) =>
              '$_abreLink${match.group(1)!}$_fechaLink'
              '${match.group(2)!}$_fechaTextoLink',
        )
        // Imagens embutidas no HTML viram trechos renderizáveis, na posição
        // original do enunciado (inclusive data:image;base64).
        .replaceAllMapped(RegExp(r'<img\b[^>]*>', caseSensitive: false), (
          match,
        ) {
          final imagens = QuestionImage.extrair(html: match.group(0)!);
          if (imagens.isEmpty) return '';
          return '$_abreImagemRender${imagens.first}$_fechaImagemRender';
        })
        // Tags conhecidas restantes.
        .replaceAll(_tagConhecida, '');
    limpo = _decodificarEntidades(limpo);
    return limpo
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  /// Converte listas HTML em marcadores visíveis, respeitando o estilo da
  /// lista ordenada (`1.`, `A.`, `I.` etc.) e sua numeração inicial.
  static String _converterListas(
    String texto, [
    List<_ListaHtml>? contextoLista,
  ]) {
    final pilha = contextoLista ?? <_ListaHtml>[];
    return texto.replaceAllMapped(_tagListaHtml, (match) {
      final fechamento = match.group(1)!.isNotEmpty;
      final tag = match.group(2)!.toLowerCase();
      final atributos = match.group(3) ?? '';

      if (tag == 'li') {
        if (fechamento) return '';
        if (pilha.isEmpty || pilha.last.estilo == 'unordered') {
          return '\n• ';
        }
        final valorItem = _atributoValorItem.firstMatch(atributos);
        if (valorItem != null) {
          pilha.last.proximo =
              int.tryParse(valorItem.group(1)!) ?? pilha.last.proximo;
        }
        final recuo = '  ' * pilha.length;
        return '\n$recuo${pilha.last.proximoMarcador()} ';
      }

      if (fechamento) {
        for (var i = pilha.length - 1; i >= 0; i--) {
          if (pilha[i].tag == tag) {
            pilha.removeRange(i, pilha.length);
            break;
          }
        }
        return '\n';
      }

      if (tag == 'ul') {
        pilha.add(
          _ListaHtml(
            tag: tag,
            estilo: 'unordered',
            proximo: 1,
            invertida: false,
          ),
        );
        return '\n';
      }

      final estiloDeclarado = _estiloLista.firstMatch(atributos)?.group(1);
      final tipoDeclarado = _atributoTipoLista.firstMatch(atributos)?.group(1);
      final estilo = _estiloOrdenado(estiloDeclarado, tipoDeclarado);
      final inicio = int.tryParse(
        _atributoInicioLista.firstMatch(atributos)?.group(1) ?? '',
      );
      final invertida = RegExp(
        r'\breversed\b',
        caseSensitive: false,
      ).hasMatch(atributos);
      pilha.add(
        _ListaHtml(
          tag: tag,
          estilo: estilo,
          proximo: inicio ?? 1,
          invertida: invertida,
        ),
      );
      return '\n';
    });
  }

  /// Converte as listas na passagem completa do HTML, antes de isolar cada
  /// `<code>`. O contexto da lista atravessa os trechos de código, porque um
  /// `<li>` pode conter código inline antes do próximo item.
  static String _converterListasForaDeCodigo(String texto) {
    final buffer = StringBuffer();
    final contexto = <_ListaHtml>[];
    var ultimo = 0;
    for (final match in _regiaoCodigoHtml.allMatches(texto)) {
      if (match.start > ultimo) {
        buffer.write(
          _converterListas(texto.substring(ultimo, match.start), contexto),
        );
      }
      buffer.write(match.group(0)!);
      ultimo = match.end;
    }
    if (ultimo < texto.length) {
      buffer.write(_converterListas(texto.substring(ultimo), contexto));
    }
    return buffer.toString();
  }

  static String _estiloOrdenado(String? estilo, String? tipo) {
    switch (estilo?.toLowerCase()) {
      case 'upper-roman':
        return 'upper-roman';
      case 'lower-roman':
        return 'lower-roman';
      case 'upper-alpha':
      case 'upper-latin':
        return 'upper-alpha';
      case 'lower-alpha':
      case 'lower-latin':
        return 'lower-alpha';
      case 'decimal':
        return 'decimal';
      case 'decimal-leading-zero':
        return 'decimal-leading-zero';
    }
    switch (tipo) {
      case 'I':
        return 'upper-roman';
      case 'i':
        return 'lower-roman';
      case 'A':
        return 'upper-alpha';
      case 'a':
        return 'lower-alpha';
      default:
        return 'decimal';
    }
  }

  /// Limpa o conteúdo interno de um `<pre>`: remove as tags reais, decodifica
  /// as entidades e mantém quebras de linha e espaços à esquerda.
  static String _limparCodigo(String html) {
    var codigo = html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(
          RegExp(r'</?(?:code|pre)\b[^>]*>', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'<[^>]+>'), '');
    codigo = _decodificarEntidades(codigo)
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    return _apararCodigo(codigo);
  }

  /// Remove apenas linhas vazias nas pontas e espaços no fim das linhas.
  /// Os espaços à esquerda são a indentação do código e não podem sair.
  static String _apararCodigo(String codigo) {
    final linhas = codigo.split('\n');
    while (linhas.isNotEmpty && linhas.first.trim().isEmpty) {
      linhas.removeAt(0);
    }
    while (linhas.isNotEmpty && linhas.last.trim().isEmpty) {
      linhas.removeLast();
    }
    return linhas
        .map((linha) => linha.replaceFirst(RegExp(r'[ \t]+$'), ''))
        .join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(style);
    final normalizado = limparHtml(texto);
    if (normalizado.isEmpty) return const SizedBox.shrink();

    final blocos = <Widget>[];
    var spans = <InlineSpan>[];
    var destacado = false;

    void flush() {
      if (spans.isEmpty) return;
      blocos.add(
        Text.rich(
          TextSpan(children: spans),
          style: base,
          textAlign: textAlign,
          textDirection: textDirection,
          softWrap: softWrap,
          maxLines: maxLines,
          overflow: overflow,
        ),
      );
      spans = <InlineSpan>[];
    }

    void adicionarTexto(String valor) {
      for (final segmento in _scanner.scan(valor)) {
        switch (segmento) {
          case TextSegment(:final text):
            var trecho = text;
            if (spans.isEmpty && blocos.isNotEmpty) {
              trecho = trecho.replaceFirst(RegExp(r'^\s+'), '');
            }
            if (trecho.isEmpty) continue;
            destacado = _adicionarMarkup(trecho, spans, destacado: destacado);
          case MathSegment(:final tex, :final display):
            if (tex.trim().isEmpty) continue;
            if (display) {
              _removerEspacosFinais(spans);
              flush();
              blocos.add(
                Padding(
                  padding: EdgeInsets.symmetric(vertical: displaySpacing),
                  child: Math.tex(
                    tex,
                    displayMode: true,
                    textStyle: base,
                    parseOptions: ParseOptions(streaming: streaming),
                  ),
                ),
              );
            } else {
              spans.add(
                MathSpan(
                  tex,
                  style: base,
                  parseOptions: ParseOptions(streaming: streaming),
                ),
              );
            }
        }
      }
    }

    for (final parte in dividirBlocosCodigo(normalizado)) {
      if (parte.codigo) {
        if (parte.texto.trim().isEmpty) continue;
        _removerEspacosFinais(spans);
        flush();
        blocos.add(CodeBlockView(parte.texto, style: base));
        continue;
      }
      if (parte.citacao) {
        if (parte.texto.trim().isEmpty) continue;
        _removerEspacosFinais(spans);
        flush();
        blocos.add(BlockquoteView(parte.texto, style: base));
        continue;
      }
      if (parte.imagem) {
        _removerEspacosFinais(spans);
        flush();
        blocos.add(QuestionImage(source: parte.texto));
        continue;
      }

      var ultimoCodigo = 0;
      for (final match in _trechosCodigoInline.allMatches(parte.texto)) {
        if (match.start > ultimoCodigo) {
          adicionarTexto(parte.texto.substring(ultimoCodigo, match.start));
        }
        spans.add(
          TextSpan(
            text: match.group(1),
            style: const TextStyle(
              fontFamily: 'RobotoMono',
              fontFamilyFallback: ['monospace', 'Courier New', 'Courier'],
            ),
          ),
        );
        ultimoCodigo = match.end;
      }
      if (ultimoCodigo < parte.texto.length) {
        adicionarTexto(parte.texto.substring(ultimoCodigo));
      }
    }
    flush();

    if (blocos.isEmpty) return const SizedBox.shrink();
    if (blocos.length == 1) return blocos.single;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: blocos,
    );
  }

  bool _adicionarMarkup(
    String texto,
    List<InlineSpan> spans, {
    bool destacado = false,
    bool negrito = false,
    bool italico = false,
    bool codigo = false,
    bool sublinhado = false,
    bool riscado = false,
    bool superior = false,
    bool inferior = false,
    bool markdownBold = false,
    String? linkUrl,
  }) {
    var ultimo = 0;
    for (final match in _markup.allMatches(texto)) {
      if (match.start > ultimo) {
        _adicionarTexto(
          texto.substring(ultimo, match.start),
          spans,
          destacado: destacado,
          negrito: negrito,
          italico: italico,
          codigo: codigo,
          sublinhado: sublinhado,
          riscado: riscado,
          superior: superior,
          inferior: inferior,
          markdownBold: markdownBold,
          linkUrl: linkUrl,
        );
      }

      final token = match.group(0)!;
      if (token == _abreNegrito) {
        negrito = true;
      } else if (token == _fechaNegrito) {
        negrito = false;
      } else if (token == _abreItalico) {
        italico = true;
      } else if (token == _fechaItalico) {
        italico = false;
      } else if (token == _abreCodigo) {
        codigo = true;
      } else if (token == _fechaCodigo) {
        codigo = false;
      } else if (token == _abreSublinhado) {
        sublinhado = true;
      } else if (token == _fechaSublinhado) {
        sublinhado = false;
      } else if (token == _abreRiscado) {
        riscado = true;
      } else if (token == _fechaRiscado) {
        riscado = false;
      } else if (token == _abreSuperior) {
        superior = true;
      } else if (token == _fechaSuperior) {
        superior = false;
      } else if (token == _abreInferior) {
        inferior = true;
      } else if (token == _fechaInferior) {
        inferior = false;
      } else if (token == _abreDestaque) {
        destacado = true;
      } else if (token == _fechaDestaque) {
        destacado = false;
      } else if (match.group(1) != null) {
        // Link: o texto de dentro herda toda a formatação atual.
        destacado = _adicionarMarkup(
          match.group(2)!,
          spans,
          destacado: destacado,
          negrito: negrito,
          italico: italico,
          codigo: codigo,
          sublinhado: sublinhado,
          riscado: riscado,
          superior: superior,
          inferior: inferior,
          markdownBold: markdownBold,
          linkUrl: match.group(1)!,
        );
      } else if (match.group(3) != null || match.group(4) != null) {
        destacado = _adicionarMarkup(
          match.group(3) ?? match.group(4)!,
          spans,
          destacado: destacado,
          negrito: true,
          italico: italico,
          codigo: codigo,
          sublinhado: sublinhado,
          riscado: riscado,
          superior: superior,
          inferior: inferior,
          markdownBold: true,
          linkUrl: linkUrl,
        );
      } else if (match.group(5) != null || match.group(6) != null) {
        destacado = _adicionarMarkup(
          match.group(5) ?? match.group(6)!,
          spans,
          destacado: destacado,
          negrito: negrito,
          italico: true,
          codigo: codigo,
          sublinhado: sublinhado,
          riscado: riscado,
          superior: superior,
          inferior: inferior,
          markdownBold: markdownBold,
          linkUrl: linkUrl,
        );
      } else if (match.group(7) != null) {
        destacado = _adicionarMarkup(
          match.group(7)!,
          spans,
          destacado: destacado,
          negrito: negrito,
          italico: italico,
          codigo: codigo,
          sublinhado: sublinhado,
          riscado: true,
          superior: superior,
          inferior: inferior,
          markdownBold: markdownBold,
          linkUrl: linkUrl,
        );
      } else if (match.group(8) != null) {
        _adicionarTexto(
          match.group(8)!,
          spans,
          destacado: destacado,
          negrito: negrito,
          italico: italico,
          codigo: true,
          sublinhado: sublinhado,
          riscado: riscado,
          superior: superior,
          inferior: inferior,
          markdownBold: markdownBold,
          linkUrl: linkUrl,
        );
      }
      ultimo = match.end;
    }

    if (ultimo < texto.length) {
      _adicionarTexto(
        texto.substring(ultimo),
        spans,
        destacado: destacado,
        negrito: negrito,
        italico: italico,
        codigo: codigo,
        sublinhado: sublinhado,
        riscado: riscado,
        superior: superior,
        inferior: inferior,
        markdownBold: markdownBold,
        linkUrl: linkUrl,
      );
    }
    return destacado;
  }

  void _adicionarTexto(
    String texto,
    List<InlineSpan> spans, {
    required bool destacado,
    required bool negrito,
    required bool italico,
    required bool codigo,
    required bool sublinhado,
    required bool riscado,
    required bool superior,
    required bool inferior,
    required bool markdownBold,
    String? linkUrl,
  }) {
    if (texto.isEmpty) return;
    var estilo = destacado ? highlightStyle : null;
    if (negrito || markdownBold) {
      estilo = (estilo ?? const TextStyle()).merge(
        const TextStyle(fontWeight: FontWeight.w700),
      );
    }
    if (italico) {
      estilo = (estilo ?? const TextStyle()).merge(
        const TextStyle(fontStyle: FontStyle.italic),
      );
    }
    if (codigo) {
      estilo = (estilo ?? const TextStyle()).merge(
        const TextStyle(
          fontFamily: 'RobotoMono',
          fontFamilyFallback: ['monospace', 'Courier New', 'Courier'],
        ),
      );
    }
    if (markdownBold && markdownBoldStyle != null) {
      estilo = (estilo ?? const TextStyle()).merge(markdownBoldStyle!);
    }
    if (linkUrl != null) {
      estilo = (estilo ?? const TextStyle()).merge(
        const TextStyle(
          color: Color(0xFF2563EB),
          decoration: TextDecoration.underline,
        ),
      );
    }

    final decoracoes = <TextDecoration>[];
    if (sublinhado) decoracoes.add(TextDecoration.underline);
    if (riscado) decoracoes.add(TextDecoration.lineThrough);
    if (decoracoes.isNotEmpty) {
      estilo = (estilo ?? const TextStyle()).merge(
        TextStyle(decoration: TextDecoration.combine(decoracoes)),
      );
    }

    if (superior || inferior) {
      final tamanho = (estilo?.fontSize ?? 14) * 0.75;
      final deslocamento = superior ? -tamanho * 0.45 : tamanho * 0.15;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Transform.translate(
            offset: Offset(0, deslocamento),
            child: Text(
              texto,
              style: (estilo ?? const TextStyle()).copyWith(fontSize: tamanho),
              textHeightBehavior: const TextHeightBehavior(
                applyHeightToFirstAscent: false,
                applyHeightToLastDescent: false,
              ),
            ),
          ),
        ),
      );
      return;
    }

    spans.add(TextSpan(text: texto, style: estilo));
  }

  void _removerEspacosFinais(List<InlineSpan> spans) {
    while (spans.isNotEmpty) {
      final ultimo = spans.last;
      if (ultimo is! TextSpan || ultimo.text == null) return;
      final texto = ultimo.text!.replaceFirst(RegExp(r'\s+$'), '');
      if (texto.isEmpty) {
        spans.removeLast();
      } else {
        spans[spans.length - 1] = TextSpan(text: texto, style: ultimo.style);
        return;
      }
    }
  }

  static String _protegerMoedas(String texto) =>
      texto.replaceAllMapped(_moeda, (match) => '${match.group(1)}${r'\$'}');

  static String _decodificarEntidades(String texto) {
    return texto
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&ldquo;', '“')
        .replaceAll('&rdquo;', '”')
        .replaceAll('&ndash;', '–')
        .replaceAll('&mdash;', '—')
        .replaceAll('&hellip;', '…')
        .replaceAll('&minus;', '−');
  }
}
