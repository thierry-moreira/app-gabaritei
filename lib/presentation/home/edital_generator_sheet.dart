import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/ui/responsive.dart';
import '../../models/edital.dart';
import '../../models/taxonomy.dart';
import 'edital_ui.dart';
import 'simulados_ui.dart';

/// Configurador mobile do ciclo adaptativo do edital.
class EditalGeneratorSheet extends ConsumerStatefulWidget {
  const EditalGeneratorSheet({super.key, required this.colors});

  final SimuladosColors colors;

  @override
  ConsumerState<EditalGeneratorSheet> createState() =>
      _EditalGeneratorSheetState();
}

class _EditalGeneratorSheetState extends ConsumerState<EditalGeneratorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final List<_MateriaDraft> _materias = [_MateriaDraft()];
  var _criando = false;

  @override
  void dispose() {
    _tituloController.dispose();
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
            _CabecalhoCriacao(
              colors: colors,
              onFechar: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: catalogo.when(
                loading: () => Center(
                  child: CircularProgressIndicator(color: colors.accent),
                ),
                error: (error, _) => EditalErrorState(
                  colors: colors,
                  title: 'Não foi possível carregar as matérias',
                  message: editalErrorMessage(error),
                  onRetry: () => ref.invalidate(taxonomyCatalogProvider),
                ),
                data: (dados) => Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    key: const Key('edital-generator-scroll'),
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
                            TextFormField(
                              key: const Key('edital-titulo'),
                              controller: _tituloController,
                              maxLength: 120,
                              textCapitalization: TextCapitalization.sentences,
                              style: TextStyle(color: colors.text),
                              decoration: InputDecoration(
                                labelText: 'Nome do edital / concurso *',
                                hintText: 'Ex.: Polícia Federal — Agente 2026',
                                filled: true,
                                fillColor: colors.cardSoft,
                                counterStyle: TextStyle(color: colors.muted),
                                prefixIcon: Icon(
                                  Icons.menu_book_outlined,
                                  color: colors.accent,
                                ),
                              ),
                              validator: (value) =>
                                  value?.trim().isNotEmpty == true
                                  ? null
                                  : 'Informe o nome do edital.',
                            ),
                            SizedBox(height: responsive.sp(14)),
                            _DicaCiclo(colors: colors, responsive: responsive),
                            SizedBox(height: responsive.sp(18)),
                            Row(
                              children: [
                                Icon(
                                  Icons.collections_bookmark_outlined,
                                  color: colors.accent,
                                  size: responsive.sp(18),
                                ),
                                SizedBox(width: responsive.sp(8)),
                                Expanded(
                                  child: Text(
                                    'Matérias e assuntos do edital',
                                    style: TextStyle(
                                      color: colors.text,
                                      fontSize: responsive.sp(12),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${_materias.length}',
                                  style: TextStyle(
                                    color: colors.secondary,
                                    fontSize: responsive.sp(10),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: responsive.sp(10)),
                            for (var i = 0; i < _materias.length; i++) ...[
                              _MateriaEditalCard(
                                key: ValueKey('edital-materia-$i'),
                                colors: colors,
                                responsive: responsive,
                                catalogo: dados,
                                draft: _materias[i],
                                index: i,
                                podeRemover: _materias.length > 1,
                                onChanged: () => setState(() {}),
                                onRemover: () => _removerMateria(i),
                              ),
                              if (i < _materias.length - 1)
                                SizedBox(height: responsive.sp(10)),
                            ],
                            SizedBox(height: responsive.sp(9)),
                            OutlinedButton.icon(
                              key: const Key('edital-adicionar-materia'),
                              onPressed: _adicionarMateria,
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                              ),
                              label: const Text('Adicionar matéria ao ciclo'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colors.accent,
                                side: BorderSide(color: colors.accentBorder),
                                minimumSize: const Size(48, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    responsive.sp(12),
                                  ),
                                ),
                                textStyle: TextStyle(
                                  fontSize: responsive.sp(10.5),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _RodapeCriacao(
              colors: colors,
              criando: _criando,
              onCancelar: () => Navigator.of(context).pop(),
              onCriar: catalogo.hasValue ? _criar : null,
            ),
          ],
        ),
      ),
    );
  }

  void _adicionarMateria() {
    if (_materias.length >= 20) {
      showEditalMessage(context, 'Você pode adicionar até 20 matérias.');
      return;
    }
    setState(() => _materias.add(_MateriaDraft()));
  }

  void _removerMateria(int index) {
    if (_materias.length <= 1) return;
    setState(() => _materias.removeAt(index));
  }

  Future<void> _criar() async {
    if (_criando || _formKey.currentState?.validate() != true) return;
    final materias = [
      for (final materia in _materias)
        if (materia.idMateria != null && materia.idsTopicos.isNotEmpty)
          EditalMateriaSelecionada(
            idMateria: materia.idMateria!,
            idsTopicos: materia.idsTopicos.toList()..sort(),
          ),
    ];
    if (materias.isEmpty) {
      showEditalMessage(context, 'Selecione ao menos um assunto do edital.');
      return;
    }

    setState(() => _criando = true);
    try {
      final perfil = await ref.read(perfilAtualProvider.future);
      if (perfil == null) throw StateError('Sessão indisponível.');
      final criado = await ref
          .read(editalRepositoryProvider)
          .criar(
            idUsuario: perfil.id,
            titulo: _tituloController.text.trim(),
            materias: materias,
          );
      if (!mounted) return;
      Navigator.of(context).pop(criado);
    } catch (error) {
      if (!mounted) return;
      setState(() => _criando = false);
      showEditalMessage(context, editalErrorMessage(error));
    }
  }
}

class _MateriaDraft {
  int? idMateria;
  final Set<int> idsTopicos = {};
  bool assuntosAbertos = false;
}

class _CabecalhoCriacao extends StatelessWidget {
  const _CabecalhoCriacao({required this.colors, required this.onFechar});

  final SimuladosColors colors;
  final VoidCallback onFechar;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 12, 10, 12),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: colors.isDark
            ? const [Color(0xFF4338CA), Color(0xFF5B21B6)]
            : const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
      ),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: Row(
      children: [
        const Icon(Icons.track_changes_rounded, color: Colors.white),
        const SizedBox(width: 9),
        const Expanded(
          child: Text(
            'Configurar Ciclo do Edital',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        IconButton(
          key: const Key('edital-generator-fechar'),
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

class _DicaCiclo extends StatelessWidget {
  const _DicaCiclo({required this.colors, required this.responsive});

  final SimuladosColors colors;
  final Responsive responsive;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('edital-ciclo-adaptativo-dica'),
    padding: EdgeInsets.all(responsive.sp(12)),
    decoration: BoxDecoration(
      color: colors.accentSoft,
      borderRadius: BorderRadius.circular(responsive.sp(12)),
      border: Border.all(color: colors.accentBorder),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.auto_awesome_rounded, color: colors.accent, size: 20),
        SizedBox(width: responsive.sp(9)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ciclo Adaptativo Inteligente',
                style: TextStyle(
                  color: colors.accent,
                  fontSize: responsive.sp(10.5),
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: responsive.sp(4)),
              Text(
                'A ordem e a meta de questões se ajustam ao seu desempenho. Matérias e assuntos mais difíceis voltam com maior frequência.',
                style: TextStyle(
                  color: colors.secondary,
                  fontSize: responsive.sp(10),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MateriaEditalCard extends StatelessWidget {
  const _MateriaEditalCard({
    super.key,
    required this.colors,
    required this.responsive,
    required this.catalogo,
    required this.draft,
    required this.index,
    required this.podeRemover,
    required this.onChanged,
    required this.onRemover,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final TaxonomyCatalog catalogo;
  final _MateriaDraft draft;
  final int index;
  final bool podeRemover;
  final VoidCallback onChanged;
  final VoidCallback onRemover;

  @override
  Widget build(BuildContext context) {
    final materias = catalogo.materiasOrdenadas;
    final topicos = draft.idMateria == null
        ? <Topico>[]
        : List<Topico>.of(catalogo.topicosDaMateria(draft.idMateria!));
    topicos.sort((a, b) => a.nome.compareTo(b.nome));
    final selecionados = draft.idsTopicos
        .where((id) => topicos.any((topico) => topico.id == id))
        .length;
    final todosSelecionados =
        topicos.isNotEmpty && selecionados == topicos.length;

    return Container(
      key: Key('edital-materia-card-$index'),
      padding: EdgeInsets.all(responsive.sp(11)),
      decoration: BoxDecoration(
        color: colors.cardSoft,
        borderRadius: BorderRadius.circular(responsive.sp(13)),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Matéria ${index + 1}',
                  style: TextStyle(
                    color: colors.text,
                    fontSize: responsive.sp(10.5),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (podeRemover)
                IconButton(
                  key: Key('edital-materia-remover-$index'),
                  onPressed: onRemover,
                  tooltip: 'Remover matéria',
                  style: IconButton.styleFrom(
                    foregroundColor: colors.danger,
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          DropdownButtonFormField<int?>(
            key: Key('edital-materia-select-$index'),
            initialValue: draft.idMateria,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Matéria'),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Escolha uma matéria...'),
              ),
              for (final materia in materias)
                DropdownMenuItem<int?>(
                  value: materia.id,
                  child: Text(materia.nome, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) {
              draft.idMateria = value;
              draft.idsTopicos.clear();
              draft.assuntosAbertos = false;
              onChanged();
            },
          ),
          if (draft.idMateria != null && topicos.isNotEmpty) ...[
            SizedBox(height: responsive.sp(8)),
            Material(
              color: colors.card,
              child: Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: PageStorageKey(
                    'edital-assuntos-$index-${draft.idMateria}',
                  ),
                  initiallyExpanded: draft.assuntosAbertos,
                  onExpansionChanged: (value) {
                    draft.assuntosAbertos = value;
                    onChanged();
                  },
                  tilePadding: EdgeInsets.symmetric(
                    horizontal: responsive.sp(8),
                  ),
                  childrenPadding: EdgeInsets.fromLTRB(
                    responsive.sp(8),
                    0,
                    responsive.sp(8),
                    responsive.sp(8),
                  ),
                  leading: Icon(
                    Icons.list_alt_rounded,
                    color: colors.secondary,
                    size: responsive.sp(17),
                  ),
                  title: Text(
                    'Assuntos do edital',
                    style: TextStyle(
                      color: colors.text,
                      fontSize: responsive.sp(10.5),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    selecionados == 0
                        ? 'Selecione ao menos um assunto'
                        : '$selecionados ${selecionados == 1 ? 'assunto selecionado' : 'assuntos selecionados'}',
                    style: TextStyle(
                      color: colors.secondary,
                      fontSize: responsive.sp(9),
                    ),
                  ),
                  children: [
                    _AssuntoCheck(
                      key: Key('edital-assunto-todos-$index'),
                      colors: colors,
                      responsive: responsive,
                      label: 'Marcar todo o edital',
                      selected: todosSelecionados,
                      bold: true,
                      onChanged: (value) {
                        draft.idsTopicos
                          ..clear()
                          ..addAll(
                            value
                                ? topicos.map((topico) => topico.id)
                                : const <int>[],
                          );
                        onChanged();
                      },
                    ),
                    for (final topico in topicos)
                      _AssuntoCheck(
                        key: Key('edital-assunto-$index-${topico.id}'),
                        colors: colors,
                        responsive: responsive,
                        label: topico.nome,
                        selected: draft.idsTopicos.contains(topico.id),
                        onChanged: (value) {
                          if (value) {
                            draft.idsTopicos.add(topico.id);
                          } else {
                            draft.idsTopicos.remove(topico.id);
                          }
                          onChanged();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ] else if (draft.idMateria != null)
            Padding(
              padding: EdgeInsets.only(top: responsive.sp(8)),
              child: Text(
                'Não há assuntos cadastrados para esta matéria.',
                style: TextStyle(
                  color: colors.secondary,
                  fontSize: responsive.sp(10),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AssuntoCheck extends StatelessWidget {
  const _AssuntoCheck({
    super.key,
    required this.colors,
    required this.responsive,
    required this.label,
    required this.selected,
    required this.onChanged,
    this.bold = false,
  });

  final SimuladosColors colors;
  final Responsive responsive;
  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final bool bold;

  @override
  Widget build(BuildContext context) => Material(
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

class _RodapeCriacao extends StatelessWidget {
  const _RodapeCriacao({
    required this.colors,
    required this.criando,
    required this.onCancelar,
    required this.onCriar,
  });

  final SimuladosColors colors;
  final bool criando;
  final VoidCallback onCancelar;
  final VoidCallback? onCriar;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        responsive.sp(14),
        responsive.sp(8),
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
            key: const Key('edital-cancelar'),
            onPressed: criando ? null : onCancelar,
            style: TextButton.styleFrom(
              foregroundColor: colors.secondary,
              minimumSize: const Size(78, 48),
            ),
            child: const Text('Cancelar'),
          ),
          SizedBox(width: responsive.sp(8)),
          Expanded(
            child: FilledButton.icon(
              key: const Key('edital-criar-confirmar'),
              onPressed: criando ? null : onCriar,
              icon: criando
                  ? SizedBox(
                      width: responsive.sp(16),
                      height: responsive.sp(16),
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(Icons.rocket_launch_rounded, size: responsive.sp(16)),
              label: Text(criando ? 'Criando...' : 'Criar Meu Ciclo'),
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
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
