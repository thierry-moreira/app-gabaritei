import '../core/data/database.dart';
import '../core/data/global_write_gateway.dart';
import '../core/data/repository_helpers.dart';
import '../core/errors/app_exception.dart';
import '../core/moderation/moderation_service.dart';
import '../core/validation/validators.dart';
import '../models/question.dart';
import '../services/filter_service.dart';

/// Questões: listagem com filtros, detalhe, resposta, comentários e feedbacks.
///
/// Reproduz `rotas/questao.py` (rotas `/aluno/questoes`, `/aluno/responder`,
/// `/api/responder`, `/api/comentarios`, `/api/feedback`).
class QuestionRepository {
  QuestionRepository({
    required this._db,
    GlobalWriteGateway? globalWrites,
    ModerationService? moderacao,
  }) : _globalWrites = globalWrites,
       _moderacao = moderacao ?? const ModerationService();

  final GabariteiDatabase _db;
  final GlobalWriteGateway? _globalWrites;
  final ModerationService _moderacao;

  static const _tiposFeedbackQuestao = {
    'Gabarito Errado',
    'Questão Desatualizada',
    'Erro de Digitação/Formatação',
    'Falta de Alternativa Correta',
    'Outro',
  };

  static const itensPorPagina = 10;
  static const comentariosPorPagina = 20;
  static const offsetMaxComentarios = 10000;

  /// Página de questões publicadas com os mesmos filtros e ordenação aleatória
  /// estável (`ordem_aleatoria`) do backend.
  Future<PaginaQuestoes> listar(
    QuestaoFiltros filtros, {
    required int idUsuario,
  }) {
    return mapDatabaseErrors(() async {
      final historico = await _db
          .from('historico_respostas')
          .select('id_questao, is_correct')
          .eq('id_usuario', idUsuario.toString())
          .limit(50000)
          .get();

      final idsRespondidos = <int>[];
      final idsAcertos = <int>[];
      final idsErros = <int>[];
      for (final item in historico.rows) {
        final id = _intOrNull(item['id_questao']);
        if (id == null) continue;
        idsRespondidos.add(id);
        if (item['is_correct'] == true) {
          idsAcertos.add(id);
        } else {
          idsErros.add(id);
        }
      }

      final pagina = filtros.pagina < 1 ? 1 : filtros.pagina;
      final inicio = (pagina - 1) * itensPorPagina;
      final fim = inicio + itensPorPagina - 1;

      var consulta = _db
          .from('view_questoes_completa')
          .select('*', countExact: true)
          .eq('status', 'publicada');

      switch (filtros.status) {
        case StatusQuestao.naoRespondidas:
          if (idsRespondidos.isNotEmpty) {
            consulta = consulta.notInList('id_questao', idsRespondidos);
          }
        case StatusQuestao.respondidas:
          consulta = idsRespondidos.isEmpty
              ? consulta.eq('id_questao', 0)
              : consulta.inList('id_questao', idsRespondidos);
        case StatusQuestao.acertos:
          consulta = idsAcertos.isEmpty
              ? consulta.eq('id_questao', 0)
              : consulta.inList('id_questao', idsAcertos);
        case StatusQuestao.erros:
          consulta = idsErros.isEmpty
              ? consulta.eq('id_questao', 0)
              : consulta.inList('id_questao', idsErros);
        case StatusQuestao.todas:
          break;
      }

      if (filtros.idQuestao != null) {
        consulta = consulta.eq('id_questao', filtros.idQuestao!);
      }
      if (filtros.idsMaterias.isNotEmpty) {
        consulta = consulta.inList('id_materia', filtros.idsMaterias);
      }
      if (filtros.idsTopicos.isNotEmpty) {
        consulta = consulta.inList('id_topico', filtros.idsTopicos);
      }
      if (filtros.idsSubtopicos.isNotEmpty) {
        consulta = consulta.inList('id_subtopico', filtros.idsSubtopicos);
      }
      if (filtros.idsBancas.isNotEmpty) {
        consulta = consulta.inList('id_banca', filtros.idsBancas);
      }
      if (filtros.idsOrgaos.isNotEmpty) {
        consulta = consulta.inList('id_orgao', filtros.idsOrgaos);
      }
      if (filtros.idsCargos.isNotEmpty) {
        consulta = consulta.inList('id_cargo', filtros.idsCargos);
      }
      if (filtros.anos.isNotEmpty) {
        consulta = consulta.inList('ano', filtros.anos);
      }
      if (filtros.idNivel != null) {
        consulta = consulta.eq('id_nivel', filtros.idNivel!);
      }
      if (filtros.tiposQuestao.isNotEmpty) {
        consulta = consulta.inList('tipo_questao', filtros.tiposQuestao);
      }

      final resultado = await consulta
          .order('ordem_aleatoria')
          .range(inicio, fim)
          .get();

      final questoes = await hidratarLinhas(resultado.rows);
      return PaginaQuestoes(
        questoes: questoes,
        total: resultado.count ?? questoes.length,
        pagina: pagina,
        itensPorPagina: itensPorPagina,
        statusRespostas: {
          for (final questao in questoes)
            questao.id: idsAcertos.contains(questao.id)
                ? true
                : idsErros.contains(questao.id)
                ? false
                : null,
        },
      );
    });
  }

