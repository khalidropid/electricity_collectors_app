import 'package:flutter/material.dart';
import 'dart:convert'; // 🌟 للتعامل مع الصلاحيات المحفوظة

import '../models/customer.dart';
import '../database/database_helper.dart';
import '../core/utils/secure_storage_helper.dart'; // 🌟 لجلب الصلاحيات

class CustomerProvider extends ChangeNotifier {
  List<Customer> _customers = [];
  bool _isLoading = false;

  List<Customer> get customers => _customers;
  bool get isLoading => _isLoading;

  // 🌟 تعديل الأداء: جلب أول 50 مشترك فقط لتسريع فتح الشاشة
  Future<void> loadCustomers() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper().database;

      // جلب 50 سجل فقط، ويمكنك ترتيبهم حسب الأحدث
      final List<Map<String, dynamic>> maps = await db.query(
        'Customer',
        limit: 50, // 🌟 حماية الذاكرة من الانهيار إذا كان هناك آلاف المشتركين
      );

      _customers = maps.map((e) => Customer.fromJson(e)).toList();
    } catch (e) {
      debugPrint("Error loading customers: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // البحث عن مشترك بالاسم، رقم المشترك، أو رقم العداد (ورقم الهاتف إذا كان مصرحاً له)
  Future<void> searchCustomers(String query) async {
    if (query.isEmpty) {
      await loadCustomers();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // 🌟 1. قراءة صلاحية البحث برقم الهاتف
      bool allowPhoneSearch = false;
      String? permsString = await SecureStorageHelper.getPermissions();
      if (permsString != null) {
        Map<String, dynamic> permissions = jsonDecode(permsString);
        allowPhoneSearch = permissions['allow_phone_search'] ?? false;
      }

      final db = await DatabaseHelper().database;

      // 🌟 2. البناء الديناميكي لجملة البحث (Query)
      String whereString =
          'name_customer LIKE ? OR id_customer LIKE ? OR num_addaad LIKE ?';
      List<dynamic> whereArguments = ['%$query%', '%$query%', '%$query%'];

      // إذا كان مصرحاً له، نضيف عمود الهاتف للبحث
      if (allowPhoneSearch) {
        whereString += ' OR num_phone LIKE ?';
        whereArguments.add('%$query%');
      }

      final List<Map<String, dynamic>> maps = await db.query(
        'Customer',
        where: whereString,
        whereArgs: whereArguments,
        limit: 100, // 🌟 يفضل وضع حد للبحث (مثلاً 100 نتيجة) لتبقى القائمة سلسة
      );

      _customers = maps.map((e) => Customer.fromJson(e)).toList();
    } catch (e) {
      debugPrint("Error searching customers: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // دالة لتحديث القائمة بعد أي عملية دفع أو قراءة لتنعكس في الواجهة
  void refreshCustomers() {
    loadCustomers();
  }
}
