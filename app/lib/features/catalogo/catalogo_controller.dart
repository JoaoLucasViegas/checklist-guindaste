import 'package:flutter/foundation.dart';

import '../../data/repositories/catalogo_repository.dart';
import '../../domain/catalogo.dart';

class CatalogoController extends ChangeNotifier {
  final CatalogoRepository _repo;
  CatalogoController(this._repo);

  Catalogo? catalogo;
  bool atualizando = false;
  bool ultimaTentativaFalhou = false;

  /// Chamar ao abrir a home: mostra o cache na hora e tenta atualizar em seguida.
  Future<void> iniciar() async {
    catalogo = await _repo.ler();
    notifyListeners();
    await atualizar();
  }

  Future<void> atualizar() async {
    if (atualizando) return;
    atualizando = true;
    notifyListeners();
    try {
      final ok = await _repo.atualizar();
      ultimaTentativaFalhou = !ok;
      if (ok) catalogo = await _repo.ler();
    } finally {
      atualizando = false;
      notifyListeners();
    }
  }
}
