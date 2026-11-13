import 'package:flutter/material.dart';
import '../models/reading.dart';
import '../database/database_helper.dart';

class ReadingProvider extends ChangeNotifier {
  List<Reading> _readings = [];
  bool _isLoading = false;

  List<Reading> get readings => _readings;
  bool get isLoading => _isLoading;

  // جلب سجل القراءات لمشترك معين (من الأحدث للأقدم)
  Future<void> loadCustomerReadings(int customerId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper().database;

      final List<Map<String, dynamic>> maps = await db.query(
        'app_readings',
        where: 'id_customer = ?',
        whereArgs: [customerId],
        orderBy: 'id DESC',
        limit: 100, // 🌟 حماية الأداء: جلب آخر 100 قراءة فقط لتسريع العرض
      );

      // 🌟 التحديث هنا: استخدام fromJson لتتطابق مع المودل المحدث
      _readings = maps.map((e) => Reading.fromJson(e)).toList();
    } catch (e) {
      debugPrint("Error loading readings: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // جلب جميع القراءات المعلقة للمزامنة
  Future<void> loadPendingReadings() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper().database;
      final List<Map<String, dynamic>> maps = await db.query(
        'app_readings',
        where: 'status = ?',
        whereArgs: ['pending'],
      );

      // 🌟 التحديث هنا: استخدام fromJson
      _readings = maps.map((e) => Reading.fromJson(e)).toList();
    } catch (e) {
      debugPrint("Error loading pending readings: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 🌟 دالة لتحديث قائمة القراءات (استخدمها عند العودة من شاشة إضافة قراءة)
  void refreshReadings(int customerId) {
    loadCustomerReadings(customerId);
  }
}
