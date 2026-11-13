import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'station_electricity.db');
    return await openDatabase(
      path,
      version: 4, // 🌟 الإصدار 4 لتحديث الهيكلية المتطابقة مع السيرفر
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // حذف جميع الجداول القديمة لإعادة بنائها بشكل نظيف
    final tables = [
      'Customer',
      'Employees',
      'geathers',
      'Months',
      'State_Cos',
      'Streets_Line',
      'Take_up_Chits',
      'Sandaat_paying_up',
      'app_collections',
      'app_readings',
      'app_invoices',
      'modification_requests',
      'invoices',
      'customers',
      'readings',
      'collections'
    ];
    for (String table in tables) {
      await db.execute('DROP TABLE IF EXISTS $table');
    }
    await _createTables(db);
  }

  // =========================================================================
  // بناء الجداول المتطابقة تماماً مع سيرفر phpMyAdmin (Salehmey_Station)
  // =========================================================================
  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE Customer (
        id_customer INTEGER PRIMARY KEY,
        name_customer TEXT NOT NULL,
        num_phone INTEGER,
        address_customer TEXT,
        next_customer TEXT,
        Street_customer TEXT,
        type_work TEXT,
        Set_customer TEXT,
        num_account INTEGER,
        num_addaad INTEGER,
        id_state INTEGER,
        TC TEXT,
        Instant_balance INTEGER,
        Take_reading INTEGER DEFAULT 0,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE Employees (
        id_emp INTEGER PRIMARY KEY,
        name_emp TEXT NOT NULL,
        type_emp TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE geathers (
        id_geathers INTEGER PRIMARY KEY,
        id_emp INTEGER,
        username TEXT NOT NULL,
        password TEXT NOT NULL,
        is_active INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE Months (
        Month_name TEXT PRIMARY KEY,
        id_sreail_month INTEGER,
        id_month INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE State_Cos (
        id_state INTEGER PRIMARY KEY,
        name_state TEXT NOT NULL,
        state_shared TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE Streets_Line (
        Street_customer TEXT PRIMARY KEY,
        ID INTEGER,
        id_street INTEGER NOT NULL,
        id_emp INTEGER,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE Take_up_Chits (
        id_takeup_chit INTEGER PRIMARY KEY,
        id_customer INTEGER NOT NULL,
        id_month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        last_read REAL,
        now_reead REAL,
        cost_pay_up INTEGER,
        lates_cost INTEGER,
        total_cost_fatoerh INTEGER,
        Month_name TEXT NOT NULL,
        cost_rest INTEGER,
        id_emp INTEGER,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE Sandaat_paying_up (
        id_sand_paying INTEGER PRIMARY KEY,
        id_customer INTEGER NOT NULL,
        id_takeup_chit INTEGER NOT NULL,
        date_bond TEXT,
        Month_name TEXT,
        cost_paying_up INTEGER,
        cost_pay_char TEXT,
        for_to_cost TEXT,
        id_month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        id_emp INTEGER NOT NULL,
        updated_at TEXT
      )
    ''');

    // --------------------------------------------------------
    // 2. جداول الحركات (Transactional Data) - ترفع للسيرفر (Push)
    // --------------------------------------------------------

    await db.execute('''
      CREATE TABLE app_collections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_no TEXT,
        amount REAL NOT NULL,
        payment_date TEXT,
        payment_method TEXT DEFAULT 'نقدي',
        id_customer INTEGER,
        id_geathers INTEGER,
        status TEXT DEFAULT 'pending',
        sync_status INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE app_readings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        num_addaad INTEGER,
        reading_value REAL NOT NULL,
        reading_date TEXT,
        current_month TEXT,
        id_customer INTEGER,
        id_geathers INTEGER,
        status TEXT DEFAULT 'pending',
        image_path TEXT,
        sync_status INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE app_invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_no TEXT NOT NULL,
        id_customer INTEGER,
        customer_name TEXT,
        meter_no TEXT,
        total_amount REAL DEFAULT 0,
        amount_paid REAL DEFAULT 0,
        remaining_amount REAL DEFAULT 0,
        payment_date TEXT,
        id_geathers INTEGER,
        collector_name TEXT,
        sync_status INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE modification_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_geathers INTEGER,
        id_customer INTEGER,
        name_customer TEXT,
        address_customer TEXT,
        mod_type TEXT,
        notes TEXT,
        request_date TEXT,
        status TEXT DEFAULT 'pending',
        sync_status INTEGER DEFAULT 0
      )
    ''');
  }
}
