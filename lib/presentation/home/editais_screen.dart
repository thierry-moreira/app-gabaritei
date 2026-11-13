import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/ui/responsive.dart';
import '../../models/edital.dart';
import 'edital_generator_sheet.dart';
import 'edital_ui.dart';
import 'simulados_ui.dart';

/// Central do Edital em Questão: ciclos ativos, criação e acesso ao estudo.
class EditaisScreen extends ConsumerWidget {
  const EditaisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responsive = Responsive.of(context);
    final colors = SimuladosColors.of(
      Theme.of(context).brightness == Brightness.dark,
    );
    final editais = ref.watch(editaisProvider);

    return EditalPageShell(
      colors: colors,
      child: RefreshIndicator(
        key: const Key('editais-refresh'),
        color: colors.accent,
        backgroundColor: colors.card,
        onRefresh: () async {
          ref.invalidate(editaisProvider);
          try {
            await ref.read(editaisProvider.future);
          } catch (_) {
            // O estado de erro fica visível no conteúdo da página.
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: responsive.pagePadding.copyWith(bottom: responsive.sp(24)),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: responsive.dashboardMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CabecalhoEditais(
                    colors: colors,
                    responsive: responsive,
                    onCriar: () => _criarEdital(context, ref, colors),
                    onGuia: () => _abrirGuia(context, colors, responsive),
                  ),
                  SizedBox(height: responsive.sp(20)),
                  if (editais.isLoading)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: responsive.sp(54),
                      ),
                      child: Center(
                        child: CircularProgressIndicator(
                          key: const Key('editais-loading'),
                          color: colors.accent,
                        ),
                      ),
                    )
                  else if (editais.hasError)
                    EditalErrorState(
                      colors: colors,
                      title: 'Não foi possível carregar seus editais',
                      message: 'Verifique sua conexão e tente novamente.',
                      onRetry: () => ref.invalidate(editaisProvider),
                    )
                  else if (editais.requireValue.isEmpty)
                    _EditalVazio(colors: colors, responsive: responsive)
                  else
                    _ListaEditais(
                      colors: colors,
                      responsive: responsive,
                      editais: editais.requireValue,
                      onContinuar: (edital) =>
                          context.push('/editais/estudar/${edital.id}'),
                      onDashboard: (edital) =>
                          context.push('/editais/dashboard/${edital.id}'),
                      onExcluir: (edital) =>
                          _excluirEdital(context, ref, colors, edital),
                    ),
                  SizedBox(height: responsive.sp(10)),
                  SimuladosFooter(colors: colors, responsive: responsive),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _criarEdital(
    BuildContext context,
    WidgetRef ref,
    SimuladosColors colors,
  ) async {
    final criado = await showModalBottomSheet<EditalCiclo>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Responsive.of(context).sp(24)),
        ),
        side: BorderSide(color: colors.border),
      ),
      builder: (_) => EditalGeneratorSheet(colors: colors),
    );
    if (criado == null || !context.mounted) return;
    ref.invalidate(editaisProvider);
    showEditalMessage(
      context,
      'Edital criado. Seu ciclo adaptativo está pronto.',
    );
  }

  Future<void> _excluirEdital(
    BuildContext context,
    WidgetRef ref,
    SimuladosColors colors,
    EditalCiclo edital,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.card,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Excluir edital?',
          style: TextStyle(color: colors.text, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Tem certeza que deseja apagar “${edital.titulo}” e o progresso deste ciclo?',
          style: TextStyle(color: colors.secondary, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancelar', style: TextStyle(color: colors.secondary)),
          ),
          FilledButton(
            key: Key('edital-excluir-confirmar-${edital.id}'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: colors.danger,
              foregroundColor: Colors.white,
              minimumSize: const Size(90, 48),
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;

    try {
      final perfil = await ref.read(perfilAtualProvider.future);
      if (perfil == null) throw StateError('Sessão indisponível.');
      await ref
          .read(editalRepositoryProvider)
          .excluir(idEdital: edital.id, idUsuario: perfil.id);
      ref.invalidate(editaisProvider);
      if (!context.mounted) return;
      showEditalMessage(context, 'Edital excluído.');
    } catch (error) {
      if (!context.mounted) return;
      showEditalMessage(context, editalErrorMessage(error));
    }
  }

  Future<void> _abrirGuia(
    BuildContext context,
    SimuladosColors colors,
    Responsive responsive,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.card,
        surfaceTintColor: Colors.transparent,
        icon: Icon(Icons.track_changes_rounded, color: colors.accent),
        title: Text(
          'Como funciona o Edital em Questão',
          style: TextStyle(
            color: colors.text,
            fontSize: responsive.sp(16),
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'Monte seu ciclo escolhendo as matérias e os assuntos do edital. '
          'O Gabaritei seleciona questões inéditas e ajusta a meta de cada '
          'assunto conforme seu desempenho, priorizando o que precisa de revisão.',
          style: TextStyle(
            color: colors.secondary,
            height: 1.5,
            fontSize: responsive.sp(11.5),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(90, 48),
            ),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }
}

class _CabecalhoEditais extends StatelessWidget {
  const _CabecalhoEditais({
    required this.colors,
    required this.responsive,
    required this.onCriar,
    required this.onGuia,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final VoidCallback onCriar;
  final VoidCallback onGuia;

  @override
  Widget build(BuildContext context) {
    final titulo = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: responsive.sp(46),
          height: responsive.sp(46),
          decoration: BoxDecoration(
            color: colors.communitySoft,
            borderRadius: BorderRadius.circular(responsive.sp(14)),
            border: Border.all(color: colors.community.withValues(alpha: 0.22)),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.track_changes_rounded,
            size: responsive.sp(25),
            color: colors.community,
          ),
        ),
        SizedBox(width: responsive.sp(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edital em Questão',
                style: TextStyle(
                  color: colors.text,
                  fontSize: responsive.sp(21),
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.35,
                ),
              ),
              SizedBox(height: responsive.sp(4)),
              Text(
                'Monte seu ciclo automatizado e estude com inteligência.',
                style: TextStyle(
                  color: colors.secondary,
                  fontSize: responsive.sp(11.5),
                  height: 1.45,
                ),
              ),
              SizedBox(height: responsive.sp(3)),
              TextButton.icon(
                key: const Key('edital-guia'),
                onPressed: onGuia,
                icon: Icon(Icons.info_outline_rounded, size: responsive.sp(15)),
                label: const Text('Ver Guia do Edital'),
                style: TextButton.styleFrom(
                  foregroundColor: colors.community,
                  padding: EdgeInsets.zero,
                  minimumSize: Size(0, responsive.sp(34)),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  alignment: Alignment.centerLeft,
                  textStyle: TextStyle(
                    fontSize: responsive.sp(11.5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final botao = FilledButton.icon(
      key: const Key('edital-criar'),
      onPressed: onCriar,
      icon: Icon(Icons.add_rounded, size: responsive.sp(19)),
      label: const Text('Criar Novo Edital'),
      style: FilledButton.styleFrom(
        backgroundColor: colors.isDark
            ? const Color(0xFF4F46E5)
            : colors.community,
        foregroundColor: Colors.white,
        minimumSize: Size(double.infinity, responsive.sp(50)),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(responsive.sp(13)),
        ),
        textStyle: TextStyle(
          fontSize: responsive.sp(12.5),
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    if (responsive.isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          titulo,
          SizedBox(height: responsive.sp(15)),
          botao,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: titulo),
        SizedBox(width: responsive.sp(22)),
        SizedBox(width: responsive.sp(250), child: botao),
      ],
    );
  }
}

class _EditalVazio extends StatelessWidget {
  const _EditalVazio({required this.colors, required this.responsive});

  final SimuladosColors colors;
  final Responsive responsive;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('editais-vazio'),
      padding: EdgeInsets.symmetric(
        horizontal: responsive.sp(22),
        vertical: responsive.sp(30),
      ),
      decoration: BoxDecoration(
        color: colors.isDark ? const Color(0xFF0C1322) : colors.card,
        borderRadius: BorderRadius.circular(responsive.sp(18)),
        border: Border.all(
          color: colors.isDark
              ? colors.border
              : colors.border.withValues(alpha: 0.85),
          width: colors.isDark ? 1 : 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: responsive.sp(82),
            height: responsive.sp(82),
            decoration: BoxDecoration(
              color: colors.cardSoft,
              shape: BoxShape.circle,
              border: Border.all(color: colors.border),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.track_changes_rounded,
              size: responsive.sp(43),
              color: colors.muted,
            ),
          ),
          SizedBox(height: responsive.sp(17)),
          Text(
            'Nenhum edital ativo',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.text,
              fontSize: responsive.sp(16),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: responsive.sp(7)),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: responsive.sp(310)),
            child: Text(
              'Você ainda não configurou seu plano de estudos. Selecione os assuntos do edital e deixe o Gabaritei organizar seu ciclo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.secondary,
                fontSize: responsive.sp(11.5),
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListaEditais extends StatelessWidget {
  const _ListaEditais({
    required this.colors,
    required this.responsive,
    required this.editais,
    required this.onContinuar,
    required this.onDashboard,
    required this.onExcluir,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final List<EditalCiclo> editais;
  final ValueChanged<EditalCiclo> onContinuar;
  final ValueChanged<EditalCiclo> onDashboard;
  final ValueChanged<EditalCiclo> onExcluir;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Container(
            width: responsive.sp(4),
            height: responsive.sp(22),
            decoration: BoxDecoration(
              color: colors.community,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SizedBox(width: responsive.sp(9)),
          Expanded(
            child: Text(
              'Meus editais ativos',
              style: TextStyle(
                color: colors.text,
                fontSize: responsive.sp(13),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            '${editais.length}',
            style: TextStyle(
              color: colors.secondary,
              fontSize: responsive.sp(11),
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
      SizedBox(height: responsive.sp(11)),
      for (var i = 0; i < editais.length; i++) ...[
        _EditalCard(
          key: Key('edital-card-${editais[i].id}'),
          edital: editais[i],
          colors: colors,
          responsive: responsive,
          onContinuar: () => onContinuar(editais[i]),
          onDashboard: () => onDashboard(editais[i]),
          onExcluir: () => onExcluir(editais[i]),
        ),
        if (i < editais.length - 1) SizedBox(height: responsive.sp(10)),
      ],
    ],
  );
}

class _EditalCard extends StatelessWidget {
  const _EditalCard({
    super.key,
    required this.edital,
    required this.colors,
    required this.responsive,
    required this.onContinuar,
    required this.onDashboard,
    required this.onExcluir,
  });

  final EditalCiclo edital;
  final SimuladosColors colors;
  final Responsive responsive;
  final VoidCallback onContinuar;
  final VoidCallback onDashboard;
  final VoidCallback onExcluir;

  @override
  Widget build(BuildContext context) => SimuladoPanel(
    colors: colors,
    radius: responsive.sp(16),
    padding: EdgeInsets.all(responsive.sp(15)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: responsive.sp(40),
              height: responsive.sp(40),
              decoration: BoxDecoration(
                color: colors.communitySoft,
                borderRadius: BorderRadius.circular(responsive.sp(12)),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.track_changes_rounded, color: colors.community),
            ),
            SizedBox(width: responsive.sp(10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    edital.titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: responsive.sp(14),
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (edital.criadoEm != null) ...[
                    SizedBox(height: responsive.sp(4)),
                    Text(
                      'Criado em ${DateFormat('dd/MM/yyyy').format(edital.criadoEm!)}',
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: responsive.sp(9.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: responsive.sp(13)),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: Key('edital-continuar-${edital.id}'),
                onPressed: onContinuar,
                icon: Icon(Icons.play_arrow_rounded, size: responsive.sp(18)),
                label: const Text('Continuar Ciclo'),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, responsive.sp(46)),
                  textStyle: TextStyle(
                    fontSize: responsive.sp(11),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SizedBox(width: responsive.sp(6)),
            IconButton(
              key: Key('edital-dashboard-${edital.id}'),
              onPressed: onDashboard,
              tooltip: 'Ver estatísticas',
              style: IconButton.styleFrom(
                foregroundColor: colors.community,
                minimumSize: Size(responsive.sp(46), responsive.sp(46)),
              ),
              icon: const Icon(Icons.bar_chart_rounded),
            ),
            IconButton(
              key: Key('edital-excluir-${edital.id}'),
              onPressed: onExcluir,
              tooltip: 'Excluir edital',
              style: IconButton.styleFrom(
                foregroundColor: colors.danger,
                minimumSize: Size(responsive.sp(46), responsive.sp(46)),
              ),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ],
    ),
  );
}
