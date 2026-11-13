import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../../core/ui/responsive.dart';
import '../../models/question.dart';
import '../../models/study.dart';
import '../widgets/latex_text.dart';
import '../widgets/question_image.dart';
import 'cadernos_ui.dart';
import 'dashboard_shell.dart';

/// Detalhe de um caderno: questões salvas, status do aluno e ações.
///
/// O desktop (`templates/questoes/visualizar.html`) lista as questões do
/// caderno com paginação. No mobile a lista é contínua e cada questão aparece
/// completa, podendo ser respondida ali mesmo ou removida da pasta.
class CadernoDetailScreen extends ConsumerStatefulWidget {
  const CadernoDetailScreen({super.key, required this.idCaderno});

  final String idCaderno;

  @override
  ConsumerState<CadernoDetailScreen> createState() =>
      _CadernoDetailScreenState();
}

class _CadernoDetailScreenState extends ConsumerState<CadernoDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = CadernosColors.of(isDark);

    final perfil = ref.watch(perfilAtualProvider);
    final painel = ref.watch(painelProvider);
    final detalhe = ref.watch(cadernoDetalheProvider(widget.idCaderno));

    return Scaffold(
      backgroundColor: colors.bg,
      body: Column(
        children: [
          DashboardTopBar(
            isDark: isDark,
            streak: painel.value?.ofensiva ?? 0,
            username: perfil.value?.username ?? 'Estudante',
            onToggleTheme: () =>
                ref.read(themeModeProvider.notifier).alternar(isDark),
            onLogout: _sair,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _recarregar,
              color: colors.primary,
              backgroundColor: colors.card,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: responsive.pagePadding.copyWith(bottom: 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: responsive.questionsMaxWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _CabecalhoDetalhe(
                          colors: colors,
                          responsive: responsive,
                          nome: detalhe.value?.caderno.nome ?? 'Caderno',
                          quantidade: detalhe.value?.questoes.length,
                          onVoltar: () => context.go('/cadernos'),
                        ),
                        SizedBox(height: responsive.gap),
                        _buildConteudo(
                          colors: colors,
                          responsive: responsive,
                          detalhe: detalhe,
                        ),
                        SizedBox(height: responsive.gap),
                        CadernosFooter(colors: colors, responsive: responsive),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          DashboardBottomNav(
            isDark: isDark,
            selectedIndex: 2,
            onSelected: _onBottomNavSelected,
          ),
        ],
      ),
    );
  }

  Widget _buildConteudo({
    required CadernosColors colors,
    required Responsive responsive,
    required AsyncValue<CadernoDetalhe> detalhe,
  }) {
    if (detalhe.isLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: responsive.sp(64)),
        child: Center(
          child: CircularProgressIndicator(
            key: const Key('caderno-detalhe-loading'),
            color: colors.primary,
          ),
        ),
      );
    }

    if (detalhe.hasError) {
      return Container(
        key: const Key('caderno-detalhe-erro'),
        padding: EdgeInsets.all(responsive.sp(24)),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(responsive.cardRadius),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: responsive.sp(40),
              color: colors.muted,
            ),
            SizedBox(height: responsive.sp(10)),
            Text(
              'Não foi possível abrir o caderno',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: responsive.sp(15),
                fontWeight: FontWeight.w700,
                color: colors.text,
              ),
            ),
            SizedBox(height: responsive.sp(6)),
            Text(
              _mensagemErro(detalhe.error),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: responsive.sp(12.5),
                height: 1.45,
                color: colors.secondary,
              ),
            ),
            SizedBox(height: responsive.sp(16)),
            FilledButton(
              key: const Key('caderno-detalhe-retry'),
              onPressed: _recarregar,
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    final dados = detalhe.requireValue;
    if (dados.questoes.isEmpty) {
      return _CadernoVazio(
        colors: colors,
        responsive: responsive,
        onBuscarQuestoes: _buscarQuestoes,
      );
    }

    return Column(
      key: const Key('caderno-detalhe-questoes'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var indice = 0; indice < dados.questoes.length; indice++) ...[
          _QuestaoCadernoCard(
            colors: colors,
            responsive: responsive,
            questao: dados.questoes[indice],
            numero: indice + 1,
            statusInicial: dados.statusQuestao(dados.questoes[indice].id),
            onRemover: () => _removerQuestao(dados.questoes[indice]),
          ),
          if (indice != dados.questoes.length - 1)
            SizedBox(height: responsive.sp(12)),
        ],
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Ações
  // -------------------------------------------------------------------------

  void _buscarQuestoes() {
    ref.read(questoesFiltrosProvider.notifier).limpar();
    context.go('/questoes');
  }

  Future<void> _removerQuestao(Questao questao) async {
    final colors = CadernosColors.of(
      Theme.of(context).brightness == Brightness.dark,
    );
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Remover questão',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
        ),
        content: Text(
          'A questão será removida deste caderno. Ela continua disponível na '
          'busca de questões.',
          style: TextStyle(
            fontSize: 13.5,
            height: 1.45,
            color: colors.secondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancelar', style: TextStyle(color: colors.secondary)),
          ),
          FilledButton(
            key: const Key('caderno-remover-confirmar'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: colors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    try {
      final perfil = await ref.read(perfilAtualProvider.future);
      if (perfil == null) {
        throw StateError('Sessão indisponível.');
      }
      await ref
          .read(cadernoRepositoryProvider)
          .removerQuestao(
            idCaderno: widget.idCaderno,
            idUsuario: perfil.id,
            idQuestao: questao.id,
          );
      ref.invalidate(cadernoDetalheProvider(widget.idCaderno));
      ref.invalidate(cadernosProvider);
      if (!mounted) return;
      _mensagem('Questão removida do caderno.');
    } catch (error) {
      if (!mounted) return;
      _mensagem(_mensagemErro(error));
    }
  }

  Future<void> _recarregar() async {
    ref.invalidate(cadernoDetalheProvider(widget.idCaderno));
    try {
      await ref.read(cadernoDetalheProvider(widget.idCaderno).future);
    } catch (_) {
      // O estado de erro é exibido pelo próprio AsyncValue.
    }
  }

  Future<void> _sair() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair da conta'),
        content: const Text('Deseja encerrar a sessão neste aparelho?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    await ref.read(authGatewayProvider).signOut();
    if (!mounted) return;

    ref.invalidate(perfilAtualProvider);
    ref.invalidate(painelProvider);
    ref.invalidate(cadernosProvider);
    context.go('/login');
  }

  void _onBottomNavSelected(int index) {
    switch (index) {
      case 0:
        context.go('/home');
      case 1:
        context.go('/questoes');
      case 2:
        context.go('/cadernos');
      case 3:
        context.go('/flashcards');
      case 4:
        context.go('/resumos');
      case 5:
        context.go('/simulados');
      case 6:
        context.go('/editais');
      case 7:
        context.go('/conta');
      default:
        _mensagem('${DashboardBottomNav.labelFor(index)} chega em breve.');
    }
  }

  void _mensagem(String mensagem) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensagem),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }
}

// ---------------------------------------------------------------------------
// Cabeçalho do detalhe
// ---------------------------------------------------------------------------

class _CabecalhoDetalhe extends StatelessWidget {
  const _CabecalhoDetalhe({
    required this.colors,
    required this.responsive,
    required this.nome,
    required this.quantidade,
    required this.onVoltar,
  });

  final CadernosColors colors;
  final Responsive responsive;
  final String nome;
  final int? quantidade;
  final VoidCallback onVoltar;

  @override
  Widget build(BuildContext context) {
    final rotulo = switch (quantidade) {
      null => 'Carregando questões...',
      0 => 'Nenhuma questão salva',
      1 => '1 questão salva',
      final total => '$total questões salvas',
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: colors.card,
          borderRadius: BorderRadius.circular(responsive.sp(11)),
          child: InkWell(
            key: const Key('caderno-voltar'),
            onTap: onVoltar,
            borderRadius: BorderRadius.circular(responsive.sp(11)),
            child: Container(
              width: responsive.sp(40),
              height: responsive.sp(40),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(responsive.sp(11)),
                border: Border.all(color: colors.border),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                size: responsive.sp(19),
                color: colors.text,
              ),
            ),
          ),
        ),
        SizedBox(width: responsive.sp(10)),
        Container(
          width: responsive.sp(40),
          height: responsive.sp(40),
          decoration: BoxDecoration(
            color: colors.primarySoft,
            borderRadius: BorderRadius.circular(responsive.sp(11)),
            border: Border.all(color: colors.primaryBorder),
          ),
          child: Icon(
            Icons.folder_rounded,
            size: responsive.sp(21),
            color: colors.isDark ? colors.accent : colors.primary,
          ),
        ),
        SizedBox(width: responsive.sp(10)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nome,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: responsive.sp(19),
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  height: 1.2,
                  color: colors.text,
                ),
              ),
              SizedBox(height: responsive.sp(3)),
              Text(
                rotulo,
                style: TextStyle(
                  fontSize: responsive.sp(11.5),
                  fontWeight: FontWeight.w600,
                  color: colors.secondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Estado vazio do caderno
// ---------------------------------------------------------------------------

class _CadernoVazio extends StatelessWidget {
  const _CadernoVazio({
    required this.colors,
    required this.responsive,
    required this.onBuscarQuestoes,
  });

  final CadernosColors colors;
  final Responsive responsive;
  final VoidCallback onBuscarQuestoes;

  @override
  Widget build(BuildContext context) {
    return CadernosDashedBox(
      key: const Key('caderno-detalhe-vazio'),
      colors: colors,
      radius: responsive.sp(24),
      padding: EdgeInsets.symmetric(
        horizontal: responsive.sp(24),
        vertical: responsive.sp(32),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_outlined,
            size: responsive.sp(56),
            color: colors.dashedBorder,
          ),
          SizedBox(height: responsive.sp(10)),
          Text(
            'Nenhuma questão por aqui',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: responsive.sp(16),
              fontWeight: FontWeight.w700,
              color: colors.text,
            ),
          ),
          SizedBox(height: responsive.sp(6)),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: responsive.sp(280)),
            child: Text(
              'Este caderno ainda está vazio. Encontre questões na busca e '
              'salve-as para revisar depois.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: responsive.sp(12.5),
                height: 1.5,
                color: colors.secondary,
              ),
            ),
          ),
          SizedBox(height: responsive.sp(18)),
          FilledButton.icon(
            key: const Key('caderno-detalhe-buscar'),
            onPressed: onBuscarQuestoes,
            icon: Icon(Icons.search_rounded, size: responsive.sp(16)),
            label: const Text('Buscar Questões'),
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(
                horizontal: responsive.sp(20),
                vertical: responsive.sp(13),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(responsive.sp(12)),
              ),
              textStyle: TextStyle(
                fontSize: responsive.sp(12.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card de questão
// ---------------------------------------------------------------------------

enum _AlternativaEstado { normal, selecionada, correta, errada }

/// Questão completa dentro do caderno.
///
/// Reproduz o card do desktop (`templates/components/card_questao.html`):
/// enunciado, alternativas, resposta inline com feedback e remoção da pasta.
class _QuestaoCadernoCard extends ConsumerStatefulWidget {
  const _QuestaoCadernoCard({
    required this.colors,
    required this.responsive,
    required this.questao,
    required this.numero,
    required this.statusInicial,
    required this.onRemover,
  });

  final CadernosColors colors;
  final Responsive responsive;
  final Questao questao;
  final int numero;
  final bool? statusInicial;
  final VoidCallback onRemover;

  @override
  ConsumerState<_QuestaoCadernoCard> createState() =>
      _QuestaoCadernoCardState();
}

class _QuestaoCadernoCardState extends ConsumerState<_QuestaoCadernoCard> {
  String? _letraSelecionada;
  RespostaQuestaoResultado? _resultado;
  bool _enviando = false;
  late bool? _status;

  @override
  void initState() {
    super.initState();
    _status = widget.statusInicial;
  }

  @override
  void didUpdateWidget(covariant _QuestaoCadernoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.questao.id != widget.questao.id) {
      _letraSelecionada = null;
      _resultado = null;
      _enviando = false;
      _status = widget.statusInicial;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final responsive = widget.responsive;
    final questao = widget.questao;
    final enunciado = _htmlParaTexto(questao.enunciado);
    final textoBase = _htmlParaTexto(questao.textoBase ?? '');
    final imagens = QuestionImage.extrair(
      urlImagem: questao.urlImagem,
      html: '',
    );

    return Container(
      key: Key('caderno-questao-${questao.id}'),
      padding: EdgeInsets.all(responsive.sp(16)),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(responsive.cardRadius),
        border: Border.all(color: colors.border),
        boxShadow: colors.isDark
            ? null
            : [
                BoxShadow(
                  color: colors.shadow,
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Questão ${widget.numero.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: responsive.sp(11.5),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: colors.isDark ? colors.accent : colors.primary,
                ),
              ),
              SizedBox(width: responsive.sp(8)),
              Flexible(
                child: _StatusQuestao(
                  colors: colors,
                  responsive: responsive,
                  status: _status,
                ),
              ),
              const Spacer(),
              IconButton(
                key: Key('caderno-remover-${questao.id}'),
                onPressed: widget.onRemover,
                tooltip: 'Remover do caderno',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.remove_circle_outline_rounded,
                  size: responsive.sp(19),
                  color: colors.muted,
                ),
              ),
            ],
          ),
          if (_tags(questao).isNotEmpty) ...[
            SizedBox(height: responsive.sp(6)),
            Wrap(
              spacing: responsive.sp(6),
              runSpacing: responsive.sp(6),
              children: _tags(questao),
            ),
          ],
          if (textoBase.isNotEmpty) ...[
            SizedBox(height: responsive.sp(12)),
            _TextoApoioBox(
              key: ValueKey('caderno-texto-apoio-${questao.id}'),
              colors: colors,
              responsive: responsive,
              titulo: _htmlParaTexto(questao.tituloReferencia ?? ''),
              texto: textoBase,
            ),
          ],
          SizedBox(height: responsive.sp(12)),
          for (final url in imagens)
            QuestionImage(
              key: ValueKey('caderno-imagem-${questao.id}-$url'),
              source: url,
            ),
          LatexText(
            enunciado.isEmpty ? 'Enunciado indisponível.' : enunciado,
            style: TextStyle(
              fontSize: responsive.sp(13),
              height: 1.55,
              color: colors.text,
            ),
          ),
          SizedBox(height: responsive.sp(12)),
          if (questao.alternativas.isEmpty)
            _DiscursivaCaderno(colors: colors, responsive: responsive)
          else
            for (final alternativa in questao.alternativas)
              _AlternativaCaderno(
                key: Key(
                  'caderno-alternativa-${questao.id}-${alternativa.letra}',
                ),
                colors: colors,
                responsive: responsive,
                letra: alternativa.letra,
                texto: _htmlParaTexto(alternativa.texto),
                estado: _estadoAlternativa(alternativa.letra),
                onTap: _resultado == null && !_enviando
                    ? () =>
                          setState(() => _letraSelecionada = alternativa.letra)
                    : null,
              ),
          if (_resultado != null) ...[
            SizedBox(height: responsive.sp(4)),
            _FeedbackCaderno(
              colors: colors,
              responsive: responsive,
              resultado: _resultado!,
            ),
          ],
          SizedBox(height: responsive.sp(10)),
          FilledButton(
            key: Key('caderno-responder-${questao.id}'),
            onPressed:
                _resultado != null || _enviando || _letraSelecionada == null
                ? null
                : _responder,
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: colors.isDark
                  ? colors.primary.withValues(alpha: 0.35)
                  : colors.border,
              disabledForegroundColor: colors.isDark
                  ? Colors.white38
                  : colors.muted,
              elevation: 0,
              minimumSize: Size(double.infinity, responsive.sp(44)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(responsive.sp(11)),
              ),
              textStyle: TextStyle(
                fontSize: responsive.sp(12),
                fontWeight: FontWeight.w600,
              ),
            ),
            child: _enviando
                ? SizedBox(
                    width: responsive.sp(18),
                    height: responsive.sp(18),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _resultado != null
                            ? Icons.check_rounded
                            : Icons.check_circle_outline_rounded,
                        size: responsive.sp(16),
                      ),
                      SizedBox(width: responsive.sp(6)),
                      Text(_resultado != null ? 'Respondida' : 'Responder'),
                    ],
                  ),
          ),
          SizedBox(height: responsive.sp(14)),
          Divider(height: 1, color: colors.border),
          SizedBox(height: responsive.sp(10)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: Key('caderno-remover-rodape-${questao.id}'),
              onPressed: widget.onRemover,
              icon: Icon(Icons.delete_outline_rounded, size: responsive.sp(16)),
              label: const Text('Remover do caderno'),
              style: TextButton.styleFrom(
                foregroundColor: colors.danger,
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.sp(8),
                  vertical: responsive.sp(6),
                ),
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

  _AlternativaEstado _estadoAlternativa(String letra) {
    final resultado = _resultado;
    if (resultado != null) {
      final correta = resultado.letraCorreta ?? widget.questao.letraCorreta;
      if (correta != null && letra == correta) {
        return _AlternativaEstado.correta;
      }
      if (letra == _letraSelecionada && !resultado.correta) {
        return _AlternativaEstado.errada;
      }
      return _AlternativaEstado.normal;
    }
    if (letra == _letraSelecionada) return _AlternativaEstado.selecionada;
    return _AlternativaEstado.normal;
  }

  Future<void> _responder() async {
    final letra = _letraSelecionada;
    if (letra == null || _enviando) return;

    final perfil = await ref.read(perfilAtualProvider.future);
    if (!mounted) return;
    if (perfil == null) {
      _mensagem('Sessão expirada. Entre novamente.');
      return;
    }

    setState(() => _enviando = true);
    try {
      final resultado = await ref
          .read(questionRepositoryProvider)
          .responder(
            idUsuario: perfil.id,
            idQuestao: widget.questao.id,
            letra: letra,
          );
      if (!mounted) return;
      setState(() {
        _resultado = resultado;
        _status = resultado.correta;
        _enviando = false;
      });
      ref.invalidate(painelProvider);
      ref.invalidate(estatisticasDetalhadasProvider);
    } catch (error) {
      if (!mounted) return;
      setState(() => _enviando = false);
      _mensagem(_mensagemErro(error));
    }
  }

  void _mensagem(String mensagem) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensagem),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  List<Widget> _tags(Questao questao) {
    final tags = <Widget>[];
    final materia = questao.nomeMateria?.trim();
    if (materia != null && materia.isNotEmpty) {
      tags.add(
        CadernosTag(
          text: materia,
          background: widget.colors.primarySoft,
          foreground: widget.colors.isDark
              ? widget.colors.accent
              : widget.colors.primary,
          responsive: widget.responsive,
        ),
      );
    }
    final banca = questao.nomeBanca?.trim();
    if (banca != null && banca.isNotEmpty) {
      tags.add(
        CadernosTag(
          text: banca,
          background: widget.colors.cardSoft,
          foreground: widget.colors.secondary,
          responsive: widget.responsive,
          maxWidth: 150,
        ),
      );
    }
    if (questao.ano != null) {
      tags.add(
        CadernosTag(
          text: '${questao.ano}',
          background: widget.colors.cardSoft,
          foreground: widget.colors.secondary,
          responsive: widget.responsive,
          maxWidth: 80,
        ),
      );
    }
    final nivel = questao.descritivoNivel?.trim();
    if (nivel != null && nivel.isNotEmpty) {
      tags.add(
        CadernosTag(
          text: nivel,
          background: widget.colors.cardSoft,
          foreground: widget.colors.secondary,
          responsive: widget.responsive,
          maxWidth: 140,
        ),
      );
    }
    return tags;
  }
}

class _StatusQuestao extends StatelessWidget {
  const _StatusQuestao({
    required this.colors,
    required this.responsive,
    required this.status,
  });

  final CadernosColors colors;
  final Responsive responsive;
  final bool? status;

  @override
  Widget build(BuildContext context) {
    final (texto, cor, fundo, icone) = switch (status) {
      true => (
        'Acertou',
        colors.success,
        colors.successSoft,
        Icons.check_circle_outline_rounded,
      ),
      false => (
        'Errou',
        colors.danger,
        colors.dangerSoft,
        Icons.cancel_outlined,
      ),
      null => (
        'Não respondida',
        colors.secondary,
        colors.cardSoft,
        Icons.help_outline_rounded,
      ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.sp(7),
        vertical: responsive.sp(3),
      ),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(responsive.sp(6)),
        border: Border.all(color: cor.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: responsive.sp(11), color: cor),
          SizedBox(width: responsive.sp(3)),
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: responsive.sp(10),
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: cor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlternativaCaderno extends StatelessWidget {
  const _AlternativaCaderno({
    super.key,
    required this.colors,
    required this.responsive,
    required this.letra,
    required this.texto,
    required this.estado,
    required this.onTap,
  });

  final CadernosColors colors;
  final Responsive responsive;
  final String letra;
  final String texto;
  final _AlternativaEstado estado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (
      fundo,
      borda,
      larguraBorda,
      fundoLetra,
      corLetra,
      corTexto,
    ) = switch (estado) {
      _AlternativaEstado.selecionada => (
        colors.primarySoft,
        colors.primary,
        2.0,
        colors.primary,
        Colors.white,
        colors.text,
      ),
      _AlternativaEstado.correta => (
        colors.successSoft,
        colors.success,
        2.0,
        colors.success,
        colors.isDark ? colors.bg : Colors.white,
        colors.text,
      ),
      _AlternativaEstado.errada => (
        colors.dangerSoft,
        colors.danger,
        2.0,
        colors.danger,
        colors.isDark ? colors.bg : Colors.white,
        colors.text,
      ),
      _AlternativaEstado.normal => (
        colors.card,
        colors.border,
        1.0,
        colors.cardSoft,
        colors.secondary,
        colors.text,
      ),
    };

    return Padding(
      padding: EdgeInsets.only(bottom: responsive.sp(8)),
      child: Material(
        color: fundo,
        borderRadius: BorderRadius.circular(responsive.sp(11)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.sp(10),
              vertical: responsive.sp(9),
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(responsive.sp(11)),
              border: Border.all(color: borda, width: larguraBorda),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: responsive.sp(28),
                  height: responsive.sp(28),
                  decoration: BoxDecoration(
                    color: fundoLetra,
                    borderRadius: BorderRadius.circular(responsive.sp(8)),
                    border: estado == _AlternativaEstado.normal
                        ? Border.all(color: colors.border)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    letra,
                    style: TextStyle(
                      fontSize: responsive.sp(11.5),
                      fontWeight: FontWeight.w700,
                      color: corLetra,
                      height: 1,
                    ),
                  ),
                ),
                SizedBox(width: responsive.sp(10)),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: responsive.sp(5)),
                    child: LatexText(
                      texto,
                      style: TextStyle(
                        fontSize: responsive.sp(12.5),
                        height: 1.4,
                        fontWeight:
                            estado == _AlternativaEstado.correta ||
                                estado == _AlternativaEstado.selecionada
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: corTexto,
                      ),
                    ),
                  ),
                ),
                if (estado == _AlternativaEstado.correta)
                  Padding(
                    padding: EdgeInsets.only(
                      left: responsive.sp(6),
                      top: responsive.sp(4),
                    ),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: responsive.sp(18),
                      color: colors.success,
                    ),
                  )
                else if (estado == _AlternativaEstado.errada)
                  Padding(
                    padding: EdgeInsets.only(
                      left: responsive.sp(6),
                      top: responsive.sp(4),
                    ),
                    child: Icon(
                      Icons.cancel_rounded,
                      size: responsive.sp(18),
                      color: colors.danger,
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

class _FeedbackCaderno extends StatelessWidget {
  const _FeedbackCaderno({
    required this.colors,
    required this.responsive,
    required this.resultado,
  });

  final CadernosColors colors;
  final Responsive responsive;
  final RespostaQuestaoResultado resultado;

  @override
  Widget build(BuildContext context) {
    final correta = resultado.correta;
    final fundo = correta ? colors.successSoft : colors.dangerSoft;
    final destaque = correta ? colors.success : colors.danger;

    return Container(
      padding: EdgeInsets.all(responsive.sp(11)),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(responsive.sp(11)),
        border: Border.all(color: destaque.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            correta ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: responsive.sp(17),
            color: destaque,
          ),
          SizedBox(width: responsive.sp(7)),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: responsive.sp(11.5),
                  height: 1.4,
                  color: colors.text,
                ),
                children: [
                  TextSpan(
                    text: correta
                        ? 'Parabéns, você acertou! '
                        : 'Resposta incorreta. ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: destaque,
                    ),
                  ),
                  if (resultado.letraCorreta != null)
                    TextSpan(
                      text:
                          'A alternativa correta é a '
                          '${resultado.letraCorreta}.',
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscursivaCaderno extends StatelessWidget {
  const _DiscursivaCaderno({required this.colors, required this.responsive});

  final CadernosColors colors;
  final Responsive responsive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(responsive.sp(12)),
      decoration: BoxDecoration(
        color: colors.cardSoft,
        borderRadius: BorderRadius.circular(responsive.sp(10)),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        'Esta é uma questão discursiva. A correção pelo app está disponível '
        'apenas para questões objetivas.',
        style: TextStyle(
          fontSize: responsive.sp(11.5),
          height: 1.4,
          color: colors.secondary,
        ),
      ),
    );
  }
}

/// Texto de apoio (leis, trechos, tabelas) começa recolhido, como no desktop.
class _TextoApoioBox extends StatefulWidget {
  const _TextoApoioBox({
    super.key,
    required this.colors,
    required this.responsive,
    required this.titulo,
    required this.texto,
  });

  final CadernosColors colors;
  final Responsive responsive;
  final String titulo;
  final String texto;

  @override
  State<_TextoApoioBox> createState() => _TextoApoioBoxState();
}

class _TextoApoioBoxState extends State<_TextoApoioBox> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final responsive = widget.responsive;
    final titulo = widget.titulo.trim();

    return Container(
      decoration: BoxDecoration(
        color: colors.cardSoft,
        borderRadius: BorderRadius.circular(responsive.sp(11)),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expandido = !_expandido),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                responsive.sp(11),
                responsive.sp(8),
                responsive.sp(8),
                responsive.sp(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    size: responsive.sp(15),
                    color: colors.primary,
                  ),
                  SizedBox(width: responsive.sp(7)),
                  Expanded(
                    child: LatexText(
                      titulo.isEmpty ? 'TEXTO DE APOIO' : titulo.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: responsive.sp(10),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: colors.primary,
                      ),
                    ),
                  ),
                  Icon(
                    _expandido
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: responsive.sp(18),
                    color: colors.secondary,
                  ),
                ],
              ),
            ),
          ),
          if (_expandido)
            Padding(
              padding: EdgeInsets.fromLTRB(
                responsive.sp(11),
                0,
                responsive.sp(11),
                responsive.sp(11),
              ),
              child: LatexText(
                widget.texto,
                style: TextStyle(
                  fontSize: responsive.sp(12),
                  height: 1.5,
                  color: colors.secondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _htmlParaTexto(String html) => LatexText.limparHtml(html);

String _mensagemErro(Object? erro) {
  if (erro is AppException) return erro.message;
  if (erro is StateError) {
    return 'Sua sessão não está disponível. Entre novamente.';
  }
  return 'Não foi possível concluir a operação. Tente novamente.';
}
