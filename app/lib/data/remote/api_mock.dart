import 'api.dart';
import 'erros.dart';

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class ApiMock implements Api {
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

  @override
  Future<Map<String, dynamic>> login(String matricula, String pin) async {
    await Future.delayed(const Duration(milliseconds: 400)); // simula a rede
    final u = _usuarios[matricula];
    if (u == null || u['pin'] != pin) {
      throw const ErroApi(
        'Matrícula ou PIN incorretos',
      ); // mesma mensagem do servidor
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
    return {
      ...m,
      'id': 'mock-template-1',
    }; // o servidor real devolve o id do template
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
  Future<double?> ultimoHorimetro(String equipamentoId) =>
      throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> enviarChecklist(
    String id,
    Map<String, dynamic> payload,
  ) => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> listarChecklists({String? status}) =>
      throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> detalhe(String id) => throw UnimplementedError();
  @override
  Future<void> vistar(String id) => throw UnimplementedError();
  @override
  Future<void> solicitarCorrecao(String id, String motivo) =>
      throw UnimplementedError();
}
