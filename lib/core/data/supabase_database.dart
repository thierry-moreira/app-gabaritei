import 'package:supabase_flutter/supabase_flutter.dart';

import 'database.dart';

/// Implementação real sobre o PostgREST do Supabase.
///
/// Os filtros são aplicados imediatamente no builder; ordenação, limite e
/// paginação são guardados e aplicados só na execução — assim nenhum filtro é
/// perdido quando a cadeia muda para `PostgrestTransformBuilder`.
class SupabaseDatabase implements GabariteiDatabase {
  SupabaseDatabase(this.client);

  final SupabaseClient client;

  @override
  DbTable from(String table) => _SupabaseTable(client.from(table));

  @override
  Future<List<Map<String, dynamic>>> rpc(
    String function, {
    Map<String, dynamic>? params,
  }) async {
    final data = await client.rpc(function, params: params);
    return rowsOf(data);
  }

  @override
  String publicStorageUrl(String bucket, String path) =>
      client.storage.from(bucket).getPublicUrl(path);
}

class _SupabaseTable implements DbTable {
  _SupabaseTable(this._query);

  final PostgrestQueryBuilder<dynamic> _query;

  PostgrestFilterBuilder<dynamic>? _filter;
  bool _countExact = false;
  bool _isMutation = false;
  bool _isDelete = false;
  final List<({String column, bool ascending})> _orders = [];
  int? _limitValue;
  ({int from, int to})? _rangeValue;

  PostgrestFilterBuilder<dynamic> get _filters {
    final filter = _filter;
    if (filter == null) {
      throw StateError('Chame select(), update() ou delete() antes.');
    }
    return filter;
  }

  void _ensureBuilder() {
    if (_filter == null) {
      throw StateError('Chame select() antes de aplicar filtros.');
    }
  }

  @override
  DbTable select(String columns, {bool countExact = false}) {
    _filter = _query.select(columns);
    _countExact = countExact;
    return this;
  }

  @override
  DbTable eq(String column, Object value) {
    _ensureBuilder();
    _filter = _filters.eq(column, value);
    return this;
  }

  @override
  DbTable neq(String column, Object value) {
    _ensureBuilder();
    _filter = _filters.neq(column, value);
    return this;
  }

  @override
  DbTable gt(String column, Object value) {
    _ensureBuilder();
    _filter = _filters.gt(column, value);
    return this;
  }

  @override
  DbTable gte(String column, Object value) {
    _ensureBuilder();
    _filter = _filters.gte(column, value);
    return this;
  }

  @override
  DbTable lt(String column, Object value) {
    _ensureBuilder();
    _filter = _filters.lt(column, value);
    return this;
  }

  @override
  DbTable lte(String column, Object value) {
    _ensureBuilder();
    _filter = _filters.lte(column, value);
    return this;
  }

  @override
  DbTable inList(String column, List<dynamic> values) {
    _ensureBuilder();
    _filter = _filters.inFilter(column, values);
    return this;
  }

  @override
  DbTable notInList(String column, List<dynamic> values) {
    _ensureBuilder();
    _filter = _filters.not(column, 'in', values);
    return this;
  }

  @override
  DbTable isNull(String column) {
    _ensureBuilder();
    _filter = _filters.isFilter(column, null);
    return this;
  }

  @override
  DbTable isNotNull(String column) {
    _ensureBuilder();
    _filter = _filters.not(column, 'is', null);
    return this;
  }

  @override
  DbTable ilike(String column, String pattern) {
    _ensureBuilder();
    _filter = _filters.ilike(column, pattern);
    return this;
  }

  @override
  DbTable or(String filters) {
    _ensureBuilder();
    _filter = _filters.or(filters);
    return this;
  }

  @override
  DbTable order(String column, {bool ascending = true}) {
    _orders.add((column: column, ascending: ascending));
    return this;
  }

  @override
  DbTable limit(int count) {
    _limitValue = count;
    return this;
  }

  @override
  DbTable range(int from, int to) {
    _rangeValue = (from: from, to: to);
    return this;
  }

  PostgrestTransformBuilder<dynamic> _transformed() {
    PostgrestTransformBuilder<dynamic> builder = _filters;
    for (final order in _orders) {
      builder = builder.order(order.column, ascending: order.ascending);
    }
    final limit = _limitValue;
    if (limit != null) builder = builder.limit(limit);
    final range = _rangeValue;
    if (range != null) builder = builder.range(range.from, range.to);
    return builder;
  }

  @override
  Future<DbResult> get() async {
    final builder = _transformed();
    if (_countExact) {
      final response = await builder.count(CountOption.exact);
      return DbResult(rowsOf(response.data), count: response.count);
    }
    final data = await builder;
    return DbResult(rowsOf(data));
  }

  @override
  Future<Map<String, dynamic>?> maybeSingle() async {
    final data = await _transformed().maybeSingle();
    return mapOf(data);
  }

  @override
  Future<Map<String, dynamic>> single() async {
    final data = await _transformed().single();
    final map = mapOf(data);
    if (map == null) {
      throw StateError('Registro não encontrado.');
    }
    return map;
  }

  @override
  Future<List<Map<String, dynamic>>> insert(Object values) async {
    final data = await _query.insert(values).select();
    return rowsOf(data);
  }

  @override
  Future<void> insertMinimal(Object values) async {
    await _query.insert(values);
  }

  @override
  DbTable update(Map<String, dynamic> values) {
    if (_filter != null) {
      throw StateError('Esta consulta já foi iniciada.');
    }
    _filter = _query.update(values);
    _isMutation = true;
    return this;
  }

  @override
  DbTable delete() {
    if (_filter != null) {
      throw StateError('Esta consulta já foi iniciada.');
    }
    _filter = _query.delete();
    _isMutation = true;
    _isDelete = true;
    return this;
  }

  @override
  Future<List<Map<String, dynamic>>> execute() async {
    if (!_isMutation) {
      throw StateError('execute() só vale para update() ou delete().');
    }
    final builder = _filters;
    if (_isDelete) {
      await builder;
      return const [];
    }
    return rowsOf(await builder.select());
  }
}

List<Map<String, dynamic>> rowsOf(Object? data) {
  if (data is List) {
    return data
        .whereType<Map>()
        .map((row) => row.map((key, value) => MapEntry(key.toString(), value)))
        .toList(growable: false);
  }
  if (data is Map) {
    return [
      data.map((key, value) => MapEntry(key.toString(), value)),
    ];
  }
  return const [];
}

Map<String, dynamic>? mapOf(Object? data) {
  if (data is Map) {
    return data.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}
