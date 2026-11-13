class DatabaseTables {
  // 1. جدول المشتركين (أضفنا arrears للمتأخرات)
  static const String createSubscribersTable = '''
    CREATE TABLE subscribers (
      id INTEGER PRIMARY KEY,
      central_id INTEGER,
      subscriber_no TEXT NOT NULL,
      name TEXT NOT NULL,
      phone TEXT NOT NULL,
      address TEXT,
      area_id INTEGER NOT NULL,
      status TEXT DEFAULT 'active',
      meter_no TEXT,
      arrears REAL DEFAULT 0.0 
    )
  ''';

  // 2. جدول القراءات (كما هو بدون تغيير)
  static const String createReadingsTable = '''
    CREATE TABLE readings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      meter_id INTEGER NOT NULL,
      subscriber_id INTEGER NOT NULL,
      previous_reading REAL NOT NULL,
      current_reading REAL NOT NULL,
      consumption REAL,
      reading_date TEXT NOT NULL,
      status TEXT DEFAULT 'pending',
      image_url TEXT,
      latitude REAL,
      longitude REAL
    )
  ''';

  // 3. جدول التحصيلات (أضفنا emp_id و amount_char)
  static const String createCollectionsTable = '''
    CREATE TABLE collections (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      receipt_no TEXT NOT NULL,
      subscriber_id INTEGER NOT NULL,
      emp_id INTEGER NOT NULL, 
      amount REAL NOT NULL,
      amount_char TEXT, 
      payment_date TEXT NOT NULL,
      payment_method TEXT NOT NULL,
      status TEXT DEFAULT 'pending'
    )
  ''';
}
