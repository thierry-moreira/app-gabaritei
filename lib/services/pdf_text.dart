/// Normalização de texto usada pelos PDFs de resumos e simulados.
///
/// O Roboto embutido cobre a pontuação tipográfica (aspas curvas, travessões,
/// reticências), mas não símbolos decorativos e emojis. Aqui esses caracteres
/// são convertidos para equivalentes legíveis ou removidos, para que nenhum
/// deles chegue ao PDF como uma caixa.
class PdfText {
  const PdfText._();

  static final _invisiveis = RegExp(r'[\u200B-\u200D\uFEFF]');

  static final _marcadores = RegExp(r'[•‣⁃∙▪▫◦●○■□▸▹►▶➤➢]');

  static final _simbolosSemGlifo = RegExp(
    r'[\u{1F000}-\u{1FAFF}\u{2190}-\u{21FF}\u{2300}-\u{23FF}'
    r'\u{25A0}-\u{25FF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}'
    r'\u{FE0F}\u{200D}]',
    unicode: true,
  );

  static String normalizar(String texto) {
    return texto
        .replaceAll(_invisiveis, '')
        .replaceAll(_marcadores, '-')
        .replaceAll('→', '->')
        .replaceAll('←', '<-')
        .replaceAll('↑', '^')
        .replaceAll('↓', 'v')
        .replaceAll('⇒', '=>')
        .replaceAll('⇔', '<=>')
        .replaceAll('✓', '[ok]')
        .replaceAll('✔', '[ok]')
        .replaceAll('☑', '[ok]')
        .replaceAll('✅', '[ok]')
        .replaceAll('✗', '[x]')
        .replaceAll('✘', '[x]')
        .replaceAll('×', ' x ')
        .replaceAll('·', '*')
        .replaceAll('÷', '/')
        .replaceAll('≤', '<=')
        .replaceAll('≥', '>=')
        .replaceAll('≠', '!=')
        .replaceAll('∞', 'infinito')
        .replaceAll('π', 'pi')
        .replaceAll('α', 'alfa')
        .replaceAll('β', 'beta')
        .replaceAll('Σ', 'Soma')
        .replaceAll('√', 'raiz de ')
        .replaceAll(_simbolosSemGlifo, '');
  }
}
