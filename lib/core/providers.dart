import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/question.dart';
import '../models/edital.dart';
import '../models/stats.dart';
import '../models/study.dart';
import '../models/simulado.dart';
import '../models/taxonomy.dart';
import '../models/user_profile.dart';
import '../repositories/auth_repository.dart';
import '../repositories/caderno_repository.dart';
import '../repositories/dashboard_repository.dart';
import '../repositories/edital_repository.dart';
import '../repositories/filtro_repository.dart';
import '../repositories/flashcard_repository.dart';
import '../repositories/ia_config_store.dart';
import '../repositories/question_repository.dart';
import '../repositories/resumo_repository.dart';
import '../repositories/simulado_repository.dart';
import '../repositories/study_ai_repository.dart';
import '../repositories/taxonomy_repository.dart';
import '../repositories/user_repository.dart';
import '../services/filter_service.dart';
import '../services/ai_provider_service.dart';
import '../services/resumo_print_service.dart';
import '../services/simulado_print_service.dart';
import 'auth/auth_gateway.dart';
import 'data/database.dart';
import 'data/global_write_gateway.dart';
import 'data/supabase_database.dart';

/// Cliente Supabase criado em `main()` com `Supabase.initialize`.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

/// Implementação real do PostgREST usada por todos os repositórios.
final databaseProvider = Provider<GabariteiDatabase>(
  (ref) => SupabaseDatabase(ref.watch(supabaseClientProvider)),
);

/// Escritas de dados globais passam pela Edge Function autenticada.
final globalWriteGatewayProvider = Provider<GlobalWriteGateway>(
  (ref) => SupabaseGlobalWriteGateway(ref.watch(supabaseClientProvider)),
);

final authGatewayProvider = Provider<AuthGateway>(
  (ref) => SupabaseAuthGateway(ref.watch(supabaseClientProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    auth: ref.watch(authGatewayProvider),
    db: ref.watch(databaseProvider),
  ),
);

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(db: ref.watch(databaseProvider)),
);

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(db: ref.watch(databaseProvider)),
);

final questionRepositoryProvider = Provider<QuestionRepository>(
  (ref) => QuestionRepository(
    db: ref.watch(databaseProvider),
    globalWrites: ref.watch(globalWriteGatewayProvider),
  ),
);

final cadernoRepositoryProvider = Provider<CadernoRepository>(
  (ref) => CadernoRepository(db: ref.watch(databaseProvider)),
);

final filtroRepositoryProvider = Provider<FiltroRepository>(
  (ref) => FiltroRepository(db: ref.watch(databaseProvider)),
);

final flashcardRepositoryProvider = Provider<FlashcardRepository>(
  (ref) => FlashcardRepository(db: ref.watch(databaseProvider)),
);

final resumoRepositoryProvider = Provider<ResumoRepository>(
  (ref) => ResumoRepository(db: ref.watch(databaseProvider)),
);

final resumoPrintServiceProvider = Provider<ResumoPrintService>(
  (ref) => ResumoPrintService(),
);

final simuladoRepositoryProvider = Provider<SimuladoRepository>(
  (ref) => SimuladoRepository(db: ref.watch(databaseProvider)),
);

final simuladoPrintServiceProvider = Provider<SimuladoPrintService>(
  (ref) => SimuladoPrintService(),
);

final simuladosProvider = FutureProvider.autoDispose<SimuladoListagem>((
  ref,
) async {
  final perfil = await ref.watch(perfilAtualProvider.future);
  if (perfil == null) {
    throw StateError('Perfil não encontrado para a conta logada.');
  }
  return ref.watch(simuladoRepositoryProvider).listar(idUsuario: perfil.id);
});

final simuladoSessaoProvider = FutureProvider.autoDispose
    .family<SimuladoComQuestoes, String>((ref, idSimulado) async {
      final perfil = await ref.watch(perfilAtualProvider.future);
      if (perfil == null) {
        throw StateError('Perfil não encontrado para a conta logada.');
      }
      return ref
          .watch(simuladoRepositoryProvider)
          .sessao(idSimulado: idSimulado, idUsuario: perfil.id);
    });

final simuladoRankingProvider = FutureProvider.autoDispose
    .family<SimuladoRankingDados, String>((ref, idSimulado) async {
      final perfil = await ref.watch(perfilAtualProvider.future);
      if (perfil == null) {
        throw StateError('Perfil não encontrado para a conta logada.');
      }
      final repo = ref.watch(simuladoRepositoryProvider);
      final simulado = await repo.buscar(
        idSimulado: idSimulado,
        idUsuario: perfil.id,
      );
      final ranking = await repo.ranking(
        idSimulado: idSimulado,
        idUsuario: perfil.id,
      );
      return SimuladoRankingDados(simulado: simulado, ranking: ranking);
    });

final taxonomyRepositoryProvider = Provider<TaxonomyRepository>(
  (ref) => TaxonomyRepository(db: ref.watch(databaseProvider)),
);

final editalRepositoryProvider = Provider<EditalRepository>(
  (ref) => EditalRepository(db: ref.watch(databaseProvider)),
);

