import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Pure-Dart zero-dependency SHA-256 implementation for cryptographic audit trails.
class MizanSha256 {
  static const List<int> _k = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  static int _rotr(int x, int n) => ((x & 0xffffffff) >>> n) | ((x << (32 - n)) & 0xffffffff);

  static String digestHex(String input) {
    final bytes = utf8.encode(input);
    final bitLen = bytes.length * 8;
    final padLen = ((56 - (bytes.length + 1) % 64) + 64) % 64;
    final msg = Uint8List(bytes.length + 1 + padLen + 8);
    msg.setRange(0, bytes.length, bytes);
    msg[bytes.length] = 0x80;
    final bd = ByteData.view(msg.buffer);
    bd.setUint32(msg.length - 8, (bitLen ~/ 0x100000000) & 0xffffffff, Endian.big);
    bd.setUint32(msg.length - 4, bitLen & 0xffffffff, Endian.big);

    int h0 = 0x6a09e667, h1 = 0xbb67ae85, h2 = 0x3c6ef372, h3 = 0xa54ff53a;
    int h4 = 0x510e527f, h5 = 0x9b05688c, h6 = 0x1f83d9ab, h7 = 0x5be0cd19;
    final w = Uint32List(64);

    for (int offset = 0; offset < msg.length; offset += 64) {
      for (int i = 0; i < 16; i++) {
        w[i] = bd.getUint32(offset + i * 4, Endian.big);
      }
      for (int i = 16; i < 64; i++) {
        final s0 = _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >>> 3);
        final s1 = _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >>> 10);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
      }
      int a = h0, b = h1, c = h2, d = h3, e = h4, f = h5, g = h6, h = h7;
      for (int i = 0; i < 64; i++) {
        final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
        final ch = (e & f) ^ ((~e & 0xffffffff) & g);
        final t1 = (h + s1 + ch + _k[i] + w[i]) & 0xffffffff;
        final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final t2 = (s0 + maj) & 0xffffffff;
        h = g; g = f; f = e; e = (d + t1) & 0xffffffff;
        d = c; c = b; b = a; a = (t1 + t2) & 0xffffffff;
      }
      h0 = (h0 + a) & 0xffffffff; h1 = (h1 + b) & 0xffffffff;
      h2 = (h2 + c) & 0xffffffff; h3 = (h3 + d) & 0xffffffff;
      h4 = (h4 + e) & 0xffffffff; h5 = (h5 + f) & 0xffffffff;
      h6 = (h6 + g) & 0xffffffff; h7 = (h7 + h) & 0xffffffff;
    }

    return [h0, h1, h2, h3, h4, h5, h6, h7]
        .map((v) => v.toRadixString(16).padLeft(8, '0'))
        .join();
  }

  static String generateMgid(String category, String canonicalName, String baseUnit) {
    final hash = digestHex('${category.toUpperCase()}|${canonicalName.trim().toLowerCase()}|${baseUnit.trim().toLowerCase()}');
    return 'MGID-${category.toUpperCase().substring(0, min(3, category.length))}-${hash.substring(0, 10).toUpperCase()}';
  }
}

/// Time-ordered UUID v7 style generator for duplicate-free offline sync.
class MizanUuidV7 {
  static final Random _rng = Random.secure();

  static String next() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    final tsHex = ms.toRadixString(16).padLeft(12, '0');
    final r1 = _rng.nextInt(0xfff).toRadixString(16).padLeft(3, '0');
    final r2 = (0x8000 | _rng.nextInt(0x3fff)).toRadixString(16).padLeft(4, '0');
    final r3 = _rng.nextInt(0xffffffff).toRadixString(16).padLeft(8, '0');
    final r4 = _rng.nextInt(0xffff).toRadixString(16).padLeft(4, '0');
    return '${tsHex.substring(0, 8)}-${tsHex.substring(8, 12)}-7$r1-$r2-$r3$r4';
  }
}

/// 18-Table Relational SQLite Database (Schema v2) with silent migration from v3.2.
class MizanDatabase {
  static Database? _db;
  static const String _dbName = 'mizan_universal_core_v32.db';
  static const int schemaVersion = 2;

