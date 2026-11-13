import 'package:test/test.dart';
import 'package:gabaritei_app/core/utils/json_utils.dart';

void main() {
  group('Json.text', () {
    test('string -> string', () {
      expect(Json.text('hello'), 'hello');
    });

    test('int -> string', () {
      expect(Json.text(42), '42');
    });

    test('double -> string', () {
      expect(Json.text(3.14), '3.14');
    });

    test('bool -> string', () {
      expect(Json.text(true), 'true');
    });

    test('null -> fallback', () {
      expect(Json.text(null, 'fallback'), 'fallback');
    });

    test('null sem fallback -> vazio', () {
      expect(Json.text(null), '');
    });
  });

  group('Json.textOrNull', () {
    test('string não vazia -> string', () {
      expect(Json.textOrNull('hello'), 'hello');
    });

    test('string vazia -> null', () {
      expect(Json.textOrNull(''), null);
    });

    test('null -> null', () {
      expect(Json.textOrNull(null), null);
    });

    test('int -> string', () {
      expect(Json.textOrNull(42), '42');
    });
  });

  group('Json.integer', () {
    test('int -> int', () {
      expect(Json.integer(42), 42);
    });

    test('double -> int (truncado)', () {
      expect(Json.integer(3.9), 3);
      expect(Json.integer(-2.5), -2);
    });

    test('string numérica -> int', () {
      expect(Json.integer('123'), 123);
      expect(Json.integer('-456'), -456);
    });

    test('string não numérica -> fallback', () {
      expect(Json.integer('abc', 99), 99);
    });

    test('null -> fallback', () {
      expect(Json.integer(null, 7), 7);
    });

    test('bool -> fallback (bool não é num)', () {
      expect(Json.integer(true, 1), 1);
    });
  });

  group('Json.integerOrNull', () {
    test('int -> int', () {
      expect(Json.integerOrNull(42), 42);
    });

    test('double -> int', () {
      expect(Json.integerOrNull(3.14), 3);
    });

    test('string numérica -> int', () {
      expect(Json.integerOrNull('123'), 123);
    });

    test('string não numérica -> null', () {
      expect(Json.integerOrNull('abc'), null);
    });

    test('null -> null', () {
      expect(Json.integerOrNull(null), null);
    });
  });

  group('Json.decimal', () {
    test('double -> double', () {
      expect(Json.decimal(3.14), 3.14);
    });

    test('int -> double', () {
      expect(Json.decimal(42), 42.0);
    });

    test('string -> double', () {
      expect(Json.decimal('3.14'), 3.14);
      expect(Json.decimal('42'), 42.0);
    });

    test('inválido -> fallback', () {
      expect(Json.decimal('abc', 1.5), 1.5);
      expect(Json.decimal(null, 2.0), 2.0);
    });
  });

  group('Json.decimalOrNull', () {
    test('double -> double', () {
      expect(Json.decimalOrNull(3.14), 3.14);
    });

    test('int -> double', () {
      expect(Json.decimalOrNull(42), 42.0);
    });

    test('string -> double', () {
      expect(Json.decimalOrNull('3.14'), 3.14);
    });

    test('inválido -> null', () {
      expect(Json.decimalOrNull('abc'), null);
      expect(Json.decimalOrNull(null), null);
    });
  });

  group('Json.boolean', () {
    test('bool -> bool', () {
      expect(Json.boolean(true), true);
      expect(Json.boolean(false), false);
    });

    test('int não-zero -> true', () {
      expect(Json.boolean(1), true);
      expect(Json.boolean(-1), true);
      expect(Json.boolean(0), false);
    });

    test('string true/false -> bool', () {
      expect(Json.boolean('true'), true);
      expect(Json.boolean('false'), false);
      expect(Json.boolean('TRUE'), true);
      expect(Json.boolean('FALSE'), false);
      expect(Json.boolean('1'), true);
      expect(Json.boolean('0'), false);
    });

    test('outros -> fallback', () {
      expect(Json.boolean('yes', false), false);
      expect(Json.boolean(null, true), true);
    });
  });

  group('Json.dateTime', () {
    test('DateTime -> DateTime', () {
      final dt = DateTime.utc(2025, 1, 15, 12, 0, 0);
      expect(Json.dateTime(dt), dt);
    });

    test('string ISO -> DateTime', () {
      expect(Json.dateTime('2025-01-15T12:00:00Z'), DateTime.utc(2025, 1, 15, 12, 0, 0));
      expect(Json.dateTime('2025-01-15T09:00:00-03:00'), DateTime.utc(2025, 1, 15, 12, 0, 0));
    });

    test('inválido -> null', () {
      expect(Json.dateTime('não data'), null);
      expect(Json.dateTime(null), null);
      expect(Json.dateTime(123), null);
    });
  });

  group('Json.stringList', () {
    test('List<String> -> List<String>', () {
      expect(Json.stringList(['a', 'b']), ['a', 'b']);
    });

    test('List<int> -> List<String>', () {
      expect(Json.stringList([1, 2]), ['1', '2']);
    });

    test('string vírgula -> split', () {
      expect(Json.stringList('a,b,c'), ['a', 'b', 'c']);
    });

    test('null/vazio -> lista vazia', () {
      expect(Json.stringList(null), isEmpty);
      expect(Json.stringList(''), isEmpty);
    });
  });

  group('Json.intList', () {
    test('List<int> -> List<int>', () {
      expect(Json.intList([1, 2]), [1, 2]);
    });

    test('List<String> numérica -> List<int>', () {
      expect(Json.intList(['1', '2']), [1, 2]);
    });

    test('ignora não numéricos', () {
      expect(Json.intList(['1', 'abc', '3']), [1, 3]);
    });

    test('null -> vazio', () {
      expect(Json.intList(null), isEmpty);
    });
  });

  group('Json.mapOrNull', () {
    test('Map<String, dynamic> -> Map', () {
      final map = {'a': 1};
      expect(Json.mapOrNull(map), map);
    });

    test('Map com keys não-string -> converte', () {
      final map = {1: 'a', 2: 'b'};
      final result = Json.mapOrNull(map);
      expect(result, {'1': 'a', '2': 'b'});
    });

    test('null/não-Map -> null', () {
      expect(Json.mapOrNull(null), null);
      expect(Json.mapOrNull('string'), null);
      expect(Json.mapOrNull([1, 2]), null);
    });
  });

  group('Json.mapList', () {
    test('List<Map> -> List<Map<String, dynamic>>', () {
      final list = [{'a': 1}, {'b': 2}];
      final result = Json.mapList(list);
      expect(result, [{'a': 1}, {'b': 2}]);
    });

    test('ignora não-Maps', () {
      final list = [{'a': 1}, 'string', 123, {'b': 2}];
      final result = Json.mapList(list);
      expect(result.length, 2);
    });

    test('null/não-Lista -> vazio', () {
      expect(Json.mapList(null), isEmpty);
      expect(Json.mapList('string'), isEmpty);
    });
  });

  group('Json.firstWhereOrNull', () {
    test('encontra primeiro', () {
      expect(Json.firstWhereOrNull([1, 2, 3], (x) => x > 1), 2);
    });

    test('não encontra -> null', () {
      expect(Json.firstWhereOrNull([1, 2, 3], (x) => x > 10), null);
    });

    test('lista vazia -> null', () {
      expect(Json.firstWhereOrNull<int>([], (x) => true), null);
    });
  });
}