  /// Quantidade total de questões publicadas (banner do banco de questões).
  Future<int> contarPublicadas() {
    return mapDatabaseErrors(() async {
      final resultado = await _db
          .from('view_questoes_completa')
          .select('id_questao', countExact: true)
          .eq('status', 'publicada')
          .limit(1)
          .get();
      return resultado.count ?? resultado.rows.length;
    });
  }

  /// Carrega questões completas (com alternativas) por id, preservando a
  /// ordem recebida — útil para cadernos, simulados e editais.
  Future<List<Questao>> carregarPorIds(List<int> ids) {
    if (ids.isEmpty) return Future.value(const []);
    return mapDatabaseErrors(() async {
      final resultado = await _db
          .from('view_questoes_completa')
          .select('*')
          .inList('id_questao', ids)
          .get();
      final porId = {for (final q in await hidratarLinhas(resultado.rows)) q.id: q};
      return [
        for (final id in ids)
          if (porId[id] != null) porId[id]!,
      ];
    });
  }

  Future<Questao> detalhe(int idQuestao) {
    return mapDatabaseErrors(() async {
      final linha = await _db
          .from('view_questoes_completa')
          .select('*')
          .eq('id_questao', idQuestao)
          .limit(1)
          .maybeSingle();
      if (linha == null) {
        throw NotFoundException('Questão não encontrada.');
      }

      final alternativas = await carregarAlternativas(_db, [idQuestao]);
      final comentarios = await _db
          .from('view_comentarios_publicos')
          .select('id_comentario', countExact: true)
          .eq('id_questao', idQuestao)
          .get();
      final taxa = await _taxaAcerto(idQuestao);

      return Questao.fromMap(linha).copyWith(
        alternativas: alternativas,
        totalComentarios: comentarios.count ?? 0,
        taxaAcerto: taxa,
      );
    });
  }

  /// `true` se o aluno já acertou a questão, `false` se só errou e `null` se
  /// nunca respondeu (equivale a `ids_acertos`/`ids_erros` no template Flask).
  Future<bool?> statusResposta({
    required int idUsuario,
    required int idQuestao,
  }) {
    return mapDatabaseErrors(() async {
      final resultado = await _db
          .from('historico_respostas')
          .select('is_correct')
          .eq('id_usuario', idUsuario.toString())
          .eq('id_questao', idQuestao)
          .get();
      if (resultado.rows.isEmpty) return null;
      return resultado.rows.any((linha) => linha['is_correct'] == true);
    });
  }

