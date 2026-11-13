import 'package:test/test.dart';
import 'package:gabaritei_app/core/utils/slug.dart';

void main() {
  group('slugify', () {
    test('null ou vazio -> vazio', () {
      expect(slugify(null), '');
      expect(slugify(''), '');
    });

    test('minúsculas e remove acentos', () {
      expect(slugify('ÁÉÍÓÚ'), 'aeiou');
      expect(slugify('àèìòù'), 'aeiou');
      expect(slugify('âêîôû'), 'aeiou');
      expect(slugify('ãõ'), 'ao');
      expect(slugify('äëïöü'), 'aeiou');
      expect(slugify('ç'), 'c');
      expect(slugify('ñ'), 'n');
    });

    test('substitui não alfanuméricos por hífen', () {
      expect(slugify('Olá Mundo!'), 'ola-mundo');
      expect(slugify('Teste@#\$%'), 'teste');
      expect(slugify('A B C'), 'a-b-c');
    });

    test('colapsa múltiplos hífens', () {
      expect(slugify('A---B'), 'a-b');
      expect(slugify('A  B  C'), 'a-b-c');
    });

    test('remove hífens do início e fim', () {
      expect(slugify('-inicio'), 'inicio');
      expect(slugify('fim-'), 'fim');
      expect(slugify('-ambos-'), 'ambos');
    });

    test('números mantidos', () {
      expect(slugify('Teste 123'), 'teste-123');
      expect(slugify('2024 Ano'), '2024-ano');
    });

    test('exemplos reais de matéria/tópico', () {
      expect(slugify('Língua Portuguesa'), 'lingua-portuguesa');
      expect(slugify('Matemática Financeira'), 'matematica-financeira');
      expect(slugify('Direito Constitucional'), 'direito-constitucional');
      expect(slugify('Informática Básica'), 'informatica-basica');
      expect(slugify('Raciocínio Lógico'), 'raciocinio-logico');
      expect(slugify('Atualidades'), 'atualidades');
    });
  });
}