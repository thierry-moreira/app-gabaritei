import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_exception.dart';
import '../../core/providers.dart';
import '../../core/ui/responsive.dart';
import '../../models/study.dart';
import 'flashcards_ui.dart';

/// Painel de categorias e revisões do dia, alinhado ao Stitch.
class FlashcardsScreen extends ConsumerWidget {
  const FlashcardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responsive = Responsive.of(context);
    final colors = FlashcardsColors.of(
      Theme.of(context).brightness == Brightness.dark,
    );
    final dashboard = ref.watch(flashcardsDashboardProvider);

    return FlashcardsPageShell(
      child: RefreshIndicator(
        key: const Key('flashcards-refresh'),
        onRefresh: () async {
          ref.invalidate(flashcardsDashboardProvider);
          try {
            await ref.read(flashcardsDashboardProvider.future);
          } catch (_) {
            // O erro fica visível no corpo da tela.
          }
        },
        color: colors.accent,
        backgroundColor: colors.card,
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
                  _CabecalhoDeck(
                    colors: colors,
                    responsive: responsive,
                    onNovaCategoria: () =>
                        _criarCategoria(context, ref, colors),
                  ),
                  SizedBox(height: responsive.sp(20)),
                  if (dashboard.isLoading)
                    _CarregandoDeck(colors: colors, responsive: responsive)
                  else if (dashboard.hasError)
                    _ErroDeck(
                      colors: colors,
                      responsive: responsive,
                      mensagem: _mensagemErro(dashboard.error),
                      onTentar: () {
                        ref.invalidate(flashcardsDashboardProvider);
                      },
                    )
                  else
                    _ConteudoDeck(
                      colors: colors,
                      responsive: responsive,
                      dados: dashboard.requireValue,
                      onCriarCategoria: () =>
                          _criarCategoria(context, ref, colors),
                      onEstudarTodos: () =>
                          context.push('/flashcards/estudar/todos'),
                      onEstudarCategoria: (categoria) =>
                          context.push('/flashcards/estudar/${categoria.id}'),
                      onGerenciarCategoria: (categoria) =>
                          context.push('/flashcards/categoria/${categoria.id}'),
                      onExcluirCategoria: (categoria) =>
                          _excluirCategoria(context, ref, colors, categoria),
                    ),
                  SizedBox(height: responsive.sp(12)),
                  FlashcardsFooter(colors: colors, responsive: responsive),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _criarCategoria(
    BuildContext context,
    WidgetRef ref,
    FlashcardsColors colors,
  ) async {
    final nome = await showNovaFlashcardCategoriaDialog(
      context,
      colors: colors,
    );
    if (nome == null || !context.mounted) return;

    try {
      final perfil = await ref.read(perfilAtualProvider.future);
      if (perfil == null) throw StateError('Sessão indisponível.');
      await ref
          .read(flashcardRepositoryProvider)
          .criarCategoria(idUsuario: perfil.id.toString(), nome: nome);
      ref.invalidate(flashcardsDashboardProvider);
      if (!context.mounted) return;
      _mensagem(context, 'Categoria criada.');
    } catch (error) {
      if (!context.mounted) return;
      _mensagem(context, _mensagemErro(error));
    }
  }

  Future<void> _excluirCategoria(
    BuildContext context,
    WidgetRef ref,
    FlashcardsColors colors,
    FlashcardCategoria categoria,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.card,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Excluir categoria?',
          style: TextStyle(color: colors.text, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'A categoria “${categoria.nome}” e todos os flashcards vinculados '
          'serão excluídos permanentemente.',
          style: TextStyle(color: colors.secondary, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancelar', style: TextStyle(color: colors.secondary)),
          ),
          FilledButton(
            key: const Key('flashcards-categoria-excluir-confirmar'),
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
          .read(flashcardRepositoryProvider)
          .excluirCategoria(
            idCategoria: categoria.id,
            idUsuario: perfil.id.toString(),
          );
      ref.invalidate(flashcardsDashboardProvider);
      if (!context.mounted) return;
      _mensagem(context, 'Categoria excluída.');
    } catch (error) {
      if (!context.mounted) return;
      _mensagem(context, _mensagemErro(error));
    }
  }
}

class _CabecalhoDeck extends StatelessWidget {
  const _CabecalhoDeck({
    required this.colors,
    required this.responsive,
    required this.onNovaCategoria,
  });

  final FlashcardsColors colors;
  final Responsive responsive;
  final VoidCallback onNovaCategoria;

  @override
  Widget build(BuildContext context) {
    final titulo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Meu Deck de Flashcards',
          style: TextStyle(
            fontSize: responsive.sp(24),
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: colors.text,
          ),
        ),
        SizedBox(height: responsive.sp(6)),
        Text(
          'Transforme questões em memória de longo prazo.',
          style: TextStyle(
            fontSize: responsive.sp(12.5),
            height: 1.4,
            color: colors.secondary,
          ),
        ),
      ],
    );

    final botao = FilledButton.icon(
      key: const Key('flashcards-nova-categoria'),
      onPressed: onNovaCategoria,
      icon: Icon(Icons.create_new_folder_outlined, size: responsive.sp(17)),
      label: const Text('Nova Categoria'),
      style: FilledButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        minimumSize: Size(double.infinity, responsive.sp(48)),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(responsive.sp(12)),
        ),
        textStyle: TextStyle(
          fontSize: responsive.sp(12.5),
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    if (responsive.isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          titulo,
          SizedBox(height: responsive.sp(14)),
          botao,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: titulo),
        SizedBox(width: responsive.sp(20)),
        SizedBox(width: responsive.sp(205), child: botao),
      ],
    );
  }
}

