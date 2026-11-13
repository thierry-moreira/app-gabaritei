import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../../core/ui/responsive.dart';
import '../widgets/latex_text.dart';
import 'dashboard_shell.dart';

/// Cores da tela de flashcards conforme as referências Stitch claro/escuro.
@immutable
class FlashcardsColors {
  const FlashcardsColors({
    required this.isDark,
    required this.bg,
    required this.surface,
    required this.card,
    required this.cardSoft,
    required this.border,
    required this.text,
    required this.secondary,
    required this.muted,
    required this.primary,
    required this.accent,
    required this.accentSoft,
    required this.accentBorder,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
  });

  final bool isDark;
  final Color bg;
  final Color surface;
  final Color card;
  final Color cardSoft;
  final Color border;
  final Color text;
  final Color secondary;
  final Color muted;
  final Color primary;
  final Color accent;
  final Color accentSoft;
  final Color accentBorder;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;

  static FlashcardsColors of(bool isDark) => isDark ? dark : light;

  static const light = FlashcardsColors(
    isDark: false,
    bg: Color(0xFFF8FAFC),
    surface: Colors.white,
    card: Colors.white,
    cardSoft: Color(0xFFF1F5F9),
    border: Color(0xFFE2E8F0),
    text: Color(0xFF0F172A),
    secondary: Color(0xFF64748B),
    muted: Color(0xFF94A3B8),
    primary: Color(0xFF0F172A),
    accent: Color(0xFF2563EB),
    accentSoft: Color(0xFFEFF6FF),
    accentBorder: Color(0xFFBFDBFE),
    success: Color(0xFF15803D),
    successSoft: Color(0xFFF0FDF4),
    warning: Color(0xFFB45309),
    warningSoft: Color(0xFFFFFBEB),
    danger: Color(0xFFDC2626),
    dangerSoft: Color(0xFFFEF2F2),
  );

  static const dark = FlashcardsColors(
    isDark: true,
    bg: Color(0xFF07090E),
    surface: Color(0xFF0B0F17),
    card: Color(0xFF0F172A),
    cardSoft: Color(0xFF111B2A),
    border: Color(0xFF1E293B),
    text: Color(0xFFF8FAFC),
    secondary: Color(0xFF94A3B8),
    muted: Color(0xFF64748B),
    primary: Color(0xFF2563EB),
    accent: Color(0xFF60A5FA),
    accentSoft: Color(0xFF10213A),
    accentBorder: Color(0xFF1D4ED8),
    success: Color(0xFF4ADE80),
    successSoft: Color(0xFF0F2419),
    warning: Color(0xFFFBBF24),
    warningSoft: Color(0xFF2A2110),
    danger: Color(0xFFF87171),
    dangerSoft: Color(0xFF2A1416),
  );
}

/// Moldura compartilhada pelas telas de flashcards.
class FlashcardsPageShell extends ConsumerWidget {
  const FlashcardsPageShell({
    super.key,
    required this.child,
    this.selectedIndex = 3,
    this.backgroundColor,
  });

  final Widget child;
  final int selectedIndex;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = FlashcardsColors.of(isDark);
    final perfil = ref.watch(perfilAtualProvider);
    final painel = ref.watch(painelProvider);

    return Scaffold(
      backgroundColor: backgroundColor ?? colors.bg,
      body: Column(
        children: [
          DashboardTopBar(
            isDark: isDark,
            streak: painel.value?.ofensiva ?? 0,
            username: perfil.value?.username ?? 'Estudante',
            onToggleTheme: () =>
                ref.read(themeModeProvider.notifier).alternar(isDark),
            onLogout: () => _sair(context, ref),
          ),
          Expanded(child: child),
          DashboardBottomNav(
            isDark: isDark,
            selectedIndex: selectedIndex,
            onSelected: (index) => _navegar(context, index),
          ),
        ],
      ),
    );
  }

  void _navegar(BuildContext context, int index) {
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
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                '${DashboardBottomNav.labelFor(index)} chega em breve.',
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
    }
  }

  Future<void> _sair(BuildContext context, WidgetRef ref) async {
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
    if (confirmar != true || !context.mounted) return;

    await ref.read(authGatewayProvider).signOut();
    if (!context.mounted) return;
    ref.invalidate(perfilAtualProvider);
    ref.invalidate(painelProvider);
    ref.invalidate(flashcardsDashboardProvider);
    context.go('/login');
  }
}

class FlashcardsPanel extends StatelessWidget {
  const FlashcardsPanel({
    super.key,
    required this.colors,
    required this.child,
    this.padding,
    this.radius = 20,
  });

  final FlashcardsColors colors;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: colors.border),
      ),
      child: child,
    );
  }
}

