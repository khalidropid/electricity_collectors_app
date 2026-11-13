import 'package:flutter/material.dart';
import '../models/payment.dart';
import '../database/database_helper.dart';

class PaymentProvider extends ChangeNotifier {
  List<Payment> _payments = [];
  bool _isLoading = false;

  List<Payment> get payments => _payments;
  bool get isLoading => _isLoading;

  // جلب سجل التحصيلات لمشترك معين (من الأحدث للأقدم)
  Future<void> loadCustomerPayments(int customerId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper().database;

      final List<Map<String, dynamic>> maps = await db.query(
        'app_collections',
        where: 'id_customer = ?',
        whereArgs: [customerId],
        orderBy: 'id DESC',
        limit: 100, // 🌟 حماية إضافية: جلب آخر 100 سند للعميل فقط لتسريع العرض
      );

      _payments = maps.map((e) => Payment.fromJson(e)).toList();
    } catch (e) {
      debugPrint("Error loading payments: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // جلب جميع التحصيلات المعلقة (التي لم ترفع للسيرفر بعد)
  Future<void> loadPendingPayments() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper().database;
      final List<Map<String, dynamic>> maps = await db.query(
        'app_collections',
        where: 'status = ?',
        whereArgs: ['pending'],
      );

      _payments = maps.map((e) => Payment.fromJson(e)).toList();
    } catch (e) {
      debugPrint("Error loading pending payments: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 🌟 دالة جديدة: إضافة سند تحصيل جديد (من الأفضل أن تكون هنا)
  Future<bool> addPayment(Map<String, dynamic> paymentData) async {
    try {
      final db = await DatabaseHelper().database;
      
      // تأكد أن حالة السند "pending" لكي تلتقطه المزامنة التلقائية
      paymentData['status'] = 'pending'; 
      
      await db.insert('app_collections', paymentData);
      
      // تحديث قائمة السندات في الشاشة فوراً
      if (paymentData['id_customer'] != null) {
        await loadCustomerPayments(paymentData['id_customer']);
      }
      return true;
    } catch (e) {
      debugPrint("Error adding payment: $e");
      return false;
    }
  }
}