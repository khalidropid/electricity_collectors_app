import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageHelper {
  // إنشاء نسخة من وحدة التخزين الآمن
  static const _storage = FlutterSecureStorage();

  // مفاتيح الحفظ (Keys)
  static const String _keyEmpId = 'emp_id';
  static const String _keyEmpName = 'emp_name';
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserRole = 'user_role';
  static const String _keyCanPayAll = 'can_pay_all';
  static const String _keyLastSyncTime =
      'last_sync_time'; // 🌟 مفتاح حفظ وقت المزامنة

  // ==========================================
  // 1. دوال خاصة برقم المتحصل (Emp ID)
  // ==========================================
  static Future<void> saveEmpId(String empId) async {
    await _storage.write(key: _keyEmpId, value: empId);
  }

  static Future<String?> getEmpId() async {
    return await _storage.read(key: _keyEmpId);
  }

  // ==========================================
  // 2. دوال خاصة باسم المتحصل (Emp Name)
  // ==========================================
  static Future<void> saveEmpName(String empName) async {
    await _storage.write(key: _keyEmpName, value: empName);
  }

  static Future<String?> getEmpName() async {
    return await _storage.read(key: _keyEmpName);
  }

  // ==========================================
  // 3. دوال خاصة بحالة تسجيل الدخول (Is Logged In)
  // ==========================================
  static Future<void> setLoggedIn(bool isLoggedIn) async {
    await _storage.write(key: _keyIsLoggedIn, value: isLoggedIn.toString());
  }

  static Future<bool> isLoggedIn() async {
    String? value = await _storage.read(key: _keyIsLoggedIn);
    return value == 'true';
  }

  // ==========================================
  // 4. دوال خاصة بصلاحية المستخدم (Role و تسديد الكل)
  // ==========================================
  static Future<void> saveUserRole(String role) async {
    await _storage.write(key: _keyUserRole, value: role);
  }

  static Future<String?> getUserRole() async {
    return await _storage.read(key: _keyUserRole);
  }

  static Future<void> saveCanPayAll(String canPayAll) async {
    await _storage.write(key: _keyCanPayAll, value: canPayAll);
  }

  static Future<String?> getCanPayAll() async {
    return await _storage.read(key: _keyCanPayAll);
  }

  // ==========================================
  // 5. مسح جميع البيانات (عند تسجيل الخروج)
  // ==========================================
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // ==========================================
  // 6. دوال وقت آخر مزامنة (Last Sync Time) 🌟
  // ==========================================
  static Future<void> saveLastSyncTime(String time) async {
    await _storage.write(key: _keyLastSyncTime, value: time);
  }

  static Future<String?> getLastSyncTime() async {
    return await _storage.read(key: _keyLastSyncTime);
  }

  // دالة لحفظ الصلاحيات
  static Future<void> savePermissions(String permissionsJson) async {
    await _storage.write(key: 'user_permissions', value: permissionsJson);
  }

  // دالة لجلب الصلاحيات
  static Future<String?> getPermissions() async {
    return await _storage.read(key: 'user_permissions');
  }

  // 🌟 حفظ واسترجاع معرف الجهاز (Device ID)
  static Future<void> saveDeviceId(String deviceId) async {
    await _storage.write(key: 'device_id', value: deviceId);
  }

  static Future<String?> getDeviceId() async {
    return await _storage.read(key: 'device_id');
  }
}
