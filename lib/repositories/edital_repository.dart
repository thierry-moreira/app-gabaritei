import 'dart:math';

import '../core/data/database.dart';
import '../core/data/repository_helpers.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/json_utils.dart';
import '../core/utils/python_math.dart';
import '../models/edital.dart';
import '../models/question.dart';
import '../models/stats.dart';
import '../services/edital_engine.dart';
import 'question_repository.dart';

/// Ciclo adaptativo de editais (`rotas/edital.py`).
class EditalRepository {
  EditalRepository({required this._db, QuestionRepository? questoes}) {
    _questoes = questoes ?? QuestionRepository(db: _db);
  }

  final GabariteiDatabase _db;
  late final QuestionRepository _questoes;

  static const _maxAvancosSeguidos = 200;

  Future<List<EditalCiclo>> listar(int idUsuario) {
    return mapDatabaseErrors(() async {
      final resultado = await _db
          .from('editais_ciclo')
          .select('*')
          .eq('id_usuario', idUsuario)
          .order('criado_em', ascending: false)
          .get();
      return resultado.rows.map(EditalCiclo.fromMap).toList(growable: false);
    });
  }

  Future<EditalCiclo> criar({
    required int idUsuario,
    required String titulo,
    required List<EditalMateriaSelecionada> materias,
  }) {
    final tituloLimpo = titulo.trim();
    if (tituloLimpo.isEmpty) {
      throw ValidationException('Informe o título do edital.');
    }
    final selecionadas = [
      for (final materia in materias)
        if (materia.idsTopicos.any((id) => id > 0))
          EditalMateriaSelecionada(
            idMateria: materia.idMateria,
            idsTopicos: [
              for (final id in materia.idsTopicos)
                if (id > 0) id,
            ],
          ),
    ];
    if (selecionadas.isEmpty) {
      throw ValidationException(
        'Selecione ao menos um assunto para montar o edital.',
      );
    }

    return mapDatabaseErrors(() async {
      int? idEdital;
      try {
        final linhas = await _db.from('editais_ciclo').insert({
          'id_usuario': idUsuario,
          'titulo': tituloLimpo,
        });
        if (linhas.isEmpty) {
          throw AppException('Não foi possível criar o edital.');
        }
        idEdital = Json.integer(linhas.first['id_edital']);
        var ordem = 1;
        int? primeiraMateria;
        int? primeiroTopico;

        for (final materia in selecionadas) {
          final linhasMateria = await _db.from('editais_materias').insert({
            'id_edital': idEdital,
            'id_materia': materia.idMateria,
            'id_usuario': idUsuario,
            'ordem': ordem,
          });
          if (linhasMateria.isEmpty) {
            throw AppException('Não foi possível montar o edital.');
          }
          final idEditalMateria = Json.integer(
            linhasMateria.first['id_edital_materia'],
          );
          if (ordem == 1) primeiraMateria = idEditalMateria;

          for (var i = 0; i < materia.idsTopicos.length; i++) {
            final linhasTopico = await _db.from('editais_topicos').insert({
              'id_edital_materia': idEditalMateria,
              'id_topico': materia.idsTopicos[i],
              'id_usuario': idUsuario,
            });
            if (linhasTopico.isEmpty) {
              throw AppException('Não foi possível montar o edital.');
            }
            if (ordem == 1 && i == 0) {
              primeiroTopico = Json.integer(
                linhasTopico.first['id_edital_topico'],
              );
            }
          }
          ordem++;
        }

        if (primeiraMateria == null || primeiroTopico == null) {
          throw ValidationException(
            'Selecione ao menos um assunto para montar o edital.',
          );
        }

        final meta = await _metaDinamicaDoTopico(primeiroTopico);
        await _db.from('editais_progresso').insert({
          'id_edital': idEdital,
          'id_usuario': idUsuario,
          'materia_atual_id': primeiraMateria,
          'topico_atual_id': primeiroTopico,
          'meta_dinamica': meta,
          'historico_topicos': <int>[],
        });

        return EditalCiclo.fromMap(linhas.first);
      } catch (_) {
        if (idEdital != null) {
          await _excluirSilencioso(idEdital);
        }
        rethrow;
      }
    });
  }

