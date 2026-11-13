import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_exception.dart';
import '../../core/providers.dart';
import '../../core/ui/responsive.dart';
import '../../models/study.dart';
import '../../repositories/study_ai_repository.dart';
import 'flashcards_ui.dart';

/// Sessão de revisão: flip da frente/verso e avaliação SM-2 de 0 a 3.
class FlashcardEstudoScreen extends ConsumerStatefulWidget {
  const FlashcardEstudoScreen({super.key, required this.idCategoria});

  final String idCategoria;

  @override
  ConsumerState<FlashcardEstudoScreen> createState() =>
      _FlashcardEstudoScreenState();
}

class _FlashcardEstudoScreenState extends ConsumerState<FlashcardEstudoScreen> {
  var _indice = 0;
  var _versoVisivel = false;
  var _enviando = false;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final colors = FlashcardsColors.of(
      Theme.of(context).brightness == Brightness.dark,
    );
    final fila = ref.watch(flashcardsParaRevisarProvider(widget.idCategoria));

    return FlashcardsPageShell(
      child: fila.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            key: const Key('flashcard-estudo-loading'),
            color: colors.accent,
          ),
        ),
        error: (error, _) => _ErroSessao(
          colors: colors,
          responsive: responsive,
          mensagem: _mensagemErro(error),
          onTentar: () =>
              ref.invalidate(flashcardsParaRevisarProvider(widget.idCategoria)),
          onSair: _sairDaSessao,
        ),
        data: (cards) {
          if (cards.isEmpty) {
            return _EstadoSessaoVazia(
              colors: colors,
              responsive: responsive,
              onVoltar: _sairDaSessao,
            );
          }
          if (_indice >= cards.length) {
            return _SessaoConcluida(
              colors: colors,
              responsive: responsive,
              onVoltar: _sairDaSessao,
            );
          }

          final card = cards[_indice];
          return Focus(
            autofocus: true,
            onKeyEvent: (_, event) => _atalhoTeclado(event),
            child: SingleChildScrollView(
              key: const Key('flashcard-estudo-conteudo'),
              padding: responsive.pagePadding.copyWith(
                top: responsive.sp(14),
                bottom: responsive.sp(28),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: math.min(responsive.questionsMaxWidth, 760),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BarSessao(
                        colors: colors,
                        responsive: responsive,
                        indice: _indice,
                        total: cards.length,
                        card: card,
                        enviando: _enviando,
                        onSair: _sairDaSessao,
                        onReportar: () => _reportar(context, colors, card),
                      ),
                      SizedBox(height: responsive.sp(12)),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          key: const Key('flashcard-estudo-progresso'),
                          value: (_indice + 1) / cards.length,
                          minHeight: responsive.sp(5),
                          backgroundColor: colors.cardSoft,
                          color: colors.accent,
                        ),
                      ),
                      SizedBox(height: responsive.sp(18)),
                      _FlashcardFlipView(
                        card: card,
                        colors: colors,
                        responsive: responsive,
                        versoVisivel: _versoVisivel,
                        enviando: _enviando,
                        onFlip: _alternarFace,
                      ),
                      SizedBox(height: responsive.sp(12)),
                      if (!_versoVisivel)
                        _RevelarButton(
                          colors: colors,
                          responsive: responsive,
                          onPressed: _alternarFace,
                        )
                      else
                        _BotoesQualidade(
                          colors: colors,
                          responsive: responsive,
                          enviando: _enviando,
                          onAvaliar: _avaliar,
                        ),
                      SizedBox(height: responsive.sp(8)),
                      Text(
                        _versoVisivel ? 'Como foi lembrar da resposta?' : 'Toque no card ou no botão para revelar a resposta.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.muted,
                          fontSize: responsive.sp(10.5),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  KeyEventResult _atalhoTeclado(KeyEvent event) {
    if (event is! KeyDownEvent || _enviando) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.space) {
      _alternarFace();
      return KeyEventResult.handled;
    }
    if (!_versoVisivel) return KeyEventResult.ignored;

    final qualidadePorTecla = <LogicalKeyboardKey, int>{
      LogicalKeyboardKey.digit1: 0,
      LogicalKeyboardKey.numpad1: 0,
      LogicalKeyboardKey.digit2: 1,
      LogicalKeyboardKey.numpad2: 1,
      LogicalKeyboardKey.digit3: 2,
      LogicalKeyboardKey.numpad3: 2,
      LogicalKeyboardKey.digit4: 3,
      LogicalKeyboardKey.numpad4: 3,
    };
    final qualidade = qualidadePorTecla[event.logicalKey];
    if (qualidade == null) return KeyEventResult.ignored;
    _avaliar(qualidade);
    return KeyEventResult.handled;
  }

  void _alternarFace() {
    if (_enviando) return;
    setState(() => _versoVisivel = !_versoVisivel);
  }

  Future<void> _avaliar(int qualidade) async {
    if (_enviando || !_versoVisivel) return;
    final cards = ref
        .read(flashcardsParaRevisarProvider(widget.idCategoria))
        .value;
    if (cards == null || _indice >= cards.length) return;

    setState(() => _enviando = true);
    try {
      final perfil = await ref.read(perfilAtualProvider.future);
      if (perfil == null) throw StateError('Sessão indisponível.');
      await ref
          .read(flashcardRepositoryProvider)
          .revisar(
            idUsuario: perfil.id.toString(),
            idFlashcard: cards[_indice].id,
            qualidade: qualidade,
          );
      if (!mounted) return;
      setState(() {
        _indice++;
        _versoVisivel = false;
        _enviando = false;
      });
      ref.invalidate(flashcardsDashboardProvider);
      if (widget.idCategoria != 'todos') {
        ref.invalidate(flashcardCategoriaDetalheProvider(widget.idCategoria));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _enviando = false);
      _mensagem(context, _mensagemErro(error));
    }
  }

  Future<void> _reportar(
    BuildContext context,
    FlashcardsColors colors,
    Flashcard card,
  ) async {
    final idQuestao = card.idQuestao;
    if (idQuestao == null) return;
    final feedback = await showFlashcardFeedbackDialog(
      context,
      colors: colors,
      motivos: StudyAiRepository.motivosFeedback,
    );
    if (feedback == null || !context.mounted) return;

    try {
      await ref
          .read(studyAiRepositoryProvider)
          .enviarFeedback(
            idQuestao: idQuestao,
            tipo: 'flashcard',
            motivo: feedback.motivo,
            relato: feedback.relato,
          );
      if (!context.mounted) return;
      _mensagem(context, 'Obrigado. Seu relato foi enviado.');
    } catch (error) {
      if (!context.mounted) return;
      _mensagem(context, _mensagemErro(error));
    }
  }

  void _sairDaSessao() {
    context.go('/flashcards');
  }
}

class _BarSessao extends StatelessWidget {
  const _BarSessao({
    required this.colors,
    required this.responsive,
    required this.indice,
    required this.total,
    required this.card,
    required this.enviando,
    required this.onSair,
    required this.onReportar,
  });

  final FlashcardsColors colors;
  final Responsive responsive;
  final int indice;
  final int total;
  final Flashcard card;
  final bool enviando;
  final VoidCallback onSair;
  final VoidCallback onReportar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          key: const Key('flashcard-estudo-sair'),
          onPressed: enviando ? null : onSair,
          tooltip: 'Sair da sessão',
          style: IconButton.styleFrom(
            foregroundColor: colors.secondary,
            minimumSize: const Size(48, 48),
          ),
          icon: const Icon(Icons.close_rounded),
        ),
        SizedBox(width: responsive.sp(6)),
        Expanded(
          child: Text(
            'Card ${indice + 1} de $total',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.secondary,
              fontSize: responsive.sp(12),
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        if (card.idQuestao != null)
          IconButton(
            key: const Key('flashcard-estudo-reportar'),
            onPressed: enviando ? null : onReportar,
            tooltip: 'Reportar problema neste flashcard',
            style: IconButton.styleFrom(
              foregroundColor: colors.secondary,
              minimumSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.flag_outlined),
          )
        else
          const SizedBox(width: 48),
      ],
    );
  }
}

