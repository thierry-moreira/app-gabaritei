import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gabaritei_app/presentation/widgets/blockquote_view.dart';
import 'package:gabaritei_app/presentation/widgets/code_block_view.dart';
import 'package:gabaritei_app/presentation/widgets/latex_text.dart';
import 'package:gabaritei_app/presentation/widgets/question_image.dart';

void main() {
  Future<void> render(WidgetTester tester, String texto) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: LatexText(
              texto,
              style: const TextStyle(fontSize: 14, color: Colors.black),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renderiza fórmula inline sem mostrar os comandos TeX', (
    tester,
  ) async {
    await render(tester, r'A fração \(\frac{1}{2}\) equivale a 50%.');

    expect(tester.takeException(), isNull);
    expect(find.textContaining(r'\frac', findRichText: true), findsNothing);
    expect(find.textContaining('A fração', findRichText: true), findsOneWidget);
  });

  testWidgets('renderiza fórmula de bloco com delimitadores de exibição', (
    tester,
  ) async {
    await render(
      tester,
      r'Calcule: \[ x = \frac{-b \pm \sqrt{b^2-4ac}}{2a} \]',
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining(r'\frac', findRichText: true), findsNothing);
    expect(find.textContaining('Calcule:', findRichText: true), findsOneWidget);
  });

  testWidgets('mantém valores em reais como texto', (tester) async {
    await render(tester, r'Custa R$ 50,00 e outro item custa R$ 70,00.');

    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('R\$ 50,00', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('R\$ 70,00', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('mantém negrito e itálico do Markdown', (tester) async {
    await render(tester, '**Assunto**: *Redes* de computadores.');

    expect(tester.takeException(), isNull);
    expect(find.textContaining('**', findRichText: true), findsNothing);
    expect(find.textContaining('Assunto', findRichText: true), findsOneWidget);
  });

  testWidgets('preserva <mark> e a formatação HTML', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: LatexText(
              '<mark>Realce</mark> e <b>negrito</b> e <i>itálico</i>.',
              style: const TextStyle(fontSize: 14, color: Colors.black),
              highlightStyle: const TextStyle(
                backgroundColor: Colors.yellow,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('<mark>', findRichText: true), findsNothing);
    final texto = tester.widget<Text>(find.byType(Text));
    final spans = (texto.textSpan! as TextSpan).children!
        .whereType<TextSpan>()
        .toList();
    expect(
      spans.any((span) => span.style?.backgroundColor == Colors.yellow),
      isTrue,
    );
    expect(
      spans.any((span) => span.style?.fontWeight == FontWeight.w700),
      isTrue,
    );
    expect(
      spans.any((span) => span.style?.fontStyle == FontStyle.italic),
      isTrue,
    );
  });

  testWidgets('renderiza fórmula dentro de realce <mark>', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: LatexText(
              r'<mark>Área: \(\pi r^2\)</mark> no círculo.',
              style: const TextStyle(fontSize: 14, color: Colors.black),
              highlightStyle: const TextStyle(
                backgroundColor: Colors.yellow,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining(r'\pi', findRichText: true), findsNothing);
    expect(find.textContaining('Área:', findRichText: true), findsOneWidget);
  });

  test('limparHtml remove tags sem cortar fórmulas com < e >', () {
    const html =
        r'<p>Se \(x < y > z\), então <b>verdadeiro</b> e &amp; correto.</p>';

    final texto = LatexText.limparHtml(html);

    expect(texto, contains(r'\(x < y > z\)'));
    expect(texto, isNot(contains('<b>')));
    expect(texto, contains('verdadeiro'));
    expect(texto, contains('& correto'));
  });

  test('limparHtml preserva bloco <pre><code> e a indentação', () {
    const html =
        '<p>Considere o documento XML abaixo:</p>'
        '<pre><code class="language-plaintext">'
        '&lt;?xml version="1.0" encoding="UTF-8"?&gt; \r\n'
        '&lt;!DOCTYPE Processos \r\n'
        '  &lt;!ELEMENT Processos (Processo+)&gt; \r\n'
        '      &lt;NumeroSequencial&gt;0012300&lt;/NumeroSequencial&gt; \r\n'
        '&lt;/Processos&gt; '
        '</code></pre>'
        '<p>A DTD define que</p>';

    final texto = LatexText.limparHtml(html);

    expect(texto, contains('<?xml version="1.0" encoding="UTF-8"?>'));
    expect(texto, contains('\n  <!ELEMENT Processos (Processo+)>'));
    expect(
      texto,
      contains('\n      <NumeroSequencial>0012300</NumeroSequencial>'),
    );
    expect(texto, contains('\n</Processos>'));
    expect(texto, isNot(contains('<pre')));
    expect(texto, isNot(contains('<code')));
    expect(texto, contains('Considere o documento XML abaixo:'));
    expect(texto, contains('A DTD define que'));

    final trechos = LatexText.dividirBlocosCodigo(texto);
    expect(trechos.where((trecho) => trecho.codigo), hasLength(1));
    expect(
      trechos.firstWhere((trecho) => trecho.codigo).texto,
      contains('\n  <!ELEMENT Processos (Processo+)>'),
    );
  });

  testWidgets('renderiza bloco de código monoespaçado sem quebrar linhas', (
    tester,
  ) async {
    const html =
        '<p>Considere:</p>'
        '<pre><code class="language-plaintext">'
        '&lt;?xml version="1.0"?&gt;\n'
        '  &lt;!ELEMENT Processos (Processo+)&gt;\n'
        '    &lt;Processo&gt;\n'
        '&lt;/Processos&gt;'
        '</code></pre>'
        '<p>Fim.</p>';

    await render(tester, html);

    expect(tester.takeException(), isNull);
    expect(find.byType(CodeBlockView), findsOneWidget);

    final codigo = tester.widget<Text>(
      find.descendant(
        of: find.byType(CodeBlockView),
        matching: find.byType(Text),
      ),
    );
    expect(codigo.data, contains('<?xml version="1.0"?>'));
    expect(codigo.data, contains('\n  <!ELEMENT Processos (Processo+)>'));
    expect(codigo.data, contains('\n    <Processo>'));
    expect(codigo.softWrap, isFalse);
    expect(codigo.style?.fontFamily, 'RobotoMono');
    expect(
      find.textContaining('Considere:', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('Fim.', findRichText: true), findsOneWidget);
  });

  testWidgets('não interpreta cifrão nem LaTeX dentro do código', (
    tester,
  ) async {
    await render(
      tester,
      '<pre><code>var preco = "R\$ 10"; if (x &lt; y) {}</code></pre>',
    );

    expect(tester.takeException(), isNull);
    final codigo = tester.widget<Text>(
      find.descendant(
        of: find.byType(CodeBlockView),
        matching: find.byType(Text),
      ),
    );
    expect(codigo.data, 'var preco = "R\$ 10"; if (x < y) {}');
  });

  testWidgets('renderiza bloco Markdown cercado por três crases', (
    tester,
  ) async {
    await render(
      tester,
      'Exemplo:\n```dart\nvoid main() {\n  print("oi");\n}\n```\nFim.',
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(CodeBlockView), findsOneWidget);
    final codigo = tester.widget<Text>(
      find.descendant(
        of: find.byType(CodeBlockView),
        matching: find.byType(Text),
      ),
    );
    expect(codigo.data, 'void main() {\n  print("oi");\n}');
    expect(find.textContaining('Exemplo:', findRichText: true), findsOneWidget);
    expect(find.textContaining('Fim.', findRichText: true), findsOneWidget);
  });

  test('limparHtml preserva negrito, itálico, sublinhado e tachado', () {
    const html =
        '<p>Texto <strong>negrito</strong> <i>italico</i> '
        '<u>sublinhado</u> <s>tachado</s> <code>codigo</code> '
        '<mark>destaque</mark>.</p>';

    final texto = LatexText.limparHtml(html);

    expect(texto, contains('negrito'));
    expect(texto, contains('italico'));
    expect(texto, contains('sublinhado'));
    expect(texto, contains('tachado'));
    expect(texto, contains('codigo'));
    expect(texto, contains('destaque'));
    expect(texto, isNot(contains('<strong>')));
    expect(texto, isNot(contains('<u>')));
    expect(texto, isNot(contains('<s>')));
  });

  testWidgets('renderiza negrito, sublinhado e tachado', (tester) async {
    await render(
      tester,
      '<p>A <strong>forte</strong> <u>linha</u> <s>velha</s>.</p>',
    );

    expect(tester.takeException(), isNull);
    final texto = tester.widget<Text>(find.byType(Text));
    final spans = (texto.textSpan! as TextSpan).children!
        .whereType<TextSpan>()
        .toList();
    expect(
      spans.any((span) => span.style?.fontWeight == FontWeight.w700),
      isTrue,
    );
    expect(
      spans.any(
        (span) =>
            span.style?.decoration?.contains(TextDecoration.underline) == true,
      ),
      isTrue,
    );
    expect(
      spans.any(
        (span) =>
            span.style?.decoration?.contains(TextDecoration.lineThrough) ==
            true,
      ),
      isTrue,
    );
  });

  testWidgets('renderiza sobrescrito e subscrito', (tester) async {
    await render(tester, 'H<sub>2</sub>O e x<sup>2</sup>.');

    expect(tester.takeException(), isNull);
    final textos = tester
        .widgetList<Text>(find.byType(Text))
        .where((widget) => widget.textSpan != null)
        .toList();
    expect(textos, hasLength(1));
    final filhos = (textos.single.textSpan! as TextSpan).children!;
    expect(filhos.whereType<WidgetSpan>(), hasLength(2));
  });

  testWidgets('renderiza citação como bloco com formatação', (tester) async {
    await render(
      tester,
      '<p>Antes.</p>'
      '<blockquote><p>Citação <strong>importante</strong>.</p></blockquote>'
      '<p>Depois.</p>',
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(BlockquoteView), findsOneWidget);
    expect(find.textContaining('Antes.', findRichText: true), findsOneWidget);
    expect(find.textContaining('Depois.', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('importante', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('renderiza Markdown tachado, negrito duplo e itálico simples', (
    tester,
  ) async {
    await render(tester, 'Veja __forte__, _suave_ e ~~velho~~.');

    expect(tester.takeException(), isNull);
    final texto = tester.widget<Text>(find.byType(Text));
    final spans = (texto.textSpan! as TextSpan).children!
        .whereType<TextSpan>()
        .toList();
    expect(
      spans.any((span) => span.style?.fontWeight == FontWeight.w700),
      isTrue,
    );
    expect(
      spans.any((span) => span.style?.fontStyle == FontStyle.italic),
      isTrue,
    );
    expect(
      spans.any(
        (span) =>
            span.style?.decoration?.contains(TextDecoration.lineThrough) ==
            true,
      ),
      isTrue,
    );
    expect(find.textContaining('Veja', findRichText: true), findsOneWidget);
  });

  testWidgets('renderiza link com cor e sublinhado', (tester) async {
    await render(
      tester,
      '<p>Veja <a href="https://exemplo.com">o site</a>.</p>',
    );

    expect(tester.takeException(), isNull);
    final texto = tester.widget<Text>(find.byType(Text));
    final spans = (texto.textSpan! as TextSpan).children!
        .whereType<TextSpan>()
        .toList();
    expect(
      spans.any((span) => span.style?.color == const Color(0xFF2563EB)),
      isTrue,
    );
    expect(
      spans.any(
        (span) =>
            span.style?.decoration?.contains(TextDecoration.underline) == true,
      ),
      isTrue,
    );
    expect(find.textContaining('o site', findRichText: true), findsOneWidget);
  });

  testWidgets('renderiza negrito e sublinhado aninhados como no desktop', (
    tester,
  ) async {
    await render(
      tester,
      '<p>“Deixou sua marca <strong><u>indelível</u></strong>” é o mesmo '
      'que:</p>',
    );

    expect(tester.takeException(), isNull);
    final texto = tester.widget<Text>(find.byType(Text));
    final spans = (texto.textSpan! as TextSpan).children!
        .whereType<TextSpan>()
        .toList();
    expect(
      spans.any(
        (span) =>
            span.style?.fontWeight == FontWeight.w700 &&
            span.style?.decoration?.contains(TextDecoration.underline) == true,
      ),
      isTrue,
    );
    expect(
      find.textContaining('indelível', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('renderiza alternativa com negrito e sublinhado', (tester) async {
    await render(
      tester,
      '<p>Deixou sua marca <strong><u>perene</u></strong>.</p>',
    );

    expect(tester.takeException(), isNull);
    final texto = tester.widget<Text>(find.byType(Text));
    final spans = (texto.textSpan! as TextSpan).children!
        .whereType<TextSpan>()
        .toList();
    expect(
      spans.any(
        (span) =>
            span.style?.fontWeight == FontWeight.w700 &&
            span.style?.decoration?.contains(TextDecoration.underline) == true,
      ),
      isTrue,
    );
    expect(find.textContaining('perene', findRichText: true), findsOneWidget);
  });

  testWidgets('preserva underscores dentro de code HTML e Markdown', (
    tester,
  ) async {
    const html =
        '<p>Coluna <code>Contribuinte_Imposto</code> e '
        '<code>Valor_Imposto</code>; código Markdown `CPF_CNPJ`.</p>';
    // A tela de alternativas limpa o HTML antes de entregar o texto ao widget.
    await render(tester, LatexText.limparHtml(html));

    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('Contribuinte_Imposto', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Valor_Imposto', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('CPF_CNPJ', findRichText: true), findsOneWidget);

    final spans = tester
        .widgetList<Text>(find.byType(Text))
        .where((widget) => widget.textSpan != null)
        .expand((widget) => (widget.textSpan! as TextSpan).children!)
        .whereType<TextSpan>()
        .toList();
    final codigo = spans
        .where((span) => span.style?.fontFamily == 'RobotoMono')
        .map((span) => span.text ?? '')
        .join();
    expect(codigo, contains('Contribuinte_Imposto'));
    expect(codigo, contains('Valor_Imposto'));
    expect(codigo, contains('CPF_CNPJ'));
  });

  testWidgets('renderiza imagem no ponto onde aparece no HTML', (tester) async {
    const png =
        'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAEElEQVR4nGP8zwACTGCSAQANHQEDgslx/wAAAABJRU5ErkJggg==';
    await render(
      tester,
      '<p>Texto antes da tabela:</p>'
      '<figure class="image"><img src="data:image/png;base64,$png"></figure>'
      '<p>Texto depois da tabela.</p>',
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(QuestionImage), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(
      find.textContaining('Texto antes da tabela:', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Texto depois da tabela.', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('preserva numeração romana maiúscula da lista HTML', (
    tester,
  ) async {
    const html =
        '<p>Considere:</p>'
        '<ol style="list-style-type:upper-roman;">'
        '<li><code>Create View; Alter Table; Drop Table.</code></li>'
        '<li><code>Select View; Create Table; Update Table.</code></li>'
        '<li><code>Drop View; Alter View; Delete Table.</code></li>'
        '</ol>'
        '<p>São válidas as cláusulas que constam em</p>';

    final texto = LatexText.limparHtml(html);
    expect(texto, contains('I.'));
    expect(texto, contains('II.'));
    expect(texto, contains('III.'));
    expect(texto, contains('Create View; Alter Table; Drop Table.'));
    expect(texto, contains('Select View; Create Table; Update Table.'));
    expect(texto, contains('Drop View; Alter View; Delete Table.'));
    expect(texto, isNot(contains('• Create View')));

    await render(tester, texto);

    expect(tester.takeException(), isNull);
    expect(find.textContaining('I.', findRichText: true), findsOneWidget);
    expect(find.textContaining('III.', findRichText: true), findsOneWidget);
    expect(
      find.textContaining(
        'Create View; Alter Table; Drop Table.',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('• Create View', findRichText: true),
      findsNothing,
    );
  });
}
