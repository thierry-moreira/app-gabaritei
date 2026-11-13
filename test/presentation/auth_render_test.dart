import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gabaritei_app/presentation/auth/forgot_password_screen.dart';
import 'package:gabaritei_app/presentation/auth/login_screen.dart';
import 'package:gabaritei_app/presentation/auth/register_screen.dart';

/// Garante que as telas de autenticação não estourem o layout em celulares,
/// tablets em retrato e tablets em paisagem.
void main() {
  Future<void> render(
    WidgetTester tester,
    Widget screen,
    Size size,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(home: screen)),
    );
    await tester.pumpAndSettle();
  }

  const sizes = <String, Size>{
    'celular': Size(360, 800),
    'celular compacto': Size(320, 568),
    'tablet retrato': Size(800, 1280),
    'tablet paisagem': Size(1280, 800),
  };

  for (final entry in sizes.entries) {
    testWidgets('login ${entry.key}', (tester) async {
      await render(tester, const LoginScreen(), entry.value);
      expect(tester.takeException(), isNull);
      expect(find.text('Entrar na sua conta'), findsOneWidget);
    });

    testWidgets('cadastro ${entry.key}', (tester) async {
      await render(tester, const RegisterScreen(), entry.value);
      expect(tester.takeException(), isNull);
      expect(find.text('Crie sua conta'), findsOneWidget);
    });

    testWidgets('recuperação de senha ${entry.key}', (tester) async {
      await render(tester, const ForgotPasswordScreen(), entry.value);
      expect(tester.takeException(), isNull);
      expect(find.text('Recuperar conta'), findsOneWidget);
    });
  }
}
