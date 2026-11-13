import 'package:test/test.dart';
import 'package:gabaritei_app/core/time/brasilia_time.dart';
import 'package:gabaritei_app/services/streak_service.dart';

void main() {
  // Fixed "now" in UTC: 2025-01-15 12:00:00 UTC
  // In Brasília (UTC-3): 2025-01-15 09:00:00
  // Today in Brasília: 2025-01-15
  // Yesterday in Brasília: 2025-01-14
  // Day before yesterday: 2025-01-13
  final utcNow = DateTime.utc(2025, 1, 15, 12, 0, 0);

  // Helper: cria instant que cai em uma data específica de Brasília
  DateTime instantForBrasiliaDate(DateTime brasiliaDate, {int hour = 9}) {
    // brasiliaDate é meia-noite UTC (ex: 2025-01-15 00:00:00 UTC)
    // Precisamos converter para o horário de Brasília: adicionar 3h para obter UTC
    return brasiliaDate.add(Duration(hours: 3 + hour));
  }

  group('StreakService.calculate', () {
    test('empty history returns 0', () {
      expect(StreakService.calculate([], utcNow: utcNow), 0);
    });

    test('single activity today returns 1', () {
      // Activity today in Brasília (2025-01-15)
      final hojeBr = BrasiliaTime.today(utcNow: utcNow); // 2025-01-15 00:00:00 UTC
      final instant = instantForBrasiliaDate(hojeBr); // 2025-01-15 12:00:00 UTC = 09:00 Brasília
      expect(StreakService.calculate([instant], utcNow: utcNow), 1);
    });

    test('single activity yesterday returns 1', () {
      // Activity yesterday in Brasília (2025-01-14)
      final ontemBr = BrasiliaTime.today(utcNow: utcNow).subtract(const Duration(days: 1)); // 2025-01-14 00:00:00 UTC
      final instant = instantForBrasiliaDate(ontemBr); // 2025-01-14 12:00:00 UTC = 09:00 Brasília
      expect(StreakService.calculate([instant], utcNow: utcNow), 1);
    });

    test('single activity day before yesterday returns 0 (streak broken)', () {
      final anteontemBr = BrasiliaTime.today(utcNow: utcNow).subtract(const Duration(days: 2)); // 2025-01-13
      final instant = instantForBrasiliaDate(anteontemBr);
      expect(StreakService.calculate([instant], utcNow: utcNow), 0);
    });

    test('consecutive days today + yesterday = 2', () {
      final hojeBr = BrasiliaTime.today(utcNow: utcNow); // 2025-01-15
      final ontemBr = hojeBr.subtract(const Duration(days: 1)); // 2025-01-14
      final instantes = [
        instantForBrasiliaDate(hojeBr),   // today
        instantForBrasiliaDate(ontemBr),  // yesterday
      ];
      expect(StreakService.calculate(instantes, utcNow: utcNow), 2);
    });

    test('streak of 5 consecutive days', () {
      final hojeBr = BrasiliaTime.today(utcNow: utcNow);
      final instantes = <DateTime>[];
      for (var i = 0; i < 5; i++) {
        final dia = hojeBr.subtract(Duration(days: i));
        instantes.add(instantForBrasiliaDate(dia));
      }
      expect(StreakService.calculate(instantes, utcNow: utcNow), 5);
    });

    test('gap breaks streak', () {
      final hojeBr = BrasiliaTime.today(utcNow: utcNow);
      final instantes = <DateTime>[
        instantForBrasiliaDate(hojeBr),                    // hoje
        instantForBrasiliaDate(hojeBr.subtract(const Duration(days: 1))), // ontem
        instantForBrasiliaDate(hojeBr.subtract(const Duration(days: 3))), // anteontem (gap!)
      ];
      expect(StreakService.calculate(instantes, utcNow: utcNow), 2);
    });

    test('future activities make streak = 0 (latest é futuro)', () {
      final hojeBr = BrasiliaTime.today(utcNow: utcNow);
      final amanhaBr = hojeBr.add(const Duration(days: 1));
      final instantes = [
        instantForBrasiliaDate(amanhaBr), // futuro
        instantForBrasiliaDate(hojeBr),   // hoje
      ];
      // Latest activity é amanhã (futuro) -> streak = 0
      expect(StreakService.calculate(instantes, utcNow: utcNow), 0);
    });

    test('multiple activities same day count once', () {
      final hojeBr = BrasiliaTime.today(utcNow: utcNow);
      final instantes = [
        instantForBrasiliaDate(hojeBr, hour: 6),  // 06:00 UTC = 03:00 Brasília
        instantForBrasiliaDate(hojeBr, hour: 12), // 12:00 UTC = 09:00 Brasília
        instantForBrasiliaDate(hojeBr, hour: 18), // 18:00 UTC = 15:00 Brasília
      ];
      expect(StreakService.calculate(instantes, utcNow: utcNow), 1);
    });

    test('streak continues if latest was yesterday', () {
      final ontemBr = BrasiliaTime.today(utcNow: utcNow).subtract(const Duration(days: 1)); // 2025-01-14
      final anteontemBr = ontemBr.subtract(const Duration(days: 1)); // 2025-01-13
      final instantes = [
        instantForBrasiliaDate(ontemBr),
        instantForBrasiliaDate(anteontemBr),
      ];
      expect(StreakService.calculate(instantes, utcNow: utcNow), 2);
    });

    test('streak broken if latest was 2 days ago', () {
      final anteontemBr = BrasiliaTime.today(utcNow: utcNow).subtract(const Duration(days: 2)); // 2025-01-13
      final instantes = [
        instantForBrasiliaDate(anteontemBr),
      ];
      expect(StreakService.calculate(instantes, utcNow: utcNow), 0);
    });

    test('works with different times on same Brasília day', () {
      // 06:00 and 20:00 UTC = 03:00 and 17:00 Brasília (same day)
      final instantes = [
        DateTime.utc(2025, 1, 15, 6, 0, 0),  // 03:00 Brasília
        DateTime.utc(2025, 1, 15, 20, 0, 0), // 17:00 Brasília
      ];
      expect(StreakService.calculate(instantes, utcNow: utcNow), 1);
    });
  });
}