  /// Resposta avulsa da tela de questões (`/aluno/responder`).
  Future<RespostaQuestaoResultado> responder({
    required int idUsuario,
    required int idQuestao,
    required String letra,
  }) {
    return mapDatabaseErrors(() async {
      final alternativas = await _db
          .from('alternativas_questao')
          .select('id_alternativa, letra, is_correct')
          .eq('id_questao', idQuestao)
          .order('letra')
          .get();

      String? letraCorreta;
      int? idMarcada;
      for (final linha in alternativas.rows) {
        final letraLinha = linha['letra']?.toString();
        if (linha['is_correct'] == true) letraCorreta = letraLinha;
        if (letraLinha == letra) idMarcada = _intOrNull(linha['id_alternativa']);
      }
      if (idMarcada == null) {
        throw ValidationException('Alternativa inválida ou não selecionada.');
      }

      final correta = letra == letraCorreta;
      final questao = await _db
          .from('questoes')
          .select('comentario_gabarito')
          .eq('id_questao', idQuestao)
          .limit(1)
          .maybeSingle();
      final comentario =
          questao?['comentario_gabarito']?.toString() ??
          'Sem comentário disponível.';

      await _db.from('historico_respostas').insertMinimal({
        'id_usuario': idUsuario.toString(),
        'id_questao': idQuestao,
        'is_correct': correta,
        'id_alternativa_marcada': idMarcada,
      });

      return RespostaQuestaoResultado(
        correta: correta,
        letraCorreta: letraCorreta,
        comentario: comentario,
      );
    });
  }

  /// Registro de resposta idempotente usado pela UI nova (`/api/responder`):
  /// a correção vem exclusivamente do banco, nunca do cliente.
  Future<void> salvarResposta({
    required int idUsuario,
    required int idQuestao,
    required int idAlternativa,
  }) {
    return mapDatabaseErrors(() async {
      final alternativa = await _db
          .from('alternativas_questao')
          .select('id_alternativa, is_correct')
          .eq('id_questao', idQuestao)
          .eq('id_alternativa', idAlternativa)
          .limit(1)
          .maybeSingle();
      if (alternativa == null) {
        throw ValidationException('Alternativa inválida para essa questão.');
      }
      final isCorrect = alternativa['is_correct'];
      if (isCorrect is! bool) {
        throw AppException(
          'Não foi possível validar a resposta.',
          code: '500',
        );
      }

      await _db.from('historico_respostas').insertMinimal({
        'id_usuario': idUsuario.toString(),
        'id_questao': idQuestao,
        'id_alternativa_marcada': idAlternativa,
        'is_correct': isCorrect,
      });
    });
  }

  Future<ComentariosPagina> comentarios({
    required int idQuestao,
    int pagina = 1,
  }) {
    final offset = (pagina - 1) * comentariosPorPagina;
    if (pagina < 1 || offset > offsetMaxComentarios) {
      throw ValidationException('Página inválida.');
    }

    return mapDatabaseErrors(() async {
      final resultado = await _db
          .from('view_comentarios_publicos')
          .select('id_comentario, nome_usuario, texto_comentario, criado_em')
          .eq('id_questao', idQuestao)
          .order('criado_em', ascending: false)
          .order('id_comentario', ascending: false)
          .range(offset, offset + comentariosPorPagina)
          .get();

      final linhas = resultado.rows.take(comentariosPorPagina);
      return ComentariosPagina(
        comentarios: linhas.map(ComentarioPublico.fromMap).toList(
          growable: false,
        ),
        pagina: pagina,
        temMais: resultado.rows.length > comentariosPorPagina,
      );
    });
  }

  Future<void> salvarComentario({
    required int idUsuario,
    required int idQuestao,
    required String texto,
  }) {
    final validado = Validators.comment(texto);
    if (!validado.isValid) {
      throw ValidationException(validado.error!);
    }
    final moderacao = _moderacao.check(validado.value);
    if (!moderacao.allowed) {
      throw ValidationException(moderacao.message);
    }

    return mapDatabaseErrors(() async {
      final usuario = await _db
          .from('usuarios')
          .select('username')
          .eq('id', idUsuario)
          .limit(1)
          .maybeSingle();
      final bruto = usuario?['username']?.toString() ?? 'Concurseiro';
      final nome = Validators.username(bruto).value ?? 'Concurseiro';

      await _db.from('comentarios_questao').insertMinimal({
        'id_questao': idQuestao,
        'id_usuario': idUsuario.toString(),
        'nome_usuario': nome,
        'texto_comentario': validado.value,
      });
    });
  }

