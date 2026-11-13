import 'package:test/test.dart';
import 'dart:math';
import 'package:gabaritei_app/services/simulado_service.dart';
import 'package:gabaritei_app/models/question.dart';
import 'package:gabaritei_app/models/simulado.dart';

void main() {
  group('SimuladoService.podeAcessar', () {
    test('público -> true para qualquer usuário', () {
      final simulado = Simulado(id: '1', titulo: 'Público', ehPrivado: false);
      expect(SimuladoService.podeAcessar(simulado, 1), true);
      expect(SimuladoService.podeAcessar(simulado, 999), true);
    });

    test('privado -> true só para criador', () {
      final simulado = Simulado(id: '1', titulo: 'Privado', ehPrivado: true, idCriador: 42);
      expect(SimuladoService.podeAcessar(simulado, 42), true);
      expect(SimuladoService.podeAcessar(simulado, 1), false);
    });
  });

  group('SimuladoService.amostrar', () {
    final random = Random(42);

    test('quantidade <= 0 -> vazio', () {
      expect(SimuladoService.amostrar([1, 2, 3], 0, random), isEmpty);
      expect(SimuladoService.amostrar([1, 2, 3], -1, random), isEmpty);
    });

    test('pool vazio -> vazio', () {
      expect(SimuladoService.amostrar<int>([], 5, random), isEmpty);
    });

    test('quantidade >= pool -> retorna todos (ordem aleatória)', () {
      final pool = [1, 2, 3];
      final resultado = SimuladoService.amostrar(pool, 5, random);
      expect(resultado.length, 3);
      expect(resultado.toSet(), pool.toSet());
    });

    test('quantidade < pool -> retorna exatamente quantidade itens únicos', () {
      final pool = List.generate(100, (i) => i);
      final resultado = SimuladoService.amostrar(pool, 10, random);
      expect(resultado.length, 10);
      expect(resultado.toSet().length, 10); // sem duplicatas
      for (final item in resultado) {
        expect(pool.contains(item), true);
      }
    });

    test('não modifica pool original', () {
      final pool = [1, 2, 3, 4, 5];
      SimuladoService.amostrar(pool, 3, random);
      expect(pool, [1, 2, 3, 4, 5]);
    });
  });

  group('SimuladoService.letraCorreta', () {
    test('retorna letra da alternativa correta', () {
      final alternativas = [
        Alternativa(id: 1, idQuestao: 1, letra: 'A', texto: 'A', isCorrect: false),
        Alternativa(id: 2, idQuestao: 1, letra: 'B', texto: 'B', isCorrect: true),
        Alternativa(id: 3, idQuestao: 1, letra: 'C', texto: 'C', isCorrect: false),
      ];
      expect(SimuladoService.letraCorreta(alternativas), 'B');
    });

    test('null se nenhuma correta', () {
      final alternativas = [
        Alternativa(id: 1, idQuestao: 1, letra: 'A', texto: 'A', isCorrect: false),
        Alternativa(id: 2, idQuestao: 1, letra: 'B', texto: 'B', isCorrect: false),
      ];
      expect(SimuladoService.letraCorreta(alternativas), null);
    });

    test('primeira correta se múltiplas (não deve acontecer)', () {
      final alternativas = [
        Alternativa(id: 1, idQuestao: 1, letra: 'A', texto: 'A', isCorrect: true),
        Alternativa(id: 2, idQuestao: 1, letra: 'B', texto: 'B', isCorrect: true),
      ];
      expect(SimuladoService.letraCorreta(alternativas), 'A');
    });
  });

  group('SimuladoService.corrigir', () {
    test('todas corretas -> nota 10.0', () {
      final ids = [1, 2, 3];
      final gabaritos = {1: 'A', 2: 'B', 3: 'C'};
      final respostas = {1: 'A', 2: 'B', 3: 'C'};
      final resultado = SimuladoService.corrigir(
        idsQuestoes: ids,
        gabaritos: gabaritos,
        respostas: respostas,
      );
      expect(resultado.acertos, 3);
      expect(resultado.total, 3);
      expect(resultado.nota, 10.0);
      expect(resultado.percentual, 100.0);
    });

    test('todas erradas -> nota 0.0', () {
      final ids = [1, 2, 3];
      final gabaritos = {1: 'A', 2: 'B', 3: 'C'};
      final respostas = {1: 'B', 2: 'C', 3: 'A'};
      final resultado = SimuladoService.corrigir(
        idsQuestoes: ids,
        gabaritos: gabaritos,
        respostas: respostas,
      );
      expect(resultado.acertos, 0);
      expect(resultado.nota, 0.0);
    });

    test('metade correta -> nota 5.0', () {
      final ids = [1, 2, 3, 4];
      final gabaritos = {1: 'A', 2: 'B', 3: 'C', 4: 'D'};
      final respostas = {1: 'A', 2: 'B', 3: 'A', 4: 'B'};
      final resultado = SimuladoService.corrigir(
        idsQuestoes: ids,
        gabaritos: gabaritos,
        respostas: respostas,
      );
      expect(resultado.acertos, 2);
      expect(resultado.nota, 5.0);
    });

    test('resposta null (em branco) conta como erro', () {
      final ids = [1, 2];
      final gabaritos = {1: 'A', 2: 'B'};
      final respostas = {1: 'A', 2: null};
      final resultado = SimuladoService.corrigir(
        idsQuestoes: ids,
        gabaritos: gabaritos,
        respostas: respostas,
      );
      expect(resultado.acertos, 1);
      expect(resultado.detalhes[1].respostaAluno, null);
      expect(resultado.detalhes[1].correto, false);
    });

    test('questão sem gabarito -> erro', () {
      final ids = [1, 2];
      final gabaritos = {1: 'A'}; // 2 falta
      final respostas = {1: 'A', 2: 'B'};
      final resultado = SimuladoService.corrigir(
        idsQuestoes: ids,
        gabaritos: gabaritos,
        respostas: respostas,
      );
      expect(resultado.acertos, 1);
      expect(resultado.detalhes[1].respostaCorreta, null);
      expect(resultado.detalhes[1].correto, false);
    });

    test('nota com banker\'s rounding 2 casas', () {
      // 1 acerto em 3 -> 3.333... -> round 2 casas = 3.33
      final ids = [1, 2, 3];
      final gabaritos = {1: 'A', 2: 'B', 3: 'C'};
      final respostas = {1: 'A', 2: 'X', 3: 'Y'};
      final resultado = SimuladoService.corrigir(
        idsQuestoes: ids,
        gabaritos: gabaritos,
        respostas: respostas,
      );
      expect(resultado.nota, 3.33);
    });

    test('2 acertos em 3 -> 6.666... -> 6.67', () {
      final ids = [1, 2, 3];
      final gabaritos = {1: 'A', 2: 'B', 3: 'C'};
      final respostas = {1: 'A', 2: 'B', 3: 'X'};
      final resultado = SimuladoService.corrigir(
        idsQuestoes: ids,
        gabaritos: gabaritos,
        respostas: respostas,
      );
      expect(resultado.nota, 6.67);
    });

    test('inclui ranking top 10', () {
      final ids = [1];
      final gabaritos = {1: 'A'};
      final respostas = {1: 'A'};
      final ranking = List.generate(15, (i) => RankingEntry(
        nomeUsuario: 'User$i',
        nota: (10 - i * 0.5),
        respostasCorretas: 10 - i,
        totalQuestoes: 10,
      ));
      final resultado = SimuladoService.corrigir(
        idsQuestoes: ids,
        gabaritos: gabaritos,
        respostas: respostas,
        ranking: ranking,
      );
      expect(resultado.ranking.length, 10);
    });

    test('top10 helper', () {
      final ranking = List.generate(15, (i) => RankingEntry(
        nomeUsuario: 'User$i',
        nota: 10.0 - i * 0.5,
        respostasCorretas: 10 - i,
        totalQuestoes: 10,
      ));
      final top = SimuladoService.top10(ranking);
      expect(top.length, 10);
    });
  });
}