import '../core/time/brasilia_time.dart';

/// Cálculo da ofensiva (streak) no fuso fixo de Brasília.
///
/// Regra do painel: a sequência conta se a atividade mais recente foi hoje ou
/// ontem; a partir daí, conta dias consecutivos para trás. Atividades futuras
/// são ignoradas. Espelha `rotas/aluno.py`.
class StreakService {
  const StreakService._();

  static int calculate(Iterable<DateTime> instants, {DateTime? utcNow}) {
    final today = BrasiliaTime.today(utcNow: utcNow);
    final yesterday = today.subtract(const Duration(days: 1));

    final dates = <DateTime>{};
    for (final instant in instants) {
      dates.add(BrasiliaTime.dateOnly(BrasiliaTime.fromInstant(instant)));
    }
    if (dates.isEmpty) return 0;

    final ordered = dates.toList()..sort((a, b) => b.compareTo(a));
    final latest = ordered.first;
    if (latest != today && latest != yesterday) return 0;

    var streak = 1;
    for (var i = 0; i < ordered.length - 1; i++) {
      if (BrasiliaTime.daysBetween(ordered[i + 1], ordered[i]) == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }
}
