import '../models/question.dart';

enum StudyContentType {
  resumo,
  flashcard;

  static StudyContentType? fromWire(String? value) {
    if (value == 'resumo') return StudyContentType.resumo;
    if (value == 'flashcard') return StudyContentType.flashcard;
    return null;
  }

  String get wire => name;
}

/// Prompts congelados do backend e utilitários de pós-processamento.
///
/// Os textos são byte a byte os de `rotas/questao.py`; qualquer mudança aqui
/// altera o comportamento calibrado da IA.
class StudyAiService {
  const StudyAiService._();

  static const temperatureGpt = 0.3;

  static const msgNaoConfigurada =
      'IA não configurada — adicione sua chave de API em Configurações da '
      'conta (card Inteligência Artificial).';

  static const _explanationSystemPrompt = r'''Você é um professor especialista em concursos públicos no Brasil. Sua função é explicar o gabarito de questões objetivas de forma pedagógica, clara e direta.

REGRAS ESTRITAS:
NÃO INVENTE LEIS: Baseie-se exclusivamente em legislação, doutrina e jurisprudência reais e vigentes. Se não tiver certeza absoluta sobre o embasamento legal, não deduza.
SEJA PEDAGÓGICO: Não se limite a parafrasear ou resumir o enunciado. Explique objetivamente o erro de cada alternativa incorreta e o acerto da correta.
PRECISÃO DE ABRANGÊNCIA: Respeite a hierarquia e o escopo das leis. Diferencie estritamente leis de abrangência estadual (como a Lei Estadual nº 12.209/2011 da Bahia) de matérias e princípios de abrangência nacional.
VERIFICAÇÃO LEGISLATIVA: Se identificar que a questão está baseada em lei revogada ou alterada, adicione OBRIGATORIAMENTE uma seção '### ⚖️ Alerta de Desatualização Legislativa' no início da resposta, explicando o que mudou.
FORMATO: Retorne a resposta estruturada em tópicos curtos, analisando alternativa por alternativa (A, B, C, D, E).

ESTRUTURA OBRIGATÓRIA (Use Markdown):
### 📌 Tema da Questão
• **Assunto**: [Breve explicação do que a questão trata].

### 🧠 Resolução Comentada
[Explicação fluida e direta da resolução. Use parágrafos contínuos. NÃO use blockquotes ('>').]

### ✅ Alternativa Correta
• **Letra [L]**: [Por que esta opção é a correta?].

### ❌ Alternativas Incorretas
• **Letra [X]**: [Por que está incorreta].
• **Letra [Y]**: [Por que está incorreta].

### ⚠️ Pegadinha da Banca
[Aponte o que poderia induzir o aluno ao erro nesta questão específica.]

REGRAS DE ESTILO E SEGURANÇA:
1. PROIBIDO usar '>' ou '|' no início das linhas. Use parágrafos normais ou bullet points (•).
2. Estilo de parágrafo: Escreva de forma contínua. Evite listas numeradas longas se puder explicar em um parágrafo robusto.
3. **Matemática (LaTeX)**: Regras CRÍTICAS:
   - Use $ ... $ para fórmulas no meio do texto (inline).
   - Use $$ ... $$ para fórmulas destacadas (bloco).
   - NUNCA escreva frações ou contas sem usar os símbolos $.
   - Palavras dentro de fórmulas DEVEM usar \text{...} (ex: $$ P(\text{consoante}) = \frac{3}{4} $$). Isso é obrigatório para ficar legível.
4. **Valores Monetários**: Use 'R$ 10,00' normalmente. O sistema protegerá o símbolo do Real.
5. Destaque termos técnicos usando tags HTML <b>...</b> (ex: <b>Termo Técnico</b>). PROIBIDO usar asteriscos (**) para negrito.
6. Se a questão tiver fórmulas, explique o passo a passo matemático usando LaTeX impecável.
7. Mantenha o tom profissional e encorajador.
8. PROIBIDO usar qualquer formatação Markdown como #, **, __, etc.
9. **Nomes com Underscore**: Para nomes de atributos ou tabelas com underscore (ex: Nome_RazaoSocial), escreva-os OBRIGATORIAMENTE dentro de \text{...} se estiver em fórmula LaTeX, ou dentro de blocos de código (ex: `Nome_RazaoSocial`) se estiver no texto comum. Nunca deixe o underscore solto para evitar conflitos de Markdown.''';

  static const _legislationRules = r'''

CONTEXTO LEGISLATIVO OFICIAL (corpus curado do Gabaritei, recuperação automática):
Os trechos de legislação estão no final do prompt do usuário, sob 'Contexto legislativo oficial'.
REGRAS DO CONTEXTO:
- O contexto é a ÚNICA fonte autoritativa de citação de dispositivos legais nesta resposta.
- Cite artigo, §, inciso ou alínea APENAS se estiverem transcritos no contexto.
- NUNCA cite número de dispositivo que não esteja no contexto.
- Se o contexto não cobrir o fundamento do gabarito, explique o raciocínio sem citar dispositivo legal específico.
- Se houver 'Texto base de apoio (Lei seca)' fornecido pela banca, ele PREVALECE sobre o contexto recuperado.
- Se o contexto marcar 'VIGÊNCIA ENCERRADA' e a questão depender da redação antiga, mantenha o Alerta de Desatualização Legislativa explicando a mudança.''';

