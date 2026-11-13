import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/ui/responsive.dart';
import '../../models/simulado.dart';
import 'simulado_generator_sheet.dart';
import 'simulados_ui.dart';

/// Central de simulados: feed público da comunidade e simulados privados.
class SimuladosScreen extends ConsumerWidget {
  const SimuladosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responsive = Responsive.of(context);
    final colors = SimuladosColors.of(
      Theme.of(context).brightness == Brightness.dark,
    );
    final simulados = ref.watch(simuladosProvider);

    return SimuladoPageShell(
      colors: colors,
      child: RefreshIndicator(
        key: const Key('simulados-refresh'),
        color: colors.accent,
        backgroundColor: colors.card,
        onRefresh: () async {
          ref.invalidate(simuladosProvider);
          try {
            await ref.read(simuladosProvider.future);
          } catch (_) {
            // O estado de erro é exibido dentro do conteúdo.
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
                  _CabecalhoSimulados(
                    colors: colors,
                    responsive: responsive,
                    onCriar: () => _abrirGerador(context, ref, colors),
                  ),
                  SizedBox(height: responsive.sp(22)),
                  if (simulados.isLoading)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: responsive.sp(56),
                      ),
                      child: Center(
                        child: CircularProgressIndicator(
                          key: const Key('simulados-loading'),
                          color: colors.accent,
                        ),
                      ),
                    )
                  else if (simulados.hasError)
                    _ErroSimulados(
                      colors: colors,
                      responsive: responsive,
                      onTentar: () => ref.invalidate(simuladosProvider),
                    )
                  else
                    _ConteudoSimulados(
                      colors: colors,
                      responsive: responsive,
                      listagem: simulados.requireValue,
                      onFazer: (simulado) =>
                          context.push('/simulados/fazer/${simulado.id}'),
                      onRanking: (simulado) =>
                          context.push('/simulados/ranking/${simulado.id}'),
                      onPdf: (simulado) =>
                          _imprimirSimulado(context, ref, simulado),
                      onExcluir: (simulado) =>
                          _excluirSimulado(context, ref, colors, simulado),
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

  Future<void> _abrirGerador(
    BuildContext context,
    WidgetRef ref,
    SimuladosColors colors,
  ) async {
    final criado = await showModalBottomSheet<Simulado>(
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
      builder: (_) => SimuladoGeneratorSheet(colors: colors),
    );
    if (criado == null || !context.mounted) return;
    ref.invalidate(simuladosProvider);
    showSimuladosMessage(context, 'Simulado criado com sucesso.');
  }

  Future<void> _excluirSimulado(
    BuildContext context,
    WidgetRef ref,
    SimuladosColors colors,
    Simulado simulado,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.card,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Excluir simulado?',
          style: TextStyle(color: colors.text, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Tem certeza que deseja apagar “${simulado.titulo}”?',
          style: TextStyle(color: colors.secondary, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancelar', style: TextStyle(color: colors.secondary)),
          ),
          FilledButton(
            key: Key('simulado-excluir-confirmar-${simulado.id}'),
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
          .read(simuladoRepositoryProvider)
          .excluir(idSimulado: simulado.id, idUsuario: perfil.id);
      ref.invalidate(simuladosProvider);
      if (!context.mounted) return;
      showSimuladosMessage(context, 'Simulado excluído.');
    } catch (error) {
      if (!context.mounted) return;
      showSimuladosMessage(context, simuladosErrorMessage(error));
    }
  }

  Future<void> _imprimirSimulado(
    BuildContext context,
    WidgetRef ref,
    Simulado simulado,
  ) async {
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
    }
  }
}

class _CabecalhoSimulados extends StatelessWidget {
  const _CabecalhoSimulados({
    required this.colors,
    required this.responsive,
    required this.onCriar,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final VoidCallback onCriar;

  @override
  Widget build(BuildContext context) {
    final titulo = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: responsive.sp(44),
          height: responsive.sp(44),
          decoration: BoxDecoration(
            color: colors.accentSoft,
            borderRadius: BorderRadius.circular(responsive.sp(13)),
            border: Border.all(color: colors.accentBorder),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.fact_check_outlined,
            size: responsive.sp(23),
            color: colors.accent,
          ),
        ),
        SizedBox(width: responsive.sp(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Central de Simulados',
                style: TextStyle(
                  color: colors.text,
                  fontSize: responsive.sp(21),
                  height: 1.17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.45,
                ),
              ),
              SizedBox(height: responsive.sp(4)),
              Text(
                'Gerencie seus simulados e teste seus conhecimentos com a comunidade.',
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

    final botao = FilledButton.icon(
      key: const Key('simulados-criar'),
      onPressed: onCriar,
      icon: Icon(Icons.add_rounded, size: responsive.sp(18)),
      label: const Text('Criar Meu Simulado'),
      style: FilledButton.styleFrom(
        backgroundColor: colors.accent,
        foregroundColor: Colors.white,
        minimumSize: Size(double.infinity, responsive.sp(48)),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(responsive.sp(12)),
        ),
        textStyle: TextStyle(
          fontSize: responsive.sp(12.5),
          fontWeight: FontWeight.w700,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: titulo),
            SizedBox(width: responsive.sp(18)),
            SizedBox(width: responsive.sp(250), child: botao),
          ],
        ),
      ],
    );
  }
}

class _ConteudoSimulados extends StatelessWidget {
  const _ConteudoSimulados({
    required this.colors,
    required this.responsive,
    required this.listagem,
    required this.onFazer,
    required this.onRanking,
    required this.onPdf,
    required this.onExcluir,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final SimuladoListagem listagem;
  final ValueChanged<Simulado> onFazer;
  final ValueChanged<Simulado> onRanking;
  final ValueChanged<Simulado> onPdf;
  final ValueChanged<Simulado> onExcluir;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SecaoSimulados(
          colors: colors,
          responsive: responsive,
          titulo: 'Simulados da Comunidade',
          cor: colors.community,
          vazioTitulo: 'Nenhum simulado público',
          vazioDescricao: 'Explore a comunidade e participe de provas criadas por outros alunos.',
          vazioIcone: Icons.public_rounded,
          simulados: listagem.publicos,
          onFazer: onFazer,
          onRanking: onRanking,
          onPdf: onPdf,
          onExcluir: onExcluir,
        ),
        SizedBox(height: responsive.sp(22)),
        _SecaoSimulados(
          colors: colors,
          responsive: responsive,
          titulo: 'Meus Simulados Privados',
          cor: colors.private,
          vazioTitulo: 'Meus simulados',
          vazioDescricao:
              'Seus simulados personalizados e privados aparecerão aqui.',
          vazioIcone: Icons.lock_outline_rounded,
          simulados: listagem.privados,
          onFazer: onFazer,
          onRanking: onRanking,
          onPdf: onPdf,
          onExcluir: onExcluir,
        ),
      ],
    );
  }
}

class _SecaoSimulados extends StatelessWidget {
  const _SecaoSimulados({
    required this.colors,
    required this.responsive,
    required this.titulo,
    required this.cor,
    required this.vazioTitulo,
    required this.vazioDescricao,
    required this.vazioIcone,
    required this.simulados,
    required this.onFazer,
    required this.onRanking,
    required this.onPdf,
    required this.onExcluir,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final String titulo;
  final Color cor;
  final String vazioTitulo;
  final String vazioDescricao;
  final IconData vazioIcone;
  final List<Simulado> simulados;
  final ValueChanged<Simulado> onFazer;
  final ValueChanged<Simulado> onRanking;
  final ValueChanged<Simulado> onPdf;
  final ValueChanged<Simulado> onExcluir;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: responsive.sp(4),
              height: responsive.sp(22),
              decoration: BoxDecoration(
                color: cor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            SizedBox(width: responsive.sp(9)),
            Expanded(
              child: Text(
                titulo,
                style: TextStyle(
                  color: colors.text,
                  fontSize: responsive.sp(13),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.55,
                ),
              ),
            ),
            if (simulados.isNotEmpty)
              Text(
                '${simulados.length}',
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
        if (simulados.isEmpty)
          _SimuladosVazio(
            colors: colors,
            responsive: responsive,
            title: vazioTitulo,
            description: vazioDescricao,
            icon: vazioIcone,
          )
        else
          for (var i = 0; i < simulados.length; i++) ...[
            _SimuladoCard(
              key: Key('simulado-card-${simulados[i].id}'),
              colors: colors,
              responsive: responsive,
              simulado: simulados[i],
              privado: simulados[i].ehPrivado,
              onFazer: () => onFazer(simulados[i]),
              onRanking: () => onRanking(simulados[i]),
              onPdf: () => onPdf(simulados[i]),
              onExcluir: () => onExcluir(simulados[i]),
            ),
            if (i < simulados.length - 1) SizedBox(height: responsive.sp(10)),
          ],
      ],
    );
  }
}

class _SimuladosVazio extends StatelessWidget {
  const _SimuladosVazio({
    required this.colors,
    required this.responsive,
    required this.title,
    required this.description,
    required this.icon,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SimuladoPanel(
    key: Key('simulados-vazio-${title.toLowerCase().replaceAll(' ', '-')}'),
    colors: colors,
    radius: responsive.sp(18),
    padding: EdgeInsets.symmetric(
      horizontal: responsive.sp(22),
      vertical: responsive.sp(25),
    ),
    child: Column(
      children: [
        Container(
          width: responsive.sp(58),
          height: responsive.sp(58),
          decoration: BoxDecoration(
            color: colors.cardSoft,
            shape: BoxShape.circle,
            border: Border.all(color: colors.border),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: responsive.sp(30), color: colors.muted),
        ),
        SizedBox(height: responsive.sp(12)),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.text,
            fontSize: responsive.sp(14),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: responsive.sp(5)),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: responsive.sp(300)),
          child: Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.secondary,
              fontSize: responsive.sp(11.5),
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SimuladoCard extends StatelessWidget {
  const _SimuladoCard({
    super.key,
    required this.colors,
    required this.responsive,
    required this.simulado,
    required this.privado,
    required this.onFazer,
    required this.onRanking,
    required this.onPdf,
    required this.onExcluir,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final Simulado simulado;
  final bool privado;
  final VoidCallback onFazer;
  final VoidCallback onRanking;
  final VoidCallback onPdf;
  final VoidCallback onExcluir;

  @override
  Widget build(BuildContext context) {
    final cor = privado ? colors.private : colors.community;
    final meta = privado
        ? 'Personalizado para seus estudos'
        : simulado.nomeCriador?.trim().isNotEmpty == true
        ? simulado.nomeCriador!
        : 'Simulado da comunidade';

    return SimuladoPanel(
      colors: colors,
      radius: responsive.sp(16),
      padding: EdgeInsets.all(responsive.sp(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.sp(9),
                  vertical: responsive.sp(5),
                ),
                decoration: BoxDecoration(
                  color: privado ? colors.privateSoft : colors.communitySoft,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: cor.withValues(alpha: 0.22)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      privado
                          ? Icons.lock_outline_rounded
                          : Icons.public_rounded,
                      size: responsive.sp(12),
                      color: cor,
                    ),
                    SizedBox(width: responsive.sp(4)),
                    Text(
                      privado ? 'Privado' : 'Público',
                      style: TextStyle(
                        color: cor,
                        fontSize: responsive.sp(9.5),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (simulado.criadoEm != null)
                Text(
                  DateFormat('dd/MM/yyyy').format(simulado.criadoEm!),
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: responsive.sp(9.5),
                  ),
                ),
            ],
          ),
          SizedBox(height: responsive.sp(10)),
          Text(
            simulado.titulo,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.text,
              fontSize: responsive.sp(15),
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          SizedBox(height: responsive.sp(4)),
          Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.secondary,
              fontSize: responsive.sp(10.5),
            ),
          ),
          SizedBox(height: responsive.sp(12)),
          FilledButton.icon(
            key: Key('simulado-iniciar-${simulado.id}'),
            onPressed: onFazer,
            icon: Icon(Icons.play_arrow_rounded, size: responsive.sp(17)),
            label: Text(privado ? 'Iniciar Agora' : 'Iniciar Prova'),
            style: FilledButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, responsive.sp(46)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(responsive.sp(11)),
              ),
              textStyle: TextStyle(
                fontSize: responsive.sp(11.5),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: responsive.sp(5)),
          Row(
            children: [
              _AcoesSimulado(
                colors: colors,
                simulado: simulado,
                podeVerRanking: !privado,
                onRanking: onRanking,
                onPdf: onPdf,
                onExcluir: onExcluir,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AcoesSimulado extends StatelessWidget {
  const _AcoesSimulado({
    required this.colors,
    required this.simulado,
    required this.podeVerRanking,
    required this.onRanking,
    required this.onPdf,
    required this.onExcluir,
  });

  final SimuladosColors colors;
  final Simulado simulado;
  final bool podeVerRanking;
  final VoidCallback onRanking;
  final VoidCallback onPdf;
  final VoidCallback onExcluir;

  @override
  Widget build(BuildContext context) {
    final botoes = <Widget>[
      IconButton(
        key: Key('simulado-pdf-${simulado.id}'),
        onPressed: onPdf,
        tooltip: 'Imprimir ou salvar PDF',
        style: IconButton.styleFrom(
          foregroundColor: colors.secondary,
          minimumSize: const Size(48, 48),
        ),
        icon: const Icon(Icons.picture_as_pdf_outlined),
      ),
      if (podeVerRanking)
        IconButton(
          key: Key('simulado-ranking-${simulado.id}'),
          onPressed: onRanking,
          tooltip: 'Ver ranking',
          style: IconButton.styleFrom(
            foregroundColor: colors.private,
            minimumSize: const Size(48, 48),
          ),
          icon: const Icon(Icons.emoji_events_outlined),
        ),
      if (simulado.ehMeu)
        IconButton(
          key: Key('simulado-excluir-${simulado.id}'),
          onPressed: onExcluir,
          tooltip: 'Excluir simulado',
          style: IconButton.styleFrom(
            foregroundColor: colors.danger,
            minimumSize: const Size(48, 48),
          ),
          icon: const Icon(Icons.delete_outline_rounded),
        ),
    ];
    return Row(children: botoes);
  }
}

class _ErroSimulados extends StatelessWidget {
  const _ErroSimulados({
    required this.colors,
    required this.responsive,
    required this.onTentar,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final VoidCallback onTentar;

  @override
  Widget build(BuildContext context) => SimuladoPanel(
    key: const Key('simulados-erro'),
    colors: colors,
    padding: EdgeInsets.all(responsive.sp(24)),
    child: Column(
      children: [
        Icon(
          Icons.cloud_off_rounded,
          color: colors.muted,
          size: responsive.sp(36),
        ),
        SizedBox(height: responsive.sp(10)),
        Text(
          'Não foi possível carregar os simulados',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.text,
            fontSize: responsive.sp(15),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: responsive.sp(8)),
        Text(
          'Verifique sua conexão e tente novamente.',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.secondary, height: 1.45),
        ),
        SizedBox(height: responsive.sp(14)),
        OutlinedButton.icon(
          key: const Key('simulados-tentar-novamente'),
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
