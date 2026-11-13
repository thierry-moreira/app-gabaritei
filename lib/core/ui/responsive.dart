import 'package:flutter/material.dart';

/// Faixas de largura usadas para adaptar o layout do app.
///
/// - `compact`: celulares (< 600 dp)
/// - `medium`: tablets em retrato (600–899 dp)
/// - `expanded`: tablets em paisagem / janelas médias (900–1199 dp)
/// - `large`: telas grandes (>= 1200 dp)
enum ResponsiveBreakpoint { compact, medium, expanded, large }

/// Utilitário compartilhado de responsividade.
///
/// Centraliza breakpoints, larguras máximas de conteúdo e escala de
/// tipografia/componentes para que painel, raio-x e autenticação cresçam de
/// forma consistente em tablets e telas maiores, sem perder a leitura no
/// celular.
@immutable
class Responsive {
  const Responsive._(this.breakpoint, this.size);

  factory Responsive.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final breakpoint = switch (size.width) {
      >= 1200 => ResponsiveBreakpoint.large,
      >= 900 => ResponsiveBreakpoint.expanded,
      >= 600 => ResponsiveBreakpoint.medium,
      _ => ResponsiveBreakpoint.compact,
    };
    return Responsive._(breakpoint, size);
  }

  final ResponsiveBreakpoint breakpoint;
  final Size size;

  bool get isCompact => breakpoint == ResponsiveBreakpoint.compact;
  bool get isMedium => breakpoint == ResponsiveBreakpoint.medium;
  bool get isExpanded => breakpoint == ResponsiveBreakpoint.expanded;
  bool get isLarge => breakpoint == ResponsiveBreakpoint.large;
  bool get isTabletOrLarger => !isCompact;
  bool get isLandscape => size.width > size.height;

  /// Largura máxima do painel inicial.
  double get dashboardMaxWidth => switch (breakpoint) {
    ResponsiveBreakpoint.compact => 512,
    ResponsiveBreakpoint.medium => 760,
    ResponsiveBreakpoint.expanded => 1040,
    ResponsiveBreakpoint.large => 1160,
  };

  /// Largura máxima do raio-x (dashboard detalhado).
  double get detailedMaxWidth => switch (breakpoint) {
    ResponsiveBreakpoint.compact => 480,
    ResponsiveBreakpoint.medium => 760,
    ResponsiveBreakpoint.expanded => 1080,
    ResponsiveBreakpoint.large => 1160,
  };

  /// Largura máxima da tela de questões.
  ///
  /// A leitura de enunciados longos pede uma coluna mais estreita que o
  /// painel: mesmo em telas grandes o conteúdo não passa de 960 dp.
  double get questionsMaxWidth => switch (breakpoint) {
    ResponsiveBreakpoint.compact => 560,
    ResponsiveBreakpoint.medium => 760,
    ResponsiveBreakpoint.expanded => 900,
    ResponsiveBreakpoint.large => 960,
  };

  /// Largura máxima dos formulários de autenticação.
  double get authMaxWidth => switch (breakpoint) {
    ResponsiveBreakpoint.compact => 400,
    ResponsiveBreakpoint.medium => 480,
    ResponsiveBreakpoint.expanded => 520,
    ResponsiveBreakpoint.large => 520,
  };

  /// Fator aplicado a tipografia e componentes.
  double get scale => switch (breakpoint) {
    ResponsiveBreakpoint.compact => 1,
    ResponsiveBreakpoint.medium => 1.14,
    ResponsiveBreakpoint.expanded => 1.22,
    ResponsiveBreakpoint.large => 1.28,
  };

  /// Escala um tamanho de fonte/componente.
  double sp(double value) => value * scale;

  /// Padding horizontal/vertical padrão das páginas.
  EdgeInsets get pagePadding => EdgeInsets.fromLTRB(
    isCompact ? 16 : 24,
    isCompact ? 16 : 24,
    isCompact ? 16 : 24,
    isCompact ? 0 : 8,
  );

  /// Espaço entre seções.
  double get gap => isCompact ? 16 : 20;

  /// Raio padrão dos cards.
  double get cardRadius => isCompact ? 16 : 20;

  /// Métricas em três colunas a partir do tablet.
  bool get useThreeMetricCards => isTabletOrLarger;

  /// Layout em duas colunas do raio-x a partir de 900 dp.
  bool get useTwoColumnDetailedLayout => !isCompact && !isMedium;
}
