import 'dart:math';

import '../core/data/database.dart';
import '../core/data/repository_helpers.dart';
import '../core/errors/app_exception.dart';
import '../models/simulado.dart';
import '../services/simulado_service.dart';
import 'question_repository.dart';

/// Simulados: feed, geração, correção, ranking e dados para PDF.
///
/// Reproduz `rotas/simulado.py`, incluindo o guard de visibilidade: simulado
/// privado de outro aluno responde igual a simulado inexistente.
class SimuladoRepository {
  SimuladoRepository({required this._db, QuestionRepository? questoes}) {
    _questoes = questoes ?? QuestionRepository(db: _db);
  }

  final GabariteiDatabase _db;
  late final QuestionRepository _questoes;

  Future<SimuladoListagem> listar({required int idUsuario}) async {
    final resultados = await Future.wait([
      listarPublicos(idUsuario: idUsuario),
      listarMeusPrivados(idUsuario: idUsuario),
    ]);
    return SimuladoListagem(publicos: resultados[0], privados: resultados[1]);
  }

  Future<List<Simulado>> listarPublicos({required int idUsuario}) {
    return mapDatabaseErrors(() async {
      final resultado = await _db
          .from('view_simulados_publicos')
          .select('*')
          .order('criado_em', ascending: false)
          .get();
      return [
        for (final linha in resultado.rows)
          _simuladoDaView(linha, idUsuario),
      ];
    });
  }

  Future<List<Simulado>> listarMeusPrivados({required int idUsuario}) {
    return mapDatabaseErrors(() async {
      final resultado = await _db
          .from('simulados')
          .select('*')
          .eq('id_criador', idUsuario)
          .eq('eh_privado', true)
          .order('criado_em', ascending: false)
          .get();
      return [
        for (final linha in resultado.rows)
          Simulado.fromMap(linha).copyWith(ehMeu: true),
      ];
    });
  }

  Future<Simulado> buscar({
    required String idSimulado,
    required int idUsuario,
  }) {
    if (idSimulado.trim().isEmpty) {
      throw ValidationException('Simulado inválido.');
    }
    return mapDatabaseErrors(() async {
      final encontrado = await _buscarVisivel(idSimulado, idUsuario);
      if (encontrado == null) {
        throw NotFoundException('Simulado não encontrado.');
      }
      return encontrado;
    });
  }

  /// Cria o simulado e sorteia as questões de cada cota.
  Future<Simulado> gerar({
    required int idUsuario,
    required String titulo,
    required List<CotaSimulado> cotas,
    FiltrosSimulado filtros = const FiltrosSimulado(),
    bool ehPrivado = false,
    Random? random,
  }) async {
    final tituloLimpo = titulo.trim();
    if (tituloLimpo.isEmpty) {
      throw ValidationException('Informe o título do simulado.');
    }
    if (cotas.isEmpty || cotas.every((cota) => cota.quantidade <= 0)) {
      throw ValidationException('Selecione ao menos uma matéria e quantidade.');
    }

    final gerador = random ?? Random();
    return mapDatabaseErrors(() async {
      String? idCriado;
      try {
        final linhas = await _db.from('simulados').insert({
          'id_criador': idUsuario,
          'titulo': tituloLimpo,
          'eh_privado': ehPrivado,
        });
        if (linhas.isEmpty) {
          throw AppException('Não foi possível criar o simulado.');
        }
        final simulado = Simulado.fromMap(linhas.first).copyWith(ehMeu: true);
        idCriado = simulado.id;

        final idsSelecionados = <int>[];
        final vistos = <int>{};
        for (final cota in cotas) {
          if (cota.quantidade <= 0) continue;
          final pool = await _poolQuestoes(cota, filtros);
          final sorteadas = SimuladoService.amostrar(
            pool,
            cota.quantidade,
            gerador,
          );
          for (final id in sorteadas) {
            if (vistos.add(id)) idsSelecionados.add(id);
          }
        }

        if (idsSelecionados.isEmpty) {
          await _excluirSilencioso(idCriado);
          throw ValidationException(
            'Não encontramos questões suficientes com esses filtros.',
          );
        }

        await _db.from('simulados_questoes').insertMinimal([
          for (final idQuestao in idsSelecionados)
            {'id_simulado': idCriado, 'id_questao': idQuestao},
        ]);
        return simulado;
      } catch (_) {
        if (idCriado != null) {
          await _excluirSilencioso(idCriado);
        }
        rethrow;
      }
    });
  }

