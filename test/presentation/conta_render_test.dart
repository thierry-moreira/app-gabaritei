import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gabaritei_app/core/providers.dart';
import 'package:gabaritei_app/models/stats.dart';
import 'package:gabaritei_app/models/user_profile.dart';
import 'package:gabaritei_app/presentation/home/conta_screen.dart';
import 'package:gabaritei_app/repositories/auth_repository.dart';
import 'package:gabaritei_app/repositories/ia_config_store.dart';
import 'package:gabaritei_app/repositories/user_repository.dart';
import 'package:gabaritei_app/services/ai_provider_service.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockUserRepository extends Mock implements UserRepository {}

class _MockIaConfigStore extends Mock implements IaConfigStore {}

class _MockAiProviderService extends Mock implements AiProviderService {}

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockUserRepository userRepo;
  late _MockIaConfigStore configStore;
  late _MockAiProviderService aiService;
  late _MockAuthRepository authRepo;

  const profile = UserProfile(
    id: 50,
    username: 'thierry_n1',
    email: 'thierry@example.com',
  );

  setUpAll(() {
    registerFallbackValue(
      const AiConfig(
        provedor: 'openai',
        modelo: 'gpt-6.1-sol',
        chave: 'sk-test-key-12345678901234567890',
      ),
    );
  });

  setUpAll(() {
    registerFallbackValue(
      const AiConfig(
        provedor: 'openai',
        modelo: 'gpt-6.1-sol',
        chave: 'sk-test-key-12345678901234567890',
      ),
    );
  });

  setUp(() {
    userRepo = _MockUserRepository();
    configStore = _MockIaConfigStore();
    aiService = _MockAiProviderService();
    authRepo = _MockAuthRepository();
    when(() => configStore.ler(50)).thenAnswer((_) async => null);
    when(() => configStore.remover(50)).thenAnswer((_) async => true);
    when(() => authRepo.sair()).thenAnswer((_) async {});
  });

  Widget wrap({bool dark = false, GoRouter? router}) {
    final overrides = [
      perfilAtualProvider.overrideWith((ref) async => profile),
      painelProvider.overrideWith((ref) async => _resumoFixo()),
      userRepositoryProvider.overrideWithValue(userRepo),
      iaConfigStoreProvider.overrideWithValue(configStore),
      aiProviderServiceProvider.overrideWithValue(aiService),
      authRepositoryProvider.overrideWithValue(authRepo),
    ];
    return ProviderScope(
      overrides: overrides,
      child: router == null
          ? MaterialApp(
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              home: const ContaScreen(),
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
    WidgetTester tester, {
    Size size = const Size(390, 844),
    bool dark = false,
    GoRouter? router,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(dark: dark, router: router));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'configurações mostram perfil, IA e zonas de conta em claro/escuro',
    (tester) async {
      when(() => configStore.ler(50)).thenAnswer(
        (_) async => const AiConfig(
          provedor: 'gemini',
          modelo: 'gemini-3.5-flash-lite',
          chave: 'AIza12345678901234567890XY',
        ),
      );
      for (final dark in [false, true]) {
        await render(tester, dark: dark);
        expect(tester.takeException(), isNull);
        expect(find.text('Configurações'), findsOneWidget);
        expect(find.byKey(const Key('conta-username-heading')), findsOneWidget);
        expect(
          tester
              .widget<TextFormField>(find.byKey(const Key('conta-email')))
              .initialValue,
          'thierry@example.com',
        );
        expect(find.text('Informações de Identidade'), findsOneWidget);
        expect(find.text('Inteligência Artificial'), findsOneWidget);
        expect(find.text('Ativa: Google Gemini'), findsOneWidget);
        expect(find.textContaining('AIza1234'), findsNothing);
        expect(find.byKey(const Key('conta-reset-dados-card')), findsOneWidget);
        expect(find.byKey(const Key('conta-zona-risco-card')), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets('menu do perfil abre configurações e sair', (tester) async {
    final router = GoRouter(
      initialLocation: '/conta',
      routes: [
        GoRoute(
          path: '/conta',
          builder: (context, state) => const ContaScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const Scaffold(body: Text('Login')),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(body: Text('Painel')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await render(tester, router: router);

    await tester.tap(find.byKey(const Key('dashboard-account-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dashboard-account-settings')), findsOneWidget);
    expect(find.byKey(const Key('dashboard-account-logout')), findsOneWidget);
    expect(find.text('Configurações da Conta'), findsOneWidget);
    expect(find.text('Sair da Conta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('salvar perfil preserva o e-mail cadastrado', (tester) async {
    when(
      () => userRepo.atualizarPerfil(
        idUsuario: 50,
        username: 'thierry_editado',
        email: 'thierry@example.com',
      ),
    ).thenAnswer(
      (_) async => const UserProfile(
        id: 50,
        username: 'thierry_editado',
        email: 'thierry@example.com',
      ),
    );

    await render(tester);
    await tester.ensureVisible(find.byKey(const Key('conta-username')));
    await tester.enterText(
      find.byKey(const Key('conta-username')),
      'thierry_editado',
    );
    await tester.ensureVisible(find.byKey(const Key('conta-salvar-perfil')));
    await tester.tap(find.byKey(const Key('conta-salvar-perfil')));
    await tester.pumpAndSettle();

    verify(
      () => userRepo.atualizarPerfil(
        idUsuario: 50,
        username: 'thierry_editado',
        email: 'thierry@example.com',
      ),
    ).called(1);
    expect(find.text('Informações atualizadas com sucesso.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chave BYOK só é salva após testar o provedor', (tester) async {
    const chave = 'sk-test-key-12345678901234567890';
    const config = AiConfig(
      provedor: 'openai',
      modelo: 'gpt-5.6-luna',
      chave: chave,
    );
    when(
      () => aiService.testarChave(
        provedor: 'openai',
        chave: chave,
        modelo: 'gpt-5.6-luna',
      ),
    ).thenAnswer((_) async => const AiKeyTest(true, ''));
    when(() => configStore.salvar(50, any())).thenAnswer((_) async {});

    await render(tester);
    await tester.ensureVisible(find.byKey(const Key('conta-ia-chave')));
    await tester.enterText(find.byKey(const Key('conta-ia-chave')), chave);
    await tester.ensureVisible(find.byKey(const Key('conta-ia-salvar-testar')));
    await tester.tap(find.byKey(const Key('conta-ia-salvar-testar')));
    await tester.pumpAndSettle();

    verify(
      () => aiService.testarChave(
        provedor: 'openai',
        chave: chave,
        modelo: 'gpt-5.6-luna',
      ),
    ).called(1);
    final salvo =
        verify(() => configStore.salvar(50, captureAny())).captured.single
            as AiConfig;
    expect(salvo.provedor, config.provedor);
    expect(salvo.modelo, config.modelo);
    expect(salvo.chave, config.chave);
    expect(
      find.text('Chave validada e salva neste dispositivo.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reset exige a frase de confirmação e chama UserRepository', (
    tester,
  ) async {
    when(() => userRepo.resetarDados(50)).thenAnswer((_) async {});
    await render(tester);

    await tester.ensureVisible(find.byKey(const Key('conta-resetar-dados')));
    await tester.tap(find.byKey(const Key('conta-resetar-dados')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('conta-resetar-confirmar')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('conta-resetar-confirmar')),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const Key('conta-confirmacao-frase')),
      'RESETAR MEUS DADOS',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('conta-resetar-confirmar')),
          )
          .onPressed,
      isNotNull,
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('conta-resetar-confirmar')),
    );
    await tester.tap(find.byKey(const Key('conta-resetar-confirmar')));
    await tester.pumpAndSettle();

    verify(() => userRepo.resetarDados(50)).called(1);
    expect(
      find.text('Seus dados de estudo foram redefinidos.'),
      findsOneWidget,
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
