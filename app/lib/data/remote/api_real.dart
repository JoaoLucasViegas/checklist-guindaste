import 'package:dio/dio.dart';

import 'api.dart';

class ApiReal implements Api {
  final Dio _dio;
  final String? Function() lerToken;

  ApiReal(String baseUrl, {required this.lerToken})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

  Options get _op {
    final t = lerToken();
    return Options(headers: {if (t != null) 'Authorization': 'Bearer $t'});
  }

  @override
  Future<Map<String, dynamic>> login(String matricula, String pin) async {
    final r = await _dio.post(
      '/auth/login',
      data: {'matricula': matricula, 'pin': pin},
    );
    return Map<String, dynamic>.from(r.data);
  }

  @override
  Future<Map<String, dynamic>> template() async {
    final r = await _dio.get('/template', options: _op);
    return Map<String, dynamic>.from(r.data);
  }

  @override
  Future<Map<String, dynamic>> lookups() async {
    final r = await _dio.get('/lookups', options: _op);
    return Map<String, dynamic>.from(r.data);
  }

  @override
  Future<double?> ultimoHorimetro(String equipamentoId) async {
    final r = await _dio.get(
      '/equipamentos/${Uri.encodeComponent(equipamentoId)}/ultimo-horimetro',
      options: _op,
    );
    final valor = r.data['horimetro_final'];
    return valor == null ? null : (valor as num).toDouble();
  }

  @override
  Future<Map<String, dynamic>> enviarChecklist(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final r = await _dio.put(
      '/checklists/${Uri.encodeComponent(id)}',
      data: payload,
      options: _op,
    );
    return Map<String, dynamic>.from(r.data);
  }

  @override
  Future<Map<String, dynamic>> listarChecklists({String? status}) async {
    final r = await _dio.get(
      '/checklists',
      queryParameters: {'status': ?status},
      options: _op,
    );
    return Map<String, dynamic>.from(r.data);
  }

  @override
  Future<Map<String, dynamic>> detalhe(String id) async {
    final r = await _dio.get(
      '/checklists/${Uri.encodeComponent(id)}',
      options: _op,
    );
    return Map<String, dynamic>.from(r.data);
  }

  @override
  Future<void> vistar(String id) async {
    await _dio.post(
      '/checklists/${Uri.encodeComponent(id)}/vistar',
      options: _op,
    );
  }

  @override
  Future<void> solicitarCorrecao(String id, String motivo) async {
    await _dio.post(
      '/checklists/${Uri.encodeComponent(id)}/solicitar-correcao',
      data: {'motivo': motivo},
      options: _op,
    );
  }
}
