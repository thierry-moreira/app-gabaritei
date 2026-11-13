import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gabaritei_app/core/errors/app_exception.dart';
import 'package:gabaritei_app/core/providers.dart';
import 'package:gabaritei_app/models/question.dart';
import 'package:gabaritei_app/models/stats.dart';
import 'package:gabaritei_app/models/study.dart';
import 'package:gabaritei_app/models/taxonomy.dart';
import 'package:gabaritei_app/models/user_profile.dart';
import 'package:gabaritei_app/presentation/home/questoes_screen.dart';
import 'package:gabaritei_app/repositories/caderno_repository.dart';
import 'package:gabaritei_app/repositories/question_repository.dart';
import 'package:gabaritei_app/repositories/study_ai_repository.dart';
import 'package:gabaritei_app/services/filter_service.dart';
import 'package:gabaritei_app/services/study_ai_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockQuestionRepository extends Mock implements QuestionRepository {}

class _MockStudyAiRepository extends Mock implements StudyAiRepository {}

class _MockCadernoRepository extends Mock implements CadernoRepository {}

/// Garante que a tela de questões não estoure o layout em celulares e tablets
/// e que o fluxo de resposta funcione com os dados injetados.
void main() {
  late _MockQuestionRepository repo;
  late _MockStudyAiRepository aiRepo;
  late _MockCadernoRepository cadernoRepo;

  setUp(() {
    repo = _MockQuestionRepository();
    aiRepo = _MockStudyAiRepository();
    cadernoRepo = _MockCadernoRepository();
    when(() => cadernoRepo.listar(50)).thenAnswer(
      (_) async => const [
        Caderno(id: 'caderno-1', idUsuario: 50, nome: 'Direito Constitucional'),
      ],
    );
  });

  Future<void> render(
    WidgetTester tester,
    Size size, {
    Brightness brightness = Brightness.light,
    PaginaQuestoes? pagina,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          perfilAtualProvider.overrideWith(
            (ref) async => const UserProfile(id: 50, username: 'thierry_n1'),
          ),
          painelProvider.overrideWith((ref) async => _resumoFixo()),
          questoesPaginaProvider.overrideWith((ref) async {
            final filtrosAtivos = ref.watch(questoesFiltrosProvider);
            final base = pagina ?? _paginaFixa();
            if (base.pagina == filtrosAtivos.pagina) return base;
            return PaginaQuestoes(
              questoes: base.questoes,
              total: base.total,
              pagina: filtrosAtivos.pagina,
              itensPorPagina: base.itensPorPagina,
              statusRespostas: base.statusRespostas,
            );
          }),
          totalQuestoesProvider.overrideWith((ref) async => 3507),
          taxonomyCatalogProvider.overrideWith((ref) async => _catalogoFixo()),
          filtrosSalvosProvider.overrideWith(
            (ref) async => const <FiltroSalvo>[],
          ),
          questionRepositoryProvider.overrideWithValue(repo),
          studyAiRepositoryProvider.overrideWithValue(aiRepo),
          cadernoRepositoryProvider.overrideWithValue(cadernoRepo),
        ],
        child: MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: const QuestoesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('questões celular tema claro', (tester) async {
    await render(tester, const Size(390, 844));
    expect(tester.takeException(), isNull);

    expect(find.text('Questão #1730'), findsOneWidget);
    expect(find.byKey(const Key('questao-header-divider')), findsOneWidget);
    expect(find.text('Noções de Informática'), findsOneWidget);
    expect(find.text('Redes de Computadores'), findsOneWidget);
    expect(find.textContaining('3507', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('Total disponível no banco:', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Filtros de Busca Avançados'), findsOneWidget);
    expect(find.text('Meus Filtros Salvos'), findsOneWidget);
    expect(find.text('SFTP.'), findsOneWidget);
    expect(find.text('Responder'), findsOneWidget);
    expect(find.text('Comentários'), findsOneWidget);
    expect(find.text('IA Explica'), findsOneWidget);
    // Sem texto de apoio, o bloco recolhível nem aparece.
    expect(find.text('TEXTO DE APOIO'), findsNothing);
    // A resolução não pode aparecer antes de o aluno responder ou pedir a
    // explicação: o comentário do gabarito entrega a resposta.
    expect(find.text('Explicação Passo a Passo'), findsNothing);
    expect(find.text('🧠 Resolução Comentada'), findsNothing);
    expect(
      find.textContaining('O SFTP utiliza', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('mantém a questão atual ao sair para o dashboard e voltar', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final questoes = [
      for (var i = 0; i < 10; i++)
        Questao(
          id: 8000 + i,
          enunciado: 'Enunciado da questão ${i + 1}',
          status: 'publicada',
        ),
    ];
    final pagina = PaginaQuestoes(
      questoes: questoes,
      total: questoes.length,
      pagina: 1,
      itensPorPagina: 10,
      statusRespostas: {for (final questao in questoes) questao.id: null},
    );
    final container = ProviderContainer(
      overrides: [
        perfilAtualProvider.overrideWith(
          (ref) async => const UserProfile(id: 50, username: 'thierry_n1'),
        ),
        painelProvider.overrideWith((ref) async => _resumoFixo()),
        questoesPaginaProvider.overrideWith((ref) async => pagina),
        totalQuestoesProvider.overrideWith((ref) async => questoes.length),
        taxonomyCatalogProvider.overrideWith((ref) async => _catalogoFixo()),
        filtrosSalvosProvider.overrideWith(
          (ref) async => const <FiltroSalvo>[],
        ),
        questionRepositoryProvider.overrideWithValue(repo),
        studyAiRepositoryProvider.overrideWithValue(aiRepo),
        cadernoRepositoryProvider.overrideWithValue(cadernoRepo),
      ],
    );
    addTearDown(container.dispose);

    late GoRouter router;
    router = GoRouter(
      initialLocation: '/questoes',
      routes: [
        GoRoute(
          path: '/questoes',
          builder: (context, state) => const QuestoesScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => Scaffold(
            body: Center(
              child: TextButton(
                key: const Key('voltar-para-questoes'),
                onPressed: () => router.go('/questoes'),
                child: const Text('Voltar às questões'),
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Questão 1 de 10'), findsOneWidget);

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byTooltip('Próxima questão'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Questão 6 de 10'), findsOneWidget);

    router.go('/home');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('voltar-para-questoes')));
    await tester.pumpAndSettle();

    expect(find.text('Questão 6 de 10'), findsOneWidget);
    expect(find.text('Enunciado da questão 6'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('contador mostra o total correspondente aos filtros ativos', (
    tester,
  ) async {
    final paginaFiltrada = PaginaQuestoes(
      questoes: [_questaoFixa()],
      total: 13,
      pagina: 1,
      itensPorPagina: 10,
      statusRespostas: const {1730: null},
    );
    await render(tester, const Size(390, 844), pagina: paginaFiltrada);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(QuestoesScreen)),
    );
    container
        .read(questoesFiltrosProvider.notifier)
        .atualizar(const QuestaoFiltros(idsMaterias: [1]));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Foram encontradas 13 questões para o seu filtro.',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.textContaining('3507', findRichText: true), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('questões celular tema escuro', (tester) async {
    await render(tester, const Size(390, 844), brightness: Brightness.dark);
    expect(tester.takeException(), isNull);
    expect(find.text('Questão #1730'), findsOneWidget);
    expect(find.text('Explicação Passo a Passo'), findsNothing);
  });

  testWidgets('questões celular compacto', (tester) async {
    await render(tester, const Size(320, 568));
    expect(tester.takeException(), isNull);
    expect(find.text('Filtros de Busca Avançados'), findsOneWidget);
  });

  testWidgets('questões tablet retrato', (tester) async {
    await render(tester, const Size(800, 1280));
    expect(tester.takeException(), isNull);
    expect(find.text('Questão #1730'), findsOneWidget);
  });

  testWidgets('questões tablet paisagem', (tester) async {
    await render(tester, const Size(1280, 800));
    expect(tester.takeException(), isNull);
    expect(find.text('Questão #1730'), findsOneWidget);
  });

  testWidgets('caneta, marca-texto e borracha anotam sobre a questão', (
    tester,
  ) async {
    await render(tester, const Size(390, 844));
    final toolbarSize = tester.getSize(
      find.byKey(const Key('questoes-ferramentas-anotacao')),
    );
    expect(toolbarSize.width, lessThan(160));
    const penKey = Key('questoes-ferramenta-caneta');
    const highlighterKey = Key('questoes-ferramenta-marca-texto');
    const eraserKey = Key('questoes-ferramenta-borracha');
    const surfaceKey = ValueKey('questao-annotation-surface-1730');

    for (final key in [penKey, highlighterKey, eraserKey]) {
      expect(find.byKey(key), findsOneWidget);
    }

    await tester.ensureVisible(find.byKey(penKey));
    await tester.tap(find.byKey(penKey));
    await tester.pumpAndSettle();
    expect(find.textContaining('Caneta ativa.'), findsOneWidget);

    Future<void> desenharNaQuestao() async {
      final surface = find.byKey(surfaceKey);
      await tester.ensureVisible(surface);
      final rect = tester.getRect(surface);
      await tester.dragFrom(
        Offset(rect.left + 18, rect.top + 22),
        const Offset(0, 72),
      );
      await tester.pumpAndSettle();
    }

    await desenharNaQuestao();
    expect(
      find.byKey(const ValueKey('questao-anotacao-tracos-1')),
      findsOneWidget,
    );
    await tester.ensureVisible(find.byKey(highlighterKey));
    await tester.tap(find.byKey(highlighterKey));
    await tester.pumpAndSettle();
    expect(find.textContaining('Marca-texto ativa.'), findsOneWidget);
    await desenharNaQuestao();
    expect(
      find.byKey(const ValueKey('questao-anotacao-tracos-2')),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byKey(eraserKey));
    await tester.tap(find.byKey(eraserKey));
    await tester.pumpAndSettle();
    expect(find.textContaining('Borracha ativa.'), findsOneWidget);
    final surface = find.byKey(surfaceKey);
    await tester.ensureVisible(surface);
    final rect = tester.getRect(surface);
    final eraserGesture = await tester.startGesture(
      Offset(rect.left + 18, rect.top + 22),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('questao-anotacao-tracos-0')),
      findsOneWidget,
    );
    await eraserGesture.moveBy(const Offset(0, 72));
    await tester.pump();
    await eraserGesture.up();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(eraserKey));
    await tester.tap(find.byKey(eraserKey));
    await tester.pumpAndSettle();
    expect(find.textContaining('ativa. Toque na ferramenta'), findsNothing);

    await tester.ensureVisible(find.text('SFTP.'));
    await tester.tap(find.text('SFTP.'));
    await tester.pumpAndSettle();
    final responder = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Responder'),
    );
    expect(responder.onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'tesoura risca e restaura alternativas sem selecionar a resposta',
    (tester) async {
      await render(tester, const Size(390, 844));
      const tesoura = ValueKey('alternativa-tesoura-A');
      final alternativa = find.text('HTTP.');

      await tester.ensureVisible(find.byKey(tesoura));
      await tester.tap(find.byKey(tesoura));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(alternativa).style?.decoration,
        TextDecoration.lineThrough,
      );
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Responder'),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(alternativa);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Responder'),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.byKey(tesoura));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(alternativa).style?.decoration,
        isNot(TextDecoration.lineThrough),
      );
      await tester.tap(alternativa);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Responder'),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('comentários mostram o comentário do professor fixado primeiro', (
    tester,
  ) async {
    const comment = ComentarioPublico(
      id: 'com-1',
      idQuestao: 1730,
      nomeUsuario: 'Ana',
      texto: 'Excelente complemento da comunidade.',
    );
    when(() => repo.comentarios(idQuestao: 1730, pagina: 1)).thenAnswer(
      (_) async => const ComentariosPagina(
        comentarios: [comment],
        pagina: 1,
        temMais: false,
      ),
    );

    await render(tester, const Size(390, 844));
    await tester.ensureVisible(find.text('Comentários'));
    await tester.tap(find.text('Comentários'));
    await tester.pumpAndSettle();

    expect(find.text('Discussão da Comunidade'), findsOneWidget);
    expect(find.text('Comentário do Professor'), findsOneWidget);
    expect(find.text('FIXADO'), findsOneWidget);
    expect(
      find.textContaining('O SFTP utiliza', findRichText: true),
      findsOneWidget,
    );
    final teacherTop = tester
        .getTopLeft(find.byKey(const Key('comentario-professor-fixado')))
        .dy;
    final communityTop = tester
        .getTopLeft(find.byKey(const ValueKey('comentario-comunidade-com-1')))
        .dy;
    expect(teacherTop, lessThan(communityTop));
    expect(tester.takeException(), isNull);
  });

  testWidgets('paginação permite ir diretamente para outra página', (
    tester,
  ) async {
    await render(tester, const Size(390, 844));
    await tester.ensureVisible(
      find.byKey(const Key('questoes-ir-para-pagina')),
    );
    await tester.tap(find.byKey(const Key('questoes-ir-para-pagina')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('questoes-ir-para-pagina-dialog')),
      findsOneWidget,
    );
    expect(find.text('Digite um número entre 1 e 351.'), findsOneWidget);
    final input = find.byKey(const Key('questoes-ir-para-pagina-input'));
    await tester.enterText(input, '999');
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('questoes-ir-para-pagina-confirmar')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Informe uma página de 1 a 351.'), findsOneWidget);

    await tester.enterText(input, '12');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('questoes-ir-para-pagina-confirmar')),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(QuestoesScreen)),
    );
    expect(container.read(questoesFiltrosProvider).pagina, 12);
    expect(find.text('Página 12 de 351'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('seletor de página não estoura no celular compacto', (
    tester,
  ) async {
    await render(tester, const Size(320, 568));
    final seletor = find.byKey(const Key('questoes-ir-para-pagina'));
    await tester.ensureVisible(seletor);
    await tester.tap(seletor);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('questoes-ir-para-pagina-dialog')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtros avançados expandem os campos', (tester) async {
    await render(tester, const Size(390, 844));
    await tester.tap(find.text('Filtros de Busca Avançados'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('MATÉRIAS'), findsOneWidget);
    expect(find.text('ASSUNTOS'), findsOneWidget);
    expect(find.text('BANCA'), findsOneWidget);
    expect(find.text('ÓRGÃO E CARGO'), findsOneWidget);
    expect(find.text('ID DA QUESTÃO'), findsOneWidget);
    expect(find.text('MODALIDADE'), findsOneWidget);
    expect(find.text('STATUS'), findsOneWidget);
    expect(find.text('ESCOLARIDADE'), findsOneWidget);
    expect(find.text('ANO'), findsOneWidget);
    expect(find.text('Aplicar filtros'), findsOneWidget);
  });

  testWidgets('filtros avançados aplicam todos os parâmetros', (tester) async {
    await render(tester, const Size(390, 844));

    await tester.tap(find.text('Filtros de Busca Avançados'));
    await tester.pumpAndSettle();

    // Matérias (a seção já abre expandida) e assuntos dependentes.
    await tester.tap(find.text('Língua Portuguesa'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('ASSUNTOS'));
    await tester.tap(find.text('ASSUNTOS'));
    await tester.pumpAndSettle();
    expect(find.text('Interpretação de Texto'), findsOneWidget);
    expect(find.text('Ideia principal'), findsOneWidget);

    await tester.tap(find.text('Interpretação de Texto'));
    await tester.pumpAndSettle();

    // Banca.
    await tester.ensureVisible(find.text('BANCA'));
    await tester.tap(find.text('BANCA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cespe'));
    await tester.pumpAndSettle();

    // Órgão e cargo (selecionar o órgão marca os cargos).
    await tester.ensureVisible(find.text('ÓRGÃO E CARGO'));
    await tester.tap(find.text('ÓRGÃO E CARGO'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Polícia Civil'));
    await tester.pumpAndSettle();

    // ID da questão.
    await tester.ensureVisible(find.text('ID DA QUESTÃO'));
    await tester.tap(find.text('ID DA QUESTÃO'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('filtro-id-questao')), '1730');
    await tester.pumpAndSettle();

    // Modalidade.
    await tester.ensureVisible(find.text('MODALIDADE'));
    await tester.tap(find.text('MODALIDADE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Múltipla Escolha'));
    await tester.pumpAndSettle();

    // Status.
    await tester.ensureVisible(find.text('STATUS'));
    await tester.tap(find.text('STATUS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todas as questões'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Questões que acertei').last);
    await tester.pumpAndSettle();

    // Escolaridade.
    await tester.ensureVisible(find.text('ESCOLARIDADE'));
    await tester.tap(find.text('ESCOLARIDADE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nível Superior').last);
    await tester.pumpAndSettle();

    // Ano.
    await tester.ensureVisible(find.text('ANO'));
    await tester.tap(find.text('ANO'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2025'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('filtro-aplicar')));
    await tester.tap(find.byKey(const Key('filtro-aplicar')));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(QuestoesScreen)),
      listen: false,
    );
    final filtros = container.read(questoesFiltrosProvider);

    expect(filtros.idsMaterias, [2]);
    expect(filtros.idsTopicos, [10]);
    expect(filtros.idsSubtopicos, [100]);
    expect(filtros.idsBancas, [2]);
    expect(filtros.idsOrgaos, [1]);
    expect(filtros.idsCargos, [11]);
    expect(filtros.idQuestao, 1730);
    expect(filtros.tiposQuestao, ['multipla_escolha']);
    expect(filtros.status, StatusQuestao.acertos);
    expect(filtros.idNivel, 1);
    expect(filtros.anos, [2025]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('busca de matérias ignora acentos e filtra a lista', (
    tester,
  ) async {
    await render(tester, const Size(390, 844));
    await tester.tap(find.text('Filtros de Busca Avançados'));
    await tester.pumpAndSettle();

    expect(find.text('Língua Portuguesa'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('filtro-busca-materias')),
      'lingua',
    );
    await tester.pumpAndSettle();
    expect(find.text('Língua Portuguesa'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('filtro-busca-materias')),
      'informatica',
    );
    await tester.pumpAndSettle();
    expect(find.text('Língua Portuguesa'), findsNothing);

    await tester.enterText(find.byKey(const Key('filtro-busca-materias')), '');
    await tester.pumpAndSettle();
    expect(find.text('Língua Portuguesa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('limpar tudo sincroniza o ID e as buscas do painel', (
    tester,
  ) async {
    await render(tester, const Size(390, 844));
    await tester.tap(find.text('Filtros de Busca Avançados'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('ID DA QUESTÃO'));
    await tester.tap(find.text('ID DA QUESTÃO'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('filtro-id-questao')), '1730');
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('filtro-busca-materias')),
      'lingua',
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('filtro-limpar')));
    await tester.tap(find.byKey(const Key('filtro-limpar')));
    await tester.pumpAndSettle();

    final campoId = tester.widget<TextField>(
      find.byKey(const Key('filtro-id-questao')),
    );
    final campoBusca = tester.widget<TextField>(
      find.byKey(const Key('filtro-busca-materias')),
    );
    expect(campoId.controller?.text, isEmpty);
    expect(campoBusca.controller?.text, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtros avançados em tablet usam duas colunas sem estourar', (
    tester,
  ) async {
    await render(tester, const Size(800, 1280));
    await tester.tap(find.text('Filtros de Busca Avançados'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('MATÉRIAS'), findsOneWidget);
    expect(find.text('ASSUNTOS'), findsOneWidget);
    expect(find.text('BANCA'), findsOneWidget);
    expect(find.text('ÓRGÃO E CARGO'), findsOneWidget);
    expect(find.text('ID DA QUESTÃO'), findsOneWidget);
    expect(find.text('MODALIDADE'), findsOneWidget);
    expect(find.text('STATUS'), findsOneWidget);
    expect(find.text('ESCOLARIDADE'), findsOneWidget);
    expect(find.text('ANO'), findsOneWidget);
  });

  testWidgets('responder mostra o feedback e o gabarito', (tester) async {
    when(() => repo.responder(idUsuario: 50, idQuestao: 1730, letra: 'E'))
        .thenAnswer(
          (_) async => const RespostaQuestaoResultado(
            correta: true,
            letraCorreta: 'E',
            comentario: 'O SFTP usa SSH para proteger a transferência.',
          ),
        );

    await render(tester, const Size(390, 844));

    await tester.ensureVisible(find.text('SFTP.'));
    await tester.tap(find.text('SFTP.'));
    await tester.pump();

    await tester.ensureVisible(find.text('Responder'));
    await tester.tap(find.text('Responder'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Respondida'), findsOneWidget);
    expect(
      find.textContaining('Resposta correta!', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Gabarito: E.', findRichText: true),
      findsOneWidget,
    );
    // Responder não deve abrir a resolução sozinho: só o botão "IA Explica".
    expect(find.text('Explicação Passo a Passo'), findsNothing);
  });

  testWidgets('menu Salvar oferece cadernos, resumo e flashcard', (
    tester,
  ) async {
    await render(tester, const Size(390, 844));

    final saveMenu = find.byKey(const Key('questao-menu-salvar'));
    await tester.ensureVisible(saveMenu);
    await tester.tap(saveMenu);
    await tester.pumpAndSettle();

    expect(find.text('ORGANIZAÇÃO'), findsOneWidget);
    expect(find.text('Meus Cadernos'), findsOneWidget);
    expect(find.text('ESTUDO COM IA'), findsOneWidget);
    expect(find.text('Gerar Resumo (IA)'), findsOneWidget);
    expect(find.text('Criar Flashcard (IA)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Meus Cadernos salva a questão no caderno escolhido', (
    tester,
  ) async {
    when(
      () => cadernoRepo.salvarQuestao(
        idCaderno: 'caderno-1',
        idUsuario: 50,
        idQuestao: 1730,
      ),
    ).thenAnswer((_) async {});

    await render(tester, const Size(390, 844));
    await tester.ensureVisible(find.byKey(const Key('questao-menu-salvar')));
    await tester.tap(find.byKey(const Key('questao-menu-salvar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('questao-menu-meus-cadernos')));
    await tester.pumpAndSettle();

    expect(find.text('Salvar em um caderno'), findsOneWidget);
    await tester.tap(find.text('Direito Constitucional'));
    await tester.pumpAndSettle();

    verify(
      () => cadernoRepo.salvarQuestao(
        idCaderno: 'caderno-1',
        idUsuario: 50,
        idQuestao: 1730,
      ),
    ).called(1);
    expect(find.text('Questão salva no caderno.'), findsOneWidget);
  });

  testWidgets('Gerar Resumo e Criar Flashcard usam a geração de estudo', (
    tester,
  ) async {
    when(
      () => aiRepo.gerarEstudo(
        idQuestao: 1730,
        idUsuario: 50,
        tipo: StudyContentType.resumo,
      ),
    ).thenAnswer(
      (_) async => const StudyGenerationResult(tipo: StudyContentType.resumo),
    );
    when(
      () => aiRepo.gerarEstudo(
        idQuestao: 1730,
        idUsuario: 50,
        tipo: StudyContentType.flashcard,
      ),
    ).thenAnswer(
      (_) async =>
          const StudyGenerationResult(tipo: StudyContentType.flashcard),
    );

    await render(tester, const Size(390, 844));
    await tester.ensureVisible(find.byKey(const Key('questao-menu-salvar')));
    await tester.tap(find.byKey(const Key('questao-menu-salvar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('questao-menu-gerar-resumo')));
    await tester.pumpAndSettle();

    expect(find.text('Resumo Adicionado!'), findsOneWidget);
    await tester.tap(find.byKey(const Key('questao-estudo-continuar')));
    await tester.pumpAndSettle();
    verify(
      () => aiRepo.gerarEstudo(
        idQuestao: 1730,
        idUsuario: 50,
        tipo: StudyContentType.resumo,
      ),
    ).called(1);

    await tester.ensureVisible(find.byKey(const Key('questao-menu-salvar')));
    await tester.tap(find.byKey(const Key('questao-menu-salvar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('questao-menu-criar-flashcard')));
    await tester.pumpAndSettle();

    expect(find.text('Flashcard Criado!'), findsOneWidget);
    await tester.tap(find.byKey(const Key('questao-estudo-continuar')));
    await tester.pumpAndSettle();
    verify(
      () => aiRepo.gerarEstudo(
        idQuestao: 1730,
        idUsuario: 50,
        tipo: StudyContentType.flashcard,
      ),
    ).called(1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reportar exige motivo e envia descrição opcional', (
    tester,
  ) async {
    const descricao = 'O gabarito precisa ser atualizado.';
    when(
      () => repo.enviarFeedback(
        idQuestao: 1730,
        tipoErro: 'Questão Desatualizada',
        descricao: descricao,
      ),
    ).thenAnswer((_) async {});

    await render(tester, const Size(390, 844));
    await tester.ensureVisible(find.text('Reportar'));
    await tester.tap(find.text('Reportar'));
    await tester.pumpAndSettle();

    expect(find.text('Reportar Erro na Questão'), findsOneWidget);
    expect(find.text('QUAL É O PROBLEMA COM A QUESTÃO?'), findsOneWidget);
    expect(find.text('DESCREVA O ERRO (OPCIONAL)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('questao-report-enviar')));
    await tester.pumpAndSettle();
    expect(find.text('Selecione o problema encontrado.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('questao-report-tipo')));
    await tester.pumpAndSettle();
    for (final motivo in [
      'Gabarito Errado',
      'Questão Desatualizada',
      'Erro de Digitação/Formatação',
      'Falta de Alternativa Correta',
      'Outro',
    ]) {
      expect(find.text(motivo), findsOneWidget);
    }
    await tester.tap(find.text('Questão Desatualizada').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('questao-report-descricao')),
      descricao,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('questao-report-enviar')));
    await tester.pumpAndSettle();

    verify(
      () => repo.enviarFeedback(
        idQuestao: 1730,
        tipoErro: 'Questão Desatualizada',
        descricao: descricao,
      ),
    ).called(1);
    expect(find.text('Obrigado! Sua denúncia foi registrada.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resolução só aparece ao tocar em IA Explica', (tester) async {
    when(() => aiRepo.explicacao(idQuestao: 1730, idUsuario: 50))
        .thenThrow(AppException('IA não configurada.'));

    await render(tester, const Size(390, 844));

    expect(find.text('Explicação Passo a Passo'), findsNothing);
    expect(
      find.textContaining('O SFTP utiliza', findRichText: true),
      findsNothing,
    );

    await tester.ensureVisible(find.text('IA Explica'));
    await tester.tap(find.text('IA Explica'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Explicação Passo a Passo'), findsOneWidget);
    expect(find.text('🧠 Resolução Comentada'), findsOneWidget);
    expect(
      find.textContaining('O SFTP utiliza', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('reporte da explicação exige motivo e aceita relato vazio', (
    tester,
  ) async {
    when(() => aiRepo.explicacao(idQuestao: 1730, idUsuario: 50))
        .thenAnswer((_) async => 'Explicação de teste para a questão.');
    when(
      () => aiRepo.enviarFeedback(
        idQuestao: 1730,
        tipo: 'explicacao',
        motivo: 'conteudo_incorreto',
        relato: '',
      ),
    ).thenAnswer((_) async {});

    await render(tester, const Size(390, 844));
    await tester.ensureVisible(find.text('IA Explica'));
    await tester.tap(find.text('IA Explica'));
    await tester.pumpAndSettle();

    final reportButton = find.byTooltip('Reportar explicação');
    await tester.ensureVisible(reportButton);
    await tester.tap(reportButton);
    await tester.pumpAndSettle();

    expect(find.text('Reportar problema nesta explicação'), findsOneWidget);
    expect(
      find.byKey(const Key('ia-explicacao-feedback-relato')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('ia-explicacao-feedback-enviar')));
    await tester.pumpAndSettle();
    expect(find.text('Selecione um motivo.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ia-explicacao-feedback-motivo')));
    await tester.pumpAndSettle();
    for (final reason in [
      'Conteúdo incorreto',
      'Citação de lei errada ou desatualizada',
      'Conteúdo desatualizado',
      'Problema de formatação',
      'Outro',
    ]) {
      expect(find.text(reason), findsOneWidget);
    }
    await tester.tap(find.text('Conteúdo incorreto').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ia-explicacao-feedback-enviar')));
    await tester.pumpAndSettle();

    verify(
      () => aiRepo.enviarFeedback(
        idQuestao: 1730,
        tipo: 'explicacao',
        motivo: 'conteudo_incorreto',
        relato: '',
      ),
    ).called(1);
    expect(
      find.text('Obrigado! Vamos analisar e corrigir o conteúdo.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reporte da explicação envia a descrição opcional', (
    tester,
  ) async {
    const relato = 'A explicação cita uma regra que não se aplica.';
    when(() => aiRepo.explicacao(idQuestao: 1730, idUsuario: 50))
        .thenAnswer((_) async => 'Explicação de teste para a questão.');
    when(
      () => aiRepo.enviarFeedback(
        idQuestao: 1730,
        tipo: 'explicacao',
        motivo: 'citacao_legal',
        relato: relato,
      ),
    ).thenAnswer((_) async {});

    await render(tester, const Size(390, 844));
    await tester.ensureVisible(find.text('IA Explica'));
    await tester.tap(find.text('IA Explica'));
    await tester.pumpAndSettle();
    final reportButton = find.byTooltip('Reportar explicação');
    await tester.ensureVisible(reportButton);
    await tester.tap(reportButton);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ia-explicacao-feedback-motivo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Citação de lei errada ou desatualizada').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('ia-explicacao-feedback-relato')),
      relato,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ia-explicacao-feedback-enviar')));
    await tester.pumpAndSettle();

    verify(
      () => aiRepo.enviarFeedback(
        idQuestao: 1730,
        tipo: 'explicacao',
        motivo: 'citacao_legal',
        relato: relato,
      ),
    ).called(1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explicação da IA renderiza o Markdown sem asteriscos', (
    tester,
  ) async {
    when(() => aiRepo.explicacao(idQuestao: 1730, idUsuario: 50)).thenAnswer(
      (_) async =>
          '## Tema da Questão\n\n'
          '**Assunto**: **Protocolos** de transferência segura.\n\n'
          '## Resolução Comentada\n\n'
          'A alternativa **E** está correta.',
    );

    await render(tester, const Size(390, 844));

    await tester.ensureVisible(find.text('IA Explica'));
    await tester.tap(find.text('IA Explica'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('questao-ia-conteudo-unico')), findsOneWidget);
    expect(find.text('Tema da Questão'), findsOneWidget);
    expect(find.textContaining('**', findRichText: true), findsNothing);
    expect(
      find.textContaining('Protocolos', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('formato sem Markdown também fica em um único bloco', (
    tester,
  ) async {
    when(() => aiRepo.explicacao(idQuestao: 1730, idUsuario: 50)).thenAnswer(
      (_) async =>
          '📌 Tema da Questão\n'
          '• Assunto: Redes seguras.\n\n'
          '🧠 Resolução Comentada\n'
          'A alternativa correta usa **SFTP**.\n\n'
          '✅ Alternativa Correta\n'
          'Letra E, conforme o enunciado.',
    );

    await render(tester, const Size(390, 844));
    await tester.ensureVisible(find.text('IA Explica'));
    await tester.tap(find.text('IA Explica'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('questao-ia-conteudo-unico')), findsOneWidget);
    expect(find.text('📌 Tema da Questão'), findsOneWidget);
    expect(find.text('🧠 Resolução Comentada'), findsOneWidget);
    expect(find.text('✅ Alternativa Correta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('texto de apoio começa expandido e pode ser minimizado', (
    tester,
  ) async {
    await render(tester, const Size(390, 844), pagina: _paginaComTextoApoio());

    expect(tester.takeException(), isNull);
    expect(find.text('TEXTO DE APOIO'), findsOneWidget);
    expect(
      find.text(
        'O atleta negro brasileiro que enfrentou o nazismo nas Olimpíadas '
        'de 1936',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('A poucos dias da abertura', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Minimizar'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('texto-apoio-toggle')));
    await tester.tap(find.byKey(const Key('texto-apoio-toggle')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Expandir'), findsOneWidget);
    expect(find.text('Minimizar'), findsNothing);
    expect(
      find.textContaining('A poucos dias da abertura', findRichText: true),
      findsNothing,
    );
    expect(
      find.textContaining('O atleta negro brasileiro', findRichText: true),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('texto-apoio-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('Minimizar'), findsOneWidget);
    expect(
      find.textContaining('A poucos dias da abertura', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('texto de apoio volta expandido ao trocar de questão', (
    tester,
  ) async {
    await render(tester, const Size(390, 844), pagina: _paginaComTextoApoio());

    await tester.ensureVisible(find.byKey(const Key('texto-apoio-toggle')));
    await tester.tap(find.byKey(const Key('texto-apoio-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Expandir'), findsOneWidget);

    // Navega para a próxima questão da mesma página.
    await tester.ensureVisible(find.byIcon(Icons.chevron_right_rounded));
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Questão #82'), findsOneWidget);
    expect(find.text('TEXTO DE APOIO'), findsOneWidget);
    expect(find.text('Minimizar'), findsOneWidget);
  });
}

DashboardResumo _resumoFixo() {
  return const DashboardResumo(
    totalResolvidas: 40,
    acertos: 22,
    taxaAcerto: 55,
    ofensiva: 0,
    hojeResolvidas: 0,
    evolucaoPercentual: -60,
    nivelPerformance: 'Desempenho Regular',
    ultimos30Dias: [],
  );
}

PaginaQuestoes _paginaFixa() {
  return PaginaQuestoes(
    questoes: [_questaoFixa()],
    total: 3507,
    pagina: 1,
    itensPorPagina: 10,
    statusRespostas: const {1730: null},
  );
}

Questao _questaoFixa() {
  return const Questao(
    id: 1730,
    enunciado:
        'Em um ambiente de administração de servidores, um protocolo é '
        'escolhido para substituir um método legado de envio de arquivos '
        'devido à necessidade de garantir autenticação, integridade e '
        'confidencialidade por meio de um único canal seguro sobre TCP. '
        'Esse protocolo é conhecido como:',
    status: 'publicada',
    respostaCorreta: 'E',
    nomeBanca: 'Idecan',
    nomeOrgao: '(PCSC) Polícia Civil de Santa Catarina',
    nomeCargo: 'Escrivão',
    ano: 2025,
    descritivoNivel: 'Nível Superior',
    nomeMateria: 'Noções de Informática',
    nomeTopico: 'Redes de Computadores',
    comentarioGabarito:
        'O SFTP utiliza o SSH para garantir autenticação, integridade e '
        'confidencialidade sobre TCP.',
    totalComentarios: 0,
    alternativas: [
      Alternativa(
        id: 1,
        idQuestao: 1730,
        letra: 'A',
        texto: 'HTTP.',
        isCorrect: false,
      ),
      Alternativa(
        id: 2,
        idQuestao: 1730,
        letra: 'B',
        texto: 'FTP.',
        isCorrect: false,
      ),
      Alternativa(
        id: 3,
        idQuestao: 1730,
        letra: 'C',
        texto: 'SNMP.',
        isCorrect: false,
      ),
      Alternativa(
        id: 4,
        idQuestao: 1730,
        letra: 'D',
        texto: 'DNS.',
        isCorrect: false,
      ),
      Alternativa(
        id: 5,
        idQuestao: 1730,
        letra: 'E',
        texto: 'SFTP.',
        isCorrect: true,
      ),
    ],
  );
}

PaginaQuestoes _paginaComTextoApoio() {
  return PaginaQuestoes(
    questoes: [_questaoComTextoApoio(), _questaoComTextoApoio82()],
    total: 2,
    pagina: 1,
    itensPorPagina: 10,
    statusRespostas: const {81: null, 82: null},
  );
}

Questao _questaoComTextoApoio() {
  return const Questao(
    id: 81,
    enunciado:
        'No último parágrafo do texto, o enunciador conclui indicando que:',
    textoBase:
        'A poucos dias da abertura dos Jogos Olímpicos de Paris, [...] a '
        'competição de 1936 tem muito a nos ensinar.',
    tituloReferencia:
        'O atleta negro brasileiro que enfrentou o nazismo nas Olimpíadas '
        'de 1936',
    respostaCorreta: 'A',
    alternativas: [
      Alternativa(
        id: 1,
        idQuestao: 81,
        letra: 'A',
        texto: 'a negação da memória é uma política deliberada.',
        isCorrect: true,
      ),
      Alternativa(
        id: 2,
        idQuestao: 81,
        letra: 'B',
        texto: 'a sistematização de uma política de apagamento.',
        isCorrect: false,
      ),
    ],
  );
}

Questao _questaoComTextoApoio82() {
  return const Questao(
    id: 82,
    enunciado: 'Segunda questão com texto de apoio.',
    textoBase: 'Texto de apoio da segunda questão.',
    respostaCorreta: 'A',
    alternativas: [
      Alternativa(
        id: 3,
        idQuestao: 82,
        letra: 'A',
        texto: 'Alternativa correta.',
        isCorrect: true,
      ),
    ],
  );
}

TaxonomyCatalog _catalogoFixo() {
  return const TaxonomyCatalog(
    materias: [
      Materia(id: 1, nome: 'Noções de Informática'),
      Materia(id: 2, nome: 'Língua Portuguesa'),
    ],
    topicos: [Topico(id: 10, idMateria: 2, nome: 'Interpretação de Texto')],
    subtopicos: [Subtopico(id: 100, idTopico: 10, nome: 'Ideia principal')],
    bancas: [
      Banca(id: 1, nome: 'Idecan'),
      Banca(id: 2, nome: 'Cespe'),
    ],
    orgaos: [
      Orgao(
        id: 1,
        nome: 'Polícia Civil',
        cargos: [Cargo(id: 11, nome: 'Escrivão', idOrgao: 1)],
      ),
    ],
    niveis: [NivelEscolaridade(id: 1, nome: 'Nível Superior')],
  );
}
