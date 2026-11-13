import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/errors/app_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../../core/ui/responsive.dart';
import '../../models/study.dart';
import 'cadernos_ui.dart';
import 'dashboard_shell.dart';

/// Tela "Meus Cadernos" - Gabaritei Questões.
///
/// Reproduz o estado vazio do Stitch (temas claro e escuro) e complementa o
/// layout com a lista de cadernos existentes, criação e exclusão. Os cadernos
/// são pastas pessoais com questões salvas pelo aluno.
class CadernosScreen extends ConsumerStatefulWidget {
  const CadernosScreen({super.key});

  @override
  ConsumerState<CadernosScreen> createState() => _CadernosScreenState();
}

class _CadernosScreenState extends ConsumerState<CadernosScreen> {
  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = CadernosColors.of(isDark);

    final perfil = ref.watch(perfilAtualProvider);
    final painel = ref.watch(painelProvider);
    final cadernos = ref.watch(cadernosProvider);

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
                      maxWidth: responsive.dashboardMaxWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Cabecalho(
                          colors: colors,
                          responsive: responsive,
                          onCriar: _criarCaderno,
                        ),
                        SizedBox(height: responsive.gap),
                        _buildConteudo(
                          colors: colors,
                          responsive: responsive,
                          cadernos: cadernos,
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
    required AsyncValue<List<Caderno>> cadernos,
  }) {
    if (cadernos.isLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: responsive.sp(64)),
        child: Center(
          child: CircularProgressIndicator(
            key: const Key('cadernos-loading'),
            color: colors.primary,
          ),
        ),
      );
    }

    if (cadernos.hasError) {
      return _MensagemErro(
        colors: colors,
        responsive: responsive,
        mensagem: _mensagemErro(cadernos.error),
        onTentarNovamente: _recarregar,
      );
    }

    final lista = cadernos.requireValue;
    if (lista.isEmpty) {
      return _EstadoVazio(
        colors: colors,
        responsive: responsive,
        onBuscarQuestoes: _buscarQuestoes,
      );
    }

    return _ListaCadernos(
      colors: colors,
      responsive: responsive,
      cadernos: lista,
      onAbrir: (caderno) => context.go('/cadernos/${caderno.id}'),
      onExcluir: _excluirCaderno,
    );
  }

  // -------------------------------------------------------------------------
  // Ações
  // -------------------------------------------------------------------------

  Future<void> _criarCaderno() async {
    final colors = CadernosColors.of(
      Theme.of(context).brightness == Brightness.dark,
    );
    final nome = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _CriarCadernoDialog(colors: colors),
    );
    if (nome == null || !mounted) return;

    try {
      final perfil = await ref.read(perfilAtualProvider.future);
      if (perfil == null) {
        throw StateError('Sessão indisponível.');
      }
      await ref
          .read(cadernoRepositoryProvider)
          .criar(idUsuario: perfil.id, nome: nome);
      ref.invalidate(cadernosProvider);
      if (!mounted) return;
      _mensagem('Caderno criado com sucesso.');
    } catch (error) {
      if (!mounted) return;
      _mensagem(_mensagemErro(error));
    }
  }

  Future<void> _excluirCaderno(Caderno caderno) async {
    final colors = CadernosColors.of(
      Theme.of(context).brightness == Brightness.dark,
    );
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Excluir caderno',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
        ),
        content: Text(
          'O caderno "${caderno.nome}" será removido. As questões continuam '
          'disponíveis na busca.',
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
            key: const Key('caderno-excluir-confirmar'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: colors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir'),
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
          .excluir(idCaderno: caderno.id, idUsuario: perfil.id);
      ref.invalidate(cadernosProvider);
      if (!mounted) return;
      _mensagem('Caderno excluído.');
    } catch (error) {
      if (!mounted) return;
      _mensagem(_mensagemErro(error));
    }
  }

  Future<void> _recarregar() async {
    ref.invalidate(cadernosProvider);
    try {
      await ref.read(cadernosProvider.future);
    } catch (_) {
      // O estado de erro é exibido pelo próprio AsyncValue.
    }
  }

  void _buscarQuestoes() {
    ref.read(questoesFiltrosProvider.notifier).limpar();
    context.go('/questoes');
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
        return;
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
// Cabeçalho
// ---------------------------------------------------------------------------

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({
    required this.colors,
    required this.responsive,
    required this.onCriar,
  });

  final CadernosColors colors;
  final Responsive responsive;
  final VoidCallback onCriar;

  @override
  Widget build(BuildContext context) {
    final titulo = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: responsive.sp(42),
          height: responsive.sp(42),
          decoration: BoxDecoration(
            color: colors.primarySoft,
            borderRadius: BorderRadius.circular(responsive.sp(11)),
            border: Border.all(color: colors.primaryBorder),
          ),
          alignment: Alignment.center,
          child: Text(
            '📘',
            style: TextStyle(fontSize: responsive.sp(20), height: 1),
          ),
        ),
        SizedBox(width: responsive.sp(10)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Meus Cadernos',
                style: TextStyle(
                  fontSize: responsive.sp(22),
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  height: 1.15,
                  color: colors.text,
                ),
              ),
              SizedBox(height: responsive.sp(3)),
              Text(
                'Organize suas questões salvas em pastas personalizadas.',
                style: TextStyle(
                  fontSize: responsive.sp(12.5),
                  height: 1.4,
                  color: colors.secondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final botao = FilledButton.icon(
      key: const Key('cadernos-novo'),
      onPressed: onCriar,
      icon: Icon(Icons.add_rounded, size: responsive.sp(18)),
      label: Text('Novo Caderno'),
      style: FilledButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: EdgeInsets.symmetric(
          horizontal: responsive.sp(18),
          vertical: responsive.sp(14),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(responsive.sp(12)),
        ),
        textStyle: TextStyle(
          fontSize: responsive.sp(13),
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    if (!responsive.isTabletOrLarger) {
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
        SizedBox(width: responsive.sp(16)),
        botao,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Estado vazio
// ---------------------------------------------------------------------------

class _EstadoVazio extends StatelessWidget {
  const _EstadoVazio({
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
      key: const Key('cadernos-vazio'),
      colors: colors,
      radius: responsive.sp(24),
      padding: EdgeInsets.symmetric(
        horizontal: responsive.sp(24),
        vertical: responsive.sp(36),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_outlined,
            size: responsive.sp(64),
            color: colors.dashedBorder,
          ),
          SizedBox(height: responsive.sp(12)),
          Text(
            'Sua biblioteca está vazia',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: responsive.sp(17),
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: colors.text,
            ),
          ),
          SizedBox(height: responsive.sp(6)),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: responsive.sp(290)),
            child: Text(
              'Você ainda não criou nenhum caderno de questões. Crie pastas '
              'para organizar seus estudos por matéria ou concurso.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: responsive.sp(12.5),
                height: 1.5,
                color: colors.secondary,
              ),
            ),
          ),
          SizedBox(height: responsive.sp(20)),
          FilledButton.icon(
            key: const Key('cadernos-buscar'),
            onPressed: onBuscarQuestoes,
            icon: Icon(Icons.add_rounded, size: responsive.sp(16)),
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
// Lista de cadernos
// ---------------------------------------------------------------------------

class _ListaCadernos extends StatelessWidget {
  const _ListaCadernos({
    required this.colors,
    required this.responsive,
    required this.cadernos,
    required this.onAbrir,
    required this.onExcluir,
  });

  final CadernosColors colors;
  final Responsive responsive;
  final List<Caderno> cadernos;
  final ValueChanged<Caderno> onAbrir;
  final ValueChanged<Caderno> onExcluir;

  @override
  Widget build(BuildContext context) {
    final quantidade = cadernos.length;
    final rotulo = quantidade == 1 ? '1 caderno' : '$quantidade cadernos';

    return Column(
      key: const Key('cadernos-lista'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          rotulo,
          style: TextStyle(
            fontSize: responsive.sp(11.5),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: colors.muted,
          ),
        ),
        SizedBox(height: responsive.sp(10)),
        LayoutBuilder(
          builder: (context, constraints) {
            final duasColunas =
                responsive.isTabletOrLarger && constraints.maxWidth >= 600;
            final espaco = responsive.sp(12);
            final largura = duasColunas
                ? (constraints.maxWidth - espaco) / 2
                : constraints.maxWidth;

            return Wrap(
              spacing: espaco,
              runSpacing: espaco,
              children: [
                for (final caderno in cadernos)
                  SizedBox(
                    width: largura,
                    child: _CadernoCard(
                      colors: colors,
                      responsive: responsive,
                      caderno: caderno,
                      onAbrir: () => onAbrir(caderno),
                      onExcluir: () => onExcluir(caderno),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CadernoCard extends StatelessWidget {
  const _CadernoCard({
    required this.colors,
    required this.responsive,
    required this.caderno,
    required this.onAbrir,
    required this.onExcluir,
  });

  final CadernosColors colors;
  final Responsive responsive;
  final Caderno caderno;
  final VoidCallback onAbrir;
  final VoidCallback onExcluir;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(responsive.cardRadius);
    final criadoEm = caderno.criadoEm;
    final data = criadoEm == null
        ? 'Pasta personalizada'
        : 'Criado em ${DateFormat('dd/MM/yyyy').format(criadoEm)}';

    return Material(
      color: colors.card,
      borderRadius: radius,
      child: InkWell(
        key: Key('caderno-card-${caderno.id}'),
        onTap: onAbrir,
        borderRadius: radius,
        child: Container(
          padding: EdgeInsets.all(responsive.sp(16)),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
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
                  const Spacer(),
                  IconButton(
                    key: Key('caderno-excluir-${caderno.id}'),
                    onPressed: onExcluir,
                    tooltip: 'Excluir caderno',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: responsive.sp(19),
                      color: colors.muted,
                    ),
                  ),
                ],
              ),
              SizedBox(height: responsive.sp(10)),
              Text(
                caderno.nome,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: responsive.sp(15.5),
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  letterSpacing: -0.2,
                  color: colors.text,
                ),
              ),
              SizedBox(height: responsive.sp(4)),
              Text(
                data,
                style: TextStyle(
                  fontSize: responsive.sp(11.5),
                  color: colors.secondary,
                ),
              ),
              SizedBox(height: responsive.sp(14)),
              Row(
                children: [
                  Text(
                    'Abrir caderno',
                    style: TextStyle(
                      fontSize: responsive.sp(12),
                      fontWeight: FontWeight.w600,
                      color: colors.isDark ? colors.accent : colors.primary,
                    ),
                  ),
                  SizedBox(width: responsive.sp(4)),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: responsive.sp(14),
                    color: colors.isDark ? colors.accent : colors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Erro
// ---------------------------------------------------------------------------

class _MensagemErro extends StatelessWidget {
  const _MensagemErro({
    required this.colors,
    required this.responsive,
    required this.mensagem,
    required this.onTentarNovamente,
  });

  final CadernosColors colors;
  final Responsive responsive;
  final String mensagem;
  final VoidCallback onTentarNovamente;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('cadernos-erro'),
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
            'Não foi possível carregar seus cadernos',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: responsive.sp(15),
              fontWeight: FontWeight.w700,
              color: colors.text,
            ),
          ),
          SizedBox(height: responsive.sp(6)),
          Text(
            mensagem,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: responsive.sp(12.5),
              height: 1.45,
              color: colors.secondary,
            ),
          ),
          SizedBox(height: responsive.sp(16)),
          FilledButton(
            key: const Key('cadernos-retry'),
            onPressed: onTentarNovamente,
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
}

// ---------------------------------------------------------------------------
// Diálogo de criação
// ---------------------------------------------------------------------------

class _CriarCadernoDialog extends StatefulWidget {
  const _CriarCadernoDialog({required this.colors});

  final CadernosColors colors;

  @override
  State<_CriarCadernoDialog> createState() => _CriarCadernoDialogState();
}

class _CriarCadernoDialogState extends State<_CriarCadernoDialog> {
  final _controller = TextEditingController();
  String? _erro;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirmar() {
    final nome = _controller.text.trim();
    if (nome.isEmpty) {
      setState(() => _erro = 'Informe o nome do caderno.');
      return;
    }
    Navigator.of(context).pop(nome);
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return AlertDialog(
      backgroundColor: colors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Novo Caderno',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: colors.text,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Dê um nome para a pasta. Você poderá salvar questões nela depois.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: colors.secondary,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('caderno-nome'),
            controller: _controller,
            autofocus: true,
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(fontSize: 14, color: colors.text),
            onSubmitted: (_) => _confirmar(),
            decoration: InputDecoration(
              hintText: 'Ex.: Direito Constitucional',
              errorText: _erro,
              counterText: '',
              filled: true,
              fillColor: colors.cardSoft,
              hintStyle: TextStyle(color: colors.muted, fontSize: 13.5),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.primary, width: 1.5),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancelar', style: TextStyle(color: colors.secondary)),
        ),
        FilledButton(
          key: const Key('caderno-criar-confirmar'),
          onPressed: _confirmar,
          style: FilledButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Criar'),
        ),
      ],
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
