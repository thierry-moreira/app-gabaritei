import 'dart:math';

import '../core/utils/python_math.dart';
import '../models/question.dart';
import '../models/simulado.dart';

/// Regras puras de simulados: seleção, correção, nota e ranking.
class SimuladoService {
  const SimuladoService._();

  /// Confere se o usuário pode acessar o simulado (privado só para o criador).
  static bool podeAcessar(Simulado simulado, int idUsuario) =>
      !simulado.ehPrivado || simulado.idCriador == idUsuario;

  /// Sorteia até [quantidade] questões, sem reposição (como `random.sample`).
  static List<T> amostrar<T>(List<T> pool, int quantidade, Random random) {
    if (quantidade <= 0 || pool.isEmpty) return const [];
    if (pool.length <= quantidade) return List<T>.of(pool);
    final copia = List<T>.of(pool);
    for (var i = 0; i < quantidade; i++) {
      final j = i + random.nextInt(copia.length - i);
      final temp = copia[i];
      copia[i] = copia[j];
      copia[j] = temp;
    }
    return copia.take(quantidade).toList(growable: false);
  }

  /// Extrai a letra correta de uma lista de alternativas.
  static String? letraCorreta(List<Alternativa> alternativas) {
    for (final alternativa in alternativas) {
      if (alternativa.isCorrect) return alternativa.letra;
    }
    return null;
  }

  /// Corrige as respostas do formulário do simulado.
  ///
  /// [respostas] mapeia id da questão → letra marcada (null quando em branco).
  /// A nota é `acertos / total * 10`, arredondada a 2 casas com banker's
  /// rounding — igual a `round(nota, 2)` no Python.
  static SimuladoResultado corrigir({
    required List<int> idsQuestoes,
    required Map<int, String> gabaritos,
    required Map<int, String?> respostas,
    List<RankingEntry> ranking = const [],
  }) {
    final detalhes = <DetalheResposta>[];
    var acertos = 0;

    for (final id in idsQuestoes) {
      final correta = gabaritos[id];
      final marcada = respostas[id];
      final correto = correta != null && marcada == correta;
      if (correto) acertos++;
      detalhes.add(
        DetalheResposta(
          idQuestao: id,
          respostaAluno: marcada,
          respostaCorreta: correta,
          correto: correto,
        ),
      );
    }

    final total = idsQuestoes.length;
    final nota = total > 0 ? pythonRoundTo((acertos / total) * 10, 2) : 0.0;

    return SimuladoResultado(
      nota: nota,
      acertos: acertos,
      total: total,
      detalhes: detalhes,
      ranking: ranking.take(10).toList(growable: false),
    );
  }

  static List<RankingEntry> top10(List<RankingEntry> ranking) =>
      ranking.take(10).toList(growable: false);
}