  Future<SimuladoComQuestoes> sessao({
    required String idSimulado,
    required int idUsuario,
    Random? random,
  }) async {
    final simulado = await buscar(
      idSimulado: idSimulado,
      idUsuario: idUsuario,
    );
    final ids = await mapDatabaseErrors(
      () => _idsQuestoes(idSimulado),
    );
    if (ids.isEmpty) {
      throw ValidationException('Este simulado está vazio.');
    }

    final questoes = await _questoes.carregarPorIds(ids);
    if (questoes.isEmpty) {
      throw ValidationException('Este simulado está vazio.');
    }
    questoes.shuffle(random ?? Random());
    return SimuladoComQuestoes(simulado: simulado, questoes: questoes);
  }

  /// Questões na ordem de criação, sem embaralhar (usado no PDF).
  Future<SimuladoComQuestoes> dadosPdf({
    required String idSimulado,
    required int idUsuario,
  }) async {
    final simulado = await buscar(
      idSimulado: idSimulado,
      idUsuario: idUsuario,
    );
    final ids = await mapDatabaseErrors(
      () => _idsQuestoes(idSimulado),
    );
    if (ids.isEmpty) {
      throw ValidationException('Este simulado está vazio.');
    }
    final questoes = await _questoes.carregarPorIds(ids);
    if (questoes.isEmpty) {
      throw ValidationException('Este simulado está vazio.');
    }
    return SimuladoComQuestoes(simulado: simulado, questoes: questoes);
  }

  Future<SimuladoResultado> corrigir({
    required String idSimulado,
    required int idUsuario,
    required Map<int, String?> respostas,
  }) {
    return mapDatabaseErrors(() async {
      final simulado = await _buscarVisivel(idSimulado, idUsuario);
      if (simulado == null) {
        throw NotFoundException('Simulado não encontrado.');
      }

      final ids = await _idsQuestoes(idSimulado);
      if (ids.isEmpty) {
        throw ValidationException('Este simulado está vazio.');
      }

      final gabaritoResultado = await _db
          .from('alternativas_questao')
          .select('id_questao, letra')
          .eq('is_correct', true)
          .inList('id_questao', ids)
          .get();
      final gabaritos = <int, String>{};
      for (final linha in gabaritoResultado.rows) {
        final id = _intOrNull(linha['id_questao']);
        final letra = linha['letra']?.toString();
        if (id != null && letra != null) gabaritos[id] = letra;
      }

      final resultado = SimuladoService.corrigir(
        idsQuestoes: ids,
        gabaritos: gabaritos,
        respostas: respostas,
      );

      await _db.from('simulados_resultados').insertMinimal({
        'id_simulado': idSimulado,
        'id_usuario': idUsuario,
        'nota': resultado.nota,
        'respostas_corretas': resultado.acertos,
        'total_questoes': resultado.total,
      });

      final ranking = await _ranking(idSimulado);
      return SimuladoResultado(
        nota: resultado.nota,
        acertos: resultado.acertos,
        total: resultado.total,
        detalhes: resultado.detalhes,
        ranking: ranking,
      );
    });
  }

  Future<List<RankingEntry>> ranking({
    required String idSimulado,
    required int idUsuario,
  }) async {
    final simulado = await buscar(
      idSimulado: idSimulado,
      idUsuario: idUsuario,
    );
    if (simulado.id.isEmpty) {
      throw NotFoundException('Simulado não encontrado.');
    }
    return mapDatabaseErrors(() => _ranking(idSimulado));
  }

