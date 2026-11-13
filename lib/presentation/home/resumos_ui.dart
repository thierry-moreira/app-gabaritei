import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../../core/ui/responsive.dart';
import '../../repositories/study_ai_repository.dart';
import '../../services/resumo_content_formatter.dart';
import '../widgets/latex_text.dart';
import 'dashboard_shell.dart';

@immutable
class ResumosColors {
  const ResumosColors({
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
    required this.accent,
    required this.accentSoft,
    required this.accentBorder,
    required this.danger,
    required this.dangerSoft,
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
  final Color accent;
  final Color accentSoft;
  final Color accentBorder;
  final Color danger;
  final Color dangerSoft;

  static ResumosColors of(bool isDark) => isDark ? dark : light;

  static const light = ResumosColors(
    isDark: false,
    bg: Color(0xFFF8FAFC),
    card: Colors.white,
    cardSoft: Color(0xFFF8FAFC),
    border: Color(0xFFE2E8F0),
    dashedBorder: Color(0xFFCBD5E1),
    text: Color(0xFF0F172A),
    secondary: Color(0xFF64748B),
    muted: Color(0xFF94A3B8),
    primary: Color(0xFF1E2D42),
    accent: Color(0xFF2563EB),
    accentSoft: Color(0xFFEFF6FF),
    accentBorder: Color(0xFFDBEAFE),
    danger: Color(0xFFDC2626),
    dangerSoft: Color(0xFFFEF2F2),
  );

  static const dark = ResumosColors(
    isDark: true,
    bg: Color(0xFF060913),
    card: Color(0xFF0A101F),
    cardSoft: Color(0xFF0B1220),
    border: Color(0xFF15213B),
    dashedBorder: Color(0xFF1A2947),
    text: Color(0xFFF8FAFC),
    secondary: Color(0xFF94A3B8),
    muted: Color(0xFF64748B),
    primary: Color(0xFF4F46E5),
    accent: Color(0xFF6366F1),
    accentSoft: Color(0xFF161D3C),
    accentBorder: Color(0xFF353B7D),
    danger: Color(0xFFF87171),
    dangerSoft: Color(0xFF2A1416),
  );
}

class ResumosPageShell extends ConsumerWidget {
  const ResumosPageShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = ResumosColors.of(isDark);
    final perfil = ref.watch(perfilAtualProvider);
    final painel = ref.watch(painelProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: Column(
        children: [
          DashboardTopBar(
            isDark: isDark,
            streak: painel.value?.ofensiva ?? 0,
            username: perfil.value?.username ?? 'Estudante',
            onToggleTheme: () =>
                ref.read(themeModeProvider.notifier).alternar(isDark),
            onLogout: () => _sair(context, ref),
          ),
          Expanded(child: child),
          DashboardBottomNav(
            isDark: isDark,
            selectedIndex: 4,
            onSelected: (index) => _navegar(context, index),
          ),
        ],
      ),
    );
  }

  void _navegar(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
      case 1:
        context.go('/questoes');
      case 2:
        context.go('/cadernos');
      case 3:
        context.go('/flashcards');
      case 4:
        return;
      case 5:
        context.go('/simulados');
      case 6:
        context.go('/editais');
      case 7:
        context.go('/conta');
      default:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                '${DashboardBottomNav.labelFor(index)} chega em breve.',
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
    }
  }

  Future<void> _sair(BuildContext context, WidgetRef ref) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair da conta'),
        content: const Text('Deseja encerrar a sessão neste aparelho?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;
    await ref.read(authGatewayProvider).signOut();
    if (!context.mounted) return;
    ref.invalidate(perfilAtualProvider);
    ref.invalidate(painelProvider);
    ref.invalidate(resumosPorMateriaProvider);
    context.go('/login');
  }
}

class ResumosPanel extends StatelessWidget {
  const ResumosPanel({
    super.key,
    required this.colors,
    required this.child,
    this.padding,
    this.radius = 18,
  });

  final ResumosColors colors;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: colors.border),
      ),
      child: child,
    );
  }
}

class ResumosDashedPanel extends StatelessWidget {
  const ResumosDashedPanel({
    super.key,
    required this.colors,
    required this.child,
    this.padding,
    this.radius = 20,
  });

