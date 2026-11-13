import '../core/data/database.dart';
import '../core/data/global_write_gateway.dart';
import '../core/data/repository_helpers.dart';
import '../core/errors/app_exception.dart';
import '../core/moderation/moderation_service.dart';
import '../core/utils/json_utils.dart';
import '../models/question.dart';
import '../services/ai_provider_service.dart';
import '../services/legislacao_service.dart';
import '../services/study_ai_service.dart';
import 'ia_config_store.dart';
import 'question_repository.dart';

/// IA BYOK: explicação, resumo/flashcard e denúncias de conteúdo gerado.
///
/// Reproduz as rotas `/api/ia_explica`, `/api/ia/gerar_estudo` e
/// `/api/feedback_ia`. O cache global é consultado antes de exigir a chave do
/// aluno, como no backend.
class StudyAiRepository {
  StudyAiRepository({
    required this._db,
    required this._store,
    required this._globalWrites,
    AiProviderService? provider,
    LegislacaoService? legislacao,
    QuestionRepository? questoes,
    this._moderacao = const ModerationService(),
  }) {
    _provider = provider ?? AiProviderService();
    _legislacao = legislacao ?? LegislacaoService(_db);
    _questoes = questoes ?? QuestionRepository(db: _db);
  }

  final GabariteiDatabase _db;
  final IaConfigStore _store;
  final GlobalWriteGateway _globalWrites;
  final ModerationService _moderacao;
  late final AiProviderService _provider;
  late final LegislacaoService _legislacao;
  late final QuestionRepository _questoes;

  static const motivosFeedback = <String, String>{
    'conteudo_incorreto': 'Conteúdo incorreto',
    'citacao_legal': 'Citação de lei errada ou desatualizada',
    'desatualizado': 'Conteúdo desatualizado',
    'formatacao': 'Problema de formatação',
    'outro': 'Outro',
  };

  static const _tiposFeedback = {'explicacao', 'resumo', 'flashcard'};

  /// Devolve do cache global ou gera uma explicação com a chave do aluno.
  Future<String> explicacao({
    required int idQuestao,
    required int idUsuario,
  }) {
    if (idQuestao <= 0) {
      throw ValidationException('Questão inválida.');
    }
    return mapDatabaseErrors(() async {
      final cache = await _lerExplicacaoCache(idQuestao);
      if (cache != null) return cache;

      final config = await _store.ler(idUsuario);
      if (config == null) {
        throw IaException(
          StudyAiService.msgNaoConfigurada,
          code: 'sem_config',
        );
      }

      final questao = await _questoes.detalhe(idQuestao);
      final trechos = await _legislacao.recuperar(
        enunciado: questao.enunciado,
        idSubtopico: questao.idSubtopico,
      );
      final blocoLegislacao = LegislacaoService.montarBlocoContexto(trechos);
      final systemPrompt = StudyAiService.explanationSystemPrompt(
        hasLegislation: blocoLegislacao.isNotEmpty,
      );
      final userPrompt = StudyAiService.explanationUserPrompt(
        questao: questao,
        legislationBlock: blocoLegislacao,
      );

      final conteudo = <AiContentPart>[AiContentPart.text(userPrompt)];
      for (final url in _urlsImagens(
        enunciado: questao.enunciado,
        alternativas: questao.alternativas,
        legado: questao.urlImagem,
      )) {
        conteudo.add(AiContentPart.imageUrl(url));
      }

      final gerado = await _provider.chamar(
        config: config,
        systemPrompt: systemPrompt,
        conteudo: conteudo,
        temperature: 0,
        topP: 0.1,
        presencePenalty: 0,
        frequencyPenalty: 0,
      );
      final explicacaoFinal = StudyAiService.sanitizeExplanation(gerado);

      final evidencia = LegislacaoService.montarEvidencia(trechos);
      final payload = <String, dynamic>{
        'id_questao': idQuestao,
        'conteudo_explicacao': explicacaoFinal,
        if (evidencia.isNotEmpty) 'contexto_legislacao': evidencia,
      };
      try {
        await _globalWrites.submit({
          'operation': 'cache_explanation',
          ...payload,
        });
        return await _lerExplicacaoCache(idQuestao) ?? explicacaoFinal;
      } catch (_) {
        // Cache é uma otimização: não bloqueia a explicação já gerada se a
        // Edge Function ou a leitura de confirmação estiver indisponível.
        return explicacaoFinal;
      }
    });
  }

