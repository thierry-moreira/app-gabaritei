import '../core/time/brasilia_time.dart';
import '../core/utils/python_math.dart';
import '../models/question.dart';
import '../models/stats.dart';
import '../models/study.dart';

/// Estatísticas detalhadas por matéria/tópico (`/aluno/dashboard_detalhado`).
class StatisticsService {
  const StatisticsService._();

  static const _cores = <String>[
    '#3b82f6', '#10b981', '#ef4444', '#f59e0b', '#8b5cf6',
    '#06b6d4', '#f97316', '#ec4899', '#6366f1', '#22c55e',
    '#a855f7', '#0ea5e9', '#f43f5e', '#d946ef', '#14b8a6',
  ];

  static DashboardDetalhado build(
    List<HistoricoResposta> historico,
    Map<int, Questao> questoes, {
    int metaDiaria = 0,
    DateTime? utcNow,
  }) {
    final agoraBr = BrasiliaTime.now(utcNow: utcNow);
    final hoje = BrasiliaTime.dateOnly(agoraBr);

    final labels = <String>[];
    for (var i = 29; i >= 0; i--) {
      labels.add(
        BrasiliaTime.shortLabelFromDate(hoje.subtract(Duration(days: i))),
      );
    }
    final labelSet = labels.toSet();
    final evolucaoPorDia = <String, Map<int, int>>{
      for (final label in labels) label: <int, int>{},
    };

    final materias = <int, _MateriaAgg>{};

    for (final item in historico) {
      final questao = questoes[item.idQuestao];
      if (questao == null) continue;
      final idMateria = questao.idMateria;
      final idTopico = questao.idTopico;
      if (idMateria == null || idTopico == null) continue;

      final instante = item.criadoEm;
      final dtBr = instante == null
          ? agoraBr
          : BrasiliaTime.fromInstant(instante);
      final label = BrasiliaTime.shortLabelFromDate(dtBr);

      final materia = materias.putIfAbsent(
        idMateria,
        () => _MateriaAgg(
          id: idMateria,
          nome: questao.nomeMateria ?? 'Matéria Indefinida',
          ultima: dtBr,
        ),
      );
      materia.total++;
      if (item.isCorrect) materia.acertos++;
      if (dtBr.isAfter(materia.ultima)) materia.ultima = dtBr;

      final topico = materia.topicos.putIfAbsent(
        idTopico,
        () => _TopicoAgg(
          id: idTopico,
          nome: questao.nomeTopico ?? 'Tópico Indefinido',
        ),
      );
      topico.total++;
      if (item.isCorrect) topico.acertos++;

      if (labelSet.contains(label) && item.isCorrect) {
        final dia = evolucaoPorDia[label]!;
        dia[idMateria] = (dia[idMateria] ?? 0) + 1;
      }
    }

    final listaMaterias = <MateriaEstatistica>[];
    final pontosAtencao = <PontoAtencao>[];
    final alertas = <AlertaRevisao>[];

    for (final materia in materias.values) {
      final taxa = materia.total == 0
          ? 0
          : pythonRound((materia.acertos / materia.total) * 100);
      final diasAtraso = agoraBr.difference(materia.ultima).inDays;

      if (diasAtraso >= 4) {
        var status = 'REVISAR';
        var cor = 'warning';
        if (diasAtraso >= 8) {
          status = 'ALERTA';
          cor = 'orange';
        }
        if (diasAtraso >= 15) {
          status = 'CRÍTICO';
          cor = 'danger';
        }
        alertas.add(
          AlertaRevisao(
            idMateria: materia.id,
            nome: materia.nome,
            dias: diasAtraso,
            status: status,
            cor: cor,
          ),
        );
      }

      final topicos = <TopicoEstatistica>[];
      for (final topico in materia.topicos.values) {
        final taxaTopico = topico.total == 0
            ? 0
            : pythonRound((topico.acertos / topico.total) * 100);
        topicos.add(
          TopicoEstatistica(
            idTopico: topico.id,
            idMateria: materia.id,
            nome: topico.nome,
            acertos: topico.acertos,
            total: topico.total,
            taxa: taxaTopico,
          ),
        );
        if (taxaTopico < 60 && topico.total >= 5) {
          pontosAtencao.add(
            PontoAtencao(
              idMateria: materia.id,
              idTopico: topico.id,
              materia: materia.nome,
              topico: topico.nome,
              taxa: taxaTopico,
              total: topico.total,
            ),
          );
        }
      }
      topicos.sort((a, b) => a.taxa.compareTo(b.taxa));

      listaMaterias.add(
        MateriaEstatistica(
          idMateria: materia.id,
          nome: materia.nome,
          acertos: materia.acertos,
          total: materia.total,
          taxa: taxa,
          ultimaResolucao: materia.ultima,
          diasAtraso: diasAtraso,
          topicos: topicos,
        ),
      );
    }

    listaMaterias.sort((a, b) => b.total.compareTo(a.total));

    pontosAtencao.sort((a, b) {
      final porTaxa = a.taxa.compareTo(b.taxa);
      if (porTaxa != 0) return porTaxa;
      return b.total.compareTo(a.total);
    });
    alertas.sort((a, b) => b.dias.compareTo(a.dias));

    MateriaEstatistica? melhor;
    for (final materia in listaMaterias) {
      if (materia.total < 5 || materia.taxa < 60) continue;
      if (melhor == null ||
          materia.taxa > melhor.taxa ||
          (materia.taxa == melhor.taxa && materia.total > melhor.total)) {
        melhor = materia;
      }
    }

    final concluidosPorDia = <String, int>{};
    final primeiroDiaMes = DateTime.utc(agoraBr.year, agoraBr.month, 1);
    for (final item in historico) {
      final instante = item.criadoEm;
      if (instante == null) continue;
      final dtBr = BrasiliaTime.fromInstant(instante);
      if (!dtBr.isBefore(primeiroDiaMes)) {
        final chave =
            '${dtBr.year.toString().padLeft(4, '0')}-'
            '${dtBr.month.toString().padLeft(2, '0')}-'
            '${dtBr.day.toString().padLeft(2, '0')}';
        concluidosPorDia[chave] = (concluidosPorDia[chave] ?? 0) + 1;
      }
    }

    final evolucao = <EvolucaoMateria>[];
    for (var i = 0; i < listaMaterias.length && i < 12; i++) {
      final materia = listaMaterias[i];
      evolucao.add(
        EvolucaoMateria(
          idMateria: materia.idMateria,
          nome: materia.nome,
          cor: _cores[i % _cores.length],
          valores: [
            for (final label in labels)
              evolucaoPorDia[label]![materia.idMateria] ?? 0,
          ],
        ),
      );
    }

    final totalResolvidas = historico.length;
    final totalAcertos = historico.where((item) => item.isCorrect).length;
    final taxaGlobal = totalResolvidas > 0
        ? pythonRound((totalAcertos / totalResolvidas) * 100)
        : 0;

    return DashboardDetalhado(
      materias: listaMaterias,
      pontosAtencao: pontosAtencao.take(10).toList(growable: false),
      melhorMateria: melhor,
      evolucao: evolucao,
      labelsGrafico: labels,
      totalResolvidas: totalResolvidas,
      totalAcertos: totalAcertos,
      taxaGlobal: taxaGlobal,
      metaDiaria: metaDiaria,
      concluidosPorDia: concluidosPorDia,
      alertasRevisao: alertas.take(5).toList(growable: false),
    );
  }
}

class _MateriaAgg {
  _MateriaAgg({required this.id, required this.nome, required this.ultima});

  final int id;
  final String nome;
  DateTime ultima;
  int acertos = 0;
  int total = 0;
  final Map<int, _TopicoAgg> topicos = {};
}

class _TopicoAgg {
  _TopicoAgg({required this.id, required this.nome});

  final int id;
  final String nome;
  int acertos = 0;
  int total = 0;
}
