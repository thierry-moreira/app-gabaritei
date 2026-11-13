import '../core/utils/json_utils.dart';
import 'question.dart';

class Simulado {
  const Simulado({
    required this.id,
    required this.titulo,
    this.descricao,
    this.ehPrivado = false,
    this.idCriador,
    this.nomeCriador,
    this.ehMeu = false,
    this.criadoEm,
  });

  final String id;
  final String titulo;
  final String? descricao;
  final bool ehPrivado;
  final int? idCriador;
  final String? nomeCriador;
  final bool ehMeu;
  final DateTime? criadoEm;

  factory Simulado.fromMap(Map<String, dynamic> map) => Simulado(
    id: Json.text(map['id']),
    titulo: Json.text(map['titulo'], 'Simulado'),
    descricao: Json.textOrNull(map['descricao']),
    ehPrivado: Json.boolean(map['eh_privado']),
    idCriador: Json.integerOrNull(map['id_criador']),
    nomeCriador: Json.textOrNull(map['nome_criador']),
    ehMeu: Json.boolean(map['eh_meu']),
    criadoEm: Json.dateTime(map['criado_em']),
  );

  Simulado copyWith({
    bool? ehPrivado,
    int? idCriador,
    bool? ehMeu,
    String? nomeCriador,
  }) => Simulado(
    id: id,
    titulo: titulo,
    descricao: descricao,
    ehPrivado: ehPrivado ?? this.ehPrivado,
    idCriador: idCriador ?? this.idCriador,
    nomeCriador: nomeCriador ?? this.nomeCriador,
    ehMeu: ehMeu ?? this.ehMeu,
    criadoEm: criadoEm,
  );
}

/// Simulado com as questões já hidratadas (fazer, revisar ou exportar PDF).
class SimuladoComQuestoes {
  const SimuladoComQuestoes({required this.simulado, required this.questoes});

  final Simulado simulado;
  final List<Questao> questoes;
}

/// Feed de simulados dividido como no painel Flask.
class SimuladoListagem {
  const SimuladoListagem({this.publicos = const [], this.privados = const []});

  final List<Simulado> publicos;
  final List<Simulado> privados;
}

class RankingEntry {
  const RankingEntry({
    required this.nomeUsuario,
    required this.nota,
    required this.respostasCorretas,
    required this.totalQuestoes,
    this.dataConclusao,
  });

  final String nomeUsuario;
  final double nota;
  final int respostasCorretas;
  final int totalQuestoes;
  final DateTime? dataConclusao;

  factory RankingEntry.fromMap(Map<String, dynamic> map) => RankingEntry(
    nomeUsuario: Json.text(map['nome_usuario'], 'Concurseiro'),
    nota: Json.decimal(map['nota']),
    respostasCorretas: Json.integer(map['respostas_corretas']),
    totalQuestoes: Json.integer(map['total_questoes']),
    dataConclusao: Json.dateTime(map['data_conclusao']),
  );
}

class SimuladoRankingDados {
  const SimuladoRankingDados({required this.simulado, required this.ranking});

  final Simulado simulado;
  final List<RankingEntry> ranking;
}

class DetalheResposta {
  const DetalheResposta({
    required this.idQuestao,
    required this.respostaAluno,
    required this.respostaCorreta,
    required this.correto,
  });

  final int idQuestao;
  final String? respostaAluno;
  final String? respostaCorreta;
  final bool correto;
}

class SimuladoResultado {
  const SimuladoResultado({
    required this.nota,
    required this.acertos,
    required this.total,
    required this.detalhes,
    required this.ranking,
  });

  final double nota;
  final int acertos;
  final int total;
  final List<DetalheResposta> detalhes;
  final List<RankingEntry> ranking;

  double get percentual => total == 0 ? 0 : (acertos / total) * 100;
}

/// Dados transitórios levados da sessão para a tela de resultado.
class SimuladoResultadoArgs {
  const SimuladoResultadoArgs({
    required this.simulado,
    required this.resultado,
  });

  final Simulado simulado;
  final SimuladoResultado resultado;
}

/// Definição de uma cota de questões por matéria/tópico no gerador.
class CotaSimulado {
  const CotaSimulado({
    this.idMateria,
    this.idsTopicos = const [],
    required this.quantidade,
  });

  final int? idMateria;
  final List<int> idsTopicos;
  final int quantidade;
}

/// Filtros globais do gerador de simulado.
class FiltrosSimulado {
  const FiltrosSimulado({
    this.idNivel,
    this.idsBancas = const [],
    this.idsOrgaos = const [],
    this.idsCargos = const [],
    this.anos = const [],
    this.tiposQuestao = const [],
  });

  final int? idNivel;
  final List<int> idsBancas;
  final List<int> idsOrgaos;
  final List<int> idsCargos;
  final List<int> anos;
  final List<String> tiposQuestao;
}
