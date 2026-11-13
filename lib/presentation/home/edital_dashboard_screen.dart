import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/ui/responsive.dart';
import '../../models/edital.dart';
import '../../models/stats.dart';
import '../../services/filter_service.dart';
import 'edital_ui.dart';
import 'simulados_ui.dart';

/// Raio-X do edital: progresso geral, prioridade adaptativa e alertas.
class EditalDashboardScreen extends ConsumerWidget {
  const EditalDashboardScreen({super.key, required this.idEdital});

  final int idEdital;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responsive = Responsive.of(context);
    final colors = SimuladosColors.of(
      Theme.of(context).brightness == Brightness.dark,
    );
    final painel = ref.watch(editalPainelProvider(idEdital));

    return EditalPageShell(
      colors: colors,
      child: painel.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            key: const Key('edital-dashboard-loading'),
            color: colors.accent,
          ),
        ),
        error: (error, _) => EditalErrorState(
          colors: colors,
          title: 'Não foi possível carregar o raio-X',
          message: editalErrorMessage(error),
          onRetry: () => ref.invalidate(editalPainelProvider(idEdital)),
          onBack: () => context.go('/editais'),
        ),
        data: (dados) => _ConteudoDashboard(
          colors: colors,
          responsive: responsive,
          painel: dados,
          onRefresh: () async {
            ref.invalidate(editalPainelProvider(idEdital));
            try {
              await ref.read(editalPainelProvider(idEdital).future);
            } catch (_) {
              // O estado de erro é exibido no conteúdo do painel.
            }
          },
          onVoltar: () => context.go('/editais'),
          onEstudar: () => context.push('/editais/estudar/$idEdital'),
          onRevisar: (ponto) {
            ref
                .read(questoesFiltrosProvider.notifier)
                .atualizar(
                  QuestaoFiltros(
                    idsMaterias: [ponto.idMateria],
                    idsTopicos: [ponto.idTopico],
                  ),
                );
            context.go('/questoes');
          },
        ),
      ),
    );
  }
}

