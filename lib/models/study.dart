import '../core/utils/json_utils.dart';
import 'question.dart';

class Caderno {
  const Caderno({
    required this.id,
    required this.idUsuario,
    required this.nome,
    this.criadoEm,
  });

  final String id;
  final int idUsuario;
  final String nome;
  final DateTime? criadoEm;

  factory Caderno.fromMap(Map<String, dynamic> map) => Caderno(
    id: Json.text(map['id_caderno']),
    idUsuario: Json.integer(map['id_usuario']),
    nome: Json.text(map['nome_caderno'], 'Caderno sem nome'),
    criadoEm: Json.dateTime(map['criado_em']),
  );
}

/// Caderno com as questões hidratadas e o status do aluno em cada uma.
class CadernoDetalhe {
  const CadernoDetalhe({
    required this.caderno,
    required this.questoes,
    this.idsAcertos = const {},
    this.idsErros = const {},
  });

  final Caderno caderno;
  final List<Questao> questoes;
  final Set<int> idsAcertos;
  final Set<int> idsErros;

  /// `true` se já acertou, `false` se só errou e `null` se nunca respondeu.
  bool? statusQuestao(int idQuestao) {
    if (idsAcertos.contains(idQuestao)) return true;
    if (idsErros.contains(idQuestao)) return false;
    return null;
  }
}

class FiltroSalvo {
  const FiltroSalvo({
    required this.id,
    required this.idUsuario,
    required this.nome,
    required this.urlParams,
    this.criadoEm,
  });

  final String id;
  final int idUsuario;
  final String nome;
  final String urlParams;
  final DateTime? criadoEm;

  factory FiltroSalvo.fromMap(Map<String, dynamic> map) => FiltroSalvo(
    id: Json.text(map['id']),
    idUsuario: Json.integer(map['id_usuario']),
    nome: Json.text(map['nome_filtro']),
    urlParams: Json.text(map['url_params']),
    criadoEm: Json.dateTime(map['criado_em']),
  );
}

class FlashcardCategoria {
  const FlashcardCategoria({
    required this.id,
    required this.idUsuario,
    required this.nome,
    this.idMateria,
    this.nomeMateria,
    this.criadoEm,
  });

  final String id;
  final String idUsuario;
  final String nome;
  final int? idMateria;
  final String? nomeMateria;
  final DateTime? criadoEm;

  factory FlashcardCategoria.fromMap(Map<String, dynamic> map) {
    final materia = Json.mapOrNull(map['materias']);
    return FlashcardCategoria(
      id: Json.text(map['id_categoria']),
      idUsuario: Json.text(map['id_usuario']),
      nome: Json.text(map['nome_categoria']),
      idMateria: Json.integerOrNull(map['id_materia']),
      nomeMateria: materia == null
          ? null
          : Json.textOrNull(materia['nome_materia']),
      criadoEm: Json.dateTime(map['criado_em']),
    );
  }
}

class Flashcard {
  const Flashcard({
    required this.id,
    required this.idUsuario,
    required this.frente,
    required this.verso,
    this.idCategoria,
    this.idQuestao,
    this.intervalo = 0,
    this.facilidade = 2.5,
    this.estagio = 0,
    this.proximaRevisao,
    this.criadoEm,
  });

  final String id;
  final String idUsuario;
  final String frente;
  final String verso;
  final String? idCategoria;
  final int? idQuestao;
  final int intervalo;
  final double facilidade;
  final int estagio;
  final DateTime? proximaRevisao;
  final DateTime? criadoEm;

  factory Flashcard.fromMap(Map<String, dynamic> map) => Flashcard(
    id: Json.text(map['id_flashcard']),
    idUsuario: Json.text(map['id_usuario']),
    frente: Json.text(map['frente']),
    verso: Json.text(map['verso']),
    idCategoria: Json.textOrNull(map['id_categoria']),
    idQuestao: Json.integerOrNull(map['id_questao']),
    intervalo: Json.integer(map['intervalo']),
    facilidade: Json.decimal(map['facilidade'], 2.5),
    estagio: Json.integer(map['estagio']),
    proximaRevisao: Json.dateTime(map['proxima_revisao']),
    criadoEm: Json.dateTime(map['criado_em']),
  );

  bool get estaDevido {
    final proxima = proximaRevisao;
    return proxima == null || !proxima.isAfter(DateTime.now());
  }
}

/// Dados agregados exibidos no painel do deck.
class FlashcardsDashboardData {
  const FlashcardsDashboardData({
    required this.categorias,
    required this.paraRevisarHoje,
  });

  final List<FlashcardCategoria> categorias;
  final int paraRevisarHoje;
}

/// Categoria validada para o usuário atual e seus cards de gerenciamento.
class FlashcardCategoriaDetalhe {
  const FlashcardCategoriaDetalhe({
    required this.categoria,
    required this.cards,
  });

  final FlashcardCategoria categoria;
  final List<Flashcard> cards;
}

class Resumo {
  const Resumo({
    required this.id,
    required this.idUsuario,
    required this.idMateria,
    required this.conteudo,
    this.idQuestao,
    this.nomeMateria,
    this.criadoEm,
  });

  final String id;
  final String idUsuario;
  final int idMateria;
  final String conteudo;
  final int? idQuestao;
  final String? nomeMateria;
  final DateTime? criadoEm;

  factory Resumo.fromMap(Map<String, dynamic> map) {
    final materia = Json.mapOrNull(map['materias']);
    return Resumo(
      id: Json.text(map['id_resumo']),
      idUsuario: Json.text(map['id_usuario']),
      idMateria: Json.integer(map['id_materia']),
      conteudo: Json.text(map['conteudo']),
      idQuestao: Json.integerOrNull(map['id_questao']),
      nomeMateria: materia == null
          ? Json.textOrNull(map['nome_materia'])
          : Json.textOrNull(materia['nome_materia']),
      criadoEm: Json.dateTime(map['criado_em']),
    );
  }
}

class HistoricoResposta {
  const HistoricoResposta({
    required this.idQuestao,
    required this.isCorrect,
    this.idUsuario,
    this.idAlternativaMarcada,
    this.criadoEm,
  });

  final int idQuestao;
  final bool isCorrect;
  final String? idUsuario;
  final int? idAlternativaMarcada;
  final DateTime? criadoEm;

  factory HistoricoResposta.fromMap(Map<String, dynamic> map) =>
      HistoricoResposta(
        idQuestao: Json.integer(map['id_questao']),
        isCorrect: Json.boolean(map['is_correct']),
        idUsuario: Json.textOrNull(map['id_usuario']),
        idAlternativaMarcada: Json.integerOrNull(map['id_alternativa_marcada']),
        criadoEm: Json.dateTime(map['criado_em']),
      );
}

/// Agrupamento de resumos por matéria (tela inicial de resumos).
class ResumosPorMateria {
  const ResumosPorMateria({
    required this.idMateria,
    required this.nomeMateria,
    required this.total,
  });

  final int idMateria;
  final String nomeMateria;
  final int total;
}

/// Matéria do caderno e resumos ordenados cronologicamente.
class ResumoMateriaDetalhe {
  const ResumoMateriaDetalhe({required this.materia, required this.resumos});

  final ResumosPorMateria materia;
  final List<Resumo> resumos;
}