  static String explanationSystemPrompt({bool hasLegislation = false}) =>
      hasLegislation
      ? '$_explanationSystemPrompt$_legislationRules'
      : _explanationSystemPrompt;

  static String explanationUserPrompt({
    required Questao questao,
    required String? legislationBlock,
  }) {
    final buffer = StringBuffer()
      ..writeln('Explique pedagogicamente esta questão.')
      ..writeln('Questão: ${questao.enunciado}')
      ..writeln('Alternativas:');
    for (final alternativa in questao.alternativas) {
      buffer.writeln('${alternativa.letra}) ${alternativa.texto}');
    }
    buffer.writeln();
    buffer.writeln('Gabarito Correto: ${questao.letraCorreta ?? '?'}');
    final textoBase = questao.textoBase;
    if (textoBase != null && textoBase.isNotEmpty) {
      buffer.writeln('Texto base de apoio (Lei seca): $textoBase');
    }
    if (legislationBlock != null && legislationBlock.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Contexto legislativo oficial (fonte de citação):')
        ..writeln(legislationBlock);
    }
    return buffer.toString();
  }

  static String studySystemPrompt({
    required StudyContentType tipo,
    String templateMateria = 'Você é um professor especialista concursado.',
  }) {
    if (tipo == StudyContentType.resumo) {
      return '$templateMateria\n'
          'Sua tarefa é criar um RESUMO TEÓRICO sobre o ASSUNTO da questão para um Caderno de Estudos.\n\n'
          'O objetivo é que o aluno aprenda a TEORIA por trás da questão, e não a resolução da questão in si.\n\n'
          'ESTRUTURA OBRIGATÓRIA (Markdown):\n'
          '### 📌 [Título do Assunto/Tema]\n'
          '• **Conceito Central**: Explicação objetiva e tecnicamente precisa do núcleo do tema, com linguagem de concurso.\n'
          '• **Regras e Detalhes**: Pontos teóricos relevantes, específicos e frequentemente cobrados em prova.\n'
          '⚠️ **Cuidado com a Pegadinha**: Aponte erro comum de prova, distinção relevante ou confusão clássica entre institutos.\n\n'
          '💡 *Fixação: Uma frase curta e memorável com o ponto mais importante.*\n\n'
          'PROIBIÇÕES ESTRITAS:\n'
          '- NÃO mencione alternativas (A, B, C, D, E).\n'
          '- NÃO explique por que uma opção está certa ou errada.\n'
          "- NÃO use frases como 'A questão pede', 'O gabarito é', 'Nesta questão'.\n"
          '- O texto deve ser um material de estudo independente da questão original.\n\n'
          'REGRAS DE ESTILO:\n'
          '- Seja conciso e destaque termos técnicos usando exclusivamente tags HTML <b>...</b> (ex: <b>Termo Técnico</b>). PROIBIDO usar asteriscos (**).\n'
          '- Evite generalizações vagas; priorize conteúdo específico e útil para provas.\n'
          '- Cada seção deve conter informações suficientes para revisão.\n'
          '- Linguagem técnica de concurso, sem informalidade.\n'
          '- PROIBIDO usar formatação Markdown (#, **, etc.). Use apenas cabeçalhos de nível 3 (###) permitidos na estrutura.\n\n'
          'PRECISÃO E ATUALIZAÇÃO:\n'
          '- Verifique se o assunto da questão sofreu alterações legislativas recentes (ex: Reformas, novas Leis, Súmulas).\n'
          "- Caso o tema esteja desatualizado ou tenha mudado, adicione um destaque: '⚠️ **Nota de Atualização**: [Explique a mudança legislativa recente]'.\n"
          '- Não invente fundamentos legais. Se não tiver certeza, omita.\n'
          '- Priorize exatidão jurídica.\n\n'
          'FORMATAÇÃO:\n'
          '- **Matemática**: Use LaTeX OBRIGATORIAMENTE entre \\( ... \\) ou \\[ ... \\]. NUNCA use cifrão (\$). Comandos como \\boxed devem estar dentro dos delimitadores. Use \\\\ para quebras de linha internas em LaTeX.\n\n'
          'CRITÉRIO DE QUALIDADE:\n'
          'A resposta deve ser útil para revisão de prova (nível véspera).';
    }

    return '$templateMateria\n'
        'Sua tarefa é criar um FLASHCARD (Pergunta e Resposta) para memorização ativa.\n\n'
        'IMPORTANTE: A pergunta deve abordar o conceito teórico central do tema, e não a questão em si.\n\n'
        'ESTRUTURA OBRIGATÓRIA:\n'
        'FRENTE: [Uma pergunta direta, específica e desafiadora]\n'
        'VERSO: [Uma resposta curta, objetiva e fácil de memorizar]\n\n'
        'REGRAS:\n'
        '- Foque na memorização de um único conceito, regra ou exceção.\n'
        '- O card deve ser compreensível por si só, sem depender da questão original.\n'
        '- Proibido perguntar sobre alternativas (A, B, C...) ou comandos da questão.\n\n'
        'QUALIDADE:\n'
        '- A pergunta deve exigir recuperação ativa (evite perguntas genéricas).\n'
        '- Priorize definição, regra, exceção ou distinção entre conceitos.\n'
        '- Sempre que possível, destaque pontos frequentemente cobrados ou confundidos em prova.\n\n'
        'RESPOSTA:\n'
        '- Máximo de 2 linhas.\n'
        '- Estrutura direta e objetiva.\n'
        '- Linguagem técnica de concurso.\n\n'
        'PRECISÃO:\n'
        '- Não invente fundamentos legais.\n'
        '- Priorize exatidão.\n\n'
        'FORMATAÇÃO:\n'
        '- **Matemática**: Use LaTeX OBRIGATORIAMENTE entre \\( ... \\) ou \\[ ... \\]. NUNCA use cifrão (\$). NUNCA use [ ou ] fora dos delimitadores LaTeX.\n'
        '- **Destaque**: Use tags HTML <b>...</b> para enfatizar palavras-chave. PROIBIDO usar asteriscos (**).\n'
        '- **Markdown**: PROIBIDO usar qualquer sintaxe Markdown para formatação.\n\n'
        'OBJETIVO FINAL:\n'
        'O flashcard deve ser útil para revisão rápida de prova (nível véspera).';
  }

