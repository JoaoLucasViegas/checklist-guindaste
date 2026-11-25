
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import 'api.dart';
import 'erros.dart';

class ApiMock implements Api {
  static final Map<String, Map<String, dynamic>> _checklists = {};

  static const _usuarios = {
    '1001': {
      'pin': '1234',
      'id': 'u1',
      'nome': 'João Silva',
      'papel': 'OPERADOR',
    },
    '1002': {
      'pin': '1234',
      'id': 'u2',
      'nome': 'Maria Souza',
      'papel': 'OPERADOR',
    },
    '9001': {
      'pin': '0000',
      'id': 'u9',
      'nome': 'Administrador',
      'papel': 'ADMIN',
    },
  };

  static const _locaisNome = {
    'mock-local-99': 'Cais 99',
    'mock-local-100': 'Cais 100',
  };

  static const _equipamentosNome = {
    'mock-eq-280': 'GUINDASTE-280',
    'mock-eq-281': 'GUINDASTE-281',
    'mock-eq-282': 'GUINDASTE-282',
  };

  String _agoraFormatado() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(now.day)}/${two(now.month)} ${two(now.hour)}:${two(now.minute)}';
  }

  @override
  Future<Map<String, dynamic>> login(String matricula, String pin) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final u = _usuarios[matricula];
    if (u == null || u['pin'] != pin) {
      throw const ErroApi('Matrícula ou PIN incorretos');
    }
    return {
      'access_token': 'mock-token-${u['id']}',
      'usuario': {'id': u['id'], 'nome': u['nome'], 'papel': u['papel']},
    };
  }

  @override
  Future<Map<String, dynamic>> template() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final texto = await rootBundle.loadString('assets/mock/template.json');
    final m = jsonDecode(texto) as Map<String, dynamic>;
    return {...m, 'id': 'mock-template-1'};
  }

  @override
  Future<Map<String, dynamic>> lookups() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return {
      'locais': [
        {'id': 'mock-local-99', 'nome': 'Cais 99'},
        {'id': 'mock-local-100', 'nome': 'Cais 100'},
      ],
      'equipamentos': [
        {'id': 'mock-eq-280', 'identificacao': 'GUINDASTE-280'},
        {'id': 'mock-eq-281', 'identificacao': 'GUINDASTE-281'},
        {'id': 'mock-eq-282', 'identificacao': 'GUINDASTE-282'},
      ],
      'turnos': ['T_08_14', 'T_14_20', 'T_20_02', 'T_02_08'],
    };
  }

  @override
  Future<double?> ultimoHorimetro(String equipamentoId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final texto = await rootBundle.loadString(
      'assets/mock/ultimo_horimetro.json',
    );
    final json = jsonDecode(texto) as Map<String, dynamic>;
    final valor = json['ultimo_horimetro'];
    return valor == null ? null : (valor as num).toDouble();
  }

  @override
  Future<Map<String, dynamic>> enviarChecklist(
    String id,
    Map<String, dynamic> payload,
  ) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final templateJson =
        jsonDecode(await rootBundle.loadString('assets/mock/template.json'))
            as Map<String, dynamic>;

    final mapaTemplate = <int, Map<String, dynamic>>{};
    for (final item in templateJson['itens'] as List) {
      final m = Map<String, dynamic>.from(item as Map);
      mapaTemplate[m['numero'] as int] = m;
    }

    final respostasBrutas = (payload['respostas'] as List?) ?? const [];
    final itensEnriquecidos = <Map<String, dynamic>>[];
    bool impedido = false;
    bool usouLote = payload['usou_lote'] == true;

    for (final r in respostasBrutas) {
      final rm = Map<String, dynamic>.from(r as Map);
      final numItem = (rm['item_numero'] ?? rm['numero']) as int?;
      final tItem = numItem != null ? mapaTemplate[numItem] : null;
      final critico = tItem?['critico'] == true;
      final resp = (rm['resposta'] ?? '').toString().toUpperCase();

      if (critico && resp == 'N') impedido = true;
      if (rm['marcado_em_lote'] == true || rm['origem'] == 'lote') {
        usouLote = true;
      }

      itensEnriquecidos.add({
        ...rm,
        'numero': numItem,
        'ordem': numItem,
        'titulo': tItem?['titulo'] ?? tItem?['descricao'] ?? 'Item $numItem',
        'critico': critico,
      });
    }

    final jaExiste = _checklists.containsKey(id);
    final eventosAnteriores = List<Map<String, dynamic>>.from(
      (_checklists[id]?['eventos'] as List?) ?? const [],
    );
    eventosAnteriores.add({
      'tipo': jaExiste ? 'Editado' : 'Enviado',
      'autor': 'João Silva',
      'em': _agoraFormatado(),
    });

    final localId = payload['local_id']?.toString();
    final eqId = payload['equipamento_id']?.toString();

    final resposta = {
      'id': id,
      'status': 'ENVIADO',
      'revisao': jaExiste ? 2 : 1,
      'impedido': impedido,
      'editado': jaExiste,
      'usou_lote': usouLote,
      'operador': {'id': 'u1', 'nome': 'João Silva'},
      'local': payload['local'] ?? _locaisNome[localId] ?? localId ?? '-',
      'equipamento':
          payload['equipamento'] ?? _equipamentosNome[eqId] ?? eqId ?? '-',
      'itens': itensEnriquecidos,
      'eventos': eventosAnteriores,
    };

    _checklists[id] = {...payload, ...resposta};
    return resposta;
  }

  @override
  Future<Map<String, dynamic>> listarChecklists({String? status}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final todos = _checklists.values.toList();

    final pendentes = todos.where((c) => c['status'] == 'ENVIADO').length;
    final impedidos = todos
        .where((c) => c['impedido'] == true && c['status'] != 'VISTADO')
        .length;
    final correcao = todos
        .where((c) => c['status'] == 'CORRECAO_SOLICITADA')
        .length;
    final vistadosHoje = todos.where((c) => c['status'] == 'VISTADO').length;

    var filtrados = status == null
        ? List<Map<String, dynamic>>.from(todos)
        : todos.where((c) => c['status'] == status).toList();

    // Impedidos primeiro no topo
    filtrados.sort((a, b) {
      final aImp = a['impedido'] == true ? 0 : 1;
      final bImp = b['impedido'] == true ? 0 : 1;
      return aImp.compareTo(bImp);
    });

    return {
      'contadores': {
        'pendentes': pendentes,
        'impedidos': impedidos,
        'correcao': correcao,
        'vistados_hoje': vistadosHoje,
      },
      'itens': filtrados,
    };
  }

  @override
  Future<Map<String, dynamic>> detalhe(String id) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final item = _checklists[id];
    if (item == null) {
      throw const ErroApi('Checklist não encontrado');
    }
    return Map<String, dynamic>.from(item);
  }

  @override
  Future<void> vistar(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final item = _checklists[id];
    if (item == null) throw const ErroApi('Checklist não encontrado');

    final agora = _agoraFormatado();
    item['status'] = 'VISTADO';
    item['vistado_por_nome'] = 'Administrador';
    item['vistado_em'] = agora;

    final eventos = List<Map<String, dynamic>>.from(
      (item['eventos'] as List?) ?? const [],
    );
    eventos.add({
      'tipo': 'Vistado',
      'autor': 'Administrador',
      'em': agora,
    });
    item['eventos'] = eventos;
  }

  @override
  Future<void> solicitarCorrecao(String id, String motivo) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final item = _checklists[id];
    if (item == null) throw const ErroApi('Checklist não encontrado');

    final agora = _agoraFormatado();
    item['status'] = 'CORRECAO_SOLICITADA';
    item['motivo_correcao'] = motivo;

    final eventos = List<Map<String, dynamic>>.from(
      (item['eventos'] as List?) ?? const [],
    );
    eventos.add({
      'tipo': 'Correção solicitada',
      'autor': 'Administrador',
      'em': agora,
      'detalhes': motivo,
    });
    item['eventos'] = eventos;
  }
}
