import 'package:checklist_guindaste/data/local/banco_local.dart';
import 'package:checklist_guindaste/data/remote/api_mock.dart';
import 'package:checklist_guindaste/data/repositories/catalogo_repository.dart';
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
    'cache e checklist persistem sem apagar metadados de sincronização',
    () async {
      final db = await BancoLocal.abrir();
      await db.delete('cache');
      await db.delete('checklists');

      await BancoLocal.guardarCache('template', {
        'codigo': 'FOR-OPP-0017',
        'itens': [1, 2, 3],
      });
      expect(await BancoLocal.lerCache('template'), {
        'codigo': 'FOR-OPP-0017',
        'itens': [1, 2, 3],
      });

      await BancoLocal.salvarChecklist(
        id: 'checklist-1',
        usuarioId: 'operador-1',
        json: {'respostas': []},
        status: 'PENDENTE_ENVIO',
      );
      await db.update(
        'checklists',
        {'tentativas': 3, 'ultimo_erro': 'timeout'},
        where: 'id = ?',
        whereArgs: ['checklist-1'],
      );
      await BancoLocal.salvarChecklist(
        id: 'checklist-1',
        usuarioId: 'operador-1',
        json: {
          'respostas': [
            {'item_numero': 1, 'resposta': 'S'},
          ],
        },
        status: 'PENDENTE_ENVIO',
      );

      final checklist = await BancoLocal.lerChecklist('checklist-1');
      expect(checklist?['json'], {
        'respostas': [
          {'item_numero': 1, 'resposta': 'S'},
        ],
      });
      expect(checklist?['tentativas'], 3);
      expect(checklist?['ultimo_erro'], 'timeout');
      expect(
        await BancoLocal.listarChecklists(usuarioId: 'operador-1'),
        hasLength(1),
      );
    },
  );

  test(
    'catálogo permanece disponível do cache quando a API fica indisponível',
    () async {
      final repositorioOnline = CatalogoRepository(ApiMock());
      expect(await repositorioOnline.atualizar(), isTrue);
      expect((await repositorioOnline.ler())?.itens, hasLength(23));

      final repositorioOffline = CatalogoRepository(_ApiSemConexao());
      expect(await repositorioOffline.atualizar(), isFalse);
      expect((await repositorioOffline.ler())?.itens, hasLength(23));
    },
  );
}

class _ApiSemConexao extends ApiMock {
  @override
  Future<Map<String, dynamic>> template() async {
    throw DioException(
      requestOptions: RequestOptions(path: '/template'),
      type: DioExceptionType.connectionError,
    );
  }
}
