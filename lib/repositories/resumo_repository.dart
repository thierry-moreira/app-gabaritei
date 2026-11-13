import '../core/data/database.dart';
import '../core/data/repository_helpers.dart';
import '../models/study.dart';

/// Resumos de estudo agrupados por matéria (`rotas/resumos.py`).
class ResumoRepository {
  ResumoRepository({required this._db});

  final GabariteiDatabase _db;

  Future<List<ResumosPorMateria>> listarPorMateria(String idUsuario) {
    return mapDatabaseErrors(() async {
      final resultado = await _db
          .from('resumos_estudo')
          .select('id_materia, materias(nome_materia)')
          .eq('id_usuario', idUsuario)
          .get();

      final grupos = <int, ({String nome, int total})>{};
      final ordem = <int>[];
      for (final linha in resultado.rows) {
        final id = _intOrNull(linha['id_materia']);
        if (id == null) continue;
        final materias = linha['materias'];
        var nome = 'Matéria não encontrada';
        if (materias is Map) {
          final valor = materias['nome_materia'];
          if (valor != null && valor.toString().isNotEmpty) {
            nome = valor.toString();
          }
        }
        final atual = grupos[id];
        if (atual == null) {
          grupos[id] = (nome: nome, total: 1);
          ordem.add(id);
        } else {
          grupos[id] = (nome: atual.nome, total: atual.total + 1);
        }
      }

      return [
        for (final id in ordem)
          ResumosPorMateria(
            idMateria: id,
            nomeMateria: grupos[id]!.nome,
            total: grupos[id]!.total,
          ),
      ];
    });
  }

  Future<List<Resumo>> listarDaMateria({
    required String idUsuario,
    required int idMateria,
  }) {
    return mapDatabaseErrors(() async {
      final resultado = await _db
          .from('resumos_estudo')
          .select('*, materias(nome_materia)')
          .eq('id_usuario', idUsuario)
          .eq('id_materia', idMateria)
          .order('criado_em')
          .get();
      return resultado.rows.map(Resumo.fromMap).toList(growable: false);
    });
  }

  /// Busca o nome público da matéria para manter a tela aberta quando o
  /// último resumo daquele caderno é removido.
  Future<ResumosPorMateria?> buscarMateria(int idMateria) {
    return mapDatabaseErrors(() async {
      final linha = await _db
          .from('materias')
          .select('id_materia, nome_materia')
          .eq('id_materia', idMateria)
          .limit(1)
          .maybeSingle();
      if (linha == null) return null;
      return ResumosPorMateria(
        idMateria: _intOrNull(linha['id_materia']) ?? idMateria,
        nomeMateria: linha['nome_materia']?.toString() ?? 'Matéria',
        total: 0,
      );
    });
  }

  Future<void> excluir({required String idUsuario, required String idResumo}) {
    return mapDatabaseErrors(
      () => _db
          .from('resumos_estudo')
          .delete()
          .eq('id_resumo', idResumo)
          .eq('id_usuario', idUsuario)
          .execute(),
    );
  }

  Future<void> excluirMateria({
    required String idUsuario,
    required int idMateria,
  }) {
    return mapDatabaseErrors(
      () => _db
          .from('resumos_estudo')
          .delete()
          .eq('id_materia', idMateria)
          .eq('id_usuario', idUsuario)
          .execute(),
    );
  }

  int? _intOrNull(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
