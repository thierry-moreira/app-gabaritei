import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/errors/app_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../../core/ui/responsive.dart';
import '../../models/question.dart';
import '../../models/study.dart';
import '../../models/taxonomy.dart';
import '../../repositories/study_ai_repository.dart';
import '../../repositories/taxonomy_repository.dart';
import '../../services/filter_service.dart';
import '../../services/study_ai_service.dart';
import '../widgets/blockquote_view.dart';
import '../widgets/code_block_view.dart';
import '../widgets/latex_text.dart';
import '../widgets/question_image.dart';
import 'dashboard_shell.dart';

/// Tela de resolução de questões - Gabaritei Questões.
///
/// Reproduz o layout mobile do Stitch (tema claro e escuro) e usa os mesmos
/// repositórios do app desktop: listagem paginada com filtros, correção da
/// resposta, comentários, explicação por IA, cadernos e reportes.
class QuestoesScreen extends ConsumerStatefulWidget {
  const QuestoesScreen({super.key});

  @override
  ConsumerState<QuestoesScreen> createState() => _QuestoesScreenState();
}

class _QuestoesScreenState extends ConsumerState<QuestoesScreen> {
  final _scrollController = ScrollController();

  late int _indice;
  bool _filtrosAbertos = false;

  /// Rascunho dos filtros enquanto o painel avançado está aberto. Só vai para
  /// o provider quando o aluno toca em "Aplicar filtros".
  QuestaoFiltros _filtrosDraft = const QuestaoFiltros();

  /// Muda quando os filtros são limpos por fora do painel para que o painel
  /// sincronize o campo de ID e as buscas internas.
  int _filtrosResetToken = 0;

  String? _letraSelecionada;
  RespostaQuestaoResultado? _resultado;
  bool _enviando = false;
  _AnnotationTool? _annotationTool;
  final Map<int, List<_AnnotationStroke>> _annotationsByQuestion = {};
  final Map<int, Set<String>> _eliminatedAlternativesByQuestion = {};

  String? _explicacao;
  String? _erroExplicacao;
  bool _carregandoExplicacao = false;

  /// A resolução só aparece depois que o aluno toca em "IA Explica": exibir
  /// o comentário do gabarito junto com o enunciado entregaria a resposta
  /// antes de ele responder.
  bool _explicacaoVisivel = false;

  @override
  void initState() {
    super.initState();
    _indice = ref.read(questoesIndiceProvider);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _QuestoesColors.of(isDark);

    final perfil = ref.watch(perfilAtualProvider);
    final painel = ref.watch(painelProvider);
    final filtros = ref.watch(questoesFiltrosProvider);
    final pagina = ref.watch(questoesPaginaProvider);
    final filtrosSalvos = ref.watch(filtrosSalvosProvider);
    final taxonomia = ref.watch(taxonomyCatalogProvider);

    ref.listen(questoesFiltrosProvider, (anterior, atual) {
      if (!mounted) return;
      setState(() {
        _indice = 0;
        _reiniciarQuestao();
      });
      ref.read(questoesIndiceProvider.notifier).resetar();
      _voltarAoTopo();
    });

    final nomeMateria = _nomeMateriaSelecionada(filtros, taxonomia.value);

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
                controller: _scrollController,
                physics: _annotationTool == null
                    ? const AlwaysScrollableScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                padding: responsive.pagePadding.copyWith(bottom: 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: responsive.questionsMaxWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Breadcrumbs(
                          colors: colors,
                          responsive: responsive,
                          nomeMateria: nomeMateria,
                          onInicio: () => context.go('/home'),
                        ),
                        SizedBox(height: responsive.sp(10)),
                        _BankBanner(
                          colors: colors,
                          responsive: responsive,
                          total: pagina.value?.total,
                          temFiltros: filtros.temFiltros,
                        ),
                        SizedBox(height: responsive.sp(12)),
                        _AdvancedFiltersCard(
                          colors: colors,
                          responsive: responsive,
                          aberto: _filtrosAbertos,
                          taxonomia: taxonomia,
                          filtros: _filtrosDraft,
                          resetToken: _filtrosResetToken,
                          onToggle: _alternarFiltros,
                          onChanged: (novos) =>
                              setState(() => _filtrosDraft = novos),
                          onLimpar: _limparFiltros,
                          onAplicar: _aplicarFiltros,
                          onSalvar: () => _salvarFiltro(filtros: _filtrosDraft),
                        ),
                        SizedBox(height: responsive.sp(10)),
                        _SavedFiltersBar(
                          colors: colors,
                          responsive: responsive,
                          temFiltros: filtros.temFiltros,
                          onLimpar: _limparFiltros,
                          onSalvar: () => _salvarFiltro(
                            filtros: _filtrosAbertos ? _filtrosDraft : null,
                          ),
                        ),
                        if (filtrosSalvos.value?.isNotEmpty ?? false) ...[
                          SizedBox(height: responsive.sp(8)),
                          _SavedFiltersChips(
                            colors: colors,
                            filtros: filtrosSalvos.requireValue,
                            onAplicar: _aplicarFiltroSalvo,
                            onExcluir: _excluirFiltroSalvo,
                          ),
                        ],
                        SizedBox(height: responsive.gap),
                        _buildConteudo(
                          colors: colors,
                          responsive: responsive,
                          pagina: pagina,
                        ),
                        SizedBox(height: responsive.gap),
                        _Footer(colors: colors, responsive: responsive),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          DashboardBottomNav(
            isDark: isDark,
            selectedIndex: 1,
            onSelected: _onBottomNavSelected,
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Conteúdo
  // -------------------------------------------------------------------------

  Widget _buildConteudo({
    required _QuestoesColors colors,
    required Responsive responsive,
    required AsyncValue<PaginaQuestoes> pagina,
  }) {
    if (pagina.hasValue) {
      final dados = pagina.requireValue;
      if (dados.questoes.isEmpty) {
        return _EmptyCard(
          colors: colors,
          responsive: responsive,
          onLimpar: _limparFiltros,
        );
      }

      final indice = _indice.clamp(0, dados.questoes.length - 1);
      final questao = dados.questoes[indice];
      final status = _resultado != null
          ? _resultado!.correta
          : dados.statusDaQuestao(questao.id);
      final comentario = _comentarioUtil(
        _resultado?.comentario ?? questao.comentarioGabarito,
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _QuestionCard(
            colors: colors,
            responsive: responsive,
            questao: questao,
            status: status,
            letraSelecionada: _letraSelecionada,
            resultado: _resultado,
            enviando: _enviando,
            annotationTool: _annotationTool,
            annotationStrokes:
                _annotationsByQuestion[questao.id] ??
                const <_AnnotationStroke>[],
            eliminatedAlternatives:
                _eliminatedAlternativesByQuestion[questao.id] ??
                const <String>{},
            onAnnotationToolSelected: _selecionarFerramentaAnotacao,
            onAnnotationStrokeAdded: (stroke) =>
                _adicionarAnotacao(questao.id, stroke),
            onEraseAnnotation: (points, size) =>
                _apagarAnotacoes(questao.id, points, size),
            onToggleAlternativeEliminated: (letra) =>
                _alternarAlternativaEliminada(questao.id, letra),
            onSelecionar: (letra) => setState(() => _letraSelecionada = letra),
            onResponder: () => _responder(questao),
            onComentarios: () => _abrirComentarios(questao, comentario),
            onIaExplica: () => _gerarExplicacao(questao),
            onSalvarCaderno: () => _salvarEmCaderno(questao),
            onGerarResumo: () => _gerarEstudo(questao, StudyContentType.resumo),
            onCriarFlashcard: () =>
                _gerarEstudo(questao, StudyContentType.flashcard),
            onReportar: () => _reportar(questao),
          ),
          SizedBox(height: responsive.sp(10)),
          _QuestionNavigator(
            colors: colors,
            responsive: responsive,
            indice: indice,
            totalNaPagina: dados.questoes.length,
            pagina: dados.pagina,
            totalPaginas: dados.totalPaginas,
            onAnterior: _anterior,
            onProxima: _proxima,
            onIrParaPagina: () => _irParaPagina(dados),
          ),
          if (_explicacaoVisivel) ...[
            SizedBox(height: responsive.sp(12)),
            _ExplanationCard(
              colors: colors,
              responsive: responsive,
              carregando: _carregandoExplicacao,
              explicacao: _explicacao,
              erro: _erroExplicacao,
              comentarioGabarito: comentario,
              onGerar: () => _gerarExplicacao(questao),
              onFechar: () => setState(() => _explicacaoVisivel = false),
              onReportar: _explicacao == null
                  ? null
                  : () => _reportarExplicacao(questao),
            ),
          ],
        ],
      );
    }

    if (pagina.hasError) {
      return _ErrorCard(
        colors: colors,
        responsive: responsive,
        erro: pagina.error,
        onTentarNovamente: () => ref.invalidate(questoesPaginaProvider),
      );
    }

    return _LoadingCard(colors: colors, responsive: responsive);
  }

  // -------------------------------------------------------------------------
  // Ações
  // -------------------------------------------------------------------------

  Future<void> _recarregar() async {
    ref.invalidate(totalQuestoesProvider);
    ref.invalidate(taxonomyCatalogProvider);
    ref.invalidate(filtrosSalvosProvider);
    ref.invalidate(questoesPaginaProvider);
    await ref.read(questoesPaginaProvider.future);
  }

  Future<void> _responder(Questao questao) async {
    final letra = _letraSelecionada;
    if (letra == null || _enviando) return;

    final perfil = await ref.read(perfilAtualProvider.future);
    if (!mounted) return;
    if (perfil == null) {
      _mostrarMensagem('Sessão expirada. Entre novamente.');
      return;
    }

    setState(() => _enviando = true);
    try {
      final resultado = await ref
          .read(questionRepositoryProvider)
          .responder(idUsuario: perfil.id, idQuestao: questao.id, letra: letra);
      if (!mounted) return;
      setState(() {
        _resultado = resultado;
        _enviando = false;
        _eliminatedAlternativesByQuestion.remove(questao.id);
      });
      ref.invalidate(painelProvider);
      ref.invalidate(estatisticasDetalhadasProvider);
    } catch (error) {
      if (!mounted) return;
      setState(() => _enviando = false);
      _mostrarMensagem(_mensagemErro(error));
    }
  }

  Future<void> _gerarExplicacao(Questao questao) async {
    setState(() => _explicacaoVisivel = true);
    if (_explicacao != null || _carregandoExplicacao) return;

    final perfil = await ref.read(perfilAtualProvider.future);
    if (!mounted) return;
    if (perfil == null) {
      _mostrarMensagem('Sessão expirada. Entre novamente.');
      return;
    }

    setState(() {
      _carregandoExplicacao = true;
      _erroExplicacao = null;
    });

    try {
      final texto = await ref
          .read(studyAiRepositoryProvider)
          .explicacao(idQuestao: questao.id, idUsuario: perfil.id);
      if (!mounted) return;
      setState(() {
        _explicacao = texto;
        _carregandoExplicacao = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _erroExplicacao = _mensagemErro(error);
        _carregandoExplicacao = false;
      });
    }
  }

  Future<void> _gerarEstudo(Questao questao, StudyContentType tipo) async {
    final perfil = await ref.read(perfilAtualProvider.future);
    if (!mounted) return;
    if (perfil == null) {
      _mostrarMensagem('Sessão expirada. Entre novamente.');
      return;
    }

    final colors = _QuestoesColors.of(
      Theme.of(context).brightness == Brightness.dark,
    );
    final isResumo = tipo == StudyContentType.resumo;
    var progressoAberto = true;
    final progresso = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: colors.card,
          content: Row(
            children: [
              CircularProgressIndicator(color: colors.primary),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isResumo ? 'Gerando resumo...' : 'Criando flashcard...',
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      isResumo
                          ? 'A IA está preparando um ponto de revisão para seu caderno.'
                          : 'A IA está formulando um card de memorização.',
                      style: TextStyle(
                        color: colors.secondary,
                        fontSize: 12,
                        height: 1.4,
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
    Future<void> fecharProgresso() async {
      if (progressoAberto && mounted) {
        progressoAberto = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
      await progresso;
    }

    try {
      final geracao = await ref
          .read(studyAiRepositoryProvider)
          .gerarEstudo(idQuestao: questao.id, idUsuario: perfil.id, tipo: tipo);
      if (!mounted) {
        await fecharProgresso();
        return;
      }
      await fecharProgresso();
      if (!mounted) return;

      if (isResumo) {
        ref.invalidate(resumosPorMateriaProvider);
      } else {
        ref.invalidate(flashcardsDashboardProvider);
      }

      final verConteudo = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => _EstudoGeradoDialog(
          colors: colors,
          tipo: tipo,
          jaPossuia: geracao.jaPossuia,
          mensagem:
              geracao.mensagem ??
              (isResumo
                  ? 'O ponto de revisão foi salvo no seu Caderno de Resumos.'
                  : 'O card foi salvo na categoria da matéria.'),
        ),
      );
      if (!mounted || verConteudo != true) return;
      context.go(isResumo ? '/resumos' : '/flashcards');
    } catch (error) {
      if (!mounted) return;
      await fecharProgresso();
      if (!mounted) return;
      _mostrarMensagem(_mensagemErro(error));
    }
  }

  Future<void> _abrirComentarios(
    Questao questao,
    String? comentarioProfessor,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _QuestoesColors.of(
        Theme.of(context).brightness == Brightness.dark,
      ).card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => _CommentsSheet(
        idQuestao: questao.id,
        comentarioProfessor: comentarioProfessor,
      ),
    );
    if (!mounted) return;
    ref.invalidate(questoesPaginaProvider);
  }

  Future<void> _salvarEmCaderno(Questao questao) async {
    final perfil = await ref.read(perfilAtualProvider.future);
    if (!mounted) return;
    if (perfil == null) {
      _mostrarMensagem('Sessão expirada. Entre novamente.');
      return;
    }

    final colors = _QuestoesColors.of(
      Theme.of(context).brightness == Brightness.dark,
    );

    List<Caderno> cadernos;
    try {
      cadernos = await ref.read(cadernoRepositoryProvider).listar(perfil.id);
    } catch (error) {
      if (!mounted) return;
      _mostrarMensagem(_mensagemErro(error));
      return;
    }
    if (!mounted) return;

    final escolha = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.card,
        scrollable: true,
        title: Text(
          'Salvar em um caderno',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final caderno in cadernos)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.book_outlined,
                      color: colors.primary,
                      size: 20,
                    ),
                    title: Text(
                      caderno.nome,
                      style: TextStyle(fontSize: 13, color: colors.text),
                    ),
                    onTap: () => Navigator.of(dialogContext).pop(caderno.id),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.add_rounded,
                    color: colors.success,
                    size: 20,
                  ),
                  title: Text(
                    'Novo caderno',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.success,
                    ),
                  ),
                  onTap: () => Navigator.of(dialogContext).pop(''),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (escolha == null || !mounted) return;

    var idCaderno = escolha;
    if (idCaderno.isEmpty) {
      final nome = await _pedirTexto(
        titulo: 'Novo caderno',
        dica: 'Nome do caderno',
        confirmar: 'Criar',
      );
      if (nome == null || nome.isEmpty || !mounted) return;
      try {
        final novo = await ref
            .read(cadernoRepositoryProvider)
            .criar(idUsuario: perfil.id, nome: nome);
        idCaderno = novo.id;
        ref.invalidate(cadernosProvider);
      } catch (error) {
        if (!mounted) return;
        _mostrarMensagem(_mensagemErro(error));
        return;
      }
    }

    try {
      await ref
          .read(cadernoRepositoryProvider)
          .salvarQuestao(
            idCaderno: idCaderno,
            idUsuario: perfil.id,
            idQuestao: questao.id,
          );
      ref.invalidate(cadernosProvider);
      ref.invalidate(cadernoDetalheProvider);
      if (!mounted) return;
      _mostrarMensagem('Questão salva no caderno.');
    } catch (error) {
      if (!mounted) return;
      _mostrarMensagem(_mensagemErro(error));
    }
  }

  Future<void> _reportar(Questao questao) async {
    final colors = _QuestoesColors.of(
      Theme.of(context).brightness == Brightness.dark,
    );

    final feedback = await showDialog<_QuestionFeedback>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _QuestionFeedbackDialog(colors: colors),
    );
    if (feedback == null || !mounted) return;

    try {
      await ref
          .read(questionRepositoryProvider)
          .enviarFeedback(
            idQuestao: questao.id,
            tipoErro: feedback.tipoErro,
            descricao: feedback.descricao,
          );
      if (!mounted) return;
      _mostrarMensagem('Obrigado! Sua denúncia foi registrada.');
    } catch (error) {
      if (!mounted) return;
      _mostrarMensagem(_mensagemErro(error));
    }
  }

  Future<void> _reportarExplicacao(Questao questao) async {
    final colors = _QuestoesColors.of(
      Theme.of(context).brightness == Brightness.dark,
    );
    final feedback = await showDialog<_ExplanationFeedback>(
      context: context,
      builder: (_) => _ExplanationFeedbackDialog(colors: colors),
    );
    if (feedback == null || !mounted) return;

    try {
      await ref
          .read(studyAiRepositoryProvider)
          .enviarFeedback(
            idQuestao: questao.id,
            tipo: 'explicacao',
            motivo: feedback.motivo,
            relato: feedback.relato,
          );
      if (!mounted) return;
      _mostrarMensagem('Obrigado! Vamos analisar e corrigir o conteúdo.');
    } catch (error) {
      if (!mounted) return;
      _mostrarMensagem(_mensagemErro(error));
    }
  }

