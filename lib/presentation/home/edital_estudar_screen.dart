import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/ui/responsive.dart';
import '../../models/edital.dart';
import '../../models/question.dart';
import '../widgets/latex_text.dart';
import '../widgets/question_image.dart';
import 'edital_ui.dart';
import 'simulados_ui.dart';

/// Sessão de questões inéditas do ciclo adaptativo.
class EditalEstudarScreen extends ConsumerStatefulWidget {
  const EditalEstudarScreen({super.key, required this.idEdital});

  final int idEdital;

  @override
  ConsumerState<EditalEstudarScreen> createState() =>
      _EditalEstudarScreenState();
}

class _EditalEstudarScreenState extends ConsumerState<EditalEstudarScreen> {
  String? _letraSelecionada;
  RespostaQuestaoResultado? _resultado;
  var _enviando = false;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final colors = SimuladosColors.of(
      Theme.of(context).brightness == Brightness.dark,
    );
    final sessao = ref.watch(editalSessaoProvider(widget.idEdital));

    return EditalPageShell(
      colors: colors,
      child: sessao.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            key: const Key('edital-estudo-loading'),
            color: colors.accent,
          ),
        ),
        error: (error, _) => EditalErrorState(
          colors: colors,
          title: 'Não foi possível carregar a questão',
          message: editalErrorMessage(error),
          onRetry: () => ref.invalidate(editalSessaoProvider(widget.idEdital)),
          onBack: () => context.go('/editais'),
        ),
        data: (dados) {
          if (dados.concluido || dados.questao == null) {
            return _EditalConcluido(
              colors: colors,
              responsive: responsive,
              onDashboard: () =>
                  context.push('/editais/dashboard/${widget.idEdital}'),
              onVoltar: () => context.go('/editais'),
            );
          }
          return _ConteudoSessaoEdital(
            colors: colors,
            responsive: responsive,
            sessao: dados,
            letraSelecionada: _letraSelecionada,
            resultado: _resultado,
            enviando: _enviando,
            onSelecionar: (letra) => setState(() => _letraSelecionada = letra),
            onResponder: () => _responder(dados),
            onProxima: _proxima,
            onPular: () => _pular(context, dados),
            onVoltar: () => context.go('/editais'),
          );
        },
      ),
    );
  }

  Future<void> _responder(EditalSessaoEstudo sessao) async {
    final questao = sessao.questao;
    final letra = _letraSelecionada;
    if (_enviando || questao == null || letra == null) return;

    setState(() => _enviando = true);
    try {
      final perfil = await ref.read(perfilAtualProvider.future);
      if (perfil == null) throw StateError('Sessão indisponível.');
      final resultado = await ref
          .read(editalRepositoryProvider)
          .responder(
            idEdital: widget.idEdital,
            idUsuario: perfil.id,
            idQuestao: questao.id,
            letra: letra,
          );
      if (!mounted) return;
      setState(() {
        _resultado = resultado;
        _enviando = false;
      });
      ref.invalidate(painelProvider);
      ref.invalidate(estatisticasDetalhadasProvider);
      ref.invalidate(editalPainelProvider(widget.idEdital));
    } catch (error) {
      if (!mounted) return;
      setState(() => _enviando = false);
      showEditalMessage(context, editalErrorMessage(error));
    }
  }

  void _proxima() {
    if (_enviando) return;
    setState(() {
      _letraSelecionada = null;
      _resultado = null;
    });
    ref.invalidate(editalSessaoProvider(widget.idEdital));
  }

  Future<void> _pular(BuildContext context, EditalSessaoEstudo sessao) async {
    if (_enviando) return;
    final colors = SimuladosColors.of(
      Theme.of(context).brightness == Brightness.dark,
    );
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.card,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Pular este assunto?',
          style: TextStyle(color: colors.text, fontWeight: FontWeight.w700),
        ),
        content: Text(
          '“${sessao.nomeTopico}” será marcado como concluído neste ciclo e o sistema escolherá a próxima prioridade.',
          style: TextStyle(color: colors.secondary, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Continuar estudando',
              style: TextStyle(color: colors.secondary),
            ),
          ),
          FilledButton(
            key: const Key('edital-pular-confirmar'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 48),
            ),
            child: const Text('Pular assunto'),
          ),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;

    setState(() => _enviando = true);
    try {
      final perfil = await ref.read(perfilAtualProvider.future);
      if (perfil == null) throw StateError('Sessão indisponível.');
      final avanco = await ref
          .read(editalRepositoryProvider)
          .pular(idEdital: widget.idEdital, idUsuario: perfil.id);
      if (!context.mounted) return;
      setState(() {
        _enviando = false;
        _letraSelecionada = null;
        _resultado = null;
      });
      if (!avanco.sucesso) {
        showEditalMessage(context, avanco.mensagem);
        return;
      }
      ref.invalidate(editalSessaoProvider(widget.idEdital));
      ref.invalidate(editalPainelProvider(widget.idEdital));
      showEditalMessage(context, avanco.mensagem);
    } catch (error) {
      if (!context.mounted) return;
      setState(() => _enviando = false);
      showEditalMessage(context, editalErrorMessage(error));
    }
  }
}

