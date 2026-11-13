import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gabaritei_app/models/study.dart';
import 'package:gabaritei_app/services/resumo_print_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PDF de resumo usa fonte Unicode para aspas e travessões', () async {
    final bytes = await ResumoPdfService.gerar(
      nomeMateria: 'Língua Portuguesa',
      resumos: [
        Resumo(
          id: 'r1',
          idUsuario: '1',
          idMateria: 1,
          nomeMateria: 'Língua Portuguesa',
          conteudo:
              '### Conclusão\n'
              '- **Conceito**: O SFTP não é “FTP com criptografia”; '
              'ele é um protocolo distinto — fim…\n'
              '▸ Marcador de lista\n'
              '✓ Item correto\n'
              '⭐ Destaque',
          criadoEm: DateTime(2026, 11, 12),
        ),
      ],
      agora: DateTime(2026, 11, 12),
    );

    expect(utf8.decode(bytes.take(5).toList()), '%PDF-');
    final bruto = latin1.decode(bytes, allowInvalid: true);
    expect(bruto, contains('Roboto'));
    expect(bruto, isNot(contains('Helvetica')));
  });
}