  /// Carrega a próxima questão do ciclo. Se o tópico atual não tiver mais
  /// questões inéditas, avança automaticamente (como o redirect do Flask).
  Future<EditalSessaoEstudo> estudar({
    required int idEdital,
    required int idUsuario,
    Random? random,
    DateTime? utcNow,
  }) {
    if (idEdital <= 0) {
      throw ValidationException('Edital inválido.');
    }
    return mapDatabaseErrors(() async {
      await _editalDoUsuario(idEdital, idUsuario);
      final gerador = random ?? Random();

      for (var tentativa = 0; tentativa < _maxAvancosSeguidos; tentativa++) {
        final progresso = await _progresso(idEdital);
        if (progresso == null) {
          throw AppException('Erro ao carregar o progresso do edital.');
        }
        final idTopicoAtual = progresso.topicoAtualId;
        if (idTopicoAtual == null) {
          return EditalSessaoEstudo(
            idEdital: idEdital,
            nomeMateria: '',
            nomeTopico: '',
            meta: 0,
            feitas: 0,
            concluido: true,
          );
        }

        final dados = await _contextoDoTopico(
          idEditalMateria: progresso.materiaAtualId,
          idEditalTopico: idTopicoAtual,
        );
        if (dados == null) {
          throw AppException('Erro ao carregar o tópico atual do edital.');
        }

        final historico = await _db
            .from('historico_respostas')
            .select('id_questao')
            .eq('id_usuario', idUsuario.toString())
            .limit(50000)
            .get();
        final idsFeitos = <int>[];
        for (final linha in historico.rows) {
          final id = _intOrNull(linha['id_questao']);
          if (id != null) idsFeitos.add(id);
        }

        var consulta = _db
            .from('view_questoes_completa')
            .select('*')
            .eq('id_topico', dados.idTopico);
        if (idsFeitos.isNotEmpty) {
          consulta = consulta.notInList('id_questao', idsFeitos);
        }
        final pool = await consulta.limit(50).get();
        if (pool.rows.isEmpty) {
          final avanco = await _avancarCiclo(
            idEdital: idEdital,
            idUsuario: idUsuario,
            marcarConcluido: true,
            random: gerador,
            utcNow: utcNow,
          );
          if (!avanco.sucesso) {
            throw AppException(avanco.mensagem);
          }
          continue;
        }

        final escolhida = pool.rows[gerador.nextInt(pool.rows.length)];
        final hidratadas = await _questoes.hidratarLinhas([escolhida]);
        final questao = hidratadas.isEmpty
            ? Questao.fromMap(escolhida)
            : hidratadas.first;
        final meta = progresso.metaDinamica == 0
            ? 10
            : progresso.metaDinamica;
        return EditalSessaoEstudo(
          idEdital: idEdital,
          nomeMateria: dados.nomeMateria,
          nomeTopico: dados.nomeTopico,
          meta: meta,
          feitas: progresso.questoesResolvidasNesteTopico,
          idEditalMateria: progresso.materiaAtualId,
          idEditalTopico: idTopicoAtual,
          idMateria: dados.idMateria,
          idTopico: dados.idTopico,
          questao: questao,
        );
      }
      throw AppException(
        'Não foi possível encontrar uma questão inédita neste edital.',
      );
    });
  }

