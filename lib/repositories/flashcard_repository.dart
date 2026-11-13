import '../core/data/database.dart';
import '../core/data/repository_helpers.dart';
import '../core/errors/app_exception.dart';
import '../models/study.dart';
import '../services/sm2_service.dart';

/// Flashcards e categorias (`rotas/flashcards.py`).
class FlashcardRepository {
  FlashcardRepository({required this._db});

  final GabariteiDatabase _db;

  Future<List<FlashcardCategoria>> listarCategorias(String idUsuario) {
    return mapDatabaseErrors(() async {
      final resultado = await _db
          .from('flashcard_categorias')
          .select('*, materias(nome_materia)')
          .eq('id_usuario', idUsuario)
          .order('nome_categoria')
          .get();
      return resultado.rows
          .map(FlashcardCategoria.fromMap)
          .toList(growable: false);
    });
  }

  Future<FlashcardCategoria> criarCategoria({
    required String idUsuario,
    required String nome,
    int? idMateria,
  }) {
    final nomeLimpo = nome.trim();
    if (nomeLimpo.isEmpty) {
      throw ValidationException('Nome da categoria é obrigatório.');
    }

    return mapDatabaseErrors(() async {
      final linhas = await _db.from('flashcard_categorias').insert({
        'id_usuario': idUsuario,
        'nome_categoria': nomeLimpo,
        'id_materia': ?idMateria,
      });
      if (linhas.isEmpty) {
        throw AppException('Não foi possível criar a categoria.');
      }
      return FlashcardCategoria.fromMap(linhas.first);
    });
  }

  Future<void> excluirCategoria({
    required String idCategoria,
    required String idUsuario,
  }) {
    if (idCategoria.trim().isEmpty) {
      throw ValidationException('Categoria inválida.');
    }
    return mapDatabaseErrors(
      () => _db
          .from('flashcard_categorias')
          .delete()
          .eq('id_categoria', idCategoria)
          .eq('id_usuario', idUsuario)
          .execute(),
    );
  }

  Future<List<Flashcard>> listarCards({
    required String idUsuario,
    String? idCategoria,
  }) {
    return mapDatabaseErrors(() async {
      var consulta = _db
          .from('flashcards')
          .select('*')
          .eq('id_usuario', idUsuario);
      if (idCategoria != null && idCategoria.isNotEmpty) {
        consulta = consulta.eq('id_categoria', idCategoria);
      }
      final resultado = await consulta
          .order('criado_em', ascending: false)
          .get();
      return resultado.rows.map(Flashcard.fromMap).toList(growable: false);
    });
  }

  Future<int> contarParaRevisar(
    String idUsuario, {
    DateTime? agora,
  }) {
    final instante = (agora ?? DateTime.now()).toUtc().toIso8601String();
    return mapDatabaseErrors(() async {
      final resultado = await _db
          .from('flashcards')
          .select('id_flashcard', countExact: true)
          .eq('id_usuario', idUsuario)
          .lte('proxima_revisao', instante)
          .get();
      return resultado.count ?? resultado.rows.length;
    });
  }

  Future<List<Flashcard>> cardsParaRevisar({
    required String idUsuario,
    String? idCategoria,
    DateTime? agora,
  }) {
    final instante = (agora ?? DateTime.now()).toUtc().toIso8601String();
    return mapDatabaseErrors(() async {
      var consulta = _db
          .from('flashcards')
          .select('*')
          .eq('id_usuario', idUsuario)
          .lte('proxima_revisao', instante);
      if (idCategoria != null && idCategoria.isNotEmpty) {
        consulta = consulta.eq('id_categoria', idCategoria);
      }
      final resultado = await consulta.order('proxima_revisao').get();
      return resultado.rows.map(Flashcard.fromMap).toList(growable: false);
    });
  }

  Future<Flashcard> criar({
    required String idUsuario,
    required String frente,
    required String verso,
    String? idCategoria,
    int? idQuestao,
    DateTime? agora,
  }) {
    final frenteLimpa = frente.trim();
    final versoLimpo = verso.trim();
    if (frenteLimpa.isEmpty || versoLimpo.isEmpty) {
      throw ValidationException('Campos obrigatórios.');
    }

    return mapDatabaseErrors(() async {
      final linhas = await _db.from('flashcards').insert({
        'id_usuario': idUsuario,
        'id_categoria': ?idCategoria,
        'frente': frenteLimpa,
        'verso': versoLimpo,
        'id_questao': ?idQuestao,
        'proxima_revisao': (agora ?? DateTime.now()).toUtc().toIso8601String(),
      });
      if (linhas.isEmpty) {
        throw AppException('Não foi possível criar o flashcard.');
      }
      return Flashcard.fromMap(linhas.first);
    });
  }

  /// Aplica SM-2 e persiste o novo intervalo/facilidade.
  Future<Sm2Result> revisar({
    required String idUsuario,
    required String idFlashcard,
    required int qualidade,
    DateTime? agora,
  }) {
    if (idFlashcard.trim().isEmpty) {
      throw ValidationException('Flashcard não informado.');
    }
    if (qualidade < 0 || qualidade > 3) {
      throw ValidationException('Qualidade inválida.');
    }

    return mapDatabaseErrors(() async {
      final linha = await _db
          .from('flashcards')
          .select('*')
          .eq('id_flashcard', idFlashcard)
          .eq('id_usuario', idUsuario)
          .limit(1)
          .maybeSingle();
      if (linha == null) {
        throw NotFoundException('Flashcard não encontrado.');
      }

      final card = Flashcard.fromMap(linha);
      final resultado = Sm2Service.revisar(
        intervaloAtual: card.intervalo,
        facilidadeAtual: card.facilidade,
        qualidade: qualidade,
        agora: agora,
      );

      final atualizados = await _db
          .from('flashcards')
          .update({
            'intervalo': resultado.intervalo,
            'facilidade': resultado.facilidade,
            'proxima_revisao': resultado.proximaRevisao
                .toUtc()
                .toIso8601String(),
          })
          .eq('id_flashcard', idFlashcard)
          .eq('id_usuario', idUsuario)
          .execute();
      if (atualizados.isEmpty) {
        throw NotFoundException('Flashcard não encontrado.');
      }
      return resultado;
    });
  }

  Future<void> excluir({
    required String idFlashcard,
    required String idUsuario,
  }) {
    if (idFlashcard.trim().isEmpty) {
      throw ValidationException('Flashcard inválido.');
    }
    return mapDatabaseErrors(
      () => _db
          .from('flashcards')
          .delete()
          .eq('id_flashcard', idFlashcard)
          .eq('id_usuario', idUsuario)
          .execute(),
    );
  }
}
