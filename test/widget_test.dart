import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gabaritei_app/presentation/auth/login_screen.dart';

void main() {
  testWidgets('Login screen renders correctly', (WidgetTester tester) async {
    // Testa a tela de login isoladamente: GabariteiApp exige as credenciais
    // de build (--dart-define-from-file=env.json), que não existem no teste.
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.text('Gabaritei Questões'), findsOneWidget);
    expect(find.text('Gabarite suas Provas', findRichText: true), findsOneWidget);
    expect(find.text('Entrar na sua conta'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2)); // email + senha
    expect(find.text('ENTRAR'), findsOneWidget);
  });
}
