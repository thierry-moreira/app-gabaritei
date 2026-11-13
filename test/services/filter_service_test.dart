import 'package:test/test.dart';
import 'package:gabaritei_app/services/filter_service.dart';

void main() {
  group('QuestaoFiltros', () {
    test('construtor padrão', () {
      final f = QuestaoFiltros();
      expect(f.idQuestao, null);
      expect(f.status, StatusQuestao.todas);
      expect(f.idsMaterias, isEmpty);
      expect(f.pagina, 1);
      expect(f.temFiltros, false);
    });

    test('temFiltros detecta filtros ativos', () {
      expect(QuestaoFiltros(idQuestao: 1).temFiltros, true);
      expect(QuestaoFiltros(status: StatusQuestao.acertos).temFiltros, true);
      expect(QuestaoFiltros(idsMaterias: [1]).temFiltros, true);
      expect(QuestaoFiltros(idsTopicos: [1]).temFiltros, true);
      expect(QuestaoFiltros(idsSubtopicos: [1]).temFiltros, true);
      expect(QuestaoFiltros(idsBancas: [1]).temFiltros, true);
      expect(QuestaoFiltros(idsOrgaos: [1]).temFiltros, true);
      expect(QuestaoFiltros(idsCargos: [1]).temFiltros, true);
      expect(QuestaoFiltros(anos: [2024]).temFiltros, true);
      expect(QuestaoFiltros(idNivel: 1).temFiltros, true);
      expect(QuestaoFiltros(tiposQuestao: ['multipla_escolha']).temFiltros, true);
      expect(QuestaoFiltros(pagina: 2).temFiltros, false); // página não conta
    });

    test('copyWith mantém valores não alterados', () {
      final original = QuestaoFiltros(
        idQuestao: 10,
        status: StatusQuestao.erros,
        idsMaterias: [1, 2],
        pagina: 3,
      );
      final copia = original.copyWith(status: StatusQuestao.acertos);
      expect(copia.idQuestao, 10);
      expect(copia.status, StatusQuestao.acertos);
      expect(copia.idsMaterias, [1, 2]);
      expect(copia.pagina, 3);
    });

    test('copyWith com limparIdQuestao', () {
      final original = QuestaoFiltros(idQuestao: 10);
      final copia = original.copyWith(limparIdQuestao: true);
      expect(copia.idQuestao, null);
    });

    test('copyWith com limparIdNivel', () {
      final original = QuestaoFiltros(idNivel: 3);
      final copia = original.copyWith(limparIdNivel: true);
      expect(copia.idNivel, null);
    });

    test('toQueryParameters serializa corretamente', () {
      final f = QuestaoFiltros(
        idQuestao: 42,
        status: StatusQuestao.respondidas,
        idsMaterias: [1, 2],
        idsTopicos: [10],
        idsSubtopicos: [100],
        idsBancas: [5],
        idsOrgaos: [6],
        idsCargos: [7],
        anos: [2023, 2024],
        idNivel: 2,
        tiposQuestao: ['multipla_escolha', 'certa_errada'],
        pagina: 2,
      );
      final params = f.toQueryParameters();

      expect(params['id_questao'], ['42']);
      expect(params['status'], ['respondidas']);
      expect(params['id_materia'], ['1', '2']);
      expect(params['id_topico'], ['10']);
      expect(params['id_subtopico'], ['100']);
      expect(params['id_banca'], ['5']);
      expect(params['id_orgao'], ['6']);
      expect(params['id_cargo'], ['7']);
      expect(params['ano'], ['2023', '2024']);
      expect(params['id_nivel'], ['2']);
      expect(params['tipo_questao'], ['multipla_escolha', 'certa_errada']);
      expect(params['page'], ['2']);
    });

    test('toQueryParameters omite valores padrão', () {
      final f = QuestaoFiltros();
      final params = f.toQueryParameters();
      expect(params, isEmpty);
    });

    test('toQueryString gera string válida', () {
      final f = QuestaoFiltros(
        idsMaterias: [1, 2],
        status: StatusQuestao.acertos,
      );
      final query = f.toQueryString();
      expect(query, contains('id_materia=1'));
      expect(query, contains('id_materia=2'));
      expect(query, contains('status=acertos'));
    });

    test('fromQueryParameters faz parse correto', () {
      final params = {
        'id_questao': ['123'],
        'status': ['nao_respondidas'],
        'id_materia': ['1', '2'],
        'id_topico': ['10'],
        'id_subtopico': ['100'],
        'id_banca': ['5'],
        'id_orgao': ['6'],
        'id_cargo': ['7'],
        'ano': ['2023', '2024'],
        'id_nivel': ['3'],
        'tipo_questao': ['multipla_escolha'],
        'page': ['3'],
      };
      final f = QuestaoFiltros.fromQueryParameters(params);

      expect(f.idQuestao, 123);
      expect(f.status, StatusQuestao.naoRespondidas);
      expect(f.idsMaterias, [1, 2]);
      expect(f.idsTopicos, [10]);
      expect(f.idsSubtopicos, [100]);
      expect(f.idsBancas, [5]);
      expect(f.idsOrgaos, [6]);
      expect(f.idsCargos, [7]);
      expect(f.anos, [2023, 2024]);
      expect(f.idNivel, 3);
      expect(f.tiposQuestao, ['multipla_escolha']);
      expect(f.pagina, 3);
    });

    test('fromQueryParameters ignora valores inválidos', () {
      final params = {
        'id_questao': ['abc'],
        'id_materia': ['1', 'xyz', '3'],
        'page': ['0'],
      };
      final f = QuestaoFiltros.fromQueryParameters(params);
      expect(f.idQuestao, null);
      expect(f.idsMaterias, [1, 3]);
      expect(f.pagina, 0); // página 0 é mantida como 0
    });

    test('fromQueryParameters com chaves ausentes usa padrão', () {
      final f = QuestaoFiltros.fromQueryParameters({});
      expect(f.idQuestao, null);
      expect(f.status, StatusQuestao.todas);
      expect(f.pagina, 1);
    });

    test('fromUri e fromQueryString', () {
      final uri = Uri.parse('?id_materia=1&id_materia=2&status=erros&page=2');
      final f1 = QuestaoFiltros.fromUri(uri);
      expect(f1.idsMaterias, [1, 2]);
      expect(f1.status, StatusQuestao.erros);
      expect(f1.pagina, 2);

      final f2 = QuestaoFiltros.fromQueryString('id_topico=5&tipo_questao=multipla_escolha');
      expect(f2.idsTopicos, [5]);
      expect(f2.tiposQuestao, ['multipla_escolha']);
    });

    test('StatusQuestao.fromWire', () {
      expect(StatusQuestao.fromWire('todas'), StatusQuestao.todas);
      expect(StatusQuestao.fromWire('nao_respondidas'), StatusQuestao.naoRespondidas);
      expect(StatusQuestao.fromWire('respondidas'), StatusQuestao.respondidas);
      expect(StatusQuestao.fromWire('acertos'), StatusQuestao.acertos);
      expect(StatusQuestao.fromWire('erros'), StatusQuestao.erros);
      expect(StatusQuestao.fromWire('invalido'), StatusQuestao.todas);
      expect(StatusQuestao.fromWire(null), StatusQuestao.todas);
    });

    test('StatusQuestao.wire', () {
      expect(StatusQuestao.todas.wire, 'todas');
      expect(StatusQuestao.naoRespondidas.wire, 'nao_respondidas');
      expect(StatusQuestao.respondidas.wire, 'respondidas');
      expect(StatusQuestao.acertos.wire, 'acertos');
      expect(StatusQuestao.erros.wire, 'erros');
    });
  });
}