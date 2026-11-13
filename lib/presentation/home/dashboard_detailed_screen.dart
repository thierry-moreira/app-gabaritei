import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../../core/time/brasilia_time.dart';
import '../../core/ui/responsive.dart';
import '../../models/stats.dart';
import '../../services/filter_service.dart';
import 'dashboard_shell.dart';

/// Dashboard detalhado (raio-x) - Gabaritei Questões.
///
/// Alimentado por `DashboardRepository.estatisticasDetalhadas`, que agrega
/// `historico_respostas` + `view_questoes_completa` por matéria e tópico.
class DashboardDetailedScreen extends ConsumerStatefulWidget {
  const DashboardDetailedScreen({super.key});

  @override
  ConsumerState<DashboardDetailedScreen> createState() =>
      _DashboardDetailedScreenState();
}

class _DashboardDetailedScreenState
    extends ConsumerState<DashboardDetailedScreen> {
  static const _cores = <Color>[
    Color(0xFF0284C7),
    Color(0xFF10B981),
    Color(0xFFEF4444),
    Color(0xFFF97316),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF06B6D4),
    Color(0xFF6366F1),
    Color(0xFF22C55E),
    Color(0xFFF43F5E),
  ];

  /// Matéria expandida no accordion (apenas uma por vez, como no desktop).
  int? _materiaExpandida;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF080B11) : const Color(0xFFF7F8F9);
    final cardColor = isDark ? const Color(0xFF101726) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE9ECEF);
    final textColor = isDark
        ? const Color(0xFFE2E8F0)
        : const Color(0xFF1A293D);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF6C757D);
    final primaryBlue = isDark
        ? const Color(0xFF3B82F6)
        : const Color(0xFF2F4F75);

    final perfil = ref.watch(perfilAtualProvider);
    final detalhado = ref.watch(estatisticasDetalhadasProvider);
    final streak = ref.watch(painelProvider).value?.ofensiva ?? 0;

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          DashboardTopBar(
            isDark: isDark,
            streak: streak,
            username: perfil.value?.username ?? 'Estudante',
            onToggleTheme: () =>
                ref.read(themeModeProvider.notifier).alternar(isDark),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: responsive.pagePadding.copyWith(bottom: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: responsive.detailedMaxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPageHeader(
                        isDark,
                        primaryBlue,
                        cardColor,
                        borderColor,
                        textColor,
                        textSecondary,
                      ),
                      SizedBox(height: responsive.gap),
                      ..._buildConteudo(
                        isDark: isDark,
                        detalhado: detalhado,
                        cardColor: cardColor,
                        borderColor: borderColor,
                        textColor: textColor,
                        textSecondary: textSecondary,
                        responsive: responsive,
                      ),
                      SizedBox(height: responsive.gap),
                      _buildFooter(isDark, textSecondary),
                    ],
                  ),
                ),
              ),
            ),
          ),
          DashboardBottomNav(
            isDark: isDark,
            selectedIndex: 0,
            onSelected: _onBottomNavSelected,
          ),
        ],
      ),
    );
  }

  void _onBottomNavSelected(int index) {
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
        context.go('/resumos');
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
    }
  }

  List<Widget> _buildConteudo({
    required bool isDark,
    required AsyncValue<DashboardDetalhado> detalhado,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color textSecondary,
    required Responsive responsive,
  }) {
    if (detalhado.isLoading && !detalhado.hasValue) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator(color: textColor)),
        ),
      ];
    }

    if (detalhado.hasError && !detalhado.hasValue) {
      return [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(responsive.sp(20)),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(responsive.cardRadius + 4),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: responsive.sp(36),
                color: textSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                'Não foi possível carregar suas estatísticas.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: responsive.sp(13),
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${detalhado.error}',
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: responsive.sp(11),
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(perfilAtualProvider);
                  ref.invalidate(estatisticasDetalhadasProvider);
                },
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ];
    }

    final dados = detalhado.requireValue;

    if (dados.totalResolvidas == 0) {
      return [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(responsive.sp(24)),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(responsive.cardRadius + 4),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              Icon(
                Icons.insights_rounded,
                size: responsive.sp(40),
                color: textSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                'Ainda não há questões resolvidas.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: responsive.sp(14),
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Resolva algumas questões para desbloquear o raio-x por '
                'matéria e tópico.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: responsive.sp(12),
                  color: textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ];
    }

    return [
      _buildResumoCard(
        dados,
        isDark,
        cardColor,
        borderColor,
        textColor,
        textSecondary,
      ),
      SizedBox(height: responsive.gap - 4),
      if (responsive.useTwoColumnDetailedLayout)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: _buildDonutChartCard(
                dados,
                isDark,
                cardColor,
                borderColor,
                textColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 7,
              child: _buildBarChartCard(
                dados,
                isDark,
                cardColor,
                borderColor,
                textColor,
              ),
            ),
          ],
        )
      else ...[
        _buildDonutChartCard(dados, isDark, cardColor, borderColor, textColor),
        const SizedBox(height: 12),
        _buildBarChartCard(dados, isDark, cardColor, borderColor, textColor),
      ],
      SizedBox(height: responsive.gap),
      if (responsive.useTwoColumnDetailedLayout)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: _buildStrategicAnalysis(
                dados,
                isDark,
                cardColor,
                borderColor,
                textColor,
                textSecondary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 7,
              child: _buildSubjectPerformance(
                dados,
                isDark,
                cardColor,
                borderColor,
                textColor,
                textSecondary,
              ),
            ),
          ],
        )
      else ...[
        _buildStrategicAnalysis(
          dados,
          isDark,
          cardColor,
          borderColor,
          textColor,
          textSecondary,
        ),
        const SizedBox(height: 16),
        _buildSubjectPerformance(
          dados,
          isDark,
          cardColor,
          borderColor,
          textColor,
          textSecondary,
        ),
      ],
    ];
  }

  Widget _buildPageHeader(
    bool isDark,
    Color primaryBlue,
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color textSecondary,
  ) {
    final responsive = Responsive.of(context);
    final canGoBack = Navigator.of(context).canPop();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (canGoBack) ...[
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: responsive.sp(12),
                vertical: responsive.sp(8),
              ),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_back_rounded,
                    size: responsive.sp(16),
                    color: textSecondary,
                  ),
                  SizedBox(width: responsive.sp(6)),
                  Text(
                    'Voltar ao Inicio',
                    style: TextStyle(
                      fontSize: responsive.sp(12),
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: responsive.sp(16)),
        ],
        Row(
          children: [
            Container(
              width: responsive.sp(36),
              height: responsive.sp(36),
              decoration: BoxDecoration(
                color: primaryBlue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(responsive.sp(12)),
                border: Border.all(color: primaryBlue.withValues(alpha: 0.3)),
              ),
              child: Icon(
                Icons.view_list_rounded,
                size: responsive.sp(20),
                color: Colors.blue,
              ),
            ),
            SizedBox(width: responsive.sp(10)),
            Expanded(
              child: Text(
                'Dashboard Detalhado',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: responsive.sp(20),
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: EdgeInsets.only(left: responsive.sp(40)),
          child: Text(
            'Analise profunda do seu desempenho por materia e assunto',
            style: TextStyle(
              fontSize: responsive.sp(12),
              color: textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResumoCard(
    DashboardDetalhado dados,
    bool isDark,
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color textSecondary,
  ) {
    final responsive = Responsive.of(context);
    final itens = <({String label, String valor})>[
      (label: 'Resolvidas', valor: '${dados.totalResolvidas}'),
      (label: 'Acertos', valor: '${dados.totalAcertos}'),
      (label: 'Taxa global', valor: '${dados.taxaGlobal}%'),
      (label: 'Meta diaria', valor: '${dados.metaDiaria}'),
    ];

    final widgets = <Widget>[
      for (final item in itens)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.valor,
              style: TextStyle(
                fontSize: responsive.sp(20),
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            Text(
              item.label,
              style: TextStyle(
                fontSize: responsive.sp(10),
                color: textSecondary,
              ),
            ),
          ],
        ),
    ];

    final Widget content;
    if (responsive.isCompact) {
      content = Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final widget in widgets) SizedBox(width: 110, child: widget),
        ],
      );
    } else {
      final children = <Widget>[];
      for (var i = 0; i < widgets.length; i++) {
        if (i > 0) children.add(const SizedBox(width: 16));
        children.add(Expanded(child: widgets[i]));
      }
      content = Row(children: children);
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(responsive.sp(16)),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(responsive.cardRadius + 4),
        border: Border.all(color: borderColor),
      ),
      child: content,
    );
  }

  Widget _buildDonutChartCard(
    DashboardDetalhado dados,
    bool isDark,
    Color cardColor,
    Color borderColor,
    Color textColor,
  ) {
    final responsive = Responsive.of(context);
    final materias = dados.materias.take(7).toList(growable: false);
    final total = dados.totalResolvidas;
    final donutOuter = responsive.isCompact ? 140.0 : 190.0;
    final donutInner = donutOuter - 20;

    final segments = <_Segment>[
      for (var i = 0; i < materias.length; i++)
        _Segment(
          _cores[i % _cores.length],
          total == 0 ? 0 : materias[i].total / total,
        ),
    ];

    return Container(
      padding: EdgeInsets.all(responsive.sp(16)),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(responsive.cardRadius + 4),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Questoes Resolvidas',
            style: TextStyle(
              fontSize: responsive.sp(13),
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Distribuicao por disciplina',
            style: TextStyle(
              fontSize: responsive.sp(11),
              color: const Color(0xFF94A3B8),
            ),
          ),
          SizedBox(height: responsive.sp(16)),
          Center(
            child: SizedBox(
              width: donutOuter,
              height: donutOuter,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: donutInner,
                    height: donutInner,
                    child: CustomPaint(
                      painter: _DonutChartPainter(segments),
                      size: Size(donutInner, donutInner),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$total',
                        style: TextStyle(
                          fontSize: responsive.sp(24),
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: responsive.sp(9),
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: responsive.sp(16)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < materias.length; i++)
                _buildLegendItem(_cores[i % _cores.length], materias[i].nome),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    final responsive = Responsive.of(context);
    final textSecondary = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF6C757D);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.sp(8),
        vertical: responsive.sp(4),
      ),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: responsive.sp(8),
            height: responsive.sp(8),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: responsive.sp(6)),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: responsive.sp(160)),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: responsive.sp(10),
                color: textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChartCard(
    DashboardDetalhado dados,
    bool isDark,
    Color cardColor,
    Color borderColor,
    Color textColor,
  ) {
    final responsive = Responsive.of(context);
    final materias = dados.materias.take(10).toList(growable: false);
    final barWidth = responsive.isCompact ? 58.0 : 74.0;
    final chartHeight = responsive.isCompact ? 180.0 : 240.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(responsive.sp(16)),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(responsive.cardRadius + 4),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Taxa de Acertos (%)',
            style: TextStyle(
              fontSize: responsive.sp(13),
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Desempenho por disciplina',
            style: TextStyle(
              fontSize: responsive.sp(11),
              color: const Color(0xFF94A3B8),
            ),
          ),
          SizedBox(height: responsive.sp(16)),
          LayoutBuilder(
            builder: (context, constraints) {
              // O gráfico ocupa a largura do card; se houver muitas matérias,
              // ganha rolagem horizontal em vez de espremer as barras.
              final larguraConteudo = math.max(
                constraints.maxWidth,
                materias.length * barWidth,
              );

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: larguraConteudo,
                  child: SizedBox(
                    height: chartHeight,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Column(
                            children: List.generate(
                              5,
                              (i) => Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: const Color(0xFF1E293B),
                                        width: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            for (var i = 0; i < materias.length; i++)
                              SizedBox(
                                width: barWidth,
                                child: _buildBarColumn(
                                  label: materias[i].nome,
                                  percentage: materias[i].taxa,
                                  color: _cores[i % _cores.length],
                                  chartHeight: chartHeight,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          if (materias.length > 4)
            Center(
              child: Text(
                'Deslize para ver todas as materias',
                style: TextStyle(
                  fontSize: responsive.sp(10),
                  color: Colors.grey.shade500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBarColumn({
    required String label,
    required int percentage,
    required Color color,
    required double chartHeight,
  }) {
    final responsive = Responsive.of(context);
    final fraction = (percentage.clamp(0, 100)) / 100;
    return Semantics(
      label: '$label: $percentage%',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '$percentage%',
            style: TextStyle(
              fontSize: responsive.sp(9),
              color: Colors.grey,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            height: (chartHeight - 60) * fraction,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: responsive.sp(8),
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrategicAnalysis(
    DashboardDetalhado dados,
    bool isDark,
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color textSecondary,
  ) {
    final responsive = Responsive.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          icon: Icons.lightbulb_outline_rounded,
          iconColor: Colors.amber.shade600,
          titulo: 'Analise Estrategica',
          textColor: textColor,
        ),
        SizedBox(height: responsive.sp(12)),
        _buildCicloRevisaoCard(
          dados,
          isDark,
          cardColor,
          borderColor,
          textColor,
          textSecondary,
        ),
        SizedBox(height: responsive.sp(12)),
        _GoalsCalendarCard(
          key: const ValueKey('calendario-metas'),
          isDark: isDark,
          cardColor: cardColor,
          borderColor: borderColor,
          textColor: textColor,
          textSecondary: textSecondary,
          metaDiaria: dados.metaDiaria,
          concluidosPorDia: dados.concluidosPorDia,
        ),
        SizedBox(height: responsive.sp(12)),
        _buildBestPerformanceCard(
          dados,
          cardColor,
          borderColor,
          textColor,
          textSecondary,
        ),
        SizedBox(height: responsive.sp(12)),
        _buildFocusReviewCard(
          dados,
          cardColor,
          borderColor,
          textColor,
          textSecondary,
        ),
      ],
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required Color iconColor,
    required String titulo,
    required Color textColor,
  }) {
    final responsive = Responsive.of(context);
    return Row(
      children: [
        Icon(icon, size: responsive.sp(17), color: iconColor),
        SizedBox(width: responsive.sp(8)),
        Expanded(
          child: Text(
            titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: responsive.sp(15),
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCicloRevisaoCard(
    DashboardDetalhado dados,
    bool isDark,
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color textSecondary,
  ) {
    final responsive = Responsive.of(context);
    final alertas = dados.alertasRevisao;
    final innerColor = isDark
        ? const Color(0xFF151C2C)
        : const Color(0xFFF8FAFC);
    final innerBorder = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(responsive.sp(16)),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(responsive.cardRadius + 4),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: responsive.sp(16),
                color: const Color(0xFF0891B2),
              ),
              SizedBox(width: responsive.sp(8)),
              Expanded(
                child: Text(
                  'Ciclo de Revisao Ativa',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: responsive.sp(13),
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.sp(7),
                  vertical: responsive.sp(2),
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0891B2).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'CURVA DO ESQUECIMENTO',
                  style: TextStyle(
                    fontSize: responsive.sp(7.5),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: const Color(0xFF0891B2),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.sp(8)),
          Text(
            alertas.isEmpty
                ? 'Nenhuma materia esta "esfriando". Bom trabalho!'
                : 'Materias que estao "esfriando" na sua memoria:',
            style: TextStyle(
              fontSize: responsive.sp(11),
              color: textSecondary,
              height: 1.4,
            ),
          ),
          if (alertas.isNotEmpty) ...[
            SizedBox(height: responsive.sp(12)),
            Container(
              padding: EdgeInsets.all(responsive.sp(14)),
              decoration: BoxDecoration(
                color: innerColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: innerBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final alerta in alertas)
                    _buildAlertItem(
                      alerta.nome,
                      alerta.status,
                      (alerta.dias / 30).clamp(0.05, 1.0),
                      _corAlerta(alerta.cor),
                      alerta.dias,
                      textColor,
                      textSecondary,
                    ),
                ],
              ),
            ),
            SizedBox(height: responsive.sp(12)),
            _buildDicaAtiva(responsive, textSecondary),
          ],
        ],
      ),
    );
  }

  Widget _buildDicaAtiva(Responsive responsive, Color textSecondary) {
    final cor = const Color(0xFF0891B2);
    return Container(
      padding: EdgeInsets.all(responsive.sp(12)),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withValues(alpha: 0.25)),
      ),
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            fontSize: responsive.sp(10),
            color: textSecondary,
            height: 1.4,
          ),
          children: [
            TextSpan(
              text: 'Dica Ativa: ',
              style: TextStyle(fontWeight: FontWeight.w700, color: cor),
            ),
            const TextSpan(
              text:
                  'Tente revisar as materias em vermelho imediatamente para '
                  'evitar a perda total do conteudo.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBestPerformanceCard(
    DashboardDetalhado dados,
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color textSecondary,
  ) {
    final responsive = Responsive.of(context);
    final melhor = dados.melhorMateria;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(responsive.sp(16)),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(responsive.cardRadius + 4),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MELHOR DESEMPENHO',
            style: TextStyle(
              fontSize: responsive.sp(10),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: textSecondary,
            ),
          ),
          SizedBox(height: responsive.sp(12)),
          if (melhor == null)
            Text(
              'Continue praticando para destacar sua melhor disciplina.',
              style: TextStyle(
                fontSize: responsive.sp(11),
                color: textSecondary,
                height: 1.4,
              ),
            )
          else
            Row(
              children: [
                Container(
                  width: responsive.sp(46),
                  height: responsive.sp(46),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.emoji_events_rounded,
                    size: responsive.sp(24),
                    color: const Color(0xFF10B981),
                  ),
                ),
                SizedBox(width: responsive.sp(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        melhor.nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: responsive.sp(13),
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      SizedBox(height: responsive.sp(2)),
                      Text.rich(
                        TextSpan(
                          style: TextStyle(fontSize: responsive.sp(11)),
                          children: [
                            TextSpan(
                              text: '${melhor.taxa}%',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                            TextSpan(
                              text: ' de precisao',
                              style: TextStyle(color: textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFocusReviewCard(
    DashboardDetalhado dados,
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color textSecondary,
  ) {
    final responsive = Responsive.of(context);
    final pontos = dados.pontosAtencao;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(responsive.cardRadius + 4),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(responsive.sp(16)),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: responsive.sp(16),
                  color: const Color(0xFFEF4444),
                ),
                SizedBox(width: responsive.sp(8)),
                Expanded(
                  child: Text(
                    'Foco para Revisao',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: responsive.sp(13),
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: responsive.sp(8),
                    vertical: responsive.sp(2),
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'Prioridade',
                    style: TextStyle(
                      fontSize: responsive.sp(8),
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (pontos.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                responsive.sp(16),
                0,
                responsive.sp(16),
                responsive.sp(20),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: responsive.sp(30),
                    color: textSecondary.withValues(alpha: 0.4),
                  ),
                  SizedBox(height: responsive.sp(8)),
                  Text(
                    'Nenhum ponto critico identificado. Bom trabalho!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: responsive.sp(11),
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            for (var i = 0; i < pontos.length; i++) ...[
              if (i == 0) Divider(height: 1, color: borderColor),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.sp(16),
                  vertical: responsive.sp(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pontos[i].topico,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: responsive.sp(12),
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          SizedBox(height: responsive.sp(2)),
                          Text(
                            pontos[i].materia.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: responsive.sp(8.5),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: responsive.sp(10)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${pontos[i].taxa}%',
                          style: TextStyle(
                            fontSize: responsive.sp(12),
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFEF4444),
                          ),
                        ),
                        Text(
                          '${pontos[i].total} q.',
                          style: TextStyle(
                            fontSize: responsive.sp(9),
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (i < pontos.length - 1) Divider(height: 1, color: borderColor),
            ],
        ],
      ),
    );
  }

  Color _corAlerta(String cor) {
    switch (cor) {
      case 'danger':
        return Colors.red;
      case 'orange':
        return Colors.orange;
      default:
        return Colors.amber;
    }
  }

  Widget _buildAlertItem(
    String title,
    String level,
    double progress,
    Color color,
    int days,
    Color textColor,
    Color textSecondary,
  ) {
    final responsive = Responsive.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: responsive.sp(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: responsive.sp(11),
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
              SizedBox(width: responsive.sp(6)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.sp(6),
                  vertical: responsive.sp(1),
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Text(
                  level,
                  style: TextStyle(
                    fontSize: responsive.sp(8),
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.sp(6)),
          Stack(
            children: [
              Container(
                height: responsive.sp(3),
                decoration: BoxDecoration(
                  color: textSecondary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: responsive.sp(3),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.sp(4)),
          Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: responsive.sp(10),
                color: textSecondary,
              ),
              children: [
                const TextSpan(text: 'Sem resolver questoes ha '),
                TextSpan(
                  text: '$days',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textColor.withValues(alpha: 0.8),
                  ),
                ),
                const TextSpan(text: ' dias'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectPerformance(
    DashboardDetalhado dados,
    bool isDark,
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color textSecondary,
  ) {
    final responsive = Responsive.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: responsive.sp(28),
              height: responsive.sp(28),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.bar_chart_rounded,
                size: responsive.sp(14),
                color: const Color(0xFF3B82F6),
              ),
            ),
            SizedBox(width: responsive.sp(8)),
            Expanded(
              child: Text(
                'Desempenho por Materia',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: responsive.sp(15),
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: responsive.sp(4)),
        Text(
          'Toque em uma materia para ver os assuntos',
          style: TextStyle(fontSize: responsive.sp(10.5), color: textSecondary),
        ),
        SizedBox(height: responsive.sp(12)),
        for (final materia in dados.materias)
          _buildSubjectCard(
            materia: materia,
            isDark: isDark,
            expandida: _materiaExpandida == materia.idMateria,
            onToggle: () => setState(() {
              _materiaExpandida = _materiaExpandida == materia.idMateria
                  ? null
                  : materia.idMateria;
            }),
            onPraticar: (topico) =>
                _praticarTopico(materia.idMateria, topico.idTopico),
            cardColor: cardColor,
            borderColor: borderColor,
            textColor: textColor,
            textSecondary: textSecondary,
          ),
      ],
    );
  }

  Color _corDesempenho(int taxa) {
    if (taxa >= 80) return const Color(0xFF10B981);
    if (taxa >= 60) return Colors.amber;
    return const Color(0xFFEF4444);
  }

  /// Abre a tela de questões já filtrada pela matéria e pelo tópico, como o
  /// link "Praticar" do dashboard desktop.
  void _praticarTopico(int idMateria, int idTopico) {
    ref
        .read(questoesFiltrosProvider.notifier)
        .atualizar(
          QuestaoFiltros(idsMaterias: [idMateria], idsTopicos: [idTopico]),
        );
    context.go('/questoes');
  }

  Widget _buildSubjectCard({
    required MateriaEstatistica materia,
    required bool isDark,
    required bool expandida,
    required VoidCallback onToggle,
    required ValueChanged<TopicoEstatistica> onPraticar,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color textSecondary,
  }) {
    final responsive = Responsive.of(context);
    final cor = _corDesempenho(materia.taxa);
    final innerColor = isDark
        ? const Color(0xFF0D1420)
        : const Color(0xFFF8FAFC);

    return Container(
      margin: EdgeInsets.only(bottom: responsive.sp(10)),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: Key('materia-card-${materia.idMateria}'),
            onTap: onToggle,
            child: Padding(
              padding: EdgeInsets.all(responsive.sp(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          materia.nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: responsive.sp(12),
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ),
                      SizedBox(width: responsive.sp(8)),
                      Text(
                        '${materia.taxa}%',
                        style: TextStyle(
                          fontSize: responsive.sp(11),
                          fontWeight: FontWeight.w700,
                          color: cor,
                          fontFamily: 'monospace',
                        ),
                      ),
                      SizedBox(width: responsive.sp(4)),
                      AnimatedRotation(
                        turns: expandida ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: responsive.sp(18),
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: responsive.sp(8)),
                  Stack(
                    children: [
                      Container(
                        height: responsive.sp(4),
                        decoration: BoxDecoration(
                          color: cor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: (materia.taxa.clamp(0, 100)) / 100,
                        child: Container(
                          height: responsive.sp(4),
                          decoration: BoxDecoration(
                            color: cor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: responsive.sp(8)),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${materia.total} questoes resolvidas',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: responsive.sp(9),
                            color: textSecondary,
                          ),
                        ),
                      ),
                      SizedBox(width: responsive.sp(8)),
                      Flexible(
                        child: Text(
                          '${materia.acertos} acertos',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: responsive.sp(9),
                            fontWeight: FontWeight.w600,
                            color: textColor.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: expandida
                ? Container(
                    decoration: BoxDecoration(
                      color: innerColor,
                      border: Border(top: BorderSide(color: borderColor)),
                    ),
                    child: materia.topicos.isEmpty
                        ? Padding(
                            padding: EdgeInsets.all(responsive.sp(14)),
                            child: Text(
                              'Nenhum assunto registrado nesta materia.',
                              style: TextStyle(
                                fontSize: responsive.sp(10.5),
                                color: textSecondary,
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < materia.topicos.length; i++)
                                _buildTopicRow(
                                  materia.idMateria,
                                  materia.topicos[i],
                                  mostrarDivisor: i > 0,
                                  borderColor: borderColor,
                                  textColor: textColor,
                                  textSecondary: textSecondary,
                                  onPraticar: onPraticar,
                                ),
                            ],
                          ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicRow(
    int idMateria,
    TopicoEstatistica topico, {
    required bool mostrarDivisor,
    required Color borderColor,
    required Color textColor,
    required Color textSecondary,
    required ValueChanged<TopicoEstatistica> onPraticar,
  }) {
    final responsive = Responsive.of(context);
    final cor = _corDesempenho(topico.taxa);

    return Container(
      decoration: BoxDecoration(
        border: mostrarDivisor
            ? Border(top: BorderSide(color: borderColor))
            : null,
      ),
      padding: EdgeInsets.fromLTRB(
        responsive.sp(18),
        responsive.sp(10),
        responsive.sp(10),
        responsive.sp(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  topico.nome,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: responsive.sp(11),
                    fontWeight: FontWeight.w700,
                    color: textSecondary,
                  ),
                ),
              ),
              SizedBox(width: responsive.sp(8)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.sp(7),
                  vertical: responsive.sp(1.5),
                ),
                decoration: BoxDecoration(
                  color: cor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${topico.taxa}%',
                  style: TextStyle(
                    fontSize: responsive.sp(8.5),
                    fontWeight: FontWeight.w700,
                    color: topico.taxa >= 60 && topico.taxa < 80
                        ? const Color(0xFF1A293D)
                        : Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.sp(5)),
          Stack(
            children: [
              Container(
                height: responsive.sp(3),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: (topico.taxa.clamp(0, 100)) / 100,
                child: Container(
                  height: responsive.sp(3),
                  decoration: BoxDecoration(
                    color: cor.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.sp(2)),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${topico.total} resolvidas',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: responsive.sp(9),
                    color: textSecondary.withValues(alpha: 0.8),
                  ),
                ),
              ),
              TextButton.icon(
                key: Key('praticar-$idMateria-${topico.idTopico}'),
                onPressed: () => onPraticar(topico),
                icon: Icon(
                  Icons.play_circle_outline_rounded,
                  size: responsive.sp(14),
                ),
                label: Text(
                  'Praticar',
                  style: TextStyle(
                    fontSize: responsive.sp(10),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF3B82F6),
                  minimumSize: Size(0, responsive.sp(28)),
                  padding: EdgeInsets.symmetric(horizontal: responsive.sp(4)),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isDark, Color textSecondary) {
    final responsive = Responsive.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Center(
        child: Text(
          'Gabaritei Questoes 2026 Software livre',
          style: TextStyle(
            fontSize: responsive.sp(11),
            color: textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Calendário de metas diárias do dashboard detalhado.
///
/// Replica o card do desktop: navegação por mês, dias com meta batida em
/// verde, hoje em rosa, legenda e ajuste/salvamento da meta diária.
class _GoalsCalendarCard extends ConsumerStatefulWidget {
  const _GoalsCalendarCard({
    super.key,
    required this.isDark,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.textSecondary,
    required this.metaDiaria,
    required this.concluidosPorDia,
  });

  final bool isDark;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color textSecondary;
  final int metaDiaria;
  final Map<String, int> concluidosPorDia;

  @override
  ConsumerState<_GoalsCalendarCard> createState() => _GoalsCalendarCardState();
}

class _GoalsCalendarCardState extends ConsumerState<_GoalsCalendarCard> {
  static const _meses = <String>[
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];

  static const _diasSemana = <String>[
    'segunda-feira',
    'terça-feira',
    'quarta-feira',
    'quinta-feira',
    'sexta-feira',
    'sábado',
    'domingo',
  ];

  late final DateTime _hoje;
  late DateTime _mes;
  late int _meta;
  bool _aberto = true;
  bool _salvando = false;
  bool _salvo = false;
  Timer? _resetSalvo;

  @override
  void initState() {
    super.initState();
    _hoje = BrasiliaTime.now();
    _mes = DateTime(_hoje.year, _hoje.month);
    _meta = widget.metaDiaria;
  }

  @override
  void didUpdateWidget(covariant _GoalsCalendarCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metaDiaria != widget.metaDiaria && !_salvando) {
      _meta = widget.metaDiaria;
    }
  }

  @override
  void dispose() {
    _resetSalvo?.cancel();
    super.dispose();
  }

  String _capitalizar(String texto) {
    return texto
        .split(' ')
        .map(
          (palavra) => palavra.isEmpty
              ? palavra
              : '${palavra[0].toUpperCase()}${palavra.substring(1)}',
        )
        .join(' ');
  }

  String get _dataCabecalho {
    final diaSemana = _diasSemana[_hoje.weekday - 1];
    return _capitalizar(
      '$diaSemana, ${_hoje.day} de ${_meses[_hoje.month - 1]}',
    );
  }

  String get _rotuloMes => '${_meses[_mes.month - 1]} de ${_mes.year}';

  void _mudarMes(int delta) {
    setState(() => _mes = DateTime(_mes.year, _mes.month + delta));
  }

  void _ajustarMeta(int delta) {
    _resetSalvo?.cancel();
    setState(() {
      _meta = math.max(0, _meta + delta);
      _salvo = false;
    });
  }

  Future<void> _salvarMeta() async {
    final idUsuario = ref.read(perfilAtualProvider).value?.id;
    if (idUsuario == null) return;

    setState(() => _salvando = true);
    try {
      await ref
          .read(userRepositoryProvider)
          .definirMetaDiaria(idUsuario, _meta);
      if (!mounted) return;
      setState(() {
        _salvando = false;
        _salvo = true;
      });
      ref.invalidate(perfilAtualProvider);
      ref.invalidate(estatisticasDetalhadasProvider);
      _resetSalvo?.cancel();
      _resetSalvo = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() => _salvo = false);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Erro ao salvar meta.'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
    }
  }

  List<({int dia, bool outroMes, int resolvidos, bool hoje})> _diasDoMes() {
    final ano = _mes.year;
    final mes = _mes.month;
    final primeiroDiaSemana = DateTime(ano, mes, 1).weekday % 7;
    final ultimoDia = DateTime(ano, mes + 1, 0).day;
    final ultimoDiaMesAnterior = DateTime(ano, mes, 0).day;

    final dias = <({int dia, bool outroMes, int resolvidos, bool hoje})>[];
    for (var i = primeiroDiaSemana; i > 0; i--) {
      dias.add((
        dia: ultimoDiaMesAnterior - i + 1,
        outroMes: true,
        resolvidos: 0,
        hoje: false,
      ));
    }
    for (var dia = 1; dia <= ultimoDia; dia++) {
      final chave =
          '${ano.toString().padLeft(4, '0')}-'
          '${mes.toString().padLeft(2, '0')}-'
          '${dia.toString().padLeft(2, '0')}';
      dias.add((
        dia: dia,
        outroMes: false,
        resolvidos: widget.concluidosPorDia[chave] ?? 0,
        hoje: dia == _hoje.day && mes == _hoje.month && ano == _hoje.year,
      ));
    }
    return dias;
  }

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: widget.cardColor,
        borderRadius: BorderRadius.circular(responsive.cardRadius + 4),
        border: Border.all(color: widget.borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              responsive.sp(16),
              responsive.sp(12),
              responsive.sp(10),
              responsive.sp(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _dataCabecalho,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: responsive.sp(13),
                          fontWeight: FontWeight.w700,
                          color: widget.textColor,
                        ),
                      ),
                      SizedBox(height: responsive.sp(2)),
                      Text(
                        'Acompanhe sua consistencia diaria',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: responsive.sp(10),
                          color: widget.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('calendario-toggle'),
                  onPressed: () => setState(() => _aberto = !_aberto),
                  icon: AnimatedRotation(
                    turns: _aberto ? 0 : 0.5,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: responsive.sp(20),
                    ),
                  ),
                  style: IconButton.styleFrom(
                    foregroundColor: widget.textSecondary,
                    backgroundColor: widget.isDark
                        ? const Color(0xFF21262D)
                        : const Color(0xFFF6F8FA),
                    side: BorderSide(color: widget.borderColor),
                    minimumSize: Size(responsive.sp(34), responsive.sp(34)),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: _aberto
                ? Padding(
                    padding: EdgeInsets.fromLTRB(
                      responsive.sp(16),
                      0,
                      responsive.sp(16),
                      responsive.sp(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _rotuloMes,
                                        key: const Key('calendario-mes'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: responsive.sp(12),
                                          fontWeight: FontWeight.w700,
                                          color: widget.textSecondary,
                                        ),
                                      ),
                                    ),
                                    _monthNavButton(
                                      key: const Key('calendario-anterior'),
                                      icon: Icons.chevron_left_rounded,
                                      onTap: () => _mudarMes(-1),
                                      responsive: responsive,
                                    ),
                                    SizedBox(width: responsive.sp(10)),
                                    _monthNavButton(
                                      key: const Key('calendario-proximo'),
                                      icon: Icons.chevron_right_rounded,
                                      onTap: () => _mudarMes(1),
                                      responsive: responsive,
                                    ),
                                  ],
                                ),
                                SizedBox(height: responsive.sp(10)),
                                Row(
                                  children: [
                                    for (final dia in const [
                                      'D',
                                      'S',
                                      'T',
                                      'Q',
                                      'Q',
                                      'S',
                                      'S',
                                    ])
                                      Expanded(
                                        child: Center(
                                          child: Text(
                                            dia,
                                            style: TextStyle(
                                              fontSize: responsive.sp(9.5),
                                              fontWeight: FontWeight.w800,
                                              color: widget.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                SizedBox(height: responsive.sp(4)),
                                GridView.count(
                                  crossAxisCount: 7,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  mainAxisSpacing: responsive.sp(2),
                                  crossAxisSpacing: responsive.sp(2),
                                  children: [
                                    for (final dia in _diasDoMes())
                                      _buildDia(dia, responsive),
                                  ],
                                ),
                                SizedBox(height: responsive.sp(10)),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: responsive.sp(14),
                                  runSpacing: responsive.sp(6),
                                  children: [
                                    _legenda(
                                      const Color(0xFFD39ED3),
                                      'Hoje',
                                      responsive,
                                    ),
                                    _legenda(
                                      const Color(0xFF238636),
                                      'Meta Batida',
                                      responsive,
                                    ),
                                    _legenda(
                                      widget.textSecondary.withValues(
                                        alpha: 0.5,
                                      ),
                                      'Tentativas',
                                      responsive,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: responsive.sp(12)),
                        Divider(height: 1, color: widget.borderColor),
                        SizedBox(height: responsive.sp(12)),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final controles = Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _metaButton(
                                  key: const Key('calendario-meta-menos'),
                                  icon: Icons.remove_rounded,
                                  onTap: () => _ajustarMeta(-5),
                                  responsive: responsive,
                                ),
                                SizedBox(width: responsive.sp(8)),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$_meta',
                                      key: const Key('calendario-meta'),
                                      style: TextStyle(
                                        fontSize: responsive.sp(18),
                                        fontWeight: FontWeight.w800,
                                        color: widget.textColor,
                                      ),
                                    ),
                                    Text(
                                      'QUESTOES',
                                      style: TextStyle(
                                        fontSize: responsive.sp(7.5),
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.8,
                                        color: widget.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(width: responsive.sp(8)),
                                _metaButton(
                                  key: const Key('calendario-meta-mais'),
                                  icon: Icons.add_rounded,
                                  onTap: () => _ajustarMeta(5),
                                  responsive: responsive,
                                ),
                              ],
                            );
                            final botao = _buildSalvarButton(responsive);

                            if (constraints.maxWidth < 300) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  controles,
                                  SizedBox(height: responsive.sp(10)),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: botao,
                                  ),
                                ],
                              );
                            }

                            return Row(
                              children: [controles, const Spacer(), botao],
                            );
                          },
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildDia(
    ({int dia, bool outroMes, int resolvidos, bool hoje}) info,
    Responsive responsive,
  ) {
    final metaBatida = !info.outroMes && _meta > 0 && info.resolvidos >= _meta;
    final tentativa = !info.outroMes && info.resolvidos > 0 && !metaBatida;

    Color? fundo;
    var texto = widget.textColor;
    if (info.hoje) {
      fundo = const Color(0xFFD39ED3);
      texto = const Color(0xFF161B22);
    } else if (metaBatida) {
      fundo = const Color(0xFF238636);
      texto = Colors.white;
    } else if (info.outroMes) {
      texto = widget.textSecondary.withValues(alpha: 0.45);
    }

    return Container(
      decoration: BoxDecoration(
        color: fundo,
        shape: BoxShape.circle,
        boxShadow: metaBatida
            ? [
                BoxShadow(
                  color: const Color(0xFF238636).withValues(alpha: 0.3),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${info.dia}',
            style: TextStyle(
              fontSize: responsive.sp(10.5),
              fontWeight: FontWeight.w600,
              color: texto,
            ),
          ),
          if (tentativa)
            Container(
              width: responsive.sp(3),
              height: responsive.sp(3),
              margin: EdgeInsets.only(top: responsive.sp(1)),
              decoration: BoxDecoration(
                color: widget.textSecondary.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  Widget _monthNavButton({
    required Key key,
    required IconData icon,
    required VoidCallback onTap,
    required Responsive responsive,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.all(responsive.sp(2)),
        child: Icon(icon, size: responsive.sp(20), color: widget.textSecondary),
      ),
    );
  }

  Widget _legenda(Color cor, String texto, Responsive responsive) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: responsive.sp(7),
          height: responsive.sp(7),
          decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
        ),
        SizedBox(width: responsive.sp(5)),
        Text(
          texto,
          style: TextStyle(
            fontSize: responsive.sp(9.5),
            color: widget.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _metaButton({
    required Key key,
    required IconData icon,
    required VoidCallback onTap,
    required Responsive responsive,
  }) {
    return Material(
      key: key,
      color: widget.isDark ? const Color(0xFF21262D) : const Color(0xFFF6F8FA),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: responsive.sp(30),
          height: responsive.sp(30),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: widget.borderColor),
          ),
          child: Icon(icon, size: responsive.sp(16), color: widget.textColor),
        ),
      ),
    );
  }

  Widget _buildSalvarButton(Responsive responsive) {
    final texto = _salvando
        ? 'SALVANDO...'
        : _salvo
        ? 'SALVO!'
        : 'SALVAR META';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _salvo ? const Color(0xFF238636) : null,
        gradient: _salvo
            ? null
            : const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
              ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextButton(
        key: const Key('salvar-meta'),
        onPressed: _salvando ? null : _salvarMeta,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white70,
          padding: EdgeInsets.symmetric(
            horizontal: responsive.sp(14),
            vertical: responsive.sp(9),
          ),
          minimumSize: Size(0, responsive.sp(34)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: TextStyle(
            fontSize: responsive.sp(10),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        child: Text(texto),
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter(this.segments);

  final List<_Segment> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    double startAngle = -3.14159 / 2;
    for (final segment in segments) {
      final sweepAngle = segment.percentage * 2 * 3.14159;
      if (sweepAngle <= 0) continue;
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16.0
        ..strokeCap = StrokeCap.butt;
      // Desconta metade da espessura para o traço não ser cortado pela borda.
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: size.width / 2 - 8),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) =>
      oldDelegate.segments != segments;
}

class _Segment {
  const _Segment(this.color, this.percentage);

  final Color color;
  final double percentage;
}
