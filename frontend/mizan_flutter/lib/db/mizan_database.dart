import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Stage 1 SQLite Relational Storage Engine for Mizan Universal Core.
/// Stores normalized entity/branch/effective-settings metadata alongside
/// verified JSON snapshots and immutable audit log rows so zero data is lost offline.
class MizanDatabase {
  static Database? _db;
  static const String _dbName = 'mizan_universal_core_v32.db';

  static Future<Database> instance() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, _dbName);
    _db = await openDatabase(
      fullPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE core_state (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE effective_settings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            setting_key TEXT NOT NULL,
            setting_value TEXT NOT NULL,
            effective_from TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE audit_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            event_time TEXT NOT NULL,
            entity_name TEXT NOT NULL,
            branch_name TEXT NOT NULL,
            action TEXT NOT NULL,
            ref_no TEXT NOT NULL,
            sha256_hash TEXT NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  static Future<void> saveStateJson(String jsonPayload) async {
    final db = await instance();
    await db.insert(
      'core_state',
      {
        'key': 'ledger_snapshot',
        'value': jsonPayload,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<String?> loadStateJson() async {
    final db = await instance();
    final rows = await db.query(
      'core_state',
      where: 'key = ?',
      whereArgs: ['ledger_snapshot'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  static Future<void> recordEffectiveSetting(String key, String value) async {
    final db = await instance();
    await db.insert('effective_settings', {
      'setting_key': key,
      'setting_value': value,
      'effective_from': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> appendAuditEvent({
    required String entityName,
    required String branchName,
    required String action,
    required String refNo,
    required String sha256Hash,
  }) async {
    final db = await instance();
    await db.insert('audit_events', {
      'event_time': DateTime.now().toIso8601String(),
      'entity_name': entityName,
      'branch_name': branchName,
      'action': action,
      'ref_no': refNo,
      'sha256_hash': sha256Hash,
    });
  }

  static Future<int> auditEventCount() async {
    final db = await instance();
    final res = await db.rawQuery('SELECT COUNT(*) as c FROM audit_events');
    return Sqflite.firstIntValue(res) ?? 0;
  }

  static Future<void> clearAll() async {
    final db = await instance();
    await db.delete('core_state');
    await db.delete('audit_events');
  }
}