  Future<RespostaQuestaoResultado> responder({
    required int idEdital,
    required int idUsuario,
    required int idQuestao,
    required String letra,
    Random? random,
    DateTime? utcNow,
  }) {
    if (idQuestao <= 0 || letra.trim().isEmpty) {
      throw ValidationException('Dados incompletos.');
    }
    return mapDatabaseErrors(() async {
      await _editalDoUsuario(idEdital, idUsuario);

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
        if (letraLinha == letra) {
          idMarcada = _intOrNull(linha['id_alternativa']);
        }
      }
      if (idMarcada == null) {
        throw ValidationException('Alternativa inválida.');
      }

      final correta = letra == letraCorreta;
      final linhaQuestao = await _db
          .from('questoes')
          .select('comentario_gabarito')
          .eq('id_questao', idQuestao)
          .limit(1)
          .maybeSingle();
      final comentario =
          linhaQuestao?['comentario_gabarito']?.toString() ?? 'Sem comentário.';

      await _db.from('historico_respostas').insertMinimal({
        'id_usuario': idUsuario.toString(),
        'id_questao': idQuestao,
        'is_correct': correta,
        'id_alternativa_marcada': idMarcada,
      });

      final progresso = await _progresso(idEdital);
      if (progresso == null) {
        throw AppException('Erro ao carregar o progresso do edital.');
      }
      final idMateriaAtual = progresso.materiaAtualId;
      final idTopicoAtual = progresso.topicoAtualId;
      if (idMateriaAtual == null || idTopicoAtual == null) {
        throw AppException('Este edital já foi concluído.');
      }
      final meta = progresso.metaDinamica == 0
          ? 10
          : progresso.metaDinamica;
      final resolvidas =
          progresso.questoesResolvidasNesteTopico + 1;

      final statsTopico = await _db
          .from('editais_topicos')
          .select('questoes_resolvidas, questoes_acertadas')
          .eq('id_edital_topico', idTopicoAtual)
          .limit(1)
          .maybeSingle();
      final resolvidasTopico =
          Json.integer(statsTopico?['questoes_resolvidas']) + 1;
      final acertadasTopico =
          Json.integer(statsTopico?['questoes_acertadas']) +
          (correta ? 1 : 0);
      await _db
          .from('editais_topicos')
          .update({
            'questoes_resolvidas': resolvidasTopico,
            'questoes_acertadas': acertadasTopico,
          })
          .eq('id_edital_topico', idTopicoAtual)
          .execute();

      final statsMateria = await _db
          .from('editais_materias')
          .select('questoes_resolvidas, questoes_acertadas')
          .eq('id_edital_materia', idMateriaAtual)
          .limit(1)
          .maybeSingle();
      final resolvidasMateria =
          Json.integer(statsMateria?['questoes_resolvidas']) + 1;
      final acertadasMateria =
          Json.integer(statsMateria?['questoes_acertadas']) +
          (correta ? 1 : 0);
      await _db
          .from('editais_materias')
          .update({
            'questoes_resolvidas': resolvidasMateria,
            'questoes_acertadas': acertadasMateria,
          })
          .eq('id_edital_materia', idMateriaAtual)
          .execute();

      var cicloAvancou = false;
      var mensagemAvanco = '';
      if (resolvidas >= meta) {
        final avanco = await _avancarCiclo(
          idEdital: idEdital,
          idUsuario: idUsuario,
          random: random,
          utcNow: utcNow,
        );
        cicloAvancou = avanco.sucesso;
        mensagemAvanco = avanco.mensagem;
      } else {
        await _db
            .from('editais_progresso')
            .update({'questoes_resolvidas_neste_topico': resolvidas})
            .eq('id_edital', idEdital)
            .execute();
      }

      return RespostaQuestaoResultado(
        correta: correta,
        letraCorreta: letraCorreta,
        comentario: comentario,
        cicloAvancou: cicloAvancou,
        mensagemAvanco: mensagemAvanco,
      );
    });
  }

  Future<EditalAvanco> pular({
    required int idEdital,
    required int idUsuario,
    Random? random,
    DateTime? utcNow,
  }) {
    return mapDatabaseErrors(() async {
      await _editalDoUsuario(idEdital, idUsuario);
      return _avancarCiclo(
        idEdital: idEdital,
        idUsuario: idUsuario,
        marcarConcluido: true,
        random: random,
        utcNow: utcNow,
      );
    });
  }

  Future<EditalAvanco> avancarCiclo({
    required int idEdital,
    required int idUsuario,
    bool marcarConcluido = false,
    Random? random,
    DateTime? utcNow,
  }) {
    return mapDatabaseErrors(() async {
      await _editalDoUsuario(idEdital, idUsuario);
      return _avancarCiclo(
        idEdital: idEdital,
        idUsuario: idUsuario,
        marcarConcluido: marcarConcluido,
        random: random,
        utcNow: utcNow,
      );
    });
  }

  Future<EditalPainel> dashboard({
    required int idEdital,
    required int idUsuario,
    DateTime? utcNow,
  }) {
    return mapDatabaseErrors(() async {
      final edital = await _editalDoUsuario(idEdital, idUsuario);
      final linhaProgresso = await _db
          .from('editais_progresso')
          .select('historico_topicos')
          .eq('id_edital', idEdital)
          .limit(1)
          .maybeSingle();
      final historico = Json.intList(
        linhaProgresso?['historico_topicos'],
      );

      final resultado = await _db
          .from('editais_materias')
          .select(
            '*, materias(nome_materia), '
            'editais_topicos(*, topicos(nome_topico))',
          )
          .eq('id_edital', idEdital)
          .order('ordem')
          .get();
      final materias = resultado.rows
          .map(EditalMateria.fromMap)
          .toList(growable: false);

      var totalResolvidas = 0;
      var totalAcertos = 0;
      final pontosAtencao = <PontoAtencaoEdital>[];
      final topicosPrioridade = <TopicoPrioridade>[];

      for (final materia in materias) {
        totalResolvidas += materia.questoesResolvidas;
        totalAcertos += materia.questoesAcertadas;
        final nomeMateria = materia.nomeMateria ?? 'Matéria Indefinida';

        for (final topico in materia.topicos) {
          final taxa = topico.questoesResolvidas == 0
              ? 0
              : pythonRound(
                  (topico.questoesAcertadas / topico.questoesResolvidas) * 100,
                );
          final peso = pythonRoundTo(
            EditalEngine.pesoTopico(
              idEditalTopico: topico.id,
              resolvidas: topico.questoesResolvidas,
              acertadas: topico.questoesAcertadas,
              ultimoEstudadoEm: topico.ultimoEstudadoEm,
              historicoTopicos: historico,
              agora: utcNow,
            ),
            1,
          );
          final meta = EditalEngine.metaDinamica(
            resolvidas: topico.questoesResolvidas,
            acertadas: topico.questoesAcertadas,
          );

          final String nivel;
          final String badge;
          if (peso >= 80) {
            nivel = 'alta';
            badge = 'danger';
          } else if (peso >= 50) {
            nivel = 'media';
            badge = 'warning';
          } else {
            nivel = 'baixa';
            badge = 'success';
          }
          final nomeTopico = topico.nomeTopico ?? 'Tópico Indefinido';
          topicosPrioridade.add(
            TopicoPrioridade(
              id: topico.id,
              nome: nomeTopico,
              idMateria: materia.idMateria,
              idTopico: topico.idTopico,
              taxaAcerto: taxa,
              pesoAdaptativo: peso,
              metaDinamica: meta,
              nivelPrioridade: nivel,
              badgeCor: badge,
            ),
          );

          if (topico.questoesResolvidas >= 3 && taxa < 60) {
            pontosAtencao.add(
              PontoAtencaoEdital(
                materia: nomeMateria,
                topico: nomeTopico,
                taxa: taxa,
                resolvidas: topico.questoesResolvidas,
                idMateria: materia.idMateria,
                idTopico: topico.idTopico,
                pesoAdaptativo: peso,
                metaDinamica: meta,
              ),
            );
          }
        }
      }

      pontosAtencao.sort((a, b) => a.taxa.compareTo(b.taxa));
      topicosPrioridade.sort(
        (a, b) => b.pesoAdaptativo.compareTo(a.pesoAdaptativo),
      );

      final desempenho = totalResolvidas == 0
          ? 0
          : pythonRound((totalAcertos / totalResolvidas) * 100);

      return EditalPainel(
        edital: edital,
        materias: materias,
        dashboard: EditalDashboard(
          totalResolvidas: totalResolvidas,
          totalAcertos: totalAcertos,
          desempenhoGeral: desempenho,
          pontosAtencao: pontosAtencao,
          topicosPrioridade: topicosPrioridade,
        ),
      );
    });
  }

  Future<void> excluir({
    required int idEdital,
    required int idUsuario,
  }) {
    if (idEdital <= 0) {
      throw ValidationException('Edital inválido.');
    }
    return mapDatabaseErrors(
      () => _db
          .from('editais_ciclo')
          .delete()
          .eq('id_edital', idEdital)
          .eq('id_usuario', idUsuario)
          .execute(),
    );
  }

  Future<EditalCiclo> _editalDoUsuario(
    int idEdital,
    int idUsuario,
  ) async {
    final linha = await _db
        .from('editais_ciclo')
        .select('*')
        .eq('id_edital', idEdital)
        .eq('id_usuario', idUsuario)
        .limit(1)
        .maybeSingle();
    if (linha == null) {
      throw NotFoundException('Edital não encontrado.');
    }
    return EditalCiclo.fromMap(linha);
  }

  Future<EditalProgresso?> _progresso(int idEdital) async {
    final linha = await _db
        .from('editais_progresso')
        .select('*')
        .eq('id_edital', idEdital)
        .limit(1)
        .maybeSingle();
    return linha == null ? null : EditalProgresso.fromMap(linha);
  }

  Future<({String nomeMateria, String nomeTopico, int idMateria, int idTopico})?>
  _contextoDoTopico({
    required int? idEditalMateria,
    required int idEditalTopico,
  }) async {
    if (idEditalMateria == null) return null;
    final materia = await _db
        .from('editais_materias')
        .select('id_materia, materias(nome_materia)')
        .eq('id_edital_materia', idEditalMateria)
        .limit(1)
        .maybeSingle();
    final topico = await _db
        .from('editais_topicos')
        .select('id_topico, topicos(nome_topico)')
        .eq('id_edital_topico', idEditalTopico)
        .limit(1)
        .maybeSingle();
    if (materia == null || topico == null) return null;

    final dadosMateria = Json.mapOrNull(materia['materias']);
    final dadosTopico = Json.mapOrNull(topico['topicos']);
    final idMateria = Json.integerOrNull(materia['id_materia']);
    final idTopico = Json.integerOrNull(topico['id_topico']);
    if (idMateria == null || idTopico == null) return null;

    return (
      nomeMateria: Json.text(
        dadosMateria?['nome_materia'],
        'Matéria Indefinida',
      ),
      nomeTopico: Json.text(
        dadosTopico?['nome_topico'],
        'Tópico Indefinido',
      ),
      idMateria: idMateria,
      idTopico: idTopico,
    );
  }

  Future<int> _metaDinamicaDoTopico(int idEditalTopico) async {
    final linha = await _db
        .from('editais_topicos')
        .select('questoes_resolvidas, questoes_acertadas')
        .eq('id_edital_topico', idEditalTopico)
        .limit(1)
        .maybeSingle();
    if (linha == null) return 15;
    return EditalEngine.metaDinamica(
      resolvidas: Json.integer(linha['questoes_resolvidas']),
      acertadas: Json.integer(linha['questoes_acertadas']),
    );
  }

  Future<EditalAvanco> _avancarCiclo({
    required int idEdital,
    required int idUsuario,
    bool marcarConcluido = false,
    Random? random,
    DateTime? utcNow,
  }) async {
    final progresso = await _progresso(idEdital);
    if (progresso == null) {
      return const EditalAvanco(
        sucesso: false,
        mensagem: 'Erro ao carregar progresso.',
      );
    }
    final idTopicoAtual = progresso.topicoAtualId;
    if (idTopicoAtual == null) {
      return const EditalAvanco(
        sucesso: false,
        mensagem: 'Este edital já foi concluído.',
      );
    }

    if (marcarConcluido) {
      await _db
          .from('editais_topicos')
          .update({'concluido': true})
          .eq('id_edital_topico', idTopicoAtual)
          .execute();
    }

    final historico = EditalEngine.atualizarHistorico(
      progresso.historicoTopicos,
      idTopicoAtual,
    );
    final gerador = random ?? Random();
    final agora = (utcNow ?? DateTime.now()).toUtc();

    final materiasResultado = await _db
        .from('editais_materias')
        .select(
          'id_edital_materia, questoes_resolvidas, questoes_acertadas',
        )
        .eq('id_edital', idEdital)
        .order('ordem')
        .get();
    if (materiasResultado.rows.isEmpty) {
      return const EditalAvanco(
        sucesso: false,
        mensagem: 'Nenhuma matéria encontrada no edital.',
      );
    }

    final materiasComTaxa = <({int id, double taxa})>[];
    for (final linha in materiasResultado.rows) {
      final id = _intOrNull(linha['id_edital_materia']);
      if (id == null) continue;
      final resolvidas = Json.integer(linha['questoes_resolvidas']);
      final acertadas = Json.integer(linha['questoes_acertadas']);
      materiasComTaxa.add((
        id: id,
        taxa: resolvidas == 0 ? 0 : acertadas / resolvidas,
      ));
    }

    final idMateriaProxima = EditalEngine.escolherProximaMateria(
      materiasComTaxa,
      gerador,
    );
    if (idMateriaProxima == null) {
      return const EditalAvanco(
        sucesso: false,
        mensagem: 'Nenhuma matéria encontrada no edital.',
      );
    }

    var topicos = await _db
        .from('editais_topicos')
        .select(
          'id_edital_topico, questoes_resolvidas, questoes_acertadas, '
          'ultimo_estudado_em, vezes_estudado',
        )
        .eq('id_edital_materia', idMateriaProxima)
        .eq('concluido', false)
        .get();

    if (topicos.rows.isEmpty) {
      await _db
          .from('editais_topicos')
          .update({'concluido': false})
          .eq('id_edital_materia', idMateriaProxima)
          .execute();
      topicos = await _db
          .from('editais_topicos')
          .select(
            'id_edital_topico, questoes_resolvidas, questoes_acertadas, '
            'ultimo_estudado_em, vezes_estudado',
          )
          .eq('id_edital_materia', idMateriaProxima)
          .get();
    }
    if (topicos.rows.isEmpty) {
      return const EditalAvanco(
        sucesso: false,
        mensagem: 'Erro: nenhum tópico disponível.',
      );
    }

    final candidatos = <({int id, double peso})>[];
    final dadosPorId = <int, Map<String, dynamic>>{};
    for (final linha in topicos.rows) {
      final id = _intOrNull(linha['id_edital_topico']);
      if (id == null) continue;
      dadosPorId[id] = linha;
      candidatos.add((
        id: id,
        peso: EditalEngine.pesoTopico(
          idEditalTopico: id,
          resolvidas: Json.integer(linha['questoes_resolvidas']),
          acertadas: Json.integer(linha['questoes_acertadas']),
          ultimoEstudadoEm: Json.dateTime(linha['ultimo_estudado_em']),
          historicoTopicos: historico,
          agora: agora,
        ),
      ));
    }
    final idTopicoProximo = EditalEngine.escolherProximoTopico(
      candidatos,
      gerador,
    );
    if (idTopicoProximo == null) {
      return const EditalAvanco(
        sucesso: false,
        mensagem: 'Erro: nenhum tópico disponível.',
      );
    }

    final dadosTopico = dadosPorId[idTopicoProximo]!;
    final meta = EditalEngine.metaDinamica(
      resolvidas: Json.integer(dadosTopico['questoes_resolvidas']),
      acertadas: Json.integer(dadosTopico['questoes_acertadas']),
    );
    final vezes = Json.integer(dadosTopico['vezes_estudado']) + 1;
    await _db
        .from('editais_topicos')
        .update({
          'vezes_estudado': vezes,
          'ultimo_estudado_em': agora.toIso8601String(),
        })
        .eq('id_edital_topico', idTopicoProximo)
        .execute();

    await _db
        .from('editais_progresso')
        .update({
          'materia_atual_id': idMateriaProxima,
          'topico_atual_id': idTopicoProximo,
          'questoes_resolvidas_neste_topico': 0,
          'meta_dinamica': meta,
          'historico_topicos': historico,
        })
        .eq('id_edital', idEdital)
        .execute();

    final linhaNome = await _db
        .from('editais_materias')
        .select('materias(nome_materia)')
        .eq('id_edital_materia', idMateriaProxima)
        .limit(1)
        .maybeSingle();
    final nomeMateria = Json.text(
      Json.mapOrNull(linhaNome?['materias'])?['nome_materia'],
    );
    return EditalAvanco(
      sucesso: true,
      mensagem: 'Avançando para $nomeMateria — meta: $meta questões.',
      metaDinamica: meta,
    );
  }

  Future<void> _excluirSilencioso(int idEdital) async {
    try {
      await _db
          .from('editais_ciclo')
          .delete()
          .eq('id_edital', idEdital)
          .execute();
    } catch (_) {
      // Limpeza de melhor esforço.
    }
  }

  int? _intOrNull(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