final editaisProvider = FutureProvider.autoDispose<List<EditalCiclo>>((
  ref,
) async {
  final perfil = await ref.watch(perfilAtualProvider.future);
  if (perfil == null) {
    throw StateError('Perfil não encontrado para a conta logada.');
  }
  return ref.watch(editalRepositoryProvider).listar(perfil.id);
});

final editalPainelProvider = FutureProvider.autoDispose
    .family<EditalPainel, int>((ref, idEdital) async {
      final perfil = await ref.watch(perfilAtualProvider.future);
      if (perfil == null) {
        throw StateError('Perfil não encontrado para a conta logada.');
      }
      return ref
          .watch(editalRepositoryProvider)
          .dashboard(idEdital: idEdital, idUsuario: perfil.id);
    });

final editalSessaoProvider = FutureProvider.autoDispose
    .family<EditalSessaoEstudo, int>((ref, idEdital) async {
      final perfil = await ref.watch(perfilAtualProvider.future);
      if (perfil == null) {
        throw StateError('Perfil não encontrado para a conta logada.');
      }
      return ref
          .watch(editalRepositoryProvider)
          .estudar(idEdital: idEdital, idUsuario: perfil.id);
    });

final iaConfigStoreProvider = Provider<IaConfigStore>(
  (ref) => IaConfigStore(storage: FlutterSecureKeyValueStore()),
);

final aiProviderServiceProvider = Provider<AiProviderService>(
  (ref) => AiProviderService(),
);

final studyAiRepositoryProvider = Provider<StudyAiRepository>(
  (ref) => StudyAiRepository(
    db: ref.watch(databaseProvider),
    store: ref.watch(iaConfigStoreProvider),
    globalWrites: ref.watch(globalWriteGatewayProvider),
  ),
);

/// Perfil do aluno logado (`usuarios` vinculado ao `auth.uid()`).
///
/// Retorna `null` quando não há sessão ou quando a conta ainda não tem linha
/// em `usuarios`.
final perfilAtualProvider = FutureProvider<UserProfile?>(
  (ref) => ref.watch(authRepositoryProvider).perfilAtual(),
);

/// Resumo do painel inicial calculado a partir de `historico_respostas`.
final painelProvider = FutureProvider<DashboardResumo>((ref) async {
  final perfil = await ref.watch(perfilAtualProvider.future);
  if (perfil == null) {
    throw StateError('Perfil não encontrado para a conta logada.');
  }
  return ref.watch(dashboardRepositoryProvider).painel(idUsuario: perfil.id);
});

/// Estatísticas detalhadas (raio-x) do aluno logado.
final estatisticasDetalhadasProvider = FutureProvider<DashboardDetalhado>((
  ref,
) async {
  final perfil = await ref.watch(perfilAtualProvider.future);
  if (perfil == null) {
    throw StateError('Perfil não encontrado para a conta logada.');
  }
  return ref
      .watch(dashboardRepositoryProvider)
      .estatisticasDetalhadas(idUsuario: perfil.id);
});

/// Catálogo de matérias, bancas e anos usado pelos filtros de questões.
final taxonomyCatalogProvider = FutureProvider<TaxonomyCatalog>(
  (ref) => ref.watch(taxonomyRepositoryProvider).carregarCatalogo(),
);

/// Total de questões publicadas exibido no topo da tela de questões.
final totalQuestoesProvider = FutureProvider<int>(
  (ref) => ref.watch(questionRepositoryProvider).contarPublicadas(),
);

/// Filtros ativos da tela de questões.
class QuestoesFiltrosNotifier extends Notifier<QuestaoFiltros> {
  @override
  QuestaoFiltros build() => const QuestaoFiltros();

  void atualizar(QuestaoFiltros filtros) => state = filtros;

  void limpar() => state = const QuestaoFiltros();

  void irParaPagina(int pagina) => state = state.copyWith(pagina: pagina);
}

final questoesFiltrosProvider =
    NotifierProvider<QuestoesFiltrosNotifier, QuestaoFiltros>(
      QuestoesFiltrosNotifier.new,
    );

/// Índice da questão atual, mantido enquanto o aluno navega entre telas.
/// A tela de questões recria seu widget ao trocar de rota, mas o progresso na
/// página do filtro deve continuar de onde o aluno parou.
class QuestoesIndiceNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void definir(int indice) => state = indice < 0 ? 0 : indice;

  void resetar() => state = 0;
}

final questoesIndiceProvider = NotifierProvider<QuestoesIndiceNotifier, int>(
  QuestoesIndiceNotifier.new,
);

/// Página de questões correspondente aos filtros ativos.
final questoesPaginaProvider = FutureProvider<PaginaQuestoes>((ref) async {
  final filtros = ref.watch(questoesFiltrosProvider);
  final perfil = await ref.watch(perfilAtualProvider.future);
  if (perfil == null) {
    throw StateError('Perfil não encontrado para a conta logada.');
  }
  return ref
      .watch(questionRepositoryProvider)
      .listar(filtros, idUsuario: perfil.id);
});

