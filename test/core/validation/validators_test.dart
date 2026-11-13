import 'package:test/test.dart';
import 'package:gabaritei_app/core/validation/validators.dart';

void main() {
  group('Validators.username', () {
    test('válido: letras, números, espaço, ponto, hífen, underscore', () {
      expect(Validators.username('João Silva').isValid, true);
      expect(Validators.username('joao_silva').isValid, true);
      expect(Validators.username('joao.silva').isValid, true);
      expect(Validators.username('joao-silva').isValid, true);
      expect(Validators.username('Joao123').isValid, true);
      expect(Validators.username('A'.padRight(30, 'a')).isValid, true); // 30 chars
    });

    test('inválido: muito curto', () {
      final r = Validators.username('A');
      expect(r.isValid, false);
      expect(r.error, contains('entre 2 e 30'));
    });

    test('inválido: muito longo', () {
      final r = Validators.username('A' * 31);
      expect(r.isValid, false);
      expect(r.error, contains('entre 2 e 30'));
    });

    test('inválido: caracteres especiais', () {
      expect(Validators.username('joao@silva').isValid, false);
      expect(Validators.username('joao#silva').isValid, false);
      expect(Validators.username('joao!silva').isValid, false);
      expect(Validators.username('joão\$silva').isValid, false);
    });

    test('caracteres de controle são normalizados para espaço', () {
      // \n e \t são normalizados para espaço pelo replaceAll(\s+)
      expect(Validators.username('joao\nsilva').isValid, true);
      expect(Validators.username('joao\nsilva').value, 'joao silva');
      expect(Validators.username('joao\tsilva').isValid, true);
      expect(Validators.username('joao\tsilva').value, 'joao silva');
    });

    test('normaliza espaços múltiplos', () {
      final r = Validators.username('João   Silva');
      expect(r.isValid, true);
      expect(r.value, 'João Silva');
    });

    test('trim', () {
      final r = Validators.username('  João Silva  ');
      expect(r.isValid, true);
      expect(r.value, 'João Silva');
    });

    test('valor null -> inválido', () {
      expect(Validators.username(null).isValid, false);
    });
  });

  group('Validators.usernameBase', () {
    test('usa username se válido', () {
      expect(Validators.usernameBase('João Silva'), 'João Silva');
    });

    test('remove caracteres inválidos', () {
      expect(Validators.usernameBase('joao@silva'), 'joaosilva');
      expect(Validators.usernameBase('joão#silva!'), 'joãosilva');
    });

    test('trunca em 30 chars', () {
      final long = 'a' * 40;
      expect(Validators.usernameBase(long).length, 30);
    });

    test('trim de pontuação nas pontas (apenas se username for inválido)', () {
      // .joao. é válido (pontos permitidos), então retorna como está
      expect(Validators.usernameBase('.joao.'), '.joao.');
      // Mas @joao@ é inválido, então remove @
      expect(Validators.usernameBase('@joao@'), 'joao');
      expect(Validators.usernameBase('-joao-'), '-joao-'); // hífen permitido
      expect(Validators.usernameBase('_joao_'), '_joao_'); // underscore permitido
    });

    test('vazio -> Estudante', () {
      expect(Validators.usernameBase(''), 'Estudante');
      expect(Validators.usernameBase('@#\$%'), 'Estudante');
      expect(Validators.usernameBase(null), 'Estudante');
    });
  });

  group('Validators.comment', () {
    test('válido: texto normal', () {
      expect(Validators.comment('Ótima questão!').isValid, true);
    });

    test('inválido: vazio', () {
      final r = Validators.comment('');
      expect(r.isValid, false);
      expect(r.error, contains('Escreva um comentário'));
    });

    test('inválido: só espaços', () {
      expect(Validators.comment('   ').isValid, false);
    });

    test('inválido: > 1000 chars', () {
      final r = Validators.comment('a' * 1001);
      expect(r.isValid, false);
      expect(r.error, contains('1000 caracteres'));
    });

    test('inválido: caracteres de controle', () {
      expect(Validators.comment('linha1\nlinha2').isValid, false);
      expect(Validators.comment('tab\taqui').isValid, false);
    });

    test('valor null -> inválido', () {
      expect(Validators.comment(null).isValid, false);
    });
  });

  group('Validators.email', () {
    test('válido', () {
      expect(Validators.email('teste@email.com'), null);
      expect(Validators.email('user.name@domain.org'), null);
      expect(Validators.email('user+tag@example.com'), null);
    });

    test('inválido: vazio', () {
      expect(Validators.email(''), 'Informe seu e-mail.');
    });

    test('inválido: sem @', () {
      expect(Validators.email('testeemail.com'), 'Informe um e-mail válido.');
    });

    test('inválido: sem domínio', () {
      expect(Validators.email('teste@'), 'Informe um e-mail válido.');
    });

    test('inválido: sem TLD', () {
      expect(Validators.email('teste@dominio'), 'Informe um e-mail válido.');
    });

    test('trim e lowercase', () {
      expect(Validators.email('  TESTE@EMAIL.COM  '), null);
    });
  });

  group('Validators.password', () {
    test('válido: >= 8 chars', () {
      expect(Validators.password('12345678'), null);
      expect(Validators.password('senha123'), null);
    });

    test('inválido: < 8 chars', () {
      expect(Validators.password('1234567'), 'A senha precisa ter no mínimo 8 caracteres.');
      expect(Validators.password(''), 'A senha precisa ter no mínimo 8 caracteres.');
    });
  });

  group('Validators.passwordConfirmation', () {
    test('válido: iguais', () {
      expect(Validators.passwordConfirmation('senha123', 'senha123'), null);
    });

    test('inválido: diferentes', () {
      expect(Validators.passwordConfirmation('senha123', 'senha456'), 'As senhas não conferem. Digite a mesma senha nos dois campos.');
    });
  });

  group('Validators.usernameFromEmail', () {
    test('usa prefixo do e-mail', () {
      expect(Validators.usernameFromEmail('joao.silva@email.com'), 'joao.silva');
      // + não é permitido no username, então é removido
      expect(Validators.usernameFromEmail('user+tag@domain.com'), 'usertag');
    });

    test('aplica usernameBase (limpa inválidos)', () {
      expect(Validators.usernameFromEmail('joão@email.com'), 'joão');
      expect(Validators.usernameFromEmail('a@b.c'), 'Estudante'); // muito curto
    });
  });

  group('Validators.positiveInt', () {
    test('válido: int positivo', () {
      expect(Validators.positiveInt(42), 42);
      expect(Validators.positiveInt('123'), 123);
    });

    test('inválido: zero ou negativo', () {
      expect(Validators.positiveInt(0), null);
      expect(Validators.positiveInt(-1), null);
      expect(Validators.positiveInt('-5'), null);
    });

    test('inválido: > 2^31-1', () {
      expect(Validators.positiveInt(2147483648), null);
    });

    test('inválido: não numérico', () {
      expect(Validators.positiveInt('abc'), null);
      expect(Validators.positiveInt(null), null);
      expect(Validators.positiveInt(true), null); // bool é rejeitado
    });
  });

  group('Validators.requiredText', () {
    test('válido: texto não vazio', () {
      expect(Validators.requiredText('algo'), null);
    });

    test('inválido: null, vazio, só espaços', () {
      expect(Validators.requiredText(null), 'Campo obrigatório.');
      expect(Validators.requiredText(''), 'Campo obrigatório.');
      expect(Validators.requiredText('   '), 'Campo obrigatório.');
    });
  });

  group('Validators.slugMatches', () {
    test('true para slugs iguais', () {
      expect(Validators.slugMatches('Língua Portuguesa', 'lingua-portuguesa'), true);
      expect(Validators.slugMatches('Matemática', 'matematica'), true);
    });

    test('false para slugs diferentes', () {
      expect(Validators.slugMatches('Português', 'matematica'), false);
    });

    test('null/empty', () {
      expect(Validators.slugMatches(null, ''), true);
      expect(Validators.slugMatches('', null), true);
      expect(Validators.slugMatches('a', null), false);
    });
  });
}