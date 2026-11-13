import 'package:electricity_collectors_app/models/user.dart';
import 'package:electricity_collectors_app/services/auth_service.dart';

class AuthRepository {
  final AuthService _authService = AuthService();

  // دالة تسجيل الدخول
  Future<User?> login(String username, String password) async {
    try {
      User? user = await _authService.login(username, password);

      if (user != null) {
        // إذا تم الدخول بنجاح، نحفظ بيانات الجلسة محلياً (سنضيف كود الحفظ لاحقاً)
        await _saveUserSession(user);
        return user;
      }
      return null;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // دالة مساعدة لحفظ بيانات المستخدم محلياً
  Future<void> _saveUserSession(User user) async {
    // في الخطوة القادمة، سنستخدم flutter_secure_storage لحفظ هذه البيانات هنا بأمان
  }
}
