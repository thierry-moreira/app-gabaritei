import '../core/data/database.dart';
import '../core/data/repository_helpers.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/json_utils.dart';
import '../models/question.dart';
import '../models/stats.dart';
import '../models/study.dart';
import '../services/dashboard_service.dart';
import '../services/statistics_service.dart';
import 'question_repository.dart';

/// Painel, estatísticas detalhadas e histórico de respostas do aluno.
class DashboardRepository {
  DashboardRepository({required this._db, QuestionRepository? questoes}) {
    _questoes = questoes ?? QuestionRepository(db: _db);
  }

  final GabariteiDatabase _db;
  late final QuestionRepository _questoes;

  static const itensPorPaginaHistorico = 20;

  Future<DashboardResumo> painel({
    required int idUsuario,
    DateTime? utcNow,
  }) {
    return mapDatabaseErrors(() async {
      final resultado = await _db
          .from('historico_respostas')
          .select('id_questao, is_correct, criado_em')
          .eq('id_usuario', idUsuario.toString())
          .limit(50000)
          .get();
      final historico = resultado.rows
          .map(HistoricoResposta.fromMap)
          .toList(growable: false);
      return DashboardService.build(historico, utcNow: utcNow);
    });
  }

  Future<DashboardDetalhado> estatisticasDetalhadas({
    required int idUsuario,
    DateTime? utcNow,
  }) {
    return mapDatabaseErrors(() async {
      final resultado = await _db
          .from('historico_respostas')
          .select('id_questao, is_correct, criado_em')
          .eq('id_usuario', idUsuario.toString())
          .order('criado_em', ascending: false)
          .get();
      final historico = resultado.rows
          .map(HistoricoResposta.fromMap)
          .toList(growable: false);

      final perfil = await _db
          .from('usuarios')
          .select('meta_diaria')
          .eq('id', idUsuario)
          .limit(1)
          .maybeSingle();

      final ids = <int>{
        for (final item in historico) item.idQuestao,
      }.toList(growable: false);
      final questoes = await _carregarMetadados(ids);

      return StatisticsService.build(
        historico,
        questoes,
        metaDiaria: Json.integer(perfil?['meta_diaria']),
        utcNow: utcNow,
      );
    });
  }

  Future<PaginaHistorico> historico({
    required int idUsuario,
    int pagina = 1,
  }) {
    if (pagina < 1) {
      throw ValidationException('Página inválida.');
    }
    final inicio = (pagina - 1) * itensPorPaginaHistorico;
    final fim = inicio + itensPorPaginaHistorico - 1;

    return mapDatabaseErrors(() async {
      final resultado = await _db
          .from('historico_respostas')
          .select('id_questao, is_correct, criado_em', countExact: true)
          .eq('id_usuario', idUsuario.toString())
          .order('criado_em', ascending: false)
          .range(inicio, fim)
          .get();
      final historico = resultado.rows
          .map(HistoricoResposta.fromMap)
          .toList(growable: false);

      final ids = <int>[];
      final vistos = <int>{};
      for (final item in historico) {
        if (item.idQuestao > 0 && vistos.add(item.idQuestao)) {
          ids.add(item.idQuestao);
        }
      }
      final questoes = ids.isEmpty
          ? const <Questao>[]
          : await _questoes.carregarPorIds(ids);
      final porId = {for (final questao in questoes) questao.id: questao};

      return PaginaHistorico(
        itens: [
          for (final item in historico)
            HistoricoComQuestao(
              historico: item,
              questao: porId[item.idQuestao],
            ),
        ],
        total: resultado.count ?? historico.length,
        pagina: pagina,
        itensPorPagina: itensPorPaginaHistorico,
      );
    });
  }

  Future<Map<int, Questao>> _carregarMetadados(List<int> ids) async {
    final porId = <int, Questao>{};
    for (var i = 0; i < ids.length; i += 500) {
      final fim = (i + 500 < ids.length) ? i + 500 : ids.length;
      final bloco = ids.sublist(i, fim);
      final resultado = await _db
          .from('view_questoes_completa')
          .select(
            'id_questao, id_materia, nome_materia, id_topico, nome_topico',
          )
          .inList('id_questao', bloco)
          .get();
      for (final linha in resultado.rows) {
        final questao = Questao.fromMap(linha);
        porId[questao.id] = questao;
      }
    }
    return porId;
  }
}
