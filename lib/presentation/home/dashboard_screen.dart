import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../../core/ui/responsive.dart';
import '../../models/stats.dart';
import 'dashboard_shell.dart';

/// Dashboard (Home) - Gabaritei Questões.
///
/// Tela inicial após o login: visão resumida com boas-vindas, métricas da
/// semana, ofensiva e frequência de estudos. Espelha o painel `/aluno/painel`
/// do app desktop e o layout mobile do Stitch; o raio-x completo continua
/// disponível em um toque.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _diasAtivos = 7;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _DashColors.of(isDark);
    final perfil = ref.watch(perfilAtualProvider);
    final painel = ref.watch(painelProvider);

    final username = perfil.value?.username ?? 'Estudante';
    final resumo = painel.value;

    return Scaffold(
      backgroundColor: colors.bg,
      body: Column(
        children: [
          DashboardTopBar(
            isDark: isDark,
            streak: resumo?.ofensiva ?? 0,
            username: username,
            onToggleTheme: () =>
                ref.read(themeModeProvider.notifier).alternar(isDark),
            onLogout: _sair,
          ),
          Expanded(child: _buildConteudo(colors, username, painel, responsive)),
          DashboardBottomNav(
            isDark: isDark,
            selectedIndex: 0,
            onSelected: _onBottomNavSelected,
          ),
        ],
      ),
    );
  }

  Widget _buildConteudo(
    _DashColors colors,
    String username,
    AsyncValue<DashboardResumo> painel,
    Responsive responsive,
  ) {
    if (painel.isLoading) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }

    if (painel.hasError) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(responsive.isCompact ? 24 : 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: responsive.sp(40),
                  color: colors.muted,
                ),
                const SizedBox(height: 12),
                Text(
                  'Não foi possível carregar seu painel.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: responsive.sp(14),
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${painel.error}',
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: responsive.sp(11),
                    color: colors.muted,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.invalidate(perfilAtualProvider);
                    ref.invalidate(painelProvider);
                  },
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final resumo = painel.requireValue;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: responsive.pagePadding,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: responsive.dashboardMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _GreetingSection(
                colors: colors,
                username: username,
                evolucao: resumo.evolucaoPercentual,
                onRaioX: () => context.push('/dashboard-detailed'),
                onResolverQuestoes: () => context.go('/questoes'),
              ),
              SizedBox(height: responsive.gap),
              _MetricsSection(colors: colors, resumo: resumo),
              SizedBox(height: responsive.gap),
              _FrequencyCard(
                colors: colors,
                resumo: resumo,
                diasAtivos: _diasAtivos,
                onDiasChanged: (dias) => setState(() => _diasAtivos = dias),
              ),
              const SizedBox(height: 8),
              _Footer(colors: colors),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sair() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da conta'),
        content: const Text('Deseja encerrar a sessão neste aparelho?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    await ref.read(authGatewayProvider).signOut();
    if (!mounted) return;

    ref.invalidate(perfilAtualProvider);
    ref.invalidate(painelProvider);
    context.go('/login');
  }

  void _onBottomNavSelected(int index) {
    switch (index) {
      case 0:
        return;
      case 1:
        context.go('/questoes');
      case 2:
        context.go('/cadernos');
      case 3:
        context.go('/flashcards');
      case 4:
        context.go('/resumos');
      case 5:
        context.go('/simulados');
      case 6:
        context.go('/editais');
      case 7:
        context.go('/conta');
      default:
        _mostrarEmBreve(DashboardBottomNav.labelFor(index));
    }
  }

  void _mostrarEmBreve(String recurso) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$recurso chega em breve.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }
}

// ---------------------------------------------------------------------------
// Paleta
// ---------------------------------------------------------------------------

/// Cores do painel nos temas claro e escuro, seguindo os tokens do Stitch.
class _DashColors {
  const _DashColors({
    required this.isDark,
    required this.bg,
    required this.card,
    required this.border,
    required this.borderSoft,
    required this.text,
    required this.secondary,
    required this.muted,
    required this.primary,
    required this.accent,
    required this.iconBg,
    required this.iconColor,
    required this.badgeBg,
    required this.badgeBorder,
    required this.badgeText,
    required this.actionBg,
    required this.actionBorder,
    required this.actionText,
    required this.actionIcon,
    required this.ctaBg,
    required this.ctaBorder,
    required this.ringTrack,
    required this.streakBg,
    required this.streakGradient,
    required this.streakBorder,
    required this.streakLabel,
    required this.streakUnit,
    required this.streakMessage,
    required this.flame,
    required this.chartGrid,
    required this.chartAxis,
    required this.chartY,
    required this.chartX,
    required this.chartPeak,
    required this.chartLine,
    required this.chartArea,
    required this.tooltipBg,
    required this.tooltipBorder,
    required this.tabBg,
    required this.tabBorder,
    required this.tabActiveBg,
    required this.tabActiveText,
    required this.tabInactiveText,
    required this.footerStrong,
    required this.footerText,
    required this.cardShadow,
  });

