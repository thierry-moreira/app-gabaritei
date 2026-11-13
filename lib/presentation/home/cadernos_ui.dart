import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/ui/responsive.dart';

/// Paleta compartilhada pelas telas de cadernos (lista e detalhe).
///
/// Segue os tokens do Stitch para os temas claro e escuro: fundo quente no
/// claro, azul quase preto no escuro e botões em azul-marinho/índigo.
@immutable
class CadernosColors {
  const CadernosColors({
    required this.isDark,
    required this.bg,
    required this.card,
    required this.cardSoft,
    required this.border,
    required this.dashedBorder,
    required this.text,
    required this.secondary,
    required this.muted,
    required this.primary,
    required this.primaryHover,
    required this.primarySoft,
    required this.primaryBorder,
    required this.accent,
    required this.accentSoft,
    required this.success,
    required this.successSoft,
    required this.danger,
    required this.dangerSoft,
    required this.shadow,
  });

  final bool isDark;
  final Color bg;
  final Color card;
  final Color cardSoft;
  final Color border;
  final Color dashedBorder;
  final Color text;
  final Color secondary;
  final Color muted;
  final Color primary;
  final Color primaryHover;
  final Color primarySoft;
  final Color primaryBorder;
  final Color accent;
  final Color accentSoft;
  final Color success;
  final Color successSoft;
  final Color danger;
  final Color dangerSoft;
  final Color shadow;

  static CadernosColors of(bool isDark) => isDark ? dark : light;

  static const light = CadernosColors(
    isDark: false,
    bg: Color(0xFFF6F6F2),
    card: Colors.white,
    cardSoft: Color(0xFFF8FAFC),
    border: Color(0xFFE2E8F0),
    dashedBorder: Color(0xFFCBD5E1),
    text: Color(0xFF0F172A),
    secondary: Color(0xFF475569),
    muted: Color(0xFF94A3B8),
    primary: Color(0xFF2D4356),
    primaryHover: Color(0xFF233547),
    primarySoft: Color(0xFFEEF2F6),
    primaryBorder: Color(0xFFD9E2EC),
    accent: Color(0xFF2563EB),
    accentSoft: Color(0xFFEFF6FF),
    success: Color(0xFF16A34A),
    successSoft: Color(0xFFF0FDF4),
    danger: Color(0xFFDC2626),
    dangerSoft: Color(0xFFFEF2F2),
    shadow: Color(0x140F172A),
  );

  static const dark = CadernosColors(
    isDark: true,
    bg: Color(0xFF080C14),
    card: Color(0xFF0D1320),
    cardSoft: Color(0xFF111B2A),
    border: Color(0xFF1E293B),
    dashedBorder: Color(0xFF222F43),
    text: Color(0xFFF1F5F9),
    secondary: Color(0xFF94A3B8),
    muted: Color(0xFF64748B),
    primary: Color(0xFF6366F1),
    primaryHover: Color(0xFF5457E5),
    primarySoft: Color(0xFF161E33),
    primaryBorder: Color(0xFF2A3550),
    accent: Color(0xFF60A5FA),
    accentSoft: Color(0xFF132033),
    success: Color(0xFF4ADE80),
    successSoft: Color(0xFF0F2419),
    danger: Color(0xFFF87171),
    dangerSoft: Color(0xFF2A1416),
    shadow: Color(0x33000000),
  );
}

/// Caixa com borda tracejada arredondada (estado vazio dos cadernos).
///
/// O Flutter não traz borda tracejada nativa; o painter percorre o caminho do
/// retângulo arredondado desenhando pequenos segmentos.
class CadernosDashedBox extends StatelessWidget {
  const CadernosDashedBox({
    super.key,
    required this.colors,
    required this.radius,
    required this.child,
    this.padding,
  });

  final CadernosColors colors;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedRoundedBorderPainter(
        color: colors.dashedBorder,
        radius: radius,
      ),
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: colors.isDark
              ? colors.card.withValues(alpha: 0.6)
              : colors.card,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: colors.isDark
              ? null
              : [
                  BoxShadow(
                    color: colors.shadow,
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: child,
      ),
    );
  }
}

class _DashedRoundedBorderPainter extends CustomPainter {
  const _DashedRoundedBorderPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  static const _dash = 7.0;
  static const _gap = 5.0;
  static const _strokeWidth = 1.6;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + _dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

/// Etiqueta compacta usada nos cards de questão (matéria, banca, ano).
class CadernosTag extends StatelessWidget {
  const CadernosTag({
    super.key,
    required this.text,
    required this.background,
    required this.foreground,
    required this.responsive,
    this.maxWidth = 220,
  });

  final String text;
  final Color background;
  final Color foreground;
  final Responsive responsive;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: responsive.sp(maxWidth)),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: responsive.sp(7),
          vertical: responsive.sp(3),
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(responsive.sp(6)),
          border: Border.all(color: foreground.withValues(alpha: 0.16)),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: responsive.sp(10.5),
            fontWeight: FontWeight.w600,
            height: 1.2,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

/// Rodapé de licença compartilhado pelas telas de cadernos.
class CadernosFooter extends StatelessWidget {
  const CadernosFooter({
    super.key,
    required this.colors,
    required this.responsive,
  });

  final CadernosColors colors;
  final Responsive responsive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: responsive.sp(4),
        bottom: responsive.sp(16),
      ),
      child: Text.rich(
        TextSpan(
          style: TextStyle(fontSize: responsive.sp(10.5), color: colors.muted),
          children: [
            TextSpan(
              text: 'Gabaritei Questões',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colors.secondary,
              ),
            ),
            const TextSpan(text: ' © 2026. Software livre.'),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
