import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/ui/responsive.dart';
import '../../models/simulado.dart';
import 'simulados_ui.dart';

class SimuladoResultadoScreen extends ConsumerStatefulWidget {
  const SimuladoResultadoScreen({super.key, required this.args});

  final SimuladoResultadoArgs? args;

  @override
  ConsumerState<SimuladoResultadoScreen> createState() =>
      _SimuladoResultadoScreenState();
}

class _SimuladoResultadoScreenState
    extends ConsumerState<SimuladoResultadoScreen> {
  var _imprimindoResultado = false;
  var _imprimindoProva = false;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final colors = SimuladosColors.of(
      Theme.of(context).brightness == Brightness.dark,
    );
    final args = widget.args;
    return SimuladoPageShell(
      colors: colors,
      child: args == null
          ? _ResultadoIndisponivel(
              colors: colors,
              responsive: responsive,
              onVoltar: () => context.go('/simulados'),
            )
          : _ConteudoResultado(
              colors: colors,
              responsive: responsive,
              args: args,
              imprimindoResultado: _imprimindoResultado,
              imprimindoProva: _imprimindoProva,
              onVoltar: () => context.go('/simulados'),
              onRanking: () =>
                  context.push('/simulados/ranking/${args.simulado.id}'),
              onImprimirResultado: () => _imprimirResultado(context, args),
              onImprimirProva: () => _imprimirProva(context, args.simulado),
            ),
    );
  }

  Future<void> _imprimirResultado(
    BuildContext context,
    SimuladoResultadoArgs args,
  ) async {
    if (_imprimindoResultado) return;
    setState(() => _imprimindoResultado = true);
    try {
      final impresso = await ref
          .read(simuladoPrintServiceProvider)
          .imprimirResultado(args);
      if (!context.mounted) return;
      if (impresso) {
        showSimuladosMessage(context, 'Resultado enviado à impressão.');
      }
    } catch (error) {
      if (!context.mounted) return;
      showSimuladosMessage(context, simuladosErrorMessage(error));
    } finally {
      if (mounted) setState(() => _imprimindoResultado = false);
    }
  }

  Future<void> _imprimirProva(BuildContext context, Simulado simulado) async {
    if (_imprimindoProva) return;
    setState(() => _imprimindoProva = true);
    try {
      final perfil = await ref.read(perfilAtualProvider.future);
      if (perfil == null) throw StateError('Sessão indisponível.');
      final dados = await ref
          .read(simuladoRepositoryProvider)
          .dadosPdf(idSimulado: simulado.id, idUsuario: perfil.id);
      if (!context.mounted) return;
      final impresso = await ref
          .read(simuladoPrintServiceProvider)
          .imprimir(dados);
      if (!context.mounted) return;
      if (impresso) showSimuladosMessage(context, 'Prova enviada à impressão.');
    } catch (error) {
      if (!context.mounted) return;
      showSimuladosMessage(context, simuladosErrorMessage(error));
    } finally {
      if (mounted) setState(() => _imprimindoProva = false);
    }
  }
}

