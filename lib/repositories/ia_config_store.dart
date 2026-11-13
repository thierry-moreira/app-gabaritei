import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/errors/app_exception.dart';
import '../services/ai_provider_service.dart';

/// Porta de armazenamento seguro — permite fake nos testes.
abstract class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// BYOK: a chave de IA fica apenas no dispositivo (Keychain/Keystore), nunca
/// no Supabase — mesma decisão de privacidade de `banco_local.py`.
class IaConfigStore {
  IaConfigStore({required this._storage});

  final SecureKeyValueStore _storage;

  static const _prefixo = 'gabaritei.ia.';

  String _chave(int idUsuario) => '$_prefixo$idUsuario';

  Future<AiConfig?> ler(int idUsuario) async {
    final bruto = await _storage.read(_chave(idUsuario));
    if (bruto == null || bruto.isEmpty) return null;
    try {
      final json = jsonDecode(bruto);
      if (json is! Map) return null;
      final config = AiConfig.fromJson(
        json.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (config.provedor.isEmpty || config.chave.isEmpty) return null;
      return config;
    } catch (_) {
      return null;
    }
  }

  Future<void> salvar(int idUsuario, AiConfig config) async {
    if (!AiProviderService.provedores.containsKey(config.provedor)) {
      throw ValidationException('Provedor não suportado.');
    }
    if (config.chave.trim().length < 20) {
      throw ValidationException('Chave de API inválida (muito curta).');
    }
    await _storage.write(
      _chave(idUsuario),
      jsonEncode(config.toJson()),
    );
  }

  Future<bool> remover(int idUsuario) async {
    final existia = await _storage.read(_chave(idUsuario)) != null;
    await _storage.delete(_chave(idUsuario));
    return existia;
  }

  static String mascarar(String chave) {
    if (chave.isEmpty) return '';
    if (chave.length <= 8) return '••••••';
    return '${chave.substring(0, 4)}…${chave.substring(chave.length - 4)}';
  }
}