  final bool isDark;
  final Color bg;
  final Color card;
  final Color border;
  final Color borderSoft;
  final Color text;
  final Color secondary;
  final Color muted;
  final Color primary;
  final Color accent;
  final Color iconBg;
  final Color iconColor;
  final Color badgeBg;
  final Color badgeBorder;
  final Color badgeText;
  final Color actionBg;
  final Color actionBorder;
  final Color actionText;
  final Color actionIcon;
  final Color ctaBg;
  final Color ctaBorder;
  final Color ringTrack;
  final Color streakBg;
  final List<Color>? streakGradient;
  final Color streakBorder;
  final Color streakLabel;
  final Color streakUnit;
  final Color streakMessage;
  final Color flame;
  final Color chartGrid;
  final Color chartAxis;
  final Color chartY;
  final Color chartX;
  final Color chartPeak;
  final Color chartLine;
  final Color chartArea;
  final Color tooltipBg;
  final Color tooltipBorder;
  final Color tabBg;
  final Color tabBorder;
  final Color tabActiveBg;
  final Color tabActiveText;
  final Color tabInactiveText;
  final Color footerStrong;
  final Color footerText;
  final List<BoxShadow> cardShadow;

  static _DashColors of(bool isDark) => isDark ? dark : light;

  static const light = _DashColors(
    isDark: false,
    bg: Color(0xFFF7F8F9),
    card: Colors.white,
    border: Color(0xFFE2E8F0),
    borderSoft: Color(0xFFF1F5F9),
    text: Color(0xFF0F172A),
    secondary: Color(0xFF64748B),
    muted: Color(0xFF94A3B8),
    primary: Color(0xFF2F4F75),
    accent: Color(0xFF3B5998),
    iconBg: Color(0xFFF1F5F9),
    iconColor: Color(0xFF64748B),
    badgeBg: Color(0xFFECFDF5),
    badgeBorder: Color(0xFFD1FAE5),
    badgeText: Color(0xFF047857),
    actionBg: Colors.white,
    actionBorder: Color(0xFFE2E8F0),
    actionText: Color(0xFF334155),
    actionIcon: Color(0xFF64748B),
    ctaBg: Color(0xFF2B4C74),
    ctaBorder: Color(0x00000000),
    ringTrack: Color(0xFFF1F5F9),
    streakBg: Color(0xFFF0F7F4),
    streakGradient: null,
    streakBorder: Color(0xFFD5EADB),
    streakLabel: Color(0xFF2D7349),
    streakUnit: Color(0xFF334155),
    streakMessage: Color(0xFF475569),
    flame: Color(0xFF2D6A4F),
    chartGrid: Color(0xFFEEF2F6),
    chartAxis: Color(0xFFCBD5E1),
    chartY: Color(0xFF94A3B8),
    chartX: Color(0xFF64748B),
    chartPeak: Color(0xFF1E293B),
    chartLine: Color(0xFF37557A),
    chartArea: Color(0xFF3B5998),
    tooltipBg: Colors.white,
    tooltipBorder: Color(0xFFE2E8F0),
    tabBg: Color(0xFFF1F5F9),
    tabBorder: Color(0xFFE2E8F0),
    tabActiveBg: Colors.white,
    tabActiveText: Color(0xFF0F172A),
    tabInactiveText: Color(0xFF64748B),
    footerStrong: Color(0xFF64748B),
    footerText: Color(0xFF94A3B8),
    cardShadow: [
      BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2)),
    ],
  );

  static const dark = _DashColors(
    isDark: true,
    bg: Color(0xFF0B0E14),
    card: Color(0xFF131823),
    border: Color(0xFF1F2737),
    borderSoft: Color(0xFF1F2737),
    text: Color(0xFFF1F5F9),
    secondary: Color(0xFF94A3B8),
    muted: Color(0xFF64748B),
    primary: Color(0xFF3B82F6),
    accent: Color(0xFF60A5FA),
    iconBg: Color(0xFF1B2333),
    iconColor: Color(0xFF60A5FA),
    badgeBg: Color(0xFF022C22),
    badgeBorder: Color(0xFF065F46),
    badgeText: Color(0xFF34D399),
    actionBg: Color(0xFF161B26),
    actionBorder: Color(0xFF222C3D),
    actionText: Color(0xFFE2E8F0),
    actionIcon: Color(0xFF60A5FA),
    ctaBg: Color(0xFF254B77),
    ctaBorder: Color(0x663B82F6),
    ringTrack: Color(0xFF1E293B),
    streakBg: Color(0xFF06281E),
    streakGradient: [Color(0xFF06281E), Color(0xFF073829), Color(0xFF041E16)],
    streakBorder: Color(0xFF0E4936),
    streakLabel: Color(0xFF34D399),
    streakUnit: Color(0xFFA7F3D0),
    streakMessage: Color(0xFF6EE7B7),
    flame: Color(0xFF34D399),
    chartGrid: Color(0xFF1F283B),
    chartAxis: Color(0xFF2A374F),
    chartY: Color(0xFF64748B),
    chartX: Color(0xFF94A3B8),
    chartPeak: Color(0xFF60A5FA),
    chartLine: Color(0xFF4F87F6),
    chartArea: Color(0xFF4F87F6),
    tooltipBg: Color(0xFF161B26),
    tooltipBorder: Color(0xFF27324D),
    tabBg: Color(0xFF0E121A),
    tabBorder: Color(0xFF1F2737),
    tabActiveBg: Color(0xFF1E283C),
    tabActiveText: Color(0xFFF8FAFC),
    tabInactiveText: Color(0xFF94A3B8),
    footerStrong: Color(0xFF94A3B8),
    footerText: Color(0xFF64748B),
    cardShadow: [
      BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2)),
    ],
  );
}

