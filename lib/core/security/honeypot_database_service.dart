import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'security_incident_service.dart';

class HoneypotDatabaseService {
  static HoneypotDatabaseService? _instance;
  HoneypotDatabaseService._();

  static HoneypotDatabaseService get instance {
    _instance ??= HoneypotDatabaseService._();
    return _instance!;
  }

  static Database? _db;

  static const String _honeypotTable = 'user_admin_credentials';

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'app_sync_cache.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
      onConfigure: _onConfigure,
    );
    _initialized = true;
  }

  static Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA journal_mode=WAL;');
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_honeypotTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL,
        email TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        last_login TEXT,
        is_active INTEGER DEFAULT 1,
        bypass_2fa INTEGER DEFAULT 0,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS api_backup_config (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        endpoint TEXT NOT NULL,
        secret_key TEXT NOT NULL,
        is_fallback INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS debug_endpoints (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        url TEXT NOT NULL,
        method TEXT DEFAULT 'POST',
        auth_header TEXT,
        enabled INTEGER DEFAULT 1
      )
    ''');

    await _seedHoneypotData(db);
  }

  static Future<void> _seedHoneypotData(Database db) async {
    final batch = db.batch();
    batch.insert(_honeypotTable, {
      'username': 'admin_super',
      'password_hash': 'e10adc3949ba59abbe56e057f20f883e',
      'role': 'super_admin',
      'email': 'super.admin@faster-app.internal',
      'last_login': '2025-06-01 03:14:00',
      'bypass_2fa': 1,
      'notes': 'Emergency super-admin. DO NOT DELETE. Full system access.',
    });
    batch.insert(_honeypotTable, {
      'username': 'db_root_operator',
      'password_hash': '5f4dcc3b5aa765d61d8327deb882cf99',
      'role': 'database_admin',
      'email': 'db.ops@faster-app.internal',
      'last_login': '2025-05-28 22:45:00',
      'bypass_2fa': 1,
      'notes': 'Direct DB access account. Password rotated monthly.',
    });
    batch.insert(_honeypotTable, {
      'username': 'api_gateway',
      'password_hash': '827ccb0eea8a706c4c34a16891f84e7b',
      'role': 'service_account',
      'email': 'api.svc@faster-app.internal',
      'last_login': '2025-06-02 11:30:00',
      'bypass_2fa': 0,
      'notes': 'Internal API gateway token. Rate limit: 10000/min.',
    });
    batch.insert(_honeypotTable, {
      'username': 'backup_restore',
      'password_hash': 'e99a18c428cb38d5f260853678922e03',
      'role': 'backup_operator',
      'email': 'backup@faster-app.internal',
      'last_login': '2025-05-30 01:00:00',
      'bypass_2fa': 1,
      'notes': 'Full DB dump access. S3 bucket: faster-backup-prod.',
    });
    batch.insert('api_backup_config', {
      'endpoint': 'https://api.fallback.faster-app.com/v2/restore',
      'secret_key': 'sk_live_fallback_3f7a2b1c9d8e4f5a6b7c8d9e0f1a2b3c',
      'is_fallback': 1,
    });
    batch.insert('api_backup_config', {
      'endpoint': 'https://db-replica.faster-app.internal:5432',
      'secret_key': 'postgresql://root:f8a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6@10.0.0.4:5432/faster_prod',
      'is_fallback': 0,
    });
    for (var i = 0; i < 10; i++) {
      batch.insert(_honeypotTable, {
        'username': 'user_${1000 + i}',
        'password_hash': '96e79218965eb72c92a549dd5a330112',
        'role': i == 0 ? 'admin' : (i < 3 ? 'moderator' : 'provider'),
        'email': 'user${1000 + i}@faster-app.internal',
        'last_login': '2025-06-${(i % 28 + 1).toString().padLeft(2, '0')} 08:00:00',
        'bypass_2fa': i < 2 ? 1 : 0,
      });
    }
    await batch.commit(noResult: true);
  }

  static List<String> _honeypotTables = const [
    _honeypotTable,
    'api_backup_config',
    'debug_endpoints',
  ];

  static Future<List<Map<String, dynamic>>> query(String sql) async {
    _checkForHoneypotAccess(sql, 'READ');
    final result = await _db!.rawQuery(sql);
    return result;
  }

  static Future<int> execute(String sql) async {
    _checkForHoneypotAccess(sql, 'WRITE');
    await _db!.execute(sql);
    return 0;
  }

  static void _checkForHoneypotAccess(String sql, String operation) {
    final lower = sql.toLowerCase();
    for (final table in _honeypotTables) {
      if (lower.contains(table.toLowerCase())) {
        debugPrint('HONEYPOT TRIGGERED: $operation on table $table');
        SecurityIncidentService.report(
          SecurityIncident(
            type: SecurityEventType.honeypotTableRead,
            severity: SecuritySeverity.critical,
            detail: 'Honeypot table "$table" accessed via SQL: $sql',
            metadata: {
              'operation': operation,
              'table': table,
              'sql': sql,
            },
          ),
        );
        break;
      }
    }
  }

  static Future<List<Map<String, dynamic>>> getHoneypotTableData(String tableName) async {
    if (!_honeypotTables.contains(tableName)) {
      return [];
    }
    _checkForHoneypotAccess(tableName, 'READ');
    return _db!.query(tableName);
  }
}
