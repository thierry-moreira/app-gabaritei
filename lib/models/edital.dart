import '../core/utils/json_utils.dart';
import 'question.dart';
import 'stats.dart';

class EditalCiclo {
  const EditalCiclo({
    required this.id,
    required this.titulo,
    this.idUsuario,
    this.criadoEm,
  });

  final int id;
  final String titulo;
  final int? idUsuario;
  final DateTime? criadoEm;

  factory EditalCiclo.fromMap(Map<String, dynamic> map) => EditalCiclo(
    id: Json.integer(map['id_edital']),
    titulo: Json.text(map['titulo'], 'Edital'),
    idUsuario: Json.integerOrNull(map['id_usuario']),
    criadoEm: Json.dateTime(map['criado_em']),
  );
}

class EditalTopico {
  const EditalTopico({
    required this.id,
    required this.idEditalMateria,
    required this.idTopico,
    this.nomeTopico,
    this.concluido = false,
    this.questoesResolvidas = 0,
    this.questoesAcertadas = 0,
    this.ultimoEstudadoEm,
    this.vezesEstudado = 0,
  });

  final int id;
  final int idEditalMateria;
  final int idTopico;
  final String? nomeTopico;
  final bool concluido;
  final int questoesResolvidas;
  final int questoesAcertadas;
  final DateTime? ultimoEstudadoEm;
  final int vezesEstudado;

  double get taxaAcerto =>
      questoesResolvidas == 0 ? 0 : questoesAcertadas / questoesResolvidas;

  factory EditalTopico.fromMap(Map<String, dynamic> map) {
    final topico = Json.mapOrNull(map['topicos']);
    return EditalTopico(
      id: Json.integer(map['id_edital_topico']),
      idEditalMateria: Json.integer(map['id_edital_materia']),
      idTopico: Json.integer(map['id_topico']),
      nomeTopico: topico == null
          ? Json.textOrNull(map['nome_topico'])
          : Json.textOrNull(topico['nome_topico']),
      concluido: Json.boolean(map['concluido']),
      questoesResolvidas: Json.integer(map['questoes_resolvidas']),
      questoesAcertadas: Json.integer(map['questoes_acertadas']),
      ultimoEstudadoEm: Json.dateTime(map['ultimo_estudado_em']),
      vezesEstudado: Json.integer(map['vezes_estudado']),
    );
  }
}

class EditalMateria {
  const EditalMateria({
    required this.id,
    required this.idEdital,
    required this.idMateria,
    required this.ordem,
    this.nomeMateria,
    this.questoesResolvidas = 0,
    this.questoesAcertadas = 0,
    this.topicos = const [],
  });

  final int id;
  final int idEdital;
  final int idMateria;
  final int ordem;
  final String? nomeMateria;
  final int questoesResolvidas;
  final int questoesAcertadas;
  final List<EditalTopico> topicos;

  double get taxaAcerto =>
      questoesResolvidas == 0 ? 0 : questoesAcertadas / questoesResolvidas;

  factory EditalMateria.fromMap(Map<String, dynamic> map) {
    final materia = Json.mapOrNull(map['materias']);
    return EditalMateria(
      id: Json.integer(map['id_edital_materia']),
      idEdital: Json.integer(map['id_edital']),
      idMateria: Json.integer(map['id_materia']),
      ordem: Json.integer(map['ordem']),
      nomeMateria: materia == null
          ? Json.textOrNull(map['nome_materia'])
          : Json.textOrNull(materia['nome_materia']),
      questoesResolvidas: Json.integer(map['questoes_resolvidas']),
      questoesAcertadas: Json.integer(map['questoes_acertadas']),
      topicos: Json.mapList(map['editais_topicos'])
          .map(EditalTopico.fromMap)
          .toList(growable: false),
    );
  }
}

class EditalProgresso {
  const EditalProgresso({
    required this.idEdital,
    this.materiaAtualId,
    this.topicoAtualId,
    this.metaDinamica = 10,
    this.questoesResolvidasNesteTopico = 0,
    this.historicoTopicos = const [],
  });

  final int idEdital;
  final int? materiaAtualId;
  final int? topicoAtualId;
  final int metaDinamica;
  final int questoesResolvidasNesteTopico;
  final List<int> historicoTopicos;

  bool get concluido => topicoAtualId == null;

  factory EditalProgresso.fromMap(Map<String, dynamic> map) =>
      EditalProgresso(
        idEdital: Json.integer(map['id_edital']),
        materiaAtualId: Json.integerOrNull(map['materia_atual_id']),
        topicoAtualId: Json.integerOrNull(map['topico_atual_id']),
        metaDinamica: Json.integer(map['meta_dinamica'], 10),
        questoesResolvidasNesteTopico: Json.integer(
          map['questoes_resolvidas_neste_topico'],
        ),
        historicoTopicos: Json.intList(map['historico_topicos']),
      );
}

/// Estado atual do ciclo usado pela tela "estudar".
class EditalSessaoEstudo {
  const EditalSessaoEstudo({
    required this.idEdital,
    required this.nomeMateria,
    required this.nomeTopico,
    required this.meta,
    required this.feitas,
    this.idEditalMateria,
    this.idEditalTopico,
    this.idMateria,
    this.idTopico,
    this.questao,
    this.concluido = false,
  });

  final int idEdital;
  final String nomeMateria;
  final String nomeTopico;
  final int meta;
  final int feitas;
  final int? idEditalMateria;
  final int? idEditalTopico;
  final int? idMateria;
  final int? idTopico;
  final Questao? questao;
  final bool concluido;

  int get restantes => (meta - feitas).clamp(0, meta);
}

/// Matéria + tópicos escolhidos na criação do ciclo.
class EditalMateriaSelecionada {
  const EditalMateriaSelecionada({
    required this.idMateria,
    required this.idsTopicos,
  });

  final int idMateria;
  final List<int> idsTopicos;
}

/// Resultado de avançar/pular um tópico do ciclo.
class EditalAvanco {
  const EditalAvanco({
    required this.sucesso,
    required this.mensagem,
    this.metaDinamica,
  });

  final bool sucesso;
  final String mensagem;
  final int? metaDinamica;
}

/// Edital + matérias detalhadas + estatísticas agregadas do ciclo.
class EditalPainel {
  const EditalPainel({
    required this.edital,
    required this.materias,
    required this.dashboard,
  });

  final EditalCiclo edital;
  final List<EditalMateria> materias;
  final EditalDashboard dashboard;
}