class _ConteudoDashboard extends StatelessWidget {
  const _ConteudoDashboard({
    required this.colors,
    required this.responsive,
    required this.painel,
    required this.onRefresh,
    required this.onVoltar,
    required this.onEstudar,
    required this.onRevisar,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final EditalPainel painel;
  final Future<void> Function() onRefresh;
  final VoidCallback onVoltar;
  final VoidCallback onEstudar;
  final ValueChanged<PontoAtencaoEdital> onRevisar;

  @override
  Widget build(BuildContext context) {
    final dashboard = painel.dashboard;
    return RefreshIndicator(
      color: colors.accent,
      backgroundColor: colors.card,
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        key: const Key('edital-dashboard-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: responsive.pagePadding.copyWith(bottom: responsive.sp(28)),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: responsive.detailedMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      key: const Key('edital-dashboard-voltar'),
                      onPressed: onVoltar,
                      tooltip: 'Voltar aos editais',
                      style: IconButton.styleFrom(
                        foregroundColor: colors.secondary,
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    SizedBox(width: responsive.sp(4)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Raio-X do Edital',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.text,
                              fontSize: responsive.sp(19),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            painel.edital.titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.secondary,
                              fontSize: responsive.sp(10.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: responsive.sp(15)),
                FilledButton.icon(
                  key: const Key('edital-dashboard-continuar'),
                  onPressed: onEstudar,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Continuar Ciclo'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, responsive.sp(48)),
                    textStyle: TextStyle(
                      fontSize: responsive.sp(12),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(height: responsive.sp(17)),
                _MetricasEdital(
                  colors: colors,
                  responsive: responsive,
                  taxa: dashboard.desempenhoGeral,
                  resolvidas: dashboard.totalResolvidas,
                ),
                if (dashboard.topicosPrioridade.isNotEmpty) ...[
                  SizedBox(height: responsive.sp(20)),
                  _TituloSecao(
                    colors: colors,
                    responsive: responsive,
                    title: 'Prioridades do ciclo',
                    subtitle: 'Assuntos priorizados pelo seu desempenho',
                    icon: Icons.sort_rounded,
                  ),
                  SizedBox(height: responsive.sp(9)),
                  SimuladoPanel(
                    key: const Key('edital-dashboard-prioridades'),
                    colors: colors,
                    padding: EdgeInsets.all(responsive.sp(12)),
                    child: Column(
                      children: [
                        for (
                          var i = 0;
                          i < dashboard.topicosPrioridade.length && i < 10;
                          i++
                        ) ...[
                          _LinhaPrioridade(
                            colors: colors,
                            responsive: responsive,
                            prioridade: dashboard.topicosPrioridade[i],
                            nomeMateria: _nomeMateria(
                              dashboard.topicosPrioridade[i].idMateria,
                            ),
                            posicao: i + 1,
                          ),
                          if (i < dashboard.topicosPrioridade.length - 1 &&
                              i < 9)
                            Divider(height: 1, color: colors.border),
                        ],
                      ],
                    ),
                  ),
                ],
                if (dashboard.pontosAtencao.isNotEmpty) ...[
                  SizedBox(height: responsive.sp(20)),
                  _TituloSecao(
                    colors: colors,
                    responsive: responsive,
                    title: 'Pontos de atenção',
                    subtitle: 'Assuntos com menos de 60% de acertos',
                    icon: Icons.warning_amber_rounded,
                  ),
                  SizedBox(height: responsive.sp(9)),
                  for (final ponto in dashboard.pontosAtencao) ...[
                    _PontoAtencaoCard(
                      colors: colors,
                      responsive: responsive,
                      ponto: ponto,
                      onRevisar: () => onRevisar(ponto),
                    ),
                    SizedBox(height: responsive.sp(8)),
                  ],
                ],
                SizedBox(height: responsive.sp(20)),
                _TituloSecao(
                  colors: colors,
                  responsive: responsive,
                  title: 'Desempenho por disciplina',
                  subtitle: 'Resultado acumulado em cada matéria',
                  icon: Icons.bar_chart_rounded,
                ),
                SizedBox(height: responsive.sp(9)),
                if (painel.materias.isEmpty)
                  SimuladoPanel(
                    colors: colors,
                    padding: EdgeInsets.all(responsive.sp(16)),
                    child: Text(
                      'Ainda não há matérias neste edital.',
                      style: TextStyle(color: colors.secondary),
                    ),
                  )
                else
                  for (final materia in painel.materias) ...[
                    _DesempenhoMateriaCard(
                      colors: colors,
                      responsive: responsive,
                      materia: materia,
                    ),
                    SizedBox(height: responsive.sp(8)),
                  ],
                SimuladosFooter(colors: colors, responsive: responsive),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _nomeMateria(int idMateria) {
    for (final materia in painel.materias) {
      if (materia.idMateria == idMateria) {
        return materia.nomeMateria ?? 'Matéria';
      }
    }
    return 'Matéria';
  }
}

class _MetricasEdital extends StatelessWidget {
  const _MetricasEdital({
    required this.colors,
    required this.responsive,
    required this.taxa,
    required this.resolvidas,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final int taxa;
  final int resolvidas;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final gap = responsive.sp(8);
      final width = (constraints.maxWidth - gap * 2) / 3;
      return Row(
        children: [
          SizedBox(
            width: width,
            child: _MetricCard(
              colors: colors,
              responsive: responsive,
              icon: Icons.track_changes_rounded,
              value: '$taxa%',
              label: 'Taxa de acerto',
              tone: colors.community,
            ),
          ),
          SizedBox(width: gap),
          SizedBox(
            width: width,
            child: _MetricCard(
              colors: colors,
              responsive: responsive,
              icon: Icons.checklist_rounded,
              value: '$resolvidas',
              label: 'Questões resolvidas',
              tone: colors.success,
            ),
          ),
          SizedBox(width: gap),
          SizedBox(
            width: width,
            child: _MetricCard(
              colors: colors,
              responsive: responsive,
              icon: Icons.auto_awesome_rounded,
              value: 'Ativo',
              label: 'Ciclo adaptativo',
              tone: colors.accent,
            ),
          ),
        ],
      );
    },
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.colors,
    required this.responsive,
    required this.icon,
    required this.value,
    required this.label,
    required this.tone,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final IconData icon;
  final String value;
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) => SimuladoPanel(
    colors: colors,
    radius: responsive.sp(13),
    padding: EdgeInsets.all(responsive.sp(9)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: tone, size: responsive.sp(17)),
        SizedBox(height: responsive.sp(5)),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.text,
            fontSize: responsive.sp(15),
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.secondary,
            fontSize: responsive.sp(8.5),
            height: 1.3,
          ),
        ),
      ],
    ),
  );
}

class _TituloSecao extends StatelessWidget {
  const _TituloSecao({
    required this.colors,
    required this.responsive,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: colors.accent, size: responsive.sp(17)),
      SizedBox(width: responsive.sp(8)),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: colors.text,
                fontSize: responsive.sp(12.5),
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: colors.secondary,
                fontSize: responsive.sp(9.5),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _LinhaPrioridade extends StatelessWidget {
  const _LinhaPrioridade({
    required this.colors,
    required this.responsive,
    required this.prioridade,
    required this.nomeMateria,
    required this.posicao,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final TopicoPrioridade prioridade;
  final String nomeMateria;
  final int posicao;

  @override
  Widget build(BuildContext context) {
    final cor = _corPrioridade(colors, prioridade.nivelPrioridade);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: responsive.sp(9)),
      child: Row(
        children: [
          Container(
            width: responsive.sp(25),
            height: responsive.sp(25),
            decoration: BoxDecoration(
              color: colors.cardSoft,
              borderRadius: BorderRadius.circular(responsive.sp(8)),
            ),
            alignment: Alignment.center,
            child: Text(
              '$posicao',
              style: TextStyle(
                color: colors.secondary,
                fontSize: responsive.sp(9),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(width: responsive.sp(8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prioridade.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: responsive.sp(10.5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: responsive.sp(3)),
                Text(
                  '$nomeMateria · ${prioridade.taxaAcerto}% · Meta ${prioridade.metaDinamica}',
                  style: TextStyle(
                    color: colors.secondary,
                    fontSize: responsive.sp(9),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: responsive.sp(6)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.sp(7),
              vertical: responsive.sp(4),
            ),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: colors.isDark ? 0.16 : 0.09),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: cor.withValues(alpha: 0.3)),
            ),
            child: Text(
              _etiquetaPrioridade(prioridade.nivelPrioridade),
              style: TextStyle(
                color: cor,
                fontSize: responsive.sp(8.5),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PontoAtencaoCard extends StatelessWidget {
  const _PontoAtencaoCard({
    required this.colors,
    required this.responsive,
    required this.ponto,
    required this.onRevisar,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final PontoAtencaoEdital ponto;
  final VoidCallback onRevisar;

  @override
  Widget build(BuildContext context) => SimuladoPanel(
    colors: colors,
    padding: EdgeInsets.all(responsive.sp(12)),
    child: Row(
      children: [
        Icon(Icons.warning_amber_rounded, color: colors.danger),
        SizedBox(width: responsive.sp(8)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ponto.topico,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.text,
                  fontSize: responsive.sp(10.5),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: responsive.sp(2)),
              Text(
                '${ponto.materia} · ${ponto.taxa}% · ${ponto.resolvidas} questões',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.secondary,
                  fontSize: responsive.sp(9),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: responsive.sp(4)),
        IconButton(
          key: Key('edital-revisar-${ponto.idTopico}'),
          onPressed: onRevisar,
          tooltip: 'Treinar este assunto',
          style: IconButton.styleFrom(
            foregroundColor: colors.accent,
            minimumSize: const Size(48, 48),
          ),
          icon: const Icon(Icons.play_circle_outline_rounded),
        ),
      ],
    ),
  );
}

class _DesempenhoMateriaCard extends StatelessWidget {
  const _DesempenhoMateriaCard({
    required this.colors,
    required this.responsive,
    required this.materia,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final EditalMateria materia;

  @override
  Widget build(BuildContext context) {
    final taxa = materia.taxaAcerto;
    final cor = _corTaxa(colors, taxa);
    return SimuladoPanel(
      colors: colors,
      radius: responsive.sp(13),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Material(
          color: colors.card,
          child: ExpansionTile(
            key: PageStorageKey('edital-dashboard-materia-${materia.id}'),
            tilePadding: EdgeInsets.symmetric(horizontal: responsive.sp(12)),
            childrenPadding: EdgeInsets.fromLTRB(
              responsive.sp(12),
              0,
              responsive.sp(12),
              responsive.sp(10),
            ),
            leading: Icon(Icons.menu_book_outlined, color: colors.accent),
            title: Text(
              materia.nomeMateria ?? 'Matéria',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.text,
                fontSize: responsive.sp(11),
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Padding(
              padding: EdgeInsets.only(top: responsive.sp(5)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: taxa.clamp(0.0, 1.0),
                    minHeight: responsive.sp(5),
                    backgroundColor: colors.cardSoft,
                    color: cor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  SizedBox(height: responsive.sp(4)),
                  Text(
                    '${(taxa * 100).round()}% · ${materia.questoesResolvidas} resolvidas',
                    style: TextStyle(
                      color: colors.secondary,
                      fontSize: responsive.sp(8.5),
                    ),
                  ),
                ],
              ),
            ),
            children: [
              if (materia.topicos.isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: responsive.sp(7)),
                    child: Text(
                      'Ainda não há desempenho por assunto.',
                      style: TextStyle(
                        color: colors.secondary,
                        fontSize: responsive.sp(9.5),
                      ),
                    ),
                  ),
                )
              else
                for (final topico in materia.topicos)
                  _LinhaDesempenhoTopico(
                    colors: colors,
                    responsive: responsive,
                    topico: topico,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinhaDesempenhoTopico extends StatelessWidget {
  const _LinhaDesempenhoTopico({
    required this.colors,
    required this.responsive,
    required this.topico,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final EditalTopico topico;

  @override
  Widget build(BuildContext context) {
    final taxa = topico.taxaAcerto;
    final cor = _corTaxa(colors, taxa);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: responsive.sp(6)),
      child: Row(
        children: [
          Icon(
            topico.concluido
                ? Icons.check_circle_rounded
                : Icons.circle_outlined,
            size: responsive.sp(14),
            color: topico.concluido ? colors.success : colors.muted,
          ),
          SizedBox(width: responsive.sp(7)),
          Expanded(
            child: Text(
              topico.nomeTopico ?? 'Assunto',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.secondary,
                fontSize: responsive.sp(9.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${(taxa * 100).round()}%',
            style: TextStyle(
              color: cor,
              fontSize: responsive.sp(9.5),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

Color _corPrioridade(SimuladosColors colors, String nivel) => switch (nivel) {
  'alta' => colors.danger,
  'media' => colors.private,
  _ => colors.success,
};

String _etiquetaPrioridade(String nivel) => switch (nivel) {
  'alta' => 'Alta',
  'media' => 'Média',
  _ => 'Baixa',
};

Color _corTaxa(SimuladosColors colors, double taxa) {
  if (taxa < 0.6) return colors.danger;
  if (taxa < 0.8) return colors.private;
  return colors.success;
}
