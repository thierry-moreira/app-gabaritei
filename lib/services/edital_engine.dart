import 'dart:math';

import '../core/utils/python_math.dart';

/// Regras puras do ciclo adaptativo de editais (`rotas/edital.py`).
class EditalEngine {
  const EditalEngine._();

  static const metaMinima = 5;
  static const metaMaxima = 30;
  static const pesoDesempenho = 0.5;
  static const penalidadeRecente = 20;
  static const penalidadeRecenteDecai = 10;
  static const bonusNovidade = 15;
  static const limiarDominio = 0.8;
  static const intervaloRevisaoDias = 3;
  static const historicoMaximo = 5;

  static const pesoMateriaMuitoRuim = 100;
  static const pesoMateriaRuim = 75;
  static const pesoMateriaRegular = 50;
  static const pesoMateriaBom = 25;

  /// Meta dinâmica de questões para o tópico atual.
  ///
  /// Sem registro → 15; nenhuma resolvida → 20; caso contrário
  /// `clamp(5, 30, round(10 + (100 - taxa%) * 0.25))`.
  static int metaDinamica({int? resolvidas, int? acertadas}) {
    if (resolvidas == null) return 15;
    if (resolvidas == 0) return 20;
    final taxa = (acertadas ?? 0) / resolvidas;
    final meta = pythonRound(10 + (100 - taxa * 100) * 0.25);
    return meta.clamp(metaMinima, metaMaxima);
  }

  /// Peso da matéria conforme a taxa de acerto (0..1).
  static int pesoMateria(double taxa) {
    if (taxa <= 0.4) return pesoMateriaMuitoRuim;
    if (taxa <= 0.6) return pesoMateriaRuim;
    if (taxa <= 0.8) return pesoMateriaRegular;
    return pesoMateriaBom;
  }

  /// Peso adaptativo do tópico.
  static double pesoTopico({
    required int idEditalTopico,
    required int resolvidas,
    required int acertadas,
    DateTime? ultimoEstudadoEm,
    List<int> historicoTopicos = const [],
    DateTime? agora,
  }) {
    var peso = 50.0;

    if (resolvidas > 0) {
      final taxa = acertadas / resolvidas;
      peso += (1.0 - taxa) * 100 * pesoDesempenho;
    } else {
      peso += bonusNovidade;
    }

    final indice = historicoTopicos.indexOf(idEditalTopico);
    if (indice == 0) {
      peso -= penalidadeRecente;
    } else if (indice == 1) {
      peso -= penalidadeRecenteDecai;
    }

    if (resolvidas > 0) {
      final taxa = acertadas / resolvidas;
      if (taxa >= limiarDominio) {
        final ultimo = ultimoEstudadoEm;
        if (ultimo != null) {
          final agoraUtc = (agora ?? DateTime.now()).toUtc();
          final diasDesde = agoraUtc.difference(ultimo.toUtc()).inDays;
          peso -= diasDesde < intervaloRevisaoDias ? 30 : 10;
        } else {
          peso -= 10;
        }
      }
    }

    return max(0, peso);
  }

  /// Sorteio proporcional usado na escolha da matéria.
  static T? escolherPonderado<T>(
    List<({T item, double peso})> candidatos,
    Random random,
  ) {
    if (candidatos.isEmpty) return null;
    if (candidatos.length == 1) return candidatos.first.item;

    final total = candidatos.fold<double>(0, (soma, c) => soma + c.peso);
    if (total <= 0) {
      return candidatos[random.nextInt(candidatos.length)].item;
    }
    final sorteio = random.nextDouble() * total;
    var acumulado = 0.0;
    for (final candidato in candidatos) {
      acumulado += candidato.peso;
      if (sorteio <= acumulado) return candidato.item;
    }
    return candidatos.last.item;
  }

  /// Matéria com maior chance de ser cobrada: peso inversamente proporcional
  /// ao desempenho. `taxas` mapeia id da matéria → taxa de acerto (0..1).
  static int? escolherProximaMateria(
    List<({int id, double taxa})> materias,
    Random random,
  ) {
    if (materias.isEmpty) return null;
    if (materias.length == 1) return materias.first.id;

    return escolherPonderado(
      [
        for (final materia in materias)
          (item: materia.id, peso: pesoMateria(materia.taxa).toDouble()),
      ],
      random,
    );
  }

  /// Escolhe o próximo tópico entre os disponíveis.
  ///
  /// Calcula os pesos, mantém os 3 maiores e sorteia proporcionalmente. O
  /// histórico é a lista dos últimos tópicos estudados (mais recente primeiro).
  static int? escolherProximoTopico(
    List<({int id, double peso})> topicos,
    Random random,
  ) {
    if (topicos.isEmpty) return null;
    final ordenados = [...topicos]
      ..sort((a, b) => b.peso.compareTo(a.peso));
    final candidatos = ordenados.take(3).toList(growable: false);
    if (candidatos.length == 1) return candidatos.first.id;
    return escolherPonderado(
      [for (final t in candidatos) (item: t.id, peso: t.peso)],
      random,
    );
  }

  /// Atualiza o histórico de tópicos como no backend (remove duplicata,
  /// insere no início e mantém no máximo 5).
  static List<int> atualizarHistorico(
    List<int> historico,
    int idTopico,
  ) {
    final novo = historico.where((id) => id != idTopico).toList();
    novo.insert(0, idTopico);
    return novo.take(historicoMaximo).toList(growable: false);
  }
}
