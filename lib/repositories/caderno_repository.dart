import '../core/data/database.dart';
import '../core/data/repository_helpers.dart';
import '../core/errors/app_exception.dart';
import '../models/study.dart';
import 'question_repository.dart';

/// Cadernos de questões do aluno (`rotas/caderno.py`).
class CadernoRepository {
  CadernoRepository({required this._db, QuestionRepository? questoes}) {
    _questoes = questoes ?? QuestionRepository(db: _db);
  }

  final GabariteiDatabase _db;
  late final QuestionRepository _questoes;

  Future<List<Caderno>> listar(int idUsuario) {
    return mapDatabaseErrors(() async {
      final resultado = await _db
          .from('cadernos')
          .select('*')
          .eq('id_usuario', idUsuario)
          .order('criado_em', ascending: false)
          .get();
      return resultado.rows.map(Caderno.fromMap).toList(growable: false);
    });
  }

  Future<Caderno> criar({
    required int idUsuario,
    required String nome,
  }) {
    final nomeLimpo = nome.trim();
    if (nomeLimpo.isEmpty) {
      throw ValidationException('Informe o nome do caderno.');
    }

    return mapDatabaseErrors(() async {
      final linhas = await _db.from('cadernos').insert({
        'id_usuario': idUsuario,
        'nome_caderno': nomeLimpo,
      });
      if (linhas.isEmpty) {
        throw AppException('Não foi possível criar o caderno.');
      }
      return Caderno.fromMap(linhas.first);
    });
  }

  Future<void> excluir({
    required String idCaderno,
    required int idUsuario,
  }) {
    if (idCaderno.trim().isEmpty) {
      throw ValidationException('Caderno inválido.');
    }
    return mapDatabaseErrors(
      () => _db
          .from('cadernos')
          .delete()
          .eq('id_caderno', idCaderno)
          .eq('id_usuario', idUsuario)
          .execute(),
    );
  }

  Future<void> salvarQuestao({
    required String idCaderno,
    required int idUsuario,
    required int idQuestao,
  }) {
    if (idCaderno.trim().isEmpty || idQuestao <= 0) {
      throw ValidationException('Dados incompletos.');
    }

    return mapDatabaseErrors(() async {
      final caderno = await _db
          .from('cadernos')
          .select('id_caderno')
          .eq('id_caderno', idCaderno)
          .eq('id_usuario', idUsuario)
          .limit(1)
          .maybeSingle();
      if (caderno == null) {
        throw NotFoundException('Caderno não encontrado.');
      }

      try {
        await _db.from('caderno_questoes').insertMinimal({
          'id_caderno': idCaderno,
          'id_questao': idQuestao,
          'id_usuario': idUsuario,
        });
      } on AppException catch (error) {
        final detalhe = '${error.code ?? ''} ${error.message}'.toLowerCase();
        if (error.code == '23505' ||
            detalhe.contains('duplicate key') ||
            detalhe.contains('caderno_questoes_pkey')) {
          throw ConflictException('Esta questão já está neste caderno.');
        }
        if (detalhe.contains('id_questao') || detalhe.contains('questao')) {
          throw ValidationException('Questão não encontrada.');
        }
        if (error.code == '23503' ||
            detalhe.contains('id_caderno') ||
            detalhe.contains('caderno_questoes')) {
          throw NotFoundException('Caderno não encontrado.');
        }
        rethrow;
      }
    });
  }

  Future<void> removerQuestao({
    required String idCaderno,
    required int idUsuario,
    required int idQuestao,
  }) {
    if (idCaderno.trim().isEmpty || idQuestao <= 0) {
      throw ValidationException('Dados incompletos.');
    }
    return mapDatabaseErrors(
      () => _db
          .from('caderno_questoes')
          .delete()
          .eq('id_caderno', idCaderno)
          .eq('id_questao', idQuestao)
          .eq('id_usuario', idUsuario)
          .execute(),
    );
  }

  Future<CadernoDetalhe> detalhe({
    required String idCaderno,
    required int idUsuario,
  }) {
    if (idCaderno.trim().isEmpty) {
      throw ValidationException('Caderno inválido.');
    }

    return mapDatabaseErrors(() async {
      final linhaCaderno = await _db
          .from('cadernos')
          .select('*')
          .eq('id_caderno', idCaderno)
          .eq('id_usuario', idUsuario)
          .limit(1)
          .maybeSingle();
      if (linhaCaderno == null) {
        throw NotFoundException('Caderno não encontrado.');
      }

      final idsResultado = await _db
          .from('caderno_questoes')
          .select('id_questao')
          .eq('id_caderno', idCaderno)
          .eq('id_usuario', idUsuario)
          .order('id_questao')
          .get();
      final ids = <int>[];
      for (final linha in idsResultado.rows) {
        final id = linha['id_questao'];
        final parsed = id is int ? id : int.tryParse(id?.toString() ?? '');
        if (parsed != null) ids.add(parsed);
      }

      if (ids.isEmpty) {
        return CadernoDetalhe(
          caderno: Caderno.fromMap(linhaCaderno),
          questoes: const [],
        );
      }

      final questoes = await _questoes.carregarPorIds(ids);
      final acertos = <int>{};
      final erros = <int>{};

      final historico = await _db
          .from('historico_respostas')
          .select('id_questao, is_correct')
          .eq('id_usuario', idUsuario.toString())
          .inList('id_questao', ids)
          .get();
      for (final linha in historico.rows) {
        final id = linha['id_questao'];
        final parsed = id is int ? id : int.tryParse(id?.toString() ?? '');
        if (parsed == null) continue;
        if (linha['is_correct'] == true) {
          acertos.add(parsed);
        } else {
          erros.add(parsed);
        }
      }

      return CadernoDetalhe(
        caderno: Caderno.fromMap(linhaCaderno),
        questoes: questoes,
        idsAcertos: acertos,
        idsErros: erros,
      );
    });
  }
}
