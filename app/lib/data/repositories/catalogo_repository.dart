import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../domain/catalogo.dart';
import '../local/banco_local.dart';
import '../mappers/catalogo_mapper.dart';
import '../remote/api.dart';

class CatalogoRepository {
  final Api api;
  CatalogoRepository(this.api);

  /// Baixa template e lookups e guarda no cache. Devolve true se conseguiu.
  /// Só grava se os DOIS downloads funcionarem (nunca deixa o cache pela metade).
  Future<bool> atualizar() async {
    late final Map<String, dynamic> template;
    late final Map<String, dynamic> lookups;
    try {
      template = await api.template();
      lookups = await api.lookups();
    } on DioException catch (e) {
      debugPrint('Falha ao baixar o catálogo: $e');
      return false;
    }

    await BancoLocal.guardarCaches({
      'template': template,
      'lookups': lookups,
      'catalogo_meta': {
        'atualizado_em': DateTime.now().toUtc().toIso8601String(),
      },
    });
    return true;
  }

  /// Lê SEMPRE do cache. Devolve null se nunca houve download.
  Future<Catalogo?> ler() async {
    final t = await BancoLocal.lerCache('template');
    final l = await BancoLocal.lerCache('lookups');
    if (t == null || l == null) return null;
    final meta = await BancoLocal.lerCache('catalogo_meta');
    final quando = meta == null
        ? null
        : DateTime.tryParse(meta['atualizado_em'] as String)?.toLocal();
    return CatalogoMapper.fromJson(
      template: Map<String, dynamic>.from(t as Map),
      lookups: Map<String, dynamic>.from(l as Map),
      atualizadoEm: quando,
    );
  }
}
