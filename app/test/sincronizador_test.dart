import 'package:checklist_guindaste/data/local/banco_local.dart';
import 'package:checklist_guindaste/data/remote/api_mock.dart';
import 'package:checklist_guindaste/sync/sincronizador.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'mantém falha offline na fila e sincroniza só uma vez ao reconectar',
    () async {
      const id = 'fila-fe-10';
      const usuarioId = 'operador-fe-10';
      final db = await BancoLocal.abrir();
      await db.delete('checklists', where: 'id = ?', whereArgs: [id]);
      await BancoLocal.salvarChecklist(
        id: id,
        usuarioId: usuarioId,
        json: {'respostas': []},
        status: 'PENDENTE_ENVIO',
      );

      final api = _ApiFila()..falhar = true;
      final sincronizador = Sincronizador(api, lerUsuarioId: () => usuarioId);
      expect(await sincronizador.sincronizar(), 0);
      final falha = await BancoLocal.lerChecklist(id);
      expect(falha?['status'], 'PENDENTE_ENVIO');
      expect(falha?['tentativas'], 1);
      expect(falha?['ultimo_erro'], 'Sem conexão com o servidor');

      api.falhar = false;
      expect(await sincronizador.sincronizar(), 1);
      expect(await sincronizador.sincronizar(), 0);
      expect(api.chamadas, 2);
      expect((await BancoLocal.lerChecklist(id))?['status'], 'SINCRONIZADO');

      sincronizador.dispose();
      await db.delete('checklists', where: 'id = ?', whereArgs: [id]);
    },
  );

  test('erros de validação não entram em retentativa automática', () async {
    const id = 'fila-erro-fe-10';
    const usuarioId = 'operador-fe-10';
    final db = await BancoLocal.abrir();
    await db.delete('checklists', where: 'id = ?', whereArgs: [id]);
    await BancoLocal.salvarChecklist(
      id: id,
      usuarioId: usuarioId,
      json: {'respostas': []},
      status: 'PENDENTE_ENVIO',
    );

    final api = _ApiFila()..erroValidacao = true;
    final sincronizador = Sincronizador(api, lerUsuarioId: () => usuarioId);
    expect(await sincronizador.sincronizar(), 0);
    expect(await sincronizador.sincronizar(), 0);
    expect(api.chamadas, 1);
    final salvo = await BancoLocal.lerChecklist(id);
    expect(salvo?['status'], 'ERRO_VALIDACAO');
    expect(salvo?['ultimo_erro'], 'Checklist inválido');
    expect(sincronizador.errosValidacao, 1);

    sincronizador.dispose();
    await db.delete('checklists', where: 'id = ?', whereArgs: [id]);
  });
}

class _ApiFila extends ApiMock {
  int chamadas = 0;
  bool falhar = false;
  bool erroValidacao = false;

  @override
  Future<Map<String, dynamic>> enviarChecklist(
    String id,
    Map<String, dynamic> payload,
  ) async {
    chamadas++;
    if (erroValidacao) {
      throw DioException(
        requestOptions: RequestOptions(path: '/checklists/$id'),
        response: Response(
          requestOptions: RequestOptions(path: '/checklists/$id'),
          statusCode: 400,
          data: {
            'erro': {'mensagem': 'Checklist inválido'},
          },
        ),
      );
    }
    if (falhar) {
      throw DioException(
        requestOptions: RequestOptions(path: '/checklists/$id'),
        type: DioExceptionType.connectionError,
      );
    }
    return {'id': id, 'status': 'ENVIADO'};
  }
}
