import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/ui/responsive.dart';
import '../../models/study.dart';
import 'resumos_ui.dart';

/// Painel de resumos agrupados automaticamente por matéria.
class ResumosScreen extends ConsumerWidget {
  const ResumosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responsive = Responsive.of(context);
    final colors = ResumosColors.of(
      Theme.of(context).brightness == Brightness.dark,
    );
    final materias = ref.watch(resumosPorMateriaProvider);

    return ResumosPageShell(
      child: RefreshIndicator(
        key: const Key('resumos-refresh'),
        color: colors.accent,
        backgroundColor: colors.card,
        onRefresh: () async {
          ref.invalidate(resumosPorMateriaProvider);
          try {
            await ref.read(resumosPorMateriaProvider.future);
          } catch (_) {
            // O erro é apresentado pela própria tela.
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: responsive.pagePadding.copyWith(bottom: responsive.sp(28)),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: responsive.dashboardMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _CabecalhoResumos(),
                  SizedBox(
                    height: responsive.isCompact
                        ? responsive.sp(18)
                        : responsive.sp(24),
                  ),
                  if (materias.isLoading)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: responsive.sp(56),
                      ),
                      child: Center(
                        child: CircularProgressIndicator(
                          key: const Key('resumos-loading'),
                          color: colors.accent,
                        ),
                      ),
                    )
                  else if (materias.hasError)
                    _ErroResumos(
                      colors: colors,
                      responsive: responsive,
                      mensagem: resumosErrorMessage(materias.error),
                      onTentar: () => ref.invalidate(resumosPorMateriaProvider),
                    )
                  else if (materias.requireValue.isEmpty) ...[
                    SizedBox(height: responsive.size.height * 0.14),
                    _EstadoVazioResumos(
                      colors: colors,
                      responsive: responsive,
                      onBuscarQuestoes: () => _buscarQuestoes(context, ref),
                    ),
                  ] else
                    _ListaMaterias(
                      colors: colors,
                      responsive: responsive,
                      materias: materias.requireValue,
                      onAbrir: (materia) =>
                          context.push('/resumos/materia/${materia.idMateria}'),
                      onExcluir: (materia) =>
                          _excluirCaderno(context, ref, colors, materia),
                    ),
                  SizedBox(height: responsive.sp(10)),
                  ResumosFooter(colors: colors, responsive: responsive),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _buscarQuestoes(BuildContext context, WidgetRef ref) {
    ref.read(questoesFiltrosProvider.notifier).limpar();
    context.go('/questoes');
  }

  Future<void> _excluirCaderno(
    BuildContext context,
    WidgetRef ref,
    ResumosColors colors,
    ResumosPorMateria materia,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.card,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Excluir caderno inteiro?',
          style: TextStyle(color: colors.text, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Esta ação excluirá os ${materia.total} resumo(s) de '
          '${materia.nomeMateria}. Não será possível desfazer.',
          style: TextStyle(color: colors.secondary, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancelar', style: TextStyle(color: colors.secondary)),
          ),
          FilledButton(
            key: Key('resumos-excluir-materia-confirmar-${materia.idMateria}'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: colors.danger,
              foregroundColor: Colors.white,
              minimumSize: const Size(90, 48),
            ),
            child: const Text('Excluir tudo'),
          ),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;

    try {
      final perfil = await ref.read(perfilAtualProvider.future);
      if (perfil == null) throw StateError('Sessão indisponível.');
      await ref
          .read(resumoRepositoryProvider)
          .excluirMateria(
            idUsuario: perfil.id.toString(),
            idMateria: materia.idMateria,
          );
      ref.invalidate(resumosPorMateriaProvider);
      if (!context.mounted) return;
      showResumosMessage(context, 'Caderno excluído.');
    } catch (error) {
      if (!context.mounted) return;
      showResumosMessage(context, resumosErrorMessage(error));
    }
  }
}

class _CabecalhoResumos extends StatelessWidget {
  const _CabecalhoResumos();

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final colors = ResumosColors.of(
      Theme.of(context).brightness == Brightness.dark,
    );
    final icon = Container(
      width: responsive.sp(responsive.isCompact ? 36 : 48),
      height: responsive.sp(responsive.isCompact ? 36 : 48),
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(responsive.sp(12)),
        border: Border.all(color: colors.accentBorder),
      ),
      alignment: Alignment.center,
      child: Icon(
        responsive.isCompact
            ? Icons.description_outlined
            : Icons.menu_book_outlined,
        color: colors.accent,
        size: responsive.sp(responsive.isCompact ? 19 : 24),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        icon,
        SizedBox(width: responsive.sp(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Caderno de Resumos',
                style: TextStyle(
                  color: colors.text,
                  fontSize: responsive.sp(responsive.isCompact ? 20 : 24),
                  height: 1.18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.45,
                ),
              ),
              SizedBox(height: responsive.sp(4)),
              Text(
                'Suas revisões rápidas organizadas automaticamente por matéria.',
                style: TextStyle(
                  color: colors.secondary,
                  fontSize: responsive.sp(11.5),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErroResumos extends StatelessWidget {
  const _ErroResumos({
    required this.colors,
    required this.responsive,
    required this.mensagem,
    required this.onTentar,
  });

  final ResumosColors colors;
  final Responsive responsive;
  final String mensagem;
  final VoidCallback onTentar;

  @override
  Widget build(BuildContext context) {
    return ResumosPanel(
      key: const Key('resumos-erro'),
      colors: colors,
      padding: EdgeInsets.all(responsive.sp(22)),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: responsive.sp(36),
            color: colors.muted,
          ),
          SizedBox(height: responsive.sp(10)),
          Text(
            'Não foi possível carregar seus resumos',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.text,
              fontSize: responsive.sp(15),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: responsive.sp(7)),
          Text(
            mensagem,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.secondary, height: 1.45),
          ),
          SizedBox(height: responsive.sp(14)),
          OutlinedButton.icon(
            key: const Key('resumos-tentar-novamente'),
            onPressed: onTentar,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar novamente'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.accent,
              side: BorderSide(color: colors.accentBorder),
              minimumSize: const Size(48, 48),
            ),
          ),
        ],
      ),
    );
  }
}

class _EstadoVazioResumos extends StatelessWidget {
  const _EstadoVazioResumos({
    required this.colors,
    required this.responsive,
    required this.onBuscarQuestoes,
  });

  final ResumosColors colors;
  final Responsive responsive;
  final VoidCallback onBuscarQuestoes;

  @override
  Widget build(BuildContext context) {
    return ResumosDashedPanel(
      key: const Key('resumos-vazio'),
      colors: colors,
      radius: responsive.sp(20),
      padding: EdgeInsets.symmetric(
        horizontal: responsive.sp(22),
        vertical: responsive.sp(responsive.isCompact ? 30 : 36),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: responsive.sp(64),
            height: responsive.sp(64),
            decoration: BoxDecoration(
              color: colors.isDark ? colors.card : colors.cardSoft,
              borderRadius: BorderRadius.circular(responsive.sp(18)),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.library_books_outlined,
              size: responsive.sp(36),
              color: colors.muted,
            ),
          ),
          SizedBox(height: responsive.sp(14)),
          Text(
            'Caderno Vazio',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.text,
              fontSize: responsive.sp(18),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: responsive.sp(7)),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: responsive.sp(310)),
            child: Text(
              'Ainda não existem resumos salvos. Use a IA nas questões para '
              'gerar seus primeiros pontos de revisão.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.secondary,
                fontSize: responsive.sp(12),
                height: 1.55,
              ),
            ),
          ),
          SizedBox(height: responsive.sp(18)),
          FilledButton.icon(
            key: const Key('resumos-buscar-questoes'),
            onPressed: onBuscarQuestoes,
            icon: Icon(Icons.add_rounded, size: responsive.sp(18)),
            label: const Text('Buscar Questões'),
            style: FilledButton.styleFrom(
              backgroundColor: colors.isDark ? colors.accent : colors.primary,
              foregroundColor: Colors.white,
              minimumSize: Size(responsive.sp(220), responsive.sp(48)),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(responsive.sp(12)),
              ),
              textStyle: TextStyle(
                fontSize: responsive.sp(12.5),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListaMaterias extends StatelessWidget {
  const _ListaMaterias({
    required this.colors,
    required this.responsive,
    required this.materias,
    required this.onAbrir,
    required this.onExcluir,
  });

  final ResumosColors colors;
  final Responsive responsive;
  final List<ResumosPorMateria> materias;
  final ValueChanged<ResumosPorMateria> onAbrir;
  final ValueChanged<ResumosPorMateria> onExcluir;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Suas matérias',
                style: TextStyle(
                  color: colors.text,
                  fontSize: responsive.sp(15),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: responsive.sp(10),
                vertical: responsive.sp(5),
              ),
              decoration: BoxDecoration(
                color: colors.cardSoft,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                '${materias.length} ${materias.length == 1 ? 'matéria' : 'matérias'}',
                style: TextStyle(
                  color: colors.secondary,
                  fontSize: responsive.sp(10.5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: responsive.sp(12)),
        LayoutBuilder(
          builder: (context, constraints) {
            final colunas = constraints.maxWidth >= 760 ? 2 : 1;
            final gap = responsive.sp(12);
            final largura =
                (constraints.maxWidth - gap * (colunas - 1)) / colunas;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var i = 0; i < materias.length; i++)
                  SizedBox(
                    width: largura,
                    child: _MateriaCard(
                      key: Key('resumos-materia-${materias[i].idMateria}'),
                      colors: colors,
                      responsive: responsive,
                      materia: materias[i],
                      acento: _cores[i % _cores.length],
                      onAbrir: () => onAbrir(materias[i]),
                      onExcluir: () => onExcluir(materias[i]),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  static const _cores = <Color>[
    Color(0xFF2563EB),
    Color(0xFF10B981),
    Color(0xFF8B5CF6),
    Color(0xFFF59E0B),
    Color(0xFFEF476F),
    Color(0xFF06B6D4),
  ];
}

class _MateriaCard extends StatelessWidget {
  const _MateriaCard({
    super.key,
    required this.colors,
    required this.responsive,
    required this.materia,
    required this.acento,
    required this.onAbrir,
    required this.onExcluir,
  });

  final ResumosColors colors;
  final Responsive responsive;
  final ResumosPorMateria materia;
  final Color acento;
  final VoidCallback onAbrir;
  final VoidCallback onExcluir;

  @override
  Widget build(BuildContext context) {
    return ResumosPanel(
      colors: colors,
      padding: EdgeInsets.all(responsive.sp(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: responsive.sp(44),
                height: responsive.sp(44),
                decoration: BoxDecoration(
                  color: acento.withValues(alpha: colors.isDark ? 0.16 : 0.09),
                  borderRadius: BorderRadius.circular(responsive.sp(13)),
                  border: Border.all(color: acento.withValues(alpha: 0.24)),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.menu_book_outlined,
                  size: responsive.sp(21),
                  color: acento,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.sp(10),
                  vertical: responsive.sp(5),
                ),
                decoration: BoxDecoration(
                  color: acento.withValues(alpha: colors.isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: acento.withValues(alpha: 0.24)),
                ),
                child: Text(
                  '${materia.total} ${materia.total == 1 ? 'item' : 'itens'}',
                  style: TextStyle(
                    color: acento,
                    fontSize: responsive.sp(10),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: responsive.sp(6)),
              IconButton(
                key: Key('resumos-excluir-materia-${materia.idMateria}'),
                onPressed: onExcluir,
                tooltip: 'Excluir caderno inteiro',
                style: IconButton.styleFrom(
                  foregroundColor: colors.danger,
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          SizedBox(height: responsive.sp(10)),
          Text(
            materia.nomeMateria,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.text,
              fontSize: responsive.sp(14.5),
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          SizedBox(height: responsive.sp(9)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: Key('resumos-ver-materia-${materia.idMateria}'),
              onPressed: onAbrir,
              icon: Icon(Icons.arrow_forward_rounded, size: responsive.sp(15)),
              label: const Text('Ver revisões'),
              style: TextButton.styleFrom(
                foregroundColor: colors.accent,
                minimumSize: const Size(48, 48),
                padding: EdgeInsets.symmetric(horizontal: responsive.sp(8)),
                textStyle: TextStyle(
                  fontSize: responsive.sp(11.5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
