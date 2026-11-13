import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gabaritei_app/core/providers.dart';
import 'package:gabaritei_app/models/stats.dart';
import 'package:gabaritei_app/models/user_profile.dart';
import 'package:gabaritei_app/presentation/home/dashboard_screen.dart';

/// Garante que o painel inicial (dashboard comum) não estoure o layout e
/// exponha os indicadores esperados.
///
/// A tela agora lê os dados do Supabase via Riverpod; aqui os providers são
/// sobrescritos com um resumo fixo para o teste não depender da rede.
void main() {
  Future<void> render(
    WidgetTester tester,
    Size size, {
    Brightness brightness = Brightness.light,
  }) async {
    // Define o DPR antes do tamanho físico para que o teste use o tamanho
    // lógico real informado (ex.: 360x800 no celular).
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          perfilAtualProvider.overrideWith(
            (ref) async => const UserProfile(id: 50, username: 'thierry_n1'),
          ),
          painelProvider.overrideWith((ref) async => _resumoFixo()),
        ],
        child: MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: const DashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('painel celular', (tester) async {
    await render(tester, const Size(360, 800));
    expect(tester.takeException(), isNull);

    expect(find.text('Olá, thierry_n1!'), findsOneWidget);
    expect(find.textContaining('60% menor', findRichText: true), findsOneWidget);
    expect(find.text('Raio-X Completo'), findsOneWidget);
    expect(find.text('Resolver Questões'), findsOneWidget);
    expect(find.text('QUESTÕES RESOLVIDAS'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(find.text('+0 hoje'), findsOneWidget);
    expect(find.text('TAXA DE ACERTO'), findsOneWidget);
    expect(find.text('55%'), findsOneWidget);
    expect(find.text('Desempenho Regular'), findsOneWidget);
    expect(find.text('OFENSIVA ATIVA'), findsOneWidget);
    expect(find.text('Frequência de Estudos'), findsOneWidget);
    expect(find.text('7 dias'), findsOneWidget);
    expect(find.text('15 dias'), findsOneWidget);
    expect(find.text('30 dias'), findsOneWidget);
    expect(
      find.textContaining('Gabaritei Questões', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('painel celular compacto', (tester) async {
    await render(tester, const Size(320, 568));
    expect(tester.takeException(), isNull);
    expect(find.text('Frequência de Estudos'), findsOneWidget);
  });

  testWidgets('painel celular tema escuro', (tester) async {
    await render(
      tester,
      const Size(390, 844),
      brightness: Brightness.dark,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Frequência de Estudos'), findsOneWidget);
  });

  testWidgets('painel tablet retrato', (tester) async {
    await render(tester, const Size(800, 1280));
    expect(tester.takeException(), isNull);
  });

  testWidgets('painel tablet usa métricas em linha', (tester) async {
    await render(tester, const Size(800, 1280));
    expect(tester.takeException(), isNull);

    // No tablet as três métricas ficam lado a lado; no celular a ofensiva
    // ocupa uma linha própria. A posição horizontal confirma a mudança.
    final ofensiva = tester.getTopLeft(find.text('OFENSIVA ATIVA'));
    expect(ofensiva.dx, greaterThan(400));
  });

  testWidgets('painel tablet paisagem', (tester) async {
    await render(tester, const Size(1280, 800));
    expect(tester.takeException(), isNull);
  });
}

/// Resumo com os mesmos números da tela de referência do Stitch:
/// 40 questões, 55% de acerto, ofensiva zerada e evolução de -60%.
DashboardResumo _resumoFixo() {
  const ultimosSete = [
    (acertos: 0, erros: 0),
    (acertos: 0, erros: 0),
    (acertos: 2, erros: 1),
    (acertos: 0, erros: 0),
    (acertos: 1, erros: 0),
    (acertos: 0, erros: 0),
    (acertos: 0, erros: 0),
  ];

  final dias = <DiaAtividade>[
    for (var i = 0; i < 23; i++)
      DiaAtividade(label: '01/01', acertos: 1, erros: 1),
    for (var i = 0; i < ultimosSete.length; i++)
      DiaAtividade(
        label: '0${i + 1}/02',
        acertos: ultimosSete[i].acertos,
        erros: ultimosSete[i].erros,
      ),
  ];

  return DashboardResumo(
    totalResolvidas: 40,
    acertos: 22,
    taxaAcerto: 55,
    ofensiva: 0,
    hojeResolvidas: 0,
    evolucaoPercentual: -60,
    nivelPerformance: 'Desempenho Regular',
    ultimos30Dias: dias,
  );
}
