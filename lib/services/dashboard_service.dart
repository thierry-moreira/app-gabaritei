import '../core/time/brasilia_time.dart';
import '../core/utils/python_math.dart';
import '../models/stats.dart';
import '../models/study.dart';
import 'streak_service.dart';

/// Monta o resumo do painel inicial a partir do histórico do aluno.
///
/// Reproduz `rotas/aluno.py::area_do_aluno`: taxa arredondada com banker's
/// rounding, gráfico de 30 dias em Brasília e evolução semanal.
class DashboardService {
  const DashboardService._();

  static DashboardResumo build(
    List<HistoricoResposta> historico, {
    DateTime? utcNow,
  }) {
    final nowBr = BrasiliaTime.now(utcNow: utcNow);
    final hoje = BrasiliaTime.dateOnly(nowBr);

    final total = historico.length;
    final acertos = historico.where((item) => item.isCorrect).length;
    final taxa = total > 0 ? pythonRound((acertos / total) * 100) : 0;

    final atividades = <DateTime>[];
    final porDia = <String, ({int acertos, int erros})>{};
    final labels = <String>[];
    for (var i = 29; i >= 0; i--) {
      final dia = hoje.subtract(Duration(days: i));
      final label = BrasiliaTime.shortLabelFromDate(dia);
      labels.add(label);
      porDia[label] = (acertos: 0, erros: 0);
    }

    var hojeResolvidas = 0;
    var semanaAtual = 0;
    var semanaAnterior = 0;
    final seteDiasAtras = hoje.subtract(const Duration(days: 7));
    final quatorzeDiasAtras = hoje.subtract(const Duration(days: 14));

    for (final item in historico) {
      final criadoEm = item.criadoEm;
      if (criadoEm == null) continue;
      atividades.add(criadoEm);

      final diaBr = BrasiliaTime.dateOnly(
        BrasiliaTime.fromInstant(criadoEm),
      );
      final label = BrasiliaTime.shortLabelFromDate(diaBr);
      final atual = porDia[label];
      if (atual != null) {
        porDia[label] = (
          acertos: atual.acertos + (item.isCorrect ? 1 : 0),
          erros: atual.erros + (item.isCorrect ? 0 : 1),
        );
      }

      if (diaBr == hoje) hojeResolvidas++;
      if (diaBr.isAfter(seteDiasAtras)) {
        semanaAtual++;
      } else if (diaBr.isAfter(quatorzeDiasAtras) &&
          !diaBr.isAfter(seteDiasAtras)) {
        semanaAnterior++;
      }
    }

    final evolucao = semanaAnterior > 0
        ? pythonRound(((semanaAtual - semanaAnterior) / semanaAnterior) * 100)
        : (semanaAtual > 0 ? semanaAtual * 100 : 0);

    final streak = StreakService.calculate(atividades, utcNow: utcNow);

    final String nivel;
    if (taxa >= 80) {
      nivel = 'Alto Desempenho';
    } else if (taxa >= 60) {
      nivel = 'Bom Desempenho';
    } else if (taxa >= 40) {
      nivel = 'Desempenho Regular';
    } else {
      nivel = 'Precisa de Foco';
    }

    final grafico = [
      for (final label in labels)
        DiaAtividade(
          label: label,
          acertos: porDia[label]!.acertos,
          erros: porDia[label]!.erros,
        ),
    ];

    return DashboardResumo(
      totalResolvidas: total,
      acertos: acertos,
      taxaAcerto: taxa,
      ofensiva: streak,
      hojeResolvidas: hojeResolvidas,
      evolucaoPercentual: evolucao,
      nivelPerformance: nivel,
      ultimos30Dias: grafico,
    );
  }
}
