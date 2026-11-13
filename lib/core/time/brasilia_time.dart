import 'dart:math' as math;

/// Fuso fixo de Brasília (UTC-3), o mesmo adotado pelo backend.
///
/// O Brasil não observa horário de verão desde 2019; o backend também usa
/// `timezone(timedelta(hours=-3))`, então não há dependência de tzdata.
class BrasiliaTime {
  const BrasiliaTime._();

  static const offset = Duration(hours: -3);

  static DateTime now({DateTime? utcNow}) =>
      (utcNow ?? DateTime.now()).toUtc().add(offset);

  static DateTime fromUtc(DateTime value) => value.toUtc().add(offset);

  /// Converte um instante qualquer para o horário de Brasília.
  static DateTime fromInstant(DateTime value) => value.toUtc().add(offset);

  static DateTime dateOnly(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

  static DateTime today({DateTime? utcNow}) => dateOnly(now(utcNow: utcNow));

  /// Chave `yyyy-MM-dd` no fuso de Brasília.
  static String dayKey(DateTime instant) {
    final local = fromInstant(instant);
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  static String shortLabel(DateTime instant) {
    final local = fromInstant(instant);
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}';
  }

  static String shortLabelFromDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}';

  /// Dias inteiros entre duas datas (ignora horas, como `date - date`).
  static int daysBetween(DateTime from, DateTime to) {
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  static DateTime subtractDays(DateTime date, int days) =>
      date.subtract(Duration(days: days));

  /// Lista os últimos [count] dias (do mais antigo para o mais recente),
  /// ancorada em [today].
  static List<DateTime> lastDays(DateTime today, int count) {
    return List<DateTime>.generate(
      count,
      (index) => DateTime.utc(today.year, today.month, today.day)
          .subtract(Duration(days: count - 1 - index)),
      growable: false,
    );
  }

  static int clampInt(int value, int min, int max) =>
      math.min(max, math.max(min, value));
}
