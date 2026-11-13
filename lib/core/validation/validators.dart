import '../utils/slug.dart';

/// Resultado de uma validação com valor normalizado.
class ValidatedValue {
  const ValidatedValue.valid(this.value) : error = null;
  const ValidatedValue.invalid(this.error) : value = null;

  final String? value;
  final String? error;

  bool get isValid => error == null;
}

class Validators {
  const Validators._();

  static const usernameMin = 2;
  static const usernameMax = 30;
  static const commentMax = 1000;
  static const passwordMin = 8;

  static final _usernamePattern = RegExp(
    r'^[\p{L}\p{N}_ .-]+$',
    unicode: true,
  );
  static final _controlChars = RegExp(r'[\x00-\x1f\x7f]');
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Normaliza e valida o nome de usuário exibido na comunidade.
  static ValidatedValue username(String? raw) {
    if (raw is! String) {
      return const ValidatedValue.invalid('Nome de usuário inválido.');
    }
    final normalized = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length < usernameMin || normalized.length > usernameMax) {
      return const ValidatedValue.invalid(
        'O nome de usuário deve ter entre 2 e 30 caracteres.',
      );
    }
    if (!_usernamePattern.hasMatch(normalized)) {
      return const ValidatedValue.invalid(
        'O nome de usuário pode conter apenas letras, números, espaços, '
        'ponto, hífen e sublinhado.',
      );
    }
    return ValidatedValue.valid(normalized);
  }

  /// Base de username para criação automática de perfil.
  ///
  /// Primeiro tenta preservar o valor; se ele não passar na allowlist, remove
  /// caracteres inválidos (ex.: prefixo de e-mail `joao+teste`), trunca e cai
  /// em "Estudante" se nada sobrar.
  static String usernameBase(String? raw) {
    final collapsed = (raw ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    final direct = username(collapsed);
    if (direct.isValid) return direct.value!;

    var cleaned = collapsed.replaceAll(RegExp(r'[^\p{L}\p{N}_ .-]', unicode: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    cleaned = cleaned.replaceAll(RegExp(r'^[ ._-]+|[ ._-]+$'), '');
    if (cleaned.length > usernameMax) {
      cleaned = cleaned.substring(0, usernameMax);
    }
    cleaned = cleaned.trim();
    final validated = username(cleaned);
    return validated.value ?? 'Estudante';
  }

  static ValidatedValue comment(String? raw) {
    if (raw is! String) {
      return const ValidatedValue.invalid('Comentário inválido.');
    }
    final text = raw.trim();
    if (text.isEmpty) {
      return const ValidatedValue.invalid('Escreva um comentário antes de enviar.');
    }
    if (text.length > commentMax) {
      return const ValidatedValue.invalid(
        'O comentário deve ter no máximo 1000 caracteres.',
      );
    }
    if (_controlChars.hasMatch(text)) {
      return const ValidatedValue.invalid('O comentário contém caracteres inválidos.');
    }
    return ValidatedValue.valid(text);
  }

  static String? email(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    if (value.isEmpty) return 'Informe seu e-mail.';
    if (!_emailPattern.hasMatch(value)) return 'Informe um e-mail válido.';
    return null;
  }

  static String? password(String? raw) {
    final value = raw ?? '';
    if (value.length < passwordMin) {
      return 'A senha precisa ter no mínimo $passwordMin caracteres.';
    }
    return null;
  }

  static String? passwordConfirmation(String? password, String? confirmation) {
    if (password != confirmation) {
      return 'As senhas não conferem. Digite a mesma senha nos dois campos.';
    }
    return null;
  }

  /// Deriva um username curto do e-mail, como o backend faz no login.
  static String usernameFromEmail(String email) {
    final prefix = email.split('@').first;
    return usernameBase(prefix);
  }

  /// Usado para validar ids inteiros recebidos da UI.
  static int? positiveInt(Object? value) {
    if (value is bool || value == null) return null;
    final parsed = value is int ? value : int.tryParse(value.toString());
    if (parsed == null || parsed <= 0 || parsed > 2147483647) return null;
    return parsed;
  }

  static String? requiredText(String? value) {
    if (value == null || value.trim().isEmpty) return 'Campo obrigatório.';
    return null;
  }

  /// Ajuda a manter slugs estáveis para links de matéria/tópico.
  static bool slugMatches(String? a, String? b) => slugify(a) == slugify(b);
}