class _ConteudoSessaoEdital extends StatelessWidget {
  const _ConteudoSessaoEdital({
    required this.colors,
    required this.responsive,
    required this.sessao,
    required this.letraSelecionada,
    required this.resultado,
    required this.enviando,
    required this.onSelecionar,
    required this.onResponder,
    required this.onProxima,
    required this.onPular,
    required this.onVoltar,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final EditalSessaoEstudo sessao;
  final String? letraSelecionada;
  final RespostaQuestaoResultado? resultado;
  final bool enviando;
  final ValueChanged<String> onSelecionar;
  final VoidCallback onResponder;
  final VoidCallback onProxima;
  final VoidCallback onPular;
  final VoidCallback onVoltar;

  @override
  Widget build(BuildContext context) {
    final questao = sessao.questao!;
    final progresso = sessao.meta <= 0
        ? 0.0
        : (sessao.feitas / sessao.meta).clamp(0.0, 1.0);
    return SingleChildScrollView(
      key: const Key('edital-estudo-scroll'),
      padding: responsive.pagePadding.copyWith(bottom: responsive.sp(28)),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: responsive.questionsMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CabecalhoCiclo(
                colors: colors,
                responsive: responsive,
                sessao: sessao,
                progresso: progresso,
                enviando: enviando,
                onPular: onPular,
                onVoltar: onVoltar,
              ),
              SizedBox(height: responsive.sp(14)),
              _QuestaoEditalCard(
                key: Key('edital-questao-${questao.id}'),
                colors: colors,
                responsive: responsive,
                questao: questao,
                letraSelecionada: letraSelecionada,
                resultado: resultado,
                onSelecionar: onSelecionar,
              ),
              SizedBox(height: responsive.sp(14)),
              if (resultado == null)
                FilledButton.icon(
                  key: const Key('edital-responder'),
                  onPressed: letraSelecionada == null || enviando
                      ? null
                      : onResponder,
                  icon: enviando
                      ? SizedBox(
                          width: responsive.sp(16),
                          height: responsive.sp(16),
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          Icons.check_circle_outline_rounded,
                          size: responsive.sp(17),
                        ),
                  label: Text(
                    enviando ? 'Corrigindo...' : 'Responder e Avançar',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, responsive.sp(48)),
                    textStyle: TextStyle(
                      fontSize: responsive.sp(12),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                FilledButton.icon(
                  key: const Key('edital-proxima'),
                  onPressed: enviando ? null : onProxima,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Próxima Questão do Ciclo'),
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
              if (resultado == null) ...[
                SizedBox(height: responsive.sp(9)),
                Center(
                  child: TextButton.icon(
                    key: const Key('edital-pular'),
                    onPressed: enviando ? null : onPular,
                    icon: const Icon(Icons.skip_next_rounded),
                    label: const Text('Pular para o próximo assunto'),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.secondary,
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                ),
              ],
              SizedBox(height: responsive.sp(18)),
              SimuladosFooter(colors: colors, responsive: responsive),
            ],
          ),
        ),
      ),
    );
  }
}

class _CabecalhoCiclo extends StatelessWidget {
  const _CabecalhoCiclo({
    required this.colors,
    required this.responsive,
    required this.sessao,
    required this.progresso,
    required this.enviando,
    required this.onPular,
    required this.onVoltar,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final EditalSessaoEstudo sessao;
  final double progresso;
  final bool enviando;
  final VoidCallback onPular;
  final VoidCallback onVoltar;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(responsive.sp(15)),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: colors.isDark
            ? const [Color(0xFF3730A3), Color(0xFF4F46E5)]
            : const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
      ),
      borderRadius: BorderRadius.circular(responsive.sp(16)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              key: const Key('edital-estudo-voltar'),
              onPressed: onVoltar,
              tooltip: 'Voltar aos editais',
              style: IconButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
              ),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            SizedBox(width: responsive.sp(4)),
            Expanded(
              child: Text(
                'Ciclo Ativo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: responsive.sp(10),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            IconButton(
              key: const Key('edital-estudo-pular-header'),
              onPressed: enviando ? null : onPular,
              tooltip: 'Pular assunto',
              style: IconButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
              ),
              icon: const Icon(Icons.skip_next_rounded),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: responsive.sp(6)),
          child: Text(
            sessao.nomeMateria,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: responsive.sp(18),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(height: responsive.sp(3)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: responsive.sp(6)),
          child: Text(
            'Assunto: ${sessao.nomeTopico}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: responsive.sp(11),
            ),
          ),
        ),
        SizedBox(height: responsive.sp(12)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: responsive.sp(6)),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Meta do tópico',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: responsive.sp(9.5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${sessao.feitas} / ${sessao.meta} questões',
                key: const Key('edital-meta-progresso'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: responsive.sp(10),
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: responsive.sp(6)),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progresso,
            minHeight: responsive.sp(6),
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            color: colors.private,
          ),
        ),
      ],
    ),
  );
}

