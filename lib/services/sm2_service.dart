/// Repetição espaçada SM-2 simplificada, idêntica a `rotas/flashcards.py`.
class Sm2Result {
  const Sm2Result({
    required this.intervalo,
    required this.facilidade,
    required this.proximaRevisao,
  });

  final int intervalo;
  final double facilidade;
  final DateTime proximaRevisao;
}

class Sm2Service {
  const Sm2Service._();

  static const facilidadeMinima = 1.3;
  static const facilidadeMaxima = 2.5;

  /// Qualidades: 0 = errei, 1 = difícil, 2 = bom, 3 = fácil.
  static Sm2Result revisar({
    required int intervaloAtual,
    required double facilidadeAtual,
    required int qualidade,
    DateTime? agora,
  }) {
    if (qualidade < 0 || qualidade > 3) {
      throw ArgumentError.value(qualidade, 'qualidade', 'Use 0, 1, 2 ou 3.');
    }

    final intervalo = intervaloAtual.toDouble();
    final facilidade = facilidadeAtual;
    final int novoIntervalo;
    final double novaFacilidade;

    switch (qualidade) {
      case 0:
        novoIntervalo = 0;
        novaFacilidade = _max(facilidadeMinima, facilidade - 0.2);
      case 1:
        novoIntervalo = _maxInt(1, (intervalo * 1.2).toInt());
        novaFacilidade = _max(facilidadeMinima, facilidade - 0.15);
      case 2:
        if (intervalo == 0) {
          novoIntervalo = 1;
        } else if (intervalo == 1) {
          novoIntervalo = 4;
        } else {
          novoIntervalo = (intervalo * facilidade).toInt();
        }
        novaFacilidade = facilidade;
      default:
        novoIntervalo = intervalo <= 1
            ? 7
            : (intervalo * facilidade * 1.3).toInt();
        novaFacilidade = _min(
          facilidadeMaxima,
          facilidade + 0.15,
        );
    }

    final base = agora ?? DateTime.now();
    return Sm2Result(
      intervalo: novoIntervalo,
      facilidade: novaFacilidade,
      proximaRevisao: base.add(Duration(days: novoIntervalo)),
    );
  }

  static double _max(double a, double b) => a > b ? a : b;
  static double _min(double a, double b) => a < b ? a : b;
  static int _maxInt(int a, int b) => a > b ? a : b;
}
