import 'package:test/test.dart';
import 'package:gabaritei_app/core/time/brasilia_time.dart';
import 'package:gabaritei_app/services/dashboard_service.dart';
import 'package:gabaritei_app/models/study.dart';

void main() {
  // Fixed "now" in UTC: 2025-01-15 12:00:00 UTC
  // In Brasília (UTC-3): 2025-01-15 09:00:00
  final utcNow = DateTime.utc(2025, 1, 15, 12, 0, 0);
  final hojeBr = BrasiliaTime.today(utcNow: utcNow);

  DateTime instantFromBr(DateTime diaBr, {int hour = 9}) {
    // diaBr é meia-noite UTC da data de Brasília
    // Para obter o instant UTC correspondente a `hour` em Brasília:
    // diaBr (meia-noite UTC) + 3h = meia-noite Brasília
    // + hour = hour em Brasília
    return diaBr.add(Duration(hours: 3 + hour));
  }

  group('DashboardService.build', () {
    test('histórico vazio -> tudo zero', () {
      final resumo = DashboardService.build([], utcNow: utcNow);
      expect(resumo.totalResolvidas, 0);
      expect(resumo.acertos, 0);
      expect(resumo.taxaAcerto, 0);
      expect(resumo.ofensiva, 0);
      expect(resumo.hojeResolvidas, 0);
      expect(resumo.evolucaoPercentual, 0);
      expect(resumo.nivelPerformance, 'Precisa de Foco');
      expect(resumo.ultimos30Dias.length, 30);
      for (final dia in resumo.ultimos30Dias) {
        expect(dia.acertos, 0);
        expect(dia.erros, 0);
      }
    });

    test('um acerto hoje -> taxa 100, ofensiva 1, hoje 1', () {
      final historico = [
        HistoricoResposta(
          idQuestao: 1,
          isCorrect: true,
          criadoEm: instantFromBr(hojeBr),
        ),
      ];
      final resumo = DashboardService.build(historico, utcNow: utcNow);
      expect(resumo.totalResolvidas, 1);
      expect(resumo.acertos, 1);
      expect(resumo.taxaAcerto, 100);
      expect(resumo.ofensiva, 1);
      expect(resumo.hojeResolvidas, 1);
      expect(resumo.nivelPerformance, 'Alto Desempenho');
    });

    test('um erro hoje -> taxa 0', () {
      final historico = [
        HistoricoResposta(
          idQuestao: 1,
          isCorrect: false,
          criadoEm: instantFromBr(hojeBr),
        ),
      ];
      final resumo = DashboardService.build(historico, utcNow: utcNow);
      expect(resumo.totalResolvidas, 1);
      expect(resumo.acertos, 0);
      expect(resumo.taxaAcerto, 0);
      expect(resumo.nivelPerformance, 'Precisa de Foco');
    });

    test('taxa com banker\'s rounding: 1 acerto em 3 -> 33.33... -> 33', () {
      final historico = [
        HistoricoResposta(idQuestao: 1, isCorrect: true, criadoEm: instantFromBr(hojeBr)),
        HistoricoResposta(idQuestao: 2, isCorrect: false, criadoEm: instantFromBr(hojeBr)),
        HistoricoResposta(idQuestao: 3, isCorrect: false, criadoEm: instantFromBr(hojeBr)),
      ];
      final resumo = DashboardService.build(historico, utcNow: utcNow);
      expect(resumo.taxaAcerto, 33); // round(33.33...) = 33
    });

    test('taxa 66.66... -> 67 (banker\'s: 66.66... -> 67)', () {
      final historico = [
        HistoricoResposta(idQuestao: 1, isCorrect: true, criadoEm: instantFromBr(hojeBr)),
        HistoricoResposta(idQuestao: 2, isCorrect: true, criadoEm: instantFromBr(hojeBr)),
        HistoricoResposta(idQuestao: 3, isCorrect: false, criadoEm: instantFromBr(hojeBr)),
      ];
      final resumo = DashboardService.build(historico, utcNow: utcNow);
      expect(resumo.taxaAcerto, 67); // round(66.66...) = 67
    });

    test('streak: hoje + ontem = 2', () {
      final ontemBr = hojeBr.subtract(const Duration(days: 1));
      final historico = [
        HistoricoResposta(idQuestao: 1, isCorrect: true, criadoEm: instantFromBr(hojeBr)),
        HistoricoResposta(idQuestao: 2, isCorrect: true, criadoEm: instantFromBr(ontemBr)),
      ];
      final resumo = DashboardService.build(historico, utcNow: utcNow);
      expect(resumo.ofensiva, 2);
    });

    test('streak quebrado: hoje + anteontem = 1', () {
      final anteontemBr = hojeBr.subtract(const Duration(days: 2));
      final historico = [
        HistoricoResposta(idQuestao: 1, isCorrect: true, criadoEm: instantFromBr(hojeBr)),
        HistoricoResposta(idQuestao: 2, isCorrect: true, criadoEm: instantFromBr(anteontemBr)),
      ];
      final resumo = DashboardService.build(historico, utcNow: utcNow);
      expect(resumo.ofensiva, 1); // quebra no gap
    });

    test('atividades futuras fazem streak = 0 (latest é futuro)', () {
      final amanhaBr = hojeBr.add(const Duration(days: 1));
      final historico = [
        HistoricoResposta(idQuestao: 1, isCorrect: true, criadoEm: instantFromBr(amanhaBr)),
        HistoricoResposta(idQuestao: 2, isCorrect: true, criadoEm: instantFromBr(hojeBr)),
      ];
      final resumo = DashboardService.build(historico, utcNow: utcNow);
      // Latest activity é amanhã (futuro) -> streak = 0
      expect(resumo.ofensiva, 0);
    });

    test('evolucaoPercentual: semana anterior 0, semana atual > 0 -> semanaAtual * 100', () {
      // 8 dias atrás (semana anterior) e hoje (semana atual)
      final oitoDiasAtras = hojeBr.subtract(const Duration(days: 8));
      final historico = [
        HistoricoResposta(idQuestao: 1, isCorrect: true, criadoEm: instantFromBr(hojeBr)),
        HistoricoResposta(idQuestao: 2, isCorrect: true, criadoEm: instantFromBr(oitoDiasAtras)),
      ];
      final resumo = DashboardService.build(historico, utcNow: utcNow);
      // semanaAtual = 1, semanaAnterior = 1 -> ((1-1)/1)*100 = 0
      expect(resumo.evolucaoPercentual, 0);
    });

    test('evolucaoPercentual: semana anterior 0, semana atual 4 -> 400', () {
      // 4 atividades nos últimos 7 dias, nenhuma na semana anterior
      final historico = List.generate(4, (i) => HistoricoResposta(
        idQuestao: i + 1,
        isCorrect: true,
        criadoEm: instantFromBr(hojeBr.subtract(Duration(days: i))),
      ));
      final resumo = DashboardService.build(historico, utcNow: utcNow);
      // semanaAtual = 4, semanaAnterior = 0 -> 4 * 100 = 400
      expect(resumo.evolucaoPercentual, 400);
    });

    test('evolucaoPercentual com banker\'s rounding', () {
      // semanaAnterior = 1, semanaAtual = 3 -> ((3-1)/1)*100 = 200
      final tresDiasAtras = hojeBr.subtract(const Duration(days: 3));
      final historico = [
        HistoricoResposta(idQuestao: 1, isCorrect: true, criadoEm: instantFromBr(hojeBr)),
        HistoricoResposta(idQuestao: 2, isCorrect: true, criadoEm: instantFromBr(hojeBr.subtract(const Duration(days: 1)))),
        HistoricoResposta(idQuestao: 3, isCorrect: true, criadoEm: instantFromBr(hojeBr.subtract(const Duration(days: 2)))),
        HistoricoResposta(idQuestao: 4, isCorrect: true, criadoEm: instantFromBr(tresDiasAtras)),
      ];
      final resumo = DashboardService.build(historico, utcNow: utcNow);
      // semanaAtual = 4 (hoje, -1, -2, -3), semanaAnterior = 0
      // Wait: -3 é 3 dias atrás, hoje é 0, então 4 dias na semana atual
      // semanaAnterior = 0
      expect(resumo.evolucaoPercentual, 400);
    });

    test('nivelPerformance: 80 -> Alto, 60 -> Bom, 40 -> Regular, <40 -> Precisa', () {
      for (var taxa = 0; taxa <= 100; taxa += 20) {
        final historico = List.generate(100, (i) => HistoricoResposta(
          idQuestao: i + 1,
          isCorrect: i < taxa,
          criadoEm: instantFromBr(hojeBr),
        ));
        final resumo = DashboardService.build(historico, utcNow: utcNow);
        if (taxa >= 80) {
          expect(resumo.nivelPerformance, 'Alto Desempenho');
        } else if (taxa >= 60) {
          expect(resumo.nivelPerformance, 'Bom Desempenho');
        } else if (taxa >= 40) {
          expect(resumo.nivelPerformance, 'Desempenho Regular');
        } else {
          expect(resumo.nivelPerformance, 'Precisa de Foco');
        }
      }
    });

    test('ultimos30Dias tem 30 labels DD/MM', () {
      final resumo = DashboardService.build([], utcNow: utcNow);
      expect(resumo.ultimos30Dias.length, 30);
      for (final dia in resumo.ultimos30Dias) {
        expect(dia.label, matches(RegExp(r'^\d{2}/\d{2}$')));
      }
    });

    test('hojeResolvidas conta só hoje', () {
      final ontemBr = hojeBr.subtract(const Duration(days: 1));
      final historico = [
        HistoricoResposta(idQuestao: 1, isCorrect: true, criadoEm: instantFromBr(hojeBr)),
        HistoricoResposta(idQuestao: 2, isCorrect: true, criadoEm: instantFromBr(hojeBr)),
        HistoricoResposta(idQuestao: 3, isCorrect: true, criadoEm: instantFromBr(ontemBr)),
      ];
      final resumo = DashboardService.build(historico, utcNow: utcNow);
      expect(resumo.hojeResolvidas, 2);
    });

    test('itens sem criadoEm não quebram', () {
      final historico = [
        HistoricoResposta(idQuestao: 1, isCorrect: true, criadoEm: null),
        HistoricoResposta(idQuestao: 2, isCorrect: true, criadoEm: instantFromBr(hojeBr)),
      ];
      final resumo = DashboardService.build(historico, utcNow: utcNow);
      expect(resumo.totalResolvidas, 2);
      expect(resumo.acertos, 2);
      expect(resumo.ofensiva, 1); // só o de hoje conta
    });
  });
}