class _FlashcardFlipView extends StatelessWidget {
  const _FlashcardFlipView({
    required this.card,
    required this.colors,
    required this.responsive,
    required this.versoVisivel,
    required this.enviando,
    required this.onFlip,
  });

  final Flashcard card;
  final FlashcardsColors colors;
  final Responsive responsive;
  final bool versoVisivel;
  final bool enviando;
  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) {
    final altura = math.max(
      responsive.sp(280),
      math.min(responsive.sp(480), MediaQuery.sizeOf(context).height * 0.44),
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.center,
        children: [...previousChildren, ?currentChild],
      ),
      transitionBuilder: (child, animation) {
        final entering = child.key == ValueKey<bool>(versoVisivel);
        final rotation = animation.drive(
          Tween<double>(
            begin: entering ? math.pi / 2 : 0,
            end: entering ? 0 : -math.pi / 2,
          ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        );
        return AnimatedBuilder(
          animation: rotation,
          builder: (context, _) => Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(rotation.value),
            child: child,
          ),
        );
      },
      child: _FaceFlashcard(
        key: ValueKey<bool>(versoVisivel),
        card: card,
        colors: colors,
        responsive: responsive,
        altura: altura,
        verso: versoVisivel,
        enviando: enviando,
        onTap: onFlip,
      ),
    );
  }
}

