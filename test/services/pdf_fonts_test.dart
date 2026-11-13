import 'package:flutter_test/flutter_test.dart';
import 'package:gabaritei_app/services/pdf_fonts.dart';
import 'package:gabaritei_app/services/pdf_text.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tema do PDF embute Roboto com a pontuação tipográfica', () async {
    final tema = await PdfFonts.tema();
    final fonte = tema.defaultTextStyle.font;

    expect(fonte, isA<pw.TtfFont>());
    final pdfFont = (fonte! as pw.TtfFont).buildFont(pw.Document().document);
    for (final rune in '“”‘’–—…•'.runes) {
      expect(
        pdfFont.isRuneSupported(rune),
        isTrue,
        reason: 'U+${rune.toRadixString(16)} deveria existir no Roboto',
      );
    }

    expect(tema.defaultTextStyle.fontBold, isA<pw.TtfFont>());
    expect(tema.defaultTextStyle.fontItalic, isA<pw.TtfFont>());
    expect(tema.defaultTextStyle.fontBoldItalic, isA<pw.TtfFont>());
  });

  test('normaliza símbolos sem glifo no Roboto', () {
    expect(
      PdfText.normalizar('▸ item → fim ✓ ⭐').trimRight(),
      '- item -> fim [ok]',
    );
    expect(PdfText.normalizar('a\u200Bb'), 'ab');
    expect(PdfText.normalizar('“aspas” — travessão…'), '“aspas” — travessão…');
  });
}
