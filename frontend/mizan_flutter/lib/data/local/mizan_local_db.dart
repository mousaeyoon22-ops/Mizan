import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Unified Encrypted Offline-First SQLite Database (SQLCipher + OS Keychain/Keystore key).
/// Runs ALL 8 versioned SQLite migrations (001 -> 008) in strict sequence with WAL mode.
class MizanLocalDb {
  static const _dbName = 'mizan_offline_v2.db';
  static const _keyStorageName = 'mizan_sqlcipher_master_key';
  static const _schemaVersion = 8;
  final FlutterSecureStorage _secureStorage;
  Database? _db;

  static const Map<int, String> _migrationAssets = {
    1: 'assets/sql/001_mizan_offline_client.sql',
    2: 'assets/sql/002_flutter_feature_flags.sql',
    3: 'assets/sql/003_flutter_fx_and_translation.sql',
    4: 'assets/sql/004_flutter_peak_wal_indexes.sql',
    5: 'assets/sql/005_flutter_pos_shifts_variants.sql',
    6: 'assets/sql/006_flutter_voice_and_accessibility.sql',
    7: 'assets/sql/007_flutter_workspace_modes.sql',
    8: 'assets/sql/008_flutter_meters_and_custody.sql',
  };

  MizanLocalDb({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<Database> get database async {
    if (_db != null) return _db!;
    final password = await _getOrCreateEncryptionKey();
    final path = '${await getDatabasesPath()}/$_dbName';

    _db = await openDatabase(
      path,
      password: password,
      version: _schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
        await db.execute('PRAGMA journal_mode = WAL;');
        await db.execute('PRAGMA synchronous = NORMAL;');
        await db.execute('PRAGMA busy_timeout = 10000;');
      },
      onCreate: (db, version) async {
        for (int v = 1; v <= version; v++) {
          await _applySqlAsset(db, _migrationAssets[v]!);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        for (int v = oldVersion + 1; v <= newVersion; v++) {
          await _applySqlAsset(db, _migrationAssets[v]!);
        }
      },
    );
    return _db!;
  }

  Future<void> _applySqlAsset(Database db, String assetPath) async {
    final sql = await rootBundle.loadString(assetPath);
    final statements = sql.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty);
    for (final stmt in statements) {
      await db.execute('$stmt;');
    }
  }

  Future<String> enqueueOutboxMutation({
    required String orgId,
    required String idempotencyKey,
    required String endpoint,
    required String httpMethod,
    required Map<String, dynamic> payload,
  }) async {
    final db = await database;
    final payloadJson = jsonEncode(payload);
    final digest = sha256.convert(utf8.encode(payloadJson)).toString();
    final id = const Uuid().v4();

    await db.insert(
      'sync_outbox',
      {
        'id': id,
        'idempotency_key': idempotencyKey,
        'org_id': orgId,
        'endpoint': endpoint,
        'http_method': httpMethod,
        'payload_json': payloadJson,
        'payload_sha256': digest,
        'status': 'PENDING',
        'retry_count': 0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return id;
  }

  Future<List<Map<String, Object?>>> fetchPendingOutbox() async {
    final db = await database;
    return db.query('sync_outbox', where: 'status = ?', whereArgs: ['PENDING'], orderBy: 'created_at ASC');
  }

  Future<void> markOutboxStatus(String id, String status, {String? error}) async {
    final db = await database;
    await db.update('sync_outbox', {'status': status, 'last_error': error}, where: 'id = ?', whereArgs: [id]);
  }

  Future<String> _getOrCreateEncryptionKey() async {
    var key = await _secureStorage.read(key: _keyStorageName);
    if (key == null) {
      key = const Uuid().v4() + const Uuid().v4();
      await _secureStorage.write(key: _keyStorageName, value: key);
    }
    return key;
  }
}
