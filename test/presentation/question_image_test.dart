import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gabaritei_app/presentation/widgets/question_image.dart';

const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAEElEQVR4nGP8zwACTGCSAQANHQEDgslx/wAAAABJRU5ErkJggg==';

void main() {
  test('extrai data URI embutida no HTML e URL remota', () {
    const html =
        '<figure><img src="data:image/png;base64,$_png"></figure>'
        '<img src="https://cdn.example.com/chart.png?x=1&amp;y=2">';

    final imagens = QuestionImage.extrair(html: html);

    expect(imagens, hasLength(2));
    expect(imagens.first, 'data:image/png;base64,$_png');
    expect(imagens.last, 'https://cdn.example.com/chart.png?x=1&y=2');
  });

  test('inclui a URL da coluna e remove imagens duplicadas', () {
    const url = 'https://cdn.example.com/question.png';
    expect(
      QuestionImage.extrair(urlImagem: url, html: '<p><img src="$url"></p>'),
      [url],
    );
  });

  testWidgets('renderiza imagem base64 embutida em vez de texto da tag', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QuestionImage(source: 'data:image/png;base64,$_png'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final imagem = tester.widget<Image>(find.byType(Image));
    expect(imagem.image, isA<MemoryImage>());
    expect(find.text('Não foi possível carregar esta imagem.'), findsNothing);
  });
}
