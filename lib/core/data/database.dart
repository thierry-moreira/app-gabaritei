/// Abstração mínima do PostgREST usada pelos repositórios.
///
/// Os testes de domínio usam um fake em memória; o app usa
/// [SupabaseDatabase]. A API imita o encadeamento do backend Flask
/// (`table(...).select(...).eq(...).order(...).range(...)`) sem expor o SDK,
/// cujos builders perdem os métodos de filtro depois de `order`/`range`.
library;

/// Resultado de uma consulta com contagem opcional.
class DbResult {
  const DbResult(this.rows, {this.count});

  final List<Map<String, dynamic>> rows;
  final int? count;

  Map<String, dynamic>? get firstOrNull => rows.isEmpty ? null : rows.first;
}

/// Contrato usado pelos repositórios. Implementações devem traduzir erros do
/// PostgREST para [AppException] nos repositórios (não aqui).
abstract class GabariteiDatabase {
  DbTable from(String table);

  Future<List<Map<String, dynamic>>> rpc(
    String function, {
    Map<String, dynamic>? params,
  });

  /// URL pública de um objeto do Storage (bucket público `imagens_questoes`).
  String publicStorageUrl(String bucket, String path);
}

/// Construtor de consulta encadeável.
///
/// Uso típico:
/// ```dart
/// final result = await db
///     .from('historico_respostas')
///     .select('criado_em, is_correct', countExact: true)
///     .eq('id_usuario', userId)
///     .order('criado_em', ascending: false)
///     .range(0, 49)
///     .get();
/// ```
abstract class DbTable {
  DbTable select(String columns, {bool countExact = false});

  DbTable eq(String column, Object value);
  DbTable neq(String column, Object value);
  DbTable gt(String column, Object value);
  DbTable gte(String column, Object value);
  DbTable lt(String column, Object value);
  DbTable lte(String column, Object value);
  DbTable inList(String column, List<dynamic> values);
  DbTable notInList(String column, List<dynamic> values);
  DbTable isNull(String column);
  DbTable isNotNull(String column);
  DbTable ilike(String column, String pattern);
  DbTable or(String filters);

  DbTable order(String column, {bool ascending = true});
  DbTable limit(int count);
  DbTable range(int from, int to);

  /// Executa a consulta montada com [select].
  Future<DbResult> get();

  Future<Map<String, dynamic>?> maybeSingle();
  Future<Map<String, dynamic>> single();

  /// Insere e devolve as linhas (usa `Prefer: return=representation`).
  Future<List<Map<String, dynamic>>> insert(Object values);

  /// Insere sem `RETURNING` — necessário em tabelas sem policy de SELECT
  /// (ex.: fila de denúncias).
  Future<void> insertMinimal(Object values);

  /// Prepara um `UPDATE`. Aplique os filtros (`eq`, `isNull`, ...) e finalize
  /// com [execute], que devolve as linhas atualizadas.
  DbTable update(Map<String, dynamic> values);

  /// Prepara um `DELETE`. Aplique os filtros e finalize com [execute].
  DbTable delete();

  /// Executa o `UPDATE`/`DELETE` preparado. Não use em consultas `select`.
  Future<List<Map<String, dynamic>>> execute();
}
