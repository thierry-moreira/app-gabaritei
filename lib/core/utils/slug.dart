/// Slug de matéria/tópico, idêntico ao `slugify` do backend.
String slugify(String? text) {
  if (text == null || text.isEmpty) return '';
  // Equivalente a NFD + remoção de diacríticos + ASCII only.
  final normalized = _removeDiacritics(text).toLowerCase();
  return normalized
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

const _diacritics = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
  'Á': 'a', 'À': 'a', 'Â': 'a', 'Ã': 'a', 'Ä': 'a', 'Å': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'É': 'e', 'È': 'e', 'Ê': 'e', 'Ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'Í': 'i', 'Ì': 'i', 'Î': 'i', 'Ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'Ó': 'o', 'Ò': 'o', 'Ô': 'o', 'Õ': 'o', 'Ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'Ú': 'u', 'Ù': 'u', 'Û': 'u', 'Ü': 'u',
  'ç': 'c', 'Ç': 'c', 'ñ': 'n', 'Ñ': 'n',
  'ý': 'y', 'ÿ': 'y', 'Ý': 'y',
};

String _removeDiacritics(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_diacritics[char] ?? char);
  }
  return buffer.toString();
}
