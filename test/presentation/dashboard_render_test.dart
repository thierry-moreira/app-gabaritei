import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gabaritei_app/core/providers.dart';
import 'package:gabaritei_app/models/stats.dart';
import 'package:gabaritei_app/models/user_profile.dart';
import 'package:gabaritei_app/presentation/home/dashboard_detailed_screen.dart';
import 'package:gabaritei_app/repositories/user_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockUserRepository extends Mock implements UserRepository {}

/// Garante que o raio-x não estoure o layout em celulares e tablets.
///
/// Os providers são sobrescritos com dados fixos para exercitar o conteúdo
/// completo (cards, gráficos e listas) sem depender da rede.
void main() {
  Widget wrap(UserRepository userRepo, Widget child) => ProviderScope(
    overrides: [
      perfilAtualProvider.overrideWith(
        (ref) async => const UserProfile(id: 50, username: 'thierry_n1'),
      ),
      painelProvider.overrideWith((ref) async => _resumoFixo()),
      estatisticasDetalhadasProvider.overrideWith(
        (ref) async => _detalhadoFixo(),
      ),
      userRepositoryProvider.overrideWithValue(userRepo),
    ],
    child: child,
  );

  Future<void> render(
    WidgetTester tester,
    Size size, {
    UserRepository? userRepo,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrap(
        userRepo ?? _MockUserRepository(),
        const MaterialApp(home: DashboardDetailedScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> renderComRouter(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/dashboard-detailed',
      routes: [
        GoRoute(
          path: '/dashboard-detailed',
          builder: (context, state) => const DashboardDetailedScreen(),
        ),
        GoRoute(
          path: '/questoes',
          builder: (context, state) => const _QuestoesProbe(),
        ),
      ],
    );

    await tester.pumpWidget(
      wrap(_MockUserRepository(), MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('dashboard detalhado celular', (tester) async {
    await render(tester, const Size(360, 800));
    expect(tester.takeException(), isNull);
    expect(find.text('Dashboard Detalhado'), findsOneWidget);
    expect(find.text('Desempenho por Materia'), findsOneWidget);
  });

  testWidgets('dashboard detalhado celular compacto', (tester) async {
    await render(tester, const Size(320, 568));
    expect(tester.takeException(), isNull);
    expect(find.text('Questoes Resolvidas'), findsOneWidget);
  });

  testWidgets('dashboard detalhado tablet retrato', (tester) async {
    await render(tester, const Size(800, 1280));
    expect(tester.takeException(), isNull);
    expect(find.text('Analise Estrategica'), findsOneWidget);
  });

  testWidgets('dashboard detalhado tablet paisagem em duas colunas', (
    tester,
  ) async {
    await render(tester, const Size(1280, 800));
    expect(tester.takeException(), isNull);

    // A partir de 900 dp o raio-x usa duas colunas: o desempenho por matéria
    // fica à direita da análise estratégica.
    final desempenho = tester.getTopLeft(find.text('Desempenho por Materia'));
    expect(desempenho.dx, greaterThan(400));
  });

  testWidgets('dashboard detalhado expande a materia e mostra os assuntos', (
    tester,
  ) async {
    await render(tester, const Size(390, 844));
    expect(find.text('Crase'), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('materia-card-1')));
    await tester.tap(find.byKey(const Key('materia-card-1')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Crase'), findsOneWidget);
    expect(find.text('Concordância Verbal'), findsOneWidget);
    expect(find.byKey(const Key('praticar-1-101')), findsOneWidget);
    expect(find.text('4 resolvidas'), findsOneWidget);

    // Accordion do desktop: abrir outra matéria recolhe a anterior.
    await tester.ensureVisible(find.byKey(const Key('materia-card-2')));
    await tester.tap(find.byKey(const Key('materia-card-2')));
    await tester.pumpAndSettle();

    expect(find.text('Crase'), findsNothing);
    expect(find.text('Controle de Constitucionalidade'), findsOneWidget);
  });

  testWidgets('praticar assunto abre questoes filtradas', (tester) async {
    await renderComRouter(tester, const Size(390, 844));

    await tester.ensureVisible(find.byKey(const Key('materia-card-1')));
    await tester.tap(find.byKey(const Key('materia-card-1')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('praticar-1-101')));
    await tester.tap(find.byKey(const Key('praticar-1-101')));
    await tester.pumpAndSettle();

    expect(find.text('materias=1 topicos=101'), findsOneWidget);
  });

  testWidgets('calendario de metas navega entre meses e ajusta a meta', (
    tester,
  ) async {
    await render(tester, const Size(390, 844));

    await tester.ensureVisible(find.byKey(const Key('calendario-mes')));
    final inicial = tester
        .widget<Text>(find.byKey(const Key('calendario-mes')))
        .data;

    await tester.tap(find.byKey(const Key('calendario-proximo')));
    await tester.pumpAndSettle();
    final proximo = tester
        .widget<Text>(find.byKey(const Key('calendario-mes')))
        .data;
    expect(proximo, isNot(inicial));

    await tester.tap(find.byKey(const Key('calendario-anterior')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('calendario-mes'))).data,
      inicial,
    );

    expect(
      tester.widget<Text>(find.byKey(const Key('calendario-meta'))).data,
      '20',
    );
    await tester.tap(find.byKey(const Key('calendario-meta-menos')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('calendario-meta'))).data,
      '15',
    );
    await tester.tap(find.byKey(const Key('calendario-meta-mais')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('calendario-meta'))).data,
      '20',
    );

    expect(find.text('Hoje'), findsOneWidget);
    expect(find.text('Meta Batida'), findsOneWidget);
    expect(find.text('Tentativas'), findsOneWidget);
  });

  testWidgets('calendario recolhe e expande', (tester) async {
    await render(tester, const Size(390, 844));

    await tester.ensureVisible(find.byKey(const Key('calendario-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendario-mes')), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendario-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendario-mes')), findsNothing);

    await tester.tap(find.byKey(const Key('calendario-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendario-mes')), findsOneWidget);
  });

  testWidgets('salvar meta persiste no repositorio', (tester) async {
    final userRepo = _MockUserRepository();
    when(() => userRepo.definirMetaDiaria(50, 20)).thenAnswer((_) async {});

    await render(tester, const Size(390, 844), userRepo: userRepo);

    await tester.ensureVisible(find.byKey(const Key('salvar-meta')));
    await tester.tap(find.byKey(const Key('salvar-meta')));
    await tester.pumpAndSettle();

    verify(() => userRepo.definirMetaDiaria(50, 20)).called(1);
    expect(find.text('SALVO!'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('SALVAR META'), findsOneWidget);
  });
}

class _QuestoesProbe extends ConsumerWidget {
  const _QuestoesProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtros = ref.watch(questoesFiltrosProvider);
    return Scaffold(
      body: Center(
        child: Text(
          'materias=${filtros.idsMaterias.join(',')} '
          'topicos=${filtros.idsTopicos.join(',')}',
        ),
      ),
    );
  }
}

DashboardResumo _resumoFixo() {
  const dias = [
    DiaAtividade(label: '01/11', acertos: 1, erros: 0),
    DiaAtividade(label: '02/11', acertos: 2, erros: 1),
    DiaAtividade(label: '03/11', acertos: 0, erros: 0),
    DiaAtividade(label: '04/11', acertos: 1, erros: 1),
    DiaAtividade(label: '05/11', acertos: 0, erros: 0),
    DiaAtividade(label: '06/11', acertos: 2, erros: 0),
    DiaAtividade(label: '07/11', acertos: 3, erros: 1),
  ];

  return const DashboardResumo(
    totalResolvidas: 13,
    acertos: 9,
    taxaAcerto: 69,
    ofensiva: 5,
    hojeResolvidas: 3,
    evolucaoPercentual: 12,
    nivelPerformance: 'Bom desempenho',
    ultimos30Dias: dias,
  );
}

DashboardDetalhado _detalhadoFixo() {
  final agora = DateTime(2026, 11, 7);
  final materias = <MateriaEstatistica>[
    MateriaEstatistica(
      idMateria: 1,
      nome: 'Língua Portuguesa',
      acertos: 6,
      total: 9,
      taxa: 67,
      ultimaResolucao: agora,
      diasAtraso: 1,
      topicos: const [
        TopicoEstatistica(
          idTopico: 101,
          idMateria: 1,
          nome: 'Crase',
          acertos: 2,
          total: 4,
          taxa: 50,
        ),
        TopicoEstatistica(
          idTopico: 102,
          idMateria: 1,
          nome: 'Concordância Verbal',
          acertos: 4,
          total: 5,
          taxa: 80,
        ),
      ],
    ),
    MateriaEstatistica(
      idMateria: 2,
      nome: 'Direito Constitucional',
      acertos: 3,
      total: 4,
      taxa: 75,
      ultimaResolucao: agora,
      diasAtraso: 2,
      topicos: const [
        TopicoEstatistica(
          idTopico: 201,
          idMateria: 2,
          nome: 'Controle de Constitucionalidade',
          acertos: 3,
          total: 4,
          taxa: 75,
        ),
      ],
    ),
    MateriaEstatistica(
      idMateria: 3,
      nome: 'Raciocínio Lógico',
      acertos: 2,
      total: 5,
      taxa: 40,
      ultimaResolucao: agora,
      diasAtraso: 12,
      topicos: const [],
    ),
    MateriaEstatistica(
      idMateria: 4,
      nome: 'Informática',
      acertos: 1,
      total: 2,
      taxa: 50,
      ultimaResolucao: agora,
      diasAtraso: 20,
      topicos: const [],
    ),
  ];

  return DashboardDetalhado(
    materias: materias,
    pontosAtencao: const [
      PontoAtencao(
        idMateria: 3,
        idTopico: 10,
        materia: 'Raciocínio Lógico',
        topico: 'Proposições',
        taxa: 35,
        total: 8,
      ),
    ],
    melhorMateria: materias[1],
    evolucao: const [],
    labelsGrafico: const [],
    totalResolvidas: 13,
    totalAcertos: 9,
    taxaGlobal: 69,
    metaDiaria: 20,
    concluidosPorDia: const {},
    alertasRevisao: const [
      AlertaRevisao(
        idMateria: 3,
        nome: 'Raciocínio Lógico',
        dias: 12,
        status: 'Atenção',
        cor: 'orange',
      ),
      AlertaRevisao(
        idMateria: 4,
        nome: 'Informática',
        dias: 20,
        status: 'Crítico',
        cor: 'danger',
      ),
    ],
  );
}
