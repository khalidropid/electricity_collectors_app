import 'package:dio/dio.dart';
import 'package:electricity_collectors_app/core/network/api_client.dart';
import 'package:electricity_collectors_app/models/user.dart';

class AuthService {
  final ApiClient _apiClient = ApiClient();

  Future<User?> login(String username, String password) async {
    // ---------------------------------------------------------
    // كود محاكاة (وهمي) لاختبار التطبيق قبل ربطه بالسيرفر الفعلي
    await Future.delayed(
        const Duration(seconds: 2)); // محاكاة وقت الاتصال بالنت

    if (username == 'admin' && password == '1234') {
      return User(
        id: 1,
        name: 'أحمد المتحصل',
        username: 'admin',
        role: 'collector',
        status: 1,
        collectorCode: 'C-100',
      );
    } else {
      throw Exception(
          'اسم المستخدم أو كلمة المرور غير صحيحة (جرب admin و 1234)');
    }
    // ---------------------------------------------------------

    /* 
    // هذا هو الكود الحقيقي الذي سنفعله لاحقاً عند تجهيز السيرفر
    try {
      final response = await _apiClient.dio.post(
        '/login',
        data: {'username': username, 'password': password},
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return User.fromJson(response.data['user']);
      } else {
        throw Exception(response.data['message'] ?? 'فشل تسجيل الدخول');
      }
    } on DioException catch (e) {
      throw Exception('خطأ في الاتصال بالسيرفر: ${e.message}');
    }
    */
  }
}
