import '../models/payment.dart';
import '../database/database_helper.dart';

class PaymentRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // إضافة تحصيل جديد إلى القاعدة المحلية
  Future<int> insertPayment(Payment payment) async {
    final db = await _dbHelper.database;
    // 🌟 التحديث هنا: استخدام toJson() بدلاً من toMap()
    return await db.insert('app_collections', payment.toJson());
  }

  // جلب التحصيلات المعلقة التي تنتظر الرفع للسيرفر
  Future<List<Payment>> getPendingPayments() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'app_collections',
      where: 'status = ?',
      whereArgs: ['pending'],
    );
    // 🌟 التحديث هنا: استخدام fromJson() بدلاً من fromMap()
    return maps.map((e) => Payment.fromJson(e)).toList();
  }

  // جلب جميع التحصيلات الخاصة بمشترك معين
  Future<List<Payment>> getPaymentsByCustomer(int customerId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'app_collections',
      where: 'id_customer = ?',
      whereArgs: [customerId],
      orderBy: 'id DESC', // ترتيب من الأحدث للأقدم
    );
    // 🌟 التحديث هنا: استخدام fromJson()
    return maps.map((e) => Payment.fromJson(e)).toList();
  }

  // تحديث حالة التحصيل (مثلاً: من pending إلى synced بعد المزامنة)
  Future<int> updatePaymentStatus(int id, String status) async {
    final db = await _dbHelper.database;
    return await db.update(
      'app_collections',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // حذف جميع التحصيلات (قد تحتاجه عند تنظيف الهاتف بعد فترة)
  Future<int> deleteAllPayments() async {
    final db = await _dbHelper.database;
    return await db.delete('app_collections');
  }
}
