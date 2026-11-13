import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/secure_storage_helper.dart';

class ApiService {
  // أخذ نسخة من عميل Supabase
  final _supabase = Supabase.instance.client;

  // =======================================================
  // 1. جلب المشتركين المخصصين للمحصل بناءً على الشوارع
  // =======================================================
  Future<List<dynamic>> fetchMyCustomers() async {
    try {
      // الحصول على رقم المحصل من التخزين الآمن
      String? empIdStr = await SecureStorageHelper.getEmpId();
      if (empIdStr == null) return [];

      int empId = int.parse(empIdStr);

      // الخطوة الأولى: جلب أسماء الشوارع المخصصة لهذا المحصل
      final streetsResponse = await _supabase
          .from('streets_line')
          .select('Street_customer')
          .eq('id_emp', empId);

      // تحويل النتيجة إلى قائمة نصوص (List of Strings) بأسماء الشوارع
      List<String> myStreets = (streetsResponse as List<dynamic>)
          .map((row) => row['Street_customer'].toString())
          .toList();

      if (myStreets.isEmpty) {
        debugPrint('لا يوجد شوارع مخصصة لهذا المحصل.');
        return []; // إرجاع قائمة فارغة إذا لم يكن لديه شوارع
      }

      // الخطوة الثانية: جلب المشتركين الذين يسكنون في هذه الشوارع
      // نستخدم inFilter للبحث عن أي مشترك يطابق شارعه أحد الشوارع في القائمة
      final customersResponse = await _supabase
          .from('customer')
          .select()
          .inFilter('Street_customer', myStreets);

      return customersResponse as List<dynamic>;
    } catch (e) {
      debugPrint('خطأ في جلب المشتركين من Supabase: $e');
      return [];
    }
  }

  // =======================================================
  // 2. رفع التحصيلات/السندات (Push)
  // =======================================================
  Future<bool> uploadCollections(List<Map<String, dynamic>> collections) async {
    if (collections.isEmpty) return true; // لا يوجد شيء لرفعه

    try {
      // إدخال السندات كدفعة واحدة (Batch Insert) في الجدول الوسيط
      await _supabase.from('app_collections').insert(collections);
      return true;
    } catch (e) {
      debugPrint('خطأ في رفع التحصيلات: $e');
      return false;
    }
  }

  // =======================================================
  // 3. رفع القراءات (Push)
  // =======================================================
  Future<bool> uploadReadings(List<Map<String, dynamic>> readings) async {
    if (readings.isEmpty) return true;

    try {
      await _supabase.from('app_readings').insert(readings);
      return true;
    } catch (e) {
      debugPrint('خطأ في رفع القراءات: $e');
      return false;
    }
  }

  // =======================================================
  // 4. رفع طلبات التعديل (Push)
  // =======================================================
  Future<bool> uploadModifications(List<Map<String, dynamic>> requests) async {
    if (requests.isEmpty) return true;

    try {
      await _supabase.from('modification_requests').insert(requests);
      return true;
    } catch (e) {
      debugPrint('خطأ في رفع طلبات التعديل: $e');
      return false;
    }
  }
}
