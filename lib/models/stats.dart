import 'question.dart';
import 'study.dart';

class DiaAtividade {
  const DiaAtividade({
    required this.label,
    required this.acertos,
    required this.erros,
  });

  final String label;
  final int acertos;
  final int erros;
}

/// Dados do painel inicial (`/aluno/painel`).
class DashboardResumo {
  const DashboardResumo({
    required this.totalResolvidas,
    required this.acertos,
    required this.taxaAcerto,
    required this.ofensiva,
    required this.hojeResolvidas,
    required this.evolucaoPercentual,
    required this.nivelPerformance,
    required this.ultimos30Dias,
  });

  final int totalResolvidas;
  final int acertos;
  final int taxaAcerto;
  final int ofensiva;
  final int hojeResolvidas;
  final int evolucaoPercentual;
  final String nivelPerformance;
  final List<DiaAtividade> ultimos30Dias;
}

class TopicoEstatistica {
  const TopicoEstatistica({
    required this.idTopico,
    required this.idMateria,
    required this.nome,
    required this.acertos,
    required this.total,
    required this.taxa,
  });

  final int idTopico;
  final int idMateria;
  final String nome;
  final int acertos;
  final int total;
  final int taxa;
}

class MateriaEstatistica {
  const MateriaEstatistica({
    required this.idMateria,
    required this.nome,
    required this.acertos,
    required this.total,
    required this.taxa,
    required this.ultimaResolucao,
    required this.diasAtraso,
    required this.topicos,
  });

  final int idMateria;
  final String nome;
  final int acertos;
  final int total;
  final int taxa;
  final DateTime ultimaResolucao;
  final int diasAtraso;
  final List<TopicoEstatistica> topicos;
}

class AlertaRevisao {
  const AlertaRevisao({
    required this.idMateria,
    required this.nome,
    required this.dias,
    required this.status,
    required this.cor,
  });

  final int idMateria;
  final String nome;
  final int dias;
  final String status;
  final String cor;
}

class PontoAtencao {
  const PontoAtencao({
    required this.idMateria,
    required this.idTopico,
    required this.materia,
    required this.topico,
    required this.taxa,
    required this.total,
  });

  final int idMateria;
  final int idTopico;
  final String materia;
  final String topico;
  final int taxa;
  final int total;
}

class EvolucaoMateria {
  const EvolucaoMateria({
    required this.idMateria,
    required this.nome,
    required this.cor,
    required this.valores,
  });

  final int idMateria;
  final String nome;
  final String cor;
  final List<int> valores;
}

/// Dados de `/aluno/dashboard_detalhado`.
class DashboardDetalhado {
  const DashboardDetalhado({
    required this.materias,
    required this.pontosAtencao,
    required this.melhorMateria,
    required this.evolucao,
    required this.labelsGrafico,
    required this.totalResolvidas,
    required this.totalAcertos,
    required this.taxaGlobal,
    required this.metaDiaria,
    required this.concluidosPorDia,
    required this.alertasRevisao,
  });

  final List<MateriaEstatistica> materias;
  final List<PontoAtencao> pontosAtencao;
  final MateriaEstatistica? melhorMateria;
  final List<EvolucaoMateria> evolucao;
  final List<String> labelsGrafico;
  final int totalResolvidas;
  final int totalAcertos;
  final int taxaGlobal;
  final int metaDiaria;
  final Map<String, int> concluidosPorDia;
  final List<AlertaRevisao> alertasRevisao;
}

/// Item de histórico já enriquecido com matéria/tópico, usado nos cálculos.
class HistoricoComQuestao {
  const HistoricoComQuestao({
    required this.historico,
    this.questao,
  });

  final HistoricoResposta historico;
  final Questao? questao;
}

/// Página do histórico de respostas com as questões hidratadas.
class PaginaHistorico {
  const PaginaHistorico({
    required this.itens,
    required this.total,
    required this.pagina,
    required this.itensPorPagina,
  });

  final List<HistoricoComQuestao> itens;
  final int total;
  final int pagina;
  final int itensPorPagina;

  bool get temProxima => total > pagina * itensPorPagina;
  bool get temAnterior => pagina > 1;
  int get totalPaginas =>
      total == 0 ? 0 : ((total + itensPorPagina - 1) ~/ itensPorPagina);
}

/// Estatísticas agregadas de um edital (dashboard do ciclo).
class EditalDashboard {
  const EditalDashboard({
    required this.totalResolvidas,
    required this.totalAcertos,
    required this.desempenhoGeral,
    required this.pontosAtencao,
    required this.topicosPrioridade,
  });

  final int totalResolvidas;
  final int totalAcertos;
  final int desempenhoGeral;
  final List<PontoAtencaoEdital> pontosAtencao;
  final List<TopicoPrioridade> topicosPrioridade;
}

class PontoAtencaoEdital {
  const PontoAtencaoEdital({
    required this.materia,
    required this.topico,
    required this.taxa,
    required this.resolvidas,
    required this.idMateria,
    required this.idTopico,
    required this.pesoAdaptativo,
    required this.metaDinamica,
  });

  final String materia;
  final String topico;
  final int taxa;
  final int resolvidas;
  final int idMateria;
  final int idTopico;
  final double pesoAdaptativo;
  final int metaDinamica;
}

class TopicoPrioridade {
  const TopicoPrioridade({
    required this.id,
    required this.nome,
    required this.idMateria,
    required this.idTopico,
    required this.taxaAcerto,
    required this.pesoAdaptativo,
    required this.metaDinamica,
    required this.nivelPrioridade,
    required this.badgeCor,
  });

  final int id;
  final String nome;
  final int idMateria;
  final int idTopico;
  final int taxaAcerto;
  final double pesoAdaptativo;
  final int metaDinamica;
  final String nivelPrioridade;
  final String badgeCor;
}
