enum StatusQuestao {
  todas('todas'),
  naoRespondidas('nao_respondidas'),
  respondidas('respondidas'),
  acertos('acertos'),
  erros('erros');

  const StatusQuestao(this.wire);

  final String wire;

  static StatusQuestao fromWire(String? value) {
    for (final status in values) {
      if (status.wire == value) return status;
    }
    return StatusQuestao.todas;
  }
}

/// Filtros da tela de questões, com a mesma serialização de query string do
/// backend Flask (chaves repetidas para listas).
class QuestaoFiltros {
  const QuestaoFiltros({
    this.idQuestao,
    this.status = StatusQuestao.todas,
    this.idsMaterias = const [],
    this.idsTopicos = const [],
    this.idsSubtopicos = const [],
    this.idsBancas = const [],
    this.idsOrgaos = const [],
    this.idsCargos = const [],
    this.anos = const [],
    this.idNivel,
    this.tiposQuestao = const [],
    this.pagina = 1,
  });

  final int? idQuestao;
  final StatusQuestao status;
  final List<int> idsMaterias;
  final List<int> idsTopicos;
  final List<int> idsSubtopicos;
  final List<int> idsBancas;
  final List<int> idsOrgaos;
  final List<int> idsCargos;
  final List<int> anos;
  final int? idNivel;
  final List<String> tiposQuestao;
  final int pagina;

  bool get temFiltros =>
      idQuestao != null ||
      status != StatusQuestao.todas ||
      idsMaterias.isNotEmpty ||
      idsTopicos.isNotEmpty ||
      idsSubtopicos.isNotEmpty ||
      idsBancas.isNotEmpty ||
      idsOrgaos.isNotEmpty ||
      idsCargos.isNotEmpty ||
      anos.isNotEmpty ||
      idNivel != null ||
      tiposQuestao.isNotEmpty;

  QuestaoFiltros copyWith({
    int? idQuestao,
    bool limparIdQuestao = false,
    StatusQuestao? status,
    List<int>? idsMaterias,
    List<int>? idsTopicos,
    List<int>? idsSubtopicos,
    List<int>? idsBancas,
    List<int>? idsOrgaos,
    List<int>? idsCargos,
    List<int>? anos,
    int? idNivel,
    bool limparIdNivel = false,
    List<String>? tiposQuestao,
    int? pagina,
  }) => QuestaoFiltros(
    idQuestao: limparIdQuestao ? null : (idQuestao ?? this.idQuestao),
    status: status ?? this.status,
    idsMaterias: idsMaterias ?? this.idsMaterias,
    idsTopicos: idsTopicos ?? this.idsTopicos,
    idsSubtopicos: idsSubtopicos ?? this.idsSubtopicos,
    idsBancas: idsBancas ?? this.idsBancas,
    idsOrgaos: idsOrgaos ?? this.idsOrgaos,
    idsCargos: idsCargos ?? this.idsCargos,
    anos: anos ?? this.anos,
    idNivel: limparIdNivel ? null : (idNivel ?? this.idNivel),
    tiposQuestao: tiposQuestao ?? this.tiposQuestao,
    pagina: pagina ?? this.pagina,
  );

  Map<String, List<String>> toQueryParameters() {
    final params = <String, List<String>>{};
    void add(String key, Object value) {
      params.putIfAbsent(key, () => []).add(value.toString());
    }

    void addList(String key, List<int> values) {
      for (final value in values) {
        add(key, value);
      }
    }

    if (idQuestao != null) add('id_questao', idQuestao!);
    if (status != StatusQuestao.todas) add('status', status.wire);
    addList('id_materia', idsMaterias);
    addList('id_topico', idsTopicos);
    addList('id_subtopico', idsSubtopicos);
    addList('id_banca', idsBancas);
    addList('id_orgao', idsOrgaos);
    addList('id_cargo', idsCargos);
    addList('ano', anos);
    if (idNivel != null) add('id_nivel', idNivel!);
    for (final tipo in tiposQuestao) {
      add('tipo_questao', tipo);
    }
    if (pagina > 1) add('page', pagina);
    return params;
  }

  String toQueryString() {
    final partes = <String>[];
    for (final entry in toQueryParameters().entries) {
      for (final value in entry.value) {
        partes.add(
          '${Uri.encodeQueryComponent(entry.key)}='
          '${Uri.encodeQueryComponent(value)}',
        );
      }
    }
    return partes.join('&');
  }

  factory QuestaoFiltros.fromQueryParameters(
    Map<String, List<String>> params,
  ) {
    List<int> ints(String key) => [
      for (final value in params[key] ?? const <String>[])
        if (int.tryParse(value) != null) int.parse(value),
    ];
    String? first(String key) {
      final values = params[key];
      return values == null || values.isEmpty ? null : values.first;
    }

    return QuestaoFiltros(
      idQuestao: int.tryParse(first('id_questao') ?? ''),
      status: StatusQuestao.fromWire(first('status')),
      idsMaterias: ints('id_materia'),
      idsTopicos: ints('id_topico'),
      idsSubtopicos: ints('id_subtopico'),
      idsBancas: ints('id_banca'),
      idsOrgaos: ints('id_orgao'),
      idsCargos: ints('id_cargo'),
      anos: ints('ano'),
      idNivel: int.tryParse(first('id_nivel') ?? ''),
      tiposQuestao: params['tipo_questao'] ?? const [],
      pagina: int.tryParse(first('page') ?? '') ?? 1,
    );
  }

  factory QuestaoFiltros.fromUri(Uri uri) =>
      QuestaoFiltros.fromQueryParameters(uri.queryParametersAll);

  factory QuestaoFiltros.fromQueryString(String query) => QuestaoFiltros.fromUri(
    Uri.parse(query.startsWith('?') ? query : '?$query'),
  );
}