BoxDecoration _cardDecoration(_DashColors colors) {
  return BoxDecoration(
    color: colors.card,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: colors.border),
    boxShadow: colors.cardShadow,
  );
}

// ---------------------------------------------------------------------------
// Boas-vindas e ações rápidas
// ---------------------------------------------------------------------------

class _GreetingSection extends StatelessWidget {
  const _GreetingSection({
    required this.colors,
    required this.username,
    required this.evolucao,
    required this.onRaioX,
    required this.onResolverQuestoes,
  });

  final _DashColors colors;
  final String username;
  final int evolucao;
  final VoidCallback onRaioX;
  final VoidCallback onResolverQuestoes;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final cresceu = evolucao >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Olá, $username!',
          style: TextStyle(
            fontSize: responsive.sp(24),
            fontWeight: colors.isDark ? FontWeight.w800 : FontWeight.w700,
            letterSpacing: -0.6,
            color: colors.text,
          ),
        ),
        SizedBox(height: responsive.isCompact ? 4 : 6),
        Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: responsive.sp(12),
              height: 1.5,
              color: colors.secondary,
            ),
            children: [
              const TextSpan(text: 'Seu volume de estudos está '),
              TextSpan(
                text: '${evolucao.abs()}% ${cresceu ? 'maior' : 'menor'}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colors.accent,
                  decoration: colors.isDark
                      ? TextDecoration.underline
                      : TextDecoration.none,
                  decorationColor: colors.accent.withValues(alpha: 0.4),
                  decorationThickness: 1,
                ),
              ),
              const TextSpan(text: ' que na semana passada.'),
            ],
          ),
        ),
        SizedBox(height: responsive.isCompact ? 12 : 16),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                colors: colors,
                icon: Icons.bar_chart_rounded,
                label: 'Raio-X Completo',
                onTap: onRaioX,
              ),
            ),
            SizedBox(width: responsive.isCompact ? 10 : 14),
            Expanded(
              child: _ActionButton(
                colors: colors,
                icon: Icons.add_rounded,
                label: 'Resolver Questões',
                primary: true,
                onTap: onResolverQuestoes,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.colors,
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final _DashColors colors;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final radius = BorderRadius.circular(responsive.isCompact ? 12 : 14);
    final fundo = primary ? colors.ctaBg : colors.actionBg;
    final borda = primary ? colors.ctaBorder : colors.actionBorder;
    final texto = primary ? Colors.white : colors.actionText;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: primary
                ? const Color(0x1A1E3A8A)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: primary ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: fundo,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: responsive.sp(38),
            padding: EdgeInsets.symmetric(horizontal: responsive.sp(12)),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: borda),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: responsive.sp(16),
                  color: primary ? Colors.white : colors.actionIcon,
                ),
                SizedBox(width: responsive.sp(7)),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: responsive.sp(12),
                      fontWeight: primary ? FontWeight.w600 : FontWeight.w500,
                      color: texto,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Métricas
