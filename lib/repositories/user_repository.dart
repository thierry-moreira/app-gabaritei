import '../core/data/database.dart';
import '../core/data/repository_helpers.dart';
import '../core/errors/app_exception.dart';
import '../core/validation/validators.dart';
import '../models/user_profile.dart';

/// Operações de conta do aluno (`rotas/conta.py` e meta diária de `aluno.py`).
class UserRepository {
  UserRepository({required this._db});

  final GabariteiDatabase _db;

  Future<UserProfile> perfil(int idUsuario) async {
    return mapDatabaseErrors(() async {
      final linha = await _db
          .from('usuarios')
          .select('*')
          .eq('id', idUsuario)
          .limit(1)
          .maybeSingle();
      if (linha == null) {
        throw NotFoundException('Perfil não encontrado.');
      }
      return UserProfile.fromMap(linha);
    });
  }

  Future<UserProfile> atualizarPerfil({
    required int idUsuario,
    required String username,
    String? email,
  }) async {
    final validado = Validators.username(username);
    if (!validado.isValid) {
      throw ValidationException(validado.error!);
    }
    final emailNormalizado = (email ?? '').trim().toLowerCase();

    return mapDatabaseErrors(() async {
      final linhas = await _db
          .from('usuarios')
          .update({
            'username': validado.value,
            'email': emailNormalizado.isEmpty ? null : emailNormalizado,
          })
          .eq('id', idUsuario)
          .execute();
      if (linhas.isEmpty) {
        throw NotFoundException('Perfil não encontrado.');
      }
      return UserProfile.fromMap(linhas.first);
    });
  }

  Future<void> definirMetaDiaria(int idUsuario, int meta) async {
    if (meta < 0) {
      throw ValidationException('A meta diária não pode ser negativa.');
    }
    await mapDatabaseErrors(
      () => _db
          .from('usuarios')
          .update({'meta_diaria': meta})
          .eq('id', idUsuario)
          .execute(),
    );
  }

  /// Zera todo o progresso de estudo mantendo a conta
  /// (`/aluno/conta/resetar-dados`).
  Future<void> resetarDados(int idUsuario) async {
    final idTexto = idUsuario.toString();
    await mapDatabaseErrors(() async {
      await _db
          .from('usuarios')
          .update({'meta_diaria': 0})
          .eq('id', idUsuario)
          .execute();

      await _db
          .from('historico_respostas')
          .delete()
          .eq('id_usuario', idTexto)
          .execute();
      await _db
          .from('cadernos')
          .delete()
          .eq('id_usuario', idUsuario)
          .execute();
      await _db
          .from('filtros_salvos')
          .delete()
          .eq('id_usuario', idUsuario)
          .execute();
      await _db
          .from('flashcard_categorias')
          .delete()
          .eq('id_usuario', idTexto)
          .execute();
      await _db
          .from('flashcards')
          .delete()
          .eq('id_usuario', idTexto)
          .execute();
      await _db
          .from('simulados')
          .delete()
          .eq('id_criador', idUsuario)
          .execute();
      await _db
          .from('editais_ciclo')
          .delete()
          .eq('id_usuario', idUsuario)
          .execute();
      await _db
          .from('editais_materias')
          .delete()
          .eq('id_usuario', idUsuario)
          .execute();
      await _db
          .from('editais_topicos')
          .delete()
          .eq('id_usuario', idUsuario)
          .execute();
      await _db
          .from('editais_progresso')
          .delete()
          .eq('id_usuario', idUsuario)
          .execute();
      await _db
          .from('comentarios_questao')
          .delete()
          .eq('id_usuario', idTexto)
          .execute();
      await _db
          .from('reports_comentarios')
          .delete()
          .eq('id_usuario', idTexto)
          .execute();
    });
  }

  /// Remove o perfil público do aluno (a conta Auth é removida pelo suporte,
  /// assim como no backend Flask).
  Future<void> excluirPerfil(int idUsuario) async {
    final idTexto = idUsuario.toString();
    await mapDatabaseErrors(() async {
      await _db
          .from('reports_comentarios')
          .delete()
          .eq('id_usuario', idTexto)
          .execute();
      await _db.from('usuarios').delete().eq('id', idUsuario).execute();
    });
  }
}
