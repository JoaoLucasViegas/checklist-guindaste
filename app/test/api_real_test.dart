import 'dart:convert';
import 'dart:io';

import 'package:checklist_guindaste/data/remote/api_real.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ApiReal usa rotas do contrato e envia o token Bearer', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final chamadas =
        <
          ({String metodo, String caminho, String? autorizacao, String corpo})
        >[];
    final atendendo = server.listen((request) async {
      final corpo = await utf8.decoder.bind(request).join();
      chamadas.add((
        metodo: request.method,
        caminho: request.uri.toString(),
        autorizacao: request.headers.value(HttpHeaders.authorizationHeader),
        corpo: corpo,
      ));

      final resposta = switch ((request.method, request.uri.path)) {
        ('POST', '/api/v1/auth/login') => {
          'access_token': 'token-de-teste',
          'usuario': {'id': 'u1', 'nome': 'Operador', 'papel': 'OPERADOR'},
        },
        ('GET', '/api/v1/template') => {'id': 't1', 'itens': <dynamic>[]},
        ('GET', '/api/v1/lookups') => {'locais': <dynamic>[]},
        ('GET', '/api/v1/equipamentos/eq-1/ultimo-horimetro') => {
          'horimetro_final': 123.4,
        },
        ('PUT', '/api/v1/checklists/c-1') => {
          'id': 'c-1',
          'status': 'ENVIADO',
          'revisao': 1,
          'impedido': false,
          'editado': false,
        },
        ('GET', '/api/v1/checklists') => {
          'contadores': {},
          'itens': <dynamic>[],
        },
        ('GET', '/api/v1/checklists/c-1') => {'id': 'c-1', 'status': 'ENVIADO'},
        _ => <String, dynamic>{'ok': true},
      };

      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(resposta));
      await request.response.close();
    });
    addTearDown(() async {
      await atendendo.cancel();
      await server.close(force: true);
    });

    final api = ApiReal(
      'http://127.0.0.1:${server.port}/api/v1',
      lerToken: () => 'token-de-teste',
    );

    await api.login('1001', '1234');
    await api.template();
    await api.lookups();
    expect(await api.ultimoHorimetro('eq-1'), 123.4);
    expect(await api.enviarChecklist('c-1', {'respostas': []}), {
      'id': 'c-1',
      'status': 'ENVIADO',
      'revisao': 1,
      'impedido': false,
      'editado': false,
    });
    expect(await api.listarChecklists(status: 'ENVIADO'), {
      'contadores': {},
      'itens': [],
    });
    expect(await api.detalhe('c-1'), {'id': 'c-1', 'status': 'ENVIADO'});
    await api.vistar('c-1');
    await api.solicitarCorrecao('c-1', 'Revisar horário');

    expect(chamadas.map((c) => '${c.metodo} ${c.caminho}').toList(), [
      'POST /api/v1/auth/login',
      'GET /api/v1/template',
      'GET /api/v1/lookups',
      'GET /api/v1/equipamentos/eq-1/ultimo-horimetro',
      'PUT /api/v1/checklists/c-1',
      'GET /api/v1/checklists?status=ENVIADO',
      'GET /api/v1/checklists/c-1',
      'POST /api/v1/checklists/c-1/vistar',
      'POST /api/v1/checklists/c-1/solicitar-correcao',
    ]);
    expect(chamadas.first.autorizacao, isNull);
    for (final chamada in chamadas.skip(1)) {
      expect(chamada.autorizacao, 'Bearer token-de-teste');
    }
    expect(jsonDecode(chamadas[0].corpo), {'matricula': '1001', 'pin': '1234'});
    expect(jsonDecode(chamadas[4].corpo), {'respostas': []});
    expect(jsonDecode(chamadas[8].corpo), {'motivo': 'Revisar horário'});
  });
}
