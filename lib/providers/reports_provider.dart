import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';

class ReportsProvider extends ChangeNotifier {
  bool _isLoading = false;

  double _totalCollectedToday = 0.0;
  int _paymentsCountToday = 0;
  int _readingsCountToday = 0;

  // 🌟 المتغيرات الجديدة
  int _totalCustomersCount = 0;
  int _remainingReadingsCount = 0;

  List<Map<String, dynamic>> _todayPaymentsList = [];
  List<Map<String, dynamic>> _todayReadingsList = [];
  List<Map<String, dynamic>> _todayModificationsList = [];

  bool get isLoading => _isLoading;
  double get totalCollectedToday => _totalCollectedToday;
  int get paymentsCountToday => _paymentsCountToday;
  int get readingsCountToday => _readingsCountToday;

  // 🌟 دوال القراءة للمتغيرات الجديدة
  int get totalCustomersCount => _totalCustomersCount;
  int get remainingReadingsCount => _remainingReadingsCount;

  List<Map<String, dynamic>> get todayPaymentsList => _todayPaymentsList;
  List<Map<String, dynamic>> get todayReadingsList => _todayReadingsList;
  List<Map<String, dynamic>> get todayModificationsList =>
      _todayModificationsList;

  Future<void> loadDailyReport() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper().database;
      String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      String currentMonth = DateFormat('yyyy-MM')
          .format(DateTime.now()); // 🌟 لمعرفة قراءات هذا الشهر

      // =====================================
      // 1. معالجة التحصيلات (السندات)
      // =====================================
      final List<Map<String, dynamic>> rawCollections = await db.rawQuery('''
        SELECT c.*, 
               COALESCE(cust.name_customer, 'مشترك غير معروف') as customer_name
        FROM app_collections c
        LEFT JOIN Customer cust ON c.id_customer = cust.id_customer
      ''');

      List<Map<String, dynamic>> tempPayments = [];
      double totalAmount = 0.0;

      for (var col in rawCollections) {
        String paymentDate = col['payment_date']?.toString() ?? '';

        if (paymentDate.startsWith(todayDate)) {
          double amount = (col['amount'] as num?)?.toDouble() ?? 0.0;
          totalAmount += amount;

          tempPayments.add({
            'id_customer': col['id_customer'],
            'customer_name': col['customer_name'],
            'receipt_no': col['receipt_no'] ?? 'بدون رقم',
            'payment_method': col['payment_method'] ?? 'نقدي',
            'amount': amount,
            'payment_date': paymentDate,
          });
        }
      }

      _todayPaymentsList = tempPayments;
      _paymentsCountToday = tempPayments.length;
      _totalCollectedToday = totalAmount;

      // =====================================
      // 2. معالجة القراءات (اليومية)
      // =====================================
      final List<Map<String, dynamic>> rawReadings = await db.rawQuery('''
        SELECT r.*, 
               COALESCE(cust.name_customer, 'مشترك غير معروف') as customer_name
        FROM app_readings r
        LEFT JOIN Customer cust ON r.id_customer = cust.id_customer
      ''');

      List<Map<String, dynamic>> tempReadings = [];

      for (var read in rawReadings) {
        String readingDate = read['reading_date']?.toString() ?? '';

        if (readingDate.startsWith(todayDate)) {
          tempReadings.add({
            'id_customer': read['id_customer'],
            'customer_name': read['customer_name'],
            'num_addaad': read['num_addaad'] ?? 'غير متوفر',
            'reading_value': read['reading_value'] ?? 0,
            'reading_date': readingDate,
          });
        }
      }

      _todayReadingsList = tempReadings;
      _readingsCountToday = tempReadings.length;

      // =====================================
      // 3. معالجة طلبات التعديل
      // =====================================
      final List<Map<String, dynamic>> allModifications = await db.rawQuery('''
        SELECT m.*, 
               COALESCE(cust.name_customer, m.name_customer, 'مشترك غير معروف') as customer_name
        FROM modification_requests m
        LEFT JOIN Customer cust ON m.id_customer = cust.id_customer
      ''');

      List<Map<String, dynamic>> tempModifications = [];

      for (var mod in allModifications) {
        String requestDate = mod['request_date']?.toString() ?? '';

        if (requestDate.startsWith(todayDate)) {
          tempModifications.add({
            'id_customer': mod['id_customer'],
            'customer_name': mod['customer_name'],
            'mod_type': mod['mod_type'] ?? 'تعديل بيانات',
            'notes': mod['notes'] ?? '',
            'request_date': requestDate,
          });
        }
      }

      _todayModificationsList = tempModifications;

      // =====================================
      // 🌟 4. حساب إجمالي المشتركين والقراءات المتبقية للشهر الحالي
      // =====================================

      // جلب إجمالي عدد المشتركين
      final countResult =
          await db.rawQuery('SELECT COUNT(*) as count FROM Customer');
      _totalCustomersCount = countResult.isNotEmpty
          ? (countResult.first['count'] as int? ?? 0)
          : 0;

      // جلب عدد المشتركين الذين تمت قراءتهم (هذا الشهر) وليس اليوم فقط لتكون الحسبة دقيقة
      final monthReadingsResult = await db.rawQuery('''
        SELECT COUNT(DISTINCT id_customer) as count 
        FROM app_readings 
        WHERE reading_date LIKE '$currentMonth%'
      ''');
      int monthReadingsCount = monthReadingsResult.isNotEmpty
          ? (monthReadingsResult.first['count'] as int? ?? 0)
          : 0;

      // حساب المتبقي
      _remainingReadingsCount = _totalCustomersCount - monthReadingsCount;
      if (_remainingReadingsCount < 0)
        _remainingReadingsCount = 0; // حماية من الأرقام السالبة
    } catch (e) {
      debugPrint("Error loading daily report: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
