import 'package:test/test.dart';
import 'package:gabaritei_app/core/time/brasilia_time.dart';

void main() {
  group('BrasiliaTime', () {
    final utcRef = DateTime.utc(2025, 1, 15, 12, 0, 0); // 2025-01-15 12:00 UTC
    // Em Brasília (UTC-3): 2025-01-15 09:00

    test('offset é -3 horas', () {
      expect(BrasiliaTime.offset, const Duration(hours: -3));
    });

    test('now converte UTC para Brasília', () {
      final agora = BrasiliaTime.now(utcNow: utcRef);
      expect(agora.year, 2025);
      expect(agora.month, 1);
      expect(agora.day, 15);
      expect(agora.hour, 9);
      expect(agora.minute, 0);
    });

    test('fromUtc converte UTC para Brasília', () {
      final br = BrasiliaTime.fromUtc(DateTime.utc(2025, 6, 10, 15, 30));
      expect(br.hour, 12);
      expect(br.minute, 30);
    });

    test('fromInstant converte qualquer DateTime para Brasília', () {
      // DateTime UTC - fromInstant assume que o input é UTC
      final instant = DateTime.utc(2025, 1, 15, 12, 0, 0);
      final br = BrasiliaTime.fromInstant(instant);
      expect(br.hour, 9);
    });

    test('dateOnly zera horas/minutos/segundos/millis', () {
      final dt = DateTime(2025, 1, 15, 14, 30, 45, 123);
      final dateOnly = BrasiliaTime.dateOnly(dt);
      expect(dateOnly.hour, 0);
      expect(dateOnly.minute, 0);
      expect(dateOnly.second, 0);
      expect(dateOnly.millisecond, 0);
      expect(dateOnly.microsecond, 0);
    });

    test('today retorna data de hoje em Brasília', () {
      final hoje = BrasiliaTime.today(utcNow: utcRef);
      expect(hoje.year, 2025);
      expect(hoje.month, 1);
      expect(hoje.day, 15);
      expect(hoje.hour, 0);
    });

    test('dayKey retorna yyyy-MM-dd em Brasília', () {
      final instant = DateTime.utc(2025, 1, 15, 12, 0, 0); // 09:00 Brasília
      expect(BrasiliaTime.dayKey(instant), '2025-01-15');

      // Meia-noite UTC = 21:00 dia anterior em Brasília
      final meiaNoiteUtc = DateTime.utc(2025, 1, 15, 0, 0, 0);
      expect(BrasiliaTime.dayKey(meiaNoiteUtc), '2025-01-14');
    });

    test('shortLabel retorna DD/MM', () {
      final instant = DateTime.utc(2025, 1, 15, 12, 0, 0); // 15/01
      expect(BrasiliaTime.shortLabel(instant), '15/01');

      final instant2 = DateTime.utc(2025, 12, 3, 12, 0, 0); // 03/12
      expect(BrasiliaTime.shortLabel(instant2), '03/12');
    });

    test('shortLabelFromDate usa DateTime já em Brasília', () {
      final date = DateTime.utc(2025, 1, 15); // já zerado
      expect(BrasiliaTime.shortLabelFromDate(date), '15/01');
    });

    test('daysBetween calcula dias inteiros ignorando horas', () {
      final a = DateTime.utc(2025, 1, 15, 23, 59);
      final b = DateTime.utc(2025, 1, 16, 0, 1);
      expect(BrasiliaTime.daysBetween(a, b), 1);

      final c = DateTime.utc(2025, 1, 15);
      final d = DateTime.utc(2025, 1, 18);
      expect(BrasiliaTime.daysBetween(c, d), 3);
    });

    test('subtractDays subtrai dias', () {
      final date = DateTime.utc(2025, 1, 15);
      expect(BrasiliaTime.subtractDays(date, 1), DateTime.utc(2025, 1, 14));
      expect(BrasiliaTime.subtractDays(date, 10), DateTime.utc(2025, 1, 5));
    });

    test('lastDays lista últimos N dias do mais antigo para o mais recente', () {
      final hoje = DateTime.utc(2025, 1, 15);
      final dias = BrasiliaTime.lastDays(hoje, 5);
      expect(dias.length, 5);
      expect(dias[0], DateTime.utc(2025, 1, 11));
      expect(dias[4], DateTime.utc(2025, 1, 15));
    });

    test('clampInt', () {
      expect(BrasiliaTime.clampInt(5, 0, 10), 5);
      expect(BrasiliaTime.clampInt(-5, 0, 10), 0);
      expect(BrasiliaTime.clampInt(15, 0, 10), 10);
    });
  });
}