// ---------------------------------------------------------------------------

class _MetricsSection extends StatelessWidget {
  const _MetricsSection({required this.colors, required this.resumo});

  final _DashColors colors;
  final DashboardResumo resumo;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);

    if (responsive.useThreeMetricCards) {
      final gap = responsive.isCompact ? 12.0 : 16.0;
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _ResolvedCard(colors: colors, resumo: resumo),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _AccuracyCard(colors: colors, resumo: resumo),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _StreakCard(colors: colors, resumo: resumo, compact: true),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _ResolvedCard(colors: colors, resumo: resumo),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AccuracyCard(colors: colors, resumo: resumo),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _StreakCard(colors: colors, resumo: resumo),
      ],
    );
  }
}

class _ResolvedCard extends StatelessWidget {
  const _ResolvedCard({required this.colors, required this.resumo});

  final _DashColors colors;
  final DashboardResumo resumo;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);

    return Container(
      padding: EdgeInsets.all(responsive.sp(14)),
      decoration: _cardDecoration(colors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: responsive.sp(36),
                height: responsive.sp(36),
                decoration: BoxDecoration(
                  color: colors.iconBg,
                  borderRadius: BorderRadius.circular(responsive.sp(12)),
                ),
                child: Icon(
                  Icons.check_circle_outline_rounded,
                  size: responsive.sp(20),
                  color: colors.iconColor,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: responsive.sp(8),
                    vertical: responsive.isCompact ? 2 : 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.badgeBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: colors.badgeBorder),
                  ),
                  child: Text(
                    '+${resumo.hojeResolvidas} hoje',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: responsive.sp(11),
                      fontWeight: FontWeight.w500,
                      color: colors.badgeText,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.sp(14)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'QUESTÕES RESOLVIDAS',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: responsive.sp(10),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                  height: 1.25,
                  color: colors.muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${resumo.totalResolvidas}',
                style: TextStyle(
                  fontSize: responsive.sp(30),
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  height: 1.05,
                  color: colors.text,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccuracyCard extends StatelessWidget {
  const _AccuracyCard({required this.colors, required this.resumo});

  final _DashColors colors;
  final DashboardResumo resumo;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final percentual = resumo.taxaAcerto.clamp(0, 100).toInt();
    final anel = (colors.isDark ? 48.0 : 44.0) * responsive.scale;

    return Container(
      padding: EdgeInsets.all(responsive.sp(14)),
      decoration: _cardDecoration(colors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              SizedBox(
                width: anel,
                height: anel,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: CircularProgressIndicator(
                        value: percentual / 100,
                        strokeWidth: responsive.sp(4),
                        strokeCap: StrokeCap.round,
                        color: colors.primary,
                        backgroundColor: colors.ringTrack,
                      ),
                    ),
                    Text(
                      '$percentual%',
                      style: TextStyle(
                        fontSize: (colors.isDark ? 11 : 10) * responsive.scale,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: colors.isDark
                            ? Colors.white
                            : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: responsive.sp(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TAXA DE ACERTO',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: responsive.sp(10),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                        color: colors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      resumo.nivelPerformance,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: responsive.sp(12),
                        fontWeight: colors.isDark
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: colors.isDark
                            ? Colors.white
                            : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.sp(8)),
          Text(
            'Média calculada sobre o total de resoluções.',
            style: TextStyle(
              fontSize: responsive.sp(10),
              height: 1.3,
              color: colors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({
    required this.colors,
    required this.resumo,
    this.compact = false,
  });

  final _DashColors colors;
  final DashboardResumo resumo;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final mensagem = resumo.ofensiva > 0
        ? 'Mantenha o ritmo!'
        : 'Complete 1 questão hoje para iniciar!';
    final flameSize = compact
        ? responsive.sp(74)
        : (colors.isDark ? 100.0 : 112.0) * responsive.scale;
    final rightPadding = compact
        ? responsive.sp(20)
        : (colors.isDark ? 44.0 : 64.0) * responsive.scale;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.streakBg,
        gradient: colors.streakGradient == null
            ? null
            : LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: colors.streakGradient!,
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.streakBorder),
        boxShadow: colors.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned(
              right: compact
                  ? -14
                  : (colors.isDark ? -8 : -12) * responsive.scale,
              bottom: compact
                  ? -12
                  : (colors.isDark ? -10 : -16) * responsive.scale,
              child: Icon(
                Icons.local_fire_department_rounded,
                size: flameSize,
                color: colors.flame.withValues(
                  alpha: colors.isDark ? 0.15 : 0.13,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(responsive.sp(16)),
              child: Padding(
                padding: EdgeInsets.only(right: rightPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'OFENSIVA ATIVA',
                      style: TextStyle(
                        fontSize: responsive.sp(10),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: colors.streakLabel,
                      ),
                    ),
                    SizedBox(height: responsive.sp(4)),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: responsive.sp(6),
                      runSpacing: 2,
                      children: [
                        Text(
                          '${resumo.ofensiva}',
                          style: TextStyle(
                            fontSize: responsive.sp(30),
                            fontWeight: FontWeight.w800,
                            height: 1,
                            letterSpacing: -0.8,
                            color: colors.text,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            'Dias de estudo constante',
                            style: TextStyle(
                              fontSize: responsive.sp(12),
                              fontWeight: FontWeight.w500,
                              color: colors.streakUnit,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: responsive.sp(6)),
                    if (colors.isDark)
                      Container(
                        margin: EdgeInsets.only(top: responsive.sp(4)),
                        padding: EdgeInsets.only(top: responsive.sp(8)),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0x6610B981)),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.circle,
                              size: 6,
                              color: Color(0xFF34D399),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                mensagem,
                                style: TextStyle(
                                  fontSize: responsive.sp(11),
                                  fontWeight: FontWeight.w500,
                                  color: colors.streakMessage,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Text(
                        mensagem,
                        style: TextStyle(
                          fontSize: responsive.sp(11),
                          height: 1.3,
                          color: colors.streakMessage,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Frequência de estudos
// ---------------------------------------------------------------------------

class _FrequencyCard extends StatelessWidget {
  const _FrequencyCard({
    required this.colors,
    required this.resumo,
    required this.diasAtivos,
    required this.onDiasChanged,
  });

  final _DashColors colors;
  final DashboardResumo resumo;
  final int diasAtivos;
  final ValueChanged<int> onDiasChanged;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final inicio = math.max(0, resumo.ultimos30Dias.length - diasAtivos);
    final exibidos = resumo.ultimos30Dias.sublist(inicio);
    final labels = [for (final dia in exibidos) dia.label];
    final totais = [for (final dia in exibidos) dia.acertos + dia.erros];
    final pico = totais.isEmpty ? 0 : totais.reduce(math.max);
    final topo = math.max(4, (pico / 4).ceil() * 4).toDouble();
    final destaque = pico > 0 ? totais.indexOf(pico) : -1;
    final spots = [
      for (var i = 0; i < totais.length; i++)
        FlSpot(i.toDouble(), totais[i].toDouble()),
    ];
    final areaCores = colors.isDark
        ? [
            colors.chartArea.withValues(alpha: 0.35),
            colors.chartArea.withValues(alpha: 0.08),
            colors.chartArea.withValues(alpha: 0),
          ]
        : [
            colors.chartArea.withValues(alpha: 0.22),
            colors.chartArea.withValues(alpha: 0),
          ];

    return Container(
      padding: EdgeInsets.all(responsive.sp(16)),
      decoration: _cardDecoration(colors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Frequência de Estudos',
            style: TextStyle(
              fontSize: responsive.sp(14),
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Acompanhamento diário de resolução',
            style: TextStyle(fontSize: responsive.sp(11), color: colors.muted),
          ),
          SizedBox(height: responsive.sp(10)),
          Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: _RangeTabs(
                colors: colors,
                selecionado: diasAtivos,
                onChanged: onDiasChanged,
              ),
            ),
          ),
          SizedBox(height: responsive.sp(12)),
          Divider(height: 1, color: colors.borderSoft),
          SizedBox(height: responsive.sp(8)),
          AspectRatio(
            aspectRatio: responsive.isCompact
                ? 350 / 170
                : responsive.isMedium
                ? 700 / 250
                : 960 / 300,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: math.max(1, spots.length - 1).toDouble(),
                minY: 0,
                maxY: topo,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: topo / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: colors.chartGrid,
                    strokeWidth: 1,
                    dashArray: colors.isDark ? const [3, 4] : null,
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(
                      color: colors.chartAxis,
                      width: colors.isDark ? 1 : 1.2,
                    ),
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: responsive.sp(24),
                      interval: topo / 4,
                      getTitlesWidget: (value, meta) {
                        if (value < -0.01 || value > topo + 0.01) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(right: 5),
                          child: Text(
                            value.round().toString(),
                            style: TextStyle(
                              fontSize: responsive.sp(8),
                              color: colors.chartY,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: responsive.sp(22),
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final indice = value.round();
                        if (value != indice.toDouble() ||
                            indice < 0 ||
                            indice >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        final passo = labels.length <= 7
                            ? 1
                            : labels.length <= 15
                            ? 2
                            : 5;
                        final mostrar =
                            indice == 0 ||
                            indice == labels.length - 1 ||
                            indice % passo == 0;
                        if (!mostrar) return const SizedBox.shrink();

                        final ehDestaque = indice == destaque;
                        return SideTitleWidget(
                          meta: meta,
                          space: responsive.sp(6),
                          child: Text(
                            labels[indice],
                            style: TextStyle(
                              fontSize: responsive.sp(8.5),
                              fontWeight: ehDestaque
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: ehDestaque
                                  ? colors.chartPeak
                                  : colors.chartX,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => colors.tooltipBg,
                    tooltipBorder: BorderSide(color: colors.tooltipBorder),
                    tooltipBorderRadius: BorderRadius.circular(8),
                    tooltipPadding: EdgeInsets.symmetric(
                      horizontal: responsive.sp(10),
                      vertical: responsive.sp(6),
                    ),
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (spots) => [
                      for (final spot in spots)
                        LineTooltipItem(
                          '${labels[spot.x.round()]}\n'
                          '${spot.y.round()} questões',
                          TextStyle(
                            fontSize: responsive.sp(10),
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                          ),
                        ),
                    ],
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    preventCurveOverShooting: true,
                    barWidth: responsive.sp(2.5),
                    isStrokeCapRound: true,
                    color: colors.chartLine,
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: areaCores,
                        stops: colors.isDark ? const [0, 0.7, 1] : const [0, 1],
                      ),
                    ),
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        if (index == destaque) {
                          return _PeakDotPainter(colors.chartLine);
                        }
                        return FlDotCirclePainter(
                          radius: responsive.sp(2.5),
                          color: colors.chartLine,
                          strokeColor: colors.chartLine,
                          strokeWidth: 0,
                        );
                      },
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeTabs extends StatelessWidget {
  const _RangeTabs({
    required this.colors,
    required this.selecionado,
    required this.onChanged,
  });

  final _DashColors colors;
  final int selecionado;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);

    return Container(
      padding: EdgeInsets.all(responsive.isCompact ? 2 : 3),
      decoration: BoxDecoration(
        color: colors.tabBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.tabBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final dias in const [7, 15, 30])
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(dias),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.sp(10),
                  vertical: responsive.sp(4),
                ),
                decoration: BoxDecoration(
                  color: selecionado == dias
                      ? colors.tabActiveBg
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: selecionado == dias
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: colors.isDark ? 0.25 : 0.06,
                            ),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  '$dias dias',
                  style: TextStyle(
                    fontSize: responsive.sp(11),
                    fontWeight: selecionado == dias
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: selecionado == dias
                        ? colors.tabActiveText
                        : colors.tabInactiveText,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ponto em destaque do gráfico: círculo branco com contorno e miolo colorido.
class _PeakDotPainter extends FlDotPainter {
  const _PeakDotPainter(this.color);

  final Color color;

  @override
  void draw(Canvas canvas, FlSpot spot, Offset offsetInCanvas) {
    canvas.drawCircle(
      offsetInCanvas,
      5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      offsetInCanvas,
      5,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawCircle(
      offsetInCanvas,
      2,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  Size getSize(FlSpot spot) => const Size.square(10);

  @override
  Color get mainColor => color;

  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) => b;

  @override
  List<Object?> get props => [color];
}

// ---------------------------------------------------------------------------
// Rodapé e dados de demonstração
// ---------------------------------------------------------------------------

class _Footer extends StatelessWidget {
  const _Footer({required this.colors});

  final _DashColors colors;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            fontSize: responsive.sp(11),
            color: colors.footerText,
          ),
          children: [
            TextSpan(
              text: 'Gabaritei Questões',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colors.footerStrong,
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
