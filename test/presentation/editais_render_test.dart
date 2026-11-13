import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gabaritei_app/core/providers.dart';
import 'package:gabaritei_app/models/edital.dart';
import 'package:gabaritei_app/models/question.dart';
import 'package:gabaritei_app/models/stats.dart';
import 'package:gabaritei_app/models/taxonomy.dart';
import 'package:gabaritei_app/models/user_profile.dart';
import 'package:gabaritei_app/presentation/home/edital_dashboard_screen.dart';
import 'package:gabaritei_app/presentation/home/edital_estudar_screen.dart';
import 'package:gabaritei_app/presentation/home/editais_screen.dart';
import 'package:gabaritei_app/repositories/edital_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockEditalRepository extends Mock implements EditalRepository {}

void main() {
  late _MockEditalRepository repo;

  const materia = Materia(id: 1, nome: 'Direito Constitucional');
  const topico = Topico(id: 11, idMateria: 1, nome: 'Princípios fundamentais');
  const catalogo = TaxonomyCatalog(materias: [materia], topicos: [topico]);
  const questao = Questao(
    id: 101,
    enunciado: 'Qual princípio orienta a administração pública?',
    tipoQuestao: 'multipla_escolha',
    nomeMateria: 'Direito Constitucional',
    nomeTopico: 'Princípios fundamentais',
    alternativas: [
      Alternativa(
        id: 1,
        idQuestao: 101,
        letra: 'A',
        texto: 'Legalidade',
        isCorrect: true,
      ),
      Alternativa(
        id: 2,
        idQuestao: 101,
        letra: 'B',
        texto: 'Informalidade',
        isCorrect: false,
      ),
    ],
  );
  const sessao = EditalSessaoEstudo(
    idEdital: 10,
    nomeMateria: 'Direito Constitucional',
    nomeTopico: 'Princípios fundamentais',
    meta: 15,
    feitas: 0,
    idEditalMateria: 20,
    idEditalTopico: 30,
    idMateria: 1,
    idTopico: 11,
    questao: questao,
  );

  setUpAll(() {
    registerFallbackValue(
      const EditalMateriaSelecionada(idMateria: 1, idsTopicos: [11]),
    );
    registerFallbackValue(<EditalMateriaSelecionada>[]);
  });

  setUp(() {
    repo = _MockEditalRepository();
  });

  Widget wrap(
    Widget child, {
    bool dark = false,
    List<EditalCiclo> editais = const [],
    TaxonomyCatalog taxonomia = const TaxonomyCatalog(),
    EditalPainel? painel,
    EditalSessaoEstudo? sessaoEstudo,
    GoRouter? router,
  }) {
    final overrides = [
      perfilAtualProvider.overrideWith(
        (ref) async => const UserProfile(id: 50, username: 'thierry_n1'),
      ),
      painelProvider.overrideWith((ref) async => _resumoFixo()),
      editalRepositoryProvider.overrideWithValue(repo),
      editaisProvider.overrideWith((ref) async => editais),
      taxonomyCatalogProvider.overrideWith((ref) async => taxonomia),
      editalPainelProvider.overrideWith(
        (ref, id) async => painel ?? _painelVazio,
      ),
      editalSessaoProvider.overrideWith(
        (ref, id) async => sessaoEstudo ?? _sessao,
      ),
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
    List<EditalCiclo> editais = const [],
    TaxonomyCatalog taxonomia = const TaxonomyCatalog(),
    EditalPainel? painel,
    EditalSessaoEstudo? sessaoEstudo,
    GoRouter? router,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrap(
        child,
        dark: dark,
        editais: editais,
        taxonomia: taxonomia,
        painel: painel,
        sessaoEstudo: sessaoEstudo,
        router: router,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('estado vazio adapta em celular e tablet nos dois temas', (
    tester,
  ) async {
    for (final (size, dark) in [
      (const Size(390, 844), false),
      (const Size(390, 844), true),
      (const Size(800, 1280), true),
      (const Size(1280, 800), false),
    ]) {
      await render(tester, const EditaisScreen(), size: size, dark: dark);
      expect(tester.takeException(), isNull);
      expect(find.text('Edital em Questão').first, findsOneWidget);
      expect(find.text('Ver Guia do Edital'), findsOneWidget);
      expect(find.byKey(const Key('edital-criar')), findsOneWidget);
      expect(find.byKey(const Key('editais-vazio')), findsOneWidget);
      expect(find.text('Nenhum edital ativo'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('edital ativo apresenta continuação, raio-X e exclusão', (
    tester,
  ) async {
    await render(
      tester,
      const EditaisScreen(),
      editais: const [EditalCiclo(id: 10, titulo: 'Concurso PCDF')],
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Concurso PCDF'), findsOneWidget);
    expect(find.byKey(const Key('edital-continuar-10')), findsOneWidget);
    expect(find.byKey(const Key('edital-dashboard-10')), findsOneWidget);
    expect(find.byKey(const Key('edital-excluir-10')), findsOneWidget);
  });

  testWidgets('criação envia matérias e assuntos escolhidos ao repositório', (
    tester,
  ) async {
    String? tituloEnviado;
    List<EditalMateriaSelecionada>? materiasEnviadas;
    when(
      () => repo.criar(
        idUsuario: 50,
        titulo: any(named: 'titulo'),
        materias: any(named: 'materias'),
      ),
    ).thenAnswer((invocation) async {
      tituloEnviado = invocation.namedArguments[#titulo] as String;
      materiasEnviadas =
          invocation.namedArguments[#materias]
              as List<EditalMateriaSelecionada>;
      return const EditalCiclo(id: 11, titulo: 'PCDF - Agente');
    });

    await render(tester, const EditaisScreen(), taxonomia: catalogo);
    await tester.tap(find.byKey(const Key('edital-criar')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('edital-titulo')),
      'PCDF - Agente',
    );
    await _tapVisible(tester, find.byKey(const Key('edital-materia-select-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Direito Constitucional').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const PageStorageKey('edital-assuntos-0-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('edital-assunto-0-11')));
    await tester.ensureVisible(find.byKey(const Key('edital-criar-confirmar')));
    await tester.tap(find.byKey(const Key('edital-criar-confirmar')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(tituloEnviado, 'PCDF - Agente');
    expect(materiasEnviadas, hasLength(1));
    expect(materiasEnviadas!.single.idMateria, 1);
    expect(materiasEnviadas!.single.idsTopicos, [11]);
  });

  testWidgets('dashboard mostra desempenho e tópicos prioritários', (
    tester,
  ) async {
    await render(
      tester,
      const EditalDashboardScreen(idEdital: 10),
      painel: _painelCompleto,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Raio-X do Edital'), findsOneWidget);
    expect(find.text('Concurso PCDF'), findsOneWidget);
    expect(find.text('Taxa de acerto'), findsOneWidget);
    expect(find.text('Princípios fundamentais'), findsWidgets);
    expect(
      find.byKey(const Key('edital-dashboard-prioridades')),
      findsOneWidget,
    );
  });

  testWidgets('sessão corrige a questão e libera a próxima do ciclo', (
    tester,
  ) async {
    when(
      () => repo.responder(
        idEdital: 10,
        idUsuario: 50,
        idQuestao: 101,
        letra: 'A',
      ),
    ).thenAnswer(
      (_) async => const RespostaQuestaoResultado(
        correta: true,
        letraCorreta: 'A',
        comentario: 'Legalidade é um princípio expresso.',
      ),
    );

    final router = GoRouter(
      initialLocation: '/editais/estudar/10',
      routes: [
        GoRoute(
          path: '/editais',
          builder: (context, state) => const Scaffold(body: Text('Editais')),
        ),
        GoRoute(
          path: '/editais/dashboard/:id',
          builder: (context, state) => EditalDashboardScreen(
            idEdital: int.parse(state.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: '/editais/estudar/:id',
          builder: (context, state) => EditalEstudarScreen(
            idEdital: int.parse(state.pathParameters['id']!),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await render(
      tester,
      const SizedBox.shrink(),
      sessaoEstudo: sessao,
      router: router,
    );

    expect(
      find.text('Qual princípio orienta a administração pública?'),
      findsOneWidget,
    );
    final alternativa = find.byKey(const Key('edital-alternativa-101-A'));
    await tester.ensureVisible(alternativa);
    await tester.tap(alternativa);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('edital-responder')));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('edital-responder')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('edital-responder')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    verify(
      () => repo.responder(
        idEdital: 10,
        idUsuario: 50,
        idQuestao: 101,
        letra: 'A',
      ),
    ).called(1);
    expect(find.byKey(const Key('edital-feedback-resposta')), findsOneWidget);
    expect(find.text('Próxima Questão do Ciclo'), findsOneWidget);
  });
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

EditalSessaoEstudo get _sessao => const EditalSessaoEstudo(
  idEdital: 10,
  nomeMateria: 'Direito Constitucional',
  nomeTopico: 'Princípios fundamentais',
  meta: 15,
  feitas: 0,
  idEditalMateria: 20,
  idEditalTopico: 30,
  idMateria: 1,
  idTopico: 11,
  questao: questao,
);

const questao = Questao(
  id: 101,
  enunciado: 'Qual princípio orienta a administração pública?',
  tipoQuestao: 'multipla_escolha',
  nomeMateria: 'Direito Constitucional',
  nomeTopico: 'Princípios fundamentais',
  alternativas: [
    Alternativa(
      id: 1,
      idQuestao: 101,
      letra: 'A',
      texto: 'Legalidade',
      isCorrect: true,
    ),
    Alternativa(
      id: 2,
      idQuestao: 101,
      letra: 'B',
      texto: 'Informalidade',
      isCorrect: false,
    ),
  ],
);

EditalPainel get _painelVazio => const EditalPainel(
  edital: EditalCiclo(id: 10, titulo: 'Concurso PCDF'),
  materias: [],
  dashboard: EditalDashboard(
    totalResolvidas: 0,
    totalAcertos: 0,
    desempenhoGeral: 0,
    pontosAtencao: [],
    topicosPrioridade: [],
  ),
);

const _painelCompleto = EditalPainel(
  edital: EditalCiclo(id: 10, titulo: 'Concurso PCDF'),
  materias: [
    EditalMateria(
      id: 20,
      idEdital: 10,
      idMateria: 1,
      ordem: 1,
      nomeMateria: 'Direito Constitucional',
      questoesResolvidas: 3,
      questoesAcertadas: 1,
      topicos: [
        EditalTopico(
          id: 30,
          idEditalMateria: 20,
          idTopico: 11,
          nomeTopico: 'Princípios fundamentais',
          questoesResolvidas: 3,
          questoesAcertadas: 1,
        ),
      ],
    ),
  ],
  dashboard: EditalDashboard(
    totalResolvidas: 3,
    totalAcertos: 1,
    desempenhoGeral: 33,
    pontosAtencao: [
      PontoAtencaoEdital(
        materia: 'Direito Constitucional',
        topico: 'Princípios fundamentais',
        taxa: 33,
        resolvidas: 3,
        idMateria: 1,
        idTopico: 11,
        pesoAdaptativo: 80,
        metaDinamica: 27,
      ),
    ],
    topicosPrioridade: [
      TopicoPrioridade(
        id: 30,
        nome: 'Princípios fundamentais',
        idMateria: 1,
        idTopico: 11,
        taxaAcerto: 33,
        pesoAdaptativo: 80,
        metaDinamica: 27,
        nivelPrioridade: 'alta',
        badgeCor: 'danger',
      ),
    ],
  ),
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
