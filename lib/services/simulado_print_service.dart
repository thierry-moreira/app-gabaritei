import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/simulado.dart';
import 'pdf_fonts.dart';
import 'pdf_text.dart';

/// Abre a interface nativa de impressão/Salvar como PDF para uma prova.
class SimuladoPrintService {
  Future<bool> imprimir(SimuladoComQuestoes dados) {
    return Printing.layoutPdf(
      name: 'Simulado - ${dados.simulado.titulo}',
      format: PdfPageFormat.a4,
      onLayout: (format) => SimuladoPdfService.gerar(dados, formato: format),
    );
  }

  Future<bool> imprimirResultado(SimuladoResultadoArgs args) {
    return Printing.layoutPdf(
      name: 'Resultado - ${args.simulado.titulo}',
      format: PdfPageFormat.a4,
      onLayout: (format) =>
          SimuladoPdfService.gerarResultado(args, formato: format),
    );
  }
}

class SimuladoPdfService {
  const SimuladoPdfService._();

  static Future<Uint8List> gerar(
    SimuladoComQuestoes dados, {
    PdfPageFormat formato = PdfPageFormat.a4,
    DateTime? agora,
  }) async {
    final data = DateFormat('dd/MM/yyyy').format(agora ?? DateTime.now());
    final tema = await PdfFonts.tema();
    final document = pw.Document(
      theme: tema,
      title: 'Simulado - ${dados.simulado.titulo}',
      author: 'Gabaritei Questões',
    );
    document.addPage(
      pw.MultiPage(
        pageFormat: formato,
        margin: const pw.EdgeInsets.fromLTRB(42, 48, 42, 52),
        maxPages: 200,
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 10),
          margin: const pw.EdgeInsets.only(bottom: 14),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.8),
            ),
          ),
          child: pw.Row(
            children: [
              pw.Container(
                width: 22,
                height: 22,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue800,
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Text(
                  'G',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 9),
              pw.Expanded(
                child: pw.Text(
                  dados.simulado.titulo,
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                  style: pw.TextStyle(
                    color: PdfColors.grey900,
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Text(
                '${dados.questoes.length} questões  |  $data',
                style: const pw.TextStyle(
                  color: PdfColors.grey600,
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey300, width: 0.7),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Gabaritei - O GPS da Aprovação',
                style: const pw.TextStyle(
                  color: PdfColors.grey600,
                  fontSize: 8,
                ),
              ),
              pw.Text(
                '${context.pageNumber} / ${context.pagesCount}',
                style: const pw.TextStyle(
                  color: PdfColors.grey600,
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ),
        build: (_) {
          final widgets = <pw.Widget>[];
          for (var i = 0; i < dados.questoes.length; i++) {
            final questao = dados.questoes[i];
            widgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 8, bottom: 5),
                child: pw.Text(
                  'QUESTÃO ${i + 1}  |  ${questao.nomeMateria ?? 'Geral'}'
                  '${questao.nomeBanca == null ? '' : '  |  ${questao.nomeBanca}'}'
                  '${questao.ano == null ? '' : '  |  ${questao.ano}'}',
                  style: pw.TextStyle(
                    color: PdfColors.blue800,
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            );
            final textoBase = _htmlParaTexto(questao.textoBase ?? '');
            if (textoBase.isNotEmpty) {
              widgets.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 5),
                  child: pw.Text(
                    textoBase,
                    style: pw.TextStyle(
                      color: PdfColors.grey700,
                      fontSize: 9,
                      fontStyle: pw.FontStyle.italic,
                      lineSpacing: 1.2,
                    ),
                  ),
                ),
              );
            }
            widgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 5),
                child: pw.Text(
                  _htmlParaTexto(questao.enunciado),
                  style: pw.TextStyle(
                    color: PdfColors.grey900,
                    fontSize: 10.5,
                    lineSpacing: 2,
                  ),
                ),
              ),
            );
            for (final alternativa in questao.alternativas) {
              widgets.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 8, bottom: 3),
                  child: pw.RichText(
                    text: pw.TextSpan(
                      style: const pw.TextStyle(
                        color: PdfColors.grey800,
                        fontSize: 9.5,
                      ),
                      children: [
                        pw.TextSpan(
                          text: '${alternativa.letra}) ',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.TextSpan(text: _htmlParaTexto(alternativa.texto)),
                      ],
                    ),
                  ),
                ),
              );
            }
          }
          widgets
            ..add(pw.SizedBox(height: 18))
            ..add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(
                  'GABARITO OFICIAL',
                  style: pw.TextStyle(
                    color: PdfColors.grey900,
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            );
          for (var i = 0; i < dados.questoes.length; i++) {
            widgets.add(
              pw.Text(
                'Questão ${i + 1}: ${dados.questoes[i].letraCorreta ?? 'N/A'}',
                style: pw.TextStyle(
                  color: PdfColors.grey800,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
          }
          return widgets;
        },
      ),
    );
    return document.save();
  }

  static Future<Uint8List> gerarResultado(
    SimuladoResultadoArgs args, {
    PdfPageFormat formato = PdfPageFormat.a4,
    DateTime? agora,
  }) async {
    final data = DateFormat('dd/MM/yyyy').format(agora ?? DateTime.now());
    final tema = await PdfFonts.tema();
    final document = pw.Document(
      theme: tema,
      title: 'Resultado - ${args.simulado.titulo}',
      author: 'Gabaritei Questões',
    );
    document.addPage(
      pw.MultiPage(
        pageFormat: formato,
        margin: const pw.EdgeInsets.all(48),
        header: (_) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 20),
          child: pw.Text(
            'Gabaritei Questões  |  Resultado do Simulado',
            style: pw.TextStyle(
              color: PdfColors.blue800,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Gerado em $data',
              style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8),
            ),
            pw.Text(
              '${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8),
            ),
          ],
        ),
        build: (_) => [
          pw.Text(
            args.simulado.titulo,
            style: pw.TextStyle(
              color: PdfColors.grey900,
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Nota final: ${args.resultado.nota.toStringAsFixed(2)} / 10',
            style: pw.TextStyle(
              color: args.resultado.nota >= 7
                  ? PdfColors.green800
                  : PdfColors.red800,
              fontSize: 17,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Acertos: ${args.resultado.acertos}   |   '
            'Erros: ${args.resultado.total - args.resultado.acertos}   |   '
            'Total: ${args.resultado.total}',
            style: const pw.TextStyle(color: PdfColors.grey800, fontSize: 11),
          ),
          if (args.resultado.ranking.isNotEmpty) ...[
            pw.SizedBox(height: 24),
            pw.Text(
              'Ranking Global',
              style: pw.TextStyle(
                color: PdfColors.grey900,
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            for (var i = 0; i < args.resultado.ranking.length; i++)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Text(
                  '${i + 1}. ${args.resultado.ranking[i].nomeUsuario}  |  '
                  '${args.resultado.ranking[i].respostasCorretas}/'
                  '${args.resultado.ranking[i].totalQuestoes}  |  '
                  'Nota ${args.resultado.ranking[i].nota.toStringAsFixed(2)}',
                  style: const pw.TextStyle(
                    color: PdfColors.grey800,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
    return document.save();
  }

  static String _htmlParaTexto(String html) {
    if (html.isEmpty) return '';
    final texto = html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
    return PdfText.normalizar(texto);
  }
}