class _ConteudoResultado extends StatelessWidget {
  const _ConteudoResultado({
    required this.colors,
    required this.responsive,
    required this.args,
    required this.imprimindoResultado,
    required this.imprimindoProva,
    required this.onVoltar,
    required this.onRanking,
    required this.onImprimirResultado,
    required this.onImprimirProva,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final SimuladoResultadoArgs args;
  final bool imprimindoResultado;
  final bool imprimindoProva;
  final VoidCallback onVoltar;
  final VoidCallback onRanking;
  final VoidCallback onImprimirResultado;
  final VoidCallback onImprimirProva;

  @override
  Widget build(BuildContext context) {
    final resultado = args.resultado;
    final notaColor = resultado.nota >= 7 ? colors.success : colors.danger;
    return SingleChildScrollView(
      padding: responsive.pagePadding.copyWith(bottom: responsive.sp(28)),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: responsive.questionsMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SimuladoPanel(
                key: const Key('simulado-resultado-card'),
                colors: colors,
                radius: responsive.sp(20),
                padding: EdgeInsets.all(responsive.sp(22)),
                child: Column(
                  children: [
                    Text(
                      'Resultado do Simulado',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: responsive.sp(19),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: responsive.sp(5)),
                    Text(
                      args.simulado.titulo,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.secondary,
                        fontSize: responsive.sp(11.5),
                      ),
                    ),
                    SizedBox(height: responsive.sp(20)),
                    Text(
                      resultado.nota.toStringAsFixed(2),
                      key: const Key('simulado-resultado-nota'),
                      style: TextStyle(
                        color: notaColor,
                        fontSize: responsive.sp(48),
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    SizedBox(height: responsive.sp(4)),
                    Text(
                      'Sua nota final de 0 a 10',
                      style: TextStyle(
                        color: colors.secondary,
                        fontSize: responsive.sp(11),
                      ),
                    ),
                    SizedBox(height: responsive.sp(18)),
                    Row(
                      children: [
                        Expanded(
                          child: _EstatisticaResultado(
                            colors: colors,
                            responsive: responsive,
                            valor: '${resultado.acertos}',
                            rotulo: 'ACERTOS',
                            cor: colors.success,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: responsive.sp(48),
                          color: colors.border,
                        ),
                        Expanded(
                          child: _EstatisticaResultado(
                            colors: colors,
                            responsive: responsive,
                            valor: '${resultado.total - resultado.acertos}',
                            rotulo: 'ERROS',
                            cor: colors.danger,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: responsive.sp(20)),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: responsive.sp(8),
                      runSpacing: responsive.sp(8),
                      children: [
                        OutlinedButton.icon(
                          onPressed: onVoltar,
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Voltar para Simulados'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.accent,
                            side: BorderSide(color: colors.accentBorder),
                            minimumSize: const Size(48, 48),
                          ),
                        ),
                        OutlinedButton.icon(
                          key: const Key('simulado-imprimir-resultado'),
                          onPressed: imprimindoResultado
                              ? null
                              : onImprimirResultado,
                          icon: imprimindoResultado
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.print_outlined),
                          label: const Text('Imprimir Resultado'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.secondary,
                            side: BorderSide(color: colors.border),
                            minimumSize: const Size(48, 48),
                          ),
                        ),
                        FilledButton.icon(
                          key: const Key('simulado-imprimir-prova'),
                          onPressed: imprimindoProva ? null : onImprimirProva,
                          icon: imprimindoProva
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('Ver PDF da Prova'),
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
              if (resultado.ranking.isNotEmpty) ...[
                SizedBox(height: responsive.sp(20)),
                _RankingResumo(
                  colors: colors,
                  responsive: responsive,
                  args: args,
                  onAbrir: onRanking,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EstatisticaResultado extends StatelessWidget {
  const _EstatisticaResultado({
    required this.colors,
    required this.responsive,
    required this.valor,
    required this.rotulo,
    required this.cor,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final String valor;
  final String rotulo;
  final Color cor;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        valor,
        style: TextStyle(
          color: cor,
          fontSize: responsive.sp(22),
          fontWeight: FontWeight.w800,
        ),
      ),
      Text(
        rotulo,
        style: TextStyle(
          color: colors.secondary,
          fontSize: responsive.sp(9),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
        ),
      ),
    ],
  );
}

class _RankingResumo extends StatelessWidget {
  const _RankingResumo({
    required this.colors,
    required this.responsive,
    required this.args,
    required this.onAbrir,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final SimuladoResultadoArgs args;
  final VoidCallback onAbrir;

  @override
  Widget build(BuildContext context) {
    final ranking = args.resultado.ranking.take(10).toList(growable: false);
    return SimuladoPanel(
      colors: colors,
      padding: EdgeInsets.all(responsive.sp(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_outlined, color: colors.private),
              SizedBox(width: responsive.sp(7)),
              Expanded(
                child: Text(
                  'Ranking Global do Simulado',
                  style: TextStyle(
                    color: colors.text,
                    fontSize: responsive.sp(13),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(onPressed: onAbrir, child: const Text('Ver ranking')),
            ],
          ),
          for (var i = 0; i < ranking.length; i++)
            Padding(
              padding: EdgeInsets.symmetric(vertical: responsive.sp(6)),
              child: Row(
                children: [
                  SizedBox(
                    width: responsive.sp(28),
                    child: Text(
                      '${i + 1}º',
                      style: TextStyle(
                        color: i < 3 ? colors.private : colors.secondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      ranking[i].nomeUsuario,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.text),
                    ),
                  ),
                  Text(
                    ranking[i].nota.toStringAsFixed(2),
                    style: TextStyle(
                      color: ranking[i].nota >= 7
                          ? colors.success
                          : colors.danger,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultadoIndisponivel extends StatelessWidget {
  const _ResultadoIndisponivel({
    required this.colors,
    required this.responsive,
    required this.onVoltar,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final VoidCallback onVoltar;

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
            Text(
              'Resultado indisponível',
              style: TextStyle(
                color: colors.text,
                fontSize: responsive.sp(16),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: responsive.sp(8)),
            Text(
              'A sessão expirou ou o resultado não está mais disponível.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.secondary),
            ),
            SizedBox(height: responsive.sp(14)),
            FilledButton(
              onPressed: onVoltar,
              child: const Text('Voltar para Simulados'),
            ),
          ],
        ),
      ),
    ),
  );
}
