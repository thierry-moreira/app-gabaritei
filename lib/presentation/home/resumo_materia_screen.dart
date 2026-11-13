import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/ui/responsive.dart';
import '../../models/study.dart';
import 'resumos_ui.dart';

/// Leitura cronológica dos resumos de uma matéria, com impressão nativa.
class ResumoMateriaScreen extends ConsumerStatefulWidget {
  const ResumoMateriaScreen({super.key, required this.idMateria});

  final int idMateria;

  @override
  ConsumerState<ResumoMateriaScreen> createState() =>
      _ResumoMateriaScreenState();
}

class _ResumoMateriaScreenState extends ConsumerState<ResumoMateriaScreen> {
  late final PageController _pageController;
  var _paginaAtual = 0;
  var _imprimindo = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final colors = ResumosColors.of(
      Theme.of(context).brightness == Brightness.dark,
    );
    final detalhe = ref.watch(resumoMateriaDetalheProvider(widget.idMateria));

    return ResumosPageShell(
      child: detalhe.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            key: const Key('resumo-materia-loading'),
            color: colors.accent,
          ),
        ),
        error: (error, _) => _EstadoErroMateria(
          colors: colors,
          responsive: responsive,
          mensagem: resumosErrorMessage(error),
          onVoltar: _voltar,
          onTentar: () =>
              ref.invalidate(resumoMateriaDetalheProvider(widget.idMateria)),
        ),
        data: (dados) {
          if (dados == null) {
            return _MateriaNaoEncontrada(
              colors: colors,
              responsive: responsive,
              onVoltar: _voltar,
            );
          }
          if (dados.resumos.isEmpty) {
            return _MateriaSemResumos(
              colors: colors,
              responsive: responsive,
              materia: dados.materia,
              onVoltar: _voltar,
              onBuscarQuestoes: () => _buscarQuestoes(context, ref),
            );
          }

          if (_paginaAtual >= dados.resumos.length) {
            _paginaAtual = math.max(0, dados.resumos.length - 1);
          }
          return Focus(
            onKeyEvent: (_, event) =>
                _atalhoTeclado(event, dados.resumos.length),
            child: _ConteudoMateria(
              colors: colors,
              responsive: responsive,
              dados: dados,
              pageController: _pageController,
              paginaAtual: _paginaAtual,
              imprimindo: _imprimindo,
              onPaginaChanged: (index) => setState(() => _paginaAtual = index),
              onVoltar: _voltar,
              onImprimir: () => _imprimir(context, dados),
              onExcluirMateria: () =>
                  _excluirMateria(context, ref, colors, dados),
              onExcluirResumo: (resumo) =>
                  _excluirResumo(context, ref, colors, dados, resumo),
              onReportar: (resumo) => _reportar(context, colors, resumo),
              onAnterior: () => _irParaPagina(_paginaAtual - 1),
              onProxima: () => _irParaPagina(_paginaAtual + 1),
            ),
          );
        },
      ),
    );
  }

  KeyEventResult _atalhoTeclado(KeyEvent event, int total) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _irParaPagina(math.max(0, _paginaAtual - 1));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _irParaPagina(math.min(total - 1, _paginaAtual + 1));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _irParaPagina(int index) {
    if (index < 0) return;
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    } else {
      setState(() => _paginaAtual = index);
    }
  }

  void _voltar() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/resumos');
    }
  }

  void _buscarQuestoes(BuildContext context, WidgetRef ref) {
    ref.read(questoesFiltrosProvider.notifier).limpar();
    context.go('/questoes');
  }

  Future<void> _imprimir(
    BuildContext context,
    ResumoMateriaDetalhe dados,
  ) async {
    if (_imprimindo) return;
    setState(() => _imprimindo = true);
    try {
      final impresso = await ref
          .read(resumoPrintServiceProvider)
          .imprimir(
            nomeMateria: dados.materia.nomeMateria,
            resumos: dados.resumos,
          );
      if (!context.mounted) return;
      if (impresso) {
        showResumosMessage(context, 'Documento enviado à impressão.');
      }
    } catch (_) {
      if (!context.mounted) return;
      showResumosMessage(
        context,
        'Não foi possível abrir a impressão. Tente novamente.',
      );
    } finally {
      if (mounted) setState(() => _imprimindo = false);
    }
  }

  Future<void> _excluirResumo(
    BuildContext context,
    WidgetRef ref,
    ResumosColors colors,
    ResumoMateriaDetalhe dados,
    Resumo resumo,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.card,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Excluir resumo?',
          style: TextStyle(color: colors.text, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Deseja remover este ponto de revisão do seu caderno?',
          style: TextStyle(color: colors.secondary, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancelar', style: TextStyle(color: colors.secondary)),
          ),
          FilledButton(
            key: Key('resumo-excluir-confirmar-${resumo.id}'),
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
      final indiceRemovido = dados.resumos.indexWhere(
        (item) => item.id == resumo.id,
      );
      await ref
          .read(resumoRepositoryProvider)
          .excluir(idUsuario: perfil.id.toString(), idResumo: resumo.id);
      ref.invalidate(resumoMateriaDetalheProvider(widget.idMateria));
      ref.invalidate(resumosPorMateriaProvider);
      if (!context.mounted) return;
      final novoTotal = dados.resumos.length - 1;
      final proximaPagina = novoTotal == 0
          ? 0
          : math.min(indiceRemovido, novoTotal - 1);
      setState(() => _paginaAtual = proximaPagina);
      if (_pageController.hasClients && novoTotal > 0) {
        _pageController.jumpToPage(proximaPagina);
      }
      showResumosMessage(context, 'Resumo excluído.');
    } catch (error) {
      if (!context.mounted) return;
      showResumosMessage(context, resumosErrorMessage(error));
    }
  }

  Future<void> _excluirMateria(
    BuildContext context,
    WidgetRef ref,
    ResumosColors colors,
    ResumoMateriaDetalhe dados,
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
          'Todos os ${dados.resumos.length} resumo(s) de '
          '${dados.materia.nomeMateria} serão removidos. Não será possível desfazer.',
          style: TextStyle(color: colors.secondary, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancelar', style: TextStyle(color: colors.secondary)),
          ),
          FilledButton(
            key: const Key('resumos-excluir-todos-confirmar'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: colors.danger,
              foregroundColor: Colors.white,
              minimumSize: const Size(110, 48),
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
            idMateria: widget.idMateria,
          );
      ref.invalidate(resumoMateriaDetalheProvider(widget.idMateria));
      ref.invalidate(resumosPorMateriaProvider);
      if (!context.mounted) return;
      context.go('/resumos');
      showResumosMessage(context, 'Caderno excluído.');
    } catch (error) {
      if (!context.mounted) return;
      showResumosMessage(context, resumosErrorMessage(error));
    }
  }

  Future<void> _reportar(
    BuildContext context,
    ResumosColors colors,
    Resumo resumo,
  ) async {
    final idQuestao = resumo.idQuestao;
    if (idQuestao == null) return;
    final feedback = await showResumosFeedbackDialog(context, colors: colors);
    if (feedback == null || !context.mounted) return;

    try {
      await ref
          .read(studyAiRepositoryProvider)
          .enviarFeedback(
            idQuestao: idQuestao,
            tipo: 'resumo',
            motivo: feedback.motivo,
            relato: feedback.relato,
          );
      if (!context.mounted) return;
      showResumosMessage(context, 'Obrigado. Seu relato foi enviado.');
    } catch (error) {
      if (!context.mounted) return;
      showResumosMessage(context, resumosErrorMessage(error));
    }
  }
}