  Future<void> excluir({
    required String idSimulado,
    required int idUsuario,
  }) {
    return mapDatabaseErrors(() async {
      final linha = await _db
          .from('simulados')
          .select('id_criador')
          .eq('id', idSimulado)
          .limit(1)
          .maybeSingle();
      final dono = _intOrNull(linha?['id_criador']);
      if (linha == null || dono != idUsuario) {
        throw NotFoundException('Simulado não encontrado.');
      }
      await _db
          .from('simulados')
          .delete()
          .eq('id', idSimulado)
          .eq('id_criador', idUsuario)
          .execute();
    });
  }

  Future<Simulado?> _buscarVisivel(
    String idSimulado,
    int idUsuario,
  ) async {
    final tabela = await _db
        .from('simulados')
        .select('*')
        .eq('id', idSimulado)
        .limit(1)
        .maybeSingle();
    if (tabela != null) {
      final simulado = Simulado.fromMap(tabela).copyWith(
        ehMeu: _intOrNull(tabela['id_criador']) == idUsuario,
      );
      if (!SimuladoService.podeAcessar(simulado, idUsuario)) return null;
      return simulado;
    }

    final view = await _db
        .from('view_simulados_publicos')
        .select('*')
        .eq('id', idSimulado)
        .limit(1)
        .maybeSingle();
    if (view == null) return null;
    final simulado = _simuladoDaView(view, idUsuario);
    if (!SimuladoService.podeAcessar(simulado, idUsuario)) return null;
    return simulado;
  }

  Simulado _simuladoDaView(
    Map<String, dynamic> linha,
    int idUsuario,
  ) {
    final simulado = Simulado.fromMap(linha);
    return simulado.copyWith(
      idCriador: simulado.ehMeu ? idUsuario : null,
    );
  }

  Future<List<int>> _idsQuestoes(String idSimulado) async {
    final resultado = await _db
        .from('simulados_questoes')
        .select('id_questao')
        .eq('id_simulado', idSimulado)
        .get();
    final ids = <int>[];
    for (final linha in resultado.rows) {
      final id = _intOrNull(linha['id_questao']);
      if (id != null) ids.add(id);
    }
    if (ids.isNotEmpty) return ids;

    final publicas = await _db
        .from('view_simulados_questoes_publicas')
        .select('id_questao')
        .eq('id_simulado', idSimulado)
        .get();
    for (final linha in publicas.rows) {
      final id = _intOrNull(linha['id_questao']);
      if (id != null) ids.add(id);
    }
    return ids;
  }

  Future<List<int>> _poolQuestoes(
    CotaSimulado cota,
    FiltrosSimulado filtros,
  ) async {
    var consulta = _db
        .from('view_questoes_completa')
        .select('id_questao');
    if (cota.idMateria != null) {
      consulta = consulta.eq('id_materia', cota.idMateria!);
    }
    if (filtros.idNivel != null) {
      consulta = consulta.eq('id_nivel', filtros.idNivel!);
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
    if (filtros.tiposQuestao.isNotEmpty) {
      consulta = consulta.inList('tipo_questao', filtros.tiposQuestao);
    }
    if (cota.idsTopicos.isNotEmpty) {
      consulta = consulta.inList('id_topico', cota.idsTopicos);
    }
    final resultado = await consulta.limit(500).get();
    return [
      for (final linha in resultado.rows)
        if (_intOrNull(linha['id_questao']) != null)
          _intOrNull(linha['id_questao'])!,
    ];
  }

  Future<List<RankingEntry>> _ranking(String idSimulado) async {
    final linhas = await _db.rpc(
      'ranking_simulado',
      params: {'p_id_simulado': idSimulado},
    );
    return linhas
        .map(RankingEntry.fromMap)
        .take(10)
        .toList(growable: false);
  }

  Future<void> _excluirSilencioso(String? idSimulado) async {
    if (idSimulado == null) return;
    try {
      await _db.from('simulados').delete().eq('id', idSimulado).execute();
    } catch (_) {
      // Limpeza de melhor esforço: não esconde o erro original.
    }
  }

  int? _intOrNull(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
