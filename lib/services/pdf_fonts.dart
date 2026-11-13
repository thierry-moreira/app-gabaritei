import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// Fontes Unicode embutidas nos PDFs gerados pelo app.
///
/// As fontes padrão do pacote `pdf` (Helvetica, Times e Courier) só têm
/// glifos até U+00FF. Por isso, aspas curvas, travessões, reticências e
/// marcadores de lista apareciam como caixas no PDF. O Roboto cobre esses
/// caracteres e é embutido no APK, sem depender de rede na hora de imprimir.
class PdfFonts {
  const PdfFonts._();

  static const _regular = 'assets/fonts/Roboto-Regular.ttf';
  static const _bold = 'assets/fonts/Roboto-Bold.ttf';
  static const _italic = 'assets/fonts/Roboto-Italic.ttf';
  static const _boldItalic = 'assets/fonts/Roboto-BoldItalic.ttf';

  static Future<pw.ThemeData>? _tema;

  /// Tema padrão dos documentos, com Roboto em todos os pesos e estilos.
  ///
  /// O regular também entra como fallback: trechos em fonte monoespaçada
  /// (Courier) continuam usando a fonte de código, mas caracteres fora do
  /// Latin-1 são desenhados pelo Roboto em vez de virar caixa.
  static Future<pw.ThemeData> tema() => _tema ??= _carregar();

  static Future<pw.ThemeData> _carregar() async {
    final regular = await _fonte(_regular);
    final bold = await _fonte(_bold);
    final italic = await _fonte(_italic);
    final boldItalic = await _fonte(_boldItalic);
    return pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      italic: italic,
      boldItalic: boldItalic,
      fontFallback: [regular, bold, italic, boldItalic],
    );
  }

  static Future<pw.Font> _fonte(String caminho) async =>
      pw.Font.ttf(await rootBundle.load(caminho));
}