class _QuestaoEditalCard extends StatelessWidget {
  const _QuestaoEditalCard({
    super.key,
    required this.colors,
    required this.responsive,
    required this.questao,
    required this.letraSelecionada,
    required this.resultado,
    required this.onSelecionar,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final Questao questao;
  final String? letraSelecionada;
  final RespostaQuestaoResultado? resultado;
  final ValueChanged<String> onSelecionar;

  @override
  Widget build(BuildContext context) {
    final enunciado = _textoSemHtml(questao.enunciado);
    final textoBase = _textoSemHtml(questao.textoBase ?? '');
    final imagens = QuestionImage.extrair(
      urlImagem: questao.urlImagem,
      html: '',
    );
    return SimuladoPanel(
      key: const Key('edital-questao-card'),
      colors: colors,
      radius: responsive.sp(16),
      padding: EdgeInsets.all(responsive.sp(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: responsive.sp(6),
            runSpacing: responsive.sp(5),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Questão #${questao.id}',
                style: TextStyle(
                  color: colors.text,
                  fontSize: responsive.sp(12),
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (questao.nomeMateria?.isNotEmpty ?? false)
                _QuestaoTag(colors: colors, label: questao.nomeMateria!),
              if (questao.nomeTopico?.isNotEmpty ?? false)
                _QuestaoTag(colors: colors, label: questao.nomeTopico!),
              if (questao.nomeBanca?.isNotEmpty ?? false)
                _QuestaoTag(colors: colors, label: questao.nomeBanca!),
              if (questao.ano != null)
                _QuestaoTag(colors: colors, label: '${questao.ano}'),
            ],
          ),
          if (textoBase.isNotEmpty) ...[
            SizedBox(height: responsive.sp(10)),
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
                  fontSize: responsive.sp(10.5),
                  height: 1.45,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          if (imagens.isNotEmpty) ...[
            SizedBox(height: responsive.sp(10)),
            for (final url in imagens)
              QuestionImage(
                key: ValueKey('edital-imagem-${questao.id}-$url'),
                source: url,
              ),
          ],
          SizedBox(height: responsive.sp(11)),
          LatexText(
            enunciado.isEmpty ? 'Enunciado indisponível.' : enunciado,
            style: TextStyle(
              color: colors.text,
              fontSize: responsive.sp(12.5),
              height: 1.55,
            ),
          ),
          SizedBox(height: responsive.sp(13)),
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
                child: _AlternativaEdital(
                  colors: colors,
                  responsive: responsive,
                  alternativa: alternativa,
                  selecionada: alternativa.letra == letraSelecionada,
                  resultado: resultado,
                  onTap: resultado == null
                      ? () => onSelecionar(alternativa.letra)
                      : null,
                ),
              ),
          if (resultado != null) ...[
            SizedBox(height: responsive.sp(5)),
            _FeedbackEdital(
              colors: colors,
              responsive: responsive,
              resultado: resultado!,
            ),
          ],
        ],
      ),
    );
  }
}

class _QuestaoTag extends StatelessWidget {
  const _QuestaoTag({required this.colors, required this.label});

