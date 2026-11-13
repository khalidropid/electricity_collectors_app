import 'package:dio/dio.dart';
import '../constants/app_constants.dart';

class ApiClient {
  late Dio dio;

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout:
            const Duration(seconds: 10), // مدة الانتظار القصوى للاتصال
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // إضافة Interceptor لطباعة الطلبات في شاشة التنفيذ (تساعدنا جداً في اكتشاف الأخطاء)
    dio.interceptors.add(LogInterceptor(
      request: true,
      requestBody: true,
      responseBody: true,
      error: true,
    ));
  }
}