  /// Gera (ou reaproveita do cache) um resumo/flashcard e o adiciona ao
  /// caderno do aluno, criando a categoria automática quando necessário.
  Future<StudyGenerationResult> gerarEstudo({
    required int idQuestao,
    required int idUsuario,
    required StudyContentType tipo,
  }) {
    if (idQuestao <= 0) {
      throw ValidationException('Questão inválida.');
    }
    return mapDatabaseErrors(() async {
      final questao = await _questoes.detalhe(idQuestao);
      final idUsuarioTexto = idUsuario.toString();
      final idMateria = questao.idMateria;

      final tabelaExistente = tipo == StudyContentType.resumo
          ? 'resumos_estudo'
          : 'flashcards';
      final colunaExistente = tipo == StudyContentType.resumo
          ? 'id_resumo'
          : 'id_flashcard';
      final existente = await _db
          .from(tabelaExistente)
          .select(colunaExistente)
          .eq('id_usuario', idUsuarioTexto)
          .eq('id_questao', idQuestao)
          .limit(1)
          .maybeSingle();
      if (existente != null) {
        return StudyGenerationResult(
          tipo: tipo,
          jaPossuia: true,
          mensagem: tipo == StudyContentType.resumo
              ? 'Este resumo já está no seu caderno!'
              : 'Você já possui um flashcard para esta questão!',
        );
      }

      final cacheLinha = await _db
          .from('ia_cache_estudo')
          .select('conteudo_json')
          .eq('id_questao', idQuestao)
          .eq('tipo', tipo.wire)
          .limit(1)
          .maybeSingle();
      final cacheJson = Json.mapOrNull(cacheLinha?['conteudo_json']);
      final usouCache = cacheJson != null;

      StudyContent conteudo;
      if (cacheJson != null) {
        conteudo = StudyContent.fromJson(cacheJson, tipo: tipo);
      } else {
        final config = await _store.ler(idUsuario);
        if (config == null) {
          throw IaException(
            StudyAiService.msgNaoConfigurada,
            code: 'sem_config',
          );
        }

        final explicacaoCache = await _lerExplicacaoCache(idQuestao);
        var templateMateria =
            'Você é um professor especialista concursado.';
        if (idMateria != null) {
          final prompt = await _db
              .from('prompts_materias')
              .select('template_prompt')
              .eq('id_materia', idMateria)
              .limit(1)
              .maybeSingle();
          final texto = prompt?['template_prompt']?.toString();
          if (texto != null && texto.isNotEmpty) {
            templateMateria = texto;
          }
        }

        final systemPrompt = StudyAiService.studySystemPrompt(
          tipo: tipo,
          templateMateria: templateMateria,
        );
        final userPrompt = StudyAiService.studyUserPrompt(
          questao: questao,
          explicacaoBase: explicacaoCache,
        );
        final partes = <AiContentPart>[AiContentPart.text(userPrompt)];
        for (final url in _urlsImagens(
          enunciado: questao.enunciado,
          alternativas: const [],
          legado: questao.urlImagem,
        )) {
          partes.add(AiContentPart.imageUrl(url));
        }

        final gerado = await _provider.chamar(
          config: config,
          systemPrompt: systemPrompt,
          conteudo: partes,
          temperature: StudyAiService.temperatureGpt,
        );
        conteudo = StudyAiService.parseStudyContent(
          tipo: tipo,
          gerado: gerado,
          nomeMateria: questao.nomeMateria ?? 'Geral',
        );
        try {
          await _globalWrites.submit({
            'operation': 'cache_study',
            'id_questao': idQuestao,
            'tipo': tipo.wire,
            'conteudo_json': conteudo.toJson(),
          });
          final cachePersistido = await _db
              .from('ia_cache_estudo')
              .select('conteudo_json')
              .eq('id_questao', idQuestao)
              .eq('tipo', tipo.wire)
              .limit(1)
              .maybeSingle();
          final jsonPersistido = Json.mapOrNull(
            cachePersistido?['conteudo_json'],
          );
          if (jsonPersistido != null) {
            conteudo = StudyContent.fromJson(jsonPersistido, tipo: tipo);
          }
        } catch (_) {
          // Cache global é best-effort; o conteúdo ainda é salvo no caderno.
        }
      }

      if (tipo == StudyContentType.resumo) {
        if (idMateria == null) {
          throw AppException('Questão sem matéria vinculada.');
        }
        await _db.from('resumos_estudo').insertMinimal({
          'id_usuario': idUsuarioTexto,
          'id_questao': idQuestao,
          'id_materia': idMateria,
          'conteudo': conteudo.conteudo ?? '',
        });
      } else {
        final nomeMateria = questao.nomeMateria ?? 'Geral';
        final categoria = await _db
            .from('flashcard_categorias')
            .select('id_categoria')
            .eq('id_usuario', idUsuarioTexto)
            .eq('nome_categoria', nomeMateria)
            .limit(1)
            .maybeSingle();
        String? idCategoria = categoria?['id_categoria']?.toString();
        if (idCategoria == null) {
          final linhas = await _db.from('flashcard_categorias').insert({
            'id_usuario': idUsuarioTexto,
            'nome_categoria': nomeMateria,
            'id_materia': ?idMateria,
          });
          idCategoria = linhas.isEmpty
              ? null
              : linhas.first['id_categoria']?.toString();
          if (idCategoria == null) {
            throw AppException('Falha ao criar categoria automática.');
          }
        }
        await _db.from('flashcards').insertMinimal({
          'id_usuario': idUsuarioTexto,
          'id_categoria': idCategoria,
          'id_questao': idQuestao,
          'frente': conteudo.frente ?? 'Revisão',
          'verso': conteudo.verso ?? '...',
        });
      }

      return StudyGenerationResult(
        tipo: tipo,
        usouCacheGlobal: usouCache,
      );
    });
  }

