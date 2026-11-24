import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Sessao extends ChangeNotifier {
  final _seguro = const FlutterSecureStorage();
  String? token, nome, papel, usuarioId;

  bool get logado => token != null;
  bool get ehAdmin => papel == 'ADMIN';

  Future<void> entrar(Map<String, dynamic> resp) async {
    final u = resp['usuario'] as Map;
    token = resp['access_token'] as String;
    nome = u['nome'] as String;
    papel = u['papel'] as String;
    usuarioId = u['id'] as String;
    await _seguro.write(
      key: 'sessao',
      value: jsonEncode({
        'token': token,
        'nome': nome,
        'papel': papel,
        'id': usuarioId,
      }),
    );
    notifyListeners(); // o main.dart troca para a home sozinho
  }

  /// Chamar ao abrir o app: permite continuar logado, inclusive sem internet.
  Future<void> restaurar() async {
    try {
      final v = await _seguro.read(key: 'sessao');
      if (v == null) return;
      final m = jsonDecode(v) as Map<String, dynamic>;
      token = m['token'] as String?;
      nome = m['nome'] as String?;
      papel = m['papel'] as String?;
      usuarioId = m['id'] as String?;
      notifyListeners();
    } catch (_) {
      // dado corrompido ou keystore indisponível: segue deslogado
    }
  }

  Future<void> sair() async {
    try {
      await _seguro.delete(key: 'sessao');
    } catch (_) {}
    token = nome = papel = usuarioId = null;
    notifyListeners();
  }
}
