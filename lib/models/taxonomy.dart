import '../core/utils/json_utils.dart';

class Materia {
  const Materia({required this.id, required this.nome});

  final int id;
  final String nome;

  factory Materia.fromMap(Map<String, dynamic> map) => Materia(
    id: Json.integer(map['id_materia']),
    nome: Json.text(map['nome_materia']),
  );
}

class Topico {
  const Topico({
    required this.id,
    required this.idMateria,
    required this.nome,
  });

  final int id;
  final int idMateria;
  final String nome;

  factory Topico.fromMap(Map<String, dynamic> map) => Topico(
    id: Json.integer(map['id_topico']),
    idMateria: Json.integer(map['id_materia']),
    nome: Json.text(map['nome_topico']),
  );
}

class Subtopico {
  const Subtopico({
    required this.id,
    required this.idTopico,
    required this.nome,
  });

  final int id;
  final int idTopico;
  final String nome;

  factory Subtopico.fromMap(Map<String, dynamic> map) => Subtopico(
    id: Json.integer(map['id_subtopico']),
    idTopico: Json.integer(map['id_topico']),
    nome: Json.text(map['nome_subtopico']),
  );
}

class Banca {
  const Banca({required this.id, required this.nome});

  final int id;
  final String nome;

  factory Banca.fromMap(Map<String, dynamic> map) => Banca(
    id: Json.integer(map['id_banca']),
    nome: Json.text(map['nome_banca']),
  );
}

class Orgao {
  const Orgao({required this.id, required this.nome, this.cargos = const []});

  final int id;
  final String nome;
  final List<Cargo> cargos;

  factory Orgao.fromMap(Map<String, dynamic> map) => Orgao(
    id: Json.integer(map['id_orgao']),
    nome: Json.text(map['nome_orgao']),
    cargos: Json.mapList(map['cargos']).map(Cargo.fromMap).toList(),
  );

  Orgao copyWith({List<Cargo>? cargos}) =>
      Orgao(id: id, nome: nome, cargos: cargos ?? this.cargos);
}

class Cargo {
  const Cargo({required this.id, required this.nome, this.idOrgao});

  final int id;
  final String nome;
  final int? idOrgao;

  factory Cargo.fromMap(Map<String, dynamic> map) => Cargo(
    id: Json.integer(map['id_cargo']),
    nome: Json.text(map['nome_cargo']),
    idOrgao: Json.integerOrNull(map['id_orgao']),
  );
}

class NivelEscolaridade {
  const NivelEscolaridade({required this.id, required this.nome});

  final int id;
  final String nome;

  factory NivelEscolaridade.fromMap(Map<String, dynamic> map) =>
      NivelEscolaridade(
        id: Json.integer(map['id_nivel']),
        nome: Json.text(map['descritivo_nivel']),
      );
}

/// Taxonomia carregada de uma vez para telas de filtro/formulários.
class TaxonomyCatalog {
  const TaxonomyCatalog({
    this.materias = const [],
    this.topicos = const [],
    this.subtopicos = const [],
    this.bancas = const [],
    this.orgaos = const [],
    this.niveis = const [],
  });

  final List<Materia> materias;
  final List<Topico> topicos;
  final List<Subtopico> subtopicos;
  final List<Banca> bancas;
  final List<Orgao> orgaos;
  final List<NivelEscolaridade> niveis;

  List<Materia> get materiasOrdenadas =>
      [...materias]..sort((a, b) => a.nome.compareTo(b.nome));

  List<Topico> topicosDaMateria(int idMateria) =>
      topicos.where((topico) => topico.idMateria == idMateria).toList();

  List<Subtopico> subtopicosDoTopico(int idTopico) =>
      subtopicos.where((subtopico) => subtopico.idTopico == idTopico).toList();

  List<Cargo> cargosDoOrgao(int idOrgao) =>
      orgaos.where((orgao) => orgao.id == idOrgao).expand((o) => o.cargos).toList();
}