/// Filtros salvos pelo aluno.
final filtrosSalvosProvider = FutureProvider<List<FiltroSalvo>>((ref) async {
  final perfil = await ref.watch(perfilAtualProvider.future);
  if (perfil == null) return const [];
  return ref.watch(filtroRepositoryProvider).listar(perfil.id);
});

/// Cadernos de questões do aluno logado.
final cadernosProvider = FutureProvider<List<Caderno>>((ref) async {
  final perfil = await ref.watch(perfilAtualProvider.future);
  if (perfil == null) return const [];
  return ref.watch(cadernoRepositoryProvider).listar(perfil.id);
});

/// Detalhe de um caderno com as questões hidratadas e o histórico do aluno.
///
/// É `autoDispose` para que, ao reabrir o caderno, o detalhe seja recarregado
/// e reflita questões salvas/removidas em outras telas.
final cadernoDetalheProvider = FutureProvider.autoDispose
    .family<CadernoDetalhe, String>((ref, idCaderno) async {
      final perfil = await ref.watch(perfilAtualProvider.future);
      if (perfil == null) {
        throw StateError('Perfil não encontrado para a conta logada.');
      }
      return ref
          .watch(cadernoRepositoryProvider)
          .detalhe(idCaderno: idCaderno, idUsuario: perfil.id);
    });

/// Categorias e revisões vencidas exibidas no painel de flashcards.
final flashcardsDashboardProvider =
    FutureProvider.autoDispose<FlashcardsDashboardData>((ref) async {
      final perfil = await ref.watch(perfilAtualProvider.future);
      if (perfil == null) {
        throw StateError('Perfil não encontrado para a conta logada.');
      }

      final repo = ref.watch(flashcardRepositoryProvider);
      final resultados = await Future.wait<Object>([
        repo.listarCategorias(perfil.id.toString()),
        repo.contarParaRevisar(perfil.id.toString()),
      ]);
      return FlashcardsDashboardData(
        categorias: resultados[0] as List<FlashcardCategoria>,
        paraRevisarHoje: resultados[1] as int,
      );
    });

/// Cards de gerenciamento de uma categoria que pertence ao aluno atual.
final flashcardCategoriaDetalheProvider = FutureProvider.autoDispose
    .family<FlashcardCategoriaDetalhe?, String>((ref, idCategoria) async {
      final perfil = await ref.watch(perfilAtualProvider.future);
      if (perfil == null) {
        throw StateError('Perfil não encontrado para a conta logada.');
      }

      final repo = ref.watch(flashcardRepositoryProvider);
      final categorias = await repo.listarCategorias(perfil.id.toString());
      FlashcardCategoria? categoria;
      for (final item in categorias) {
        if (item.id == idCategoria) {
          categoria = item;
          break;
        }
      }
      if (categoria == null) return null;

      final cards = await repo.listarCards(
        idUsuario: perfil.id.toString(),
        idCategoria: idCategoria,
      );
      return FlashcardCategoriaDetalhe(categoria: categoria, cards: cards);
    });

/// Fila vencida da sessão global (`todos`) ou de uma categoria específica.
final flashcardsParaRevisarProvider = FutureProvider.autoDispose
    .family<List<Flashcard>, String>((ref, idCategoria) async {
      final perfil = await ref.watch(perfilAtualProvider.future);
      if (perfil == null) {
        throw StateError('Perfil não encontrado para a conta logada.');
      }
      return ref
          .watch(flashcardRepositoryProvider)
          .cardsParaRevisar(
            idUsuario: perfil.id.toString(),
            idCategoria: idCategoria == 'todos' ? null : idCategoria,
          );
    });

/// Cadernos de resumo agrupados por matéria.
final resumosPorMateriaProvider =
    FutureProvider.autoDispose<List<ResumosPorMateria>>((ref) async {
      final perfil = await ref.watch(perfilAtualProvider.future);
      if (perfil == null) {
        throw StateError('Perfil não encontrado para a conta logada.');
      }
      return ref
          .watch(resumoRepositoryProvider)
          .listarPorMateria(perfil.id.toString());
    });

/// Matéria do aluno e seus resumos ordenados para leitura/impressão.
final resumoMateriaDetalheProvider = FutureProvider.autoDispose
    .family<ResumoMateriaDetalhe?, int>((ref, idMateria) async {
      final perfil = await ref.watch(perfilAtualProvider.future);
      if (perfil == null) {
        throw StateError('Perfil não encontrado para a conta logada.');
      }
      final repo = ref.watch(resumoRepositoryProvider);
      final materias = await repo.listarPorMateria(perfil.id.toString());
      ResumosPorMateria? materia;
      for (final item in materias) {
        if (item.idMateria == idMateria) {
          materia = item;
          break;
        }
      }
      materia ??= await repo.buscarMateria(idMateria);
      if (materia == null) return null;
      final resumos = await repo.listarDaMateria(
        idUsuario: perfil.id.toString(),
        idMateria: idMateria,
      );
      return ResumoMateriaDetalhe(materia: materia, resumos: resumos);
    });
