import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class BancoLocal {
  static Future<Database>? _abrindo;

  /// Abre o banco uma única vez (várias chamadas simultâneas reaproveitam a mesma).
  static Future<Database> abrir() => _abrindo ??= _abrirDeVerdade();

  static Future<Database> _abrirDeVerdade() async {
    return openDatabase(
      join(await getDatabasesPath(), 'checklist.db'),
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA busy_timeout = 5000');
      },
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE cache(chave TEXT PRIMARY KEY, json TEXT NOT NULL)',
        );
        await db.execute('''CREATE TABLE checklists(
          id TEXT PRIMARY KEY,
          usuario_id TEXT NOT NULL,
          json TEXT NOT NULL,
          status TEXT NOT NULL,
          tentativas INTEGER NOT NULL DEFAULT 0,
          ultimo_erro TEXT,
          atualizado_em TEXT NOT NULL)''');
      },
    );
  }

  // ---------- cache (template, lookups...) ----------
  static Future<void> guardarCache(String chave, Object json) async {
    await guardarCaches({chave: json});
  }

  static Future<void> guardarCaches(Map<String, Object> valores) async {
    final db = await abrir();
    await db.transaction((txn) async {
      for (final entrada in valores.entries) {
        await txn.insert('cache', {
          'chave': entrada.key,
          'json': jsonEncode(entrada.value),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  static Future<dynamic> lerCache(String chave) async {
    final db = await abrir();
    final l = await db.query('cache', where: 'chave = ?', whereArgs: [chave]);
    return l.isEmpty ? null : jsonDecode(l.first['json'] as String);
  }

  // ---------- checklists ----------
  /// status local: RASCUNHO | PENDENTE_ENVIO | SINCRONIZADO | ERRO_VALIDACAO
  static Future<void> salvarChecklist({
    required String id,
    required String usuarioId,
    required Map<String, dynamic> json,
    required String status,
  }) async {
    final db = await abrir();
    final valores = {
      'usuario_id': usuarioId,
      'json': jsonEncode(json),
      'status': status,
      'atualizado_em': DateTime.now().toUtc().toIso8601String(),
    };
    await db.transaction((txn) async {
      final existentes = await txn.query(
        'checklists',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (existentes.isEmpty) {
        await txn.insert('checklists', {'id': id, ...valores});
      } else {
        await txn.update(
          'checklists',
          valores,
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
  }

  /// Muda só o status (usado pela sincronização, FE-10), sem mexer no JSON.
  static Future<void> atualizarStatus(
    String id,
    String status, {
    String? erro,
  }) async {
    final db = await abrir();
    await db.update(
      'checklists',
      {
        'status': status,
        'ultimo_erro': erro,
        'atualizado_em': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> registrarFalhaEnvio(
    String id,
    String erro, {
    String? status,
  }) async {
    final db = await abrir();
    await db.rawUpdate(
      '''UPDATE checklists
      SET tentativas = tentativas + 1,
          ultimo_erro = ?,
          status = COALESCE(?, status),
          atualizado_em = ?
      WHERE id = ?''',
      [erro, status, DateTime.now().toUtc().toIso8601String(), id],
    );
  }

  /// Remove um rascunho local (apenas se ainda estiver em status RASCUNHO).
  static Future<void> removerRascunho(String id) async {
    final db = await abrir();
    await db.delete(
      'checklists',
      where: 'id = ? AND status = ?',
      whereArgs: [id, 'RASCUNHO'],
    );
  }

  static Future<Map<String, dynamic>?> lerChecklist(String id) async {
    final db = await abrir();
    final l = await db.query('checklists', where: 'id = ?', whereArgs: [id]);
    if (l.isEmpty) return null;
    return {...l.first, 'json': jsonDecode(l.first['json'] as String)};
  }

  static Future<List<Map<String, dynamic>>> listarChecklists({
    String? status,
    String? usuarioId,
  }) async {
    final db = await abrir();
    final where = <String>[];
    final args = <Object>[];
    if (status != null) {
      where.add('status = ?');
      args.add(status);
    }
    if (usuarioId != null) {
      where.add('usuario_id = ?');
      args.add(usuarioId);
    }
    final l = await db.query(
      'checklists',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'atualizado_em ASC',
    );
    return [
      for (final r in l) {...r, 'json': jsonDecode(r['json'] as String)},
    ];
  }
}
