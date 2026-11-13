import '../models/reading.dart';
import '../database/database_helper.dart';

class ReadingRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // حفظ قراءة جديدة محلياً
  Future<int> insertReading(Reading reading) async {
    final db = await _dbHelper.database;
    // 🌟 التحديث هنا: استخدام toJson() بدلاً من toMap()
    return await db.insert('app_readings', reading.toJson());
  }

  // جلب القراءات المعلقة لرفعها للسيرفر
  Future<List<Reading>> getPendingReadings() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'app_readings',
      where: 'status = ?',
      whereArgs: ['pending'],
    );
    // 🌟 التحديث هنا: استخدام fromJson() بدلاً من fromMap()
    return maps.map((e) => Reading.fromJson(e)).toList();
  }

  // جلب سجل القراءات الخاص بمشترك معين
  Future<List<Reading>> getReadingsByCustomer(int customerId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'app_readings',
      where: 'id_customer = ?',
      whereArgs: [customerId],
      orderBy: 'id DESC',
    );
    // 🌟 التحديث هنا: استخدام fromJson()
    return maps.map((e) => Reading.fromJson(e)).toList();
  }

  // تحديث حالة القراءة (synced / pending)
  Future<int> updateReadingStatus(int id, String status) async {
    final db = await _dbHelper.database;
    return await db.update(
      'app_readings',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // حذف جميع القراءات
  Future<int> deleteAllReadings() async {
    final db = await _dbHelper.database;
    return await db.delete('app_readings');
  }
}