class _FaceFlashcard extends StatelessWidget {
  const _FaceFlashcard({
    super.key,
    required this.card,
    required this.colors,
    required this.responsive,
    required this.altura,
    required this.verso,
    required this.enviando,
    required this.onTap,
  });

  final Flashcard card;
  final FlashcardsColors colors;
  final Responsive responsive;
  final double altura;
  final bool verso;
  final bool enviando;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fundo = verso ? colors.accentSoft : colors.card;
    final labelColor = verso ? colors.success : colors.accent;
    final texto = verso ? card.verso : card.frente;
    final label = verso ? 'RESPOSTA' : 'PERGUNTA';
    final hint = verso
        ? 'Avalie como foi lembrar'
        : 'Toque para ver a resposta';

    return Semantics(
      key: Key(verso ? 'flashcard-face-verso' : 'flashcard-face-frente'),
      button: true,
      label: '$label. $texto',
      hint: 'Toque duas vezes para virar o flashcard.',
      child: Material(
        color: fundo,
        borderRadius: BorderRadius.circular(responsive.sp(22)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enviando ? null : onTap,
          child: Container(
            height: altura,
            padding: EdgeInsets.all(responsive.sp(22)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(responsive.sp(22)),
              border: Border.all(color: colors.accentBorder, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      verso
                          ? Icons.lightbulb_outline_rounded
                          : Icons.help_outline_rounded,
                      size: responsive.sp(16),
                      color: labelColor,
                    ),
                    SizedBox(width: responsive.sp(7)),
                    Text(
                      label,
                      style: TextStyle(
                        color: labelColor,
                        fontSize: responsive.sp(10),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.flip_rounded,
                      size: responsive.sp(17),
                      color: colors.muted,
                    ),
                  ],
                ),
                SizedBox(height: responsive.sp(14)),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: FlashcardRichText(
                        key: Key(
                          verso
                              ? 'flashcard-verso-texto'
                              : 'flashcard-frente-texto',
                        ),
                        text: texto,
                        colors: colors,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.text,
                          fontSize: responsive.sp(18),
                          height: 1.55,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: responsive.sp(12)),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: responsive.sp(10.5),
                    fontWeight: FontWeight.w500,
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

class _RevelarButton extends StatelessWidget {
  const _RevelarButton({
    required this.colors,
    required this.responsive,
    required this.onPressed,
  });

  final FlashcardsColors colors;
  final Responsive responsive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: const Key('flashcard-revelar'),
      onPressed: onPressed,
      icon: Icon(Icons.visibility_outlined, size: responsive.sp(17)),
      label: const Text('Revelar resposta'),
      style: FilledButton.styleFrom(
        backgroundColor: colors.accent,
        foregroundColor: Colors.white,
        minimumSize: Size(double.infinity, responsive.sp(48)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(responsive.sp(12)),
        ),
        textStyle: TextStyle(
          fontSize: responsive.sp(12.5),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BotoesQualidade extends StatelessWidget {
  const _BotoesQualidade({
    required this.colors,
    required this.responsive,
    required this.enviando,
    required this.onAvaliar,
  });

  final FlashcardsColors colors;
  final Responsive responsive;
  final bool enviando;
  final ValueChanged<int> onAvaliar;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final colunas = constraints.maxWidth < 560 ? 2 : 4;
        final gap = responsive.sp(8);
        final largura = (constraints.maxWidth - gap * (colunas - 1)) / colunas;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final opcao in _opcoes)
              SizedBox(
                width: largura,
                child: _BotaoQualidade(
                  colors: colors,
                  responsive: responsive,
                  opcao: opcao,
                  enviando: enviando,
                  onTap: () => onAvaliar(opcao.qualidade),
                ),
              ),
          ],
        );
      },
    );
  }

  List<_OpcaoQualidade> get _opcoes => [
    _OpcaoQualidade(
      qualidade: 0,
      titulo: 'ERREI',
      detalhe: 'ESQUECI',
      cor: colors.danger,
      fundo: colors.dangerSoft,
      icon: Icons.close_rounded,
    ),
    _OpcaoQualidade(
      qualidade: 1,
      titulo: 'MÉDIO',
      detalhe: 'DIFÍCIL',
      cor: colors.warning,
      fundo: colors.warningSoft,
      icon: Icons.more_horiz_rounded,
    ),
    _OpcaoQualidade(
      qualidade: 2,
      titulo: 'BOM',
      detalhe: 'RECORDEI',
      cor: colors.accent,
      fundo: colors.accentSoft,
      icon: Icons.check_rounded,
    ),
    _OpcaoQualidade(
      qualidade: 3,
      titulo: 'FÁCIL',
      detalhe: 'NATURAL',
      cor: colors.success,
      fundo: colors.successSoft,
      icon: Icons.done_all_rounded,
    ),
  ];
}

class _OpcaoQualidade {
  const _OpcaoQualidade({
    required this.qualidade,
    required this.titulo,
    required this.detalhe,
    required this.cor,
    required this.fundo,
    required this.icon,
  });

  final int qualidade;
  final String titulo;
  final String detalhe;
  final Color cor;
  final Color fundo;
  final IconData icon;
}

class _BotaoQualidade extends StatelessWidget {
  const _BotaoQualidade({
    required this.colors,
    required this.responsive,
    required this.opcao,
    required this.enviando,
    required this.onTap,
  });

  final FlashcardsColors colors;
  final Responsive responsive;
  final _OpcaoQualidade opcao;
  final bool enviando;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: Key('flashcard-avaliar-${opcao.qualidade}'),
      onPressed: enviando ? null : onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: opcao.fundo,
        foregroundColor: opcao.cor,
        side: BorderSide(color: opcao.cor.withValues(alpha: 0.38)),
        minimumSize: Size(double.infinity, responsive.sp(76)),
        padding: EdgeInsets.symmetric(horizontal: responsive.sp(6)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(responsive.sp(12)),
        ),
      ),
      child: enviando
          ? SizedBox(
              width: responsive.sp(18),
              height: responsive.sp(18),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: opcao.cor,
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  opcao.detalhe,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: responsive.sp(8.5),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.45,
                  ),
                ),
                SizedBox(height: responsive.sp(2)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(opcao.icon, size: responsive.sp(14)),
                    SizedBox(width: responsive.sp(3)),
                    Flexible(
                      child: Text(
                        opcao.titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: responsive.sp(10.5),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _EstadoSessaoVazia extends StatelessWidget {
  const _EstadoSessaoVazia({
    required this.colors,
    required this.responsive,
    required this.onVoltar,
  });

  final FlashcardsColors colors;
  final Responsive responsive;
  final VoidCallback onVoltar;

  @override
  Widget build(BuildContext context) {
    return _EstadoFinalBase(
      colors: colors,
      responsive: responsive,
      chave: const Key('flashcard-estudo-vazio'),
      icone: Icons.check_circle_outline_rounded,
      titulo: 'Tudo revisado por aqui!',
      descricao: 'Você não tem cards para revisar neste momento.',
      progresso: '0 cards',
      botao: 'Voltar ao Início',
      onVoltar: onVoltar,
    );
  }
}

class _SessaoConcluida extends StatelessWidget {
  const _SessaoConcluida({
    required this.colors,
    required this.responsive,
    required this.onVoltar,
  });

  final FlashcardsColors colors;
  final Responsive responsive;
  final VoidCallback onVoltar;

  @override
  Widget build(BuildContext context) {
    return _EstadoFinalBase(
      colors: colors,
      responsive: responsive,
      chave: const Key('flashcard-estudo-concluido'),
      icone: Icons.emoji_events_outlined,
      titulo: 'Sessão Finalizada!',
      descricao: 'Parabéns por concluir seus estudos de hoje.',
      progresso: 'Concluído',
      botao: 'Voltar ao Início',
      onVoltar: onVoltar,
      iconeCor: colors.warning,
    );
  }
}

class _EstadoFinalBase extends StatelessWidget {
  const _EstadoFinalBase({
    required this.colors,
    required this.responsive,
    required this.chave,
    required this.icone,
    required this.titulo,
    required this.descricao,
    required this.progresso,
    required this.botao,
    required this.onVoltar,
    this.iconeCor,
  });

  final FlashcardsColors colors;
  final Responsive responsive;
  final Key chave;
  final IconData icone;
  final String titulo;
  final String descricao;
  final String progresso;
  final String botao;
  final VoidCallback onVoltar;
  final Color? iconeCor;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: responsive.pagePadding.copyWith(bottom: responsive.sp(28)),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: responsive.questionsMaxWidth),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  progresso,
                  style: TextStyle(
                    color: colors.secondary,
                    fontSize: responsive.sp(11.5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(height: responsive.sp(72)),
              FlashcardsPanel(
                key: chave,
                colors: colors,
                padding: EdgeInsets.all(responsive.sp(28)),
                child: Column(
                  children: [
                    Icon(
                      icone,
                      size: responsive.sp(48),
                      color: iconeCor ?? colors.success,
                    ),
                    SizedBox(height: responsive.sp(14)),
                    Text(
                      titulo,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: responsive.sp(20),
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: responsive.sp(8)),
                    Text(
                      descricao,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.secondary,
                        fontSize: responsive.sp(12.5),
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: responsive.sp(20)),
                    FilledButton.icon(
                      key: const Key('flashcard-estudo-voltar-inicio'),
                      onPressed: onVoltar,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: Text(botao),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(48, 48),
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.sp(18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErroSessao extends StatelessWidget {
  const _ErroSessao({
    required this.colors,
    required this.responsive,
    required this.mensagem,
    required this.onTentar,
    required this.onSair,
  });

  final FlashcardsColors colors;
  final Responsive responsive;
  final String mensagem;
  final VoidCallback onTentar;
  final VoidCallback onSair;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: responsive.pagePadding,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: responsive.questionsMaxWidth),
          child: FlashcardsPanel(
            key: const Key('flashcard-estudo-erro'),
            colors: colors,
            padding: EdgeInsets.all(responsive.sp(22)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  color: colors.muted,
                  size: responsive.sp(38),
                ),
                SizedBox(height: responsive.sp(10)),
                Text(
                  'Não foi possível carregar a sessão',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                    fontSize: responsive.sp(15),
                  ),
                ),
                SizedBox(height: responsive.sp(8)),
                Text(
                  mensagem,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.secondary, height: 1.4),
                ),
                SizedBox(height: responsive.sp(16)),
                Wrap(
                  spacing: responsive.sp(8),
                  runSpacing: responsive.sp(8),
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: onSair,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.secondary,
                        minimumSize: const Size(48, 48),
                      ),
                      child: const Text('Sair da Sessão'),
                    ),
                    FilledButton(
                      key: const Key('flashcard-estudo-tentar-novamente'),
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
