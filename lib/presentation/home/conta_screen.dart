import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_exception.dart';
import '../../core/providers.dart';
import '../../core/ui/responsive.dart';
import '../../models/user_profile.dart';
import '../../repositories/ia_config_store.dart';
import '../../services/ai_provider_service.dart';
import 'flashcards_ui.dart';

/// Configurações da conta, alinhadas ao fluxo de `/aluno/conta` do desktop.
class ContaScreen extends ConsumerStatefulWidget {
  const ContaScreen({super.key});

  @override
  ConsumerState<ContaScreen> createState() => _ContaScreenState();
}

class _ContaScreenState extends ConsumerState<ContaScreen> {
  final _usernameController = TextEditingController();
  int? _usuarioDoCampo;
  var _salvandoPerfil = false;
  var _resetandoDados = false;
  var _excluindoConta = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final colors = FlashcardsColors.of(
      Theme.of(context).brightness == Brightness.dark,
    );
    final perfil = ref.watch(perfilAtualProvider);

    return FlashcardsPageShell(
      selectedIndex: 7,
      backgroundColor: colors.bg,
      child: RefreshIndicator(
        key: const Key('conta-refresh'),
        color: colors.accent,
        backgroundColor: colors.card,
        onRefresh: () async {
          ref.invalidate(perfilAtualProvider);
          final atual = await ref.read(perfilAtualProvider.future);
          if (atual != null && _usuarioDoCampo != atual.id) {
            _usernameController.text = atual.username;
            _usuarioDoCampo = atual.id;
          }
        },
        child: perfil.when(
          loading: () => Center(
            child: CircularProgressIndicator(
              key: const Key('conta-loading'),
              color: colors.accent,
            ),
          ),
          error: (error, _) => _ContaEstadoErro(
            colors: colors,
            responsive: responsive,
            mensagem: _mensagemErro(error),
            onTentar: () => ref.invalidate(perfilAtualProvider),
          ),
          data: (usuario) {
            if (usuario == null) {
              return _ContaEstadoErro(
                colors: colors,
                responsive: responsive,
                mensagem: 'Sua sessão expirou. Entre novamente.',
                onTentar: () => context.go('/login'),
              );
            }
            if (_usuarioDoCampo != usuario.id) {
              _usernameController.text = usuario.username;
              _usuarioDoCampo = usuario.id;
            }
            return _conteudo(context, responsive, colors, usuario);
          },
        ),
      ),
    );
  }

  Widget _conteudo(
    BuildContext context,
    Responsive responsive,
    FlashcardsColors colors,
    UserProfile usuario,
  ) => SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: responsive.pagePadding.copyWith(bottom: responsive.sp(28)),
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: responsive.dashboardMaxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TituloConta(colors: colors, responsive: responsive),
            SizedBox(height: responsive.sp(15)),
            _IdentidadeContaCard(
              colors: colors,
              responsive: responsive,
              usuario: usuario,
              usernameController: _usernameController,
              salvando: _salvandoPerfil,
              onSalvar: () => _salvarPerfil(usuario),
            ),
            SizedBox(height: responsive.sp(12)),
            _AiConfiguracaoCard(
              key: ValueKey('ai-config-${usuario.id}'),
              colors: colors,
              responsive: responsive,
              idUsuario: usuario.id,
            ),
            SizedBox(height: responsive.sp(12)),
            _ZonaResetCard(
              colors: colors,
              responsive: responsive,
              executando: _resetandoDados,
              onResetar: () => _resetarDados(usuario),
            ),
            SizedBox(height: responsive.sp(12)),
            _ZonaExcluirContaCard(
              colors: colors,
              responsive: responsive,
              executando: _excluindoConta,
              onExcluir: () => _excluirConta(usuario),
            ),
            FlashcardsFooter(colors: colors, responsive: responsive),
          ],
        ),
      ),
    ),
  );

  Future<void> _salvarPerfil(UserProfile usuario) async {
    if (_salvandoPerfil) return;
    setState(() => _salvandoPerfil = true);
    try {
      await ref
          .read(userRepositoryProvider)
          .atualizarPerfil(
            idUsuario: usuario.id,
            username: _usernameController.text.trim(),
            email: usuario.email,
          );
      if (!mounted) return;
      ref.invalidate(perfilAtualProvider);
      ref.invalidate(painelProvider);
      showContaMensagem(context, 'Informações atualizadas com sucesso.');
    } catch (error) {
      if (!mounted) return;
      showContaMensagem(context, _mensagemErro(error));
    } finally {
      if (mounted) setState(() => _salvandoPerfil = false);
    }
  }

  Future<void> _resetarDados(UserProfile usuario) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmacaoDigitadaDialog(
        colors: FlashcardsColors.of(
          Theme.of(context).brightness == Brightness.dark,
        ),
        icon: Icons.restart_alt_rounded,
        title: 'Zerar todos os dados?',
        description: 'Todo o seu progresso de estudo será apagado. Sua conta continuará ativa.',
        detalhes: const [
          'Questões resolvidas e histórico de acertos/erros',
          'Cadernos de questões e filtros salvos',
          'Flashcards, simulados e editais',
          'Comentários e contadores de uso',
        ],
        phrase: 'RESETAR MEUS DADOS',
        confirmLabel: 'Sim, resetar dados',
        confirmColor: const Color(0xFFF59E0B),
        confirmKey: const Key('conta-resetar-confirmar'),
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _resetandoDados = true);
    try {
      await ref.read(userRepositoryProvider).resetarDados(usuario.id);
      if (!mounted) return;
      _invalidarDadosDeEstudo();
      showContaMensagem(context, 'Seus dados de estudo foram redefinidos.');
    } catch (error) {
      if (!mounted) return;
      showContaMensagem(context, _mensagemErro(error));
    } finally {
      if (mounted) setState(() => _resetandoDados = false);
    }
  }

  Future<void> _excluirConta(UserProfile usuario) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmacaoDigitadaDialog(
        colors: FlashcardsColors.of(
          Theme.of(context).brightness == Brightness.dark,
        ),
        icon: Icons.delete_forever_outlined,
        title: 'Encerrar minha conta?',
        description: 'Esta ação é permanente. O perfil e os dados associados serão removidos e você sairá da conta.',
        detalhes: const [
          'Seu desempenho e histórico de estudo',
          'Cadernos, flashcards, simulados e editais',
          'Comentários e dados de perfil',
        ],
        phrase: 'EXCLUIR MINHA CONTA',
        confirmLabel: 'Excluir Conta',
        confirmColor: const Color(0xFFDC2626),
        confirmKey: const Key('conta-excluir-confirmar'),
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _excluindoConta = true);
    try {
      await ref.read(userRepositoryProvider).excluirPerfil(usuario.id);
      try {
        await ref.read(iaConfigStoreProvider).remover(usuario.id);
      } catch (_) {
        // A exclusão do perfil continua válida mesmo se o keystore estiver
        // temporariamente indisponível.
      }
      await ref.read(authRepositoryProvider).sair();
      if (!mounted) return;
      ref.invalidate(perfilAtualProvider);
      context.go('/login');
    } catch (error) {
      if (!mounted) return;
      setState(() => _excluindoConta = false);
      showContaMensagem(context, _mensagemErro(error));
    }
  }

  void _invalidarDadosDeEstudo() {
    ref
      ..invalidate(perfilAtualProvider)
      ..invalidate(painelProvider)
      ..invalidate(estatisticasDetalhadasProvider)
      ..invalidate(questoesPaginaProvider)
      ..invalidate(totalQuestoesProvider)
      ..invalidate(filtrosSalvosProvider)
      ..invalidate(cadernosProvider)
      ..invalidate(flashcardsDashboardProvider)
      ..invalidate(resumosPorMateriaProvider)
      ..invalidate(editaisProvider)
      ..invalidate(simuladosProvider);
  }
}