  final ResumosColors colors;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedBorderPainter(
        color: colors.dashedBorder,
        radius: radius,
      ),
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: colors.isDark
              ? colors.cardSoft.withValues(alpha: 0.72)
              : colors.card,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final fim = math.min(distance + 7, metric.length);
        canvas.drawPath(metric.extractPath(distance, fim), paint);
        distance = fim + 5;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class ResumosRichContent extends StatelessWidget {
  const ResumosRichContent({
    super.key,
    required this.content,
    required this.colors,
    required this.responsive,
  });

  final String content;
  final ResumosColors colors;
  final Responsive responsive;

  @override
  Widget build(BuildContext context) {
    final blocks = ResumoContentFormatter.parse(content);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final block in blocks) ...[
          if (block.kind == ResumoBlockKind.heading)
            Padding(
              padding: EdgeInsets.only(
                top: responsive.sp(block.level <= 3 ? 7 : 4),
                bottom: responsive.sp(4),
              ),
              child: _text(
                block,
                fontSize: responsive.sp(14.5),
                weight: FontWeight.w700,
              ),
            )
          else if (block.kind == ResumoBlockKind.bullet)
            Padding(
              padding: EdgeInsets.only(
                left: responsive.sp(4),
                bottom: responsive.sp(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: responsive.sp(1)),
                    child: Text(
                      '•',
                      style: TextStyle(
                        color: colors.accent,
                        fontSize: responsive.sp(13),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(width: responsive.sp(8)),
                  Expanded(child: _text(block, fontSize: responsive.sp(12.5))),
                ],
              ),
            )
          else
            Padding(
              padding: EdgeInsets.only(bottom: responsive.sp(8)),
              child: _text(block, fontSize: responsive.sp(12.5)),
            ),
        ],
      ],
    );
  }

  Widget _text(
    ResumoContentBlock block, {
    required double fontSize,
    FontWeight weight = FontWeight.w400,
  }) {
    return LatexText(
      block.raw,
      style: TextStyle(
        color: colors.text,
        fontSize: fontSize,
        height: 1.55,
        fontWeight: weight,
      ),
    );
  }
}

class ResumosFooter extends StatelessWidget {
  const ResumosFooter({
    super.key,
    required this.colors,
    required this.responsive,
  });

  final ResumosColors colors;
  final Responsive responsive;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: responsive.sp(8), bottom: responsive.sp(18)),
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

class ResumosFeedbackDraft {
  const ResumosFeedbackDraft({required this.motivo, required this.relato});

  final String motivo;
  final String relato;
}

Future<ResumosFeedbackDraft?> showResumosFeedbackDialog(
  BuildContext context, {
  required ResumosColors colors,
}) {
  return showDialog<ResumosFeedbackDraft>(
    context: context,
    builder: (_) => _ResumosFeedbackDialog(colors: colors),
  );
}

class _ResumosFeedbackDialog extends StatefulWidget {
  const _ResumosFeedbackDialog({required this.colors});

  final ResumosColors colors;

  @override
  State<_ResumosFeedbackDialog> createState() => _ResumosFeedbackDialogState();
}

class _ResumosFeedbackDialogState extends State<_ResumosFeedbackDialog> {
  final _formKey = GlobalKey<FormState>();
  final _relato = TextEditingController();
  String? _motivo;

  @override
  void dispose() {
    _relato.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return AlertDialog(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      title: Text(
        'Reportar problema no resumo',
        style: TextStyle(color: colors.text, fontWeight: FontWeight.w700),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              key: const Key('resumo-feedback-motivo'),
              isExpanded: true,
              initialValue: _motivo,
              decoration: const InputDecoration(labelText: 'Motivo'),
              items: [
                for (final item in StudyAiRepository.motivosFeedback.entries)
                  DropdownMenuItem(value: item.key, child: Text(item.value)),
              ],
              validator: (value) =>
                  value == null ? 'Selecione o motivo.' : null,
              onChanged: (value) => setState(() => _motivo = value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('resumo-feedback-relato'),
              controller: _relato,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Detalhes (opcional)',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancelar', style: TextStyle(color: colors.secondary)),
        ),
        FilledButton(
          key: const Key('resumo-feedback-enviar'),
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            Navigator.of(context).pop(
              ResumosFeedbackDraft(
                motivo: _motivo!,
                relato: _relato.text.trim(),
              ),
            );
          },
          style: FilledButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 48),
          ),
          child: const Text('Enviar'),
        ),
      ],
    );
  }
}

String resumosErrorMessage(Object? error) {
  if (error is AppException) return error.message;
  if (error is StateError) {
    return 'Sua sessão não está disponível. Entre novamente.';
  }
  return 'Não foi possível concluir a operação. Tente novamente.';
}

void showResumosMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
}
