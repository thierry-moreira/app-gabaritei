import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_exception.dart';
import '../../core/providers.dart';
import '../../core/ui/responsive.dart';
import '../../models/question.dart';
import '../../models/simulado.dart';
import '../widgets/latex_text.dart';
import '../widgets/question_image.dart';
import 'simulados_ui.dart';

/// Sessão de prova completa com cronômetro e correção no envio.
class SimuladoFazerScreen extends ConsumerStatefulWidget {
  const SimuladoFazerScreen({super.key, required this.idSimulado});

  final String idSimulado;

  @override
  ConsumerState<SimuladoFazerScreen> createState() =>
      _SimuladoFazerScreenState();
}

class _SimuladoFazerScreenState extends ConsumerState<SimuladoFazerScreen> {
  final _cronometro = Stopwatch();
  Timer? _timer;
  final Map<int, String?> _respostas = {};
  var _segundos = 0;
  var _enviando = false;

  @override
  void initState() {
    super.initState();
    _cronometro.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _segundos = _cronometro.elapsed.inSeconds);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cronometro.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final colors = SimuladosColors.of(
      Theme.of(context).brightness == Brightness.dark,
    );
    final sessao = ref.watch(simuladoSessaoProvider(widget.idSimulado));

    return SimuladoPageShell(
      colors: colors,
      child: sessao.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            key: const Key('simulado-fazer-loading'),
            color: colors.accent,
          ),
        ),
        error: (error, _) => _ErroSessao(
          colors: colors,
          responsive: responsive,
          message: _mensagemErro(error),
          onVoltar: () => context.go('/simulados'),
          onTentar: () =>
              ref.invalidate(simuladoSessaoProvider(widget.idSimulado)),
        ),
        data: (dados) => _ConteudoProva(
          colors: colors,
          responsive: responsive,
          dados: dados,
          respostas: _respostas,
          segundos: _segundos,
          enviando: _enviando,
          onResposta: (idQuestao, letra) =>
              setState(() => _respostas[idQuestao] = letra),
          onEntregar: () => _entregar(context, dados),
          onSair: () => context.go('/simulados'),
        ),
      ),
    );
  }

  Future<void> _entregar(
    BuildContext context,
    SimuladoComQuestoes dados,
  ) async {
    if (_enviando) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Entregar simulado?'),
        content: Text(
          'Você respondeu ${_respostas.values.whereType<String>().length} '
          'de ${dados.questoes.length} questões. A nota será calculada com '
          'as marcações atuais.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Continuar revisando'),
          ),
          FilledButton(
            key: const Key('simulado-entregar-confirmar'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Entregar prova'),
          ),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;

    setState(() => _enviando = true);
    try {
      final perfil = await ref.read(perfilAtualProvider.future);
      if (perfil == null) throw StateError('Sessão indisponível.');
      final resultado = await ref
          .read(simuladoRepositoryProvider)
          .corrigir(
            idSimulado: widget.idSimulado,
            idUsuario: perfil.id,
            respostas: {
              for (final questao in dados.questoes)
                questao.id: _respostas[questao.id],
            },
          );
      if (!context.mounted) return;
      ref.invalidate(simuladosProvider);
      context.push(
        '/simulados/resultado/${widget.idSimulado}',
        extra: SimuladoResultadoArgs(
          simulado: dados.simulado,
          resultado: resultado,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      setState(() => _enviando = false);
      showSimuladosMessage(context, _mensagemErro(error));
    }
  }
}

class _ConteudoProva extends StatelessWidget {
  const _ConteudoProva({
    required this.colors,
    required this.responsive,
    required this.dados,
    required this.respostas,
    required this.segundos,
    required this.enviando,
    required this.onResposta,
    required this.onEntregar,
    required this.onSair,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final SimuladoComQuestoes dados;
  final Map<int, String?> respostas;
  final int segundos;
  final bool enviando;
  final void Function(int idQuestao, String letra) onResposta;
  final VoidCallback onEntregar;
  final VoidCallback onSair;

  @override
  Widget build(BuildContext context) {
    final respondidas = respostas.values.whereType<String>().length;
    return SingleChildScrollView(
      key: const Key('simulado-fazer-scroll'),
      padding: responsive.pagePadding.copyWith(bottom: responsive.sp(28)),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: responsive.questionsMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SimuladoPanel(
                colors: colors,
                radius: responsive.sp(16),
                padding: EdgeInsets.all(responsive.sp(16)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dados.simulado.titulo,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.text,
                              fontSize: responsive.sp(16),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: responsive.sp(5)),
                          Text(
                            '${dados.questoes.length} questões · $respondidas respondidas',
                            style: TextStyle(
                              color: colors.secondary,
                              fontSize: responsive.sp(10.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: responsive.sp(8)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: responsive.sp(10),
                        vertical: responsive.sp(8),
                      ),
                      decoration: BoxDecoration(
                        color: colors.cardSoft,
                        borderRadius: BorderRadius.circular(responsive.sp(10)),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: responsive.sp(15),
                            color: colors.accent,
                          ),
                          SizedBox(width: responsive.sp(5)),
                          Text(
                            _formatarTempo(segundos),
                            key: const Key('simulado-cronometro'),
                            style: TextStyle(
                              color: colors.text,
                              fontSize: responsive.sp(10.5),
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: responsive.sp(14)),
              for (var i = 0; i < dados.questoes.length; i++) ...[
                _QuestaoProvaCard(
                  key: Key('simulado-questao-${dados.questoes[i].id}'),
                  colors: colors,
                  responsive: responsive,
                  questao: dados.questoes[i],
                  numero: i + 1,
                  selecionada: respostas[dados.questoes[i].id],
                  onResposta: (letra) =>
                      onResposta(dados.questoes[i].id, letra),
                ),
                if (i < dados.questoes.length - 1)
                  SizedBox(height: responsive.sp(12)),
              ],
              SizedBox(height: responsive.sp(14)),
              SimuladoPanel(
                colors: colors,
                radius: responsive.sp(16),
                padding: EdgeInsets.all(responsive.sp(18)),
                child: Column(
                  children: [
                    Text(
                      'Terminou a prova?',
                      style: TextStyle(
                        color: colors.text,
                        fontSize: responsive.sp(15),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: responsive.sp(5)),
                    Text(
                      'Revise suas marcações antes de entregar. A nota será calculada ao finalizar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.secondary,
                        fontSize: responsive.sp(11),
                        height: 1.45,
                      ),
                    ),
                    SizedBox(height: responsive.sp(14)),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            key: const Key('simulado-fazer-sair'),
                            onPressed: enviando ? null : onSair,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colors.secondary,
                              side: BorderSide(color: colors.border),
                              minimumSize: const Size(48, 48),
                            ),
                            child: const Text('Sair'),
                          ),
                        ),
                        SizedBox(width: responsive.sp(9)),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            key: const Key('simulado-entregar'),
                            onPressed: enviando ? null : onEntregar,
                            icon: enviando
                                ? SizedBox(
                                    width: responsive.sp(17),
                                    height: responsive.sp(17),
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.check_circle_outline_rounded,
                                  ),
                            label: Text(
                              enviando
                                  ? 'Corrigindo...'
                                  : 'Entregar e Ver Nota',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: colors.success,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(48, 48),
                              textStyle: TextStyle(
                                fontSize: responsive.sp(11),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
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

class _QuestaoProvaCard extends StatelessWidget {
  const _QuestaoProvaCard({
    super.key,
    required this.colors,
    required this.responsive,
    required this.questao,
    required this.numero,
    required this.selecionada,
    required this.onResposta,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final Questao questao;
  final int numero;
  final String? selecionada;
  final ValueChanged<String> onResposta;

  @override
  Widget build(BuildContext context) {
    final enunciado = _htmlParaTexto(questao.enunciado);
    final textoBase = _htmlParaTexto(questao.textoBase ?? '');
    final imagens = QuestionImage.extrair(
      urlImagem: questao.urlImagem,
      html: '',
    );
    return SimuladoPanel(
      colors: colors,
      radius: responsive.sp(16),
      padding: EdgeInsets.all(responsive.sp(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: responsive.sp(7),
            runSpacing: responsive.sp(5),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Questão ${numero.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: colors.accent,
                  fontSize: responsive.sp(11),
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (questao.nomeMateria?.isNotEmpty ?? false)
                _MetaChip(colors: colors, label: questao.nomeMateria!),
              if (questao.nomeBanca?.isNotEmpty ?? false)
                _MetaChip(colors: colors, label: questao.nomeBanca!),
              if (questao.ano != null)
                _MetaChip(colors: colors, label: '${questao.ano}'),
            ],
          ),
          if (textoBase.isNotEmpty) ...[
            SizedBox(height: responsive.sp(9)),
            Container(
              padding: EdgeInsets.all(responsive.sp(10)),
              decoration: BoxDecoration(
                color: colors.cardSoft,
                borderRadius: BorderRadius.circular(responsive.sp(10)),
                border: Border.all(color: colors.border),
              ),
              child: LatexText(
                textoBase,
                style: TextStyle(
                  color: colors.secondary,
                  fontSize: responsive.sp(11),
                  height: 1.45,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          for (final url in imagens)
            QuestionImage(
              key: ValueKey('simulado-imagem-${questao.id}-$url'),
              source: url,
            ),
          SizedBox(height: responsive.sp(10)),
          LatexText(
            enunciado.isEmpty ? 'Enunciado indisponível.' : enunciado,
            style: TextStyle(
              color: colors.text,
              fontSize: responsive.sp(12.5),
              height: 1.55,
            ),
          ),
          SizedBox(height: responsive.sp(12)),
          if (questao.alternativas.isEmpty)
            Text(
              'Questão discursiva: não há alternativas para marcar.',
              style: TextStyle(
                color: colors.secondary,
                fontSize: responsive.sp(11),
              ),
            )
          else
            for (final alternativa in questao.alternativas)
              Padding(
                padding: EdgeInsets.only(bottom: responsive.sp(7)),
                child: _AlternativaProva(
                  colors: colors,
                  responsive: responsive,
                  alternativa: alternativa,
                  selecionada: alternativa.letra == selecionada,
                  onTap: () => onResposta(alternativa.letra),
                ),
              ),
        ],
      ),
    );
  }
}

class _AlternativaProva extends StatelessWidget {
  const _AlternativaProva({
    required this.colors,
    required this.responsive,
    required this.alternativa,
    required this.selecionada,
    required this.onTap,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final Alternativa alternativa;
  final bool selecionada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final corBorda = selecionada ? colors.accent : colors.border;
    final fundo = selecionada ? colors.accentSoft : colors.cardSoft;
    return Material(
      color: fundo,
      borderRadius: BorderRadius.circular(responsive.sp(11)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key(
          'simulado-alternativa-${alternativa.idQuestao}-${alternativa.letra}',
        ),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: responsive.sp(10),
            vertical: responsive.sp(9),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(responsive.sp(11)),
            border: Border.all(color: corBorda, width: selecionada ? 1.6 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: responsive.sp(28),
                height: responsive.sp(28),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selecionada ? colors.accent : colors.card,
                  borderRadius: BorderRadius.circular(responsive.sp(8)),
                  border: Border.all(color: corBorda),
                ),
                child: Text(
                  alternativa.letra,
                  style: TextStyle(
                    color: selecionada ? Colors.white : colors.secondary,
                    fontSize: responsive.sp(11),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(width: responsive.sp(9)),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: responsive.sp(4)),
                  child: LatexText(
                    _htmlParaTexto(alternativa.texto),
                    style: TextStyle(
                      color: colors.text,
                      fontSize: responsive.sp(11.5),
                      height: 1.4,
                      fontWeight: selecionada
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
              if (selecionada)
                Padding(
                  padding: EdgeInsets.only(
                    left: responsive.sp(5),
                    top: responsive.sp(5),
                  ),
                  child: Icon(
                    Icons.radio_button_checked_rounded,
                    size: responsive.sp(16),
                    color: colors.accent,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.colors, required this.label});

  final SimuladosColors colors;
  final String label;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return Container(
      constraints: BoxConstraints(maxWidth: responsive.sp(190)),
      padding: EdgeInsets.symmetric(
        horizontal: responsive.sp(7),
        vertical: responsive.sp(3),
      ),
      decoration: BoxDecoration(
        color: colors.cardSoft,
        borderRadius: BorderRadius.circular(responsive.sp(6)),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colors.secondary,
          fontSize: responsive.sp(9),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ErroSessao extends StatelessWidget {
  const _ErroSessao({
    required this.colors,
    required this.responsive,
    required this.message,
    required this.onVoltar,
    required this.onTentar,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final String message;
  final VoidCallback onVoltar;
  final VoidCallback onTentar;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: responsive.pagePadding,
      child: SimuladoPanel(
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
              'Não foi possível carregar a prova',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.text,
                fontSize: responsive.sp(15),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: responsive.sp(7)),
            Text(message, textAlign: TextAlign.center),
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

String _formatarTempo(int segundos) {
  final horas = (segundos ~/ 3600).toString().padLeft(2, '0');
  final minutos = ((segundos % 3600) ~/ 60).toString().padLeft(2, '0');
  final resto = (segundos % 60).toString().padLeft(2, '0');
  return '$horas:$minutos:$resto';
}

String _htmlParaTexto(String html) => LatexText.limparHtml(html);

String _mensagemErro(Object? error) {
  if (error is AppException) return error.message;
  if (error is StateError) {
    return 'Sua sessão não está disponível. Entre novamente.';
  }
  return 'Não foi possível concluir a prova. Tente novamente.';
}
