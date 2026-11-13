import 'package:test/test.dart';
import 'package:gabaritei_app/core/time/brasilia_time.dart';
import 'package:gabaritei_app/services/statistics_service.dart';
import 'package:gabaritei_app/models/question.dart';
import 'package:gabaritei_app/models/study.dart';

void main() {
  final utcNow = DateTime.utc(2025, 1, 15, 12, 0, 0);
  final hojeBr = BrasiliaTime.today(utcNow: utcNow);

  DateTime instantFromBr(DateTime diaBr, {int hour = 9}) {
    return diaBr.add(Duration(hours: 3 + hour));
  }

  Questao makeQuestao({
    required int id,
    required int idMateria,
    required int idTopico,
    String nomeMateria = 'Matéria',
    String nomeTopico = 'Tópico',
  }) {
    return Questao(
      id: id,
      enunciado: 'Enunciado $id',
      idMateria: idMateria,
      nomeMateria: nomeMateria,
      idTopico: idTopico,
      nomeTopico: nomeTopico,
    );
  }

  group('StatisticsService.build', () {
    test('histórico vazio -> estrutura vazia', () {
      final detalhado = StatisticsService.build([], {}, utcNow: utcNow);
      expect(detalhado.materias, isEmpty);
      expect(detalhado.pontosAtencao, isEmpty);
      expect(detalhado.melhorMateria, null);
      expect(detalhado.evolucao, isEmpty);
      expect(detalhado.labelsGrafico.length, 30);
      expect(detalhado.totalResolvidas, 0);
      expect(detalhado.totalAcertos, 0);
      expect(detalhado.taxaGlobal, 0);
      expect(detalhado.concluidosPorDia, isEmpty);
      expect(detalhado.alertasRevisao, isEmpty);
    });

    test('agrupa por matéria e tópico', () {
      final q1 = makeQuestao(id: 1, idMateria: 1, idTopico: 10, nomeMateria: 'Português', nomeTopico: 'Gramática');
      final q2 = makeQuestao(id: 2, idMateria: 1, idTopico: 11, nomeMateria: 'Português', nomeTopico: 'Interpretação');
      final q3 = makeQuestao(id: 3, idMateria: 2, idTopico: 20, nomeMateria: 'Matemática', nomeTopico: 'Álgebra');

      final historico = [
        HistoricoResposta(idQuestao: 1, isCorrect: true, criadoEm: instantFromBr(hojeBr)),
        HistoricoResposta(idQuestao: 2, isCorrect: false, criadoEm: instantFromBr(hojeBr)),
        HistoricoResposta(idQuestao: 3, isCorrect: true, criadoEm: instantFromBr(hojeBr)),
      ];
      final questoes = {1: q1, 2: q2, 3: q3};

      final detalhado = StatisticsService.build(historico, questoes, utcNow: utcNow);

      expect(detalhado.materias.length, 2);
      final port = detalhado.materias.firstWhere((m) => m.nome == 'Português');
      expect(port.total, 2);
      expect(port.acertos, 1);
      expect(port.taxa, 50); // round(50) = 50
      expect(port.topicos.length, 2);

      final mat = detalhado.materias.firstWhere((m) => m.nome == 'Matemática');
      expect(mat.total, 1);
      expect(mat.acertos, 1);
      expect(mat.taxa, 100);
    });

    test('ordena matérias por total desc', () {
      final q1 = makeQuestao(id: 1, idMateria: 1, idTopico: 10, nomeMateria: 'Matéria A');
      final q2 = makeQuestao(id: 2, idMateria: 2, idTopico: 20, nomeMateria: 'Matéria B');
      final q3 = makeQuestao(id: 3, idMateria: 2, idTopico: 21, nomeMateria: 'Matéria B');

      final historico = [
        HistoricoResposta(idQuestao: 1, isCorrect: true, criadoEm: instantFromBr(hojeBr)),
        HistoricoResposta(idQuestao: 2, isCorrect: true, criadoEm: instantFromBr(hojeBr)),
        HistoricoResposta(idQuestao: 3, isCorrect: true, criadoEm: instantFromBr(hojeBr)),
      ];
      final questoes = {1: q1, 2: q2, 3: q3};

      final detalhado = StatisticsService.build(historico, questoes, utcNow: utcNow);
      expect(detalhado.materias[0].nome, 'Matéria B'); // total 2
      expect(detalhado.materias[1].nome, 'Matéria A'); // total 1
    });

    test('pontosAtencao: taxa < 60 e total >= 5, ordena por taxa asc depois total desc', () {
      final q1 = makeQuestao(id: 1, idMateria: 1, idTopico: 10, nomeMateria: 'Matéria 1', nomeTopico: 'T1'); // 40%, 10 questoes
      final q2 = makeQuestao(id: 2, idMateria: 1, idTopico: 11, nomeMateria: 'Matéria 1', nomeTopico: 'T2'); // 50%, 10 questoes
      final q3 = makeQuestao(id: 3, idMateria: 2, idTopico: 20, nomeMateria: 'Matéria 2', nomeTopico: 'T3'); // 30%, 20 questoes

      final historico = [
        ...List.generate(4, (i) => HistoricoResposta(idQuestao: 1, isCorrect: true, criadoEm: instantFromBr(hojeBr))),
        ...List.generate(6, (i) => HistoricoResposta(idQuestao: 1, isCorrect: false, criadoEm: instantFromBr(hojeBr))),
        ...List.generate(5, (i) => HistoricoResposta(idQuestao: 2, isCorrect: true, criadoEm: instantFromBr(hojeBr))),
        ...List.generate(5, (i) => HistoricoResposta(idQuestao: 2, isCorrect: false, criadoEm: instantFromBr(hojeBr))),
        ...List.generate(6, (i) => HistoricoResposta(idQuestao: 3, isCorrect: true, criadoEm: instantFromBr(hojeBr))),
        ...List.generate(14, (i) => HistoricoResposta(idQuestao: 3, isCorrect: false, criadoEm: instantFromBr(hojeBr))),
      ];
      final questoes = {1: q1, 2: q2, 3: q3};

      final detalhado = StatisticsService.build(historico, questoes, utcNow: utcNow);
      // T1: 4/10 = 40%, T2: 5/10 = 50%, T3: 6/20 = 30%
      expect(detalhado.pontosAtencao.length, 3);
      expect(detalhado.pontosAtencao[0].topico, 'T3'); // 30% menor taxa
      expect(detalhado.pontosAtencao[1].topico, 'T1'); // 40%
      expect(detalhado.pontosAtencao[2].topico, 'T2'); // 50%
    });

    test('pontosAtencao limitado a 10', () {
      final historico = <HistoricoResposta>[];
      final questoes = <int, Questao>{};
      for (var m = 1; m <= 15; m++) {
        final q = makeQuestao(id: m, idMateria: 1, idTopico: m, nomeMateria: 'Matéria', nomeTopico: 'T$m');
        questoes[m] = q;
        // 3 acertos, 7 erros = 30%
        historico.addAll(List.generate(3, (i) => HistoricoResposta(idQuestao: m, isCorrect: true, criadoEm: instantFromBr(hojeBr))));
        historico.addAll(List.generate(7, (i) => HistoricoResposta(idQuestao: m, isCorrect: false, criadoEm: instantFromBr(hojeBr))));
      }
      final detalhado = StatisticsService.build(historico, questoes, utcNow: utcNow);
      expect(detalhado.pontosAtencao.length, 10);
    });

    test('alertasRevisao: dias >= 4 -> REVISAR warning, >= 8 -> ALERTA orange, >= 15 -> CRÍTICO danger', () {
      final q1 = makeQuestao(id: 1, idMateria: 1, idTopico: 10); // 3 dias
      final q2 = makeQuestao(id: 2, idMateria: 2, idTopico: 20); // 7 dias
      final q3 = makeQuestao(id: 3, idMateria: 3, idTopico: 30); // 14 dias
      final q4 = makeQuestao(id: 4, idMateria: 4, idTopico: 40); // 16 dias

      final historico = [
        HistoricoResposta(idQuestao: 1, isCorrect: true, criadoEm: instantFromBr(hojeBr.subtract(const Duration(days: 3)))),
        HistoricoResposta(idQuestao: 2, isCorrect: true, criadoEm: instantFromBr(hojeBr.subtract(const Duration(days: 7)))),
        HistoricoResposta(idQuestao: 3, isCorrect: true, criadoEm: instantFromBr(hojeBr.subtract(const Duration(days: 14)))),
        HistoricoResposta(idQuestao: 4, isCorrect: true, criadoEm: instantFromBr(hojeBr.subtract(const Duration(days: 16)))),
      ];
      final questoes = {1: q1, 2: q2, 3: q3, 4: q4};

      final detalhado = StatisticsService.build(historico, questoes, utcNow: utcNow);
      expect(detalhado.alertasRevisao.length, 3); // q1 não aparece (< 4 dias)
      expect(detalhado.alertasRevisao[0].status, 'CRÍTICO'); // 16 dias
      expect(detalhado.alertasRevisao[0].cor, 'danger');
      expect(detalhado.alertasRevisao[1].status, 'ALERTA'); // 14 dias
      expect(detalhado.alertasRevisao[1].cor, 'orange');
      expect(detalhado.alertasRevisao[2].status, 'REVISAR'); // 7 dias
      expect(detalhado.alertasRevisao[2].cor, 'warning');
    });

    test('alertasRevisao limitado a 5', () {
      final historico = <HistoricoResposta>[];
      final questoes = <int, Questao>{};
      for (var m = 1; m <= 10; m++) {
        final q = makeQuestao(id: m, idMateria: m, idTopico: m);
        questoes[m] = q;
        historico.add(HistoricoResposta(idQuestao: m, isCorrect: true, criadoEm: instantFromBr(hojeBr.subtract(const Duration(days: 20)))));
      }
      final detalhado = StatisticsService.build(historico, questoes, utcNow: utcNow);
      expect(detalhado.alertasRevisao.length, 5);
    });

    test('melhorMateria: total >= 5 e taxa >= 60, maior taxa, desempate por total', () {
      final q1 = makeQuestao(id: 1, idMateria: 1, idTopico: 10, nomeMateria: 'Matéria A'); // 100%, 10 total
      final q2 = makeQuestao(id: 2, idMateria: 2, idTopico: 20, nomeMateria: 'Matéria B'); // 80%, 20 total
      final q3 = makeQuestao(id: 3, idMateria: 3, idTopico: 30, nomeMateria: 'Matéria C'); // 50%, 10 total (taxa < 60)
      final q4 = makeQuestao(id: 4, idMateria: 4, idTopico: 40, nomeMateria: 'Matéria D'); // 80%, 10 total (empate taxa, menos total)

      final historico = [
        ...List.generate(10, (i) => HistoricoResposta(idQuestao: 1, isCorrect: true, criadoEm: instantFromBr(hojeBr))),
        ...List.generate(16, (i) => HistoricoResposta(idQuestao: 2, isCorrect: true, criadoEm: instantFromBr(hojeBr))),
        ...List.generate(4, (i) => HistoricoResposta(idQuestao: 2, isCorrect: false, criadoEm: instantFromBr(hojeBr))),
        ...List.generate(5, (i) => HistoricoResposta(idQuestao: 3, isCorrect: true, criadoEm: instantFromBr(hojeBr))),
        ...List.generate(5, (i) => HistoricoResposta(idQuestao: 3, isCorrect: false, criadoEm: instantFromBr(hojeBr))),
        ...List.generate(8, (i) => HistoricoResposta(idQuestao: 4, isCorrect: true, criadoEm: instantFromBr(hojeBr))),
        ...List.generate(2, (i) => HistoricoResposta(idQuestao: 4, isCorrect: false, criadoEm: instantFromBr(hojeBr))),
      ];
      final questoes = {1: q1, 2: q2, 3: q3, 4: q4};

      final detalhado = StatisticsService.build(historico, questoes, utcNow: utcNow);
      expect(detalhado.melhorMateria!.nome, 'Matéria A'); // 100% > 80%
    });

    test('evolucao: top 12 matérias, valores por dia nos últimos 30', () {
      final q1 = makeQuestao(id: 1, idMateria: 1, idTopico: 10);
      final historico = [
        HistoricoResposta(idQuestao: 1, isCorrect: true, criadoEm: instantFromBr(hojeBr)),
        HistoricoResposta(idQuestao: 1, isCorrect: true, criadoEm: instantFromBr(hojeBr.subtract(const Duration(days: 5)))),
      ];
      final questoes = {1: q1};

      final detalhado = StatisticsService.build(historico, questoes, utcNow: utcNow);
      expect(detalhado.evolucao.length, 1);
      expect(detalhado.evolucao[0].valores.length, 30);
      // Hoje e 5 dias atrás devem ter 1
      final idxHoje = 29; // último índice
      final idx5dias = 24;
      expect(detalhado.evolucao[0].valores[idxHoje], 1);
      expect(detalhado.evolucao[0].valores[idx5dias], 1);
    });

    test('concluidosPorDia: apenas mês atual', () {
      final q1 = makeQuestao(id: 1, idMateria: 1, idTopico: 10);
      final mesPassado = DateTime.utc(2024, 12, 20);
      final historico = [
        HistoricoResposta(idQuestao: 1, isCorrect: true, criadoEm: instantFromBr(hojeBr)),
        HistoricoResposta(idQuestao: 1, isCorrect: true, criadoEm: mesPassado),
      ];
      final questoes = {1: q1};

      final detalhado = StatisticsService.build(historico, questoes, utcNow: utcNow);
      expect(detalhado.concluidosPorDia.length, 1);
      final chaveHoje = '${hojeBr.year.toString().padLeft(4, '0')}-${hojeBr.month.toString().padLeft(2, '0')}-${hojeBr.day.toString().padLeft(2, '0')}';
      expect(detalhado.concluidosPorDia[chaveHoje], 1);
    });

    test('questões sem idMateria/idTopico são ignoradas', () {
      final q1 = makeQuestao(id: 1, idMateria: 1, idTopico: 10);
      final q2 = Questao(id: 2, enunciado: 'Sem matéria', idMateria: null, idTopico: null);

      final historico = [
        HistoricoResposta(idQuestao: 1, isCorrect: true, criadoEm: instantFromBr(hojeBr)),
        HistoricoResposta(idQuestao: 2, isCorrect: true, criadoEm: instantFromBr(hojeBr)),
      ];
      final questoes = {1: q1, 2: q2};

      final detalhado = StatisticsService.build(historico, questoes, utcNow: utcNow);
      expect(detalhado.materias.length, 1);
      expect(detalhado.totalResolvidas, 2); // total conta tudo
      expect(detalhado.totalAcertos, 2);
    });
  });
}