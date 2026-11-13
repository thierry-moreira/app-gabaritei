import '../core/data/database.dart';
import '../core/data/repository_helpers.dart';
import '../core/utils/slug.dart';
import '../models/taxonomy.dart';

/// Catálogo de taxonomia usado por filtros, cadernos, editais e simulados.
class TaxonomyRepository {
  TaxonomyRepository({required this._db});

  final GabariteiDatabase _db;

  /// Mesmo intervalo do backend: 2026 até 2000, do mais recente ao mais antigo.
  static List<int> get anosDisponiveis =>
      [for (var ano = 2026; ano >= 2000; ano--) ano];

  Future<TaxonomyCatalog> carregarCatalogo() {
    return mapDatabaseErrors(() async {
      final respostas = await Future.wait([
        _db.from('materias').select('*').order('nome_materia').get(),
        _db.from('topicos').select('*').order('nome_topico').get(),
        _db.from('subtopicos').select('*').order('nome_subtopico').get(),
        _db.from('bancas').select('*').order('nome_banca').get(),
        _db.from('orgaos').select('*').order('nome_orgao').get(),
        _db.from('cargos').select('*').order('nome_cargo').get(),
        _db.from('niveis_escolaridade').select('*').order('id_nivel').get(),
      ]);

      final materias = respostas[0].rows.map(Materia.fromMap).toList();
      final topicos = respostas[1].rows.map(Topico.fromMap).toList();
      final subtopicos = respostas[2].rows.map(Subtopico.fromMap).toList();
      final bancas = respostas[3].rows.map(Banca.fromMap).toList();
      final cargos = respostas[5].rows.map(Cargo.fromMap).toList();
      final orgaos = respostas[4].rows.map((linha) {
        final orgao = Orgao.fromMap(linha);
        return orgao.copyWith(
          cargos: cargos
              .where((cargo) => cargo.idOrgao == orgao.id)
              .toList(growable: false),
        );
      }).toList(growable: false);
      final niveis = respostas[6].rows.map(NivelEscolaridade.fromMap).toList();

      return TaxonomyCatalog(
        materias: materias,
        topicos: topicos,
        subtopicos: subtopicos,
        bancas: bancas,
        orgaos: orgaos,
        niveis: niveis,
      );
    });
  }

  Future<List<Topico>> topicosDaMateria(int idMateria) {
    return mapDatabaseErrors(() async {
      final resultado = await _db
          .from('topicos')
          .select('*')
          .eq('id_materia', idMateria)
          .order('nome_topico')
          .get();
      return resultado.rows.map(Topico.fromMap).toList(growable: false);
    });
  }

  Future<List<Subtopico>> subtopicosDoTopico(int idTopico) {
    return mapDatabaseErrors(() async {
      final resultado = await _db
          .from('subtopicos')
          .select('*')
          .eq('id_topico', idTopico)
          .order('nome_subtopico')
          .get();
      return resultado.rows.map(Subtopico.fromMap).toList(growable: false);
    });
  }

  Future<Materia?> materiaPorSlug(String slug, {TaxonomyCatalog? catalogo}) async {
    final fonte = catalogo ?? await carregarCatalogo();
    return _buscarMateria(fonte, slug);
  }

  static Materia? _buscarMateria(TaxonomyCatalog catalogo, String slug) {
    for (final materia in catalogo.materias) {
      if (slugify(materia.nome) == slug) return materia;
    }
    return null;
  }

  Future<Topico?> topicoPorSlug(
    int idMateria,
    String slug, {
    TaxonomyCatalog? catalogo,
  }) async {
    final fonte = catalogo ?? await carregarCatalogo();
    for (final topico in fonte.topicosDaMateria(idMateria)) {
      if (slugify(topico.nome) == slug) return topico;
    }
    return null;
  }

  /// Template de prompt específico da matéria (fallback: o genérico da IA).
  Future<String?> promptMateria(int idMateria) {
    return mapDatabaseErrors(() async {
      final linha = await _db
          .from('prompts_materias')
          .select('template_prompt')
          .eq('id_materia', idMateria)
          .limit(1)
          .maybeSingle();
      final template = linha?['template_prompt']?.toString();
      return template == null || template.trim().isEmpty ? null : template;
    });
  }
}
