/// Moderação local por blocklist, equivalente a `utils.verificar_texto_improprio`.
///
/// A decisão de produto do backend é sem IA: blocklist local na publicação e
/// denúncia humana depois. A normalização remove acentos, converte para
/// minúsculas e aplica o mapa "leet" (0→o, 1→i, 3→e, 4→a, 5→s, 7→t); cada
/// letra pode aparecer repetida e separada por até 3 caracteres não-alfabéticos
/// (ex.: "p0rr4", "m-e-r-d-a"). Isso evita burlas simples sem bloquear palavras
/// legítimas que apenas contêm o termo como prefixo ("computador", "disputa").
class ModerationService {
  const ModerationService();

  static const _blockedTerms = <String>[
    'porra', 'caralho', 'merda', 'puta', 'putaria', 'putinha', 'putas',
    'putona', 'viado', 'gay', 'gays', 'idiota', 'imbecil', 'burro',
    'jumento', 'desgraça', 'vagabundo', 'vaca', 'vacas', 'safado',
    'canalha', 'corno', 'arrombado', 'foda', 'filho da puta',
    'foder', 'fuder', 'fode', 'fude', 'fodr', 'fudr', 'fueder', 'fudder',
  ];

  static const _exactTerms = {'gay', 'puta', 'vaca'};

  static const _leet = {
    '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't',
  };

  static final _wordChar = RegExp(r'\w');

  static final List<_BlockedPattern> _patterns = _blockedTerms
      .map(_compile)
      .whereType<_BlockedPattern>()
      .toList(growable: false);

  ModerationResult check(String? text) {
    if (text == null || text.isEmpty) return const ModerationResult.allowed();
    final normalized = normalize(text);
    for (final pattern in _patterns) {
      for (final match in pattern.regex.allMatches(normalized)) {
        if (match.start > 0 &&
            _wordChar.hasMatch(normalized[match.start - 1])) {
          continue;
        }
        if (pattern.requiresWordEnd &&
            match.end < normalized.length &&
            _wordChar.hasMatch(normalized[match.end])) {
          continue;
        }
        return const ModerationResult.blocked();
      }
    }
    return const ModerationResult.allowed();
  }

  static String normalize(String text) {
    final buffer = StringBuffer();
    for (final rune in text.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      final withoutAccent = _accentMap[char] ?? char;
      for (final unit in withoutAccent.runes) {
        final value = String.fromCharCode(unit);
        buffer.write(_leet[value] ?? value);
      }
    }
    return buffer.toString();
  }

  static _BlockedPattern? _compile(String term) {
    final normalized = normalize(term);
    final chars = <String>[];
    for (final rune in normalized.runes) {
      final char = String.fromCharCode(rune);
      if (RegExp(r'^[\p{L}\p{N}]$', unicode: true).hasMatch(char)) {
        chars.add(char);
      }
    }
    if (chars.isEmpty) return null;
    final body = chars.map((char) => '${RegExp.escape(char)}+').join(r'[\W_]{0,3}');
    final compact = chars.join();
    return _BlockedPattern(
      RegExp(body),
      _exactTerms.contains(compact) || normalized.contains(' '),
    );
  }

  static const _accentMap = <String, String>{
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n', 'ý': 'y', 'ÿ': 'y',
  };
}

class ModerationResult {
  const ModerationResult.allowed() : allowed = true, message = '';
  const ModerationResult.blocked()
      : allowed = false,
        message =
            'Seu comentário contém termos que violam as diretrizes da '
            'comunidade. Por favor, mantenha o respeito.';

  final bool allowed;
  final String message;
}

class _BlockedPattern {
  const _BlockedPattern(this.regex, this.requiresWordEnd);

  final RegExp regex;
  final bool requiresWordEnd;
}
