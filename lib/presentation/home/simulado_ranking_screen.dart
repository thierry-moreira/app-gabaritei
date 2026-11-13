import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/ui/responsive.dart';
import '../../models/simulado.dart';
import 'simulados_ui.dart';

/// Ranking público do simulado, com estados de carregamento, erro e vazio.
class SimuladoRankingScreen extends ConsumerWidget {
  const SimuladoRankingScreen({super.key, required this.idSimulado});

  final String idSimulado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responsive = Responsive.of(context);
    final colors = SimuladosColors.of(
      Theme.of(context).brightness == Brightness.dark,
    );
    final ranking = ref.watch(simuladoRankingProvider(idSimulado));

    return SimuladoPageShell(
      colors: colors,
      child: ranking.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            key: const Key('simulado-ranking-loading'),
            color: colors.accent,
          ),
        ),
        error: (error, _) => _RankingErro(
          colors: colors,
          responsive: responsive,
          onVoltar: () => context.go('/simulados'),
          onTentar: () => ref.invalidate(simuladoRankingProvider(idSimulado)),
        ),
        data: (dados) => _RankingConteudo(
          colors: colors,
          responsive: responsive,
          dados: dados,
          onVoltar: () => context.go('/simulados'),
        ),
      ),
    );
  }
}

class _RankingConteudo extends StatelessWidget {
  const _RankingConteudo({
    required this.colors,
    required this.responsive,
    required this.dados,
    required this.onVoltar,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final SimuladoRankingDados dados;
  final VoidCallback onVoltar;

  @override
  Widget build(BuildContext context) {
    final isEmpty = dados.ranking.isEmpty;
    return SingleChildScrollView(
      key: const Key('simulado-ranking-scroll'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: responsive.pagePadding.copyWith(bottom: responsive.sp(28)),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: responsive.questionsMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    key: const Key('simulado-ranking-voltar'),
                    onPressed: onVoltar,
                    tooltip: 'Voltar para simulados',
                    style: IconButton.styleFrom(
                      foregroundColor: colors.secondary,
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  SizedBox(width: responsive.sp(5)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: responsive.sp(5)),
                        Text(
                          'Ranking Global',
                          style: TextStyle(
                            color: colors.text,
                            fontSize: responsive.sp(20),
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.35,
                          ),
                        ),
                        SizedBox(height: responsive.sp(3)),
                        Text(
                          dados.simulado.titulo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.secondary,
                            fontSize: responsive.sp(11.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: responsive.sp(42),
                    height: responsive.sp(42),
                    decoration: BoxDecoration(
                      color: colors.privateSoft,
                      borderRadius: BorderRadius.circular(responsive.sp(13)),
                      border: Border.all(
                        color: colors.private.withValues(alpha: 0.25),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.emoji_events_rounded,
                      color: colors.private,
                      size: responsive.sp(22),
                    ),
                  ),
                ],
              ),
              SizedBox(height: responsive.sp(20)),
              if (isEmpty)
                _RankingVazio(
                  colors: colors,
                  responsive: responsive,
                  onVoltar: onVoltar,
                )
              else
                _TabelaRanking(
                  colors: colors,
                  responsive: responsive,
                  ranking: dados.ranking,
                ),
              SizedBox(height: responsive.sp(12)),
              if (!isEmpty)
                Text(
                  'Exibindo os ${dados.ranking.length} melhores resultados.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: responsive.sp(10),
                  ),
                ),
              SizedBox(height: responsive.sp(12)),
              OutlinedButton.icon(
                onPressed: onVoltar,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Voltar para Simulados'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.accent,
                  side: BorderSide(color: colors.accentBorder),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabelaRanking extends StatelessWidget {
  const _TabelaRanking({
    required this.colors,
    required this.responsive,
    required this.ranking,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final List<RankingEntry> ranking;

  @override
  Widget build(BuildContext context) {
    return SimuladoPanel(
      key: const Key('simulado-ranking-lista'),
      colors: colors,
      radius: responsive.sp(17),
      padding: EdgeInsets.all(responsive.sp(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              responsive.sp(8),
              responsive.sp(5),
              responsive.sp(8),
              responsive.sp(10),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: responsive.sp(42),
                  child: _Coluna('POS.', colors, responsive),
                ),
                Expanded(child: _Coluna('ALUNO', colors, responsive)),
                SizedBox(
                  width: responsive.sp(70),
                  child: _Coluna(
                    'ACERTOS',
                    colors,
                    responsive,
                    alinharDireita: true,
                  ),
                ),
                SizedBox(
                  width: responsive.sp(64),
                  child: _Coluna(
                    'NOTA',
                    colors,
                    responsive,
                    alinharDireita: true,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),
          for (var i = 0; i < ranking.length; i++) ...[
            _LinhaRanking(
              key: Key('simulado-ranking-linha-${i + 1}'),
              colors: colors,
              responsive: responsive,
              entry: ranking[i],
              posicao: i + 1,
            ),
            if (i < ranking.length - 1)
              Divider(height: 1, color: colors.border.withValues(alpha: 0.65)),
          ],
        ],
      ),
    );
  }
}

class _Coluna extends StatelessWidget {
  const _Coluna(
    this.label,
    this.colors,
    this.responsive, {
    this.alinharDireita = false,
  });

  final String label;
  final SimuladosColors colors;
  final Responsive responsive;
  final bool alinharDireita;

  @override
  Widget build(BuildContext context) => Text(
    label,
    textAlign: alinharDireita ? TextAlign.right : TextAlign.left,
    style: TextStyle(
      color: colors.muted,
      fontSize: responsive.sp(8),
      fontWeight: FontWeight.w800,
      letterSpacing: 0.45,
    ),
  );
}

class _LinhaRanking extends StatelessWidget {
  const _LinhaRanking({
    super.key,
    required this.colors,
    required this.responsive,
    required this.entry,
    required this.posicao,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final RankingEntry entry;
  final int posicao;

  @override
  Widget build(BuildContext context) {
    final medalha = switch (posicao) {
      1 => const Color(0xFFF59E0B),
      2 => const Color(0xFF94A3B8),
      3 => const Color(0xFFB45309),
      _ => colors.secondary,
    };
    final data = entry.dataConclusao;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.sp(8),
        vertical: responsive.sp(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: responsive.sp(42),
            child: Row(
              children: [
                if (posicao <= 3)
                  Padding(
                    padding: EdgeInsets.only(right: responsive.sp(3)),
                    child: Icon(
                      Icons.emoji_events_rounded,
                      size: responsive.sp(13),
                      color: medalha,
                    ),
                  ),
                Text(
                  '$posicaoº',
                  style: TextStyle(
                    color: medalha,
                    fontSize: responsive.sp(10),
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.nomeUsuario,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: responsive.sp(10.5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (data != null) ...[
                  SizedBox(height: responsive.sp(2)),
                  Text(
                    DateFormat('dd/MM/yy').format(data),
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: responsive.sp(8.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: responsive.sp(70),
            child: Text(
              '${entry.respostasCorretas}/${entry.totalQuestoes}',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: colors.secondary,
                fontSize: responsive.sp(9.5),
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          SizedBox(width: responsive.sp(10)),
          SizedBox(
            width: responsive.sp(54),
            child: Text(
              entry.nota.toStringAsFixed(2),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: entry.nota >= 7 ? colors.success : colors.text,
                fontSize: responsive.sp(10),
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingVazio extends StatelessWidget {
  const _RankingVazio({
    required this.colors,
    required this.responsive,
    required this.onVoltar,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final VoidCallback onVoltar;

  @override
  Widget build(BuildContext context) => SimuladoPanel(
    key: const Key('simulado-ranking-vazio'),
    colors: colors,
    padding: EdgeInsets.symmetric(
      horizontal: responsive.sp(22),
      vertical: responsive.sp(28),
    ),
    child: Column(
      children: [
        Container(
          width: responsive.sp(62),
          height: responsive.sp(62),
          decoration: BoxDecoration(
            color: colors.privateSoft,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.emoji_events_outlined,
            color: colors.private,
            size: responsive.sp(31),
          ),
        ),
        SizedBox(height: responsive.sp(13)),
        Text(
          'Ninguém completou este simulado ainda.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.text,
            fontSize: responsive.sp(14),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: responsive.sp(6)),
        Text(
          'Seja o primeiro a aparecer por aqui!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.secondary,
            fontSize: responsive.sp(11),
          ),
        ),
        SizedBox(height: responsive.sp(14)),
        FilledButton.icon(
          onPressed: onVoltar,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Voltar'),
          style: FilledButton.styleFrom(
            backgroundColor: colors.accent,
            foregroundColor: Colors.white,
            minimumSize: const Size(120, 48),
          ),
        ),
      ],
    ),
  );
}

class _RankingErro extends StatelessWidget {
  const _RankingErro({
    required this.colors,
    required this.responsive,
    required this.onVoltar,
    required this.onTentar,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final VoidCallback onVoltar;
  final VoidCallback onTentar;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: responsive.pagePadding,
      child: SimuladoPanel(
        key: const Key('simulado-ranking-erro'),
        colors: colors,
        padding: EdgeInsets.all(responsive.sp(22)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              color: colors.muted,
              size: responsive.sp(36),
            ),
            SizedBox(height: responsive.sp(10)),
            Text(
              'Não foi possível carregar o ranking',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.text,
                fontSize: responsive.sp(15),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: responsive.sp(7)),
            Text(
              'Verifique sua conexão e tente novamente.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.secondary),
            ),
            SizedBox(height: responsive.sp(14)),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: responsive.sp(8),
              children: [
                OutlinedButton(
                  onPressed: onVoltar,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  child: const Text('Voltar'),
                ),
                FilledButton(
                  onPressed: onTentar,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(48, 48),
                  ),
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