/// Renderiza a formatação permitida nos conteúdos dos flashcards: negrito
/// (`<b>`/`<strong>`), itálico (`<i>`/`<em>`), negrito Markdown legado,
/// `<mark>realce</mark>` e fórmulas LaTeX nos mesmos delimitadores do desktop.
/// O restante permanece literal, sem interpretar HTML arbitrário.
class FlashcardRichText extends StatelessWidget {
  const FlashcardRichText({
    super.key,
    required this.text,
    required this.colors,
    required this.style,
    this.textAlign,
  });

  final String text;
  final FlashcardsColors colors;
  final TextStyle style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return LatexText(
      text,
      style: style,
      textAlign: textAlign ?? TextAlign.start,
      highlightStyle: TextStyle(
        color: colors.isDark
            ? const Color(0xFF1F2937)
            : const Color(0xFF212529),
        backgroundColor: const Color(0xFFFFD43B),
        fontWeight: FontWeight.w600,
      ),
      markdownBoldStyle: TextStyle(
        color: colors.isDark ? const Color(0xFFA5B4FC) : colors.accent,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class FlashcardsFooter extends StatelessWidget {
  const FlashcardsFooter({
    super.key,
    required this.colors,
    required this.responsive,
  });

  final FlashcardsColors colors;
  final Responsive responsive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: responsive.sp(8),
        bottom: responsive.sp(20),
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

Future<String?> showNovaFlashcardCategoriaDialog(
  BuildContext context, {
  required FlashcardsColors colors,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _NovaFlashcardCategoriaDialog(colors: colors),
  );
}

class _NovaFlashcardCategoriaDialog extends StatefulWidget {
  const _NovaFlashcardCategoriaDialog({required this.colors});

  final FlashcardsColors colors;

  @override
  State<_NovaFlashcardCategoriaDialog> createState() =>
      _NovaFlashcardCategoriaDialogState();
}

class _NovaFlashcardCategoriaDialogState
    extends State<_NovaFlashcardCategoriaDialog> {
  final _formKey = GlobalKey<FormState>();
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
    return AlertDialog(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(responsive.sp(20)),
        side: BorderSide(color: colors.border),
      ),
      title: Text(
        'Nova Categoria',
        style: TextStyle(
          color: colors.text,
          fontSize: responsive.sp(18),
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: const Key('flashcards-categoria-nome'),
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          maxLength: 80,
          decoration: InputDecoration(
            labelText: 'Nome da Categoria',
            hintText: 'Ex.: Direito Administrativo',
            filled: true,
            fillColor: colors.surface,
            counterStyle: TextStyle(color: colors.muted),
          ),
          validator: (value) => (value?.trim().isNotEmpty ?? false)
              ? null
              : 'Informe o nome da categoria.',
          onFieldSubmitted: (_) => _salvar(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancelar', style: TextStyle(color: colors.secondary)),
        ),
        FilledButton(
          key: const Key('flashcards-categoria-criar-confirmar'),
          onPressed: _salvar,
          style: FilledButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 48),
          ),
          child: const Text('Criar Categoria'),
        ),
      ],
    );
  }

  void _salvar() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(context).pop(_controller.text.trim());
  }
}

class FlashcardDraft {
  const FlashcardDraft({required this.frente, required this.verso});

  final String frente;
  final String verso;
}

Future<FlashcardDraft?> showNovoFlashcardDialog(
  BuildContext context, {
  required FlashcardsColors colors,
}) {
  return showDialog<FlashcardDraft>(
    context: context,
    builder: (_) => _NovoFlashcardDialog(colors: colors),
  );
}

class _NovoFlashcardDialog extends StatefulWidget {
  const _NovoFlashcardDialog({required this.colors});

  final FlashcardsColors colors;

  @override
  State<_NovoFlashcardDialog> createState() => _NovoFlashcardDialogState();
}

class _NovoFlashcardDialogState extends State<_NovoFlashcardDialog> {
  final _formKey = GlobalKey<FormState>();
  final _frente = TextEditingController();
  final _verso = TextEditingController();

