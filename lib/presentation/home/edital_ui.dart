import 'package:flutter/material.dart';

import '../../core/errors/app_exception.dart';
import '../../core/ui/responsive.dart';
import 'flashcards_ui.dart';
import 'simulados_ui.dart';

/// Edital screens share the app's top bar and bottom navigation.
class EditalPageShell extends StatelessWidget {
  const EditalPageShell({super.key, required this.colors, required this.child});

  final SimuladosColors colors;
  final Widget child;

  @override
  Widget build(BuildContext context) => FlashcardsPageShell(
    selectedIndex: 6,
    backgroundColor: colors.bg,
    child: child,
  );
}

class EditalErrorState extends StatelessWidget {
  const EditalErrorState({
    super.key,
    required this.colors,
    required this.title,
    required this.message,
    required this.onRetry,
    this.onBack,
  });

  final SimuladosColors colors;
  final String title;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return Center(
      child: Padding(
        padding: responsive.pagePadding,
        child: SimuladoPanel(
          key: const Key('edital-erro'),
          colors: colors,
          padding: EdgeInsets.all(responsive.sp(22)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                color: colors.muted,
                size: responsive.sp(36),
              ),
              SizedBox(height: responsive.sp(10)),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.text,
                  fontSize: responsive.sp(15),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: responsive.sp(7)),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.secondary,
                  fontSize: responsive.sp(11),
                  height: 1.45,
                ),
              ),
              SizedBox(height: responsive.sp(14)),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: responsive.sp(8),
                children: [
                  if (onBack != null)
                    OutlinedButton(
                      onPressed: onBack,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.secondary,
                        side: BorderSide(color: colors.border),
                        minimumSize: const Size(48, 48),
                      ),
                      child: const Text('Voltar'),
                    ),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Tentar novamente'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(48, 48),
                    ),
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

String editalErrorMessage(Object? error) {
  if (error is AppException) return error.message;
  if (error is StateError) {
    return 'Sua sessão não está disponível. Entre novamente.';
  }
  return 'Não foi possível concluir a operação. Tente novamente.';
}

void showEditalMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
}