  static String studyUserPrompt({
    required Questao questao,
    required String? explicacaoBase,
  }) =>
      'QUESTÃO: ${questao.enunciado}\n'
      'TEXTO BASE: ${questao.textoBase ?? 'N/A'}\n'
      'GABARITO: ${questao.letraCorreta ?? '?'}\n'
      'EXPLICAÇÃO PRÉVIA: ${explicacaoBase ?? ''}\n';

  /// Conteúdo produzido para caderno (`resumo`) ou flashcard.
  static StudyContent parseStudyContent({
    required StudyContentType tipo,
    required String gerado,
    required String nomeMateria,
  }) {
    if (tipo == StudyContentType.resumo) {
      return StudyContent(conteudo: gerado);
    }
    final frenteMatch = RegExp(
      r'FRENTE:\s*(.*?)(?=\s*VERSO:|$)',
      dotAll: true,
      caseSensitive: false,
    ).firstMatch(gerado);
    final versoMatch = RegExp(
      r'VERSO:\s*(.*)',
      dotAll: true,
      caseSensitive: false,
    ).firstMatch(gerado);
    return StudyContent(
      frente: frenteMatch?.group(1)?.trim() ?? 'Revisão: $nomeMateria',
      verso: versoMatch?.group(1)?.trim() ?? gerado,
    );
  }

  /// Remove blockquotes/tabelas do início das linhas e normaliza espaços,
  /// como `re.sub(r'(?m)^[ \t]*[>|][ \t]*', ' ', ...)`.
  static String sanitizeExplanation(String texto) {
    final semPrefixo = texto.replaceAll(
      RegExp(r'^[ \t]*[>|][ \t]*', multiLine: true),
      ' ',
    );
    return semPrefixo.replaceAll(RegExp(r' +'), ' ');
  }

  /// URLs de imagens embutidas no HTML do enunciado/alternativas.
  static List<String> imageUrls({
    required Questao questao,
    String? legacyImageUrl,
  }) {
    final urls = <String>[];
    if (legacyImageUrl != null && legacyImageUrl.isNotEmpty) {
      urls.add(legacyImageUrl);
    }
    final pattern = RegExp(
      r'''<img[^>]+src=["']([^"']+)["']''',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(questao.enunciado)) {
      urls.add(match.group(1)!);
    }
    for (final alternativa in questao.alternativas) {
      for (final match in pattern.allMatches(alternativa.texto)) {
        urls.add(match.group(1)!);
      }
    }
    return urls;
  }
}

class StudyContent {
  const StudyContent({this.conteudo, this.frente, this.verso});

  final String? conteudo;
  final String? frente;
  final String? verso;

  Map<String, dynamic> toJson() {
    if (conteudo != null) return {'conteudo': conteudo};
    return {'frente': frente ?? '', 'verso': verso ?? ''};
  }

  factory StudyContent.fromJson(
    Map<String, dynamic> json, {
    required StudyContentType tipo,
  }) {
    if (tipo == StudyContentType.resumo) {
      return StudyContent(conteudo: json['conteudo']?.toString() ?? '');
    }
    return StudyContent(
      frente: json['frente']?.toString() ?? '',
      verso: json['verso']?.toString() ?? '',
    );
  }
}

/// Resultado de salvar um resumo/flashcard gerado pela IA no caderno.
class StudyGenerationResult {
  const StudyGenerationResult({
    required this.tipo,
    this.jaPossuia = false,
    this.usouCacheGlobal = false,
    this.mensagem,
  });

  final StudyContentType tipo;
  final bool jaPossuia;
  final bool usouCacheGlobal;
  final String? mensagem;
}