  Future<void> _salvarFiltro({QuestaoFiltros? filtros}) async {
    final QuestaoFiltros alvo = filtros ?? ref.read(questoesFiltrosProvider);
    if (!alvo.temFiltros) {
      _mostrarMensagem('Aplique ao menos um filtro antes de salvar.');
      return;
    }

    final perfil = await ref.read(perfilAtualProvider.future);
    if (!mounted) return;
    if (perfil == null) {
      _mostrarMensagem('Sessão expirada. Entre novamente.');
      return;
    }

    final nome = await _pedirTexto(
      titulo: 'Salvar filtro',
      dica: 'Ex.: Informática • Idecan',
      confirmar: 'Salvar',
    );
    if (nome == null || nome.isEmpty || !mounted) return;

    try {
      await ref
          .read(filtroRepositoryProvider)
          .salvar(
            idUsuario: perfil.id,
            nome: nome,
            urlParams: alvo.copyWith(pagina: 1).toQueryString(),
          );
      if (!mounted) return;
      ref.invalidate(filtrosSalvosProvider);
      _mostrarMensagem('Filtro "$nome" salvo.');
    } catch (error) {
      if (!mounted) return;
      _mostrarMensagem(_mensagemErro(error));
    }
  }

  void _aplicarFiltroSalvo(FiltroSalvo filtro) {
    final novos = QuestaoFiltros.fromQueryString(filtro.urlParams);
    ref.read(questoesFiltrosProvider.notifier).atualizar(novos);
    setState(() {
      _filtrosDraft = novos.copyWith(pagina: 1);
      _filtrosAbertos = false;
    });
  }

  Future<void> _excluirFiltroSalvo(FiltroSalvo filtro) async {
    final perfil = await ref.read(perfilAtualProvider.future);
    if (!mounted || perfil == null) return;
    try {
      await ref
          .read(filtroRepositoryProvider)
          .excluir(idFiltro: filtro.id, idUsuario: perfil.id);
      if (!mounted) return;
      ref.invalidate(filtrosSalvosProvider);
    } catch (error) {
      if (!mounted) return;
      _mostrarMensagem(_mensagemErro(error));
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
    ref.read(questoesIndiceProvider.notifier).resetar();
    context.go('/login');
  }

  // -------------------------------------------------------------------------
  // Filtros e navegação
  // -------------------------------------------------------------------------

  void _alternarFiltros() {
    final atual = ref.read(questoesFiltrosProvider);
    setState(() {
      _filtrosAbertos = !_filtrosAbertos;
      if (_filtrosAbertos) {
        _filtrosDraft = atual.copyWith(pagina: 1);
      }
    });
  }

  void _aplicarFiltros() {
    ref
        .read(questoesFiltrosProvider.notifier)
        .atualizar(_filtrosDraft.copyWith(pagina: 1));
    setState(() => _filtrosAbertos = false);
  }

  void _limparFiltros() {
    ref.read(questoesFiltrosProvider.notifier).limpar();
    setState(() {
      _filtrosDraft = const QuestaoFiltros();
      _filtrosResetToken++;
    });
  }

  void _anterior() {
    final dados = ref.read(questoesPaginaProvider).value;
    if (dados == null || dados.questoes.isEmpty) return;

    if (_indice > 0) {
      setState(() {
        _indice -= 1;
        _reiniciarQuestao();
      });
      ref.read(questoesIndiceProvider.notifier).definir(_indice);
      _voltarAoTopo();
      return;
    }

    if (dados.pagina > 1) {
      _mudarPagina(dados.pagina - 1);
    }
  }

  void _proxima() {
    final dados = ref.read(questoesPaginaProvider).value;
    if (dados == null || dados.questoes.isEmpty) return;

    if (_indice < dados.questoes.length - 1) {
      setState(() {
        _indice += 1;
        _reiniciarQuestao();
      });
      ref.read(questoesIndiceProvider.notifier).definir(_indice);
      _voltarAoTopo();
      return;
    }

    if (dados.temProxima) {
      _mudarPagina(dados.pagina + 1);
    }
  }

  Future<void> _irParaPagina(PaginaQuestoes dados) async {
    if (dados.totalPaginas <= 1) return;
    final pagina = await showDialog<int>(
      context: context,
      builder: (_) => _PageJumpDialog(
        colors: _QuestoesColors.of(
          Theme.of(context).brightness == Brightness.dark,
        ),
        paginaAtual: dados.pagina,
        totalPaginas: dados.totalPaginas,
      ),
    );
    if (pagina == null || !mounted || pagina == dados.pagina) return;
    _mudarPagina(pagina);
  }

  void _mudarPagina(int pagina) {
    setState(() {
      _indice = 0;
      _reiniciarQuestao();
    });
    ref.read(questoesIndiceProvider.notifier).resetar();
    ref.read(questoesFiltrosProvider.notifier).irParaPagina(pagina);
    _voltarAoTopo();
  }

  void _onBottomNavSelected(int index) {
    switch (index) {
      case 0:
        context.go('/home');
      case 1:
        return;
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
        _mostrarMensagem(
          '${DashboardBottomNav.labelFor(index)} chega em breve.',
        );
    }
  }

  void _reiniciarQuestao() {
    _letraSelecionada = null;
    _resultado = null;
    _enviando = false;
    _annotationTool = null;
    _explicacao = null;
    _erroExplicacao = null;
    _carregandoExplicacao = false;
    _explicacaoVisivel = false;
  }

  void _selecionarFerramentaAnotacao(_AnnotationTool tool) {
    setState(() {
      _annotationTool = _annotationTool == tool ? null : tool;
    });
  }

  void _adicionarAnotacao(int idQuestao, _AnnotationStroke stroke) {
    setState(() {
      _annotationsByQuestion[idQuestao] = [
        ...?_annotationsByQuestion[idQuestao],
        stroke,
      ];
    });
  }

  void _apagarAnotacoes(
    int idQuestao,
    List<Offset> caminhoBorracha,
    Size tamanhoSuperficie,
  ) {
    final existentes = _annotationsByQuestion[idQuestao];
    if (existentes == null || existentes.isEmpty || caminhoBorracha.isEmpty) {
      return;
    }
    const raio = 22.0;
    final restantes = existentes
        .where((stroke) {
          final raioStroke =
              raio + (stroke.tool == _AnnotationTool.highlighter ? 8 : 2);
          return !stroke.points.any((point) {
            final localStroke = Offset(
              point.dx * tamanhoSuperficie.width,
              point.dy * tamanhoSuperficie.height,
            );
            return caminhoBorracha.any((erasePoint) {
              final localEraser = Offset(
                erasePoint.dx * tamanhoSuperficie.width,
                erasePoint.dy * tamanhoSuperficie.height,
              );
              return (localStroke - localEraser).distance <= raioStroke;
            });
          });
        })
        .toList(growable: false);
    if (restantes.length == existentes.length) return;
    setState(() {
      if (restantes.isEmpty) {
        _annotationsByQuestion.remove(idQuestao);
      } else {
        _annotationsByQuestion[idQuestao] = restantes;
      }
    });
  }

  void _alternarAlternativaEliminada(int idQuestao, String letra) {
    if (_resultado != null || _enviando) return;
    setState(() {
      final eliminadas = <String>{
        ...?_eliminatedAlternativesByQuestion[idQuestao],
      };
      if (eliminadas.remove(letra)) {
        if (eliminadas.isEmpty) {
          _eliminatedAlternativesByQuestion.remove(idQuestao);
        } else {
          _eliminatedAlternativesByQuestion[idQuestao] = eliminadas;
        }
        return;
      }

      eliminadas.add(letra);
      _eliminatedAlternativesByQuestion[idQuestao] = eliminadas;
      if (_letraSelecionada == letra) _letraSelecionada = null;
    });
  }

  void _voltarAoTopo() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  String? _nomeMateriaSelecionada(
    QuestaoFiltros filtros,
    TaxonomyCatalog? catalogo,
  ) {
    if (filtros.idsMaterias.isEmpty || catalogo == null) return null;
    final id = filtros.idsMaterias.first;
    for (final materia in catalogo.materias) {
      if (materia.id == id) return materia.nome;
    }
    return null;
  }

  Future<String?> _pedirTexto({
    required String titulo,
    required String dica,
    required String confirmar,
  }) async {
    final colors = _QuestoesColors.of(
      Theme.of(context).brightness == Brightness.dark,
    );
    final controller = TextEditingController();
    final resultado = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.card,
        title: Text(
          titulo,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(fontSize: 14, color: colors.text),
          decoration: InputDecoration(hintText: dica),
          onSubmitted: (valor) => Navigator.of(dialogContext).pop(valor.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(confirmar),
          ),
        ],
      ),
    );
    controller.dispose();
    return resultado;
  }

  void _mostrarMensagem(String mensagem) {
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
// Paleta
// ---------------------------------------------------------------------------

/// Cores da tela de questões nos temas claro e escuro, seguindo os tokens do
/// Stitch (fundo escuro azulado, cards slate e acentos índigo/azul).
class _QuestoesColors {
  const _QuestoesColors({
    required this.isDark,
    required this.bg,
    required this.card,
    required this.cardInner,
    required this.border,
    required this.borderSoft,
    required this.text,
    required this.secondary,
    required this.muted,
    required this.primary,
    required this.primarySoft,
    required this.primaryBorder,
    required this.responderBg,
    required this.success,
    required this.successBg,
    required this.successBorder,
    required this.danger,
    required this.dangerBg,
    required this.dangerBorder,
    required this.warning,
    required this.warningBg,
    required this.warningBorder,
    required this.infoBg,
    required this.infoBorder,
    required this.infoText,
    required this.aiBorder,
    required this.aiGradient,
    required this.aiAccent,
    required this.inputBg,
    required this.chipBg,
    required this.cardShadow,
  });

  final bool isDark;
  final Color bg;
  final Color card;
  final Color cardInner;
  final Color border;
  final Color borderSoft;
  final Color text;
  final Color secondary;
  final Color muted;
  final Color primary;
  final Color primarySoft;
  final Color primaryBorder;
  final Color responderBg;
  final Color success;
  final Color successBg;
  final Color successBorder;
  final Color danger;
  final Color dangerBg;
  final Color dangerBorder;
  final Color warning;
  final Color warningBg;
  final Color warningBorder;
  final Color infoBg;
  final Color infoBorder;
  final Color infoText;
  final Color aiBorder;
  final List<Color> aiGradient;
  final Color aiAccent;
  final Color inputBg;
  final Color chipBg;
  final List<BoxShadow> cardShadow;

  static _QuestoesColors of(bool isDark) => isDark ? dark : light;

  static const light = _QuestoesColors(
    isDark: false,
    bg: Color(0xFFF8FAFC),
    card: Colors.white,
    cardInner: Color(0xFFF8FAFC),
    border: Color(0xFFE2E8F0),
    borderSoft: Color(0xFFF1F5F9),
    text: Color(0xFF0F172A),
    secondary: Color(0xFF475569),
    muted: Color(0xFF94A3B8),
    primary: Color(0xFF1D4ED8),
    primarySoft: Color(0xFFEEF2FF),
    primaryBorder: Color(0xFFC7D2FE),
    responderBg: Color(0xFF1E3A8A),
    success: Color(0xFF047857),
    successBg: Color(0xFFECFDF5),
    successBorder: Color(0xFFA7F3D0),
    danger: Color(0xFFBE123C),
    dangerBg: Color(0xFFFFF1F2),
    dangerBorder: Color(0xFFFECDD3),
    warning: Color(0xFFB45309),
    warningBg: Color(0xFFFFFBEB),
    warningBorder: Color(0xFFFDE68A),
    infoBg: Color(0xFFEFF6FF),
    infoBorder: Color(0xFFBFDBFE),
    infoText: Color(0xFF1D4ED8),
    aiBorder: Color(0xFFDDD6FE),
    aiGradient: [Color(0xFF7E22CE), Color(0xFF4F46E5), Color(0xFF9333EA)],
    aiAccent: Color(0xFF7E22CE),
    inputBg: Color(0xFFF8FAFC),
    chipBg: Color(0xFFF8FAFC),
    cardShadow: [
      BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
    ],
  );

  static const dark = _QuestoesColors(
    isDark: true,
    bg: Color(0xFF080D19),
    card: Color(0xFF0F172A),
    cardInner: Color(0xFF131E36),
    border: Color(0xFF1E293B),
    borderSoft: Color(0xFF16213A),
    text: Color(0xFFE2E8F0),
    secondary: Color(0xFF94A3B8),
    muted: Color(0xFF64748B),
    primary: Color(0xFF6366F1),
    primarySoft: Color(0x266366F1),
    primaryBorder: Color(0xFF4338CA),
    responderBg: Color(0xFF4F46E5),
    success: Color(0xFF34D399),
    successBg: Color(0xFF06281E),
    successBorder: Color(0xFF065F46),
    danger: Color(0xFFFB7185),
    dangerBg: Color(0xFF2A1218),
    dangerBorder: Color(0xFF881337),
    warning: Color(0xFFFBBF24),
    warningBg: Color(0xFF2A2110),
    warningBorder: Color(0xFF92400E),
    infoBg: Color(0xFF0E1A33),
    infoBorder: Color(0xFF1E3A8A),
    infoText: Color(0xFF93C5FD),
    aiBorder: Color(0xFF312E81),
    aiGradient: [Color(0xFF7C3AED), Color(0xFF4F46E5), Color(0xFF6D28D9)],
    aiAccent: Color(0xFF7C3AED),
    inputBg: Color(0xFF0B1220),
    chipBg: Color(0xFF131E36),
    cardShadow: [
      BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 3)),
    ],
  );
}

BoxDecoration _cardDecoration(_QuestoesColors colors) {
  return BoxDecoration(
    color: colors.card,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: colors.border),
    boxShadow: colors.cardShadow,
  );
}

// ---------------------------------------------------------------------------
// Cabeçalho, banco e filtros
// ---------------------------------------------------------------------------

class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs({
    required this.colors,
    required this.responsive,
    required this.nomeMateria,
    required this.onInicio,
  });

  final _QuestoesColors colors;
  final Responsive responsive;
  final String? nomeMateria;
  final VoidCallback onInicio;

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      fontSize: responsive.sp(11),
      fontWeight: FontWeight.w500,
      color: colors.muted,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          InkWell(
            onTap: onInicio,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: Text('Início', style: estilo),
            ),
          ),
          _separador(),
          Text('Questões', style: estilo),
          _separador(),
          Text(
            nomeMateria ?? 'Todas as Matérias',
            style: estilo.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _separador() => Padding(
    padding: EdgeInsets.symmetric(horizontal: responsive.sp(5)),
    child: Text(
      '/',
      style: TextStyle(fontSize: responsive.sp(11), color: colors.muted),
    ),
  );
}

class _BankBanner extends StatelessWidget {
  const _BankBanner({
    required this.colors,
    required this.responsive,
    required this.total,
    required this.temFiltros,
  });

  final _QuestoesColors colors;
  final Responsive responsive;
  final int? total;
  final bool temFiltros;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.sp(12),
        vertical: responsive.sp(7),
      ),
      decoration: BoxDecoration(
        color: colors.cardInner,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.layers_rounded,
            size: responsive.sp(15),
            color: colors.infoText,
          ),
          SizedBox(width: responsive.sp(7)),
          Flexible(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: responsive.sp(10.5),
                  height: 1.3,
                  color: colors.secondary,
                  fontWeight: FontWeight.w600,
                ),
                children: [
                  TextSpan(
                    text: temFiltros
                        ? 'Foram encontradas '
                        : 'Total disponível no banco: ',
                  ),
                  TextSpan(
                    text: total?.toString() ?? '...',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: colors.infoText,
                    ),
                  ),
                  TextSpan(
                    text: temFiltros
                        ? ' questões para o seu filtro.'
                        : ' questões.',
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
  );
}

enum _SecaoFiltro {
  materias,
  assuntos,
  bancas,
  orgaos,
  idQuestao,
  modalidade,
  status,
  escolaridade,
  ano,
}

class _AdvancedFiltersCard extends StatefulWidget {
  const _AdvancedFiltersCard({
    required this.colors,
    required this.responsive,
    required this.aberto,
    required this.taxonomia,
    required this.filtros,
    required this.resetToken,
    required this.onToggle,
    required this.onChanged,
    required this.onLimpar,
    required this.onAplicar,
    required this.onSalvar,
  });

  final _QuestoesColors colors;
  final Responsive responsive;
  final bool aberto;
  final AsyncValue<TaxonomyCatalog> taxonomia;
  final QuestaoFiltros filtros;
  final int resetToken;
  final VoidCallback onToggle;
  final ValueChanged<QuestaoFiltros> onChanged;
  final VoidCallback onLimpar;
  final VoidCallback onAplicar;
  final VoidCallback onSalvar;

  @override
  State<_AdvancedFiltersCard> createState() => _AdvancedFiltersCardState();
}

class _AdvancedFiltersCardState extends State<_AdvancedFiltersCard> {
  final _buscaMaterias = TextEditingController();
  final _buscaAssuntos = TextEditingController();
  final _buscaBancas = TextEditingController();
  final _buscaOrgaos = TextEditingController();
  final _idQuestao = TextEditingController();
  final _idFocus = FocusNode();

  final _secoesAbertas = <_SecaoFiltro>{_SecaoFiltro.materias};

  _QuestoesColors get _colors => widget.colors;
  Responsive get _responsive => widget.responsive;
  QuestaoFiltros get _filtros => widget.filtros;

  @override
  void initState() {
    super.initState();
    _sincronizarId();
  }

  @override
  void didUpdateWidget(covariant _AdvancedFiltersCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final abriu = !oldWidget.aberto && widget.aberto;
    final limpou = oldWidget.resetToken != widget.resetToken;
    if (abriu || limpou) {
      _sincronizarId();
      _buscaMaterias.clear();
      _buscaAssuntos.clear();
      _buscaBancas.clear();
      _buscaOrgaos.clear();
    }
  }

