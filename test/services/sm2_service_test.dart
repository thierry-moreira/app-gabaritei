import 'package:test/test.dart';
import 'package:gabaritei_app/services/sm2_service.dart';

void main() {
  group('Sm2Service.revisar', () {
    final agora = DateTime.utc(2025, 1, 15, 12, 0, 0);

    group('qualidade 0 (errei completamente)', () {
      test('intervalo vira 0, facilidade -0.2 (min 1.3)', () {
        final r = Sm2Service.revisar(
          intervaloAtual: 10,
          facilidadeAtual: 2.5,
          qualidade: 0,
          agora: agora,
        );
        expect(r.intervalo, 0);
        // max(1.3, 2.5 - 0.2) = max(1.3, 2.3) = 2.3
        expect(r.facilidade, 2.3);
        expect(r.proximaRevisao, agora); // intervalo 0 = hoje
      });

      test('facilidade não desce abaixo de 1.3', () {
        final r = Sm2Service.revisar(
          intervaloAtual: 5,
          facilidadeAtual: 1.4,
          qualidade: 0,
          agora: agora,
        );
        expect(r.facilidade, 1.3); // max(1.3, 1.4 - 0.2) = 1.3
      });

      test('intervalo 0 com qualidade 0 mantém 0', () {
        final r = Sm2Service.revisar(
          intervaloAtual: 0,
          facilidadeAtual: 2.5,
          qualidade: 0,
          agora: agora,
        );
        expect(r.intervalo, 0);
      });
    });

    group('qualidade 1 (difícil)', () {
      test('intervalo = max(1, int(intervalo * 1.2)), facilidade -0.15', () {
        final r = Sm2Service.revisar(
          intervaloAtual: 10,
          facilidadeAtual: 2.5,
          qualidade: 1,
          agora: agora,
        );
        expect(r.intervalo, 12); // max(1, int(10 * 1.2)) = 12
        expect(r.facilidade, 2.35); // max(1.3, 2.5 - 0.15) = 2.35
      });

      test('intervalo 0 vira 1', () {
        final r = Sm2Service.revisar(
          intervaloAtual: 0,
          facilidadeAtual: 2.5,
          qualidade: 1,
          agora: agora,
        );
        expect(r.intervalo, 1); // max(1, int(0 * 1.2)) = 1
      });

      test('facilidade não desce abaixo de 1.3', () {
        final r = Sm2Service.revisar(
          intervaloAtual: 10,
          facilidadeAtual: 1.4,
          qualidade: 1,
          agora: agora,
        );
        expect(r.facilidade, 1.3); // max(1.3, 1.4 - 0.15) = 1.3
      });
    });

    group('qualidade 2 (bom)', () {
      test('intervalo 0 -> 1', () {
        final r = Sm2Service.revisar(
          intervaloAtual: 0,
          facilidadeAtual: 2.5,
          qualidade: 2,
          agora: agora,
        );
        expect(r.intervalo, 1);
      });

      test('intervalo 1 -> 4', () {
        final r = Sm2Service.revisar(
          intervaloAtual: 1,
          facilidadeAtual: 2.5,
          qualidade: 2,
          agora: agora,
        );
        expect(r.intervalo, 4);
      });

      test('intervalo > 1 -> int(intervalo * facilidade)', () {
        final r = Sm2Service.revisar(
          intervaloAtual: 6,
          facilidadeAtual: 2.5,
          qualidade: 2,
          agora: agora,
        );
        expect(r.intervalo, 15); // int(6 * 2.5) = 15
      });

      test('facilidade não muda', () {
        final r = Sm2Service.revisar(
          intervaloAtual: 10,
          facilidadeAtual: 2.3,
          qualidade: 2,
          agora: agora,
        );
        expect(r.facilidade, 2.3);
      });
    });

    group('qualidade 3 (fácil)', () {
      test('intervalo <= 1 -> 7', () {
        final r0 = Sm2Service.revisar(
          intervaloAtual: 0,
          facilidadeAtual: 2.5,
          qualidade: 3,
          agora: agora,
        );
        expect(r0.intervalo, 7);

        final r1 = Sm2Service.revisar(
          intervaloAtual: 1,
          facilidadeAtual: 2.5,
          qualidade: 3,
          agora: agora,
        );
        expect(r1.intervalo, 7);
      });

      test('intervalo > 1 -> int(intervalo * facilidade * 1.3)', () {
        final r = Sm2Service.revisar(
          intervaloAtual: 10,
          facilidadeAtual: 2.5,
          qualidade: 3,
          agora: agora,
        );
        expect(r.intervalo, 32); // int(10 * 2.5 * 1.3) = int(32.5) = 32
      });

      test('facilidade +0.15, max 2.5', () {
        final r = Sm2Service.revisar(
          intervaloAtual: 10,
          facilidadeAtual: 2.4,
          qualidade: 3,
          agora: agora,
        );
        expect(r.facilidade, 2.5); // min(2.5, 2.4 + 0.15)
      });

      test('facilidade sobe 0.15', () {
        final r = Sm2Service.revisar(
          intervaloAtual: 10,
          facilidadeAtual: 1.2,
          qualidade: 3,
          agora: agora,
        );
        // 1.2 + 0.15 = 1.35 (floating point can be 1.3499999999999999)
        expect(r.facilidade, closeTo(1.35, 0.0001));
      });
    });

    group('validação de qualidade', () {
      test('qualidade -1 lança ArgumentError', () {
        expect(
          () => Sm2Service.revisar(
            intervaloAtual: 10,
            facilidadeAtual: 2.5,
            qualidade: -1,
            agora: agora,
          ),
          throwsArgumentError,
        );
      });

      test('qualidade 4 lança ArgumentError', () {
        expect(
          () => Sm2Service.revisar(
            intervaloAtual: 10,
            facilidadeAtual: 2.5,
            qualidade: 4,
            agora: agora,
          ),
          throwsArgumentError,
        );
      });
    });

    group('proximaRevisao', () {
      test('intervalo 0 -> mesma data', () {
        final r = Sm2Service.revisar(
          intervaloAtual: 10,
          facilidadeAtual: 2.5,
          qualidade: 0,
          agora: agora,
        );
        expect(r.proximaRevisao, agora);
      });

      test('intervalo 1 -> amanhã', () {
        final r = Sm2Service.revisar(
          intervaloAtual: 0,
          facilidadeAtual: 2.5,
          qualidade: 1,
          agora: agora,
        );
        expect(r.proximaRevisao, agora.add(const Duration(days: 1)));
      });

      test('intervalo 7 -> daqui 7 dias', () {
        final r = Sm2Service.revisar(
          intervaloAtual: 1,
          facilidadeAtual: 2.5,
          qualidade: 3,
          agora: agora,
        );
        expect(r.proximaRevisao, agora.add(const Duration(days: 7)));
      });
    });
  });
}