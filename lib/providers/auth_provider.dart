import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:convert'; // 🌟 للتعامل مع تحويل الصلاحيات إلى JSON
import '../core/utils/secure_storage_helper.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoading = false;
  String _errorMessage = '';

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  // رابط ملف الـ PHP على استضافتك
  final String _loginUrl = 'https://saleh.me.ye/api/login.php';

  // 🌟 إضافة deviceId كمعامل ثالث
  Future<bool> login(String username, String password, String deviceId) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final dio = Dio();

      // إرسال الطلب عبر HTTP POST إلى السيرفر
      final response = await dio.post(
        _loginUrl,
        data: {
          'username': username,
          'password': password,
          'device_id': deviceId, // 🌟 إرسال رقم الجهاز للسيرفر
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;

        if (data['success'] == true) {
          var userData = data['user'];

          // حفظ المعرفات والبيانات الحقيقية القادمة من جدول geathers
          String geatherId = userData['id'].toString();
          String empId = userData['emp_id'].toString();
          String empName = userData['name'].toString();

          // استخراج الصلاحيات
          String role = userData['role']?.toString() ??
              data['role']?.toString() ??
              'collector';

          // 🌟 استخراج صلاحية تسديد الكل
          String canPayAll = userData['can_pay_all']?.toString() ?? '0';

          await SecureStorageHelper.saveEmpId(empId);
          await SecureStorageHelper.saveEmpName(empName);
          await SecureStorageHelper.saveUserRole(role);

          // 🌟 حفظ صلاحية تسديد الكل محلياً
          await SecureStorageHelper.saveCanPayAll(canPayAll);

          // ==========================================
          // 🌟 حفظ قائمة الصلاحيات المفصلة
          // ==========================================
          if (data['permissions'] != null) {
            String permissionsJson = jsonEncode(data['permissions']);
            await SecureStorageHelper.savePermissions(permissionsJson);
          }
          // ==========================================

          await SecureStorageHelper.setLoggedIn(true);

          // 🌟🌟 هنا الحلقة المفقودة: حفظ رقم الجهاز في الذاكرة لكي يستخدمه الفحص الصامت 🌟🌟
          await SecureStorageHelper.saveDeviceId(deviceId);

          return true;
        } else {
          // 🔒 سيتم عرض الرسالة هنا إذا كان الجهاز قيد الانتظار أو غير مصرح
          _errorMessage = data['message'] ?? 'بيانات الدخول غير صحيحة';
          return false;
        }
      } else {
        _errorMessage = 'خطأ في الاتصال بالخادم (${response.statusCode})';
        return false;
      }
    } catch (e) {
      debugPrint('Login API Error: $e');
      _errorMessage = 'تعذر الاتصال بالسيرفر، تأكد من اتصال الإنترنت.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await SecureStorageHelper.clearAll();
    notifyListeners();
  }
}
