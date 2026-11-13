import 'package:flutter/material.dart';

/// Bloco de código com a mesma leitura do desktop: fonte monoespaçada,
/// quebras de linha e indentação preservadas e rolagem horizontal quando
/// alguma linha não couber na tela.
///
/// O desktop renderiza `<pre><code>` com o `white-space: pre` do navegador.
/// Aqui o texto é desenhado sem quebra automática dentro de um scroll
/// horizontal, para que os espaços à esquerda continuem alinhando o código.
class CodeBlockView extends StatelessWidget {
  const CodeBlockView(
    this.codigo, {
    super.key,
    this.style,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.backgroundColor,
    this.borderColor,
  });

  final String codigo;
  final TextStyle? style;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final escuro = tema.brightness == Brightness.dark;
    final base = DefaultTextStyle.of(context).style.merge(style);
    final fundo =
        backgroundColor ??
        (escuro ? const Color(0xFF0B1220) : const Color(0xFFF1F5F9));
    final borda =
        borderColor ??
        (escuro ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0));
    final cor =
        base.color ??
        (escuro ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A));

    final estiloCodigo = base.copyWith(
      fontFamily: 'RobotoMono',
      fontFamilyFallback: const ['monospace', 'Courier New', 'Courier'],
      fontSize: (base.fontSize ?? 14) * 0.94,
      height: 1.5,
      color: cor,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borda),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: Text(
          codigo,
          style: estiloCodigo,
          softWrap: false,
          textAlign: TextAlign.left,
        ),
      ),
    );
  }
}