  Future<void> reportarComentario({
    required int idUsuario,
    required String idComentario,
    required String motivo,
  }) {
    if (!_uuidPattern.hasMatch(idComentario)) {
      throw ValidationException('Comentário inválido.');
    }
    final motivoLimpo = motivo.trim();
    if (motivoLimpo.isEmpty) {
      throw ValidationException('Selecione um motivo para a denúncia.');
    }

    return mapDatabaseErrors(() async {
      final comentario = await _db
          .from('view_comentarios_publicos')
          .select('id_comentario')
          .eq('id_comentario', idComentario)
          .limit(1)
          .maybeSingle();
      if (comentario == null) {
        throw NotFoundException('Comentário não encontrado.');
      }

      try {
        await _db.from('reports_comentarios').insertMinimal({
          'id_comentario': idComentario,
          'id_usuario': idUsuario.toString(),
          'motivo': motivoLimpo,
        });
      } on AppException catch (error) {
        if (error.code == '23505') {
          throw ConflictException('Você já denunciou este comentário.');
        }
        rethrow;
      }
    });
  }

  Future<void> enviarFeedback({
    required int idQuestao,
    required String tipoErro,
    String descricao = '',
  }) {
    if (idQuestao <= 0) throw ValidationException('Questão inválida.');
    if (!_tiposFeedbackQuestao.contains(tipoErro)) {
      throw ValidationException('Tipo de erro inválido.');
    }
    final globalWrites = _globalWrites;
    if (globalWrites == null) {
      throw StateError('O envio de feedback requer uma sessão autenticada.');
    }

    return mapDatabaseErrors(
      () => globalWrites.submit({
        'operation': 'feedback_question',
        'id_questao': idQuestao,
        'tipo_erro': tipoErro,
        'descricao': descricao.trim(),
      }),
    );
  }

  Future<List<Questao>> hidratarLinhas(
    List<Map<String, dynamic>> linhas,
  ) async {
    if (linhas.isEmpty) return const [];
    final ids = [
      for (final linha in linhas)
        if (_intOrNull(linha['id_questao']) != null)
          _intOrNull(linha['id_questao'])!,
    ];
    if (ids.isEmpty) return const [];

    final alternativas = await carregarAlternativas(_db, ids);
    final porQuestao = <int, List<Alternativa>>{};
    for (final alternativa in alternativas) {
      porQuestao.putIfAbsent(alternativa.idQuestao, () => []).add(alternativa);
    }

    final comentariosPorQuestao = <int, int>{};
    final comentarios = await _db
        .from('view_comentarios_publicos')
        .select('id_questao')
        .inList('id_questao', ids)
        .get();
    for (final linha in comentarios.rows) {
      final id = _intOrNull(linha['id_questao']);
      if (id == null) continue;
      comentariosPorQuestao[id] = (comentariosPorQuestao[id] ?? 0) + 1;
    }

    final taxas = <int, double?>{};
    final taxasResultado = await _db
        .from('view_taxa_acerto_questoes')
        .select('id_questao, taxa_acerto')
        .inList('id_questao', ids)
        .get();
    for (final linha in taxasResultado.rows) {
      final id = _intOrNull(linha['id_questao']);
      if (id == null) continue;
      taxas[id] = _doubleOrNull(linha['taxa_acerto']);
    }

    return [
      for (final linha in linhas)
        if (_intOrNull(linha['id_questao']) != null)
          Questao.fromMap(linha).copyWith(
            alternativas: porQuestao[_intOrNull(linha['id_questao'])] ?? const [],
            totalComentarios:
                comentariosPorQuestao[_intOrNull(linha['id_questao'])] ?? 0,
            taxaAcerto: taxas[_intOrNull(linha['id_questao'])],
          ),
    ];
  }

  Future<double?> _taxaAcerto(int idQuestao) async {
    final resultado = await _db
        .from('view_taxa_acerto_questoes')
        .select('taxa_acerto')
        .eq('id_questao', idQuestao)
        .limit(1)
        .maybeSingle();
    return _doubleOrNull(resultado?['taxa_acerto']);
  }

  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-'
    r'[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
}

/// Busca todas as alternativas das questões informadas, ordenadas por letra.
Future<List<Alternativa>> carregarAlternativas(
  GabariteiDatabase db,
  List<int> idsQuestoes,
) async {
  if (idsQuestoes.isEmpty) return const [];
  final resultado = await db
      .from('alternativas_questao')
      .select('*')
      .inList('id_questao', idsQuestoes)
      .order('letra')
      .get();
  return resultado.rows.map(Alternativa.fromMap).toList(growable: false);
}

int? _intOrNull(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? _doubleOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