class _TituloConta extends StatelessWidget {
  const _TituloConta({required this.colors, required this.responsive});

  final FlashcardsColors colors;
  final Responsive responsive;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: responsive.sp(1)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Configurações',
          style: TextStyle(
            color: colors.text,
            fontSize: responsive.sp(21),
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        SizedBox(height: responsive.sp(3)),
        Text(
          'Gerencie seu perfil, provedores de IA e dados da sua conta.',
          style: TextStyle(
            color: colors.secondary,
            fontSize: responsive.sp(10.5),
            height: 1.4,
          ),
        ),
      ],
    ),
  );
}

class _IdentidadeContaCard extends StatefulWidget {
  const _IdentidadeContaCard({
    required this.colors,
    required this.responsive,
    required this.usuario,
    required this.usernameController,
    required this.salvando,
    required this.onSalvar,
  });

  final FlashcardsColors colors;
  final Responsive responsive;
  final UserProfile usuario;
  final TextEditingController usernameController;
  final bool salvando;
  final VoidCallback onSalvar;

  @override
  State<_IdentidadeContaCard> createState() => _IdentidadeContaCardState();
}

class _IdentidadeContaCardState extends State<_IdentidadeContaCard> {
  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final responsive = widget.responsive;
    final inicial = widget.usuario.username.trim().isEmpty
        ? '?'
        : widget.usuario.username.trim().characters.first.toUpperCase();
    return FlashcardsPanel(
      key: const Key('conta-identidade-card'),
      colors: colors,
      radius: responsive.sp(17),
      padding: EdgeInsets.all(responsive.sp(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: responsive.sp(80),
                height: responsive.sp(80),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6366F1), Color(0xFF2563EB)],
                  ),
                  borderRadius: BorderRadius.circular(responsive.sp(21)),
                  border: Border.all(
                    color: const Color(0xFF818CF8).withValues(alpha: 0.55),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.isDark
                          ? const Color(0x556366F1)
                          : const Color(0x222563EB),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  inicial,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: responsive.sp(31),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(height: responsive.sp(11)),
              Text(
                widget.usuario.username,
                key: const Key('conta-username-heading'),
                style: TextStyle(
                  color: colors.text,
                  fontSize: responsive.sp(16),
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (widget.usuario.email?.isNotEmpty ?? false) ...[
                SizedBox(height: responsive.sp(4)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.email_outlined,
                      color: colors.muted,
                      size: responsive.sp(13),
                    ),
                    SizedBox(width: responsive.sp(5)),
                    Flexible(
                      child: Text(
                        widget.usuario.email!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.secondary,
                          fontSize: responsive.sp(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              SizedBox(height: responsive.sp(8)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.sp(10),
                  vertical: responsive.sp(4),
                ),
                decoration: BoxDecoration(
                  color: colors.accentSoft,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: colors.accentBorder),
                ),
                child: Text(
                  'Aluno',
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: responsive.sp(9.5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: responsive.sp(15)),
            child: Divider(height: 1, color: colors.border),
          ),
          Row(
            children: [
              Container(
                width: responsive.sp(28),
                height: responsive.sp(28),
                decoration: BoxDecoration(
                  color: colors.accentSoft,
                  borderRadius: BorderRadius.circular(responsive.sp(8)),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.badge_outlined,
                  color: colors.accent,
                  size: responsive.sp(16),
                ),
              ),
              SizedBox(width: responsive.sp(8)),
              Expanded(
                child: Text(
                  'Informações de Identidade',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: responsive.sp(12),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.sp(13)),
          _ContaLabel(colors: colors, text: 'NOME DE USUÁRIO'),
          SizedBox(height: responsive.sp(5)),
          TextField(
            key: const Key('conta-username'),
            controller: widget.usernameController,
            textCapitalization: TextCapitalization.none,
            autocorrect: false,
            style: TextStyle(
              color: colors.text,
              fontSize: responsive.sp(11.5),
              fontWeight: FontWeight.w600,
            ),
            decoration: _contaInputDecoration(
              colors,
              responsive,
              hint: 'Nome de usuário',
            ),
          ),
          SizedBox(height: responsive.sp(12)),
          _ContaLabel(colors: colors, text: 'E-MAIL CADASTRADO'),
          SizedBox(height: responsive.sp(5)),
          TextFormField(
            key: const Key('conta-email'),
            enabled: false,
            initialValue: widget.usuario.email ?? '',
            style: TextStyle(
              color: colors.secondary,
              fontSize: responsive.sp(11.5),
            ),
            decoration: _contaInputDecoration(
              colors,
              responsive,
              hint: 'E-mail da conta',
              fillColor: colors.isDark
                  ? const Color(0xFF0B101C)
                  : colors.cardSoft,
            ),
          ),
          SizedBox(height: responsive.sp(14)),
          FilledButton.icon(
            key: const Key('conta-salvar-perfil'),
            onPressed: widget.salvando ? null : widget.onSalvar,
            icon: widget.salvando
                ? SizedBox(
                    width: responsive.sp(15),
                    height: responsive.sp(15),
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(widget.salvando ? 'Salvando...' : 'Salvar Alterações'),
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, responsive.sp(46)),
              textStyle: TextStyle(
                fontSize: responsive.sp(10.5),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiConfiguracaoCard extends ConsumerStatefulWidget {
  const _AiConfiguracaoCard({
    super.key,
    required this.colors,
    required this.responsive,
    required this.idUsuario,
  });

  final FlashcardsColors colors;
  final Responsive responsive;
  final int idUsuario;

  @override
  ConsumerState<_AiConfiguracaoCard> createState() =>
      _AiConfiguracaoCardState();
}

class _AiConfiguracaoCardState extends ConsumerState<_AiConfiguracaoCard> {
  static const _customModel = '__custom__';

  final _apiKeyController = TextEditingController();
  final _customModelController = TextEditingController();
  late String _provedor;
  late String _modelo;
  AiConfig? _config;
  var _carregando = true;
  var _salvando = false;
  var _removendo = false;
  String? _feedback;
  var _feedbackSucesso = false;

  @override
  void initState() {
    super.initState();
    _provedor = AiProviderService.provedores.keys.first;
    _modelo = AiProviderService.provedores[_provedor]!.modeloPadrao;
    _carregarConfiguracao();
  }

  @override
  void didUpdateWidget(covariant _AiConfiguracaoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.idUsuario != widget.idUsuario) _carregarConfiguracao();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _customModelController.dispose();
    super.dispose();
  }

  Future<void> _carregarConfiguracao() async {
    setState(() => _carregando = true);
    try {
      final config = await ref
          .read(iaConfigStoreProvider)
          .ler(widget.idUsuario);
      if (!mounted) return;
      setState(() {
        _config = config;
        if (config != null &&
            AiProviderService.provedores.containsKey(config.provedor)) {
          _provedor = config.provedor;
          final modelos = AiProviderService.provedores[_provedor]!.modelos;
          if (modelos.contains(config.modelo)) {
            _modelo = config.modelo;
            _customModelController.clear();
          } else {
            _modelo = _customModel;
            _customModelController.text = config.modelo;
          }
        }
        _carregando = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _feedback = _mensagemErro(error);
        _feedbackSucesso = false;
      });
    }
  }

  void _trocarProvedor(String? provedor) {
    if (provedor == null ||
        !AiProviderService.provedores.containsKey(provedor)) {
      return;
    }
    setState(() {
      _provedor = provedor;
      _modelo = AiProviderService.provedores[provedor]!.modeloPadrao;
      _customModelController.clear();
      _feedback = null;
    });
  }

  Future<void> _salvarETestar() async {
    if (_salvando) return;
    final info = AiProviderService.provedores[_provedor];
    if (info == null) return;
    final modelo = _modelo == _customModel
        ? _customModelController.text.trim()
        : _modelo;
    if (modelo.isEmpty || modelo.length > 80) {
      setState(() {
        _feedback = 'Informe um modelo válido.';
        _feedbackSucesso = false;
      });
      return;
    }
    final digitada = _apiKeyController.text.trim();
    final chaveSalva = _config?.provedor == _provedor ? _config?.chave : null;
    final chave = digitada.isNotEmpty ? digitada : chaveSalva ?? '';
    if (chave.length < 20) {
      setState(() {
        _feedback = 'Cole uma chave de API válida antes de salvar.';
        _feedbackSucesso = false;
      });
      return;
    }

    setState(() {
      _salvando = true;
      _feedback = null;
    });
    try {
      final teste = await ref
          .read(aiProviderServiceProvider)
          .testarChave(provedor: _provedor, chave: chave, modelo: modelo);
      if (!teste.ok) {
        if (!mounted) return;
        setState(() {
          _feedback = teste.motivo;
          _feedbackSucesso = false;
          _salvando = false;
        });
        return;
      }

      final config = AiConfig(
        provedor: _provedor,
        modelo: modelo,
        chave: chave,
      );
      await ref.read(iaConfigStoreProvider).salvar(widget.idUsuario, config);
      if (!mounted) return;
      setState(() {
        _config = config;
        _modelo =
            AiProviderService.provedores[_provedor]!.modelos.contains(modelo)
            ? modelo
            : _customModel;
        if (_modelo == _customModel) _customModelController.text = modelo;
        _apiKeyController.clear();
        _feedback = 'Chave validada e salva neste dispositivo.';
        _feedbackSucesso = true;
        _salvando = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _feedback = _mensagemErro(error);
        _feedbackSucesso = false;
        _salvando = false;
      });
    }
  }

  Future<void> _removerChave() async {
    if (_config == null || _removendo) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: widget.colors.card,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Remover chave de IA?',
          style: TextStyle(
            color: widget.colors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'A chave salva neste dispositivo será apagada. A geração de novos conteúdos com IA ficará indisponível até configurar outra chave.',
          style: TextStyle(color: widget.colors.secondary, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('conta-ia-remover-confirmar'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: widget.colors.danger,
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 48),
            ),
            child: const Text('Remover chave'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() {
      _removendo = true;
      _feedback = null;
    });
    try {
      await ref.read(iaConfigStoreProvider).remover(widget.idUsuario);
      if (!mounted) return;
      setState(() {
        _config = null;
        _apiKeyController.clear();
        _customModelController.clear();
        _provedor = AiProviderService.provedores.keys.first;
        _modelo = AiProviderService.provedores[_provedor]!.modeloPadrao;
        _feedback = 'A chave de IA foi removida deste dispositivo.';
        _feedbackSucesso = true;
        _removendo = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _feedback = _mensagemErro(error);
        _feedbackSucesso = false;
        _removendo = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final responsive = widget.responsive;
    final provedores = AiProviderService.provedores;
    final info = provedores[_provedor]!;
    final modeloSelecionado = info.modelos.contains(_modelo)
        ? _modelo
        : _customModel;

    return FlashcardsPanel(
      key: const Key('conta-ia-card'),
      colors: colors,
      radius: responsive.sp(17),
      padding: EdgeInsets.all(responsive.sp(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: responsive.sp(30),
                height: responsive.sp(30),
                decoration: BoxDecoration(
                  color: colors.accentSoft,
                  borderRadius: BorderRadius.circular(responsive.sp(9)),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.smart_toy_outlined,
                  color: colors.accent,
                  size: responsive.sp(17),
                ),
              ),
              SizedBox(width: responsive.sp(8)),
              Expanded(
                child: Text(
                  'Inteligência Artificial',
                  style: TextStyle(
                    color: colors.text,
                    fontSize: responsive.sp(12.5),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.sp(7),
                  vertical: responsive.sp(3),
                ),
                decoration: BoxDecoration(
                  color: colors.accentSoft,
                  borderRadius: BorderRadius.circular(responsive.sp(6)),
                  border: Border.all(color: colors.accentBorder),
                ),
                child: Text(
                  'SUA CHAVE, SEU CONTROLE',
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: responsive.sp(7.5),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.sp(13)),
          _AiStatus(
            colors: colors,
            responsive: responsive,
            config: _config,
            loading: _carregando,
          ),
          SizedBox(height: responsive.sp(14)),
          _ContaLabel(colors: colors, text: 'PROVEDOR'),
          SizedBox(height: responsive.sp(5)),
          DropdownButtonFormField<String>(
            key: const Key('conta-ia-provedor'),
            initialValue: _provedor,
            isExpanded: true,
            decoration: _contaInputDecoration(colors, responsive),
            items: [
              for (final entry in provedores.entries)
                DropdownMenuItem(
                  value: entry.key,
                  child: Text(
                    entry.value.nome,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _salvando ? null : _trocarProvedor,
          ),
          SizedBox(height: responsive.sp(11)),
          _ContaLabel(colors: colors, text: 'MODELO'),
          SizedBox(height: responsive.sp(5)),
          DropdownButtonFormField<String>(
            key: ValueKey('conta-ia-modelo-$_provedor-$modeloSelecionado'),
            initialValue: modeloSelecionado,
            isExpanded: true,
            decoration: _contaInputDecoration(colors, responsive),
            items: [
              for (final modelo in info.modelos)
                DropdownMenuItem(
                  value: modelo,
                  child: Text(modelo, overflow: TextOverflow.ellipsis),
                ),
              const DropdownMenuItem(
                value: _customModel,
                child: Text('Outro (personalizado)'),
              ),
            ],
            onChanged: _salvando
                ? null
                : (value) => setState(() {
                    _modelo = value ?? info.modeloPadrao;
                    _feedback = null;
                  }),
          ),
          if (modeloSelecionado == _customModel) ...[
            SizedBox(height: responsive.sp(8)),
            TextField(
              key: const Key('conta-ia-modelo-custom'),
              controller: _customModelController,
              autocorrect: false,
              style: TextStyle(
                color: colors.text,
                fontSize: responsive.sp(10.5),
                fontFamily: 'monospace',
              ),
              decoration: _contaInputDecoration(
                colors,
                responsive,
                hint: 'Digite o identificador do modelo',
              ),
            ),
          ],
          SizedBox(height: responsive.sp(11)),
          _ContaLabel(colors: colors, text: 'CHAVE DE API'),
          SizedBox(height: responsive.sp(5)),
          TextField(
            key: const Key('conta-ia-chave'),
            controller: _apiKeyController,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            style: TextStyle(
              color: colors.text,
              fontSize: responsive.sp(10.5),
              fontFamily: 'monospace',
            ),
            decoration: _contaInputDecoration(
              colors,
              responsive,
              hint: 'Cole sua chave de API aqui',
            ),
          ),
          if (_feedback != null) ...[
            SizedBox(height: responsive.sp(9)),
            _AiFeedback(
              colors: colors,
              responsive: responsive,
              message: _feedback!,
              success: _feedbackSucesso,
            ),
          ],
          SizedBox(height: responsive.sp(11)),
          LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth >= 420;
              final save = FilledButton.icon(
                key: const Key('conta-ia-salvar-testar'),
                onPressed: _salvando ? null : _salvarETestar,
                icon: _salvando
                    ? SizedBox(
                        width: responsive.sp(14),
                        height: responsive.sp(14),
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(_salvando ? 'Validando...' : 'Salvar e Testar'),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: Size(horizontal ? 0 : double.infinity, 46),
                  textStyle: TextStyle(
                    fontSize: responsive.sp(9.5),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
              final remove = OutlinedButton.icon(
                key: const Key('conta-ia-remover'),
                onPressed: _config == null || _removendo ? null : _removerChave,
                icon: _removendo
                    ? SizedBox(
                        width: responsive.sp(14),
                        height: responsive.sp(14),
                        child: CircularProgressIndicator(
                          color: colors.danger,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.delete_outline_rounded),
                label: Text(_removendo ? 'Removendo...' : 'Remover Chave'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.danger,
                  side: BorderSide(
                    color: colors.danger.withValues(alpha: 0.45),
                  ),
                  minimumSize: Size(horizontal ? 0 : double.infinity, 46),
                  textStyle: TextStyle(
                    fontSize: responsive.sp(9),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
              if (horizontal) {
                return Row(
                  children: [
                    Expanded(child: save),
                    SizedBox(width: responsive.sp(8)),
                    Expanded(child: remove),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  save,
                  SizedBox(height: responsive.sp(7)),
                  remove,
                ],
              );
            },
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: responsive.sp(13)),
            child: Divider(height: 1, color: colors.border),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: responsive.sp(15),
                color: colors.secondary,
              ),
              SizedBox(width: responsive.sp(7)),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      color: colors.secondary,
                      fontSize: responsive.sp(9.5),
                      height: 1.45,
                    ),
                    children: const [
                      TextSpan(text: 'Privacidade: sua chave fica salva '),
                      TextSpan(
                        text: 'apenas neste dispositivo',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(
                        text: ' em armazenamento seguro; ela não é enviada ao Supabase.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.sp(8)),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: responsive.sp(6),
            runSpacing: responsive.sp(3),
            children: [
              Text(
                'Como obter uma chave:',
                style: TextStyle(
                  color: colors.secondary,
                  fontSize: responsive.sp(8.5),
                ),
              ),
              for (final entry in provedores.entries)
                TextButton(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: entry.value.linkChave),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text('Link de ${entry.value.nome} copiado.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: colors.accent,
                    padding: EdgeInsets.symmetric(horizontal: responsive.sp(3)),
                    minimumSize: const Size(48, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    entry.value.nome,
                    style: TextStyle(fontSize: responsive.sp(8.5)),
                  ),
                ),
            ],
          ),
          if (_carregando)
            Padding(
              padding: EdgeInsets.only(top: responsive.sp(8)),
              child: LinearProgressIndicator(
                minHeight: 2,
                color: colors.accent,
                backgroundColor: colors.cardSoft,
              ),
            ),
        ],
      ),
    );
  }
}

class _AiStatus extends StatelessWidget {
  const _AiStatus({
    required this.colors,
    required this.responsive,
    required this.config,
    required this.loading,
  });

  final FlashcardsColors colors;
  final Responsive responsive;
  final AiConfig? config;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final provedor = config == null
        ? null
        : AiProviderService.provedores[config!.provedor];
    final ativo = config != null && provedor != null;
    final cor = ativo ? colors.success : colors.accent;
    return Container(
      key: const Key('conta-ia-status'),
      padding: EdgeInsets.all(responsive.sp(10)),
      decoration: BoxDecoration(
        color: ativo ? colors.successSoft : colors.accentSoft,
        borderRadius: BorderRadius.circular(responsive.sp(11)),
        border: Border.all(
          color: ativo
              ? colors.success.withValues(alpha: 0.35)
              : colors.accentBorder,
        ),
      ),
      child: loading
          ? Row(
              children: [
                SizedBox(
                  width: responsive.sp(14),
                  height: responsive.sp(14),
                  child: CircularProgressIndicator(color: cor, strokeWidth: 2),
                ),
                SizedBox(width: responsive.sp(8)),
                Expanded(
                  child: Text(
                    'Carregando configuração local...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.secondary,
                      fontSize: responsive.sp(9.5),
                    ),
                  ),
                ),
              ],
            )
          : ativo
          ? Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: responsive.sp(5),
              runSpacing: responsive.sp(3),
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: cor,
                  size: responsive.sp(14),
                ),
                Text(
                  'Ativa: ${provedor.nome}',
                  style: TextStyle(
                    color: colors.success,
                    fontSize: responsive.sp(9.5),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text('·', style: TextStyle(color: colors.secondary)),
                Text(
                  'modelo ${config!.modelo}',
                  style: TextStyle(
                    color: colors.secondary,
                    fontSize: responsive.sp(8.5),
                  ),
                ),
                Text('·', style: TextStyle(color: colors.secondary)),
                Text(
                  'chave ${IaConfigStore.mascarar(config!.chave)}',
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: responsive.sp(8.5),
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            )
          : Text(
              'Configure sua chave para gerar explicações, resumos e flashcards com IA.',
              style: TextStyle(
                color: colors.secondary,
                fontSize: responsive.sp(9.5),
                height: 1.4,
              ),
            ),
    );
  }
}

class _AiFeedback extends StatelessWidget {
  const _AiFeedback({
    required this.colors,
    required this.responsive,
    required this.message,
    required this.success,
  });

  final FlashcardsColors colors;
  final Responsive responsive;
  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final color = success ? colors.success : colors.danger;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          success
              ? Icons.check_circle_outline_rounded
              : Icons.error_outline_rounded,
          color: color,
          size: responsive.sp(15),
        ),
        SizedBox(width: responsive.sp(6)),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: color,
              fontSize: responsive.sp(9.5),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _ZonaResetCard extends StatelessWidget {
  const _ZonaResetCard({
    required this.colors,
    required this.responsive,
    required this.executando,
    required this.onResetar,
  });

  final FlashcardsColors colors;
  final Responsive responsive;
  final bool executando;
  final VoidCallback onResetar;

  @override
  Widget build(BuildContext context) {
    final amber = const Color(0xFFF59E0B);
    return Container(
      key: const Key('conta-reset-dados-card'),
      padding: EdgeInsets.all(responsive.sp(15)),
      decoration: BoxDecoration(
        color: colors.isDark
            ? const Color(0xFF15140F)
            : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(responsive.sp(16)),
        border: Border.all(color: amber.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DangerBadge(
            colors: colors,
            responsive: responsive,
            label: 'ZERAR DADOS',
            icon: Icons.restart_alt_rounded,
            tone: amber,
          ),
          SizedBox(height: responsive.sp(9)),
          Text(
            'Resetar Dados de Estudo',
            style: TextStyle(
              color: colors.isDark
                  ? const Color(0xFFFBBF24)
                  : const Color(0xFF92400E),
              fontSize: responsive.sp(13),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: responsive.sp(4)),
          Text(
            'Zera o progresso, histórico, cadernos, flashcards, simulados e editais. Sua conta permanece ativa.',
            style: TextStyle(
              color: colors.secondary,
              fontSize: responsive.sp(10),
              height: 1.45,
            ),
          ),
          SizedBox(height: responsive.sp(12)),
          OutlinedButton.icon(
            key: const Key('conta-resetar-dados'),
            onPressed: executando ? null : onResetar,
            icon: executando
                ? SizedBox(
                    width: responsive.sp(15),
                    height: responsive.sp(15),
                    child: CircularProgressIndicator(
                      color: amber,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.restart_alt_rounded),
            label: Text(executando ? 'Resetando...' : 'Resetar Dados'),
            style: OutlinedButton.styleFrom(
              foregroundColor: amber,
              side: BorderSide(color: amber.withValues(alpha: 0.6)),
              minimumSize: Size(double.infinity, responsive.sp(46)),
              textStyle: TextStyle(
                fontSize: responsive.sp(10),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZonaExcluirContaCard extends StatelessWidget {
  const _ZonaExcluirContaCard({
    required this.colors,
    required this.responsive,
    required this.executando,
    required this.onExcluir,
  });

  final FlashcardsColors colors;
  final Responsive responsive;
  final bool executando;
  final VoidCallback onExcluir;

  @override
  Widget build(BuildContext context) {
    final danger = colors.danger;
    return Container(
      key: const Key('conta-zona-risco-card'),
      padding: EdgeInsets.all(responsive.sp(15)),
      decoration: BoxDecoration(
        color: colors.dangerSoft.withValues(alpha: colors.isDark ? 0.45 : 0.65),
        borderRadius: BorderRadius.circular(responsive.sp(16)),
        border: Border.all(color: colors.danger.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DangerBadge(
            colors: colors,
            responsive: responsive,
            label: 'ZONA DE RISCO',
            icon: Icons.warning_amber_rounded,
            tone: danger,
          ),
          SizedBox(height: responsive.sp(9)),
          Text(
            'Encerrar Minha Conta',
            style: TextStyle(
              color: danger,
              fontSize: responsive.sp(13),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: responsive.sp(4)),
          Text(
            'Remove seu perfil e dados de desempenho, simulados e progresso nos editais. Esta ação não pode ser desfeita.',
            style: TextStyle(
              color: colors.secondary,
              fontSize: responsive.sp(10),
              height: 1.45,
            ),
          ),
          SizedBox(height: responsive.sp(12)),
          FilledButton.icon(
            key: const Key('conta-excluir'),
            onPressed: executando ? null : onExcluir,
            icon: executando
                ? SizedBox(
                    width: responsive.sp(15),
                    height: responsive.sp(15),
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.delete_outline_rounded),
            label: Text(executando ? 'Excluindo...' : 'Excluir Conta'),
            style: FilledButton.styleFrom(
              backgroundColor: colors.danger,
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, responsive.sp(46)),
              textStyle: TextStyle(
                fontSize: responsive.sp(10),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DangerBadge extends StatelessWidget {
  const _DangerBadge({
    required this.colors,
    required this.responsive,
    required this.label,
    required this.icon,
    required this.tone,
  });

  final FlashcardsColors colors;
  final Responsive responsive;
  final String label;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.sp(8),
        vertical: responsive.sp(3),
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: responsive.sp(10), color: tone),
          SizedBox(width: responsive.sp(4)),
          Text(
            label,
            style: TextStyle(
              color: tone,
              fontSize: responsive.sp(8),
              fontWeight: FontWeight.w900,
              letterSpacing: 0.35,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ConfirmacaoDigitadaDialog extends StatefulWidget {
  const _ConfirmacaoDigitadaDialog({
    required this.colors,
    required this.icon,
    required this.title,
    required this.description,
    required this.detalhes,
    required this.phrase,
    required this.confirmLabel,
    required this.confirmColor,
    required this.confirmKey,
  });

  final FlashcardsColors colors;
  final IconData icon;
  final String title;
  final String description;
  final List<String> detalhes;
  final String phrase;
  final String confirmLabel;
  final Color confirmColor;
  final Key confirmKey;

  @override
  State<_ConfirmacaoDigitadaDialog> createState() =>
      _ConfirmacaoDigitadaDialogState();
}

class _ConfirmacaoDigitadaDialogState
    extends State<_ConfirmacaoDigitadaDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final responsive = Responsive.of(context);
    final correto = _controller.text.trim().toUpperCase() == widget.phrase;
    return AlertDialog(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      icon: Icon(widget.icon, color: widget.confirmColor, size: 32),
      title: Text(
        widget.title,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: colors.text,
          fontSize: responsive.sp(16),
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.secondary,
                  fontSize: responsive.sp(10.5),
                  height: 1.45,
                ),
              ),
              if (widget.detalhes.isNotEmpty) ...[
                SizedBox(height: responsive.sp(11)),
                for (final detalhe in widget.detalhes)
                  Padding(
                    padding: EdgeInsets.only(bottom: responsive.sp(5)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.remove_circle_outline_rounded,
                          size: responsive.sp(13),
                          color: widget.confirmColor,
                        ),
                        SizedBox(width: responsive.sp(6)),
                        Expanded(
                          child: Text(
                            detalhe,
                            style: TextStyle(
                              color: colors.secondary,
                              fontSize: responsive.sp(9.5),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              SizedBox(height: responsive.sp(8)),
              Text(
                'Digite exatamente: ${widget.phrase}',
                style: TextStyle(
                  color: colors.secondary,
                  fontSize: responsive.sp(9),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: responsive.sp(5)),
              TextField(
                key: const Key('conta-confirmacao-frase'),
                controller: _controller,
                autocorrect: false,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
                style: TextStyle(
                  color: colors.text,
                  fontSize: responsive.sp(10.5),
                  fontWeight: FontWeight.w700,
                ),
                decoration: _contaInputDecoration(
                  colors,
                  responsive,
                  hint: widget.phrase,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: widget.confirmKey,
          onPressed: correto ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: widget.confirmColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: colors.cardSoft,
            minimumSize: const Size(48, 48),
          ),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

class _ContaEstadoErro extends StatelessWidget {
  const _ContaEstadoErro({
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
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: responsive.pagePadding,
      child: FlashcardsPanel(
        colors: colors,
        padding: EdgeInsets.all(responsive.sp(22)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, color: colors.muted, size: 34),
            SizedBox(height: responsive.sp(10)),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.text,
                fontSize: responsive.sp(12),
                height: 1.45,
              ),
            ),
            SizedBox(height: responsive.sp(12)),
            FilledButton(
              key: const Key('conta-tentar-novamente'),
              onPressed: onTentar,
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
              ),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ContaLabel extends StatelessWidget {
  const _ContaLabel({required this.colors, required this.text});

  final FlashcardsColors colors;
  final String text;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return Text(
      text,
      style: TextStyle(
        color: colors.secondary,
        fontSize: responsive.sp(8.5),
        fontWeight: FontWeight.w900,
        letterSpacing: 0.45,
      ),
    );
  }
}

InputDecoration _contaInputDecoration(
  FlashcardsColors colors,
  Responsive responsive, {
  String? hint,
  Color? fillColor,
}) => InputDecoration(
  hintText: hint,
  hintStyle: TextStyle(color: colors.muted, fontSize: responsive.sp(10)),
  filled: true,
  fillColor: fillColor ?? colors.cardSoft,
  contentPadding: EdgeInsets.symmetric(
    horizontal: responsive.sp(12),
    vertical: responsive.sp(11),
  ),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(responsive.sp(11)),
    borderSide: BorderSide(color: colors.border),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(responsive.sp(11)),
    borderSide: BorderSide(color: colors.border),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(responsive.sp(11)),
    borderSide: BorderSide(color: colors.accent, width: 1.4),
  ),
  disabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(responsive.sp(11)),
    borderSide: BorderSide(color: colors.border),
  ),
);

String _mensagemErro(Object? error) {
  if (error is AppException) return error.message;
  if (error is StateError) {
    return 'Sua sessão não está disponível. Entre novamente.';
  }
  return 'Não foi possível concluir a operação. Tente novamente.';
}

void showContaMensagem(BuildContext context, String mensagem) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(mensagem),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
}
