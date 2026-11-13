import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/study.dart';
import 'pdf_fonts.dart';
import 'pdf_text.dart';
import 'resumo_content_formatter.dart';

/// Aciona a folha de impressão/PDF nativa do Android, iOS ou desktop.
class ResumoPrintService {
  Future<bool> imprimir({
    required String nomeMateria,
    required List<Resumo> resumos,
  }) {
    return Printing.layoutPdf(
      name: 'Resumos - $nomeMateria',
      format: PdfPageFormat.a4,
      onLayout: (formato) => ResumoPdfService.gerar(
        nomeMateria: nomeMateria,
        resumos: resumos,
        formato: formato,
      ),
    );
  }
}

/// Monta o PDF da matéria com todos os resumos, como a versão desktop.
class ResumoPdfService {
  const ResumoPdfService._();

  static Future<Uint8List> gerar({
    required String nomeMateria,
    required List<Resumo> resumos,
    PdfPageFormat formato = PdfPageFormat.a4,
    DateTime? agora,
  }) async {
    final data = DateFormat('dd/MM/yyyy').format(agora ?? DateTime.now());
    final tema = await PdfFonts.tema();
    final documento = pw.Document(
      theme: tema,
      title: 'Caderno de Resumos - $nomeMateria',
      author: 'Gabaritei Questões',
      subject: 'Resumos de $nomeMateria',
    );

    documento.addPage(
      pw.MultiPage(
        pageFormat: formato,
        margin: const pw.EdgeInsets.fromLTRB(44, 48, 44, 54),
        maxPages: 200,
        header: (contexto) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 18),
          padding: const pw.EdgeInsets.only(bottom: 10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.8),
            ),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
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
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Gabaritei Questões',
                      style: pw.TextStyle(
                        color: PdfColors.grey700,
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      nomeMateria,
                      maxLines: 1,
                      overflow: pw.TextOverflow.clip,
                      style: pw.TextStyle(
                        color: PdfColors.grey900,
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Text(
                '$data  |  ${resumos.length} ${resumos.length == 1 ? 'resumo' : 'resumos'}',
                style: const pw.TextStyle(
                  color: PdfColors.grey600,
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ),
        footer: (contexto) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 12),
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
                'Gabaritei - GPS da Aprovação  |  Gerado em $data',
                style: const pw.TextStyle(
                  color: PdfColors.grey600,
                  fontSize: 8,
                ),
              ),
              pw.Text(
                '${contexto.pageNumber} / ${contexto.pagesCount}',
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
          for (var i = 0; i < resumos.length; i++) {
            if (i > 0) {
              widgets.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4, bottom: 16),
                  child: pw.Divider(color: PdfColors.grey300, thickness: 0.6),
                ),
              );
            }
            widgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 9),
                child: pw.Text(
                  'RESUMO #${i + 1}',
                  style: pw.TextStyle(
                    color: PdfColors.blue800,
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            );
            for (final bloco in ResumoContentFormatter.parse(
              resumos[i].conteudo,
            )) {
              widgets.add(_blocoPdf(bloco));
              widgets.add(pw.SizedBox(height: 5));
            }
          }
          if (widgets.isEmpty) {
            widgets.add(
              pw.Text(
                'Nenhum resumo disponível.',
                style: const pw.TextStyle(
                  color: PdfColors.grey700,
                  fontSize: 11,
                ),
              ),
            );
          }
          return widgets;
        },
      ),
    );

    return documento.save();
  }

  static pw.Widget _blocoPdf(ResumoContentBlock bloco) {
    final isTitulo = bloco.kind == ResumoBlockKind.heading;
    final estiloBase = pw.TextStyle(
      color: isTitulo ? PdfColors.grey900 : PdfColors.grey800,
      fontSize: isTitulo ? (bloco.level <= 3 ? 14 : 12) : 10.5,
      lineSpacing: 1.5,
      fontWeight: isTitulo ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.RichText(
      text: pw.TextSpan(
        style: estiloBase,
        children: [
          if (bloco.kind == ResumoBlockKind.bullet)
            const pw.TextSpan(text: '- '),
          for (final run in bloco.runs)
            pw.TextSpan(
              text: PdfText.normalizar(run.text),
              style: pw.TextStyle(
                fontWeight: run.bold ? pw.FontWeight.bold : null,
                fontStyle: run.italic ? pw.FontStyle.italic : null,
                font: run.code ? pw.Font.courier() : null,
                color: run.code ? PdfColors.blueGrey800 : null,
              ),
            ),
        ],
      ),
    );
  }
}
