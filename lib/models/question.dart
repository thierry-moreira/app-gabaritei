import '../core/utils/json_utils.dart';

class Alternativa {
  const Alternativa({
    required this.id,
    required this.idQuestao,
    required this.letra,
    required this.texto,
    required this.isCorrect,
  });

  final int id;
  final int idQuestao;
  final String letra;
  final String texto;
  final bool isCorrect;

  factory Alternativa.fromMap(Map<String, dynamic> map) => Alternativa(
    id: Json.integer(map['id_alternativa']),
    idQuestao: Json.integer(map['id_questao']),
    letra: Json.text(map['letra']),
    texto: Json.text(map['texto_alternativa'] ?? map['texto']),
    isCorrect: Json.boolean(map['is_correct']),
  );
}

/// Questão como exposta por `view_questoes_completa`.
class Questao {
  const Questao({
    required this.id,
    required this.enunciado,
    this.urlImagem,
    this.status,
    this.textoBase,
    this.tituloReferencia,
    this.comentarioGabarito,
    this.idSubtopico,
    this.respostaCorreta,
    this.tipoQuestao,
    this.idCargo,
    this.nomeCargo,
    this.idOrgao,
    this.nomeOrgao,
    this.idMateria,
    this.nomeMateria,
    this.idTopico,
    this.nomeTopico,
    this.idBanca,
    this.nomeBanca,
    this.idNivel,
    this.descritivoNivel,
    this.ano,
    this.alternativas = const [],
    this.totalComentarios = 0,
    this.taxaAcerto,
    this.sugestaoNovoTopico,
  });

  final int id;
  final String enunciado;
  final String? urlImagem;
  final String? status;
  final String? textoBase;
  final String? tituloReferencia;
  final String? comentarioGabarito;
  final int? idSubtopico;
  final String? respostaCorreta;
  final String? tipoQuestao;
  final int? idCargo;
  final String? nomeCargo;
  final int? idOrgao;
  final String? nomeOrgao;
  final int? idMateria;
  final String? nomeMateria;
  final int? idTopico;
  final String? nomeTopico;
  final int? idBanca;
  final String? nomeBanca;
  final int? idNivel;
  final String? descritivoNivel;
  final int? ano;
  final List<Alternativa> alternativas;
  final int totalComentarios;
  final double? taxaAcerto;
  final String? sugestaoNovoTopico;

  factory Questao.fromMap(Map<String, dynamic> map) => Questao(
    id: Json.integer(map['id_questao']),
    enunciado: Json.text(map['enunciado']),
    urlImagem: Json.textOrNull(map['url_imagem']),
    status: Json.textOrNull(map['status']),
    textoBase: Json.textOrNull(map['texto_base']),
    tituloReferencia: Json.textOrNull(map['titulo_referencia']),
    comentarioGabarito: Json.textOrNull(map['comentario_gabarito']),
    idSubtopico: Json.integerOrNull(map['id_subtopico']),
    respostaCorreta: Json.textOrNull(map['resposta_correta']),
    tipoQuestao: Json.textOrNull(map['tipo_questao']),
    idCargo: Json.integerOrNull(map['id_cargo']),
    nomeCargo: Json.textOrNull(map['nome_cargo']),
    idOrgao: Json.integerOrNull(map['id_orgao']),
    nomeOrgao: Json.textOrNull(map['nome_orgao']),
    idMateria: Json.integerOrNull(map['id_materia']),
    nomeMateria: Json.textOrNull(map['nome_materia']),
    idTopico: Json.integerOrNull(map['id_topico']),
    nomeTopico: Json.textOrNull(map['nome_topico']),
    idBanca: Json.integerOrNull(map['id_banca']),
    nomeBanca: Json.textOrNull(map['nome_banca']),
    idNivel: Json.integerOrNull(map['id_nivel']),
    descritivoNivel: Json.textOrNull(map['descritivo_nivel']),
    ano: Json.integerOrNull(map['ano']),
    alternativas: Json.mapList(map['alternativas_questao'])
        .map(Alternativa.fromMap)
        .toList(growable: false),
    totalComentarios: Json.integer(map['total_comentarios']),
    taxaAcerto: Json.decimalOrNull(map['taxa_acerto']),
    sugestaoNovoTopico: Json.textOrNull(map['sugestao_novo_topico']),
  );

