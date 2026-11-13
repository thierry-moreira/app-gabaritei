import 'package:flutter/material.dart';

import 'latex_text.dart';

/// Citação (`<blockquote>`) com a mesma leitura do desktop: bloco com borda
/// esquerda, fundo suave e conteúdo renderizado com toda a formatação.
class BlockquoteView extends StatelessWidget {
  const BlockquoteView(
    this.conteudo, {
    super.key,
    this.style,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.backgroundColor,
    this.borderColor,
  });

  final String conteudo;
  final TextStyle? style;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final escuro = tema.brightness == Brightness.dark;
    final base = DefaultTextStyle.of(context).style.merge(style);
    final borda =
        borderColor ??
        (escuro ? const Color(0xFF6366F1) : const Color(0xFF1D4ED8));
    final fundo =
        backgroundColor ??
        (escuro ? const Color(0x146366F1) : const Color(0x0A1D4ED8));

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: padding,
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: borda, width: 3)),
      ),
      child: LatexText(
        conteudo,
        style: base.copyWith(fontStyle: FontStyle.italic),
      ),
    );
  }
}
