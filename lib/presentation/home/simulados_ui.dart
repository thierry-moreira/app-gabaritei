import 'package:flutter/material.dart';

import '../../core/ui/responsive.dart';
import 'flashcards_ui.dart';

@immutable
class SimuladosColors {
  const SimuladosColors({
    required this.isDark,
    required this.bg,
    required this.card,
    required this.cardSoft,
    required this.border,
    required this.text,
    required this.secondary,
    required this.muted,
    required this.primary,
    required this.accent,
    required this.accentSoft,
    required this.accentBorder,
    required this.community,
    required this.communitySoft,
    required this.private,
    required this.privateSoft,
    required this.success,
    required this.successSoft,
    required this.danger,
    required this.dangerSoft,
  });

  final bool isDark;
  final Color bg;
  final Color card;
  final Color cardSoft;
  final Color border;
  final Color text;
  final Color secondary;
  final Color muted;
  final Color primary;
  final Color accent;
  final Color accentSoft;
  final Color accentBorder;
  final Color community;
  final Color communitySoft;
  final Color private;
  final Color privateSoft;
  final Color success;
  final Color successSoft;
  final Color danger;
  final Color dangerSoft;

  static SimuladosColors of(bool isDark) => isDark ? dark : light;

  static const light = SimuladosColors(
    isDark: false,
    bg: Color(0xFFF8FAFC),
    card: Colors.white,
    cardSoft: Color(0xFFF1F5F9),
    border: Color(0xFFE2E8F0),
    text: Color(0xFF0F172A),
    secondary: Color(0xFF64748B),
    muted: Color(0xFF94A3B8),
    primary: Color(0xFF1E293B),
    accent: Color(0xFF2563EB),
    accentSoft: Color(0xFFEFF6FF),
    accentBorder: Color(0xFFBFDBFE),
    community: Color(0xFF2563EB),
    communitySoft: Color(0xFFEFF6FF),
    private: Color(0xFFD97706),
    privateSoft: Color(0xFFFFFBEB),
    success: Color(0xFF15803D),
    successSoft: Color(0xFFF0FDF4),
    danger: Color(0xFFDC2626),
    dangerSoft: Color(0xFFFEF2F2),
  );

  static const dark = SimuladosColors(
    isDark: true,
    bg: Color(0xFF070B12),
    card: Color(0xFF0F172A),
    cardSoft: Color(0xFF131D31),
    border: Color(0xFF1E293B),
    text: Color(0xFFF3F4F6),
    secondary: Color(0xFF94A3B8),
    muted: Color(0xFF64748B),
    primary: Color(0xFF4F46E5),
    accent: Color(0xFF6366F1),
    accentSoft: Color(0xFF171735),
    accentBorder: Color(0xFF4F46E5),
    community: Color(0xFF38BDF8),
    communitySoft: Color(0xFF102535),
    private: Color(0xFFF59E0B),
    privateSoft: Color(0xFF2A2110),
    success: Color(0xFF4ADE80),
    successSoft: Color(0xFF0F2419),
    danger: Color(0xFFF87171),
    dangerSoft: Color(0xFF2A1416),
  );
}

class SimuladoPanel extends StatelessWidget {
  const SimuladoPanel({
    super.key,
    required this.colors,
    required this.child,
    this.padding,
    this.radius = 18,
  });

  final SimuladosColors colors;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: colors.card,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: colors.border),
    ),
    child: child,
  );
}

class SimuladoPageShell extends StatelessWidget {
  const SimuladoPageShell({
    super.key,
    required this.child,
    required this.colors,
  });

  final Widget child;
  final SimuladosColors colors;

  @override
  Widget build(BuildContext context) => FlashcardsPageShell(
    selectedIndex: 5,
    backgroundColor: colors.bg,
    child: child,
  );
}

class SimuladosFooter extends StatelessWidget {
  const SimuladosFooter({
    super.key,
    required this.colors,
    required this.responsive,
  });

  final SimuladosColors colors;
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
              color: colors.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const TextSpan(text: ' © 2026. Software livre.'),
        ],
      ),
      textAlign: TextAlign.center,
    ),
  );
}

String simuladosErrorMessage(Object? error) {
  if (error is StateError) {
    return 'Sua sessão não está disponível. Entre novamente.';
  }
  return 'Não foi possível concluir a operação. Tente novamente.';
}

void showSimuladosMessage(BuildContext context, String message) {
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
