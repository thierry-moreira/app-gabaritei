import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_exception.dart';
import '../../core/providers.dart';
import '../../core/ui/responsive.dart';
import '../../models/study.dart';
import 'flashcards_ui.dart';

/// Gerenciamento dos flashcards de uma categoria.
class FlashcardCategoriaScreen extends ConsumerWidget {
  const FlashcardCategoriaScreen({super.key, required this.idCategoria});

  final String idCategoria;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responsive = Responsive.of(context);
    final colors = FlashcardsColors.of(
      Theme.of(context).brightness == Brightness.dark,
    );
    final detalhe = ref.watch(flashcardCategoriaDetalheProvider(idCategoria));

    return FlashcardsPageShell(
      child: RefreshIndicator(
        key: const Key('flashcard-categoria-refresh'),
        color: colors.accent,
        backgroundColor: colors.card,
        onRefresh: () async {
          ref.invalidate(flashcardCategoriaDetalheProvider(idCategoria));
          try {
            await ref.read(
              flashcardCategoriaDetalheProvider(idCategoria).future,
            );
          } catch (_) {
            // O estado de erro fica visível no corpo.
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
                  if (detalhe.isLoading)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: responsive.sp(72),
                      ),
                      child: Center(
                        child: CircularProgressIndicator(
                          key: const Key('flashcard-categoria-loading'),
                          color: colors.accent,
                        ),
                      ),
                    )
                  else if (detalhe.hasError)
                    _ErroCategoria(
                      colors: colors,
                      responsive: responsive,
                      mensagem: _mensagemErro(detalhe.error),
                      onVoltar: () => context.go('/flashcards'),
                    )
                  else if (detalhe.requireValue == null)
                    _CategoriaNaoEncontrada(
                      colors: colors,
                      responsive: responsive,
                      onVoltar: () => context.go('/flashcards'),
                    )
                  else
                    _ConteudoCategoria(
                      colors: colors,
                      responsive: responsive,
                      detalhe: detalhe.requireValue!,
                      onVoltar: () => _voltar(context),
                      onCriar: () => _criarCard(context, ref, colors),
                      onExcluir: (card) =>
                          _excluirCard(context, ref, colors, card),
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

  void _voltar(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/flashcards');
    }
  }

  Future<void> _criarCard(
    BuildContext context,
    WidgetRef ref,
    FlashcardsColors colors,
  ) async {
    final draft = await showNovoFlashcardDialog(context, colors: colors);
    if (draft == null || !context.mounted) return;

    try {
      final perfil = await ref.read(perfilAtualProvider.future);
      if (perfil == null) throw StateError('Sessão indisponível.');
      await ref
          .read(flashcardRepositoryProvider)
          .criar(
            idUsuario: perfil.id.toString(),
            idCategoria: idCategoria,
            frente: draft.frente,
            verso: draft.verso,
          );
      ref.invalidate(flashcardCategoriaDetalheProvider(idCategoria));
      ref.invalidate(flashcardsDashboardProvider);
      if (!context.mounted) return;
      _mensagem(context, 'Flashcard criado.');
    } catch (error) {
      if (!context.mounted) return;
      _mensagem(context, _mensagemErro(error));
    }
  }

  Future<void> _excluirCard(
    BuildContext context,
    WidgetRef ref,
    FlashcardsColors colors,
    Flashcard card,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.card,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Excluir flashcard?',
          style: TextStyle(color: colors.text, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Este card será removido permanentemente.',
          style: TextStyle(color: colors.secondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancelar', style: TextStyle(color: colors.secondary)),
          ),
          FilledButton(
            key: Key('flashcard-excluir-confirmar-${card.id}'),
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
          .excluir(idFlashcard: card.id, idUsuario: perfil.id.toString());
      ref.invalidate(flashcardCategoriaDetalheProvider(idCategoria));
      ref.invalidate(flashcardsDashboardProvider);
      if (!context.mounted) return;
      _mensagem(context, 'Flashcard excluído.');
    } catch (error) {
      if (!context.mounted) return;
      _mensagem(context, _mensagemErro(error));
    }
  }
}

class _ConteudoCategoria extends StatelessWidget {
  const _ConteudoCategoria({
    required this.colors,
    required this.responsive,
    required this.detalhe,
    required this.onVoltar,
    required this.onCriar,
    required this.onExcluir,
  });

  final FlashcardsColors colors;
  final Responsive responsive;
  final FlashcardCategoriaDetalhe detalhe;
  final VoidCallback onVoltar;
  final VoidCallback onCriar;
  final ValueChanged<Flashcard> onExcluir;

  @override
  Widget build(BuildContext context) {
    final heading = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton.filledTonal(
          key: const Key('flashcard-categoria-voltar'),
          onPressed: onVoltar,
          tooltip: 'Voltar aos flashcards',
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
          child: Padding(
            padding: EdgeInsets.only(top: responsive.sp(4)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detalhe.categoria.nome,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: responsive.sp(19),
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: -0.35,
                  ),
                ),
                SizedBox(height: responsive.sp(4)),
                Text(
                  '${detalhe.cards.length} ${detalhe.cards.length == 1 ? 'Card criado' : 'Cards criados'}',
                  style: TextStyle(
                    color: colors.secondary,
                    fontSize: responsive.sp(11),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    final botaoCriar = FilledButton.icon(
      key: const Key('flashcard-criar-novo'),
      onPressed: onCriar,
      icon: Icon(Icons.add_rounded, size: responsive.sp(18)),
      label: const Text('Criar Novo Card'),
      style: FilledButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        padding: EdgeInsets.symmetric(horizontal: responsive.sp(16)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(responsive.sp(11)),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (responsive.isCompact) ...[
          heading,
          SizedBox(height: responsive.sp(14)),
          SizedBox(width: double.infinity, child: botaoCriar),
        ] else
          Row(
            children: [
              Expanded(child: heading),
              SizedBox(width: responsive.sp(16)),
              botaoCriar,
            ],
          ),
        SizedBox(height: responsive.sp(18)),
        if (detalhe.cards.isEmpty)
          FlashcardsPanel(
            key: const Key('flashcard-categoria-vazia'),
            colors: colors,
            padding: EdgeInsets.symmetric(
              horizontal: responsive.sp(24),
              vertical: responsive.sp(34),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.style_outlined,
                  size: responsive.sp(40),
                  color: colors.muted,
                ),
                SizedBox(height: responsive.sp(10)),
                Text(
                  'Nenhum card nesta categoria ainda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.secondary,
                    fontSize: responsive.sp(12.5),
                    height: 1.4,
                  ),
                ),
                SizedBox(height: responsive.sp(14)),
                OutlinedButton.icon(
                  onPressed: onCriar,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Criar primeiro card'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.accent,
                    side: BorderSide(color: colors.accentBorder),
                    minimumSize: const Size(48, 48),
                  ),
                ),
              ],
            ),
          )
        else
          for (var i = 0; i < detalhe.cards.length; i++) ...[
            _CardGerenciavel(
              key: Key('flashcard-card-${detalhe.cards[i].id}'),
              colors: colors,
              responsive: responsive,
              card: detalhe.cards[i],
              onExcluir: () => onExcluir(detalhe.cards[i]),
            ),
            if (i != detalhe.cards.length - 1)
              SizedBox(height: responsive.sp(12)),
          ],
      ],
    );
  }
}

class _CardGerenciavel extends StatelessWidget {
  const _CardGerenciavel({
    super.key,
    required this.colors,
    required this.responsive,
    required this.card,
    required this.onExcluir,
  });

  final FlashcardsColors colors;
  final Responsive responsive;
  final Flashcard card;
  final VoidCallback onExcluir;

  @override
  Widget build(BuildContext context) {
    return FlashcardsPanel(
      colors: colors,
      radius: responsive.sp(16),
      padding: EdgeInsets.all(responsive.sp(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'FRENTE',
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: responsive.sp(10),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              IconButton(
                key: Key('flashcard-excluir-${card.id}'),
                onPressed: onExcluir,
                tooltip: 'Excluir flashcard',
                style: IconButton.styleFrom(
                  foregroundColor: colors.danger,
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          FlashcardRichText(
            text: card.frente,
            colors: colors,
            style: TextStyle(
              color: colors.text,
              fontSize: responsive.sp(13),
              height: 1.5,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: responsive.sp(12)),
            child: Divider(height: 1, color: colors.border),
          ),
          Text(
            'VERSO',
            style: TextStyle(
              color: colors.success,
              fontSize: responsive.sp(10),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
          SizedBox(height: responsive.sp(6)),
          FlashcardRichText(
            text: card.verso,
            colors: colors,
            style: TextStyle(
              color: colors.secondary,
              fontSize: responsive.sp(12),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErroCategoria extends StatelessWidget {
  const _ErroCategoria({
    required this.colors,
    required this.responsive,
    required this.mensagem,
    required this.onVoltar,
  });

  final FlashcardsColors colors;
  final Responsive responsive;
  final String mensagem;
  final VoidCallback onVoltar;

  @override
  Widget build(BuildContext context) => FlashcardsPanel(
    colors: colors,
    padding: EdgeInsets.all(responsive.sp(22)),
    child: Column(
      children: [
        Text(
          'Não foi possível abrir esta categoria',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.text,
            fontSize: responsive.sp(15),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: responsive.sp(8)),
        Text(mensagem, textAlign: TextAlign.center),
        SizedBox(height: responsive.sp(12)),
        FilledButton(
          onPressed: onVoltar,
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          child: const Text('Voltar ao deck'),
        ),
      ],
    ),
  );
}

class _CategoriaNaoEncontrada extends StatelessWidget {
  const _CategoriaNaoEncontrada({
    required this.colors,
    required this.responsive,
    required this.onVoltar,
  });

  final FlashcardsColors colors;
  final Responsive responsive;
  final VoidCallback onVoltar;

  @override
  Widget build(BuildContext context) => FlashcardsPanel(
    colors: colors,
    padding: EdgeInsets.all(responsive.sp(24)),
    child: Column(
      children: [
        Icon(
          Icons.folder_off_outlined,
          size: responsive.sp(38),
          color: colors.muted,
        ),
        SizedBox(height: responsive.sp(10)),
        Text(
          'Categoria não encontrada',
          style: TextStyle(
            color: colors.text,
            fontSize: responsive.sp(15),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: responsive.sp(14)),
        FilledButton(
          onPressed: onVoltar,
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          child: const Text('Voltar ao deck'),
        ),
      ],
    ),
  );
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
