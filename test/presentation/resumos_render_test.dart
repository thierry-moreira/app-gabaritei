import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gabaritei_app/core/providers.dart';
import 'package:gabaritei_app/models/stats.dart';
import 'package:gabaritei_app/models/study.dart';
import 'package:gabaritei_app/models/user_profile.dart';
import 'package:gabaritei_app/presentation/home/resumo_materia_screen.dart';
import 'package:gabaritei_app/presentation/home/resumos_screen.dart';
import 'package:gabaritei_app/repositories/resumo_repository.dart';
import 'package:gabaritei_app/repositories/study_ai_repository.dart';
import 'package:gabaritei_app/services/resumo_content_formatter.dart';
import 'package:gabaritei_app/services/resumo_print_service.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockResumoRepository extends Mock implements ResumoRepository {}

class _MockResumoPrintService extends Mock implements ResumoPrintService {}

class _MockStudyAiRepository extends Mock implements StudyAiRepository {}

void main() {
  late _MockResumoRepository repo;
  late _MockResumoPrintService printer;
  late _MockStudyAiRepository studyAiRepo;
  late List<Resumo> resumos;

  const materia = ResumosPorMateria(
    idMateria: 10,
    nomeMateria: 'Direito Constitucional',
    total: 2,
  );

  setUpAll(() => registerFallbackValue(<Resumo>[]));

  setUp(() {
    repo = _MockResumoRepository();
    printer = _MockResumoPrintService();
    studyAiRepo = _MockStudyAiRepository();
    resumos = [_resumo('r1'), _resumo('r2', idQuestao: null)];

    when(() => repo.listarPorMateria('50')).thenAnswer((_) async {
      if (resumos.isEmpty) return const <ResumosPorMateria>[];
      return [materia.copyWithTotal(resumos.length)];
    });
    when(() => repo.listarDaMateria(idUsuario: '50', idMateria: 10))
        .thenAnswer((_) async => List.of(resumos));
    when(() => repo.buscarMateria(10))
        .thenAnswer((_) async => materia.copyWithTotal(0));
  });

  Widget wrap(Widget child, {bool dark = false, GoRouter? router}) {
    final overrides = [
      perfilAtualProvider.overrideWith(
        (ref) async => const UserProfile(id: 50, username: 'thierry_n1'),
      ),
      painelProvider.overrideWith((ref) async => _resumoFixo()),
      resumoRepositoryProvider.overrideWithValue(repo),
      resumoPrintServiceProvider.overrideWithValue(printer),
      studyAiRepositoryProvider.overrideWithValue(studyAiRepo),
    ];
    if (router != null) {
      return ProviderScope(
        overrides: overrides,
        child: MaterialApp.router(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          routerConfig: router,
        ),
      );
    }
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: child,
      ),
    );
  }

  Future<void> renderRouter(
    WidgetTester tester,
    String initialLocation,
    Size size, {
    bool dark = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/resumos',
          builder: (context, state) => const ResumosScreen(),
        ),
        GoRoute(
          path: '/resumos/materia/:id',
          builder: (context, state) => ResumoMateriaScreen(
            idMateria: int.parse(state.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: '/questoes',
          builder: (context, state) => const Scaffold(body: Text('questoes')),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(body: Text('painel')),
        ),
        GoRoute(
          path: '/cadernos',
          builder: (context, state) => const Scaffold(body: Text('cadernos')),
        ),
        GoRoute(
          path: '/flashcards',
          builder: (context, state) => const Scaffold(body: Text('flashcards')),
        ),
      ],
    );
    await tester.pumpWidget(
      wrap(const SizedBox.shrink(), dark: dark, router: router),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('estado vazio segue as referências Stitch claro e escuro', (
    tester,
  ) async {
    resumos = [];
    for (final dark in [false, true]) {
      await renderRouter(tester, '/resumos', const Size(390, 844), dark: dark);
      expect(tester.takeException(), isNull);
      expect(find.text('Caderno de Resumos'), findsOneWidget);
      expect(find.text('Caderno Vazio'), findsOneWidget);
      expect(
        find.textContaining('Ainda não existem resumos salvos.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('resumos-vazio')), findsOneWidget);
      expect(find.byKey(const Key('resumos-buscar-questoes')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('lista e leitor adaptam em tablet retrato e paisagem', (
    tester,
  ) async {
    for (final size in [const Size(800, 1280), const Size(1280, 800)]) {
      await renderRouter(tester, '/resumos', size, dark: true);
      expect(tester.takeException(), isNull);
      expect(find.text('Direito Constitucional'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());

      await renderRouter(tester, '/resumos/materia/10', size, dark: true);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('resumos-pager')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('CTA vazio leva à busca de questões', (tester) async {
    resumos = [];
    await renderRouter(tester, '/resumos', const Size(390, 844));
    final cta = find.byKey(const Key('resumos-buscar-questoes'));
    await tester.ensureVisible(cta);
    await tester.pumpAndSettle();
    await tester.tap(cta);
    await tester.pumpAndSettle();
    expect(find.text('questoes'), findsOneWidget);
  });

  testWidgets('lista matérias e abre o caderno cronológico', (tester) async {
    await renderRouter(tester, '/resumos', const Size(390, 844));
    expect(find.text('Direito Constitucional'), findsOneWidget);
    expect(find.text('2 itens'), findsOneWidget);

    final abrir = find.byKey(const Key('resumos-ver-materia-10'));
    await tester.ensureVisible(abrir);
    await tester.pumpAndSettle();
    await tester.tap(abrir);
    await tester.pumpAndSettle();

    expect(find.text('2 pontos de revisão'), findsOneWidget);
    expect(find.text('Página 1 de 2'), findsOneWidget);
    expect(find.textContaining('Conceito Central'), findsOneWidget);
    expect(find.byKey(const Key('resumos-imprimir')), findsOneWidget);
  });

  testWidgets('swipe/controles navegam e imprime a matéria completa', (
    tester,
  ) async {
    when(
      () => printer.imprimir(
        nomeMateria: 'Direito Constitucional',
        resumos: any(named: 'resumos'),
      ),
    ).thenAnswer((_) async => true);

    await renderRouter(tester, '/resumos/materia/10', const Size(390, 844));
    await tester.tap(find.byKey(const Key('resumos-pagina-proxima')));
    await tester.pumpAndSettle();
    expect(find.text('Página 2 de 2'), findsOneWidget);
    expect(find.textContaining('Princípio da legalidade'), findsOneWidget);

    final imprimir = find.byKey(const Key('resumos-imprimir'));
    await tester.ensureVisible(imprimir);
    await tester.pumpAndSettle();
    await tester.tap(imprimir);
    await tester.pumpAndSettle();

    verify(
      () => printer.imprimir(
        nomeMateria: 'Direito Constitucional',
        resumos: any(named: 'resumos'),
      ),
    ).called(1);
    expect(find.text('Documento enviado à impressão.'), findsOneWidget);
  });

  testWidgets('exclui o último resumo e mantém o caderno acessível', (
    tester,
  ) async {
    resumos = [_resumo('r1')];
    when(() => repo.excluir(idUsuario: '50', idResumo: 'r1'))
        .thenAnswer((_) async {
          resumos.removeWhere((resumo) => resumo.id == 'r1');
        });

    await renderRouter(tester, '/resumos/materia/10', const Size(390, 844));
    expect(find.byKey(const Key('resumo-page-r1')), findsOneWidget);
    expect(find.text('RESUMO #1'), findsOneWidget);
    final excluir = find.byKey(const Key('resumo-excluir-r1'));
    expect(excluir, findsOneWidget);
    await tester.tap(excluir);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('resumo-excluir-confirmar-r1')));
    await tester.pumpAndSettle();

    verify(() => repo.excluir(idUsuario: '50', idResumo: 'r1')).called(1);
    verify(() => repo.buscarMateria(10)).called(1);
    expect(find.text('Nenhum resumo nesta matéria.'), findsOneWidget);
    expect(find.byKey(const Key('resumo-materia-vazia')), findsOneWidget);
  });

  testWidgets('exclui o caderno inteiro e retorna à lista', (tester) async {
    when(() => repo.excluirMateria(idUsuario: '50', idMateria: 10))
        .thenAnswer((_) async => resumos.clear());

    await renderRouter(tester, '/resumos/materia/10', const Size(390, 844));
    final excluir = find.byKey(const Key('resumos-excluir-materia'));
    await tester.ensureVisible(excluir);
    await tester.pumpAndSettle();
    await tester.tap(excluir);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('resumos-excluir-todos-confirmar')));
    await tester.pumpAndSettle();

    verify(() => repo.excluirMateria(idUsuario: '50', idMateria: 10)).called(1);
    expect(find.text('Caderno de Resumos'), findsOneWidget);
    expect(find.byKey(const Key('resumos-vazio')), findsOneWidget);
  });

  testWidgets('reporta problema em resumo criado por IA', (tester) async {
    when(
      () => studyAiRepo.enviarFeedback(
        idQuestao: 451,
        tipo: 'resumo',
        motivo: 'outro',
        relato: '',
      ),
    ).thenAnswer((_) async {});

    await renderRouter(tester, '/resumos/materia/10', const Size(390, 844));
    await tester.tap(find.byKey(const Key('resumo-reportar-r1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('resumo-feedback-motivo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Outro').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('resumo-feedback-enviar')));
    await tester.pumpAndSettle();

    verify(
      () => studyAiRepo.enviarFeedback(
        idQuestao: 451,
        tipo: 'resumo',
        motivo: 'outro',
        relato: '',
      ),
    ).called(1);
    expect(find.text('Obrigado. Seu relato foi enviado.'), findsOneWidget);
  });

  test('PDF contém o documento da matéria e seus resumos', () async {
    final bytes = await ResumoPdfService.gerar(
      nomeMateria: 'Direito Constitucional',
      resumos: [_resumo('r1')],
      agora: DateTime(2026, 11, 10),
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });

  test('formatador mantém títulos, bullets, negrito e fórmulas legíveis', () {
    final blocks = ResumoContentFormatter.parse(
      '### Tema\n• **Regra**: use \\(\\frac{a}{b}\\).',
    );
    expect(blocks.first.kind, ResumoBlockKind.heading);
    expect(blocks[1].kind, ResumoBlockKind.bullet);
    expect(
      blocks[1].runs.any((run) => run.bold && run.text == 'Regra'),
      isTrue,
    );
    expect(ResumoContentFormatter.plainText('\\(\\frac{3}{4}\\)'), '3/4');
    expect(
      ResumoContentFormatter.plainText(r'Valor: R$ 10,00'),
      r'Valor: R$ 10,00',
    );
  });

  test('formatador de resumos interpreta <b>/<strong> e <i>/<em>', () {
    final bloco = ResumoContentFormatter.parse(
      'Regra: <b>negrito</b>, <strong>forte</strong>, '
      '<i>itálico</i> e <em>ênfase</em>.',
    ).single;

    expect(
      bloco.runs.where((run) => run.bold).map((run) => run.text),
      containsAll(['negrito', 'forte']),
    );
    expect(
      bloco.runs.where((run) => run.italic).map((run) => run.text),
      containsAll(['itálico', 'ênfase']),
    );
  });
}

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

Resumo _resumo(String id, {int? idQuestao = 451}) => Resumo(
  id: id,
  idUsuario: '50',
  idMateria: 10,
  nomeMateria: 'Direito Constitucional',
  idQuestao: idQuestao,
  conteudo:
      '### Tema da Questão\n'
      '• **Conceito Central**: Princípio da legalidade e suas regras.\n'
      '💡 Fixação: a administração age conforme a lei.',
  criadoEm: DateTime(2026, 11, 10),
);

extension on ResumosPorMateria {
  ResumosPorMateria copyWithTotal(int total) => ResumosPorMateria(
    idMateria: idMateria,
    nomeMateria: nomeMateria,
    total: total,
  );
}
