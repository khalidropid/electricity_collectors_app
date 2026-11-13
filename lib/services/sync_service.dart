import 'package:dio/dio.dart';
import 'package:electricity_collectors_app/core/network/api_client.dart';

class SyncService {
  final ApiClient _apiClient = ApiClient();

  // دالة المزامنة الشاملة
  Future<Map<String, dynamic>> syncAllData() async {
    try {
      // الآن قمنا باستخدام _apiClient لعمل طلب مزامنة من السيرفر
      final response = await _apiClient.dio.get('/sync');

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'تمت المزامنة بنجاح'};
      } else {
        throw Exception('حدث خطأ أثناء المزامنة');
      }
    } on DioException catch (e) {
      throw Exception('فشل في الاتصال بالسيرفر أثناء المزامنة: ${e.message}');
    } catch (e) {
      throw Exception('خطأ غير متوقع: $e');
    }
  }
}
