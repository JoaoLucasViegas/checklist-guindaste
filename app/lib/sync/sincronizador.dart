import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/local/banco_local.dart';
import '../data/remote/api.dart';
import '../data/remote/erros.dart';

class Sincronizador extends ChangeNotifier {
  final Api _api;
  final String? Function() lerUsuarioId;
  final Future<void> Function()? aoExpirarSessao;
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _conectividade;
  Timer? _timer;
  bool _iniciado = false;
  bool _descartado = false;
  bool _rodando = false;

  bool redeDisponivel = false;
  int pendentes = 0;
  int errosValidacao = 0;
  String? erro;

  bool get sincronizando => _rodando;

  Sincronizador(this._api, {required this.lerUsuarioId, this.aoExpirarSessao});

  Future<void> iniciar() async {
    if (_iniciado) return;
    _iniciado = true;
    _conectividade = _connectivity.onConnectivityChanged.listen(
      _aoMudarConectividade,
      onError: (Object e) {
        erro = 'Falha ao acompanhar a conexão: ${mensagemDeErro(e)}';
        _notificar();
      },
    );
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _verificarConectividade();
    });
    await _verificarConectividade();
    await atualizarPendencias();
  }

  Future<void> _verificarConectividade() async {
    try {
      _aoMudarConectividade(await _connectivity.checkConnectivity());
    } catch (e) {
      erro = 'Falha ao verificar a conexão: ${mensagemDeErro(e)}';
      _notificar();
    }
  }

  void _aoMudarConectividade(List<ConnectivityResult> resultados) {
    final disponivel = resultados.any(
      (resultado) => resultado != ConnectivityResult.none,
    );
    final mudou = redeDisponivel != disponivel;
    redeDisponivel = disponivel;
    _notificar();
    if (disponivel) {
      _sincronizarAutomaticamente();
    } else if (mudou) {
      atualizarPendencias();
    }
  }

  Future<void> _sincronizarAutomaticamente() async {
    try {
      await sincronizar();
    } catch (e) {
      erro = 'Falha ao sincronizar: ${mensagemDeErro(e)}';
      _notificar();
    }
  }

  Future<int> sincronizar() async {
    if (_rodando) return 0;
    final usuarioId = lerUsuarioId();
    if (usuarioId == null) return 0;

    _rodando = true;
    erro = null;
    _notificar();
    var enviados = 0;
    try {
      final pendentesLocais = await BancoLocal.listarChecklists(
        status: 'PENDENTE_ENVIO',
        usuarioId: usuarioId,
      );
      pendentesLocais.sort((a, b) {
        final jsonA = a['json'] as Map<String, dynamic>;
        final jsonB = b['json'] as Map<String, dynamic>;
        final ordemA =
            jsonA['criado_no_dispositivo_em'] as String? ??
            a['atualizado_em'] as String;
        final ordemB =
            jsonB['criado_no_dispositivo_em'] as String? ??
            b['atualizado_em'] as String;
        return ordemA.compareTo(ordemB);
      });
      for (final linha in pendentesLocais) {
        final id = linha['id'] as String;
        final payload = Map<String, dynamic>.from(
          linha['json'] as Map<String, dynamic>,
        );
        try {
          await _api.enviarChecklist(id, payload);
          await BancoLocal.atualizarStatus(id, 'SINCRONIZADO');
          enviados++;
        } on DioException catch (e) {
          final status = e.response?.statusCode;
          final mensagem = mensagemDeErro(e);
          if (status != null &&
              status >= 400 &&
              status < 500 &&
              status != 401 &&
              status != 408 &&
              status != 429) {
            await BancoLocal.registrarFalhaEnvio(
              id,
              mensagem,
              status: 'ERRO_VALIDACAO',
            );
            erro = mensagem;
            continue;
          }
          await BancoLocal.registrarFalhaEnvio(id, mensagem);
          erro = mensagem;
          if (status == 401) await aoExpirarSessao?.call();
          break;
        } on ErroApi catch (e) {
          await BancoLocal.registrarFalhaEnvio(id, mensagemDeErro(e));
          erro = mensagemDeErro(e);
          break;
        }
      }
      if (enviados > 0) erro = null;
      return enviados;
    } finally {
      _rodando = false;
      await atualizarPendencias();
      _notificar();
    }
  }

  Future<void> atualizarPendencias() async {
    final usuarioId = lerUsuarioId();
    if (usuarioId == null) {
      pendentes = 0;
      errosValidacao = 0;
      _notificar();
      return;
    }
    final checklists = await BancoLocal.listarChecklists(usuarioId: usuarioId);
    pendentes = checklists
        .where((linha) => linha['status'] == 'PENDENTE_ENVIO')
        .length;
    errosValidacao = checklists
        .where((linha) => linha['status'] == 'ERRO_VALIDACAO')
        .length;
    _notificar();
  }

  void _notificar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    _timer?.cancel();
    _conectividade?.cancel();
    super.dispose();
  }
}
