import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/providers.dart';
import '../../core/ui/responsive.dart';
import '../../models/simulado.dart';
import '../../models/taxonomy.dart';
import '../../repositories/taxonomy_repository.dart';
import 'simulados_ui.dart';

/// Bottom sheet responsivo com todos os filtros do gerador desktop.
class SimuladoGeneratorSheet extends ConsumerStatefulWidget {
  const SimuladoGeneratorSheet({super.key, required this.colors});

  final SimuladosColors colors;

  @override
  ConsumerState<SimuladoGeneratorSheet> createState() =>
      _SimuladoGeneratorSheetState();
}

class _SimuladoGeneratorSheetState
    extends ConsumerState<SimuladoGeneratorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _idBancas = <int>{};
  final _idOrgaos = <int>{};
  final _idCargos = <int>{};
  final _anos = <int>{};
  final _tiposQuestao = <String>{};
  final List<_CotaDraft> _cotas = [_CotaDraft()];
  int? _idNivel;
  var _privado = false;
  var _gerando = false;

  @override
  void dispose() {
    _tituloController.dispose();
    for (final cota in _cotas) {
      cota.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final colors = widget.colors;
    final catalogo = ref.watch(taxonomyCatalogProvider);
    final altura = MediaQuery.sizeOf(context).height;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: altura * 0.92,
        child: Column(
          children: [
            _CabecalhoGerador(
              colors: colors,
              onFechar: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: catalogo.when(
                loading: () => Center(
                  child: CircularProgressIndicator(color: colors.accent),
                ),
                error: (error, _) => _ErroCatalogo(
                  colors: colors,
                  mensagem: _mensagemErro(error),
                  onTentar: () => ref.invalidate(taxonomyCatalogProvider),
                ),
                data: (dados) => Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    key: const Key('simulado-generator-scroll'),
                    padding: EdgeInsets.fromLTRB(
                      responsive.sp(16),
                      responsive.sp(14),
                      responsive.sp(16),
                      responsive.sp(20),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: responsive.dashboardMaxWidth,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _tituloField(colors),
                            SizedBox(height: responsive.sp(12)),
                            _identidadeFields(colors, responsive, dados),
                            SizedBox(height: responsive.sp(16)),
                            _SecaoGerador(
                              colors: colors,
                              title: 'Filtros de Questões (Opcional)',
                              icon: Icons.filter_alt_outlined,
                              subtitle: _textoFiltrosSelecionados(),
                              child: _filtrosGlobais(colors, responsive, dados),
                            ),
                            SizedBox(height: responsive.sp(15)),
                            _SecaoGerador(
                              colors: colors,
                              title: 'Composição da Prova',
                              icon: Icons.layers_outlined,
                              subtitle:
                                  '${_cotas.length} ${_cotas.length == 1 ? 'disciplina' : 'disciplinas'}',
                              child: _composicao(colors, responsive, dados),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _RodapeGerador(
              colors: colors,
              enviando: _gerando,
              onCancelar: () => Navigator.of(context).pop(),
              onGerar: catalogo.hasValue ? _gerar : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tituloField(SimuladosColors colors) {
    return TextFormField(
      key: const Key('simulado-titulo'),
      controller: _tituloController,
      textCapitalization: TextCapitalization.sentences,
      maxLength: 120,
      decoration: InputDecoration(
        labelText: 'Título do Simulado *',
        hintText: 'Ex.: Simulado PC-SP Final',
        filled: true,
        fillColor: colors.cardSoft,
        counterStyle: TextStyle(color: colors.muted),
      ),
      validator: (value) => (value?.trim().isNotEmpty ?? false)
          ? null
          : 'Informe o título do simulado.',
    );
  }

  Widget _identidadeFields(
    SimuladosColors colors,
    Responsive responsive,
    TaxonomyCatalog catalogo,
  ) {
    final niveis = catalogo.niveis;
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = constraints.maxWidth >= 560;
        final privacidade = DropdownButtonFormField<bool>(
          key: const Key('simulado-privacidade'),
          initialValue: _privado,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Visibilidade *'),
          items: const [
            DropdownMenuItem(
              value: false,
              child: Text(
                'Público (com ranking)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: true,
              child: Text(
                'Privado (só para mim)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          onChanged: (value) => setState(() => _privado = value ?? false),
        );
        final escolaridade = DropdownButtonFormField<int?>(
          key: const Key('simulado-escolaridade'),
          initialValue: _idNivel,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Escolaridade da prova'),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('Qualquer nível'),
            ),
            for (final nivel in niveis)
              DropdownMenuItem<int?>(
                value: nivel.id,
                child: Text(nivel.nome, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) => setState(() => _idNivel = value),
        );
        if (!sideBySide) {
          return Column(
            children: [
              privacidade,
              SizedBox(height: responsive.sp(10)),
              escolaridade,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: privacidade),
            SizedBox(width: responsive.sp(10)),
            Expanded(child: escolaridade),
          ],
        );
      },
    );
  }

  Widget _filtrosGlobais(
    SimuladosColors colors,
    Responsive responsive,
    TaxonomyCatalog catalogo,
  ) {
    final anos = TaxonomyRepository.anosDisponiveis;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FiltroExpansivel(
          key: const Key('simulado-filtro-bancas'),
          colors: colors,
          icon: Icons.account_balance_outlined,
          title: 'Banca',
          selectedCount: _idBancas.length,
          child: Column(
            children: [
              for (final banca in catalogo.bancas)
                _CheckLinha(
                  key: Key('simulado-banca-${banca.id}'),
                  colors: colors,
                  label: banca.nome,
                  selected: _idBancas.contains(banca.id),
                  onChanged: (selected) =>
                      _toggle(_idBancas, banca.id, selected),
                ),
            ],
          ),
        ),
        _FiltroExpansivel(
          key: const Key('simulado-filtro-orgaos'),
          colors: colors,
          icon: Icons.business_outlined,
          title: 'Órgão / Cargo',
          selectedCount: _idOrgaos.length + _idCargos.length,
          child: _orgaosECargos(colors, catalogo.orgaos),
        ),
        _FiltroExpansivel(
          key: const Key('simulado-filtro-anos'),
          colors: colors,
          icon: Icons.calendar_month_outlined,
          title: 'Ano',
          selectedCount: _anos.length,
          child: Wrap(
            spacing: responsive.sp(6),
            runSpacing: responsive.sp(4),
            children: [
              for (final ano in anos)
                FilterChip(
                  key: Key('simulado-ano-$ano'),
                  label: Text('$ano'),
                  selected: _anos.contains(ano),
                  onSelected: (selected) => _toggle(_anos, ano, selected),
                  selectedColor: colors.accentSoft,
                  checkmarkColor: colors.accent,
                  labelStyle: TextStyle(
                    color: _anos.contains(ano)
                        ? colors.accent
                        : colors.secondary,
                    fontSize: responsive.sp(10),
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(color: colors.border),
                ),
            ],
          ),
        ),
        _FiltroExpansivel(
          key: const Key('simulado-filtro-tipos'),
          colors: colors,
          icon: Icons.checklist_rounded,
          title: 'Tipo de questão',
          selectedCount: _tiposQuestao.length,
          child: Column(
            children: [
              _CheckLinha(
                key: const Key('simulado-tipo-multipla'),
                colors: colors,
                label: 'Múltipla Escolha',
                selected: _tiposQuestao.contains('multipla_escolha'),
                onChanged: (value) =>
                    _toggle(_tiposQuestao, 'multipla_escolha', value),
              ),
              _CheckLinha(
                key: const Key('simulado-tipo-certo-errado'),
                colors: colors,
                label: 'Certo / Errado',
                selected: _tiposQuestao.contains('certo_errado'),
                onChanged: (value) =>
                    _toggle(_tiposQuestao, 'certo_errado', value),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _orgaosECargos(SimuladosColors colors, List<Orgao> orgaos) {
    if (orgaos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Nenhum órgão disponível.',
          style: TextStyle(color: colors.secondary),
        ),
      );
    }
    return Column(
      children: [
        for (final orgao in orgaos)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CheckLinha(
                key: Key('simulado-orgao-${orgao.id}'),
                colors: colors,
                label: orgao.nome,
                selected: _idOrgaos.contains(orgao.id),
                bold: true,
                onChanged: (selected) {
                  setState(() {
                    _toggle(_idOrgaos, orgao.id, selected);
                    for (final cargo in orgao.cargos) {
                      _toggle(_idCargos, cargo.id, selected);
                    }
                  });
                },
              ),
              if (orgao.cargos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 22),
                  child: Column(
                    children: [
                      for (final cargo in orgao.cargos)
                        _CheckLinha(
                          key: Key('simulado-cargo-${cargo.id}'),
                          colors: colors,
                          label: cargo.nome,
                          selected: _idCargos.contains(cargo.id),
                          onChanged: (selected) => setState(
                            () => _toggle(_idCargos, cargo.id, selected),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _composicao(
    SimuladosColors colors,
    Responsive responsive,
    TaxonomyCatalog catalogo,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _cotas.length; i++) ...[
          _CotaCard(
            key: ValueKey('simulado-cota-$i-${_cotas[i].idMateria ?? 'geral'}'),
            colors: colors,
            responsive: responsive,
            catalogo: catalogo,
            cota: _cotas[i],
            numero: i + 1,
            podeRemover: _cotas.length > 1,
            onChanged: () => setState(() {}),
            onRemover: () => _removerCota(i),
          ),
          if (i < _cotas.length - 1) SizedBox(height: responsive.sp(9)),
        ],
        SizedBox(height: responsive.sp(8)),
        OutlinedButton.icon(
          key: const Key('simulado-adicionar-disciplina'),
          onPressed: _adicionarCota,
          icon: const Icon(Icons.add_circle_outline_rounded),
          label: const Text('Adicionar disciplina ao simulado'),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.accent,
            side: BorderSide(color: colors.accent.withValues(alpha: 0.45)),
            backgroundColor: colors.accentSoft.withValues(alpha: 0.45),
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(responsive.sp(12)),
            ),
            textStyle: TextStyle(
              fontSize: responsive.sp(10.5),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  String _textoFiltrosSelecionados() {
    final contagem =
        _idBancas.length +
        _idOrgaos.length +
        _idCargos.length +
        _anos.length +
        _tiposQuestao.length +
        (_idNivel == null ? 0 : 1);
    if (contagem == 0) return 'Sem filtros aplicados';
    return '$contagem ${contagem == 1 ? 'filtro aplicado' : 'filtros aplicados'}';
  }

  void _toggle<T>(Set<T> valores, T valor, bool selecionado) {
    if (selecionado) {
      valores.add(valor);
    } else {
      valores.remove(valor);
    }
  }

  void _adicionarCota() {
    if (_cotas.length >= 20) {
      showSimuladosMessage(context, 'Você pode adicionar até 20 disciplinas.');
      return;
    }
    setState(() => _cotas.add(_CotaDraft()));
  }

  void _removerCota(int index) {
    if (_cotas.length <= 1) return;
    final removida = _cotas.removeAt(index);
    removida.dispose();
    setState(() {});
  }

  Future<void> _gerar() async {
    if (_gerando || _formKey.currentState?.validate() != true) return;
    final cotas = <CotaSimulado>[];
    for (final draft in _cotas) {
      final quantidade = int.tryParse(draft.quantidade.text.trim()) ?? 0;
      if (quantidade > 0) {
        cotas.add(
          CotaSimulado(
            idMateria: draft.idMateria,
            idsTopicos: draft.idsTopicos.toList(growable: false),
            quantidade: quantidade,
          ),
        );
      }
    }
    if (cotas.isEmpty) {
      showSimuladosMessage(
        context,
        'Adicione ao menos uma quantidade de questões.',
      );
      return;
    }

    setState(() => _gerando = true);
    try {
      final perfil = await ref.read(perfilAtualProvider.future);
      if (perfil == null) throw StateError('Sessão indisponível.');
      final criado = await ref
          .read(simuladoRepositoryProvider)
          .gerar(
            idUsuario: perfil.id,
            titulo: _tituloController.text.trim(),
            cotas: cotas,
            filtros: FiltrosSimulado(
              idNivel: _idNivel,
              idsBancas: _idBancas.toList(growable: false),
              idsOrgaos: _idOrgaos.toList(growable: false),
              idsCargos: _idCargos.toList(growable: false),
              anos: _anos.toList(growable: false)
                ..sort((a, b) => b.compareTo(a)),
              tiposQuestao: _tiposQuestao.toList(growable: false),
            ),
            ehPrivado: _privado,
          );
      if (!mounted) return;
      Navigator.of(context).pop(criado);
    } catch (error) {
      if (!mounted) return;
      setState(() => _gerando = false);
      showSimuladosMessage(context, simuladosErrorMessage(error));
    }
  }

  String _mensagemErro(Object? error) {
    if (error is AppException) return error.message;
    return 'Não foi possível carregar os filtros. Tente novamente.';
  }
}

class _CotaDraft {
  _CotaDraft();

  int? idMateria;
  final idsTopicos = <int>{};
  final quantidade = TextEditingController(text: '5');
  bool topicosAbertos = false;

  void dispose() => quantidade.dispose();
}

class _CabecalhoGerador extends StatelessWidget {
  const _CabecalhoGerador({required this.colors, required this.onFechar});

  final SimuladosColors colors;
  final VoidCallback onFechar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 10, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors.isDark
              ? const [Color(0xFF4338CA), Color(0xFF5B21B6)]
              : const [Color(0xFF2563EB), Color(0xFF1E40AF)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Colors.white),
          const SizedBox(width: 9),
          const Expanded(
            child: Text(
              'Gerador de Simulado',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            key: const Key('simulado-gerador-fechar'),
            onPressed: onFechar,
            tooltip: 'Fechar',
            style: IconButton.styleFrom(
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _SecaoGerador extends StatelessWidget {
  const _SecaoGerador({
    required this.colors,
    required this.title,
    required this.icon,
    required this.subtitle,
    required this.child,
  });

  final SimuladosColors colors;
  final String title;
  final IconData icon;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return SimuladoPanel(
      colors: colors,
      radius: responsive.sp(14),
      padding: EdgeInsets.all(responsive.sp(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: colors.accent, size: responsive.sp(16)),
              SizedBox(width: responsive.sp(7)),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: responsive.sp(11),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.25,
                  ),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: colors.secondary,
                  fontSize: responsive.sp(9),
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.sp(9)),
          Divider(height: 1, color: colors.border),
          SizedBox(height: responsive.sp(7)),
          child,
        ],
      ),
    );
  }
}

class _ErroCatalogo extends StatelessWidget {
  const _ErroCatalogo({
    required this.colors,
    required this.mensagem,
    required this.onTentar,
  });

  final SimuladosColors colors;
  final String mensagem;
  final VoidCallback onTentar;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return Center(
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
                size: responsive.sp(34),
              ),
              SizedBox(height: responsive.sp(10)),
              Text(
                'Não foi possível carregar os filtros',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.text,
                  fontSize: responsive.sp(14),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: responsive.sp(7)),
              Text(
                mensagem,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.secondary,
                  fontSize: responsive.sp(10.5),
                  height: 1.45,
                ),
              ),
              SizedBox(height: responsive.sp(14)),
              OutlinedButton.icon(
                key: const Key('simulado-catalogo-tentar-novamente'),
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
        ),
      ),
    );
  }
}

class _FiltroExpansivel extends StatelessWidget {
  const _FiltroExpansivel({
    Key? key,
    required this.colors,
    required this.icon,
    required this.title,
    required this.selectedCount,
    required this.child,
  }) : _tileKey = key;

  final Key? _tileKey;
  final SimuladosColors colors;
  final IconData icon;
  final String title;
  final int selectedCount;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return Material(
      color: colors.card,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: _tileKey,
          tilePadding: EdgeInsets.symmetric(horizontal: responsive.sp(7)),
          childrenPadding: EdgeInsets.fromLTRB(
            responsive.sp(8),
            0,
            responsive.sp(8),
            responsive.sp(8),
          ),
          leading: Icon(icon, color: colors.secondary, size: responsive.sp(17)),
          title: Text(
            title,
            style: TextStyle(
              color: colors.secondary,
              fontSize: responsive.sp(10.5),
              fontWeight: FontWeight.w700,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selectedCount > 0)
                Container(
                  margin: EdgeInsets.only(right: responsive.sp(5)),
                  padding: EdgeInsets.symmetric(
                    horizontal: responsive.sp(7),
                    vertical: responsive.sp(3),
                  ),
                  decoration: BoxDecoration(
                    color: colors.accentSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$selectedCount',
                    style: TextStyle(
                      color: colors.accent,
                      fontSize: responsive.sp(9),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Icon(Icons.expand_more_rounded, color: colors.muted),
            ],
          ),
          children: [child],
        ),
      ),
    );
  }
}

class _CheckLinha extends StatelessWidget {
  const _CheckLinha({
    super.key,
    required this.colors,
    required this.label,
    required this.selected,
    required this.onChanged,
    this.bold = false,
  });

  final SimuladosColors colors;
  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return Material(
      color: Colors.transparent,
      child: CheckboxListTile(
        value: selected,
        onChanged: (value) => onChanged(value ?? false),
        dense: true,
        visualDensity: VisualDensity.compact,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        activeColor: colors.accent,
        title: Text(
          label,
          style: TextStyle(
            color: colors.secondary,
            fontSize: responsive.sp(10),
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _CotaCard extends StatelessWidget {
  const _CotaCard({
    super.key,
    required this.colors,
    required this.responsive,
    required this.catalogo,
    required this.cota,
    required this.numero,
    required this.podeRemover,
    required this.onChanged,
    required this.onRemover,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final TaxonomyCatalog catalogo;
  final _CotaDraft cota;
  final int numero;
  final bool podeRemover;
  final VoidCallback onChanged;
  final VoidCallback onRemover;

  @override
  Widget build(BuildContext context) {
    final materias = catalogo.materiasOrdenadas;
    final topicos = cota.idMateria == null
        ? const <Topico>[]
        : catalogo.topicosDaMateria(cota.idMateria!);
    final selectedTopics = cota.idsTopicos.intersection(
      topicos.map((topico) => topico.id).toSet(),
    );
    final todosSelecionados =
        topicos.isNotEmpty && selectedTopics.length == topicos.length;

    return Container(
      key: Key('simulado-cota-$numero'),
      padding: EdgeInsets.all(responsive.sp(10)),
      decoration: BoxDecoration(
        color: colors.cardSoft,
        borderRadius: BorderRadius.circular(responsive.sp(12)),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Disciplina $numero',
                  style: TextStyle(
                    color: colors.text,
                    fontSize: responsive.sp(10.5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (podeRemover)
                IconButton(
                  key: Key('simulado-cota-remover-$numero'),
                  onPressed: onRemover,
                  tooltip: 'Remover disciplina',
                  style: IconButton.styleFrom(
                    foregroundColor: colors.danger,
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          DropdownButtonFormField<int?>(
            key: Key('simulado-cota-materia-$numero'),
            initialValue: cota.idMateria,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Disciplina'),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Qualquer matéria (Geral)'),
              ),
              for (final materia in materias)
                DropdownMenuItem<int?>(
                  value: materia.id,
                  child: Text(materia.nome, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) {
              cota.idMateria = value;
              cota.idsTopicos.clear();
              cota.topicosAbertos = false;
              onChanged();
            },
          ),
          SizedBox(height: responsive.sp(9)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: Key('simulado-cota-topicos-$numero'),
                  onPressed: topicos.isEmpty
                      ? null
                      : () {
                          cota.topicosAbertos = !cota.topicosAbertos;
                          onChanged();
                        },
                  icon: Icon(
                    Icons.account_tree_outlined,
                    size: responsive.sp(15),
                  ),
                  label: Text(
                    cota.idMateria == null
                        ? 'Todos os assuntos'
                        : selectedTopics.isEmpty
                        ? 'Todos os assuntos'
                        : '${selectedTopics.length} assunto(s)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.secondary,
                    side: BorderSide(color: colors.border),
                    minimumSize: const Size(48, 48),
                  ),
                ),
              ),
              SizedBox(width: responsive.sp(9)),
              SizedBox(
                width: responsive.sp(96),
                child: TextFormField(
                  key: Key('simulado-cota-quantidade-$numero'),
                  controller: cota.quantidade,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 3,
                  decoration: const InputDecoration(
                    labelText: 'Qtd.',
                    counterText: '',
                  ),
                  validator: (value) {
                    final quantidade = int.tryParse(value?.trim() ?? '');
                    if (quantidade == null ||
                        quantidade < 1 ||
                        quantidade > 500) {
                      return '1–500';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          if (cota.topicosAbertos && topicos.isNotEmpty) ...[
            SizedBox(height: responsive.sp(8)),
            Container(
              constraints: BoxConstraints(maxHeight: responsive.sp(230)),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(responsive.sp(10)),
                border: Border.all(color: colors.border),
              ),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.symmetric(vertical: responsive.sp(4)),
                children: [
                  _CheckLinha(
                    key: Key('simulado-topico-todos-$numero'),
                    colors: colors,
                    label: 'Marcar todo o edital',
                    selected: todosSelecionados,
                    bold: true,
                    onChanged: (selected) {
                      cota.idsTopicos
                        ..clear()
                        ..addAll(
                          selected
                              ? topicos.map((item) => item.id)
                              : const <int>[],
                        );
                      onChanged();
                    },
                  ),
                  for (final topico in topicos)
                    _CheckLinha(
                      key: Key('simulado-topico-$numero-${topico.id}'),
                      colors: colors,
                      label: topico.nome,
                      selected: cota.idsTopicos.contains(topico.id),
                      onChanged: (selected) {
                        if (selected) {
                          cota.idsTopicos.add(topico.id);
                        } else {
                          cota.idsTopicos.remove(topico.id);
                        }
                        onChanged();
                      },
                    ),
                ],
              ),
            ),
          ] else if (cota.idMateria != null && topicos.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: responsive.sp(7)),
              child: Text(
                'Nenhum assunto específico cadastrado para esta matéria.',
                style: TextStyle(
                  color: colors.muted,
                  fontSize: responsive.sp(9.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RodapeGerador extends StatelessWidget {
  const _RodapeGerador({
    required this.colors,
    required this.enviando,
    required this.onCancelar,
    required this.onGerar,
  });

  final SimuladosColors colors;
  final bool enviando;
  final VoidCallback onCancelar;
  final VoidCallback? onGerar;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        responsive.sp(14),
        responsive.sp(9),
        responsive.sp(14),
        responsive.sp(10),
      ),
      decoration: BoxDecoration(
        color: colors.cardSoft,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          TextButton(
            key: const Key('simulado-gerador-cancelar'),
            onPressed: enviando ? null : onCancelar,
            style: TextButton.styleFrom(
              foregroundColor: colors.secondary,
              minimumSize: const Size(80, 48),
            ),
            child: const Text('Cancelar'),
          ),
          SizedBox(width: responsive.sp(8)),
          Expanded(
            child: FilledButton.icon(
              key: const Key('simulado-generator-submit'),
              onPressed: enviando ? null : onGerar,
              icon: enviando
                  ? SizedBox(
                      width: responsive.sp(16),
                      height: responsive.sp(16),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(Icons.bolt_rounded, size: responsive.sp(16)),
              label: Text(enviando ? 'Gerando...' : 'Gerar Prova Agora'),
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(responsive.sp(11)),
                ),
                textStyle: TextStyle(
                  fontSize: responsive.sp(10.5),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
