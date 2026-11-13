import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gabaritei_app/models/question.dart';
import 'package:gabaritei_app/models/simulado.dart';
import 'package:gabaritei_app/services/simulado_print_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const prova = SimuladoComQuestoes(
    simulado: Simulado(id: 'sim-pdf', titulo: 'Prova de Direito'),
    questoes: [
      Questao(
        id: 1,
        enunciado: 'Qual alternativa esta correta?',
        nomeMateria: 'Direito',
        nomeBanca: 'FGV',
        ano: 2026,
        alternativas: [
          Alternativa(
            id: 1,
            idQuestao: 1,
            letra: 'A',
            texto: 'Alternativa A',
            isCorrect: true,
          ),
          Alternativa(
            id: 2,
            idQuestao: 1,
            letra: 'B',
            texto: 'Alternativa B',
            isCorrect: false,
          ),
        ],
      ),
    ],
  );

  test('gera PDF de prova com questões, alternativas e gabarito', () async {
    final bytes = await SimuladoPdfService.gerar(
      prova,
      agora: DateTime(2026, 11, 10),
    );

    expect(utf8.decode(bytes.take(4).toList()), '%PDF');
    expect(bytes.length, greaterThan(1000));
  });

  test('gera PDF de resultado com nota e ranking', () async {
    const args = SimuladoResultadoArgs(
      simulado: Simulado(id: 'sim-pdf', titulo: 'Prova de Direito'),
      resultado: SimuladoResultado(
        nota: 8.5,
        acertos: 17,
        total: 20,
        detalhes: [],
        ranking: [
          RankingEntry(
            nomeUsuario: 'Aluno',
            nota: 9,
            respostasCorretas: 18,
            totalQuestoes: 20,
          ),
        ],
      ),
    );

    final bytes = await SimuladoPdfService.gerarResultado(
      args,
      agora: DateTime(2026, 11, 10),
    );

    expect(utf8.decode(bytes.take(4).toList()), '%PDF');
    expect(bytes.length, greaterThan(1000));
  });
}