  final SimuladosColors colors;
  final String label;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return Container(
      constraints: BoxConstraints(maxWidth: responsive.sp(180)),
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
          fontSize: responsive.sp(8.5),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AlternativaEdital extends StatelessWidget {
  const _AlternativaEdital({
    required this.colors,
    required this.responsive,
    required this.alternativa,
    required this.selecionada,
    required this.resultado,
    required this.onTap,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final Alternativa alternativa;
  final bool selecionada;
  final RespostaQuestaoResultado? resultado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final correta = resultado?.letraCorreta == alternativa.letra;
    final errada =
        resultado != null &&
        selecionada &&
        resultado!.letraCorreta != alternativa.letra;
    final borderColor = correta
        ? colors.success
        : errada
        ? colors.danger
        : selecionada
        ? colors.accent
        : colors.border;
    final fillColor = correta
        ? colors.successSoft
        : errada
        ? colors.dangerSoft
        : selecionada
        ? colors.accentSoft
        : colors.cardSoft;
    return Material(
      color: fillColor,
      borderRadius: BorderRadius.circular(responsive.sp(11)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key(
          'edital-alternativa-${alternativa.idQuestao}-${alternativa.letra}',
        ),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(responsive.sp(9)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(responsive.sp(11)),
            border: Border.all(
              color: borderColor,
              width: selecionada ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: responsive.sp(28),
                height: responsive.sp(28),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selecionada || correta ? borderColor : colors.card,
                  borderRadius: BorderRadius.circular(responsive.sp(8)),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  alternativa.letra,
                  style: TextStyle(
                    color: selecionada || correta
                        ? Colors.white
                        : colors.secondary,
                    fontSize: responsive.sp(10.5),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(width: responsive.sp(8)),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: responsive.sp(4)),
                  child: LatexText(
                    _textoSemHtml(alternativa.texto),
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
              if (correta)
                Padding(
                  padding: EdgeInsets.only(
                    left: responsive.sp(4),
                    top: responsive.sp(4),
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: responsive.sp(16),
                    color: colors.success,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackEdital extends StatelessWidget {
  const _FeedbackEdital({
    required this.colors,
    required this.responsive,
    required this.resultado,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final RespostaQuestaoResultado resultado;

  @override
  Widget build(BuildContext context) {
    final cor = resultado.correta ? colors.success : colors.danger;
    final fundo = resultado.correta ? colors.successSoft : colors.dangerSoft;
    return Container(
      key: const Key('edital-feedback-resposta'),
      padding: EdgeInsets.all(responsive.sp(11)),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(responsive.sp(10)),
        border: Border.all(color: cor.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            resultado.correta
                ? Icons.check_circle_rounded
                : Icons.cancel_rounded,
            color: cor,
            size: responsive.sp(17),
          ),
          SizedBox(width: responsive.sp(7)),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  color: colors.text,
                  fontSize: responsive.sp(10.5),
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: resultado.correta
                        ? 'Resposta correta. '
                        : 'Resposta incorreta. ',
                    style: TextStyle(color: cor, fontWeight: FontWeight.w800),
                  ),
                  if (resultado.letraCorreta != null)
                    TextSpan(text: 'Gabarito: ${resultado.letraCorreta}. '),
                  if (resultado.comentario.trim().isNotEmpty)
                    TextSpan(text: resultado.comentario),
                  if (resultado.cicloAvancou &&
                      resultado.mensagemAvanco.isNotEmpty)
                    TextSpan(text: '\n${resultado.mensagemAvanco}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditalConcluido extends StatelessWidget {
  const _EditalConcluido({
    required this.colors,
    required this.responsive,
    required this.onDashboard,
    required this.onVoltar,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final VoidCallback onDashboard;
  final VoidCallback onVoltar;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: responsive.pagePadding,
      child: SimuladoPanel(
        key: const Key('edital-ciclo-concluido'),
        colors: colors,
        padding: EdgeInsets.all(responsive.sp(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: responsive.sp(70),
              height: responsive.sp(70),
              decoration: BoxDecoration(
                color: colors.successSoft,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.celebration_rounded,
                color: colors.success,
                size: responsive.sp(34),
              ),
            ),
            SizedBox(height: responsive.sp(14)),
            Text(
              'Edital concluído!',
              style: TextStyle(
                color: colors.text,
                fontSize: responsive.sp(18),
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: responsive.sp(6)),
            Text(
              'Você finalizou os assuntos deste ciclo. Confira seu desempenho ou volte para seus editais.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.secondary,
                fontSize: responsive.sp(11),
                height: 1.45,
              ),
            ),
            SizedBox(height: responsive.sp(15)),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: responsive.sp(8),
              runSpacing: responsive.sp(8),
              children: [
                OutlinedButton(
                  onPressed: onVoltar,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.secondary,
                    minimumSize: const Size(48, 48),
                  ),
                  child: const Text('Meus editais'),
                ),
                FilledButton.icon(
                  onPressed: onDashboard,
                  icon: const Icon(Icons.bar_chart_rounded),
                  label: const Text('Ver desempenho'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(48, 48),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

String _textoSemHtml(String html) => LatexText.limparHtml(html);
