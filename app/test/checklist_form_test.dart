import 'package:checklist_guindaste/data/local/banco_local.dart';
import 'package:checklist_guindaste/data/remote/api_mock.dart';
import 'package:checklist_guindaste/domain/catalogo.dart';
import 'package:checklist_guindaste/domain/modelos.dart';
import 'package:checklist_guindaste/features/checklist_form/checklist_edicao_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('sugere turno correto nos limites e valida uma casa decimal', () {
    expect(
      ChecklistEdicaoController.turnoSugerido(DateTime(2026, 1, 1, 8)),
      'T_08_14',
    );
    expect(
      ChecklistEdicaoController.turnoSugerido(DateTime(2026, 1, 1, 14)),
      'T_14_20',
    );
    expect(
      ChecklistEdicaoController.turnoSugerido(DateTime(2026, 1, 1, 20)),
      'T_20_02',
    );
    expect(
      ChecklistEdicaoController.turnoSugerido(DateTime(2026, 1, 1, 1, 59)),
      'T_20_02',
    );
    expect(
      ChecklistEdicaoController.turnoSugerido(DateTime(2026, 1, 1, 2)),
      'T_02_08',
    );
    expect(
      ChecklistEdicaoController.turnoSugerido(DateTime(2026, 1, 1, 8)),
      'T_08_14',
    );

    expect(ChecklistEdicaoController.parseHorimetro('36466.1'), 36466.1);
    expect(ChecklistEdicaoController.parseHorimetro('36466,1'), 36466.1);
    expect(ChecklistEdicaoController.parseHorimetro('36466.15'), isNull);
  });

  test('só considera o cabeçalho válido com campos obrigatórios corretos', () {
    final controller = ChecklistEdicaoController(
      api: ApiMock(),
      catalogo: _catalogo(),
      usuarioId: 'operador-1',
    );

    expect(controller.cabecalhoValido, isFalse);
    controller.localId = 'local-1';
    controller.equipamentoId = 'equipamento-1';
    expect(controller.cabecalhoValido, isFalse);

    controller.horimetroInicial = '36466.1';
    expect(controller.cabecalhoValido, isTrue);

    controller.horimetroInicial = '36466.15';
    expect(controller.cabecalhoValido, isFalse);

    controller
      ..horimetroInicial = '36466.1'
      ..horimetroFinal = '36466.0';
    expect(controller.cabecalhoValido, isFalse);
    controller.dispose();
  });

  test(
    'restaura rascunho e envia o contrato completo pelo mesmo UUID',
    () async {
      final catalogo = _catalogo();
      final api = _ApiEnvio();
      final id = 'rascunho-fe-04-06';
      final db = await BancoLocal.abrir();
      await db.delete('checklists', where: 'id = ?', whereArgs: [id]);

      final primeiro = ChecklistEdicaoController(
        api: api,
        catalogo: catalogo,
        usuarioId: 'operador-1',
        rascunhoId: id,
      );
      await primeiro.inicializar();
      primeiro.selecionarLocal('local-1');
      await primeiro.selecionarEquipamento('equipamento-1');
      primeiro.definirHorimetroInicial('36466.1');
      primeiro.responder(1, 'N');
      primeiro.definirObservacao(1, 'Não tem');
      await primeiro.aguardarSalvamento();
      final inicioSalvo = primeiro.inicioPreenchimento;
      primeiro.dispose();

      final restaurado = ChecklistEdicaoController(
        api: api,
        catalogo: catalogo,
        usuarioId: 'operador-1',
        rascunhoId: id,
      );
      await restaurado.inicializar();
      expect(restaurado.localId, 'local-1');
      expect(restaurado.equipamentoId, 'equipamento-1');
      expect(restaurado.horimetroInicial, '36466.1');
      expect(restaurado.inicioPreenchimento.toUtc(), inicioSalvo.toUtc());
      expect(restaurado.respostas.first.resposta, 'N');
      expect(restaurado.respostas.first.observacao, 'Não tem');

      restaurado.definirHorimetroFinal('36470.8');
      for (final item in catalogo.itens.where((item) => item.numero != 1)) {
        if ({10, 22}.contains(item.numero)) {
          restaurado.responder(item.numero, 'N');
          restaurado.definirObservacao(item.numero, 'Problema encontrado');
        } else {
          restaurado.responder(item.numero, 'S');
        }
      }

      restaurado.definirObservacao(10, '  ');
      expect(await restaurado.enviar(), isFalse);
      expect(
        restaurado.errosValidacao.any((erro) => erro.contains('Item 10')),
        isTrue,
      );
      expect(api.payload, isNull);
      restaurado.definirObservacao(10, 'Problema encontrado');

      expect(await restaurado.enviar(), isTrue);
      expect(api.payload?['template_id'], catalogo.templateId);
      expect(api.payload?['horimetro_inicial'], 36466.1);
      expect(api.payload?['horimetro_final'], 36470.8);
      expect(api.payload?['respostas'], hasLength(23));
      expect(
        (api.payload?['respostas'] as List)
            .where((resposta) => (resposta as Map)['resposta'] == 'N')
            .map((resposta) => (resposta as Map)['item_numero'])
            .toList(),
        [1, 10, 22],
      );
      expect(restaurado.resultadoEnvio?['impedido'], isTrue);
      expect((await BancoLocal.lerChecklist(id))?['status'], 'SINCRONIZADO');
      await db.delete('checklists', where: 'id = ?', whereArgs: [id]);
      restaurado.dispose();
    },
  );
}

Catalogo _catalogo() => Catalogo(
  templateId: 'template-1',
  codigo: 'FOR-OPP-0017',
  versao: 5,
  titulo: 'Checklist',
  itens: [
    for (var numero = 1; numero <= 23; numero++)
      ItemTemplate(
        numero: numero,
        descricao: 'Item $numero',
        critico: {1, 10, 22}.contains(numero),
      ),
  ],
  locais: const [Local(id: 'local-1', nome: 'Cais 99')],
  equipamentos: const [
    Equipamento(id: 'equipamento-1', identificacao: 'GUINDASTE-280'),
  ],
  turnos: const ['T_08_14', 'T_14_20', 'T_20_02', 'T_02_08'],
);

class _ApiEnvio extends ApiMock {
  Map<String, dynamic>? payload;

  @override
  Future<double?> ultimoHorimetro(String equipamentoId) async => 36466.1;

  @override
  Future<Map<String, dynamic>> enviarChecklist(
    String id,
    Map<String, dynamic> payload,
  ) async {
    this.payload = payload;
    final problemasCriticos = (payload['respostas'] as List).any(
      (resposta) =>
          {1, 10, 22}.contains((resposta as Map)['item_numero']) &&
          resposta['resposta'] == 'N',
    );
    return {
      'id': id,
      'status': 'ENVIADO',
      'revisao': 1,
      'impedido': problemasCriticos,
      'editado': false,
    };
  }
}