  /// Envia feedback de IA pela sessão autenticada, sem gravar a identidade no
  /// registro público de feedback.
  Future<void> enviarFeedback({
    required int idQuestao,
    required String tipo,
    required String motivo,
    String relato = '',
  }) {
    if (idQuestao <= 0 || !_tiposFeedback.contains(tipo)) {
      throw ValidationException('Dados incompletos.');
    }
    if (!motivosFeedback.containsKey(motivo)) {
      throw ValidationException('Motivo inválido.');
    }
    final relatoLimpo = relato.trim();
    final moderacao = _moderacao.check(relatoLimpo);
    if (!moderacao.allowed) {
      throw ValidationException(moderacao.message);
    }
    final truncado = relatoLimpo.length > 1000
        ? relatoLimpo.substring(0, 1000)
        : relatoLimpo;

    return mapDatabaseErrors(
      () => _globalWrites.submit({
        'operation': 'feedback_ai',
        'id_questao': idQuestao,
        'tipo': tipo,
        'motivo': motivo,
        'relato': truncado.isEmpty ? null : truncado,
      }),
    );
  }

  Future<String?> _lerExplicacaoCache(int idQuestao) async {
    final linha = await _db
        .from('explicacoes_ia')
        .select('conteudo_explicacao')
        .eq('id_questao', idQuestao)
        .limit(1)
        .maybeSingle();
    final conteudo = linha?['conteudo_explicacao']?.toString();
    return conteudo == null || conteudo.isEmpty ? null : conteudo;
  }

  List<String> _urlsImagens({
    required String enunciado,
    required List<Alternativa> alternativas,
    String? legado,
  }) {
    final urls = <String>[];
    if (legado != null && legado.isNotEmpty) {
      final partes = legado.split('/');
      final arquivo = partes.isEmpty ? '' : partes.last;
      if (arquivo.isNotEmpty) {
        urls.add(_db.publicStorageUrl('imagens_questoes', arquivo));
      }
    }
    urls.addAll(_extrairImagens(enunciado));
    for (final alternativa in alternativas) {
      urls.addAll(_extrairImagens(alternativa.texto));
    }
    return urls;
  }

  List<String> _extrairImagens(String texto) => [
    for (final match in _imagemPattern.allMatches(texto)) match.group(1)!,
  ];

  static final _imagemPattern = RegExp(
    r'''<img[^>]+src=["']([^"']+)["']''',
    caseSensitive: false,
  );
}
