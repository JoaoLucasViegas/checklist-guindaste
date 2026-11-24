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

  // Demais métodos: copiar o padrão (usando options: _op) nas tarefas FE-03 em diante.
  // Até lá, deixe-os lançando UnimplementedError, como no ApiMock.
  @override
  Future<Map<String, dynamic>> template() => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> lookups() => throw UnimplementedError();
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
