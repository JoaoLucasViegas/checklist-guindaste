import 'api.dart';
import 'erros.dart';

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
