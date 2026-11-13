import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tema escolhido pelo aluno durante a sessão.
///
/// O padrão continua sendo o tema do sistema. O botão de sol/lua do cabeçalho
/// alterna explicitamente entre claro e escuro; a escolha vale para todas as
/// telas enquanto o app estiver aberto.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void alternar(bool temaEscuroAtual) {
    state = temaEscuroAtual ? ThemeMode.light : ThemeMode.dark;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
