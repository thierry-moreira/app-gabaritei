import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'models/simulado.dart';
import 'core/theme/theme_mode_provider.dart';
import 'presentation/auth/login_screen.dart';
import 'presentation/auth/register_screen.dart';
import 'presentation/auth/forgot_password_screen.dart';
import 'presentation/home/dashboard_screen.dart';
import 'presentation/home/dashboard_detailed_screen.dart';
import 'presentation/home/cadernos_screen.dart';
import 'presentation/home/caderno_detail_screen.dart';
import 'presentation/home/flashcard_categoria_screen.dart';
import 'presentation/home/flashcard_estudo_screen.dart';
import 'presentation/home/flashcards_screen.dart';
import 'presentation/home/questoes_screen.dart';
import 'presentation/home/resumo_materia_screen.dart';
import 'presentation/home/resumos_screen.dart';
import 'presentation/home/editais_screen.dart';
import 'presentation/home/edital_dashboard_screen.dart';
import 'presentation/home/edital_estudar_screen.dart';
import 'presentation/home/conta_screen.dart';
import 'presentation/home/simulados_screen.dart';
import 'presentation/home/simulado_fazer_screen.dart';
import 'presentation/home/simulado_ranking_screen.dart';
import 'presentation/home/simulado_resultado_screen.dart';

/// Configuração do roteador da aplicação
final GoRouter _router = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    // A sessão do Supabase fica persistida no aparelho: quem já entrou cai
    // direto no painel e quem não entrou volta para o login.
    final logado = Supabase.instance.client.auth.currentSession != null;
    final rota = state.matchedLocation;
    const rotasPublicas = {'/login', '/register', '/forgot-password'};
    final publica = rotasPublicas.contains(rota);

    if (!logado && !publica) return '/login';
    if (logado && publica) return '/home';
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      name: 'forgotPassword',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/dashboard-detailed',
      name: 'dashboardDetailed',
      builder: (context, state) => const DashboardDetailedScreen(),
    ),
    GoRoute(
      path: '/questoes',
      name: 'questoes',
      builder: (context, state) => const QuestoesScreen(),
    ),
    GoRoute(
      path: '/cadernos',
      name: 'cadernos',
      builder: (context, state) => const CadernosScreen(),
    ),
    GoRoute(
      path: '/cadernos/:id',
      name: 'cadernoDetalhe',
      builder: (context, state) =>
          CadernoDetailScreen(idCaderno: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/flashcards',
      name: 'flashcards',
      builder: (context, state) => const FlashcardsScreen(),
    ),
    GoRoute(
      path: '/flashcards/categoria/:id',
      name: 'flashcardCategoria',
      builder: (context, state) =>
          FlashcardCategoriaScreen(idCategoria: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/flashcards/estudar/:id',
      name: 'flashcardEstudar',
      builder: (context, state) =>
          FlashcardEstudoScreen(idCategoria: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/resumos',
      name: 'resumos',
      builder: (context, state) => const ResumosScreen(),
    ),
    GoRoute(
      path: '/resumos/materia/:id',
      name: 'resumoMateria',
      builder: (context, state) => ResumoMateriaScreen(
        idMateria: int.parse(state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/simulados',
      name: 'simulados',
      builder: (context, state) => const SimuladosScreen(),
    ),
    GoRoute(
      path: '/simulados/fazer/:id',
      name: 'simuladoFazer',
      builder: (context, state) =>
          SimuladoFazerScreen(idSimulado: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/simulados/ranking/:id',
      name: 'simuladoRanking',
      builder: (context, state) =>
          SimuladoRankingScreen(idSimulado: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/simulados/resultado/:id',
      name: 'simuladoResultado',
      builder: (context, state) {
        final args = state.extra;
        return SimuladoResultadoScreen(
          args: args is SimuladoResultadoArgs ? args : null,
        );
      },
    ),
    GoRoute(
      path: '/editais',
      name: 'editais',
      builder: (context, state) => const EditaisScreen(),
    ),
    GoRoute(
      path: '/editais/dashboard/:id',
      name: 'editalDashboard',
      builder: (context, state) => EditalDashboardScreen(
        idEdital: int.parse(state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/editais/estudar/:id',
      name: 'editalEstudar',
      builder: (context, state) =>
          EditalEstudarScreen(idEdital: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/conta',
      name: 'conta',
      builder: (context, state) => const ContaScreen(),
    ),
  ],
);

Future<void> main() async {
  // Garante que o Flutter binding esteja inicializado
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment;

  // Sem as credenciais de build o app não tem como funcionar: mostra uma tela
  // explicativa em vez de deixar a tela branca.
  if (!config.isConfigured) {
    runApp(
      const _StartupErrorApp(
        titulo: 'Configuração ausente',
        mensagem:
            'Este build foi gerado sem as credenciais do Supabase. '
            'Compile novamente informando o arquivo de ambiente:',
      ),
    );
    return;
  }

  try {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
    );
  } catch (error) {
    runApp(
      _StartupErrorApp(
        titulo: 'Falha ao conectar',
        mensagem: 'Não foi possível inicializar a conexão com o Supabase.',
        detalhe: '$error',
      ),
    );
    return;
  }

  runApp(const ProviderScope(child: GabariteiApp()));
}

/// Tela exibida quando o app não consegue iniciar (build sem credenciais ou
/// falha de conexão com o Supabase).
class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({
    required this.titulo,
    required this.mensagem,
    this.detalhe,
  });

  final String titulo;
  final String mensagem;
  final String? detalhe;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gabaritei Questões',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
      ),
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.settings_suggest_outlined, size: 40),
                  const SizedBox(height: 16),
                  Text(
                    titulo,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(mensagem),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const SelectableText(
                      'flutter build apk --release \\\n'
                      '  --dart-define-from-file=env.json',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    detalhe ??
                        'Use env.example.json como base para criar o env.json.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GabariteiApp extends ConsumerWidget {
  const GabariteiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Gabaritei Questões',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB), // brand-600
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
          iconTheme: IconThemeData(color: Color(0xFF1E293B)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.red.shade400),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.red.shade600, width: 1.5),
          ),
          labelStyle: const TextStyle(
            color: Color(0xFF334155),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
            elevation: 0,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF2563EB),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFFF1F5F9)),
          ),
          shadowColor: Colors.black.withValues(alpha: 0.02),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          elevation: 0,
        ),
        dividerTheme: DividerThemeData(
          color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
          thickness: 1,
          space: 1,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF020617),
      ),
      themeMode: themeMode,
    );
  }
}
