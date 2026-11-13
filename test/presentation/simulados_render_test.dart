import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gabaritei_app/core/providers.dart';
import 'package:gabaritei_app/models/question.dart';
import 'package:gabaritei_app/models/simulado.dart';
import 'package:gabaritei_app/models/stats.dart';
import 'package:gabaritei_app/models/taxonomy.dart';
import 'package:gabaritei_app/models/user_profile.dart';
import 'package:gabaritei_app/presentation/home/simulado_fazer_screen.dart';
import 'package:gabaritei_app/presentation/home/simulado_ranking_screen.dart';
import 'package:gabaritei_app/presentation/home/simulado_resultado_screen.dart';
import 'package:gabaritei_app/presentation/home/simulados_screen.dart';
import 'package:gabaritei_app/repositories/simulado_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockSimuladoRepository extends Mock implements SimuladoRepository {}

void main() {
  late _MockSimuladoRepository repo;

  const simulado = Simulado(id: 'sim-1', titulo: 'Prova de Direito');
  const questao = Questao(
    id: 101,
    enunciado: 'Qual alternativa está correta?',
    alternativas: [
      Alternativa(
        id: 1,
        idQuestao: 101,
        letra: 'A',
        texto: 'Alternativa A',
        isCorrect: false,
      ),
      Alternativa(
        id: 2,
        idQuestao: 101,
        letra: 'B',
        texto: 'Alternativa B',
        isCorrect: true,
      ),
    ],
  );
  const sessao = SimuladoComQuestoes(simulado: simulado, questoes: [questao]);
  const resultado = SimuladoResultado(
    nota: 10,
    acertos: 1,
    total: 1,
    detalhes: [],
    ranking: [],
  );
  const catalogo = TaxonomyCatalog(
    materias: [Materia(id: 1, nome: 'Português')],
    topicos: [Topico(id: 11, idMateria: 1, nome: 'Interpretação')],
    bancas: [Banca(id: 2, nome: 'FGV')],
    orgaos: [
      Orgao(
        id: 3,
        nome: 'Polícia Federal',
        cargos: [Cargo(id: 4, idOrgao: 3, nome: 'Agente')],
      ),
    ],
    niveis: [NivelEscolaridade(id: 7, nome: 'Superior')],
  );

  setUpAll(() {
    registerFallbackValue(const CotaSimulado(quantidade: 1));
    registerFallbackValue(<CotaSimulado>[]);
    registerFallbackValue(const FiltrosSimulado());
    registerFallbackValue(<int, String?>{});
  });

  setUp(() {
    repo = _MockSimuladoRepository();
  });

  Widget wrap(
    Widget child, {
    bool dark = false,
    SimuladoListagem listagem = const SimuladoListagem(),
    bool simuladosComErro = false,
    TaxonomyCatalog taxonomia = const TaxonomyCatalog(),
    SimuladoComQuestoes? sessao,
    SimuladoRankingDados? ranking,
    bool rankingComErro = false,
    GoRouter? router,
  }) {
    final overrides = [
      perfilAtualProvider.overrideWith(
        (ref) async => const UserProfile(id: 50, username: 'thierry_n1'),
      ),
      painelProvider.overrideWith((ref) async => _resumoFixo()),
      simuladoRepositoryProvider.overrideWithValue(repo),
      simuladosProvider.overrideWith((ref) async {
        if (simuladosComErro) throw StateError('falha de teste');
        return listagem;
      }),
      taxonomyCatalogProvider.overrideWith((ref) async => taxonomia),
      simuladoSessaoProvider.overrideWith(
        (ref, id) async => sessao ?? _sessaoVazia,
      ),
      simuladoRankingProvider.overrideWith((ref, id) async {
        if (rankingComErro) throw StateError('falha de teste');
        return ranking ??
            const SimuladoRankingDados(simulado: simulado, ranking: []);
      }),
    ];
    return ProviderScope(
      overrides: overrides,
      child: router == null
          ? MaterialApp(
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              home: child,
            )
          : MaterialApp.router(
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              routerConfig: router,
            ),
    );
  }

  Future<void> render(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(390, 844),
    bool dark = false,
    SimuladoListagem listagem = const SimuladoListagem(),
    bool simuladosComErro = false,
    TaxonomyCatalog taxonomia = const TaxonomyCatalog(),
    SimuladoComQuestoes? sessao,
    SimuladoRankingDados? ranking,
    bool rankingComErro = false,
    GoRouter? router,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrap(
        child,
        dark: dark,
        listagem: listagem,
        simuladosComErro: simuladosComErro,
        taxonomia: taxonomia,
        sessao: sessao,
        ranking: ranking,
        rankingComErro: rankingComErro,
        router: router,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('feed vazio mantém o tema claro/escuro em celular e tablet', (
    tester,
  ) async {
    for (final (size, dark) in [
      (const Size(390, 844), false),
      (const Size(390, 844), true),
      (const Size(800, 1280), true),
      (const Size(1280, 800), false),
    ]) {
      await render(tester, const SimuladosScreen(), size: size, dark: dark);
      expect(tester.takeException(), isNull);
      expect(find.text('Central de Simulados'), findsOneWidget);
      expect(find.text('Simulados da Comunidade'), findsOneWidget);
      expect(find.text('Nenhum simulado público'), findsOneWidget);
      expect(find.text('Meus simulados'), findsOneWidget);
      expect(find.byKey(const Key('simulados-criar')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('feed separa provas públicas/privadas e expõe ações permitidas', (
    tester,
  ) async {
    final publico = Simulado(
      id: 'publico',
      titulo: 'Simulado da comunidade',
      nomeCriador: 'Maria',
      criadoEm: DateTime(2026, 11, 10),
    );
    const privado = Simulado(
      id: 'privado',
      titulo: 'Meu treino',
      ehPrivado: true,
      ehMeu: true,
    );
    await render(
      tester,
      const SimuladosScreen(),
      listagem: SimuladoListagem(publicos: [publico], privados: [privado]),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Simulado da comunidade'), findsOneWidget);
    expect(find.text('Meu treino'), findsOneWidget);
    expect(find.text('Maria'), findsOneWidget);
    expect(find.byKey(const Key('simulado-iniciar-publico')), findsOneWidget);
    expect(find.byKey(const Key('simulado-ranking-publico')), findsOneWidget);
    expect(find.byKey(const Key('simulado-pdf-publico')), findsOneWidget);
    expect(find.byKey(const Key('simulado-ranking-privado')), findsNothing);
    expect(find.byKey(const Key('simulado-excluir-privado')), findsOneWidget);
  });

  testWidgets('gerador envia todos os filtros, assuntos e cotas selecionados', (
    tester,
  ) async {
    FiltrosSimulado? filtrosEnviados;
    List<CotaSimulado>? cotasEnviadas;
    String? tituloEnviado;
    int? usuarioEnviado;
    bool? privadoEnviado;
    when(
      () => repo.gerar(
        idUsuario: any(named: 'idUsuario'),
        titulo: any(named: 'titulo'),
        cotas: any(named: 'cotas'),
        filtros: any(named: 'filtros'),
        ehPrivado: any(named: 'ehPrivado'),
      ),
    ).thenAnswer((invocation) async {
      final args = invocation.namedArguments;
      usuarioEnviado = args[#idUsuario] as int;
      tituloEnviado = args[#titulo] as String;
      cotasEnviadas = args[#cotas] as List<CotaSimulado>;
      filtrosEnviados = args[#filtros] as FiltrosSimulado;
      privadoEnviado = args[#ehPrivado] as bool;
      return const Simulado(id: 'novo', titulo: 'Treino completo');
    });

    await render(tester, const SimuladosScreen(), taxonomia: catalogo);
    await tester.tap(find.byKey(const Key('simulados-criar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('simulado-titulo')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('simulado-titulo')),
      'Treino completo',
    );

    await tester.tap(find.byKey(const Key('simulado-privacidade')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privado (só para mim)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('simulado-escolaridade')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Superior').last);
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.byKey(const Key('simulado-filtro-bancas')));
    await _tapVisible(tester, find.byKey(const Key('simulado-banca-2')));
    await _tapVisible(tester, find.byKey(const Key('simulado-filtro-orgaos')));
    await _tapVisible(tester, find.byKey(const Key('simulado-orgao-3')));
    await _tapVisible(tester, find.byKey(const Key('simulado-filtro-anos')));
    await _tapVisible(tester, find.byKey(const Key('simulado-ano-2024')));
    await _tapVisible(tester, find.byKey(const Key('simulado-filtro-tipos')));
    await _tapVisible(
      tester,
      find.byKey(const Key('simulado-tipo-certo-errado')),
    );

    await _tapVisible(tester, find.byKey(const Key('simulado-cota-materia-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Português').last);
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.byKey(const Key('simulado-cota-topicos-1')));
    await _tapVisible(tester, find.byKey(const Key('simulado-topico-1-11')));
    await tester.enterText(
      find.byKey(const Key('simulado-cota-quantidade-1')),
      '12',
    );
    await tester.tap(find.byKey(const Key('simulado-generator-submit')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(usuarioEnviado, 50);
    expect(tituloEnviado, 'Treino completo');
    expect(privadoEnviado, isTrue);
    expect(filtrosEnviados?.idNivel, 7);
    expect(filtrosEnviados?.idsBancas, [2]);
    expect(filtrosEnviados?.idsOrgaos, [3]);
    expect(filtrosEnviados?.idsCargos, [4]);
    expect(filtrosEnviados?.anos, [2024]);
    expect(filtrosEnviados?.tiposQuestao, ['certo_errado']);
    expect(cotasEnviadas, hasLength(1));
    expect(cotasEnviadas?.single.idMateria, 1);
    expect(cotasEnviadas?.single.idsTopicos, [11]);
    expect(cotasEnviadas?.single.quantidade, 12);
  });

  testWidgets('sessão marca resposta, entrega e apresenta o resultado', (
    tester,
  ) async {
    Map<int, String?>? respostasEnviadas;
    when(
      () => repo.corrigir(
        idSimulado: 'sim-1',
        idUsuario: 50,
        respostas: any(named: 'respostas'),
      ),
    ).thenAnswer((invocation) async {
      respostasEnviadas =
          invocation.namedArguments[#respostas] as Map<int, String?>;
      return resultado;
    });

    final router = GoRouter(
      initialLocation: '/simulados/fazer/sim-1',
      routes: [
        GoRoute(
          path: '/simulados',
          builder: (context, state) => const Scaffold(body: Text('Feed')),
        ),
        GoRoute(
          path: '/simulados/fazer/:id',
          builder: (context, state) =>
              SimuladoFazerScreen(idSimulado: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/simulados/resultado/:id',
          builder: (context, state) => SimuladoResultadoScreen(
            args: state.extra is SimuladoResultadoArgs
                ? state.extra! as SimuladoResultadoArgs
                : null,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await render(
      tester,
      const SizedBox.shrink(),
      router: router,
      sessao: sessao,
    );

    expect(find.text('Qual alternativa está correta?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('simulado-alternativa-101-B')));
    await tester.tap(find.byKey(const Key('simulado-entregar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('simulado-entregar-confirmar')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(respostasEnviadas, {101: 'B'});
    expect(find.byKey(const Key('simulado-resultado-nota')), findsOneWidget);
    expect(find.text('10.00'), findsOneWidget);
    expect(find.byKey(const Key('simulado-imprimir-prova')), findsOneWidget);
  });

  testWidgets('ranking exibe participantes, estado vazio e erro', (
    tester,
  ) async {
    final participantes = [
      RankingEntry(
        nomeUsuario: 'Ana',
        nota: 9.5,
        respostasCorretas: 19,
        totalQuestoes: 20,
        dataConclusao: DateTime(2026, 11, 10),
      ),
      const RankingEntry(
        nomeUsuario: 'Beto',
        nota: 6.5,
        respostasCorretas: 13,
        totalQuestoes: 20,
      ),
    ];

    await render(
      tester,
      const SimuladoRankingScreen(idSimulado: 'sim-1'),
      ranking: SimuladoRankingDados(simulado: simulado, ranking: participantes),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Ranking Global'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Beto'), findsOneWidget);
    expect(find.byKey(const Key('simulado-ranking-linha-1')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());

    await render(tester, const SimuladoRankingScreen(idSimulado: 'sim-1'));
    expect(find.byKey(const Key('simulado-ranking-vazio')), findsOneWidget);
    expect(find.textContaining('Ninguém completou'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());

    await render(
      tester,
      const SimuladoRankingScreen(idSimulado: 'sim-1'),
      rankingComErro: true,
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('simulado-ranking-erro')), findsOneWidget);
  });
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

const _sessaoVazia = SimuladoComQuestoes(
  simulado: Simulado(id: 'vazio', titulo: 'Vazio'),
  questoes: [],
);

DashboardResumo _resumoFixo() => const DashboardResumo(
  totalResolvidas: 13,
  acertos: 9,
  taxaAcerto: 69,
  ofensiva: 5,
  hojeResolvidas: 3,
  evolucaoPercentual: 12,
  nivelPerformance: 'Bom desempenho',
  ultimos30Dias: [],
);
