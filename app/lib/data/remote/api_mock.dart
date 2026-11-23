import 'dart:convert';
import 'package:flutter/services.dart';
import 'api.dart';

class ApiMock implements Api {
  static const String _basePath = 'assets/mock/';

  final Map<String, Map<String, dynamic>> _checklists = {};

  Future<dynamic> _readJson(String filename) async {
    final content = await rootBundle.loadString('$_basePath$filename');
    return jsonDecode(content);
  }

  Future<Map<String, dynamic>> _readMap(String filename) async {
    final data = await _readJson(filename);
    return Map<String, dynamic>.from(data);
  }

  @override
  Future<Map<String, dynamic>> login(
    String matricula,
    String pin,
  ) async {
    return _readMap('login.json');
  }

  @override
  Future<Map<String, dynamic>> template() async {
    return _readMap('template.json');
  }

  @override
  Future<Map<String, dynamic>> lookups() async {
    return _readMap('lookups.json');
  }

  @override
  Future<double?> ultimoHorimetro(String equipamentoId) async {
    final data = await _readJson('ultimo_horimetro.json');

    if (data is num) return data.toDouble();

    if (data is Map) {
      final value = data['ultimo_horimetro'];
      return value is num ? value.toDouble() : null;
    }

    return null;
  }

  @override
  Future<Map<String, dynamic>> enviarChecklist(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final result = {
      'id': id,
      'status': 'enviado',
      ...payload,
    };

    _checklists[id] = result;

    return result;
  }

  @override
  Future<Map<String, dynamic>> listarChecklists({
    String? status,
  }) async {
    final data = await _readMap('checklists.json');

    final items = List<Map<String, dynamic>>.from(
      (data['checklists'] as List? ?? []).map(
        (item) => Map<String, dynamic>.from(item),
      ),
    );

    // Inclui checklists criados durante a execução.
    for (final item in _checklists.values) {
      items.removeWhere((e) => e['id'] == item['id']);
      items.add(item);
    }

    final filtered = status == null
        ? items
        : items.where((item) => item['status'] == status).toList();

    return {
      ...data,
      'checklists': filtered,
    };
  }

  @override
  Future<Map<String, dynamic>> detalhe(String id) async {
    if (_checklists.containsKey(id)) {
      return _checklists[id]!;
    }

    return _readMap('detalhe_$id.json');
  }

  @override
  Future<void> vistar(String id) async {
    final item = await detalhe(id);

    item['status'] = 'vistado';
    _checklists[id] = item;
  }

  @override
  Future<void> solicitarCorrecao(
    String id,
    String motivo,
  ) async {
    final item = await detalhe(id);

    item['status'] = 'correcao_solicitada';
    item['motivo_correcao'] = motivo;

    _checklists[id] = item;
  }
}