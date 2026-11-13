/// Conversões tolerantes de JSON.
///
/// O PostgREST devolve inteiros como `int`, `double` ou `String` dependendo da
/// coluna e do driver; estes helpers evitam casts frágeis em cada modelo.
class Json {
  const Json._();

  static String text(Object? value, [String fallback = '']) {
    if (value == null) return fallback;
    return value.toString();
  }

  static String? textOrNull(Object? value) {
    if (value == null) return null;
    final text = value.toString();
    return text.isEmpty ? null : text;
  }

  static int integer(Object? value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static int? integerOrNull(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double decimal(Object? value, [double fallback = 0]) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static double? decimalOrNull(Object? value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static bool boolean(Object? value, [bool fallback = false]) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return fallback;
  }

  static DateTime? dateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static List<String> stringList(Object? value) {
    if (value == null) return const [];
    if (value is List) {
      return value.map((item) => item.toString()).toList(growable: false);
    }
    if (value is String && value.isNotEmpty) {
      return value.split(',');
    }
    return const [];
  }

  static List<int> intList(Object? value) {
    if (value == null) return const [];
    if (value is List) {
      return value
          .map((item) => integerOrNull(item))
          .whereType<int>()
          .toList(growable: false);
    }
    return const [];
  }

  static Map<String, dynamic>? mapOrNull(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return null;
  }

  static List<Map<String, dynamic>> mapList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
        .toList(growable: false);
  }

  static T? firstWhereOrNull<T>(
    Iterable<T> items,
    bool Function(T item) predicate,
  ) {
    for (final item in items) {
      if (predicate(item)) return item;
    }
    return null;
  }
}