  @override
  void dispose() {
    _buscaMaterias.dispose();
    _buscaAssuntos.dispose();
    _buscaBancas.dispose();
    _buscaOrgaos.dispose();
    _idQuestao.dispose();
    _idFocus.dispose();
    super.dispose();
  }

  void _sincronizarId() {
    final texto = _filtros.idQuestao?.toString() ?? '';
    if (_idQuestao.text != texto) {
      _idQuestao.value = TextEditingValue(
        text: texto,
        selection: TextSelection.collapsed(offset: texto.length),
      );
    }
  }

  void _emitir(QuestaoFiltros novos) {
    if (!mounted) return;
    widget.onChanged(novos);
  }

  void _alternarSecao(_SecaoFiltro secao) {
    setState(() {
      if (!_secoesAbertas.remove(secao)) {
        _secoesAbertas.add(secao);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ativos = _contarFiltros(_filtros);

    return Container(
      decoration: _cardDecoration(_colors),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: widget.onToggle,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _responsive.sp(14),
                vertical: _responsive.sp(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: _responsive.sp(16),
                    color: _colors.primary,
                  ),
                  SizedBox(width: _responsive.sp(8)),
                  Expanded(
                    child: Text(
                      'Filtros de Busca Avançados',
                      style: TextStyle(
                        fontSize: _responsive.sp(12),
                        fontWeight: FontWeight.w600,
                        color: _colors.text,
                      ),
                    ),
                  ),
                  if (ativos > 0) ...[
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: _responsive.sp(7),
                        vertical: _responsive.sp(1.5),
                      ),
                      decoration: BoxDecoration(
                        color: _colors.primarySoft,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _colors.primaryBorder),
                      ),
                      child: Text(
                        '$ativos',
                        style: TextStyle(
                          fontSize: _responsive.sp(9),
                          fontWeight: FontWeight.w700,
                          color: _colors.primary,
                        ),
                      ),
                    ),
                    SizedBox(width: _responsive.sp(6)),
                  ],
                  AnimatedRotation(
                    turns: widget.aberto ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: _responsive.sp(18),
                      color: _colors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: widget.aberto
                ? Padding(
                    padding: EdgeInsets.fromLTRB(
                      _responsive.sp(14),
                      0,
                      _responsive.sp(14),
                      _responsive.sp(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Divider(height: 1, color: _colors.borderSoft),
                        SizedBox(height: _responsive.sp(12)),
                        if (widget.taxonomia.hasValue)
                          ..._corpo(widget.taxonomia.requireValue)
                        else if (widget.taxonomia.hasError)
                          Text(
                            'Não foi possível carregar o catálogo de filtros.',
                            style: TextStyle(
                              fontSize: _responsive.sp(11),
                              color: _colors.danger,
                            ),
                          )
                        else
                          Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: _responsive.sp(8),
                            ),
                            child: Center(
                              child: SizedBox(
                                width: _responsive.sp(20),
                                height: _responsive.sp(20),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _colors.primary,
                                ),
                              ),
                            ),
                          ),
                        SizedBox(height: _responsive.sp(10)),
                        _acoes(),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  List<Widget> _corpo(TaxonomyCatalog catalogo) {
    final secoes = <Widget>[
      _secaoMaterias(catalogo),
      _secaoAssuntos(catalogo),
      _secaoBancas(catalogo),
      _secaoOrgaos(catalogo),
      _secaoIdQuestao(),
      _secaoModalidade(),
      _secaoStatus(),
      _secaoEscolaridade(catalogo),
      _secaoAno(),
    ];

    if (!_responsive.isCompact) {
      return [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  secoes[0],
                  SizedBox(height: _responsive.sp(8)),
                  secoes[1],
                  SizedBox(height: _responsive.sp(8)),
                  secoes[2],
                  SizedBox(height: _responsive.sp(8)),
                  secoes[3],
                ],
              ),
            ),
            SizedBox(width: _responsive.sp(8)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  secoes[4],
                  SizedBox(height: _responsive.sp(8)),
                  secoes[5],
                  SizedBox(height: _responsive.sp(8)),
                  secoes[6],
                  SizedBox(height: _responsive.sp(8)),
                  secoes[7],
                  SizedBox(height: _responsive.sp(8)),
                  secoes[8],
                ],
              ),
            ),
          ],
        ),
      ];
    }

    return [
      for (var i = 0; i < secoes.length; i++) ...[
        if (i > 0) SizedBox(height: _responsive.sp(8)),
        secoes[i],
      ],
    ];
  }

  Widget _secaoMaterias(TaxonomyCatalog catalogo) {
    final termo = _normalizarBusca(_buscaMaterias.text.trim());
    final materias = catalogo.materiasOrdenadas
        .where((materia) => _contemBusca(materia.nome, termo))
        .toList(growable: false);

    return _FilterSection(
      colors: _colors,
      responsive: _responsive,
      titulo: 'MATÉRIAS',
      icone: Icons.menu_book_rounded,
      quantidade: _filtros.idsMaterias.length,
      aberto: _secoesAbertas.contains(_SecaoFiltro.materias),
      onToggle: () => _alternarSecao(_SecaoFiltro.materias),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SearchField(
            fieldKey: const Key('filtro-busca-materias'),
            colors: _colors,
            responsive: _responsive,
            controller: _buscaMaterias,
            hint: 'Buscar matéria...',
            onChanged: () => setState(() {}),
          ),
          SizedBox(height: _responsive.sp(6)),
          if (materias.isEmpty)
            _textoVazio('Nenhuma matéria encontrada.')
          else
            _FilterListBox(
              colors: _colors,
              itemCount: materias.length,
              estimatedItemHeight: _responsive.sp(31),
              maxHeight: _responsive.sp(190),
              itemBuilder: (context, index) {
                final materia = materias[index];
                return _CheckRow(
                  colors: _colors,
                  responsive: _responsive,
                  label: materia.nome,
                  checked: _filtros.idsMaterias.contains(materia.id),
                  onChanged: (valor) =>
                      _toggleMateria(materia, valor, catalogo),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _secaoAssuntos(TaxonomyCatalog catalogo) {
    final materiasSelecionadas = _filtros.idsMaterias.toSet();
    final termo = _normalizarBusca(_buscaAssuntos.text.trim());
    final linhas = <_LinhaFiltro>[];

    if (materiasSelecionadas.isNotEmpty) {
      final topicos =
          catalogo.topicos
              .where(
                (topico) => materiasSelecionadas.contains(topico.idMateria),
              )
              .toList()
            ..sort((a, b) => a.nome.compareTo(b.nome));

      for (final topico in topicos) {
        final subtopicos = catalogo.subtopicosDoTopico(topico.id)
          ..sort((a, b) => a.nome.compareTo(b.nome));
        final topicoCombina = _contemBusca(topico.nome, termo);
        final subtopicosVisiveis = topicoCombina
            ? subtopicos
            : subtopicos
                  .where((subtopico) => _contemBusca(subtopico.nome, termo))
                  .toList();

        if (!topicoCombina && subtopicosVisiveis.isEmpty) continue;

        linhas.add(_LinhaFiltro.topico(topico));
        for (final subtopico in subtopicosVisiveis) {
          linhas.add(_LinhaFiltro.subtopico(subtopico, topico));
        }
      }
    }

    return _FilterSection(
      colors: _colors,
      responsive: _responsive,
      titulo: 'ASSUNTOS',
      icone: Icons.account_tree_rounded,
      quantidade: _filtros.idsTopicos.length + _filtros.idsSubtopicos.length,
      aberto: _secoesAbertas.contains(_SecaoFiltro.assuntos),
      onToggle: () => _alternarSecao(_SecaoFiltro.assuntos),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SearchField(
            fieldKey: const Key('filtro-busca-assuntos'),
            colors: _colors,
            responsive: _responsive,
            controller: _buscaAssuntos,
            hint: 'Buscar tópico ou subtópico...',
            onChanged: () => setState(() {}),
          ),
          SizedBox(height: _responsive.sp(6)),
          if (materiasSelecionadas.isEmpty)
            _textoVazio(
              'Marque uma ou mais matérias para carregar os assuntos.',
            )
          else if (linhas.isEmpty)
            _textoVazio('Nenhum assunto encontrado.')
          else
            _FilterListBox(
              colors: _colors,
              itemCount: linhas.length,
              estimatedItemHeight: _responsive.sp(31),
              maxHeight: _responsive.sp(240),
              itemBuilder: (context, index) {
                final linha = linhas[index];
                if (linha.isTopico) {
                  final topico = linha.topico!;
                  return _CheckRow(
                    colors: _colors,
                    responsive: _responsive,
                    label: topico.nome,
                    checked: _filtros.idsTopicos.contains(topico.id),
                    bold: true,
                    onChanged: (valor) =>
                        _toggleTopico(topico, valor, catalogo),
                  );
                }

                final subtopico = linha.subtopico!;
                return _CheckRow(
                  colors: _colors,
                  responsive: _responsive,
                  label: subtopico.nome,
                  checked: _filtros.idsSubtopicos.contains(subtopico.id),
                  indent: true,
                  onChanged: (valor) => _toggleSubtopico(subtopico, valor),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _secaoBancas(TaxonomyCatalog catalogo) {
    final termo = _normalizarBusca(_buscaBancas.text.trim());
    final bancas =
        ([...catalogo.bancas]..sort((a, b) => a.nome.compareTo(b.nome)))
            .where((banca) => _contemBusca(banca.nome, termo))
            .toList(growable: false);

    return _FilterSection(
      colors: _colors,
      responsive: _responsive,
      titulo: 'BANCA',
      icone: Icons.business_rounded,
      quantidade: _filtros.idsBancas.length,
      aberto: _secoesAbertas.contains(_SecaoFiltro.bancas),
      onToggle: () => _alternarSecao(_SecaoFiltro.bancas),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SearchField(
            fieldKey: const Key('filtro-busca-bancas'),
            colors: _colors,
            responsive: _responsive,
            controller: _buscaBancas,
            hint: 'Buscar banca...',
            onChanged: () => setState(() {}),
          ),
          SizedBox(height: _responsive.sp(6)),
          if (bancas.isEmpty)
            _textoVazio('Nenhuma banca encontrada.')
          else
            _FilterListBox(
              colors: _colors,
              itemCount: bancas.length,
              estimatedItemHeight: _responsive.sp(31),
              maxHeight: _responsive.sp(190),
              itemBuilder: (context, index) {
                final banca = bancas[index];
                return _CheckRow(
                  colors: _colors,
                  responsive: _responsive,
                  label: banca.nome,
                  checked: _filtros.idsBancas.contains(banca.id),
                  onChanged: (valor) => _toggleBanca(banca, valor),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _secaoOrgaos(TaxonomyCatalog catalogo) {
    final termo = _normalizarBusca(_buscaOrgaos.text.trim());
    final linhas = <_LinhaOrgao>[];
    final orgaos = ([...catalogo.orgaos]
      ..sort((a, b) => a.nome.compareTo(b.nome)));

    for (final orgao in orgaos) {
      final cargos = ([...orgao.cargos]
        ..sort((a, b) => a.nome.compareTo(b.nome)));
      final orgaoCombina = _contemBusca(orgao.nome, termo);
      final cargosVisiveis = orgaoCombina
          ? cargos
          : cargos.where((cargo) => _contemBusca(cargo.nome, termo)).toList();

      if (!orgaoCombina && cargosVisiveis.isEmpty) continue;

      linhas.add(_LinhaOrgao.orgao(orgao));
      for (final cargo in cargosVisiveis) {
        linhas.add(_LinhaOrgao.cargo(cargo, orgao));
      }
    }

    return _FilterSection(
      colors: _colors,
      responsive: _responsive,
      titulo: 'ÓRGÃO E CARGO',
      icone: Icons.work_outline_rounded,
      quantidade: _filtros.idsOrgaos.length + _filtros.idsCargos.length,
      aberto: _secoesAbertas.contains(_SecaoFiltro.orgaos),
      onToggle: () => _alternarSecao(_SecaoFiltro.orgaos),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SearchField(
            fieldKey: const Key('filtro-busca-orgaos'),
            colors: _colors,
            responsive: _responsive,
            controller: _buscaOrgaos,
            hint: 'Buscar órgão ou cargo...',
            onChanged: () => setState(() {}),
          ),
          SizedBox(height: _responsive.sp(6)),
          if (linhas.isEmpty)
            _textoVazio('Nenhum órgão ou cargo encontrado.')
          else
            _FilterListBox(
              colors: _colors,
              itemCount: linhas.length,
              estimatedItemHeight: _responsive.sp(31),
              maxHeight: _responsive.sp(240),
              itemBuilder: (context, index) {
                final linha = linhas[index];
                if (linha.isOrgao) {
                  final orgao = linha.orgao!;
                  return _CheckRow(
                    colors: _colors,
                    responsive: _responsive,
                    label: orgao.nome,
                    checked: _filtros.idsOrgaos.contains(orgao.id),
                    bold: true,
                    onChanged: (valor) => _toggleOrgao(orgao, valor),
                  );
                }

                final cargo = linha.cargo!;
                return _CheckRow(
                  colors: _colors,
                  responsive: _responsive,
                  label: cargo.nome,
                  checked: _filtros.idsCargos.contains(cargo.id),
                  indent: true,
                  onChanged: (valor) => _toggleCargo(cargo, valor),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _secaoIdQuestao() {
    return _FilterSection(
      colors: _colors,
      responsive: _responsive,
      titulo: 'ID DA QUESTÃO',
      icone: Icons.tag_rounded,
      quantidade: _filtros.idQuestao == null ? 0 : 1,
      aberto: _secoesAbertas.contains(_SecaoFiltro.idQuestao),
      onToggle: () => _alternarSecao(_SecaoFiltro.idQuestao),
      child: TextField(
        key: const Key('filtro-id-questao'),
        controller: _idQuestao,
        focusNode: _idFocus,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        style: TextStyle(fontSize: _responsive.sp(12), color: _colors.text),
        decoration: _filterInputDecoration(
          colors: _colors,
          responsive: _responsive,
          hint: 'Ex.: 12345',
        ),
        onChanged: (texto) {
          final id = int.tryParse(texto.trim());
          _emitir(
            _filtros.copyWith(idQuestao: id, limparIdQuestao: id == null),
          );
        },
      ),
    );
  }

  Widget _secaoModalidade() {
    return _FilterSection(
      colors: _colors,
      responsive: _responsive,
      titulo: 'MODALIDADE',
      icone: Icons.checklist_rounded,
      quantidade: _filtros.tiposQuestao.length,
      aberto: _secoesAbertas.contains(_SecaoFiltro.modalidade),
      onToggle: () => _alternarSecao(_SecaoFiltro.modalidade),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CheckRow(
            colors: _colors,
            responsive: _responsive,
            label: 'Múltipla Escolha',
            checked: _filtros.tiposQuestao.contains('multipla_escolha'),
            onChanged: (valor) => _toggleTipo('multipla_escolha', valor),
          ),
          _CheckRow(
            colors: _colors,
            responsive: _responsive,
            label: 'Certo ou Errado',
            checked: _filtros.tiposQuestao.contains('certo_errado'),
            onChanged: (valor) => _toggleTipo('certo_errado', valor),
          ),
          SizedBox(height: _responsive.sp(4)),
          Text(
            'Sem seleção, todas as modalidades são incluídas.',
            style: TextStyle(
              fontSize: _responsive.sp(9.5),
              color: _colors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _secaoStatus() {
    return _FilterSection(
      colors: _colors,
      responsive: _responsive,
      titulo: 'STATUS',
      icone: Icons.history_rounded,
      quantidade: _filtros.status == StatusQuestao.todas ? 0 : 1,
      aberto: _secoesAbertas.contains(_SecaoFiltro.status),
      onToggle: () => _alternarSecao(_SecaoFiltro.status),
      child: _FilterDropdown<StatusQuestao>(
        colors: _colors,
        responsive: _responsive,
        value: _filtros.status,
        items: [
          for (final status in StatusQuestao.values)
            DropdownMenuItem<StatusQuestao>(
              value: status,
              child: Text(
                _statusLabel(status),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (valor) {
          if (valor == null) return;
          _emitir(_filtros.copyWith(status: valor));
        },
      ),
    );
  }

  Widget _secaoEscolaridade(TaxonomyCatalog catalogo) {
    final niveis = ([...catalogo.niveis]..sort((a, b) => a.id.compareTo(b.id)));
    final valor = niveis.any((nivel) => nivel.id == _filtros.idNivel)
        ? _filtros.idNivel!
        : -1;

    return _FilterSection(
      colors: _colors,
      responsive: _responsive,
      titulo: 'ESCOLARIDADE',
      icone: Icons.school_outlined,
      quantidade: _filtros.idNivel == null ? 0 : 1,
      aberto: _secoesAbertas.contains(_SecaoFiltro.escolaridade),
      onToggle: () => _alternarSecao(_SecaoFiltro.escolaridade),
      child: _FilterDropdown<int>(
        colors: _colors,
        responsive: _responsive,
        value: valor,
        items: [
          const DropdownMenuItem<int>(value: -1, child: Text('Todas')),
          for (final nivel in niveis)
            DropdownMenuItem<int>(
              value: nivel.id,
              child: Text(nivel.nome, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (novo) {
          if (novo == null) return;
          _emitir(
            _filtros.copyWith(
              idNivel: novo < 0 ? null : novo,
              limparIdNivel: novo < 0,
            ),
          );
        },
      ),
    );
  }

  Widget _secaoAno() {
    final anos = TaxonomyRepository.anosDisponiveis;

    return _FilterSection(
      colors: _colors,
      responsive: _responsive,
      titulo: 'ANO',
      icone: Icons.calendar_today_rounded,
      quantidade: _filtros.anos.length,
      aberto: _secoesAbertas.contains(_SecaoFiltro.ano),
      onToggle: () => _alternarSecao(_SecaoFiltro.ano),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: _responsive.sp(6),
            runSpacing: _responsive.sp(6),
            children: [
              for (final ano in anos)
                _FilterChip(
                  colors: _colors,
                  responsive: _responsive,
                  label: '$ano',
                  selected: _filtros.anos.contains(ano),
                  onTap: () => _toggleAno(ano),
                ),
            ],
          ),
          SizedBox(height: _responsive.sp(6)),
          Text(
            'Sem seleção, todos os anos são incluídos.',
            style: TextStyle(
              fontSize: _responsive.sp(9.5),
              color: _colors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _acoes() {
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: _responsive.sp(6),
      runSpacing: _responsive.sp(6),
      children: [
        TextButton(
          key: const Key('filtro-limpar'),
          onPressed: widget.onLimpar,
          style: _textButtonStyle(_colors),
          child: const Text('Limpar tudo'),
        ),
        OutlinedButton.icon(
          key: const Key('filtro-salvar'),
          onPressed: widget.onSalvar,
          icon: Icon(Icons.bookmark_add_outlined, size: _responsive.sp(14)),
          label: const Text('Salvar filtro'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _colors.primary,
            side: BorderSide(color: _colors.primaryBorder),
            minimumSize: Size(0, _responsive.sp(34)),
            padding: EdgeInsets.symmetric(horizontal: _responsive.sp(10)),
            textStyle: TextStyle(
              fontSize: _responsive.sp(10.5),
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          ),
        ),
        ElevatedButton.icon(
          key: const Key('filtro-aplicar'),
          onPressed: widget.onAplicar,
          icon: Icon(Icons.search_rounded, size: _responsive.sp(15)),
          label: const Text('Aplicar filtros'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _colors.responderBg,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: Size(_responsive.sp(120), _responsive.sp(36)),
            padding: EdgeInsets.symmetric(horizontal: _responsive.sp(14)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
            textStyle: TextStyle(
              fontSize: _responsive.sp(11),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _textoVazio(String texto) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: _responsive.sp(8),
        horizontal: _responsive.sp(4),
      ),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: _responsive.sp(10.5),
          color: _colors.muted,
          height: 1.35,
        ),
      ),
    );
  }

  void _toggleMateria(
    Materia materia,
    bool selecionado,
    TaxonomyCatalog catalogo,
  ) {
    final materias = {..._filtros.idsMaterias};
    final topicos = {..._filtros.idsTopicos};
    final subtopicos = {..._filtros.idsSubtopicos};

    if (selecionado) {
      materias.add(materia.id);
    } else {
      materias.remove(materia.id);
      final idsTopicos = catalogo
          .topicosDaMateria(materia.id)
          .map((topico) => topico.id)
          .toSet();
      final idsSubtopicos = catalogo.subtopicos
          .where((subtopico) => idsTopicos.contains(subtopico.idTopico))
          .map((subtopico) => subtopico.id)
          .toSet();
      topicos.removeWhere(idsTopicos.contains);
      subtopicos.removeWhere(idsSubtopicos.contains);
    }

    _emitir(
      _filtros.copyWith(
        idsMaterias: _ordenar(materias),
        idsTopicos: _ordenar(topicos),
        idsSubtopicos: _ordenar(subtopicos),
      ),
    );
  }

  void _toggleTopico(
    Topico topico,
    bool selecionado,
    TaxonomyCatalog catalogo,
  ) {
    final topicos = {..._filtros.idsTopicos};
    final subtopicos = {..._filtros.idsSubtopicos};
    final idsSubtopicos = catalogo
        .subtopicosDoTopico(topico.id)
        .map((subtopico) => subtopico.id);

    if (selecionado) {
      topicos.add(topico.id);
      subtopicos.addAll(idsSubtopicos);
    } else {
      topicos.remove(topico.id);
      subtopicos.removeAll(idsSubtopicos);
    }

    _emitir(
      _filtros.copyWith(
        idsTopicos: _ordenar(topicos),
        idsSubtopicos: _ordenar(subtopicos),
      ),
    );
  }

  void _toggleSubtopico(Subtopico subtopico, bool selecionado) {
    final subtopicos = {..._filtros.idsSubtopicos};
    if (selecionado) {
      subtopicos.add(subtopico.id);
    } else {
      subtopicos.remove(subtopico.id);
    }
    _emitir(_filtros.copyWith(idsSubtopicos: _ordenar(subtopicos)));
  }

  void _toggleBanca(Banca banca, bool selecionado) {
    final bancas = {..._filtros.idsBancas};
    if (selecionado) {
      bancas.add(banca.id);
    } else {
      bancas.remove(banca.id);
    }
    _emitir(_filtros.copyWith(idsBancas: _ordenar(bancas)));
  }

  void _toggleOrgao(Orgao orgao, bool selecionado) {
    final orgaos = {..._filtros.idsOrgaos};
    final cargos = {..._filtros.idsCargos};
    final idsCargos = orgao.cargos.map((cargo) => cargo.id);

    if (selecionado) {
      orgaos.add(orgao.id);
      cargos.addAll(idsCargos);
    } else {
      orgaos.remove(orgao.id);
      cargos.removeAll(idsCargos);
    }

    _emitir(
      _filtros.copyWith(
        idsOrgaos: _ordenar(orgaos),
        idsCargos: _ordenar(cargos),
      ),
    );
  }

  void _toggleCargo(Cargo cargo, bool selecionado) {
    final cargos = {..._filtros.idsCargos};
    if (selecionado) {
      cargos.add(cargo.id);
    } else {
      cargos.remove(cargo.id);
    }
    _emitir(_filtros.copyWith(idsCargos: _ordenar(cargos)));
  }

  void _toggleTipo(String tipo, bool selecionado) {
    final tipos = {..._filtros.tiposQuestao};
    if (selecionado) {
      tipos.add(tipo);
    } else {
      tipos.remove(tipo);
    }
    final ordenados = [
      for (final valor in const ['multipla_escolha', 'certo_errado'])
        if (tipos.contains(valor)) valor,
    ];
    _emitir(_filtros.copyWith(tiposQuestao: ordenados));
  }

  void _toggleAno(int ano) {
    final anos = {..._filtros.anos};
    if (!anos.remove(ano)) {
      anos.add(ano);
    }
    _emitir(_filtros.copyWith(anos: _ordenar(anos)));
  }

  List<int> _ordenar(Iterable<int> valores) => valores.toList()..sort();

  int _contarFiltros(QuestaoFiltros filtros) {
    return (filtros.idQuestao == null ? 0 : 1) +
        (filtros.status == StatusQuestao.todas ? 0 : 1) +
        filtros.idsMaterias.length +
        filtros.idsTopicos.length +
        filtros.idsSubtopicos.length +
        filtros.idsBancas.length +
        filtros.idsOrgaos.length +
        filtros.idsCargos.length +
        filtros.anos.length +
        (filtros.idNivel == null ? 0 : 1) +
        filtros.tiposQuestao.length;
  }

  String _statusLabel(StatusQuestao status) {
    return switch (status) {
      StatusQuestao.todas => 'Todas as questões',
      StatusQuestao.naoRespondidas => 'Apenas não respondidas',
      StatusQuestao.respondidas => 'Apenas as que já fiz',
      StatusQuestao.acertos => 'Questões que acertei',
      StatusQuestao.erros => 'Questões que errei',
    };
  }
}

class _LinhaFiltro {
  const _LinhaFiltro._({this.topico, this.subtopico});

  const _LinhaFiltro.topico(Topico topico) : this._(topico: topico);

  const _LinhaFiltro.subtopico(Subtopico subtopico, Topico topico)
    : this._(topico: topico, subtopico: subtopico);

  final Topico? topico;
  final Subtopico? subtopico;

  bool get isTopico => subtopico == null;
}

class _LinhaOrgao {
  const _LinhaOrgao._({this.orgao, this.cargo});

  const _LinhaOrgao.orgao(Orgao orgao) : this._(orgao: orgao);

  const _LinhaOrgao.cargo(Cargo cargo, Orgao orgao)
    : this._(orgao: orgao, cargo: cargo);

  final Orgao? orgao;
  final Cargo? cargo;

  bool get isOrgao => cargo == null;
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.colors,
    required this.responsive,
    required this.titulo,
    required this.icone,
    required this.quantidade,
    required this.aberto,
    required this.onToggle,
    required this.child,
  });

  final _QuestoesColors colors;
  final Responsive responsive;
  final String titulo;
  final IconData icone;
  final int quantidade;
  final bool aberto;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.cardInner,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: colors.borderSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: responsive.sp(10),
                vertical: responsive.sp(9),
              ),
              child: Row(
                children: [
                  Icon(icone, size: responsive.sp(14), color: colors.primary),
                  SizedBox(width: responsive.sp(7)),
                  Expanded(
                    child: Text(
                      titulo,
                      style: TextStyle(
                        fontSize: responsive.sp(10),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: colors.text,
                      ),
                    ),
                  ),
                  if (quantidade > 0) ...[
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: responsive.sp(6),
                        vertical: responsive.sp(1),
                      ),
                      decoration: BoxDecoration(
                        color: colors.primarySoft,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: colors.primaryBorder),
                      ),
                      child: Text(
                        '$quantidade',
                        style: TextStyle(
                          fontSize: responsive.sp(8.5),
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                        ),
                      ),
                    ),
                    SizedBox(width: responsive.sp(4)),
                  ],
                  AnimatedRotation(
                    turns: aberto ? 0.5 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: responsive.sp(16),
                      color: colors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 160),
            alignment: Alignment.topCenter,
            child: aberto
                ? Padding(
                    padding: EdgeInsets.fromLTRB(
                      responsive.sp(10),
                      0,
                      responsive.sp(10),
                      responsive.sp(10),
                    ),
                    child: child,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.colors,
    required this.responsive,
    required this.label,
    required this.checked,
    required this.onChanged,
    this.bold = false,
    this.indent = false,
  });

  final _QuestoesColors colors;
  final Responsive responsive;
  final String label;
  final bool checked;
  final ValueChanged<bool> onChanged;
  final bool bold;
  final bool indent;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!checked),
      child: Padding(
        padding: EdgeInsets.only(
          left: responsive.sp(indent ? 17 : 3),
          right: responsive.sp(3),
          top: responsive.sp(1),
          bottom: responsive.sp(1),
        ),
        child: Row(
          children: [
            Checkbox(
              value: checked,
              onChanged: (valor) => onChanged(valor ?? false),
              activeColor: colors.primary,
              checkColor: Colors.white,
              side: BorderSide(color: colors.muted, width: 1.2),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
            ),
            SizedBox(width: responsive.sp(5)),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: responsive.sp(indent ? 10.5 : 11.5),
                  fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                  color: indent ? colors.secondary : colors.text,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.colors,
    required this.responsive,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final _QuestoesColors colors;
  final Responsive responsive;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: responsive.sp(9),
          vertical: responsive.sp(4),
        ),
        decoration: BoxDecoration(
          color: selected ? colors.primarySoft : colors.inputBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? colors.primaryBorder : colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(
                Icons.check_rounded,
                size: responsive.sp(11),
                color: colors.primary,
              ),
              SizedBox(width: responsive.sp(3)),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: responsive.sp(10),
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? colors.primary : colors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.colors,
    required this.responsive,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.fieldKey,
  });

  final _QuestoesColors colors;
  final Responsive responsive;
  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      onChanged: (_) => onChanged(),
      style: TextStyle(fontSize: responsive.sp(11.5), color: colors.text),
      decoration: _filterInputDecoration(
        colors: colors,
        responsive: responsive,
        hint: hint,
        prefixIcon: Icons.search_rounded,
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  controller.clear();
                  onChanged();
                },
                icon: Icon(Icons.close_rounded, size: responsive.sp(14)),
                color: colors.muted,
                visualDensity: VisualDensity.compact,
                tooltip: 'Limpar busca',
              ),
      ),
    );
  }
}

class _FilterListBox extends StatelessWidget {
  const _FilterListBox({
    required this.colors,
    required this.itemCount,
    required this.estimatedItemHeight,
    required this.maxHeight,
    required this.itemBuilder,
  });

  final _QuestoesColors colors;
  final int itemCount;
  final double estimatedItemHeight;
  final double maxHeight;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    final altura = (itemCount * estimatedItemHeight)
        .clamp(0.0, maxHeight)
        .toDouble();

    return Container(
      height: altura,
      decoration: BoxDecoration(
        color: colors.inputBg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(vertical: 3),
        itemCount: itemCount,
        itemBuilder: itemBuilder,
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.colors,
    required this.responsive,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final _QuestoesColors colors;
  final Responsive responsive;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.sp(8),
        vertical: responsive.sp(2),
      ),
      decoration: BoxDecoration(
        color: colors.inputBg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: colors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          dropdownColor: colors.card,
          borderRadius: BorderRadius.circular(10),
          icon: Icon(
            Icons.expand_more_rounded,
            size: responsive.sp(17),
            color: colors.muted,
          ),
          style: TextStyle(fontSize: responsive.sp(11.5), color: colors.text),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

InputDecoration _filterInputDecoration({
  required _QuestoesColors colors,
  required Responsive responsive,
  required String hint,
  IconData? prefixIcon,
  Widget? suffixIcon,
}) {
  OutlineInputBorder borda(Color cor, [double largura = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: BorderSide(color: cor, width: largura),
    );
  }

  return InputDecoration(
    isDense: true,
    hintText: hint,
    hintStyle: TextStyle(fontSize: responsive.sp(11), color: colors.muted),
    prefixIcon: prefixIcon == null
        ? null
        : Icon(prefixIcon, size: responsive.sp(15), color: colors.muted),
    prefixIconConstraints: BoxConstraints(
      minWidth: responsive.sp(30),
      minHeight: responsive.sp(30),
    ),
    suffixIcon: suffixIcon,
    suffixIconConstraints: BoxConstraints(
      minWidth: responsive.sp(30),
      minHeight: responsive.sp(30),
    ),
    filled: true,
    fillColor: colors.inputBg,
    contentPadding: EdgeInsets.symmetric(
      horizontal: responsive.sp(8),
      vertical: responsive.sp(9),
    ),
    border: borda(colors.border),
    enabledBorder: borda(colors.border),
    focusedBorder: borda(colors.primary, 1.4),
  );
}

String _normalizarBusca(String texto) {
  const acentos = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const semAcentos = 'aaaaaeeeeiiiiooooouuuucn';
  var resultado = texto.toLowerCase();
  for (var i = 0; i < acentos.length; i++) {
    resultado = resultado.replaceAll(acentos[i], semAcentos[i]);
  }
  return resultado;
}

bool _contemBusca(String texto, String termo) {
  if (termo.isEmpty) return true;
  return _normalizarBusca(texto).contains(termo);
}

class _SavedFiltersBar extends StatelessWidget {
  const _SavedFiltersBar({
    required this.colors,
    required this.responsive,
    required this.temFiltros,
    required this.onLimpar,
    required this.onSalvar,
  });

  final _QuestoesColors colors;
  final Responsive responsive;
  final bool temFiltros;
  final VoidCallback onLimpar;
  final VoidCallback onSalvar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.sp(12),
        vertical: responsive.sp(2),
      ),
      decoration: _cardDecoration(colors),
      child: Row(
        children: [
          Icon(
            Icons.sell_outlined,
            size: responsive.sp(14),
            color: colors.muted,
          ),
          SizedBox(width: responsive.sp(6)),
          Expanded(
            child: Text(
              'Meus Filtros Salvos',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: responsive.sp(11.5),
                fontWeight: FontWeight.w500,
                color: colors.secondary,
              ),
            ),
          ),
          TextButton(
            onPressed: temFiltros ? onLimpar : null,
            style: _textButtonStyle(colors),
            child: const Text('Limpar'),
          ),
          TextButton(
            onPressed: onSalvar,
            style: _textButtonStyle(colors),
            child: const Text('+ Salvar'),
          ),
        ],
      ),
    );
  }
}

class _SavedFiltersChips extends StatelessWidget {
  const _SavedFiltersChips({
    required this.colors,
    required this.filtros,
    required this.onAplicar,
    required this.onExcluir,
  });

  final _QuestoesColors colors;
  final List<FiltroSalvo> filtros;
  final ValueChanged<FiltroSalvo> onAplicar;
  final ValueChanged<FiltroSalvo> onExcluir;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final filtro in filtros)
          InputChip(
            label: Text(
              filtro.nome,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            avatar: Icon(
              Icons.bookmark_outline,
              size: 14,
              color: colors.primary,
            ),
            onPressed: () => onAplicar(filtro),
            onDeleted: () => onExcluir(filtro),
            deleteIcon: const Icon(Icons.close_rounded, size: 14),
            backgroundColor: colors.chipBg,
            side: BorderSide(color: colors.border),
            labelStyle: TextStyle(fontSize: 11, color: colors.text),
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}

ButtonStyle _textButtonStyle(_QuestoesColors colors) {
  return TextButton.styleFrom(
    foregroundColor: colors.primary,
    disabledForegroundColor: colors.muted,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    minimumSize: Size.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
  );
}

// ---------------------------------------------------------------------------
// Card da questão
// ---------------------------------------------------------------------------

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.colors,
    required this.responsive,
    required this.questao,
    required this.status,
    required this.letraSelecionada,
    required this.resultado,
    required this.enviando,
    required this.annotationTool,
    required this.annotationStrokes,
    required this.eliminatedAlternatives,
    required this.onAnnotationToolSelected,
    required this.onAnnotationStrokeAdded,
    required this.onEraseAnnotation,
    required this.onToggleAlternativeEliminated,
    required this.onSelecionar,
    required this.onResponder,
    required this.onComentarios,
    required this.onIaExplica,
    required this.onSalvarCaderno,
    required this.onGerarResumo,
    required this.onCriarFlashcard,
    required this.onReportar,
  });

  final _QuestoesColors colors;
  final Responsive responsive;
  final Questao questao;
  final bool? status;
  final String? letraSelecionada;
  final RespostaQuestaoResultado? resultado;
  final bool enviando;
  final _AnnotationTool? annotationTool;
  final List<_AnnotationStroke> annotationStrokes;
  final Set<String> eliminatedAlternatives;
  final ValueChanged<_AnnotationTool> onAnnotationToolSelected;
  final ValueChanged<_AnnotationStroke> onAnnotationStrokeAdded;
  final void Function(List<Offset> points, Size size) onEraseAnnotation;
  final ValueChanged<String> onToggleAlternativeEliminated;
  final ValueChanged<String> onSelecionar;
  final VoidCallback onResponder;
  final VoidCallback onComentarios;
  final VoidCallback onIaExplica;
  final VoidCallback onSalvarCaderno;
  final VoidCallback onGerarResumo;
  final VoidCallback onCriarFlashcard;
  final VoidCallback onReportar;

  @override
  Widget build(BuildContext context) {
    final enunciado = _htmlParaTexto(questao.enunciado);
    final imagens = QuestionImage.extrair(
      urlImagem: questao.urlImagem,
      html: '',
    );
    final textoBase = _htmlParaTexto(questao.textoBase ?? '');
    final metadata = _metadata(questao);
    final nivel = questao.descritivoNivel?.trim();
    final ferramentaAtiva = switch (annotationTool) {
      _AnnotationTool.pen => 'Caneta',
      _AnnotationTool.highlighter => 'Marca-texto',
      _AnnotationTool.eraser => 'Borracha',
      null => null,
    };

    return Container(
      padding: EdgeInsets.all(responsive.sp(16)),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
        boxShadow: colors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: responsive.sp(8),
            runSpacing: responsive.sp(5),
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: responsive.sp(6),
                runSpacing: responsive.sp(4),
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Questão #${questao.id}',
                    style: TextStyle(
                      fontSize: responsive.sp(14),
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: colors.text,
                    ),
                  ),
                  _Tag(
                    colors: colors,
                    responsive: responsive,
                    label: _statusLabel(status),
                    tone: _statusTone(status),
                  ),
                ],
              ),
              _QuestionAnnotationToolbar(
                colors: colors,
                responsive: responsive,
                selectedTool: annotationTool,
                onToolSelected: onAnnotationToolSelected,
              ),
            ],
          ),
          if (questao.nomeMateria != null || questao.nomeTopico != null) ...[
            SizedBox(height: responsive.sp(6)),
            Wrap(
              spacing: responsive.sp(6),
              runSpacing: responsive.sp(5),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (questao.nomeMateria != null)
                  _Tag(
                    colors: colors,
                    responsive: responsive,
                    label: questao.nomeMateria!,
                    tone: _TagTone.indigo,
                  ),
                if (questao.nomeTopico != null)
                  _Tag(
                    colors: colors,
                    responsive: responsive,
                    label: questao.nomeTopico!,
                    tone: _TagTone.blue,
                  ),
              ],
            ),
          ],
          if (metadata.isNotEmpty) ...[
            SizedBox(height: responsive.sp(8)),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  metadata,
                  style: TextStyle(
                    fontSize: responsive.sp(11),
                    height: 1.4,
                    color: colors.secondary,
                  ),
                ),
                if (nivel != null && nivel.isNotEmpty)
                  _Tag(
                    colors: colors,
                    responsive: responsive,
                    label: nivel.toUpperCase(),
                    tone: _TagTone.slate,
                  ),
              ],
            ),
          ],
          if (annotationTool != null) ...[
            SizedBox(height: responsive.sp(5)),
            Text(
              '$ferramentaAtiva ativa. Toque novamente nela para rolar, selecionar ou riscar alternativas.',
              style: TextStyle(
                color: colors.muted,
                fontSize: responsive.sp(9),
                height: 1.35,
              ),
            ),
          ],
          SizedBox(height: responsive.sp(12)),
          Container(
            key: const Key('questao-header-divider'),
            height: 1,
            color: colors.border.withValues(alpha: 0.8),
          ),
          SizedBox(height: responsive.sp(12)),
          _QuestionAnnotationSurface(
            key: ValueKey('questao-annotation-surface-${questao.id}'),
            tool: annotationTool,
            strokes: annotationStrokes,
            scale: responsive.scale,
            penColor: colors.primary,
            onStrokeCompleted: onAnnotationStrokeAdded,
            onErase: onEraseAnnotation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (textoBase.isNotEmpty) ...[
                  _SupportTextBox(
                    key: ValueKey('texto-apoio-${questao.id}'),
                    colors: colors,
                    responsive: responsive,
                    titulo: _htmlParaTexto(questao.tituloReferencia ?? ''),
                    texto: textoBase,
                  ),
                  SizedBox(height: responsive.sp(14)),
                ],
                for (final url in imagens)
                  QuestionImage(
                    key: ValueKey('questao-imagem-${questao.id}-$url'),
                    source: url,
                  ),
                LatexText(
                  enunciado,
                  style: TextStyle(
                    fontSize: responsive.sp(13.5),
                    height: 1.55,
                    color: colors.text,
                  ),
                ),
                SizedBox(height: responsive.sp(14)),
                if (questao.alternativas.isEmpty)
                  _DiscursivaNote(colors: colors, responsive: responsive)
                else
                  for (final alternativa in questao.alternativas)
                    _OptionTile(
                      colors: colors,
                      responsive: responsive,
                      letra: alternativa.letra,
                      texto: _htmlParaTexto(alternativa.texto),
                      estado: _estadoAlternativa(alternativa.letra),
                      eliminada: eliminatedAlternatives.contains(
                        alternativa.letra,
                      ),
                      onTap:
                          resultado == null &&
                              !enviando &&
                              !eliminatedAlternatives.contains(
                                alternativa.letra,
                              )
                          ? () => onSelecionar(alternativa.letra)
                          : null,
                      onToggleEliminada: resultado == null && !enviando
                          ? () =>
                                onToggleAlternativeEliminated(alternativa.letra)
                          : null,
                    ),
              ],
            ),
          ),
          if (resultado != null) ...[
            SizedBox(height: responsive.sp(4)),
            _FeedbackBanner(
              colors: colors,
              responsive: responsive,
              resultado: resultado!,
            ),
          ],
          SizedBox(height: responsive.sp(10)),
          ElevatedButton(
            onPressed: resultado != null || enviando || letraSelecionada == null
                ? null
                : onResponder,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.responderBg,
              foregroundColor: Colors.white,
              disabledBackgroundColor: colors.isDark
                  ? colors.responderBg.withValues(alpha: 0.35)
                  : colors.border,
              disabledForegroundColor: colors.isDark
                  ? Colors.white38
                  : colors.muted,
              elevation: 0,
              minimumSize: Size(double.infinity, responsive.sp(44)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
              textStyle: TextStyle(
                fontSize: responsive.sp(12),
                fontWeight: FontWeight.w600,
              ),
            ),
            child: enviando
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
                        resultado != null
                            ? Icons.check_rounded
                            : Icons.check_circle_outline_rounded,
                        size: responsive.sp(16),
                      ),
                      SizedBox(width: responsive.sp(6)),
                      Text(resultado != null ? 'Respondida' : 'Responder'),
                    ],
                  ),
          ),
          SizedBox(height: responsive.sp(14)),
          Divider(height: 1, color: colors.borderSoft),
          SizedBox(height: responsive.sp(12)),
          _UtilityBar(
            colors: colors,
            responsive: responsive,
            comentarios: questao.totalComentarios,
            onComentarios: onComentarios,
            onIaExplica: onIaExplica,
            onSalvarCaderno: onSalvarCaderno,
            onGerarResumo: onGerarResumo,
            onCriarFlashcard: onCriarFlashcard,
            onReportar: onReportar,
          ),
        ],
      ),
    );
  }

  _OptionState _estadoAlternativa(String letra) {
    final correta = resultado?.letraCorreta;
    if (resultado != null && correta != null) {
      if (letra == correta) return _OptionState.correta;
      if (letra == letraSelecionada) return _OptionState.errada;
      return _OptionState.normal;
    }
    if (letra == letraSelecionada) return _OptionState.selecionada;
    return _OptionState.normal;
  }

  String _statusLabel(bool? status) {
    if (status == null) return '• Não avaliada';
    return status ? '✓ Acertou' : '✕ Errou';
  }

  _TagTone _statusTone(bool? status) {
    if (status == null) return _TagTone.slate;
    return status ? _TagTone.green : _TagTone.rose;
  }

  String _metadata(Questao questao) {
    final partes = <String>[
      if (questao.nomeBanca?.trim().isNotEmpty ?? false)
        questao.nomeBanca!.trim(),
      if (questao.nomeOrgao?.trim().isNotEmpty ?? false)
        questao.nomeOrgao!.trim(),
      if (questao.nomeCargo?.trim().isNotEmpty ?? false)
        questao.nomeCargo!.trim(),
      if (questao.ano != null) '${questao.ano}',
    ];
    return partes.join(' • ');
  }
}

enum _AnnotationTool { pen, highlighter, eraser }

class _AnnotationStroke {
  const _AnnotationStroke({required this.tool, required this.points});

  final _AnnotationTool tool;
  final List<Offset> points;
}

class _QuestionAnnotationToolbar extends StatelessWidget {
  const _QuestionAnnotationToolbar({
    required this.colors,
    required this.responsive,
    required this.selectedTool,
    required this.onToolSelected,
  });

  final _QuestoesColors colors;
  final Responsive responsive;
  final _AnnotationTool? selectedTool;
  final ValueChanged<_AnnotationTool> onToolSelected;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('questoes-ferramentas-anotacao'),
    padding: EdgeInsets.all(responsive.sp(2)),
    decoration: BoxDecoration(
      color: colors.cardInner,
      borderRadius: BorderRadius.circular(responsive.sp(10)),
      border: Border.all(color: colors.borderSoft),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AnnotationToolButton(
          key: const Key('questoes-ferramenta-caneta'),
          colors: colors,
          responsive: responsive,
          label: 'Caneta',
          icon: Icons.edit_outlined,
          selected: selectedTool == _AnnotationTool.pen,
          onTap: () => onToolSelected(_AnnotationTool.pen),
        ),
        SizedBox(width: responsive.sp(1)),
        _AnnotationToolButton(
          key: const Key('questoes-ferramenta-marca-texto'),
          colors: colors,
          responsive: responsive,
          label: 'Marca-texto',
          icon: Icons.border_color_outlined,
          selected: selectedTool == _AnnotationTool.highlighter,
          onTap: () => onToolSelected(_AnnotationTool.highlighter),
        ),
        SizedBox(width: responsive.sp(1)),
        _AnnotationToolButton(
          key: const Key('questoes-ferramenta-borracha'),
          colors: colors,
          responsive: responsive,
          label: 'Borracha',
          icon: Icons.backspace_outlined,
          eraserGlyph: true,
          selected: selectedTool == _AnnotationTool.eraser,
          onTap: () => onToolSelected(_AnnotationTool.eraser),
        ),
      ],
    ),
  );
}

class _AnnotationToolButton extends StatelessWidget {
  const _AnnotationToolButton({
    super.key,
    required this.colors,
    required this.responsive,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.eraserGlyph = false,
  });

  final _QuestoesColors colors;
  final Responsive responsive;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool eraserGlyph;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: selected
        ? '$label ativa. Toque para sair do modo desenho.'
        : label,
    child: Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(responsive.sp(8)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(responsive.sp(8)),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: Container(
                width: responsive.sp(30),
                height: responsive.sp(30),
                decoration: BoxDecoration(
                  color: selected ? colors.primarySoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(responsive.sp(8)),
                  border: Border.all(
                    color: selected ? colors.primaryBorder : Colors.transparent,
                  ),
                ),
                alignment: Alignment.center,
                child: eraserGlyph
                    ? CustomPaint(
                        size: Size.square(responsive.sp(15)),
                        painter: _EraserToolbarGlyphPainter(
                          selected ? colors.primary : colors.secondary,
                        ),
                      )
                    : Icon(
                        icon,
                        size: responsive.sp(15),
                        color: selected ? colors.primary : colors.secondary,
                      ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _EraserToolbarGlyphPainter extends CustomPainter {
  const _EraserToolbarGlyphPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final body = Path()
      ..moveTo(size.width * 0.17, size.height * 0.63)
      ..lineTo(size.width * 0.53, size.height * 0.22)
      ..quadraticBezierTo(
        size.width * 0.58,
        size.height * 0.16,
        size.width * 0.64,
        size.height * 0.22,
      )
      ..lineTo(size.width * 0.86, size.height * 0.42)
      ..quadraticBezierTo(
        size.width * 0.91,
        size.height * 0.47,
        size.width * 0.86,
        size.height * 0.53,
      )
      ..lineTo(size.width * 0.55, size.height * 0.87)
      ..close();
    canvas.drawPath(body, stroke);
    canvas.drawLine(
      Offset(size.width * 0.42, size.height * 0.35),
      Offset(size.width * 0.69, size.height * 0.60),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _EraserToolbarGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _QuestionAnnotationSurface extends StatefulWidget {
  const _QuestionAnnotationSurface({
    super.key,
    required this.tool,
    required this.strokes,
    required this.scale,
    required this.penColor,
    required this.onStrokeCompleted,
    required this.onErase,
    required this.child,
  });

  final _AnnotationTool? tool;
  final List<_AnnotationStroke> strokes;
  final double scale;
  final Color penColor;
  final ValueChanged<_AnnotationStroke> onStrokeCompleted;
  final void Function(List<Offset> points, Size size) onErase;
  final Widget child;

  @override
  State<_QuestionAnnotationSurface> createState() =>
      _QuestionAnnotationSurfaceState();
}

class _QuestionAnnotationSurfaceState
    extends State<_QuestionAnnotationSurface> {
  final _surfaceKey = GlobalKey();
  List<Offset> _currentPoints = [];
  int? _activePointer;

  @override
  void didUpdateWidget(covariant _QuestionAnnotationSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tool != widget.tool) {
      _currentPoints = [];
      _activePointer = null;
    }
  }

  RenderBox? get _surfaceBox {
    final renderObject = _surfaceKey.currentContext?.findRenderObject();
    return renderObject is RenderBox && renderObject.hasSize
        ? renderObject
        : null;
  }

  Offset? _normalize(Offset globalPosition) {
    final box = _surfaceBox;
    if (box == null || box.size.width <= 0 || box.size.height <= 0) return null;
    final local = box.globalToLocal(globalPosition);
    return Offset(
      (local.dx / box.size.width).clamp(0.0, 1.0).toDouble(),
      (local.dy / box.size.height).clamp(0.0, 1.0).toDouble(),
    );
  }

  void _pointerDown(PointerDownEvent event) {
    if (_activePointer != null) return;
    final point = _normalize(event.position);
    final size = _surfaceBox?.size;
    if (point == null || size == null) return;
    _activePointer = event.pointer;
    setState(() => _currentPoints = [point]);
    if (widget.tool == _AnnotationTool.eraser) {
      widget.onErase([point], size);
    }
  }

  void _pointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;
    final point = _normalize(event.position);
    if (point == null) return;
    final size = _surfaceBox?.size;
    setState(() => _currentPoints = [..._currentPoints, point]);
    if (widget.tool == _AnnotationTool.eraser && size != null) {
      widget.onErase([point], size);
    }
  }

  void _pointerUp(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    final tool = widget.tool;
    final points = List<Offset>.unmodifiable(_currentPoints);
    final size = _surfaceBox?.size;
    _activePointer = null;
    setState(() => _currentPoints = []);
    if (tool == null || points.isEmpty || size == null) return;
    if (tool == _AnnotationTool.eraser) {
      return;
    } else {
      widget.onStrokeCompleted(_AnnotationStroke(tool: tool, points: points));
    }
  }

  void _pointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    setState(() => _currentPoints = []);
  }

  _QuestionAnnotationPainter _painter() => _QuestionAnnotationPainter(
    strokes: widget.strokes,
    currentPoints: _currentPoints,
    currentTool: widget.tool,
    penColor: widget.penColor,
    scale: widget.scale,
  );

  @override
  Widget build(BuildContext context) {
    final annotationLayer = CustomPaint(
      key: ValueKey('questao-anotacao-tracos-${widget.strokes.length}'),
      foregroundPainter: _painter(),
      child: widget.tool == null
          ? widget.child
          : AbsorbPointer(absorbing: true, child: widget.child),
    );
    if (widget.tool == null) return annotationLayer;
    return Listener(
      key: _surfaceKey,
      behavior: HitTestBehavior.opaque,
      onPointerDown: _pointerDown,
      onPointerMove: _pointerMove,
      onPointerUp: _pointerUp,
      onPointerCancel: _pointerCancel,
      child: annotationLayer,
    );
  }
}

class _QuestionAnnotationPainter extends CustomPainter {
  const _QuestionAnnotationPainter({
    required this.strokes,
    required this.currentPoints,
    required this.currentTool,
    required this.penColor,
    required this.scale,
  });

  final List<_AnnotationStroke> strokes;
  final List<Offset> currentPoints;
  final _AnnotationTool? currentTool;
  final Color penColor;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _drawStroke(canvas, size, stroke.tool, stroke.points);
    }
    if (currentTool == null || currentPoints.isEmpty) return;
    if (currentTool == _AnnotationTool.eraser) {
      final point = currentPoints.last;
      final local = Offset(point.dx * size.width, point.dy * size.height);
      canvas.drawCircle(
        local,
        11 * scale,
        Paint()..color = Colors.black.withValues(alpha: 0.16),
      );
      canvas.drawCircle(
        local,
        11 * scale,
        Paint()
          ..color = penColor.withValues(alpha: 0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 * scale,
      );
      return;
    }
    _drawStroke(canvas, size, currentTool!, currentPoints);
  }

  void _drawStroke(
    Canvas canvas,
    Size size,
    _AnnotationTool tool,
    List<Offset> points,
  ) {
    if (points.isEmpty) return;
    final marker = tool == _AnnotationTool.highlighter;
    final paint = Paint()
      ..color = marker
          ? const Color(0xFFFFD740).withValues(alpha: 0.42)
          : penColor
      ..strokeWidth = (marker ? 15 : 2.7) * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final localPoints = points
        .map((point) => Offset(point.dx * size.width, point.dy * size.height))
        .toList(growable: false);
    if (localPoints.length == 1) {
      canvas.drawCircle(localPoints.single, paint.strokeWidth / 2, paint);
      return;
    }
    final path = Path()..moveTo(localPoints.first.dx, localPoints.first.dy);
    for (final point in localPoints.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _QuestionAnnotationPainter oldDelegate) => true;
}

/// Texto de apoio da questão (leis, trechos, tabelas) com o mesmo
/// comportamento do desktop: começa expandido e pode ser minimizado para
/// liberar espaço para o enunciado e as alternativas.
class _SupportTextBox extends StatefulWidget {
  const _SupportTextBox({
    super.key,
    required this.colors,
    required this.responsive,
    required this.titulo,
    required this.texto,
  });

  final _QuestoesColors colors;
  final Responsive responsive;
  final String titulo;
  final String texto;

  @override
  State<_SupportTextBox> createState() => _SupportTextBoxState();
}

class _SupportTextBoxState extends State<_SupportTextBox> {
  bool _expandido = true;

  void _alternar() => setState(() => _expandido = !_expandido);

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final responsive = widget.responsive;
    final titulo = widget.titulo.trim();

    return Container(
      decoration: BoxDecoration(
        color: colors.cardInner,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _alternar,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                responsive.sp(11),
                responsive.sp(7),
                responsive.sp(6),
                responsive.sp(7),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: responsive.sp(15),
                    color: colors.primary,
                  ),
                  SizedBox(width: responsive.sp(7)),
                  Expanded(
                    child: Text(
                      'TEXTO DE APOIO',
                      style: TextStyle(
                        fontSize: responsive.sp(10),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: colors.primary,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('texto-apoio-toggle'),
                    onPressed: _alternar,
                    icon: Icon(
                      _expandido
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: responsive.sp(16),
                    ),
                    label: Text(_expandido ? 'Minimizar' : 'Expandir'),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.primary,
                      minimumSize: Size(0, responsive.sp(28)),
                      padding: EdgeInsets.symmetric(
                        horizontal: responsive.sp(7),
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: TextStyle(
                        fontSize: responsive.sp(10.5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: _expandido
                ? Padding(
                    padding: EdgeInsets.fromLTRB(
                      responsive.sp(12),
                      0,
                      responsive.sp(12),
                      responsive.sp(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Divider(height: 1, color: colors.borderSoft),
                        if (titulo.isNotEmpty) ...[
                          SizedBox(height: responsive.sp(10)),
                          LatexText(
                            titulo,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: responsive.sp(12),
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                              color: colors.primary,
                            ),
                          ),
                          SizedBox(height: responsive.sp(8)),
                          Divider(height: 1, color: colors.borderSoft),
                        ],
                        SizedBox(height: responsive.sp(10)),
                        LatexText(
                          widget.texto,
                          style: TextStyle(
                            fontSize: responsive.sp(11.5),
                            height: 1.6,
                            color: colors.secondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.colors,
    required this.responsive,
    required this.label,
    required this.tone,
  });

  final _QuestoesColors colors;
  final Responsive responsive;
  final String label;
  final _TagTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, border, text) = switch (tone) {
      _TagTone.slate => (colors.cardInner, colors.border, colors.secondary),
      _TagTone.indigo => (
        colors.primarySoft,
        colors.primaryBorder,
        colors.isDark ? const Color(0xFFC7D2FE) : const Color(0xFF4338CA),
      ),
      _TagTone.blue => (colors.infoBg, colors.infoBorder, colors.infoText),
      _TagTone.green => (
        colors.successBg,
        colors.successBorder,
        colors.success,
      ),
      _TagTone.rose => (colors.dangerBg, colors.dangerBorder, colors.danger),
      _TagTone.amber => (
        colors.warningBg,
        colors.warningBorder,
        colors.warning,
      ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.sp(8),
        vertical: responsive.sp(3),
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: responsive.sp(9.5),
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }
}

enum _TagTone { slate, indigo, blue, green, rose, amber }

enum _OptionState { normal, selecionada, correta, errada }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.colors,
    required this.responsive,
    required this.letra,
    required this.texto,
    required this.estado,
    required this.eliminada,
    required this.onTap,
    required this.onToggleEliminada,
  });

  final _QuestoesColors colors;
  final Responsive responsive;
  final String letra;
  final String texto;
  final _OptionState estado;
  final bool eliminada;
  final VoidCallback? onTap;
  final VoidCallback? onToggleEliminada;

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
      _OptionState.selecionada => (
        colors.primarySoft,
        colors.primary,
        2.0,
        colors.primary,
        Colors.white,
        colors.text,
      ),
      _OptionState.correta => (
        colors.successBg,
        colors.success,
        2.0,
        colors.success,
        colors.isDark ? const Color(0xFF06281E) : Colors.white,
        colors.text,
      ),
      _OptionState.errada => (
        colors.dangerBg,
        colors.danger,
        2.0,
        colors.danger,
        Colors.white,
        colors.text,
      ),
      _OptionState.normal => (
        colors.card,
        colors.border,
        1.0,
        colors.cardInner,
        colors.secondary,
        colors.secondary,
      ),
    };

    return Padding(
      padding: EdgeInsets.only(bottom: responsive.sp(8)),
      child: Material(
        color: eliminada ? colors.cardInner : fundo,
        borderRadius: BorderRadius.circular(11),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: eliminada ? colors.borderSoft : borda,
              width: larguraBorda,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  onTap: eliminada ? null : onTap,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: responsive.sp(10),
                      vertical: responsive.sp(9),
                    ),
                    child: Opacity(
                      opacity: eliminada ? 0.45 : 1,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: responsive.sp(28),
                            height: responsive.sp(28),
                            decoration: BoxDecoration(
                              color: fundoLetra,
                              borderRadius: BorderRadius.circular(8),
                              border: estado == _OptionState.normal
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
                                decoration: eliminada
                                    ? TextDecoration.lineThrough
                                    : null,
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
                                      estado == _OptionState.correta ||
                                          estado == _OptionState.selecionada
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: corTexto,
                                  decoration: eliminada
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          if (estado == _OptionState.correta)
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
                          else if (estado == _OptionState.errada)
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
              ),
              if (onToggleEliminada != null)
                IconButton(
                  key: ValueKey('alternativa-tesoura-$letra'),
                  onPressed: onToggleEliminada,
                  tooltip: eliminada
                      ? 'Restaurar alternativa $letra'
                      : 'Riscar alternativa $letra',
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  color: eliminada ? colors.danger : colors.muted,
                  icon: Icon(
                    Icons.content_cut_rounded,
                    size: responsive.sp(16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscursivaNote extends StatelessWidget {
  const _DiscursivaNote({required this.colors, required this.responsive});

  final _QuestoesColors colors;
  final Responsive responsive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(responsive.sp(12)),
      decoration: BoxDecoration(
        color: colors.cardInner,
        borderRadius: BorderRadius.circular(10),
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

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({
    required this.colors,
    required this.responsive,
    required this.resultado,
  });

  final _QuestoesColors colors;
  final Responsive responsive;
  final RespostaQuestaoResultado resultado;

  @override
  Widget build(BuildContext context) {
    final correta = resultado.correta;
    final fundo = correta ? colors.successBg : colors.dangerBg;
    final borda = correta ? colors.successBorder : colors.dangerBorder;
    final destaque = correta ? colors.success : colors.danger;

    return Container(
      padding: EdgeInsets.all(responsive.sp(11)),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: borda),
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
                        ? 'Resposta correta! '
                        : 'Resposta incorreta. ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: destaque,
                    ),
                  ),
                  if (resultado.letraCorreta != null)
                    TextSpan(text: 'Gabarito: ${resultado.letraCorreta}.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UtilityBar extends StatelessWidget {
  const _UtilityBar({
    required this.colors,
    required this.responsive,
    required this.comentarios,
    required this.onComentarios,
    required this.onIaExplica,
    required this.onSalvarCaderno,
    required this.onGerarResumo,
    required this.onCriarFlashcard,
    required this.onReportar,
  });

  final _QuestoesColors colors;
  final Responsive responsive;
  final int comentarios;
  final VoidCallback onComentarios;
  final VoidCallback onIaExplica;
  final VoidCallback onSalvarCaderno;
  final VoidCallback onGerarResumo;
  final VoidCallback onCriarFlashcard;
  final VoidCallback onReportar;

  @override
  Widget build(BuildContext context) {
    final esquerda = <Widget>[
      _UtilityButton(
        colors: colors,
        responsive: responsive,
        icon: Icons.chat_bubble_outline_rounded,
        label: 'Comentários',
        count: comentarios,
        tone: _UtilityTone.neutral,
        onTap: onComentarios,
      ),
      _UtilityButton(
        colors: colors,
        responsive: responsive,
        icon: Icons.bolt_rounded,
        label: 'IA Explica',
        tone: _UtilityTone.purple,
        onTap: onIaExplica,
      ),
    ];
    final direita = <Widget>[
      _SaveMenuButton(
        colors: colors,
        responsive: responsive,
        onSalvarCaderno: onSalvarCaderno,
        onGerarResumo: onGerarResumo,
        onCriarFlashcard: onCriarFlashcard,
      ),
      _UtilityButton(
        colors: colors,
        responsive: responsive,
        icon: Icons.flag_outlined,
        label: 'Reportar',
        tone: _UtilityTone.warningOutline,
        onTap: onReportar,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cabeEmLinha = constraints.maxWidth >= responsive.sp(430);
        if (cabeEmLinha) {
          return Row(
            children: [
              Wrap(spacing: responsive.sp(7), children: esquerda),
              const Spacer(),
              Wrap(spacing: responsive.sp(7), children: direita),
            ],
          );
        }
        return Wrap(
          spacing: responsive.sp(7),
          runSpacing: responsive.sp(7),
          children: [...esquerda, ...direita],
        );
      },
    );
  }
}

enum _UtilityTone { neutral, purple, successOutline, warningOutline }

enum _SaveQuestionAction { cadernos, resumo, flashcard }

class _SaveMenuButton extends StatelessWidget {
  const _SaveMenuButton({
    required this.colors,
    required this.responsive,
    required this.onSalvarCaderno,
    required this.onGerarResumo,
    required this.onCriarFlashcard,
  });

  final _QuestoesColors colors;
  final Responsive responsive;
  final VoidCallback onSalvarCaderno;
  final VoidCallback onGerarResumo;
  final VoidCallback onCriarFlashcard;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SaveQuestionAction>(
      key: const Key('questao-menu-salvar'),
      tooltip: 'Salvar e estudar questão',
      onSelected: (action) {
        switch (action) {
          case _SaveQuestionAction.cadernos:
            onSalvarCaderno();
          case _SaveQuestionAction.resumo:
            onGerarResumo();
          case _SaveQuestionAction.flashcard:
            onCriarFlashcard();
        }
      },
      color: colors.isDark ? colors.bg : colors.card,
      elevation: 6,
      offset: Offset(0, -responsive.sp(8)),
      constraints: BoxConstraints(
        minWidth: responsive.sp(218),
        maxWidth: responsive.sp(270),
      ),
      menuPadding: EdgeInsets.symmetric(vertical: responsive.sp(5)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(responsive.sp(13)),
        side: BorderSide(color: colors.border),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<_SaveQuestionAction>(
          enabled: false,
          height: responsive.sp(34),
          child: _SaveMenuHeading(
            colors: colors,
            responsive: responsive,
            label: 'ORGANIZAÇÃO',
          ),
        ),
        PopupMenuItem<_SaveQuestionAction>(
          key: const Key('questao-menu-meus-cadernos'),
          value: _SaveQuestionAction.cadernos,
          height: responsive.sp(46),
          child: _SaveMenuEntry(
            colors: colors,
            responsive: responsive,
            icon: Icons.create_new_folder_outlined,
            iconColor: colors.primary,
            label: 'Meus Cadernos',
          ),
        ),
        PopupMenuDivider(height: responsive.sp(12)),
        PopupMenuItem<_SaveQuestionAction>(
          enabled: false,
          height: responsive.sp(34),
          child: _SaveMenuHeading(
            colors: colors,
            responsive: responsive,
            label: 'ESTUDO COM IA',
          ),
        ),
        PopupMenuItem<_SaveQuestionAction>(
          key: const Key('questao-menu-gerar-resumo'),
          value: _SaveQuestionAction.resumo,
          height: responsive.sp(46),
          child: _SaveMenuEntry(
            colors: colors,
            responsive: responsive,
            icon: Icons.sticky_note_2_outlined,
            iconColor: colors.success,
            label: 'Gerar Resumo (IA)',
          ),
        ),
        PopupMenuItem<_SaveQuestionAction>(
          key: const Key('questao-menu-criar-flashcard'),
          value: _SaveQuestionAction.flashcard,
          height: responsive.sp(46),
          child: _SaveMenuEntry(
            colors: colors,
            responsive: responsive,
            icon: Icons.layers_rounded,
            iconColor: colors.infoText,
            label: 'Criar Flashcard (IA)',
          ),
        ),
      ],
      child: _UtilityButton(
        colors: colors,
        responsive: responsive,
        icon: Icons.bookmark_border_rounded,
        label: 'Salvar',
        tone: _UtilityTone.successOutline,
        onTap: null,
      ),
    );
  }
}

class _SaveMenuHeading extends StatelessWidget {
  const _SaveMenuHeading({
    required this.colors,
    required this.responsive,
    required this.label,
  });

  final _QuestoesColors colors;
  final Responsive responsive;
  final String label;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: EdgeInsets.only(left: responsive.sp(4)),
      child: Text(
        label,
        style: TextStyle(
          color: colors.secondary,
          fontSize: responsive.sp(9.5),
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    ),
  );
}

class _SaveMenuEntry extends StatelessWidget {
  const _SaveMenuEntry({
    required this.colors,
    required this.responsive,
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  final _QuestoesColors colors;
  final Responsive responsive;
  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: responsive.sp(18), color: iconColor),
      SizedBox(width: responsive.sp(10)),
      Expanded(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.text,
            fontSize: responsive.sp(12),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}

class _UtilityButton extends StatelessWidget {
  const _UtilityButton({
    required this.colors,
    required this.responsive,
    required this.icon,
    required this.label,
    required this.tone,
    required this.onTap,
    this.count,
  });

  final _QuestoesColors colors;
  final Responsive responsive;
  final IconData icon;
  final String label;
  final _UtilityTone tone;
  final VoidCallback? onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final (fundo, borda, cor) = switch (tone) {
      _UtilityTone.neutral => (
        colors.cardInner,
        colors.border,
        colors.secondary,
      ),
      _UtilityTone.purple => (
        colors.aiAccent,
        Colors.transparent,
        Colors.white,
      ),
      _UtilityTone.successOutline => (
        colors.card,
        colors.successBorder,
        colors.success,
      ),
      _UtilityTone.warningOutline => (
        colors.card,
        colors.warningBorder,
        colors.warning,
      ),
    };
    final destaque = tone == _UtilityTone.purple;

    return Material(
      color: fundo,
      borderRadius: BorderRadius.circular(9),
      clipBehavior: Clip.antiAlias,
      child: Builder(
        builder: (context) {
          final content = Container(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.sp(9),
              vertical: responsive.sp(7),
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: borda),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: responsive.sp(13), color: cor),
                SizedBox(width: responsive.sp(5)),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: responsive.sp(11),
                    fontWeight: destaque ? FontWeight.w600 : FontWeight.w500,
                    color: cor,
                  ),
                ),
                if (count != null) ...[
                  SizedBox(width: responsive.sp(5)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: responsive.sp(5),
                      vertical: responsive.sp(1),
                    ),
                    decoration: BoxDecoration(
                      color: colors.isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: responsive.sp(9),
                        fontWeight: FontWeight.w700,
                        color: colors.secondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
          if (onTap == null) return content;
          return InkWell(onTap: onTap, child: content);
        },
      ),
    );
  }
}

class _ExplanationFeedback {
  const _ExplanationFeedback({required this.motivo, required this.relato});

  final String motivo;
  final String relato;
}

class _ExplanationFeedbackDialog extends StatefulWidget {
  const _ExplanationFeedbackDialog({required this.colors});

  final _QuestoesColors colors;

  @override
  State<_ExplanationFeedbackDialog> createState() =>
      _ExplanationFeedbackDialogState();
}

class _ExplanationFeedbackDialogState
    extends State<_ExplanationFeedbackDialog> {
  final _formKey = GlobalKey<FormState>();
  final _relatoController = TextEditingController();
  String? _motivo;

  @override
  void dispose() {
    _relatoController.dispose();
    super.dispose();
  }

  void _enviar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _ExplanationFeedback(
        motivo: _motivo!,
        relato: _relatoController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final responsive = Responsive.of(context);
    return Dialog(
      key: const Key('ia-explicacao-feedback-dialog'),
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: responsive.sp(18),
        vertical: responsive.sp(24),
      ),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(responsive.sp(15)),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: responsive.sp(520),
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  responsive.sp(20),
                  responsive.sp(19),
                  responsive.sp(20),
                  responsive.sp(13),
                ),
                child: Text(
                  'Reportar problema nesta explicação',
                  key: const Key('ia-explicacao-feedback-titulo'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: responsive.sp(17),
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.35,
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    responsive.sp(16),
                    0,
                    responsive.sp(16),
                    responsive.sp(15),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          key: const Key('ia-explicacao-feedback-motivo'),
                          initialValue: _motivo,
                          isExpanded: true,
                          decoration: _iaFeedbackInputDecoration(
                            colors,
                            responsive,
                          ),
                          hint: Text(
                            'Selecione o motivo...',
                            style: TextStyle(
                              color: colors.secondary,
                              fontSize: responsive.sp(11.5),
                            ),
                          ),
                          items: [
                            for (final entry
                                in StudyAiRepository.motivosFeedback.entries)
                              DropdownMenuItem(
                                value: entry.key,
                                child: Text(
                                  entry.value,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          validator: (value) =>
                              value == null ? 'Selecione um motivo.' : null,
                          onChanged: (value) => setState(() => _motivo = value),
                        ),
                        SizedBox(height: responsive.sp(9)),
                        TextFormField(
                          key: const Key('ia-explicacao-feedback-relato'),
                          controller: _relatoController,
                          minLines: 3,
                          maxLines: 3,
                          maxLength: 1000,
                          textCapitalization: TextCapitalization.sentences,
                          style: TextStyle(
                            color: colors.text,
                            fontSize: responsive.sp(11.5),
                            height: 1.4,
                          ),
                          decoration: _iaFeedbackInputDecoration(
                            colors,
                            responsive,
                            hint: 'Descreva o problema (opcional)',
                          ).copyWith(alignLabelWithHint: true, counterText: ''),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Divider(height: 1, color: colors.border),
              Padding(
                padding: EdgeInsets.all(responsive.sp(11)),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: responsive.sp(8),
                  runSpacing: responsive.sp(8),
                  children: [
                    FilledButton(
                      key: const Key('ia-explicacao-feedback-enviar'),
                      onPressed: _enviar,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: Size(0, responsive.sp(46)),
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.sp(16),
                        ),
                        textStyle: TextStyle(
                          fontSize: responsive.sp(10.5),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: const Text('Enviar reporte'),
                    ),
                    FilledButton(
                      key: const Key('ia-explicacao-feedback-cancelar'),
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.isDark
                            ? const Color(0xFF374151)
                            : const Color(0xFFE2E8F0),
                        foregroundColor: colors.text,
                        minimumSize: Size(0, responsive.sp(46)),
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.sp(16),
                        ),
                        textStyle: TextStyle(
                          fontSize: responsive.sp(10.5),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('Cancelar'),
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

InputDecoration _iaFeedbackInputDecoration(
  _QuestoesColors colors,
  Responsive responsive, {
  String? hint,
}) => InputDecoration(
  hintText: hint,
  hintStyle: TextStyle(color: colors.secondary, fontSize: responsive.sp(11.5)),
  filled: true,
  fillColor: colors.inputBg,
  contentPadding: EdgeInsets.symmetric(
    horizontal: responsive.sp(12),
    vertical: responsive.sp(11),
  ),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(responsive.sp(8)),
    borderSide: BorderSide(color: colors.border),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(responsive.sp(8)),
    borderSide: BorderSide(color: colors.border),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(responsive.sp(8)),
    borderSide: BorderSide(color: colors.aiAccent, width: 1.4),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(responsive.sp(8)),
    borderSide: BorderSide(color: colors.danger),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(responsive.sp(8)),
    borderSide: BorderSide(color: colors.danger, width: 1.4),
  ),
);

class _QuestionFeedback {
  const _QuestionFeedback({required this.tipoErro, required this.descricao});

  final String tipoErro;
  final String descricao;
}

class _QuestionFeedbackDialog extends StatefulWidget {
  const _QuestionFeedbackDialog({required this.colors});

  final _QuestoesColors colors;

  @override
  State<_QuestionFeedbackDialog> createState() =>
      _QuestionFeedbackDialogState();
}

class _QuestionFeedbackDialogState extends State<_QuestionFeedbackDialog> {
  static const _tiposErro = [
    'Gabarito Errado',
    'Questão Desatualizada',
    'Erro de Digitação/Formatação',
    'Falta de Alternativa Correta',
    'Outro',
  ];

  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();
  String? _tipoErro;

  @override
  void dispose() {
    _descricaoController.dispose();
    super.dispose();
  }

  void _enviar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _QuestionFeedback(
        tipoErro: _tipoErro!,
        descricao: _descricaoController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final responsive = Responsive.of(context);
    return Dialog(
      key: const Key('questao-report-dialog'),
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: responsive.sp(18),
        vertical: responsive.sp(24),
      ),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(responsive.sp(17)),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: responsive.sp(520),
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(
                  responsive.sp(17),
                  responsive.sp(11),
                  responsive.sp(8),
                  responsive.sp(11),
                ),
                color: const Color(0xFFEF4444),
                child: Row(
                  children: [
                    Icon(
                      Icons.flag_rounded,
                      color: Colors.white,
                      size: responsive.sp(19),
                    ),
                    SizedBox(width: responsive.sp(9)),
                    Expanded(
                      child: Text(
                        'Reportar Erro na Questão',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: responsive.sp(14),
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('questao-report-close'),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Fechar',
                      style: IconButton.styleFrom(
                        foregroundColor: Colors.white,
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(responsive.sp(17)),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'QUAL É O PROBLEMA COM A QUESTÃO?',
                          style: TextStyle(
                            color: colors.secondary,
                            fontSize: responsive.sp(9.5),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.35,
                          ),
                        ),
                        SizedBox(height: responsive.sp(7)),
                        DropdownButtonFormField<String>(
                          key: const Key('questao-report-tipo'),
                          initialValue: _tipoErro,
                          isExpanded: true,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: colors.inputBg,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: responsive.sp(11),
                              vertical: responsive.sp(10),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                responsive.sp(8),
                              ),
                              borderSide: BorderSide(color: colors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                responsive.sp(8),
                              ),
                              borderSide: BorderSide(color: colors.border),
                            ),
                          ),
                          hint: Text(
                            'Selecione uma opção...',
                            style: TextStyle(color: colors.secondary),
                          ),
                          items: [
                            for (final tipo in _tiposErro)
                              DropdownMenuItem(
                                value: tipo,
                                child: Text(
                                  tipo,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          validator: (value) => value == null
                              ? 'Selecione o problema encontrado.'
                              : null,
                          onChanged: (value) =>
                              setState(() => _tipoErro = value),
                        ),
                        SizedBox(height: responsive.sp(16)),
                        Text(
                          'DESCREVA O ERRO (OPCIONAL)',
                          style: TextStyle(
                            color: colors.secondary,
                            fontSize: responsive.sp(9.5),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.35,
                          ),
                        ),
                        SizedBox(height: responsive.sp(7)),
                        TextFormField(
                          key: const Key('questao-report-descricao'),
                          controller: _descricaoController,
                          minLines: 4,
                          maxLines: 5,
                          textCapitalization: TextCapitalization.sentences,
                          style: TextStyle(
                            color: colors.text,
                            fontSize: responsive.sp(11.5),
                            height: 1.45,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Explique rapidamente o que está errado para que possamos corrigir...',
                            hintMaxLines: 3,
                            filled: true,
                            fillColor: colors.inputBg,
                            contentPadding: EdgeInsets.all(responsive.sp(11)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                responsive.sp(8),
                              ),
                              borderSide: BorderSide(color: colors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                responsive.sp(8),
                              ),
                              borderSide: BorderSide(color: colors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                responsive.sp(8),
                              ),
                              borderSide: BorderSide(
                                color: colors.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Divider(height: 1, color: colors.border),
              Padding(
                padding: EdgeInsets.all(responsive.sp(11)),
                child: Row(
                  children: [
                    const Spacer(),
                    TextButton(
                      key: const Key('questao-report-cancelar'),
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.secondary,
                        minimumSize: Size(0, responsive.sp(48)),
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.sp(10),
                        ),
                      ),
                      child: const Text('Cancelar'),
                    ),
                    SizedBox(width: responsive.sp(7)),
                    FilledButton.icon(
                      key: const Key('questao-report-enviar'),
                      onPressed: _enviar,
                      icon: Icon(Icons.send_rounded, size: responsive.sp(14)),
                      label: const Text('Enviar Reporte'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFDC3545),
                        foregroundColor: Colors.white,
                        minimumSize: Size(0, responsive.sp(48)),
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.sp(10),
                        ),
                        textStyle: TextStyle(
                          fontSize: responsive.sp(10.5),
                          fontWeight: FontWeight.w800,
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

class _EstudoGeradoDialog extends StatelessWidget {
  const _EstudoGeradoDialog({
    required this.colors,
    required this.tipo,
    required this.jaPossuia,
    required this.mensagem,
  });

  final _QuestoesColors colors;
  final StudyContentType tipo;
  final bool jaPossuia;
  final String mensagem;

  @override
  Widget build(BuildContext context) {
    final isResumo = tipo == StudyContentType.resumo;
    final acao = isResumo ? 'Ver Caderno' : 'Ver Flashcards';
    return AlertDialog(
      key: const Key('questao-estudo-gerado'),
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      icon: Icon(
        jaPossuia ? Icons.info_outline_rounded : Icons.check_circle_outline,
        color: jaPossuia ? colors.primary : colors.success,
        size: 30,
      ),
      title: Text(
        jaPossuia
            ? 'Já está no Caderno!'
            : isResumo
            ? 'Resumo Adicionado!'
            : 'Flashcard Criado!',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: colors.text,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Text(
        mensagem,
        textAlign: TextAlign.center,
        style: TextStyle(color: colors.secondary, fontSize: 12, height: 1.45),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          key: const Key('questao-estudo-continuar'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Continuar Estudando'),
        ),
        FilledButton(
          key: const Key('questao-estudo-ver'),
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 48),
          ),
          child: Text(acao),
        ),
      ],
    );
  }
}

class _QuestionNavigator extends StatelessWidget {
  const _QuestionNavigator({
    required this.colors,
    required this.responsive,
    required this.indice,
    required this.totalNaPagina,
    required this.pagina,
    required this.totalPaginas,
    required this.onAnterior,
    required this.onProxima,
    required this.onIrParaPagina,
  });

  final _QuestoesColors colors;
  final Responsive responsive;
  final int indice;
  final int totalNaPagina;
  final int pagina;
  final int totalPaginas;
  final VoidCallback onAnterior;
  final VoidCallback onProxima;
  final VoidCallback onIrParaPagina;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: responsive.sp(4)),
      decoration: _cardDecoration(colors),
      child: Row(
        children: [
          IconButton(
            onPressed: onAnterior,
            tooltip: 'Questão anterior',
            icon: Icon(Icons.chevron_left_rounded, size: responsive.sp(22)),
            color: colors.secondary,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Questão ${indice + 1} de $totalNaPagina',
                  style: TextStyle(
                    fontSize: responsive.sp(11),
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                Tooltip(
                  message: 'Ir para uma página específica',
                  child: TextButton.icon(
                    key: const Key('questoes-ir-para-pagina'),
                    onPressed: totalPaginas > 1 ? onIrParaPagina : null,
                    icon: Icon(Icons.edit_outlined, size: responsive.sp(11)),
                    label: Text('Página $pagina de $totalPaginas'),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.primary,
                      disabledForegroundColor: colors.muted,
                      minimumSize: Size(44, responsive.sp(34)),
                      padding: EdgeInsets.symmetric(
                        horizontal: responsive.sp(5),
                      ),
                      visualDensity: VisualDensity.compact,
                      textStyle: TextStyle(
                        fontSize: responsive.sp(9.5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onProxima,
            tooltip: 'Próxima questão',
            icon: Icon(Icons.chevron_right_rounded, size: responsive.sp(22)),
            color: colors.secondary,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _PageJumpDialog extends StatefulWidget {
  const _PageJumpDialog({
    required this.colors,
    required this.paginaAtual,
    required this.totalPaginas,
  });

  final _QuestoesColors colors;
  final int paginaAtual;
  final int totalPaginas;

  @override
  State<_PageJumpDialog> createState() => _PageJumpDialogState();
}

class _PageJumpDialogState extends State<_PageJumpDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.paginaAtual}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _ir() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(int.parse(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final responsive = Responsive.of(context);
    return AlertDialog(
      key: const Key('questoes-ir-para-pagina-dialog'),
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      title: Text(
        'Ir para página',
        style: TextStyle(
          color: colors.text,
          fontSize: responsive.sp(16),
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SizedBox(
        width: responsive.sp(320),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Digite um número entre 1 e ${widget.totalPaginas}.',
                style: TextStyle(
                  color: colors.secondary,
                  fontSize: responsive.sp(10.5),
                  height: 1.4,
                ),
              ),
              SizedBox(height: responsive.sp(12)),
              TextFormField(
                key: const Key('questoes-ir-para-pagina-input'),
                controller: _controller,
                autofocus: false,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.go,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onFieldSubmitted: (_) => _ir(),
                style: TextStyle(
                  color: colors.text,
                  fontSize: responsive.sp(18),
                  fontWeight: FontWeight.w800,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: colors.inputBg,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: responsive.sp(12),
                    vertical: responsive.sp(10),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(responsive.sp(10)),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(responsive.sp(10)),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(responsive.sp(10)),
                    borderSide: BorderSide(color: colors.primary, width: 1.4),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(responsive.sp(10)),
                    borderSide: BorderSide(color: colors.danger),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(responsive.sp(10)),
                    borderSide: BorderSide(color: colors.danger, width: 1.4),
                  ),
                ),
                validator: (value) {
                  final pagina = int.tryParse(value?.trim() ?? '');
                  if (pagina == null ||
                      pagina < 1 ||
                      pagina > widget.totalPaginas) {
                    return 'Informe uma página de 1 a ${widget.totalPaginas}.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          key: const Key('questoes-ir-para-pagina-cancelar'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('questoes-ir-para-pagina-confirmar'),
          onPressed: _ir,
          style: FilledButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 46),
          ),
          child: const Text('Ir para página'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Explicação
// ---------------------------------------------------------------------------

class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard({
    required this.colors,
    required this.responsive,
    required this.carregando,
    required this.explicacao,
    required this.erro,
    required this.comentarioGabarito,
    required this.onGerar,
    required this.onFechar,
    required this.onReportar,
  });

  final _QuestoesColors colors;
  final Responsive responsive;
  final bool carregando;
  final String? explicacao;
  final String? erro;
  final String? comentarioGabarito;
  final VoidCallback onGerar;
  final VoidCallback onFechar;
  final VoidCallback? onReportar;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.aiBorder),
        boxShadow: colors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.sp(14),
              vertical: responsive.sp(8),
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors.aiGradient),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.bolt_rounded,
                  size: responsive.sp(18),
                  color: Colors.white,
                ),
                SizedBox(width: responsive.sp(6)),
                Expanded(
                  child: Text(
                    'Explicação Passo a Passo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: responsive.sp(11.5),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: Colors.white,
                    ),
                  ),
                ),
                _HeaderIconButton(
                  responsive: responsive,
                  icon: Icons.flag_outlined,
                  tooltip: 'Reportar explicação',
                  onTap: onReportar,
                ),
                SizedBox(width: responsive.sp(2)),
                _HeaderIconButton(
                  responsive: responsive,
                  icon: Icons.close_rounded,
                  tooltip: 'Fechar resolução',
                  onTap: onFechar,
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(responsive.sp(14)),
            child: _corpo(context),
          ),
        ],
      ),
    );
  }

  Widget _corpo(BuildContext context) {
    if (carregando) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: responsive.sp(20)),
        child: Column(
          children: [
            SizedBox(
              width: responsive.sp(22),
              height: responsive.sp(22),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.aiAccent,
              ),
            ),
            SizedBox(height: responsive.sp(10)),
            Text(
              'Gerando explicação...',
              style: TextStyle(
                fontSize: responsive.sp(11.5),
                color: colors.secondary,
              ),
            ),
          ],
        ),
      );
    }

    if (explicacao != null) {
      return _ExplanationContent(
        colors: colors,
        responsive: responsive,
        texto: explicacao!,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (erro != null) ...[
          Container(
            padding: EdgeInsets.all(responsive.sp(10)),
            decoration: BoxDecoration(
              color: colors.dangerBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.dangerBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: responsive.sp(16),
                  color: colors.danger,
                ),
                SizedBox(width: responsive.sp(7)),
                Expanded(
                  child: Text(
                    erro!,
                    style: TextStyle(
                      fontSize: responsive.sp(11),
                      height: 1.4,
                      color: colors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: responsive.sp(10)),
        ],
        if (comentarioGabarito != null) ...[
          _ExplanationContent(
            colors: colors,
            responsive: responsive,
            texto: _htmlParaTexto(comentarioGabarito!),
          ),
          SizedBox(height: responsive.sp(10)),
        ],
        Text(
          'Quer entender cada alternativa e a pegadinha da banca? Peça uma '
          'explicação detalhada para o professor de IA.',
          style: TextStyle(
            fontSize: responsive.sp(11.5),
            height: 1.45,
            color: colors.secondary,
          ),
        ),
        SizedBox(height: responsive.sp(10)),
        OutlinedButton.icon(
          onPressed: onGerar,
          icon: Icon(Icons.auto_awesome_rounded, size: responsive.sp(15)),
          label: Text(
            erro == null ? 'Gerar explicação com IA' : 'Tentar novamente',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.aiAccent,
            side: BorderSide(color: colors.aiBorder),
            minimumSize: Size(double.infinity, responsive.sp(38)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: TextStyle(
              fontSize: responsive.sp(11.5),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.responsive,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final Responsive responsive;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: EdgeInsets.all(responsive.sp(3)),
          child: Icon(
            icon,
            size: responsive.sp(16),
            color: Colors.white.withValues(alpha: onTap == null ? 0.35 : 0.85),
          ),
        ),
      ),
    );
  }
}

class _ExplanationSectionData {
  const _ExplanationSectionData({required this.titulo, required this.corpo});

  final String titulo;
  final String corpo;
}

class _ExplanationContent extends StatelessWidget {
  const _ExplanationContent({
    required this.colors,
    required this.responsive,
    required this.texto,
  });

  final _QuestoesColors colors;
  final Responsive responsive;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final secoes = _parseSecoes(LatexText.prepararBlocosCodigo(texto));
    return Container(
      key: const Key('questao-ia-conteudo-unico'),
      width: double.infinity,
      margin: EdgeInsets.only(bottom: responsive.sp(10)),
      padding: EdgeInsets.all(responsive.sp(12)),
      decoration: BoxDecoration(
        color: colors.cardInner,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < secoes.length; index++) ...[
            if (index > 0) SizedBox(height: responsive.sp(9)),
            Text(
              secoes[index].titulo,
              style: TextStyle(
                fontSize: responsive.sp(11.5),
                fontWeight: FontWeight.w800,
                color: colors.text,
              ),
            ),
            if (secoes[index].corpo.trim().isNotEmpty) ...[
              SizedBox(height: responsive.sp(4)),
              _RichBody(
                colors: colors,
                responsive: responsive,
                texto: secoes[index].corpo,
              ),
            ],
          ],
        ],
      ),
    );
  }

  List<_ExplanationSectionData> _parseSecoes(String texto) {
    final linhas = texto.replaceAll('\r\n', '\n').split('\n');
    final secoes = <_ExplanationSectionData>[];
    String? titulo;
    final buffer = <String>[];

    void fechar() {
      final corpo = buffer.join('\n').trim();
      buffer.clear();
      if (corpo.isEmpty) {
        titulo = null;
        return;
      }
      final nome = titulo ?? '🧠 Resolução Comentada';
      secoes.add(_ExplanationSectionData(titulo: nome, corpo: corpo));
      titulo = null;
    }

    for (final linha in linhas) {
      final limpa = linha.trim();
      final eTituloMarkdown = limpa.startsWith('#');
      final tituloLinha = eTituloMarkdown
          ? limpa.replaceFirst(RegExp(r'^#+\s*'), '').trim()
          : limpa;
      if (eTituloMarkdown || _ehTituloSemMarkdown(tituloLinha)) {
        fechar();
        titulo = tituloLinha;
      } else {
        buffer.add(linha);
      }
    }
    fechar();

    if (secoes.isEmpty) {
      secoes.add(
        _ExplanationSectionData(
          titulo: '🧠 Resolução Comentada',
          corpo: texto.trim(),
        ),
      );
    }
    return secoes;
  }

  bool _ehTituloSemMarkdown(String linha) {
    const titulos = [
      'Tema da Questão',
      'Resolução Comentada',
      'Alternativa Correta',
      'Alternativas Incorretas',
      'Pegadinha da Banca',
      'Alerta de Desatualização Legislativa',
    ];
    final normalizada = linha
        .replaceFirst(RegExp(r'^[^\p{L}\p{N}]+', unicode: true), '')
        .trim();
    return titulos.any(
      (titulo) => normalizada == titulo || normalizada.startsWith('$titulo:'),
    );
  }
}

class _RichBody extends StatelessWidget {
  const _RichBody({
    required this.colors,
    required this.responsive,
    required this.texto,
    this.italico = false,
  });

  final _QuestoesColors colors;
  final Responsive responsive;
  final String texto;
  final bool italico;

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      fontSize: responsive.sp(11.5),
      height: 1.5,
      color: colors.secondary,
      fontStyle: italico ? FontStyle.italic : null,
    );
    final widgets = <Widget>[];

    for (final trecho in LatexText.dividirBlocosCodigo(texto)) {
      if (trecho.codigo) {
        if (trecho.texto.trim().isEmpty) continue;
        widgets.add(CodeBlockView(trecho.texto, style: estilo));
        continue;
      }
      if (trecho.citacao) {
        if (trecho.texto.trim().isEmpty) continue;
        widgets.add(BlockquoteView(trecho.texto, style: estilo));
        continue;
      }

      final linhas = LatexText.dividirLinhas(trecho.texto)
          .map((linha) => linha.trim())
          .where((linha) => linha.isNotEmpty);
      for (final linha in linhas) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(bottom: responsive.sp(4)),
            child: _linha(linha, estilo),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }

  Widget _linha(String linha, TextStyle estilo) {
    // Só trata como marcador quando o símbolo vem seguido de espaço: linhas
    // iniciadas por `**negrito**` são texto normal, não listas.
    if (linha.startsWith('•') ||
        linha.startsWith('- ') ||
        linha.startsWith('* ')) {
      final conteudo = linha.replaceFirst(RegExp(r'^[•\-*]\s*'), '');
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: responsive.sp(1)),
            child: Text(
              '•',
              style: estilo.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.primary,
              ),
            ),
          ),
          SizedBox(width: responsive.sp(6)),
          Expanded(
            child: _InlineMarkup(texto: conteudo, estilo: estilo),
          ),
        ],
      );
    }

    return _InlineMarkup(texto: linha, estilo: estilo);
  }
}

class _InlineMarkup extends StatelessWidget {
  const _InlineMarkup({required this.texto, required this.estilo});

  final String texto;
  final TextStyle estilo;

  @override
  Widget build(BuildContext context) => LatexText(texto, style: estilo);
}

// ---------------------------------------------------------------------------
// Estados auxiliares
// ---------------------------------------------------------------------------

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.colors, required this.responsive});

  final _QuestoesColors colors;
  final Responsive responsive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: responsive.sp(48)),
      decoration: _cardDecoration(colors),
      child: Column(
        children: [
          CircularProgressIndicator(strokeWidth: 2.5, color: colors.primary),
          SizedBox(height: responsive.sp(12)),
          Text(
            'Carregando questões...',
            style: TextStyle(
              fontSize: responsive.sp(11.5),
              color: colors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.colors,
    required this.responsive,
    required this.erro,
    required this.onTentarNovamente,
  });

  final _QuestoesColors colors;
  final Responsive responsive;
  final Object? erro;
  final VoidCallback onTentarNovamente;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(responsive.sp(20)),
      decoration: _cardDecoration(colors),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: responsive.sp(38),
            color: colors.muted,
          ),
          SizedBox(height: responsive.sp(12)),
          Text(
            'Não foi possível carregar as questões.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: responsive.sp(13),
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
          SizedBox(height: responsive.sp(4)),
          Text(
            _mensagemErro(erro),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: responsive.sp(10.5),
              color: colors.muted,
            ),
          ),
          SizedBox(height: responsive.sp(14)),
          ElevatedButton(
            onPressed: onTentarNovamente,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.responderBg,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.colors,
    required this.responsive,
    required this.onLimpar,
  });

  final _QuestoesColors colors;
  final Responsive responsive;
  final VoidCallback onLimpar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(responsive.sp(24)),
      decoration: _cardDecoration(colors),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: responsive.sp(40),
            color: colors.muted,
          ),
          SizedBox(height: responsive.sp(12)),
          Text(
            'Nenhuma questão encontrada',
            style: TextStyle(
              fontSize: responsive.sp(14),
              fontWeight: FontWeight.w700,
              color: colors.text,
            ),
          ),
          SizedBox(height: responsive.sp(4)),
          Text(
            'Ajuste os filtros ou limpe a seleção para ver todas as questões '
            'disponíveis no banco.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: responsive.sp(11.5),
              height: 1.4,
              color: colors.secondary,
            ),
          ),
          SizedBox(height: responsive.sp(14)),
          OutlinedButton(
            onPressed: onLimpar,
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.primary,
              side: BorderSide(color: colors.primaryBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Limpar filtros'),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.colors, required this.responsive});

  final _QuestoesColors colors;
  final Responsive responsive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: responsive.sp(4),
        bottom: responsive.sp(16),
      ),
      child: Text.rich(
        TextSpan(
          style: TextStyle(fontSize: responsive.sp(10.5), color: colors.muted),
          children: [
            TextSpan(
              text: 'Gabaritei Questões',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colors.secondary,
              ),
            ),
            const TextSpan(text: ' © 2026. Software livre.'),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Comentários
// ---------------------------------------------------------------------------

class _CommentsSheet extends ConsumerStatefulWidget {
  const _CommentsSheet({
    required this.idQuestao,
    required this.comentarioProfessor,
  });

  final int idQuestao;
  final String? comentarioProfessor;

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _controller = TextEditingController();
  late Future<ComentariosPagina> _futuro;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _futuro = _carregar();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<ComentariosPagina> _carregar() {
    return ref
        .read(questionRepositoryProvider)
        .comentarios(idQuestao: widget.idQuestao);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _QuestoesColors.of(isDark);
    final responsive = Responsive.of(context);
    final altura = MediaQuery.sizeOf(context).height * 0.78;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: altura,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                responsive.sp(16),
                responsive.sp(14),
                responsive.sp(8),
                responsive.sp(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: responsive.sp(18),
                    color: colors.primary,
                  ),
                  SizedBox(width: responsive.sp(8)),
                  Expanded(
                    child: Text(
                      'Comentários',
                      style: TextStyle(
                        fontSize: responsive.sp(14),
                        fontWeight: FontWeight.w700,
                        color: colors.text,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Fechar',
                    icon: Icon(Icons.close_rounded, size: responsive.sp(20)),
                    color: colors.secondary,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.borderSoft),
            Expanded(
              child: FutureBuilder<ComentariosPagina>(
                future: _futuro,
                builder: (context, snapshot) {
                  final comentarios =
                      snapshot.data?.comentarios ?? const <ComentarioPublico>[];
                  final comentarioProfessor = _comentarioUtil(
                    widget.comentarioProfessor,
                  );
                  return ListView(
                    key: const Key('comentarios-lista'),
                    padding: EdgeInsets.symmetric(
                      horizontal: responsive.sp(16),
                      vertical: responsive.sp(12),
                    ),
                    children: [
                      Text(
                        'Discussão da Comunidade',
                        key: const Key('comentarios-discussao-titulo'),
                        style: TextStyle(
                          color: colors.secondary,
                          fontSize: responsive.sp(9.5),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.35,
                        ),
                      ),
                      SizedBox(height: responsive.sp(10)),
                      if (comentarioProfessor != null) ...[
                        _ProfessorCommentTile(
                          colors: colors,
                          responsive: responsive,
                          comentario: comentarioProfessor,
                        ),
                        if (comentarios.isNotEmpty)
                          Divider(
                            height: responsive.sp(22),
                            color: colors.borderSoft,
                          ),
                      ],
                      if (snapshot.connectionState == ConnectionState.waiting)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: responsive.sp(30),
                          ),
                          child: Column(
                            children: [
                              CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: colors.primary,
                              ),
                              SizedBox(height: responsive.sp(9)),
                              Text(
                                'Carregando comentários da comunidade...',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colors.muted,
                                  fontSize: responsive.sp(10),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (snapshot.hasError)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: responsive.sp(22),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.cloud_off_rounded,
                                size: responsive.sp(32),
                                color: colors.muted,
                              ),
                              SizedBox(height: responsive.sp(9)),
                              Text(
                                _mensagemErro(snapshot.error),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: responsive.sp(11),
                                  color: colors.secondary,
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    setState(() => _futuro = _carregar()),
                                child: const Text('Tentar novamente'),
                              ),
                            ],
                          ),
                        )
                      else if (comentarios.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: responsive.sp(22),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.forum_outlined,
                                size: responsive.sp(34),
                                color: colors.muted,
                              ),
                              SizedBox(height: responsive.sp(9)),
                              Text(
                                comentarioProfessor == null
                                    ? 'Nenhum comentário ainda.'
                                    : 'Nenhum comentário da comunidade ainda.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: responsive.sp(11.5),
                                  fontWeight: FontWeight.w600,
                                  color: colors.text,
                                ),
                              ),
                              SizedBox(height: responsive.sp(4)),
                              Text(
                                'Seja o primeiro a compartilhar seu raciocínio.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: responsive.sp(10.5),
                                  color: colors.muted,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        for (
                          var index = 0;
                          index < comentarios.length;
                          index++
                        ) ...[
                          _CommentTile(
                            key: ValueKey(
                              'comentario-comunidade-${comentarios[index].id}',
                            ),
                            colors: colors,
                            responsive: responsive,
                            comentario: comentarios[index],
                          ),
                          if (index < comentarios.length - 1)
                            Divider(
                              height: responsive.sp(20),
                              color: colors.borderSoft,
                            ),
                        ],
                    ],
                  );
                },
              ),
            ),
            Divider(height: 1, color: colors.borderSoft),
            Padding(
              padding: EdgeInsets.fromLTRB(
                responsive.sp(12),
                responsive.sp(8),
                responsive.sp(8),
                responsive.sp(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(
                        fontSize: responsive.sp(12),
                        color: colors.text,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Escreva um comentário...',
                        isDense: true,
                        filled: true,
                        fillColor: colors.inputBg,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: responsive.sp(12),
                          vertical: responsive.sp(10),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: colors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: colors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: colors.primary),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: responsive.sp(6)),
                  IconButton(
                    onPressed: _enviando ? null : _enviar,
                    tooltip: 'Enviar comentário',
                    icon: _enviando
                        ? SizedBox(
                            width: responsive.sp(18),
                            height: responsive.sp(18),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.primary,
                            ),
                          )
                        : Icon(Icons.send_rounded, size: responsive.sp(20)),
                    color: colors.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enviar() async {
    final texto = _controller.text.trim();
    if (texto.isEmpty || _enviando) return;

    final perfil = await ref.read(perfilAtualProvider.future);
    if (!mounted) return;
    if (perfil == null) {
      _mensagem('Sessão expirada. Entre novamente.');
      return;
    }

    setState(() => _enviando = true);
    try {
      await ref
          .read(questionRepositoryProvider)
          .salvarComentario(
            idUsuario: perfil.id,
            idQuestao: widget.idQuestao,
            texto: texto,
          );
      if (!mounted) return;
      _controller.clear();
      FocusScope.of(context).unfocus();
      setState(() => _futuro = _carregar());
    } catch (error) {
      if (!mounted) return;
      _mensagem(_mensagemErro(error));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _mensagem(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }
}

class _ProfessorCommentTile extends StatelessWidget {
  const _ProfessorCommentTile({
    required this.colors,
    required this.responsive,
    required this.comentario,
  });

  final _QuestoesColors colors;
  final Responsive responsive;
  final String comentario;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Comentário do professor, fixado no topo',
    child: Container(
      key: const Key('comentario-professor-fixado'),
      width: double.infinity,
      padding: EdgeInsets.all(responsive.sp(13)),
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: BorderRadius.circular(responsive.sp(12)),
        border: Border.all(color: colors.primaryBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.school_rounded,
                size: responsive.sp(15),
                color: colors.primary,
              ),
              SizedBox(width: responsive.sp(6)),
              Expanded(
                child: Text(
                  'Comentário do Professor',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: responsive.sp(10.5),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(width: responsive.sp(6)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.sp(7),
                  vertical: responsive.sp(3),
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.push_pin_rounded,
                      size: responsive.sp(9),
                      color: colors.primary,
                    ),
                    SizedBox(width: responsive.sp(3)),
                    Text(
                      'FIXADO',
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: responsive.sp(7.5),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.sp(8)),
          _RichBody(
            colors: colors,
            responsive: responsive,
            texto: _comentarioProfessorParaLinhas(comentario),
            italico: true,
          ),
        ],
      ),
    ),
  );
}

String _comentarioProfessorParaLinhas(String comentario) =>
    LatexText.limparHtml(comentario);

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    super.key,
    required this.colors,
    required this.responsive,
    required this.comentario,
  });

  final _QuestoesColors colors;
  final Responsive responsive;
  final ComentarioPublico comentario;

  @override
  Widget build(BuildContext context) {
    final inicial = comentario.nomeUsuario.trim().isEmpty
        ? '?'
        : comentario.nomeUsuario.trim().characters.first.toUpperCase();
    final data = comentario.criadoEm;
    final formatada = data == null
        ? null
        : DateFormat('dd/MM/yyyy • HH:mm').format(data.toLocal());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: responsive.sp(15),
          backgroundColor: colors.primarySoft,
          child: Text(
            inicial,
            style: TextStyle(
              fontSize: responsive.sp(11),
              fontWeight: FontWeight.w700,
              color: colors.primary,
            ),
          ),
        ),
        SizedBox(width: responsive.sp(10)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      comentario.nomeUsuario,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: responsive.sp(11.5),
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                  ),
                  if (formatada != null)
                    Text(
                      formatada,
                      style: TextStyle(
                        fontSize: responsive.sp(9),
                        color: colors.muted,
                      ),
                    ),
                ],
              ),
              SizedBox(height: responsive.sp(3)),
              Text(
                comentario.texto,
                style: TextStyle(
                  fontSize: responsive.sp(11.5),
                  height: 1.45,
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
// Utilidades de texto
// ---------------------------------------------------------------------------

String? _comentarioUtil(String? texto) {
  final limpo = texto?.trim();
  if (limpo == null || limpo.isEmpty || limpo == 'Sem comentário disponível.') {
    return null;
  }
  return limpo;
}

String _mensagemErro(Object? erro) {
  if (erro is AppException) return erro.message;
  if (erro is StateError) {
    return 'Sua sessão não está disponível. Entre novamente.';
  }
  return 'Não foi possível concluir a operação. Tente novamente.';
}

String _htmlParaTexto(String html) => LatexText.limparHtml(html);
