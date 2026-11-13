import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gabaritei_app/core/providers.dart';
import 'package:gabaritei_app/models/question.dart';
import 'package:gabaritei_app/models/stats.dart';
import 'package:gabaritei_app/models/study.dart';
import 'package:gabaritei_app/models/user_profile.dart';
import 'package:gabaritei_app/presentation/home/caderno_detail_screen.dart';
import 'package:gabaritei_app/presentation/home/cadernos_screen.dart';
import 'package:gabaritei_app/repositories/caderno_repository.dart';
import 'package:gabaritei_app/repositories/question_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockCadernoRepository extends Mock implements CadernoRepository {}

class _MockQuestionRepository extends Mock implements QuestionRepository {}

/// Garante que "Meus Cadernos" cobre o estado vazio do Stitch, a lista,
/// criação, exclusão e a tela de detalhe com as questões salvas.
void main() {
  late _MockCadernoRepository repo;
  late _MockQuestionRepository questionRepo;

  setUp(() {
    repo = _MockCadernoRepository();
    questionRepo = _MockQuestionRepository();
    when(() => repo.listar(50)).thenAnswer((_) async => const <Caderno>[]);
  });

  Widget wrap(Widget child, {bool dark = false, GoRouter? router}) {
    final overrides = [
      perfilAtualProvider.overrideWith(
        (ref) async => const UserProfile(id: 50, username: 'thierry_n1'),
      ),
      painelProvider.overrideWith((ref) async => _resumoFixo()),
      cadernoRepositoryProvider.overrideWithValue(repo),
      questionRepositoryProvider.overrideWithValue(questionRepo),
    ];

    if (router != null) {
      return ProviderScope(
        overrides: overrides,
        child: MaterialApp.router(
          theme: dark ? ThemeData.dark() : ThemeData.light(),
          routerConfig: router,
        ),
      );
    }

    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: dark ? ThemeData.dark() : ThemeData.light(),
        home: child,
      ),
    );
  }

  Future<void> render(
    WidgetTester tester,
    Size size, {
    bool dark = false,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(const CadernosScreen(), dark: dark));
    await tester.pumpAndSettle();
  }

  Future<void> renderRouter(
    WidgetTester tester,
    String initialLocation,
    Size size,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/cadernos',
          builder: (context, state) => const CadernosScreen(),
        ),
        GoRoute(
          path: '/cadernos/:id',
          builder: (context, state) =>
              CadernoDetailScreen(idCaderno: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/questoes',
          builder: (context, state) => const _QuestoesProbe(),
        ),
        GoRoute(path: '/home', builder: (context, state) => const _HomeProbe()),
      ],
    );

    await tester.pumpWidget(wrap(const SizedBox.shrink(), router: router));
    await tester.pumpAndSettle();
  }

  testWidgets('estado vazio no tema claro', (tester) async {
    await render(tester, const Size(390, 844));

    expect(tester.takeException(), isNull);
    expect(find.text('Meus Cadernos'), findsOneWidget);
    expect(
      find.text('Organize suas questões salvas em pastas personalizadas.'),
      findsOneWidget,
    );
    expect(find.text('Sua biblioteca está vazia'), findsOneWidget);
    expect(find.text('Novo Caderno'), findsOneWidget);
    expect(find.text('Buscar Questões'), findsOneWidget);
    expect(find.byKey(const Key('cadernos-vazio')), findsOneWidget);
    expect(find.textContaining('Gabaritei Questões'), findsOneWidget);
  });

  testWidgets('estado vazio no tema escuro em tablet', (tester) async {
    await render(tester, const Size(800, 1280), dark: true);

    expect(tester.takeException(), isNull);
    expect(find.text('Sua biblioteca está vazia'), findsOneWidget);
    expect(find.byKey(const Key('cadernos-vazio')), findsOneWidget);
  });

  testWidgets('lista mostra os cadernos existentes', (tester) async {
    when(() => repo.listar(50)).thenAnswer(
      (_) async => [
        Caderno(
          id: 'c1',
          idUsuario: 50,
          nome: 'Direito Constitucional',
          criadoEm: DateTime(2026, 11, 10),
        ),
        Caderno(
          id: 'c2',
          idUsuario: 50,
          nome: 'Português',
          criadoEm: DateTime(2026, 11, 9),
        ),
      ],
    );

    await render(tester, const Size(390, 844));

    expect(tester.takeException(), isNull);
    expect(find.text('2 cadernos'), findsOneWidget);
    expect(find.text('Direito Constitucional'), findsOneWidget);
    expect(find.text('Português'), findsOneWidget);
    expect(find.text('Criado em 10/11/2026'), findsOneWidget);
    expect(find.byKey(const Key('caderno-card-c1')), findsOneWidget);
    expect(find.byKey(const Key('cadernos-vazio')), findsNothing);
  });

  testWidgets('lista usa duas colunas a partir do tablet', (tester) async {
    when(() => repo.listar(50)).thenAnswer(
      (_) async => [
        const Caderno(id: 'c1', idUsuario: 50, nome: 'Direito'),
        const Caderno(id: 'c2', idUsuario: 50, nome: 'Português'),
      ],
    );

    await render(tester, const Size(800, 1280));

    final primeiro = tester.getTopLeft(
      find.byKey(const Key('caderno-card-c1')),
    );
    final segundo = tester.getTopLeft(find.byKey(const Key('caderno-card-c2')));

    expect(segundo.dx, greaterThan(primeiro.dx));
    expect((segundo.dy - primeiro.dy).abs(), lessThan(2));
  });

  testWidgets('cria um novo caderno', (tester) async {
    when(() => repo.criar(idUsuario: 50, nome: 'Direito Constitucional'))
        .thenAnswer(
          (_) async => const Caderno(
            id: 'c3',
            idUsuario: 50,
            nome: 'Direito Constitucional',
          ),
        );

    await render(tester, const Size(390, 844));

    await tester.tap(find.byKey(const Key('cadernos-novo')));
    await tester.pumpAndSettle();

    expect(find.text('Novo Caderno'), findsNWidgets(2));

    await tester.enterText(
      find.byKey(const Key('caderno-nome')),
      'Direito Constitucional',
    );
    await tester.tap(find.byKey(const Key('caderno-criar-confirmar')));
    await tester.pumpAndSettle();

    verify(() => repo.criar(idUsuario: 50, nome: 'Direito Constitucional'))
        .called(1);
    expect(find.text('Caderno criado com sucesso.'), findsOneWidget);
  });

  testWidgets('não cria caderno sem nome', (tester) async {
    await render(tester, const Size(390, 844));

    await tester.tap(find.byKey(const Key('cadernos-novo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('caderno-criar-confirmar')));
    await tester.pumpAndSettle();

    expect(find.text('Informe o nome do caderno.'), findsOneWidget);
    verifyNever(
      () => repo.criar(
        idUsuario: any(named: 'idUsuario'),
        nome: any(named: 'nome'),
      ),
    );
  });

  testWidgets('exclui um caderno com confirmação', (tester) async {
    when(() => repo.listar(50)).thenAnswer(
      (_) async => [const Caderno(id: 'c1', idUsuario: 50, nome: 'Direito')],
    );
    when(() => repo.excluir(idCaderno: 'c1', idUsuario: 50))
        .thenAnswer((_) async {});

    await render(tester, const Size(390, 844));

    await tester.tap(find.byKey(const Key('caderno-excluir-c1')));
    await tester.pumpAndSettle();
    expect(find.text('Excluir caderno'), findsOneWidget);

    await tester.tap(find.byKey(const Key('caderno-excluir-confirmar')));
    await tester.pumpAndSettle();

    verify(() => repo.excluir(idCaderno: 'c1', idUsuario: 50)).called(1);
    expect(find.text('Caderno excluído.'), findsOneWidget);
  });

  testWidgets('CTA do estado vazio abre a busca de questões', (tester) async {
    await renderRouter(tester, '/cadernos', const Size(390, 844));

    await tester.tap(find.byKey(const Key('cadernos-buscar')));
    await tester.pumpAndSettle();

    expect(find.text('questoes'), findsOneWidget);
  });

  testWidgets('bottom nav abre a tela de questões', (tester) async {
    await renderRouter(tester, '/cadernos', const Size(390, 844));

    await tester.tap(find.text('Questões'));
    await tester.pumpAndSettle();
    expect(find.text('questoes'), findsOneWidget);
  });

  testWidgets('bottom nav abre o painel', (tester) async {
    await renderRouter(tester, '/cadernos', const Size(390, 844));

    await tester.tap(find.text('Painel'));
    await tester.pumpAndSettle();
    expect(find.text('painel'), findsOneWidget);
  });

  testWidgets('detalhe lista as questões salvas', (tester) async {
    when(() => repo.detalhe(idCaderno: 'c1', idUsuario: 50))
        .thenAnswer((_) async => _detalheFixo());

    await renderRouter(tester, '/cadernos/c1', const Size(390, 844));

    expect(tester.takeException(), isNull);
    expect(find.text('Direito Constitucional'), findsWidgets);
    expect(find.text('2 questões salvas'), findsOneWidget);
    expect(find.textContaining('capital do Brasil'), findsOneWidget);
    expect(find.text('Acertou'), findsOneWidget);
    expect(find.text('Errou'), findsOneWidget);
    expect(find.byKey(const Key('caderno-questao-11')), findsOneWidget);
    expect(find.byKey(const Key('caderno-questao-12')), findsOneWidget);
  });

  testWidgets('detalhe responde a questão dentro do caderno', (tester) async {
    when(() => repo.detalhe(idCaderno: 'c1', idUsuario: 50))
        .thenAnswer((_) async => _detalheFixo());
    when(() => questionRepo.responder(idUsuario: 50, idQuestao: 11, letra: 'B'))
        .thenAnswer(
          (_) async => const RespostaQuestaoResultado(
            correta: false,
            letraCorreta: 'A',
            comentario: 'A capital do Brasil é Brasília.',
          ),
        );

    await renderRouter(tester, '/cadernos/c1', const Size(390, 844));

    final alternativa = find.byKey(const Key('caderno-alternativa-11-B'));
    await tester.ensureVisible(alternativa);
    await tester.pumpAndSettle();
    await tester.tap(alternativa);
    await tester.pumpAndSettle();

    final responder = find.byKey(const Key('caderno-responder-11'));
    await tester.ensureVisible(responder);
    await tester.pumpAndSettle();
    await tester.tap(responder);
    await tester.pumpAndSettle();

    verify(
      () => questionRepo.responder(idUsuario: 50, idQuestao: 11, letra: 'B'),
    ).called(1);
    expect(find.textContaining('Resposta incorreta.'), findsOneWidget);
    expect(find.textContaining('A alternativa correta é a A.'), findsOneWidget);
    expect(find.text('Respondida'), findsOneWidget);
    expect(find.text('Direito Constitucional'), findsWidgets);
    expect(find.text('id=11'), findsNothing);
  });

  testWidgets('detalhe remove uma questão do caderno', (tester) async {
    when(() => repo.detalhe(idCaderno: 'c1', idUsuario: 50))
        .thenAnswer((_) async => _detalheFixo());
    when(
      () => repo.removerQuestao(idCaderno: 'c1', idUsuario: 50, idQuestao: 11),
    ).thenAnswer((_) async {});

    await renderRouter(tester, '/cadernos/c1', const Size(390, 844));

    await tester.tap(find.byKey(const Key('caderno-remover-11')));
    await tester.pumpAndSettle();
    expect(find.text('Remover questão'), findsOneWidget);

    await tester.tap(find.byKey(const Key('caderno-remover-confirmar')));
    await tester.pumpAndSettle();

    verify(
      () => repo.removerQuestao(idCaderno: 'c1', idUsuario: 50, idQuestao: 11),
    ).called(1);
    expect(find.text('Questão removida do caderno.'), findsOneWidget);
  });

  testWidgets('detalhe vazio convida a buscar questões', (tester) async {
    when(() => repo.detalhe(idCaderno: 'c1', idUsuario: 50)).thenAnswer(
      (_) async => CadernoDetalhe(
        caderno: const Caderno(
          id: 'c1',
          idUsuario: 50,
          nome: 'Direito Constitucional',
        ),
        questoes: const [],
      ),
    );

    await renderRouter(tester, '/cadernos/c1', const Size(390, 844));

    expect(tester.takeException(), isNull);
    expect(find.text('Nenhuma questão por aqui'), findsOneWidget);
    expect(find.text('Nenhuma questão salva'), findsOneWidget);
    expect(find.byKey(const Key('caderno-detalhe-buscar')), findsOneWidget);

    await tester.tap(find.byKey(const Key('caderno-detalhe-buscar')));
    await tester.pumpAndSettle();
    expect(find.text('questoes'), findsOneWidget);
  });

  testWidgets('detalhe volta para meus cadernos', (tester) async {
    when(() => repo.detalhe(idCaderno: 'c1', idUsuario: 50))
        .thenAnswer((_) async => _detalheFixo());

    await renderRouter(tester, '/cadernos/c1', const Size(390, 844));

    await tester.tap(find.byKey(const Key('caderno-voltar')));
    await tester.pumpAndSettle();

    expect(find.text('Meus Cadernos'), findsOneWidget);
  });

  testWidgets('reabrir o detalhe recarrega as questões', (tester) async {
    when(() => repo.listar(50)).thenAnswer(
      (_) async => [
        const Caderno(id: 'c1', idUsuario: 50, nome: 'Direito Constitucional'),
      ],
    );
    var chamadas = 0;
    when(() => repo.detalhe(idCaderno: 'c1', idUsuario: 50))
        .thenAnswer((_) async {
          chamadas++;
          return _detalheFixo();
        });

    await renderRouter(tester, '/cadernos/c1', const Size(390, 844));
    expect(chamadas, 1);

    await tester.tap(find.byKey(const Key('caderno-voltar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('caderno-card-c1')));
    await tester.pumpAndSettle();

    expect(chamadas, 2);
    expect(find.text('2 questões salvas'), findsOneWidget);
  });
}

DashboardResumo _resumoFixo() {
  return const DashboardResumo(
    totalResolvidas: 13,
    acertos: 9,
    taxaAcerto: 69,
    ofensiva: 5,
    hojeResolvidas: 3,
    evolucaoPercentual: 12,
    nivelPerformance: 'Bom desempenho',
    ultimos30Dias: [],
  );
}

CadernoDetalhe _detalheFixo() {
  return CadernoDetalhe(
    caderno: const Caderno(
      id: 'c1',
      idUsuario: 50,
      nome: 'Direito Constitucional',
    ),
    questoes: const [
      Questao(
        id: 11,
        enunciado: '<p>Qual é a capital do Brasil?</p>',
        nomeMateria: 'Direito Constitucional',
        nomeBanca: 'CESPE',
        ano: 2025,
        alternativas: [
          Alternativa(
            id: 1,
            idQuestao: 11,
            letra: 'A',
            texto: 'Brasília',
            isCorrect: true,
          ),
          Alternativa(
            id: 2,
            idQuestao: 11,
            letra: 'B',
            texto: 'Rio de Janeiro',
            isCorrect: false,
          ),
        ],
      ),
      Questao(
        id: 12,
        enunciado: '<p>Quem foi o primeiro presidente do Brasil?</p>',
        nomeMateria: 'História do Brasil',
        nomeBanca: 'FGV',
        ano: 2024,
        alternativas: [
          Alternativa(
            id: 3,
            idQuestao: 12,
            letra: 'A',
            texto: 'Deodoro da Fonseca',
            isCorrect: true,
          ),
        ],
      ),
    ],
    idsAcertos: const {11},
    idsErros: const {12},
  );
}

class _QuestoesProbe extends ConsumerWidget {
  const _QuestoesProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtros = ref.watch(questoesFiltrosProvider);
    final id = filtros.idQuestao;
    return Scaffold(
      body: Center(child: Text(id == null ? 'questoes' : 'id=$id')),
    );
  }
}

class _HomeProbe extends StatelessWidget {
  const _HomeProbe();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('painel')));
  }
}
