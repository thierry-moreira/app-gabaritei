import '../core/data/database.dart';
import '../core/utils/json_utils.dart';

class TrechoLegislacao {
  const TrechoLegislacao({
    this.id,
    required this.referencia,
    required this.texto,
    this.vigenciaDe,
    this.vigenciaAte,
  });

  final Object? id;
  final String referencia;
  final String texto;
  final String? vigenciaDe;
  final String? vigenciaAte;
}

/// RAG leve de legislação (fail-open), como `legislacao.py`.
class LegislacaoService {
  LegislacaoService(this._db);

  final GabariteiDatabase _db;

  static const limitePadrao = 5;
  static const maxTextoTrecho = 1500;
  static const maxTextoConsulta = 1500;
  static const minimoConsulta = 15;

  Future<List<TrechoLegislacao>> recuperar({
    required String? enunciado,
    Object? idSubtopico,
    Object? idMateria,
    Object? idTopico,
    int limite = limitePadrao,
  }) async {
    final texto = cortar(limparHtml(enunciado), maxTextoConsulta);
    if (texto.length < minimoConsulta) return const [];

    final params = <String, dynamic>{
      'p_texto': texto,
      'p_limite': limite.clamp(1, limitePadrao),
    };
    if (idSubtopico != null) params['p_id_subtopico'] = idSubtopico;
    if (idMateria != null) params['p_id_materia'] = idMateria;
    if (idTopico != null) params['p_id_topico'] = idTopico;

    try {
      final linhas = await _db.rpc('buscar_legislacao', params: params);
      final trechos = <TrechoLegislacao>[];
      for (final linha in linhas) {
        final textoLinha = linha['texto'];
        if (textoLinha == null || textoLinha.toString().isEmpty) continue;
        trechos.add(
          TrechoLegislacao(
            id: linha['id'],
            referencia: Json.text(linha['referencia'], 'Legislação').trim(),
            texto: cortar(textoLinha.toString().trim(), maxTextoTrecho),
            vigenciaDe: Json.textOrNull(linha['vigencia_de']),
            vigenciaAte: Json.textOrNull(linha['vigencia_ate']),
          ),
        );
      }
      return trechos;
    } catch (_) {
      // Fail-open: RPC ausente, rede ou migration pendente nunca impedem a IA.
      return const [];
    }
  }

  static String montarBlocoContexto(List<TrechoLegislacao> trechos) {
    if (trechos.isEmpty) return '';
    final partes = <String>[];
    for (var i = 0; i < trechos.length; i++) {
      final trecho = trechos[i];
      final cabecalho =
          '[${i + 1}] ${trecho.referencia}${_formatarVigencia(trecho)}';
      partes.add('$cabecalho\n${trecho.texto}');
    }
    return partes.join('\n\n');
  }

  static List<Map<String, dynamic>> montarEvidencia(
    List<TrechoLegislacao> trechos,
  ) => [
    for (final trecho in trechos)
      if (trecho.referencia.isNotEmpty)
        {'id': trecho.id, 'referencia': trecho.referencia},
  ];

  static String _formatarVigencia(TrechoLegislacao trecho) {
    final ate = trecho.vigenciaAte;
    if (ate != null) {
      return ' — VIGÊNCIA ENCERRADA em $ate (redação histórica)';
    }
    final de = trecho.vigenciaDe;
    if (de != null) return ' — vigente desde $de';
    return '';
  }

  static String limparHtml(Object? texto) {
    if (texto == null) return '';
    final semTags = texto.toString().replaceAll(RegExp(r'<[^>]+>'), ' ');
    final semEntidades = _unescapeHtml(semTags);
    return semEntidades.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String cortar(String texto, int limite) {
    if (texto.length <= limite) return texto;
    final prefixo = texto.substring(0, limite);
    final ultimoEspaco = prefixo.lastIndexOf(' ');
    final corte = ultimoEspaco > 0 ? prefixo.substring(0, ultimoEspaco) : prefixo;
    return '${corte.trimRight()} …';
  }

  static String _unescapeHtml(String texto) {
    var resultado = texto
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
    resultado = resultado.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (match) => String.fromCharCode(int.parse(match.group(1)!)),
    );
    return resultado.replaceAllMapped(
      RegExp(r'&#x([0-9a-fA-F]+);'),
      (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)),
    );
  }
}
