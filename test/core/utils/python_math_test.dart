import 'package:test/test.dart';
import 'package:gabaritei_app/core/utils/python_math.dart';

void main() {
  group('pythonRound - banker\'s rounding (ties to even)', () {
    test('rounds .5 up when integer part is odd', () {
      expect(pythonRound(0.5), 0);
      expect(pythonRound(1.5), 2);
      expect(pythonRound(2.5), 2);
      expect(pythonRound(3.5), 4);
      expect(pythonRound(4.5), 4);
    });

    test('rounds .5 down when integer part is even', () {
      expect(pythonRound(1.5), 2);
      expect(pythonRound(2.5), 2);
      expect(pythonRound(3.5), 4);
    });

    test('rounds normally for non-ties', () {
      expect(pythonRound(1.2), 1);
      expect(pythonRound(1.7), 2);
      expect(pythonRound(2.3), 2);
      expect(pythonRound(2.8), 3);
      expect(pythonRound(-1.2), -1);
      expect(pythonRound(-1.7), -2);
      expect(pythonRound(-1.5), -2); // -1.5 -> -2 (even)
      expect(pythonRound(-2.5), -2); // -2.5 -> -2 (even)
    });

    test('handles integers', () {
      expect(pythonRound(0), 0);
      expect(pythonRound(42), 42);
      expect(pythonRound(-42), -42);
    });

    test('throws on NaN and infinity', () {
      expect(() => pythonRound(double.nan), throwsArgumentError);
      expect(() => pythonRound(double.infinity), throwsArgumentError);
      expect(() => pythonRound(double.negativeInfinity), throwsArgumentError);
    });
  });

  group('pythonRoundTo - round to N decimal places', () {
    test('rounds to 0 digits (same as pythonRound)', () {
      expect(pythonRoundTo(1.5, 0), 2.0);
      expect(pythonRoundTo(2.5, 0), 2.0);
    });

    test('rounds to 1 digit', () {
      expect(pythonRoundTo(1.25, 1), 1.2); // 1.25 -> 1.2 (2 is even)
      expect(pythonRoundTo(1.35, 1), 1.4); // 1.35 -> 1.4 (4 is even)
      expect(pythonRoundTo(2.25, 1), 2.2); // 2.25 -> 2.2 (2 is even)
      expect(pythonRoundTo(2.35, 1), 2.4); // 2.35 -> 2.4 (4 is even)
    });

    test('rounds to 2 digits', () {
      // Note: floating point precision may affect exact halfway cases
      expect(pythonRoundTo(1.235, 2), 1.24);
      expect(pythonRoundTo(2.675, 2), 2.68);
      expect(pythonRoundTo(2.685, 2), 2.68);
    });

    test('works with negative numbers', () {
      expect(pythonRoundTo(-1.25, 1), -1.2);
      expect(pythonRoundTo(-1.35, 1), -1.4);
    });

    test('works with integers', () {
      expect(pythonRoundTo(42, 3), 42.0);
    });
  });
}