class _ConteudoMateria extends StatelessWidget {
  const _ConteudoMateria({
    required this.colors,
    required this.responsive,
    required this.dados,
    required this.pageController,
    required this.paginaAtual,
    required this.imprimindo,
    required this.onPaginaChanged,
    required this.onVoltar,
    required this.onImprimir,
    required this.onExcluirMateria,
    required this.onExcluirResumo,
    required this.onReportar,
    required this.onAnterior,
    required this.onProxima,
  });

  final ResumosColors colors;
  final Responsive responsive;
  final ResumoMateriaDetalhe dados;
  final PageController pageController;
  final int paginaAtual;
  final bool imprimindo;
  final ValueChanged<int> onPaginaChanged;
  final VoidCallback onVoltar;
  final VoidCallback onImprimir;
  final VoidCallback onExcluirMateria;
  final ValueChanged<Resumo> onExcluirResumo;
  final ValueChanged<Resumo> onReportar;
  final VoidCallback onAnterior;
  final VoidCallback onProxima;

  @override
  Widget build(BuildContext context) {
    final alturaPagina = math.max(
      responsive.sp(220),
      math.min(responsive.sp(520), MediaQuery.sizeOf(context).height * 0.50),
    );
    final resumoAtual =
        dados.resumos[paginaAtual.clamp(0, dados.resumos.length - 1)];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: responsive.pagePadding.copyWith(bottom: responsive.sp(20)),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: responsive.questionsMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton.filledTonal(
                    key: const Key('resumo-materia-voltar'),
                    onPressed: onVoltar,
                    tooltip: 'Voltar para Resumos',
                    style: IconButton.styleFrom(
                      backgroundColor: colors.card,
                      foregroundColor: colors.text,
                      side: BorderSide(color: colors.border),
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  SizedBox(width: responsive.sp(10)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dados.materia.nomeMateria,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.text,
                            fontSize: responsive.sp(17),
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: responsive.sp(3)),
                        Text(
                          '${dados.resumos.length} pontos de revisão',
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
              SizedBox(height: responsive.sp(12)),
              Wrap(
                spacing: responsive.sp(8),
                runSpacing: responsive.sp(8),
                children: [
                  FilledButton.icon(
                    key: const Key('resumos-imprimir'),
                    onPressed: imprimindo ? null : onImprimir,
                    icon: imprimindo
                        ? SizedBox(
                            width: responsive.sp(17),
                            height: responsive.sp(17),
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(Icons.print_outlined, size: responsive.sp(17)),
                    label: Text(
                      imprimindo
                          ? 'Preparando PDF...'
                          : 'Imprimir / Salvar PDF',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(48, 48),
                      padding: EdgeInsets.symmetric(
                        horizontal: responsive.sp(14),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(responsive.sp(11)),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('resumos-excluir-materia'),
                    onPressed: onExcluirMateria,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: responsive.sp(17),
                    ),
                    label: const Text('Excluir Caderno'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.danger,
                      side: BorderSide(
                        color: colors.danger.withValues(alpha: 0.4),
                      ),
                      minimumSize: const Size(48, 48),
                      padding: EdgeInsets.symmetric(
                        horizontal: responsive.sp(13),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: responsive.sp(12)),
              SizedBox(
                height: alturaPagina,
                child: PageView.builder(
                  key: const Key('resumos-pager'),
                  controller: pageController,
                  itemCount: dados.resumos.length,
                  onPageChanged: onPaginaChanged,
                  itemBuilder: (context, index) => _ResumoPage(
                    key: ValueKey(dados.resumos[index].id),
                    colors: colors,
                    responsive: responsive,
                    resumo: dados.resumos[index],
                    numero: index + 1,
                    onExcluir: () => onExcluirResumo(dados.resumos[index]),
                    onReportar: dados.resumos[index].idQuestao == null
                        ? null
                        : () => onReportar(dados.resumos[index]),
                  ),
                ),
              ),
              SizedBox(height: responsive.sp(10)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    key: const Key('resumos-pagina-anterior'),
                    onPressed: paginaAtual > 0 ? onAnterior : null,
                    tooltip: 'Resumo anterior',
                    style: IconButton.styleFrom(
                      foregroundColor: colors.accent,
                      backgroundColor: colors.accentSoft,
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  SizedBox(width: responsive.sp(12)),
                  Text(
                    'Página ${paginaAtual + 1} de ${dados.resumos.length}',
                    key: const Key('resumos-pagina-indicador'),
                    style: TextStyle(
                      color: colors.secondary,
                      fontSize: responsive.sp(11.5),
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  SizedBox(width: responsive.sp(12)),
                  IconButton.filledTonal(
                    key: const Key('resumos-pagina-proxima'),
                    onPressed: paginaAtual < dados.resumos.length - 1
                        ? onProxima
                        : null,
                    tooltip: 'Próximo resumo',
                    style: IconButton.styleFrom(
                      foregroundColor: colors.accent,
                      backgroundColor: colors.accentSoft,
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              SizedBox(height: responsive.sp(7)),
              Text(
                'Deslize para navegar entre os resumos.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.muted,
                  fontSize: responsive.sp(10),
                ),
              ),
              if (resumoAtual.conteudo.isEmpty) const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumoPage extends StatelessWidget {
  const _ResumoPage({
    super.key,
    required this.colors,
    required this.responsive,
    required this.resumo,
    required this.numero,
    required this.onExcluir,
    this.onReportar,
  });

  final ResumosColors colors;
  final Responsive responsive;
  final Resumo resumo;
  final int numero;
  final VoidCallback onExcluir;
  final VoidCallback? onReportar;

  @override
  Widget build(BuildContext context) {
    return ResumosPanel(
      key: Key('resumo-page-${resumo.id}'),
      colors: colors,
      radius: responsive.sp(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              responsive.sp(15),
              responsive.sp(9),
              responsive.sp(6),
              responsive.sp(7),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: responsive.sp(10),
                    vertical: responsive.sp(6),
                  ),
                  decoration: BoxDecoration(
                    color: colors.accentSoft,
                    borderRadius: BorderRadius.circular(responsive.sp(8)),
                    border: Border.all(color: colors.accentBorder),
                  ),
                  child: Text(
                    'RESUMO #$numero',
                    style: TextStyle(
                      color: colors.accent,
                      fontSize: responsive.sp(9.5),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.55,
                    ),
                  ),
                ),
                const Spacer(),
                if (onReportar != null)
                  IconButton(
                    key: Key('resumo-reportar-${resumo.id}'),
                    onPressed: onReportar,
                    tooltip: 'Reportar problema neste resumo',
                    style: IconButton.styleFrom(
                      foregroundColor: colors.secondary,
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.flag_outlined),
                  ),
                IconButton(
                  key: Key('resumo-excluir-${resumo.id}'),
                  onPressed: onExcluir,
                  tooltip: 'Excluir este resumo',
                  style: IconButton.styleFrom(
                    foregroundColor: colors.danger,
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),
          Expanded(
            child: SingleChildScrollView(
              key: Key('resumo-conteudo-scroll-${resumo.id}'),
              padding: EdgeInsets.all(responsive.sp(16)),
              child: ResumosRichContent(
                content: resumo.conteudo,
                colors: colors,
                responsive: responsive,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MateriaSemResumos extends StatelessWidget {
  const _MateriaSemResumos({
    required this.colors,
    required this.responsive,
    required this.materia,
    required this.onVoltar,
    required this.onBuscarQuestoes,
  });

  final ResumosColors colors;
  final Responsive responsive;
  final ResumosPorMateria materia;
  final VoidCallback onVoltar;
  final VoidCallback onBuscarQuestoes;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: responsive.pagePadding,
      child: ResumosDashedPanel(
        key: const Key('resumo-materia-vazia'),
        colors: colors,
        padding: EdgeInsets.all(responsive.sp(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.note_alt_outlined,
              size: responsive.sp(42),
              color: colors.muted,
            ),
            SizedBox(height: responsive.sp(10)),
            Text(
              'Nenhum resumo nesta matéria.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.text,
                fontSize: responsive.sp(15),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: responsive.sp(15)),
            FilledButton.icon(
              onPressed: onBuscarQuestoes,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Buscar Questões'),
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
              ),
            ),
            TextButton(
              onPressed: onVoltar,
              child: const Text('Voltar para Resumos'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EstadoErroMateria extends StatelessWidget {
  const _EstadoErroMateria({
    required this.colors,
    required this.responsive,
    required this.mensagem,
    required this.onVoltar,
    required this.onTentar,
  });

  final ResumosColors colors;
  final Responsive responsive;
  final String mensagem;
  final VoidCallback onVoltar;
  final VoidCallback onTentar;

  @override
  Widget build(BuildContext context) => _ErroBase(
    colors: colors,
    responsive: responsive,
    title: 'Não foi possível carregar os resumos',
    message: mensagem,
    onTentar: onTentar,
    onVoltar: onVoltar,
  );
}

class _MateriaNaoEncontrada extends StatelessWidget {
  const _MateriaNaoEncontrada({
    required this.colors,
    required this.responsive,
    required this.onVoltar,
  });

  final ResumosColors colors;
  final Responsive responsive;
  final VoidCallback onVoltar;

  @override
  Widget build(BuildContext context) => _ErroBase(
    colors: colors,
    responsive: responsive,
    title: 'Caderno não encontrado',
    message: 'Esta matéria não possui resumos disponíveis nesta conta.',
    onTentar: onVoltar,
    onVoltar: onVoltar,
  );
}

class _ErroBase extends StatelessWidget {
  const _ErroBase({
    required this.colors,
    required this.responsive,
    required this.title,
    required this.message,
    required this.onTentar,
    required this.onVoltar,
  });

  final ResumosColors colors;
  final Responsive responsive;
  final String title;
  final String message;
  final VoidCallback onTentar;
  final VoidCallback onVoltar;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: responsive.pagePadding,
      child: ResumosPanel(
        colors: colors,
        padding: EdgeInsets.all(responsive.sp(22)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: responsive.sp(38),
              color: colors.muted,
            ),
            SizedBox(height: responsive.sp(10)),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.text,
                fontSize: responsive.sp(15),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: responsive.sp(7)),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.secondary, height: 1.45),
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
