import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gabaritei_app/core/providers.dart';
import 'package:gabaritei_app/models/stats.dart';
import 'package:gabaritei_app/models/study.dart';
import 'package:gabaritei_app/models/user_profile.dart';
import 'package:gabaritei_app/presentation/home/flashcard_categoria_screen.dart';
import 'package:gabaritei_app/presentation/home/flashcard_estudo_screen.dart';
import 'package:gabaritei_app/presentation/home/flashcards_screen.dart';
import 'package:gabaritei_app/presentation/home/flashcards_ui.dart';
import 'package:gabaritei_app/presentation/home/edital_ui.dart';
import 'package:gabaritei_app/presentation/home/simulados_ui.dart';
import 'package:gabaritei_app/repositories/flashcard_repository.dart';
import 'package:gabaritei_app/repositories/study_ai_repository.dart';
import 'package:gabaritei_app/services/sm2_service.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockFlashcardRepository extends Mock implements FlashcardRepository {}

class _MockStudyAiRepository extends Mock implements StudyAiRepository {}

void main() {
  late _MockFlashcardRepository repo;
  late _MockStudyAiRepository studyAiRepo;
  late List<FlashcardCategoria> categorias;
  late List<Flashcard> cards;
  var paraRevisar = 0;

  setUp(() {
    repo = _MockFlashcardRepository();
    studyAiRepo = _MockStudyAiRepository();
    categorias = [];
    cards = [];
    paraRevisar = 0;
    when(() => repo.listarCategorias('50'))
        .thenAnswer((_) async => List.of(categorias));
    when(() => repo.contarParaRevisar('50'))
        .thenAnswer((_) async => paraRevisar);
  });

  testWidgets('FlashcardRichText interpreta negrito e itálico HTML', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FlashcardRichText(
            text:
                'Conceito: <b>legalidade</b>, <strong>segurança jurídica</strong>, '
                '<i>texto enfatizado</i> e <em>ênfase semântica</em>.',
            colors: FlashcardsColors.light,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );

    final widget = tester.widget<Text>(find.byType(Text));
    final span = widget.textSpan! as TextSpan;
    final spans = span.children!.whereType<TextSpan>().toList();
    expect(
      span.toPlainText(),
      'Conceito: legalidade, segurança jurídica, texto enfatizado e ênfase semântica.',
    );
    final negritos = spans
        .where((item) => item.style?.fontWeight == FontWeight.w700)
        .map((item) => item.text);
    final italicos = spans
        .where((item) => item.style?.fontStyle == FontStyle.italic)
        .map((item) => item.text);
    expect(negritos, containsAll(['legalidade', 'segurança jurídica']));
    expect(italicos, containsAll(['texto enfatizado', 'ênfase semântica']));
    expect(tester.takeException(), isNull);
  });

  Widget wrap(Widget child, {bool dark = false, GoRouter? router}) {
    final overrides = [
      perfilAtualProvider.overrideWith(
        (ref) async => const UserProfile(id: 50, username: 'thierry_n1'),
      ),
      painelProvider.overrideWith((ref) async => _resumoFixo()),
      flashcardRepositoryProvider.overrideWithValue(repo),
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
          path: '/home',
          builder: (context, state) => const Scaffold(body: Text('painel')),
        ),
        GoRoute(
          path: '/questoes',
          builder: (context, state) => const Scaffold(body: Text('questoes')),
        ),
        GoRoute(
          path: '/cadernos',
          builder: (context, state) => const Scaffold(body: Text('cadernos')),
        ),
        GoRoute(
          path: '/flashcards',
          builder: (context, state) => const FlashcardsScreen(),
        ),
        GoRoute(
          path: '/simulados',
          builder: (context, state) => SimuladoPageShell(
            colors: SimuladosColors.light,
            child: const Center(child: Text('simulados-route')),
          ),
        ),
        GoRoute(
          path: '/editais',
          builder: (context, state) => EditalPageShell(
            colors: SimuladosColors.light,
            child: const Center(child: Text('editais-route')),
          ),
        ),
        GoRoute(
          path: '/flashcards/categoria/:id',
          builder: (context, state) => FlashcardCategoriaScreen(
            idCategoria: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/flashcards/estudar/:id',
          builder: (context, state) =>
              FlashcardEstudoScreen(idCategoria: state.pathParameters['id']!),
        ),
      ],
    );
    await tester.pumpWidget(
      wrap(const SizedBox.shrink(), dark: dark, router: router),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('painel vazio corresponde às referências claro e escuro', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      await renderRouter(
        tester,
        '/flashcards',
        const Size(390, 844),
        dark: dark,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Meu Deck de Flashcards'), findsOneWidget);
      expect(
        find.text('Transforme questões em memória de longo prazo.'),
        findsOneWidget,
      );
      expect(find.text('PARA REVISAR HOJE'), findsOneWidget);
      expect(
        find.text('Você ainda não tem categorias de flashcards.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('flashcards-vazio')), findsOneWidget);
      expect(find.text('Começar Agora'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('menu navega entre flashcards, simulados e edital', (
    tester,
  ) async {
    Future<void> abrirESelecionar(String origem, String item) async {
      await renderRouter(tester, origem, const Size(390, 844));
      final opcao = find.text(item);
      await tester.ensureVisible(opcao);
      await tester.tap(opcao);
      await tester.pumpAndSettle();
    }

    await abrirESelecionar('/simulados', 'Flashcards');
    expect(find.text('Meu Deck de Flashcards'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());

    await abrirESelecionar('/flashcards', 'Simulados');
    expect(find.text('simulados-route'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());

    await abrirESelecionar('/editais', 'Simulados');
    expect(find.text('simulados-route'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('painel adapta colunas em tablet retrato e paisagem', (
    tester,
  ) async {
    categorias = [
      const FlashcardCategoria(id: 'cat-1', idUsuario: '50', nome: 'Direito'),
      const FlashcardCategoria(id: 'cat-2', idUsuario: '50', nome: 'Português'),
    ];

    for (final size in [const Size(800, 1280), const Size(1280, 800)]) {
      await renderRouter(tester, '/flashcards', size, dark: true);
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('flashcards-categoria-cat-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('flashcards-categoria-cat-2')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('cria uma categoria pelo CTA do deck vazio', (tester) async {
    when(
      () =>
          repo.criarCategoria(idUsuario: '50', nome: 'Direito Administrativo'),
    ).thenAnswer((_) async {
      const categoria = FlashcardCategoria(
        id: 'cat-1',
        idUsuario: '50',
        nome: 'Direito Administrativo',
      );
      categorias.add(categoria);
      return categoria;
    });

    await renderRouter(tester, '/flashcards', const Size(390, 844));
    final cta = find.byKey(const Key('flashcards-comecar-agora'));
    await tester.ensureVisible(cta);
    await tester.pumpAndSettle();
    await tester.tap(cta);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('flashcards-categoria-nome')),
      'Direito Administrativo',
    );
    await tester.tap(
      find.byKey(const Key('flashcards-categoria-criar-confirmar')),
    );
    await tester.pumpAndSettle();

    verify(
      () =>
          repo.criarCategoria(idUsuario: '50', nome: 'Direito Administrativo'),
    ).called(1);
    expect(find.byKey(const Key('flashcards-categoria-cat-1')), findsOneWidget);
    expect(find.text('Categoria criada.'), findsOneWidget);
  });

  testWidgets('deck mostra categorias, revisões e navega para estudar', (
    tester,
  ) async {
    categorias = [
      const FlashcardCategoria(
        id: 'cat-1',
        idUsuario: '50',
        nome: 'Direito Constitucional',
        nomeMateria: 'Direito Constitucional',
      ),
    ];
    paraRevisar = 1;
    when(() => repo.cardsParaRevisar(idUsuario: '50', idCategoria: 'cat-1'))
        .thenAnswer((_) async => [_card('fc-1')]);

    await renderRouter(tester, '/flashcards', const Size(390, 844));
    expect(find.text('Direito Constitucional'), findsNWidgets(2));
    expect(find.text('1'), findsOneWidget);
    expect(find.byKey(const Key('flashcards-estudar-todos')), findsOneWidget);

    final estudar = find.byKey(const Key('flashcards-estudar-categoria-cat-1'));
    await tester.ensureVisible(estudar);
    await tester.pumpAndSettle();
    await tester.tap(estudar);
    await tester.pumpAndSettle();
    expect(find.text('Card 1 de 1'), findsOneWidget);
    expect(find.text('Pergunta de teste?'), findsOneWidget);
  });

  testWidgets('remove categoria apenas após confirmação', (tester) async {
    categorias = [
      const FlashcardCategoria(
        id: 'cat-1',
        idUsuario: '50',
        nome: 'Direito Penal',
      ),
    ];
    when(() => repo.excluirCategoria(idCategoria: 'cat-1', idUsuario: '50'))
        .thenAnswer((_) async {
          categorias.clear();
        });

    await renderRouter(tester, '/flashcards', const Size(390, 844));
    await tester.tap(find.byTooltip('Ações da categoria'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir Categoria'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('todos os flashcards vinculados'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('flashcards-categoria-excluir-confirmar')),
    );
    await tester.pumpAndSettle();

    verify(() => repo.excluirCategoria(idCategoria: 'cat-1', idUsuario: '50'))
        .called(1);
    expect(find.text('Categoria excluída.'), findsOneWidget);
    expect(find.byKey(const Key('flashcards-vazio')), findsOneWidget);
  });

  testWidgets('cria e exclui flashcards manuais no gerenciamento', (
    tester,
  ) async {
    categorias = [
      const FlashcardCategoria(
        id: 'cat-1',
        idUsuario: '50',
        nome: 'Revisão Geral',
      ),
    ];
    when(() => repo.listarCards(idUsuario: '50', idCategoria: 'cat-1'))
        .thenAnswer((_) async => List.of(cards));
    when(
      () => repo.criar(
        idUsuario: '50',
        idCategoria: 'cat-1',
        frente: 'Pergunta manual?',
        verso: 'Resposta manual.',
      ),
    ).thenAnswer((_) async {
      final card = _card(
        'fc-manual',
        frente: 'Pergunta manual?',
        verso: 'Resposta manual.',
      );
      cards.add(card);
      return card;
    });
    when(() => repo.excluir(idFlashcard: 'fc-manual', idUsuario: '50'))
        .thenAnswer((_) async {
          cards.removeWhere((card) => card.id == 'fc-manual');
        });

    await renderRouter(
      tester,
      '/flashcards/categoria/cat-1',
      const Size(390, 844),
    );
    expect(find.text('Nenhum card nesta categoria ainda.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('flashcard-criar-novo')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('flashcard-frente')),
      'Pergunta manual?',
    );
    await tester.enterText(
      find.byKey(const Key('flashcard-verso')),
      'Resposta manual.',
    );
    await tester.tap(find.byKey(const Key('flashcard-salvar-confirmar')));
    await tester.pumpAndSettle();

    verify(
      () => repo.criar(
        idUsuario: '50',
        idCategoria: 'cat-1',
        frente: 'Pergunta manual?',
        verso: 'Resposta manual.',
      ),
    ).called(1);
    expect(find.text('Pergunta manual?'), findsOneWidget);
    expect(find.text('Resposta manual.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('flashcard-excluir-fc-manual')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('flashcard-excluir-confirmar-fc-manual')),
    );
    await tester.pumpAndSettle();

    verify(() => repo.excluir(idFlashcard: 'fc-manual', idUsuario: '50'))
        .called(1);
    expect(find.text('Flashcard excluído.'), findsOneWidget);
    expect(find.text('Nenhum card nesta categoria ainda.'), findsOneWidget);
  });

  testWidgets('sessão vira o card, aplica qualidade e conclui a fila', (
    tester,
  ) async {
    final fila = [
      _card('fc-1'),
      _card('fc-2', frente: 'Segunda pergunta?', verso: 'Segunda resposta.'),
    ];
    when(() => repo.cardsParaRevisar(idUsuario: '50', idCategoria: null))
        .thenAnswer((_) async => fila);
    when(
      () => repo.revisar(
        idUsuario: '50',
        idFlashcard: any(named: 'idFlashcard'),
        qualidade: any(named: 'qualidade'),
      ),
    ).thenAnswer(
      (_) async => Sm2Result(
        intervalo: 1,
        facilidade: 2.5,
        proximaRevisao: DateTime(2026, 11, 11),
      ),
    );

    await renderRouter(
      tester,
      '/flashcards/estudar/todos',
      const Size(390, 844),
    );
    expect(find.text('Card 1 de 2'), findsOneWidget);
    expect(find.byKey(const Key('flashcard-face-frente')), findsOneWidget);
    expect(find.byKey(const Key('flashcard-avaliar-2')), findsNothing);

    await tester.tap(find.byKey(const Key('flashcard-revelar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('flashcard-face-verso')), findsOneWidget);
    expect(find.byKey(const Key('flashcard-avaliar-0')), findsOneWidget);
    expect(find.byKey(const Key('flashcard-avaliar-1')), findsOneWidget);
    expect(find.byKey(const Key('flashcard-avaliar-2')), findsOneWidget);
    expect(find.byKey(const Key('flashcard-avaliar-3')), findsOneWidget);

    await tester.tap(find.byKey(const Key('flashcard-avaliar-2')));
    await tester.pumpAndSettle();
    expect(find.text('Card 2 de 2'), findsOneWidget);
    expect(find.text('Segunda pergunta?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('flashcard-revelar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flashcard-avaliar-3')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('flashcard-estudo-concluido')), findsOneWidget);
    expect(find.text('Sessão Finalizada!'), findsOneWidget);
    verify(
      () => repo.revisar(idUsuario: '50', idFlashcard: 'fc-1', qualidade: 2),
    ).called(1);
    verify(
      () => repo.revisar(idUsuario: '50', idFlashcard: 'fc-2', qualidade: 3),
    ).called(1);
  });

  testWidgets('fila vazia mostra estado de revisões concluídas', (
    tester,
  ) async {
    when(() => repo.cardsParaRevisar(idUsuario: '50', idCategoria: 'cat-1'))
        .thenAnswer((_) async => const <Flashcard>[]);

    await renderRouter(
      tester,
      '/flashcards/estudar/cat-1',
      const Size(390, 844),
    );

    expect(find.byKey(const Key('flashcard-estudo-vazio')), findsOneWidget);
    expect(find.text('Tudo revisado por aqui!'), findsOneWidget);
    expect(find.text('0 cards'), findsOneWidget);
  });

  testWidgets('erro ao avaliar mantém o mesmo flashcard e permite tentar', (
    tester,
  ) async {
    when(() => repo.cardsParaRevisar(idUsuario: '50', idCategoria: null))
        .thenAnswer((_) async => [_card('fc-1')]);
    when(() => repo.revisar(idUsuario: '50', idFlashcard: 'fc-1', qualidade: 0))
        .thenThrow(Exception('offline'));

    await renderRouter(
      tester,
      '/flashcards/estudar/todos',
      const Size(390, 844),
    );
    await tester.tap(find.byKey(const Key('flashcard-revelar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flashcard-avaliar-0')));
    await tester.pumpAndSettle();

    expect(find.text('Card 1 de 1'), findsOneWidget);
    expect(find.byKey(const Key('flashcard-face-verso')), findsOneWidget);
    expect(find.byKey(const Key('flashcard-avaliar-0')), findsOneWidget);
    expect(find.textContaining('Não foi possível concluir'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('denúncia só é exibida para flashcard gerado por questão', (
    tester,
  ) async {
    when(() => repo.cardsParaRevisar(idUsuario: '50', idCategoria: null))
        .thenAnswer((_) async => [_card('fc-ai', idQuestao: 901)]);
    when(
      () => studyAiRepo.enviarFeedback(
        idQuestao: 901,
        tipo: 'flashcard',
        motivo: 'outro',
        relato: '',
      ),
    ).thenAnswer((_) async {});

    await renderRouter(
      tester,
      '/flashcards/estudar/todos',
      const Size(390, 844),
    );
    expect(find.byKey(const Key('flashcard-estudo-reportar')), findsOneWidget);
    await tester.tap(find.byKey(const Key('flashcard-estudo-reportar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flashcard-feedback-motivo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Outro').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flashcard-feedback-enviar')));
    await tester.pumpAndSettle();

    verify(
      () => studyAiRepo.enviarFeedback(
        idQuestao: 901,
        tipo: 'flashcard',
        motivo: 'outro',
        relato: '',
      ),
    ).called(1);
    expect(find.text('Obrigado. Seu relato foi enviado.'), findsOneWidget);
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

Flashcard _card(
  String id, {
  String frente = 'Pergunta de teste?',
  String verso = 'Resposta de teste.',
  int? idQuestao,
}) => Flashcard(
  id: id,
  idUsuario: '50',
  frente: frente,
  verso: verso,
  idCategoria: 'cat-1',
  idQuestao: idQuestao,
  proximaRevisao: DateTime(2026, 1, 1),
);