  static Future<Database> instance() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, _dbName);
    _db = await openDatabase(
      fullPath,
      version: schemaVersion,
      onCreate: (db, version) async {
        await _createAllRelationalTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createAllRelationalTables(db);
          await _migrateFromV32CoreState(db);
        }
      },
    );
    return _db!;
  }

  static Future<void> _createAllRelationalTables(Database db) async {
    // 1. Legacy compatibility key-value metadata
    await db.execute('''
      CREATE TABLE IF NOT EXISTS core_state (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    // 2. Effective-dated settings for historical report reproducibility
    await db.execute('''
      CREATE TABLE IF NOT EXISTS effective_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        setting_key TEXT NOT NULL,
        setting_value TEXT NOT NULL,
        effective_from TEXT NOT NULL
      )
    ''');
    // 3. Immutable SHA-256 audit log
    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_time TEXT NOT NULL,
        entity_name TEXT NOT NULL,
        branch_name TEXT NOT NULL,
        action TEXT NOT NULL,
        ref_no TEXT NOT NULL,
        sha256_hash TEXT NOT NULL
      )
    ''');
    // 4. Entities & Branches
    await db.execute('''
      CREATE TABLE IF NOT EXISTS branches (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');
    // 5. Warehouses
    await db.execute('''
      CREATE TABLE IF NOT EXISTS warehouses (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        branch_name TEXT NOT NULL
      )
    ''');
    // 6. Hierarchical Chart of Accounts & Parties
    await db.execute('''
      CREATE TABLE IF NOT EXISTS accounts (
        id TEXT PRIMARY KEY,
        code TEXT NOT NULL,
        parent_id TEXT,
        name TEXT NOT NULL,
        name_i18n TEXT,
        type TEXT NOT NULL,
        currency TEXT NOT NULL DEFAULT 'USD',
        phone TEXT,
        credit_limit REAL NOT NULL DEFAULT 0,
        default_warehouse TEXT,
        balance REAL NOT NULL DEFAULT 0
      )
    ''');
    // 7. Items & Services (with canonical MGID & BOM)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS items (
        id TEXT PRIMARY KEY,
        mgid TEXT NOT NULL,
        sku TEXT NOT NULL,
        name TEXT NOT NULL,
        local_alias TEXT,
        name_i18n TEXT,
        is_service INTEGER NOT NULL DEFAULT 0,
        base_unit TEXT NOT NULL,
        warehouse TEXT NOT NULL,
        bin_location TEXT,
        barcode TEXT,
        batch_no TEXT,
        expiry_date TEXT,
        serial_no TEXT,
        image_path TEXT,
        cost_price REAL NOT NULL DEFAULT 0,
        sale_price REAL NOT NULL DEFAULT 0,
        wholesale_price REAL NOT NULL DEFAULT 0,
        market_price REAL NOT NULL DEFAULT 0,
        stock_qty REAL NOT NULL DEFAULT 0,
        min_stock REAL NOT NULL DEFAULT 5,
        bom_waste_percent REAL NOT NULL DEFAULT 0,
        bom_json TEXT
      )
    ''');
    // 8. Hierarchical Item Units (3+ units per item)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS item_units (
        id TEXT PRIMARY KEY,
        item_id TEXT NOT NULL,
        name TEXT NOT NULL,
        factor_to_base REAL NOT NULL DEFAULT 1,
        barcode TEXT,
        sale_price REAL NOT NULL DEFAULT 0,
        is_default_sale INTEGER NOT NULL DEFAULT 0,
        is_default_purchase INTEGER NOT NULL DEFAULT 0
      )
    ''');
    // 9. Effective-dated FX rates (IAS 21)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fx_rates (
        id TEXT PRIMARY KEY,
        currency_code TEXT NOT NULL,
        currency_name TEXT NOT NULL,
        rate_to_book REAL NOT NULL,
        effective_from TEXT NOT NULL
      )
    ''');
    // 10. Operational Documents (All 5+1 Sector Cycles)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS documents (
        id TEXT PRIMARY KEY,
        doc_no TEXT NOT NULL,
        doc_type TEXT NOT NULL,
        sector_cycle TEXT NOT NULL,
        doc_date TEXT NOT NULL,
        branch_name TEXT NOT NULL,
        cost_center TEXT NOT NULL,
        warehouse TEXT NOT NULL,
        party_id TEXT,
        party_name TEXT,
        cashbox_id TEXT,
        payment_term TEXT NOT NULL,
        currency TEXT NOT NULL,
        fx_rate REAL NOT NULL DEFAULT 1,
        subtotal REAL NOT NULL DEFAULT 0,
        discount_percent REAL NOT NULL DEFAULT 0,
        tax_percent REAL NOT NULL DEFAULT 0,
        shipping REAL NOT NULL DEFAULT 0,
        retention_percent REAL NOT NULL DEFAULT 0,
        total_amount REAL NOT NULL DEFAULT 0,
        paid_amount REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL,
        note TEXT,
        custom_data_json TEXT
      )
    ''');
    // 11. Document Lines
    await db.execute('''
      CREATE TABLE IF NOT EXISTS document_lines (
        id TEXT PRIMARY KEY,
        document_id TEXT NOT NULL,
        item_id TEXT NOT NULL,
        mgid TEXT,
        item_name TEXT NOT NULL,
        unit_name TEXT NOT NULL,
        unit_factor REAL NOT NULL DEFAULT 1,
        qty REAL NOT NULL,
        unit_price REAL NOT NULL,
        cost_at_posting REAL NOT NULL DEFAULT 0
      )
    ''');
    // 12. Compound Journal Headers
    await db.execute('''
      CREATE TABLE IF NOT EXISTS journal_headers (
        id TEXT PRIMARY KEY,
        ref_no TEXT NOT NULL,
        entry_date TEXT NOT NULL,
        branch_name TEXT NOT NULL,
        description TEXT NOT NULL,
        category TEXT NOT NULL,
        source_doc_id TEXT,
        reversed_of_id TEXT,
        sha256_hash TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'posted'
      )
    ''');
    // 13. Compound Journal Lines (multi-line debit/credit)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS journal_lines (
        id TEXT PRIMARY KEY,
        header_id TEXT NOT NULL,
        account_id TEXT NOT NULL,
        account_name TEXT NOT NULL,
        debit REAL NOT NULL DEFAULT 0,
        credit REAL NOT NULL DEFAULT 0,
        currency TEXT NOT NULL DEFAULT 'USD',
        fx_rate REAL NOT NULL DEFAULT 1,
        cost_center TEXT NOT NULL DEFAULT 'عام',
        memo TEXT
      )
    ''');
    // 14. Fixed Assets Register
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fixed_assets (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        account_id TEXT NOT NULL,
        acquisition_cost REAL NOT NULL,
        salvage_value REAL NOT NULL DEFAULT 0,
        useful_life_months INTEGER NOT NULL DEFAULT 60,
        acquisition_date TEXT NOT NULL,
        accumulated_depreciation REAL NOT NULL DEFAULT 0
      )
    ''');
    // 15. Budgets
    await db.execute('''
      CREATE TABLE IF NOT EXISTS budgets (
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL,
        account_name TEXT NOT NULL,
        period_label TEXT NOT NULL,
        planned_amount REAL NOT NULL
      )
    ''');
    // 16. Custom Doors & Dynamic Schemas
    await db.execute('''
      CREATE TABLE IF NOT EXISTS custom_schemas (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        target_role TEXT NOT NULL,
        requires_approval INTEGER NOT NULL DEFAULT 0,
        posts_to_ledger INTEGER NOT NULL DEFAULT 0,
        debit_account_id TEXT,
        credit_account_id TEXT,
        fields_json TEXT NOT NULL
      )
    ''');
    // 17. Paired Gates + Subscriber Public Storefront + Isolated Orders
    await db.execute('''
      CREATE TABLE IF NOT EXISTS paired_gates (
        id TEXT PRIMARY KEY,
        gate_code TEXT NOT NULL,
        partner_name TEXT NOT NULL,
        gate_type TEXT NOT NULL,
        allowed_docs_json TEXT NOT NULL,
        allow_mgid INTEGER NOT NULL DEFAULT 1,
        isolate_costs INTEGER NOT NULL DEFAULT 1,
        status TEXT NOT NULL DEFAULT 'PAIRED'
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS storefront_listings (
        id TEXT PRIMARY KEY,
        item_id TEXT NOT NULL,
        mgid TEXT NOT NULL,
        public_title TEXT NOT NULL,
        public_price REAL NOT NULL,
        currency TEXT NOT NULL,
        visibility TEXT NOT NULL DEFAULT 'PUBLIC',
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS storefront_orders (
        id TEXT PRIMARY KEY,
        buyer_name TEXT NOT NULL,
        listing_id TEXT NOT NULL,
        item_id TEXT NOT NULL,
        item_title TEXT NOT NULL,
        qty REAL NOT NULL,
        unit_price REAL NOT NULL,
        currency TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'PENDING_APPROVAL',
        created_at TEXT NOT NULL
      )
    ''');
    // 18. Offline-First Sync Outbox (Idempotency-protected)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_outbox (
        id TEXT PRIMARY KEY,
        idempotency_key TEXT NOT NULL UNIQUE,
        entity_type TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'PENDING',
        created_at TEXT NOT NULL
      )
    ''');
  }

  /// Silently migrates v3.2 core_state JSON blob into normalized v2 relational tables.
  static Future<void> _migrateFromV32CoreState(Database db) async {
    final rows = await db.query(
      'core_state',
      where: 'key = ?',
      whereArgs: ['mizan_v3_offline_ledger_v1'],
      limit: 1,
    );
    if (rows.isEmpty) return;
    try {
      final raw = rows.first['value'] as String;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final accounts = (data['accounts'] as List? ?? []);
      for (final a in accounts) {
        final m = Map<String, dynamic>.from(a as Map);
        await db.insert(
          'accounts',
          {
            'id': m['id'] ?? MizanUuidV7.next(),
            'code': m['code'] ?? '1000',
            'name': m['name'] ?? 'حساب مرحّل',
            'name_i18n': '{}',
            'type': m['type'] ?? 'asset',
            'currency': m['currency'] ?? 'USD',
            'phone': m['phone'] ?? '',
            'credit_limit': 0.0,
            'default_warehouse': 'المخزن الرئيسي',
            'balance': (m['balance'] as num?)?.toDouble() ?? 0.0,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      final items = (data['items'] as List? ?? []);
      for (final it in items) {
        final m = Map<String, dynamic>.from(it as Map);
        final itemId = m['id']?.toString() ?? MizanUuidV7.next();
        final name = m['name']?.toString() ?? 'صنف مرحّل';
        final unit = m['unit']?.toString() ?? 'حبة';
        await db.insert(
          'items',
          {
            'id': itemId,
            'mgid': MizanSha256.generateMgid('TRD', name, unit),
            'sku': m['sku'] ?? 'SKU-MIG',
            'name': name,
            'local_alias': '',
            'name_i18n': '{}',
            'is_service': 0,
            'base_unit': unit,
            'warehouse': m['warehouse'] ?? 'المخزن الرئيسي',
            'bin_location': 'A-01',
            'barcode': '',
            'cost_price': (m['costPrice'] as num?)?.toDouble() ?? 0.0,
            'sale_price': (m['salePrice'] as num?)?.toDouble() ?? 0.0,
            'wholesale_price': (m['wholesalePrice'] as num?)?.toDouble() ?? 0.0,
            'market_price': (m['marketPrice'] as num?)?.toDouble() ?? 0.0,
            'stock_qty': (m['stockQty'] as num?)?.toDouble() ?? 0.0,
            'min_stock': (m['minStock'] as num?)?.toDouble() ?? 5.0,
            'bom_waste_percent': 0.0,
            'bom_json': '[]',
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await db.insert('audit_events', {
        'event_time': DateTime.now().toIso8601String(),
        'entity_name': data['entityName']?.toString() ?? 'منشأة ميزان',
        'branch_name': data['currentBranch']?.toString() ?? 'الفرع الرئيسي',
        'action': 'MIGRATE_V32_TO_V33_RELATIONAL',
        'ref_no': 'MIG-v3.3',
        'sha256_hash': MizanSha256.digestHex('MIGRATE_V32_TO_V33|${DateTime.now().toIso8601String()}'),
      });
    } catch (_) {
      // Preserve existing database safely if legacy payload is empty or malformed.
    }
  }

  static Future<void> saveEffectiveSetting(String key, String value) async {
    final db = await instance();
    await db.insert('effective_settings', {
      'setting_key': key,
      'setting_value': value,
      'effective_from': DateTime.now().toIso8601String(),
    });
  }

  static Future<String?> getEffectiveSettingAsOf(String key, DateTime asOf) async {
    final db = await instance();
    final rows = await db.query(
      'effective_settings',
      where: 'setting_key = ? AND effective_from <= ?',
      whereArgs: [key, asOf.toIso8601String()],
      orderBy: 'effective_from DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['setting_value'] as String?;
  }

  static Future<void> logAuditEvent({
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

  static Future<int> countTables() async {
    final db = await instance();
    final res = await db.rawQuery(
      "SELECT COUNT(*) as c FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }
}