  /// Letra do gabarito: prefere a coluna da view e cai para a alternativa
  /// marcada como correta.
  String? get letraCorreta {
    final daView = respostaCorreta;
    if (daView != null && daView.isNotEmpty) return daView;
    for (final alternativa in alternativas) {
      if (alternativa.isCorrect) return alternativa.letra;
    }
    return null;
  }

  Alternativa? alternativaPorLetra(String letra) {
    for (final alternativa in alternativas) {
      if (alternativa.letra == letra) return alternativa;
    }
    return null;
  }

  Questao copyWith({
    List<Alternativa>? alternativas,
    int? totalComentarios,
    double? taxaAcerto,
  }) => Questao(
    id: id,
    enunciado: enunciado,
    urlImagem: urlImagem,
    status: status,
    textoBase: textoBase,
    tituloReferencia: tituloReferencia,
    comentarioGabarito: comentarioGabarito,
    idSubtopico: idSubtopico,
    respostaCorreta: respostaCorreta,
    tipoQuestao: tipoQuestao,
    idCargo: idCargo,
    nomeCargo: nomeCargo,
    idOrgao: idOrgao,
    nomeOrgao: nomeOrgao,
    idMateria: idMateria,
    nomeMateria: nomeMateria,
    idTopico: idTopico,
    nomeTopico: nomeTopico,
    idBanca: idBanca,
    nomeBanca: nomeBanca,
    idNivel: idNivel,
    descritivoNivel: descritivoNivel,
    ano: ano,
    alternativas: alternativas ?? this.alternativas,
    totalComentarios: totalComentarios ?? this.totalComentarios,
    taxaAcerto: taxaAcerto ?? this.taxaAcerto,
    sugestaoNovoTopico: sugestaoNovoTopico,
  );
}

class ComentarioPublico {
  const ComentarioPublico({
    required this.id,
    required this.idQuestao,
    required this.nomeUsuario,
    required this.texto,
    this.criadoEm,
  });

  final String id;
  final int idQuestao;
  final String nomeUsuario;
  final String texto;
  final DateTime? criadoEm;

  factory ComentarioPublico.fromMap(Map<String, dynamic> map) =>
      ComentarioPublico(
        id: Json.text(map['id_comentario']),
        idQuestao: Json.integer(map['id_questao']),
        nomeUsuario: Json.text(map['nome_usuario'], 'Concurseiro'),
        texto: Json.text(map['texto_comentario']),
        criadoEm: Json.dateTime(map['criado_em']),
      );
}

class ComentariosPagina {
  const ComentariosPagina({
    required this.comentarios,
    required this.pagina,
    required this.temMais,
  });

  final List<ComentarioPublico> comentarios;
  final int pagina;
  final bool temMais;
}

/// Resultado da correção de uma resposta avulsa (tela de questões/edital).
class RespostaQuestaoResultado {
  const RespostaQuestaoResultado({
    required this.correta,
    required this.letraCorreta,
    required this.comentario,
    this.cicloAvancou = false,
    this.mensagemAvanco = '',
  });

  final bool correta;
  final String? letraCorreta;
  final String comentario;
  final bool cicloAvancou;
  final String mensagemAvanco;
}

class PaginaQuestoes {
  const PaginaQuestoes({
    required this.questoes,
    required this.total,
    required this.pagina,
    required this.itensPorPagina,
    this.statusRespostas = const {},
  });

  final List<Questao> questoes;
  final int total;
  final int pagina;
  final int itensPorPagina;

  /// Status do aluno em cada questão da página: `true` acertou, `false` só
  /// errou e `null` (ou ausente) ainda não respondeu.
  final Map<int, bool?> statusRespostas;

  bool? statusDaQuestao(int idQuestao) => statusRespostas[idQuestao];

  bool get temProxima => total > pagina * itensPorPagina;
  bool get temAnterior => pagina > 1;
  int get totalPaginas =>
      total == 0 ? 0 : ((total + itensPorPagina - 1) ~/ itensPorPagina);
}
