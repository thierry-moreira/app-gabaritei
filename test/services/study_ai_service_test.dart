import 'package:test/test.dart';
import 'package:gabaritei_app/services/study_ai_service.dart';
import 'package:gabaritei_app/models/question.dart';

void main() {
  group('StudyAiService.explanationSystemPrompt', () {
    test('sem legislação -> prompt base', () {
      final prompt = StudyAiService.explanationSystemPrompt(hasLegislation: false);
      expect(prompt, contains('Você é um professor especialista'));
      expect(prompt, contains('NÃO INVENTE LEIS'));
      expect(prompt, contains('SEJA PEDAGÓGICO'));
      expect(prompt, isNot(contains('CONTEXTO LEGISLATIVO OFICIAL')));
    });

    test('com legislação -> prompt base + regras', () {
      final prompt = StudyAiService.explanationSystemPrompt(hasLegislation: true);
      expect(prompt, contains('CONTEXTO LEGISLATIVO OFICIAL'));
      expect(prompt, contains('ÚNICA fonte autoritativa'));
      expect(prompt, contains('NUNCA cite número de dispositivo que não esteja no contexto'));
    });
  });

  group('StudyAiService.explanationUserPrompt', () {
    test('monta prompt com enunciado, alternativas, gabarito', () {
      final questao = Questao(
        id: 1,
        enunciado: 'Qual a capital do Brasil?',
        alternativas: [
          Alternativa(id: 1, idQuestao: 1, letra: 'A', texto: 'São Paulo', isCorrect: false),
          Alternativa(id: 2, idQuestao: 1, letra: 'B', texto: 'Brasília', isCorrect: true),
          Alternativa(id: 3, idQuestao: 1, letra: 'C', texto: 'Rio de Janeiro', isCorrect: false),
        ],
        respostaCorreta: 'B',
        textoBase: 'Art. 18 da CF/88',
      );
      final prompt = StudyAiService.explanationUserPrompt(
        questao: questao,
        legislationBlock: 'Lei 123: artigo sobre capitais.',
      );
      expect(prompt, contains('Qual a capital do Brasil?'));
      expect(prompt, contains('A) São Paulo'));
      expect(prompt, contains('B) Brasília'));
      expect(prompt, contains('C) Rio de Janeiro'));
      expect(prompt, contains('Gabarito Correto: B'));
      expect(prompt, contains('Texto base de apoio (Lei seca): Art. 18 da CF/88'));
      expect(prompt, contains('Contexto legislativo oficial'));
      expect(prompt, contains('Lei 123: artigo sobre capitais.'));
    });

    test('sem texto base e sem legislação', () {
      final questao = Questao(
        id: 1,
        enunciado: 'Pergunta simples?',
        alternativas: [
          Alternativa(id: 1, idQuestao: 1, letra: 'A', texto: 'Sim', isCorrect: true),
        ],
        respostaCorreta: 'A',
      );
      final prompt = StudyAiService.explanationUserPrompt(
        questao: questao,
        legislationBlock: null,
      );
      expect(prompt, isNot(contains('Texto base de apoio')));
      expect(prompt, isNot(contains('Contexto legislativo oficial')));
    });
  });

  group('StudyAiService.studySystemPrompt', () {
    test('resumo -> prompt de resumo', () {
      final prompt = StudyAiService.studySystemPrompt(tipo: StudyContentType.resumo);
      expect(prompt, contains('RESUMO TEÓRICO'));
      expect(prompt, contains('Caderno de Estudos'));
      expect(prompt, contains('NÃO mencione alternativas'));
      expect(prompt, contains('LaTeX OBRIGATORIAMENTE'));
      expect(prompt, contains('<b>...</b>'));
    });

    test('flashcard -> prompt de flashcard', () {
      final prompt = StudyAiService.studySystemPrompt(tipo: StudyContentType.flashcard);
      expect(prompt, contains('FLASHCARD'));
      expect(prompt, contains('FRENTE:'));
      expect(prompt, contains('VERSO:'));
      expect(prompt, contains('Máximo de 2 linhas'));
      expect(prompt, contains('recuperação ativa'));
    });

    test('templateMateria personalizado', () {
      final prompt = StudyAiService.studySystemPrompt(
        tipo: StudyContentType.resumo,
        templateMateria: 'Você é um tutor.',
      );
      expect(prompt, startsWith('Você é um tutor.'));
    });
  });

  group('StudyAiService.studyUserPrompt', () {
    test('inclui questão, texto base, gabarito, explicação prévia', () {
      final questao = Questao(
        id: 1,
        enunciado: 'Enunciado teste',
        textoBase: 'Base legal',
        respostaCorreta: 'C',
      );
      final prompt = StudyAiService.studyUserPrompt(
        questao: questao,
        explicacaoBase: 'Explicação anterior',
      );
      expect(prompt, contains('QUESTÃO: Enunciado teste'));
      expect(prompt, contains('TEXTO BASE: Base legal'));
      expect(prompt, contains('GABARITO: C'));
      expect(prompt, contains('EXPLICAÇÃO PRÉVIA: Explicação anterior'));
    });

    test('valores nulos viram N/A ou vazio', () {
      final questao = Questao(
        id: 1,
        enunciado: 'Pergunta',
        textoBase: null,
        respostaCorreta: null,
      );
      final prompt = StudyAiService.studyUserPrompt(
        questao: questao,
        explicacaoBase: null,
      );
      expect(prompt, contains('TEXTO BASE: N/A'));
      expect(prompt, contains('GABARITO: ?'));
      expect(prompt, contains('EXPLICAÇÃO PRÉVIA: '));
    });
  });

  group('StudyAiService.parseStudyContent', () {
    test('resumo -> conteudo direto', () {
      final content = StudyAiService.parseStudyContent(
        tipo: StudyContentType.resumo,
        gerado: 'Conteúdo do resumo aqui.',
        nomeMateria: 'Matéria',
      );
      expect(content.conteudo, 'Conteúdo do resumo aqui.');
      expect(content.frente, null);
      expect(content.verso, null);
    });

    test('flashcard -> extrai FRENTE e VERSO', () {
      final content = StudyAiService.parseStudyContent(
        tipo: StudyContentType.flashcard,
        gerado: 'FRENTE: O que é X?\nVERSO: X é Y.',
        nomeMateria: 'Matéria',
      );
      expect(content.frente, 'O que é X?');
      expect(content.verso, 'X é Y.');
    });

    test('flashcard case insensitive', () {
      final content = StudyAiService.parseStudyContent(
        tipo: StudyContentType.flashcard,
        gerado: 'frente: pergunta?\nverso: resposta.',
        nomeMateria: 'Matéria',
      );
      expect(content.frente, 'pergunta?');
      expect(content.verso, 'resposta.');
    });

    test('flashcard sem marcadores -> fallback', () {
      final content = StudyAiService.parseStudyContent(
        tipo: StudyContentType.flashcard,
        gerado: 'Texto sem formatação',
        nomeMateria: 'Minha Matéria',
      );
      expect(content.frente, 'Revisão: Minha Matéria');
      expect(content.verso, 'Texto sem formatação');
    });

    test('flashcard apenas FRENTE', () {
      final content = StudyAiService.parseStudyContent(
        tipo: StudyContentType.flashcard,
        gerado: 'FRENTE: Só frente\nVERSO:',
        nomeMateria: 'Matéria',
      );
      expect(content.frente, 'Só frente');
      expect(content.verso, '');
    });
  });

  group('StudyAiService.sanitizeExplanation', () {
    test('remove blockquotes > no início das linhas', () {
      final input = '> Linha 1\n> Linha 2\nNormal';
      final output = StudyAiService.sanitizeExplanation(input);
      // Remove > do início, mas mantém \n
      expect(output, ' Linha 1\n Linha 2\nNormal');
    });

    test('remove pipes | no início das linhas', () {
      final input = '| Tabela\n| Dados';
      final output = StudyAiService.sanitizeExplanation(input);
      expect(output, ' Tabela\n Dados');
    });

    test('normaliza espaços múltiplos (apenas espaços, não tabs)', () {
      final input = 'Palavra1    Palavra2\t\tPalavra3';
      final output = StudyAiService.sanitizeExplanation(input);
      // Tabs não são normalizados, apenas espaços múltiplos
      expect(output, 'Palavra1 Palavra2\t\tPalavra3');
    });

    test('combina tudo', () {
      final input = '>  Início  \n|  Meio  \nFim   ';
      final output = StudyAiService.sanitizeExplanation(input);
      // Remove > e | do início, normaliza espaços, mantém \n
      // trailing space em 'Fim ' é mantido
      expect(output, ' Início \n Meio \nFim ');
    });
  });

  group('StudyAiService.imageUrls', () {
    test('extrai URLs de imagens do enunciado e alternativas', () {
      final questao = Questao(
        id: 1,
        enunciado: 'Veja a imagem: <img src="https://ex.com/img1.png"> e outra <img src=\'img2.jpg\'>',
        alternativas: [
          Alternativa(id: 1, idQuestao: 1, letra: 'A', texto: '<img src="alt1.png">', isCorrect: false),
          Alternativa(id: 2, idQuestao: 1, letra: 'B', texto: 'Sem imagem', isCorrect: true),
        ],
        urlImagem: 'https://legacy.com/legacy.png',
      );
      final urls = StudyAiService.imageUrls(questao: questao, legacyImageUrl: questao.urlImagem);
      expect(urls.length, 4);
      expect(urls, contains('https://legacy.com/legacy.png'));
      expect(urls, contains('https://ex.com/img1.png'));
      expect(urls, contains('img2.jpg'));
      expect(urls, contains('alt1.png'));
    });

    test('sem imagens -> lista vazia', () {
      final questao = Questao(
        id: 1,
        enunciado: 'Texto apenas',
        alternativas: [
          Alternativa(id: 1, idQuestao: 1, letra: 'A', texto: 'Opção A', isCorrect: true),
        ],
      );
      final urls = StudyAiService.imageUrls(questao: questao, legacyImageUrl: null);
      expect(urls, isEmpty);
    });
  });

  group('StudyContent.toJson / fromJson', () {
    test('resumo serializa com conteudo', () {
      const content = StudyContent(conteudo: 'Resumo texto');
      final json = content.toJson();
      expect(json, {'conteudo': 'Resumo texto'});

      final parsed = StudyContent.fromJson(json, tipo: StudyContentType.resumo);
      expect(parsed.conteudo, 'Resumo texto');
    });

    test('flashcard serializa com frente/verso', () {
      const content = StudyContent(frente: 'Pergunta?', verso: 'Resposta.');
      final json = content.toJson();
      expect(json, {'frente': 'Pergunta?', 'verso': 'Resposta.'});

      final parsed = StudyContent.fromJson(json, tipo: StudyContentType.flashcard);
      expect(parsed.frente, 'Pergunta?');
      expect(parsed.verso, 'Resposta.');
    });

    test('fromJson com chaves ausentes usa vazio', () {
      final parsed = StudyContent.fromJson({}, tipo: StudyContentType.flashcard);
      expect(parsed.frente, '');
      expect(parsed.verso, '');
    });
  });

  group('StudyContentType.fromWire', () {
    test('resumo', () {
      expect(StudyContentType.fromWire('resumo'), StudyContentType.resumo);
    });
    test('flashcard', () {
      expect(StudyContentType.fromWire('flashcard'), StudyContentType.flashcard);
    });
    test('inválido', () {
      expect(StudyContentType.fromWire('invalido'), null);
    });
    test('null', () {
      expect(StudyContentType.fromWire(null), null);
    });
  });
}