class _CarregandoDeck extends StatelessWidget {
  const _CarregandoDeck({required this.colors, required this.responsive});

  final FlashcardsColors colors;
  final Responsive responsive;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: responsive.sp(64)),
    child: Center(
      child: CircularProgressIndicator(
        key: const Key('flashcards-loading'),
        color: colors.accent,
      ),
    ),
  );
}

class _ErroDeck extends StatelessWidget {
  const _ErroDeck({
    required this.colors,
    required this.responsive,
    required this.mensagem,
    required this.onTentar,
  });

  final FlashcardsColors colors;
  final Responsive responsive;
  final String mensagem;
  final VoidCallback onTentar;

  @override
  Widget build(BuildContext context) {
    return FlashcardsPanel(
      key: const Key('flashcards-erro'),
      colors: colors,
      padding: EdgeInsets.all(responsive.sp(22)),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: responsive.sp(34),
            color: colors.muted,
          ),
          SizedBox(height: responsive.sp(10)),
          Text(
            'Não foi possível carregar seus flashcards',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.text,
              fontSize: responsive.sp(15),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: responsive.sp(6)),
          Text(
            mensagem,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.secondary, height: 1.4),
          ),
          SizedBox(height: responsive.sp(14)),
          OutlinedButton.icon(
            key: const Key('flashcards-tentar-novamente'),
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

class _ConteudoDeck extends StatelessWidget {
  const _ConteudoDeck({
    required this.colors,
    required this.responsive,
    required this.dados,
    required this.onCriarCategoria,
    required this.onEstudarTodos,
    required this.onEstudarCategoria,
    required this.onGerenciarCategoria,
    required this.onExcluirCategoria,
  });

  final FlashcardsColors colors;
  final Responsive responsive;
  final FlashcardsDashboardData dados;
  final VoidCallback onCriarCategoria;
  final VoidCallback onEstudarTodos;
  final ValueChanged<FlashcardCategoria> onEstudarCategoria;
  final ValueChanged<FlashcardCategoria> onGerenciarCategoria;
  final ValueChanged<FlashcardCategoria> onExcluirCategoria;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compactStats = constraints.maxWidth < 700;
            final metric = _MetricCard(
              colors: colors,
              responsive: responsive,
              total: dados.paraRevisarHoje,
            );
            final invitation = _InvitationCard(
              colors: colors,
              responsive: responsive,
              total: dados.paraRevisarHoje,
              onEstudarTodos: onEstudarTodos,
            );
            if (compactStats) {
              return Column(
                children: [
                  metric,
                  SizedBox(height: responsive.sp(12)),
                  invitation,
                ],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: responsive.sp(220), child: metric),
                  SizedBox(width: responsive.sp(12)),
                  Expanded(child: invitation),
                ],
              ),
            );
          },
        ),
        SizedBox(height: responsive.sp(24)),
        Row(
          children: [
            Expanded(
              child: Text(
                'Minhas Categorias',
                style: TextStyle(
                  color: colors.text,
                  fontSize: responsive.sp(16),
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
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
                '${dados.categorias.length} ${dados.categorias.length == 1 ? 'total' : 'totais'}',
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
        if (dados.categorias.isEmpty)
          _EstadoVazioCategorias(
            colors: colors,
            responsive: responsive,
            onCriar: onCriarCategoria,
          )
        else
          _GradeCategorias(
            colors: colors,
            responsive: responsive,
            categorias: dados.categorias,
            onEstudar: onEstudarCategoria,
            onGerenciar: onGerenciarCategoria,
            onExcluir: onExcluirCategoria,
          ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.colors,
    required this.responsive,
    required this.total,
  });

  final FlashcardsColors colors;
  final Responsive responsive;
  final int total;

  @override
  Widget build(BuildContext context) {
    return FlashcardsPanel(
      key: const Key('flashcards-revisar-hoje'),
      colors: colors,
      radius: responsive.sp(20),
      padding: EdgeInsets.symmetric(
        horizontal: responsive.sp(20),
        vertical: responsive.sp(22),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$total',
            style: TextStyle(
              fontSize: responsive.sp(48),
              height: 1,
              fontWeight: FontWeight.w800,
              color: colors.accent,
              letterSpacing: -1.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(height: responsive.sp(8)),
          Text(
            'PARA REVISAR HOJE',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.secondary,
              fontSize: responsive.sp(10.5),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.colors,
    required this.responsive,
    required this.total,
    required this.onEstudarTodos,
  });

  final FlashcardsColors colors;
  final Responsive responsive;
  final int total;
  final VoidCallback onEstudarTodos;

  @override
  Widget build(BuildContext context) {
    return FlashcardsPanel(
      key: const Key('flashcards-convite'),
      colors: colors,
      radius: responsive.sp(20),
      padding: EdgeInsets.all(responsive.sp(18)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: responsive.sp(42),
            height: responsive.sp(42),
            decoration: BoxDecoration(
              color: colors.accentSoft,
              borderRadius: BorderRadius.circular(responsive.sp(13)),
              border: Border.all(color: colors.accentBorder),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: colors.accent,
              size: responsive.sp(20),
            ),
          ),
          SizedBox(width: responsive.sp(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pronto para começar?',
                  style: TextStyle(
                    color: colors.text,
                    fontSize: responsive.sp(14),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: responsive.sp(4)),
                Text(
                  'Mantenha sua ofensiva praticando seus cards diários.',
                  style: TextStyle(
                    color: colors.secondary,
                    fontSize: responsive.sp(11.5),
                    height: 1.45,
                  ),
                ),
                if (total > 0) ...[
                  SizedBox(height: responsive.sp(12)),
                  FilledButton.icon(
                    key: const Key('flashcards-estudar-todos'),
                    onPressed: onEstudarTodos,
                    icon: Icon(
                      Icons.play_arrow_rounded,
                      size: responsive.sp(17),
                    ),
                    label: const Text('Estudar Todos'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(48, 48),
                      padding: EdgeInsets.symmetric(
                        horizontal: responsive.sp(16),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(responsive.sp(11)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EstadoVazioCategorias extends StatelessWidget {
  const _EstadoVazioCategorias({
    required this.colors,
    required this.responsive,
    required this.onCriar,
  });

  final FlashcardsColors colors;
  final Responsive responsive;
  final VoidCallback onCriar;

  @override
  Widget build(BuildContext context) {
    return FlashcardsPanel(
      key: const Key('flashcards-vazio'),
      colors: colors,
      radius: responsive.sp(20),
      padding: EdgeInsets.symmetric(
        horizontal: responsive.sp(24),
        vertical: responsive.sp(34),
      ),
      child: Column(
        children: [
          Container(
            width: responsive.sp(62),
            height: responsive.sp(62),
            decoration: BoxDecoration(
              color: colors.accentSoft,
              borderRadius: BorderRadius.circular(responsive.sp(18)),
              border: Border.all(color: colors.accentBorder),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.layers_rounded,
              size: responsive.sp(30),
              color: colors.accent,
            ),
          ),
          SizedBox(height: responsive.sp(14)),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: responsive.sp(310)),
            child: Text(
              'Você ainda não tem categorias de flashcards.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.secondary,
                fontSize: responsive.sp(12),
                height: 1.5,
              ),
            ),
          ),
          SizedBox(height: responsive.sp(16)),
          OutlinedButton.icon(
            key: const Key('flashcards-comecar-agora'),
            onPressed: onCriar,
            icon: Icon(Icons.arrow_forward_rounded, size: responsive.sp(15)),
            label: const Text('Começar Agora'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.accent,
              side: BorderSide(color: colors.accentBorder, width: 1.3),
              minimumSize: const Size(48, 48),
              padding: EdgeInsets.symmetric(horizontal: responsive.sp(16)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(responsive.sp(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradeCategorias extends StatelessWidget {
  const _GradeCategorias({
    required this.colors,
    required this.responsive,
    required this.categorias,
    required this.onEstudar,
    required this.onGerenciar,
    required this.onExcluir,
  });

  final FlashcardsColors colors;
  final Responsive responsive;
  final List<FlashcardCategoria> categorias;
  final ValueChanged<FlashcardCategoria> onEstudar;
  final ValueChanged<FlashcardCategoria> onGerenciar;
  final ValueChanged<FlashcardCategoria> onExcluir;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final colunas = constraints.maxWidth >= 760 ? 2 : 1;
        final espaco = responsive.sp(12);
        final largura =
            (constraints.maxWidth - espaco * (colunas - 1)) / colunas;
        return Wrap(
          spacing: espaco,
          runSpacing: espaco,
          children: [
            for (var i = 0; i < categorias.length; i++)
              SizedBox(
                width: largura,
                child: _CategoriaCard(
                  key: Key('flashcards-categoria-${categorias[i].id}'),
                  colors: colors,
                  responsive: responsive,
                  categoria: categorias[i],
                  cor: _coresCategoria[i % _coresCategoria.length],
                  onEstudar: () => onEstudar(categorias[i]),
                  onGerenciar: () => onGerenciar(categorias[i]),
                  onExcluir: () => onExcluir(categorias[i]),
                ),
              ),
          ],
        );
      },
    );
  }

  static const _coresCategoria = <Color>[
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFF8B5CF6),
    Color(0xFFF59E0B),
    Color(0xFFF43F5E),
    Color(0xFF06B6D4),
  ];
}

class _CategoriaCard extends StatelessWidget {
  const _CategoriaCard({
    super.key,
    required this.colors,
    required this.responsive,
    required this.categoria,
    required this.cor,
    required this.onEstudar,
    required this.onGerenciar,
    required this.onExcluir,
  });

  final FlashcardsColors colors;
  final Responsive responsive;
  final FlashcardCategoria categoria;
  final Color cor;
  final VoidCallback onEstudar;
  final VoidCallback onGerenciar;
  final VoidCallback onExcluir;

  @override
  Widget build(BuildContext context) {
    return FlashcardsPanel(
      colors: colors,
      radius: responsive.sp(18),
      child: Padding(
        padding: EdgeInsets.all(responsive.sp(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: responsive.sp(42),
                  height: responsive.sp(42),
                  decoration: BoxDecoration(
                    color: cor.withValues(alpha: colors.isDark ? 0.16 : 0.10),
                    borderRadius: BorderRadius.circular(responsive.sp(12)),
                    border: Border.all(color: cor.withValues(alpha: 0.28)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.bookmark_added_outlined,
                    color: cor,
                    size: responsive.sp(20),
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: 'Ações da categoria',
                  icon: Icon(Icons.more_vert_rounded, color: colors.secondary),
                  onSelected: (value) {
                    if (value == 'gerenciar') onGerenciar();
                    if (value == 'excluir') onExcluir();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'gerenciar',
                      child: ListTile(
                        leading: Icon(Icons.view_list_rounded),
                        title: Text('Gerenciar Cards'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'excluir',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline_rounded),
                        title: Text('Excluir Categoria'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: responsive.sp(10)),
            Text(
              categoria.nome,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.text,
                fontSize: responsive.sp(15),
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            SizedBox(height: responsive.sp(6)),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.sp(8),
                  vertical: responsive.sp(4),
                ),
                decoration: BoxDecoration(
                  color: colors.cardSoft,
                  borderRadius: BorderRadius.circular(responsive.sp(6)),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  categoria.nomeMateria?.trim().isNotEmpty ?? false
                      ? categoria.nomeMateria!
                      : 'Personalizada',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.secondary,
                    fontSize: responsive.sp(10),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(height: responsive.sp(14)),
            OutlinedButton.icon(
              key: Key('flashcards-estudar-categoria-${categoria.id}'),
              onPressed: onEstudar,
              icon: Icon(Icons.play_arrow_rounded, size: responsive.sp(17)),
              label: const Text('Estudar Esta Categoria'),
              style: OutlinedButton.styleFrom(
                foregroundColor: cor,
                side: BorderSide(color: cor.withValues(alpha: 0.55)),
                minimumSize: Size(double.infinity, responsive.sp(46)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(responsive.sp(11)),
                ),
                textStyle: TextStyle(
                  fontSize: responsive.sp(11.5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _mensagemErro(Object? erro) {
  if (erro is AppException) return erro.message;
  if (erro is StateError) {
    return 'Sua sessão não está disponível. Entre novamente.';
  }
  return 'Não foi possível concluir a operação. Tente novamente.';
}

void _mensagem(BuildContext context, String mensagem) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(mensagem),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
}