  @override
  void dispose() {
    _frente.dispose();
    _verso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final responsive = Responsive.of(context);
    return Dialog(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.all(responsive.sp(18)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(responsive.sp(20)),
        side: BorderSide(color: colors.border),
      ),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: responsive.isCompact ? 520 : 680,
            maxHeight: MediaQuery.sizeOf(context).height * 0.84,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(responsive.sp(20)),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Criar Flashcard Manual',
                          style: TextStyle(
                            color: colors.text,
                            fontSize: responsive.sp(18),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fechar',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: colors.secondary,
                        ),
                      ),
                    ],
                  ),
                  Divider(color: colors.border),
                  SizedBox(height: responsive.sp(12)),
                  _campo(
                    context,
                    controller: _frente,
                    fieldKey: const Key('flashcard-frente'),
                    label: 'Frente do card (pergunta/conceito)',
                    hint: 'O que você quer memorizar?',
                    maxLines: 4,
                    minLines: 3,
                    requiredMessage: 'Preencha a frente do flashcard.',
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: const Key('flashcard-realcar-frente'),
                      onPressed: () => _realcar(_frente),
                      icon: const Icon(Icons.highlight_alt_outlined),
                      label: const Text('Destacar seleção'),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.accent,
                        minimumSize: const Size(48, 48),
                      ),
                    ),
                  ),
                  SizedBox(height: responsive.sp(8)),
                  _campo(
                    context,
                    controller: _verso,
                    fieldKey: const Key('flashcard-verso'),
                    label: 'Verso do card (resposta/explicação)',
                    hint: 'A explicação do card...',
                    maxLines: 5,
                    minLines: 4,
                    requiredMessage: 'Preencha o verso do flashcard.',
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: const Key('flashcard-realcar-verso'),
                      onPressed: () => _realcar(_verso),
                      icon: const Icon(Icons.highlight_alt_outlined),
                      label: const Text('Destacar seleção'),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.accent,
                        minimumSize: const Size(48, 48),
                      ),
                    ),
                  ),
                  SizedBox(height: responsive.sp(14)),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: responsive.sp(8),
                    runSpacing: responsive.sp(8),
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.secondary,
                          side: BorderSide(color: colors.border),
                          minimumSize: const Size(100, 48),
                        ),
                        child: const Text('Fechar'),
                      ),
                      FilledButton.icon(
                        key: const Key('flashcard-salvar-confirmar'),
                        onPressed: _salvar,
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Salvar Flashcard'),
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(180, 48),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _campo(
    BuildContext context, {
    required TextEditingController controller,
    required Key fieldKey,
    required String label,
    required String hint,
    required int maxLines,
    required int minLines,
    required String requiredMessage,
  }) {
    final colors = widget.colors;
    return TextFormField(
      key: fieldKey,
      controller: controller,
      textCapitalization: TextCapitalization.sentences,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: 5000,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: true,
        filled: true,
        fillColor: colors.surface,
        counterStyle: TextStyle(color: colors.muted),
      ),
      validator: (value) =>
          (value?.trim().isNotEmpty ?? false) ? null : requiredMessage,
    );
  }

  void _realcar(TextEditingController controller) {
    final selection = controller.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    final texto = controller.text;
    final inicio = selection.start;
    final fim = selection.end;
    final selecionado = texto.substring(inicio, fim);
    final atualizado = texto.replaceRange(
      inicio,
      fim,
      '<mark>$selecionado</mark>',
    );
    controller.value = TextEditingValue(
      text: atualizado,
      selection: TextSelection.collapsed(
        offset: inicio + '<mark>'.length + selecionado.length,
      ),
    );
  }

  void _salvar() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(context).pop(
      FlashcardDraft(frente: _frente.text.trim(), verso: _verso.text.trim()),
    );
  }
}

class FlashcardFeedbackDraft {
  const FlashcardFeedbackDraft({required this.motivo, required this.relato});

  final String motivo;
  final String relato;
}

Future<FlashcardFeedbackDraft?> showFlashcardFeedbackDialog(
  BuildContext context, {
  required FlashcardsColors colors,
  required Map<String, String> motivos,
}) {
  return showDialog<FlashcardFeedbackDraft>(
    context: context,
    builder: (_) => _FlashcardFeedbackDialog(colors: colors, motivos: motivos),
  );
}

class _FlashcardFeedbackDialog extends StatefulWidget {
  const _FlashcardFeedbackDialog({required this.colors, required this.motivos});

  final FlashcardsColors colors;
  final Map<String, String> motivos;

  @override
  State<_FlashcardFeedbackDialog> createState() =>
      _FlashcardFeedbackDialogState();
}

class _FlashcardFeedbackDialogState extends State<_FlashcardFeedbackDialog> {
  final _formKey = GlobalKey<FormState>();
  final _relato = TextEditingController();
  String? _motivo;

  @override
  void dispose() {
    _relato.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return AlertDialog(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      title: Text(
        'Reportar problema',
        style: TextStyle(color: colors.text, fontWeight: FontWeight.w700),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              key: const Key('flashcard-feedback-motivo'),
              isExpanded: true,
              initialValue: _motivo,
              decoration: const InputDecoration(labelText: 'Motivo'),
              items: [
                for (final entry in widget.motivos.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              validator: (value) =>
                  value == null ? 'Selecione o motivo.' : null,
              onChanged: (value) => setState(() => _motivo = value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('flashcard-feedback-relato'),
              controller: _relato,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Detalhes (opcional)',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancelar', style: TextStyle(color: colors.secondary)),
        ),
        FilledButton(
          key: const Key('flashcard-feedback-enviar'),
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            Navigator.of(context).pop(
              FlashcardFeedbackDraft(
                motivo: _motivo!,
                relato: _relato.text.trim(),
              ),
            );
          },
          style: FilledButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 48),
          ),
          child: const Text('Enviar'),
        ),
      ],
    );
  }
}
