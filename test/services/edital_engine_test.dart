import 'package:test/test.dart';
import 'dart:math';
import 'package:gabaritei_app/services/edital_engine.dart';

void main() {
  group('EditalEngine.metaDinamica', () {
    test('sem registro (resolvidas null) -> 15', () {
      expect(EditalEngine.metaDinamica(resolvidas: null, acertadas: null), 15);
    });

    test('resolvidas = 0 -> 20', () {
      expect(EditalEngine.metaDinamica(resolvidas: 0, acertadas: 0), 20);
    });

    test('taxa 100% -> clamp(5, 30, round(10 + 0)) = 10', () {
      expect(EditalEngine.metaDinamica(resolvidas: 10, acertadas: 10), 10);
    });

    test('taxa 80% -> clamp(5, 30, round(10 + 20 * 0.25)) = 15', () {
      expect(EditalEngine.metaDinamica(resolvidas: 10, acertadas: 8), 15);
    });

    test('taxa 50% -> clamp(5, 30, round(10 + 50 * 0.25)) = 22 (banker: 22.5 -> 22)', () {
      expect(EditalEngine.metaDinamica(resolvidas: 10, acertadas: 5), 22);
    });

    test('taxa 0% -> clamp(5, 30, round(10 + 100 * 0.25)) = 30 (max)', () {
      expect(EditalEngine.metaDinamica(resolvidas: 10, acertadas: 0), 30);
    });

    test('resolvidas null mas acertadas presente -> 15', () {
      expect(EditalEngine.metaDinamica(resolvidas: null, acertadas: 5), 15);
    });
  });

  group('EditalEngine.pesoMateria', () {
    test('taxa <= 0.4 -> 100', () {
      expect(EditalEngine.pesoMateria(0.0), 100);
      expect(EditalEngine.pesoMateria(0.3), 100);
      expect(EditalEngine.pesoMateria(0.4), 100);
    });

    test('taxa <= 0.6 -> 75', () {
      expect(EditalEngine.pesoMateria(0.41), 75);
      expect(EditalEngine.pesoMateria(0.5), 75);
      expect(EditalEngine.pesoMateria(0.6), 75);
    });

    test('taxa <= 0.8 -> 50', () {
      expect(EditalEngine.pesoMateria(0.61), 50);
      expect(EditalEngine.pesoMateria(0.7), 50);
      expect(EditalEngine.pesoMateria(0.8), 50);
    });

    test('taxa > 0.8 -> 25', () {
      expect(EditalEngine.pesoMateria(0.81), 25);
      expect(EditalEngine.pesoMateria(0.9), 25);
      expect(EditalEngine.pesoMateria(1.0), 25);
    });
  });

  group('EditalEngine.pesoTopico', () {
    final agora = DateTime.utc(2025, 1, 15, 12, 0, 0);

    test('sem resolvidas -> 50 + bonusNovidade(15) = 65', () {
      expect(EditalEngine.pesoTopico(
        idEditalTopico: 1,
        resolvidas: 0,
        acertadas: 0,
        agora: agora,
      ), 65);
    });

    test('com resolvidas, adiciona (1 - taxa) * 100 * 0.5', () {
      // taxa = 0.5 -> (1 - 0.5) * 100 * 0.5 = 25 -> 50 + 25 = 75
      expect(EditalEngine.pesoTopico(
        idEditalTopico: 1,
        resolvidas: 10,
        acertadas: 5,
        agora: agora,
      ), 75);
    });

    test('tópico no índice 0 do histórico -> -20', () {
      expect(EditalEngine.pesoTopico(
        idEditalTopico: 1,
        resolvidas: 10,
        acertadas: 5,
        historicoTopicos: [1],
        agora: agora,
      ), 55); // 75 - 20
    });

    test('tópico no índice 1 do histórico -> -10', () {
      expect(EditalEngine.pesoTopico(
        idEditalTopico: 2,
        resolvidas: 10,
        acertadas: 5,
        historicoTopicos: [1, 2],
        agora: agora,
      ), 65); // 75 - 10
    });

    test('tópico no índice >= 2 não tem penalidade', () {
      expect(EditalEngine.pesoTopico(
        idEditalTopico: 3,
        resolvidas: 10,
        acertadas: 5,
        historicoTopicos: [1, 2, 3],
        agora: agora,
      ), 75);
    });

    test('taxa >= 0.8 e estudado há < 3 dias -> -30', () {
      final ontem = agora.subtract(const Duration(days: 1));
      // Base 50 + desempenho 5 = 55, -30 = 25
      expect(EditalEngine.pesoTopico(
        idEditalTopico: 1,
        resolvidas: 10,
        acertadas: 9, // taxa 0.9 >= 0.8
        ultimoEstudadoEm: ontem,
        agora: agora,
      ), 25);
    });

    test('taxa >= 0.8 e estudado há >= 3 dias -> -10', () {
      final quatroDias = agora.subtract(const Duration(days: 4));
      // Base 50 + desempenho 10 = 60, -10 = 50
      expect(EditalEngine.pesoTopico(
        idEditalTopico: 1,
        resolvidas: 10,
        acertadas: 8, // taxa 0.8 >= 0.8
        ultimoEstudadoEm: quatroDias,
        agora: agora,
      ), 50);
    });

    test('taxa < 0.8 não tem penalidade de domínio', () {
      // Base 50 + desempenho 15 = 65
      expect(EditalEngine.pesoTopico(
        idEditalTopico: 1,
        resolvidas: 10,
        acertadas: 7, // taxa 0.7 < 0.8
        ultimoEstudadoEm: agora.subtract(const Duration(days: 1)),
        agora: agora,
      ), 65);
    });

    test('peso nunca negativo', () {
      // Base 50 + bonus 15 = 65, histórico índice 0 -> -20 = 45
      expect(EditalEngine.pesoTopico(
        idEditalTopico: 1,
        resolvidas: 0,
        acertadas: 0,
        historicoTopicos: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
        agora: agora,
      ), 45);
    });
  });

  group('EditalEngine.escolherPonderado', () {
    final random = Random(42); // seed fixo

    test('lista vazia -> null', () {
      expect(EditalEngine.escolherPonderado([], random), null);
    });

    test('um item -> esse item', () {
      expect(EditalEngine.escolherPonderado([(item: 'a', peso: 10.0)], random), 'a');
    });

    test('pesos iguais -> distribuição uniforme', () {
      const candidatos = [
        (item: 'a', peso: 10.0),
        (item: 'b', peso: 10.0),
      ];
      final counts = <String, int>{};
      for (var i = 0; i < 10000; i++) {
        final escolha = EditalEngine.escolherPonderado(candidatos, random);
        counts[escolha!] = (counts[escolha] ?? 0) + 1;
      }
      expect(counts['a']!, greaterThan(4500));
      expect(counts['a']!, lessThan(5500));
    });

    test('pesos diferentes -> proporcional', () {
      const candidatos = [
        (item: 'a', peso: 10.0),
        (item: 'b', peso: 90.0),
      ];
      final counts = <String, int>{};
      for (var i = 0; i < 10000; i++) {
        final escolha = EditalEngine.escolherPonderado(candidatos, random);
        counts[escolha!] = (counts[escolha] ?? 0) + 1;
      }
      expect(counts['b']!, greaterThan(8500));
      expect(counts['b']!, lessThan(9500));
    });

    test('peso total <= 0 -> escolha aleatória uniforme', () {
      const candidatos = [
        (item: 'a', peso: 0.0),
        (item: 'b', peso: 0.0),
        (item: 'c', peso: 0.0),
      ];
      final counts = <String, int>{};
      for (var i = 0; i < 9000; i++) {
        final escolha = EditalEngine.escolherPonderado(candidatos, random);
        counts[escolha!] = (counts[escolha] ?? 0) + 1;
      }
      expect(counts['a']!, greaterThan(2500));
      expect(counts['a']!, lessThan(3500));
    });
  });

  group('EditalEngine.escolherProximaMateria', () {
    final random = Random(42);

    test('lista vazia -> null', () {
      expect(EditalEngine.escolherProximaMateria([], random), null);
    });

    test('uma matéria -> essa matéria', () {
      expect(EditalEngine.escolherProximaMateria([(id: 1, taxa: 0.5)], random), 1);
    });

    test('usa pesoMateria inversamente proporcional à taxa', () {
      // Matéria 1: taxa 0.3 -> peso 100
      // Matéria 2: taxa 0.7 -> peso 50
      // Matéria 1 deve ser escolhida ~2/3 das vezes
      const materias = [
        (id: 1, taxa: 0.3),
        (id: 2, taxa: 0.7),
      ];
      final counts = <int, int>{};
      for (var i = 0; i < 10000; i++) {
        final escolha = EditalEngine.escolherProximaMateria(materias, random);
        counts[escolha!] = (counts[escolha] ?? 0) + 1;
      }
      expect(counts[1]!, greaterThan(6000));
      expect(counts[1]!, lessThan(7200));
    });
  });

  group('EditalEngine.escolherProximoTopico', () {
    final random = Random(42);

    test('lista vazia -> null', () {
      expect(EditalEngine.escolherProximoTopico([], random), null);
    });

    test('um tópico -> esse tópico', () {
      expect(EditalEngine.escolherProximoTopico([(id: 1, peso: 10.0)], random), 1);
    });

    test('mantém top 3 e sorteia entre eles', () {
      const topicos = [
        (id: 1, peso: 100.0),
        (id: 2, peso: 90.0),
        (id: 3, peso: 80.0),
        (id: 4, peso: 70.0), // 4º, deve ser ignorado
        (id: 5, peso: 60.0), // 5º, ignorado
      ];
      final counts = <int, int>{};
      for (var i = 0; i < 10000; i++) {
        final escolha = EditalEngine.escolherProximoTopico(topicos, random);
        counts[escolha!] = (counts[escolha] ?? 0) + 1;
      }
      expect(counts.containsKey(4), false);
      expect(counts.containsKey(5), false);
      expect(counts[1]!, greaterThan(counts[2]!));
      expect(counts[2]!, greaterThan(counts[3]!));
    });
  });

  group('EditalEngine.atualizarHistorico', () {
    test('insere no início e remove duplicata', () {
      expect(
        EditalEngine.atualizarHistorico([1, 2, 3], 2),
        [2, 1, 3],
      );
    });

    test('novo tópico vai para o início', () {
      expect(
        EditalEngine.atualizarHistorico([1, 2], 3),
        [3, 1, 2],
      );
    });

    test('mantém no máximo 5 itens', () {
      expect(
        EditalEngine.atualizarHistorico([1, 2, 3, 4, 5], 6),
        [6, 1, 2, 3, 4],
      );
    });

    test('lista vazia -> lista com o item', () {
      expect(EditalEngine.atualizarHistorico([], 1), [1]);
    });
  });
}