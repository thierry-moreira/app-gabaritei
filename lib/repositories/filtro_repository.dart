import '../core/data/database.dart';
import '../core/data/repository_helpers.dart';
import '../core/errors/app_exception.dart';
import '../models/study.dart';

/// Filtros de questões salvos pelo aluno (`rotas/filtro.py`).
class FiltroRepository {
  FiltroRepository({required this._db});

  final GabariteiDatabase _db;

  Future<List<FiltroSalvo>> listar(int idUsuario) {
    return mapDatabaseErrors(() async {
      final resultado = await _db
          .from('filtros_salvos')
          .select('*')
          .eq('id_usuario', idUsuario)
          .order('criado_em', ascending: false)
          .get();
      return resultado.rows.map(FiltroSalvo.fromMap).toList(growable: false);
    });
  }

  Future<FiltroSalvo> salvar({
    required int idUsuario,
    required String nome,
    required String urlParams,
  }) {
    final nomeLimpo = nome.trim();
    if (nomeLimpo.isEmpty) {
      throw ValidationException('Informe um nome para o filtro.');
    }

    return mapDatabaseErrors(() async {
      final linhas = await _db.from('filtros_salvos').insert({
        'id_usuario': idUsuario,
        'nome_filtro': nomeLimpo,
        'url_params': urlParams,
      });
      if (linhas.isEmpty) {
        throw AppException('Não foi possível salvar o filtro.');
      }
      return FiltroSalvo.fromMap(linhas.first);
    });
  }

  Future<void> excluir({
    required String idFiltro,
    required int idUsuario,
  }) {
    if (idFiltro.trim().isEmpty) {
      throw ValidationException('Filtro inválido.');
    }
    return mapDatabaseErrors(
      () => _db
          .from('filtros_salvos')
          .delete()
          .eq('id', idFiltro)
          .eq('id_usuario', idUsuario)
          .execute(),
    );
  }
}
