import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_id/android_id.dart'; // 🌟 إضافة مكتبة android_id

import '../providers/auth_provider.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ==========================================
  // دالة لجلب المعرف الفريد للجهاز (محدثة)
  // ==========================================
  Future<String> _getUniqueDeviceId() async {
    try {
      if (Platform.isIOS) {
        var deviceInfo = DeviceInfoPlugin();
        var iosDeviceInfo = await deviceInfo.iosInfo;
        return iosDeviceInfo.identifierForVendor ?? 'unknown_ios';
      } else if (Platform.isAndroid) {
        // 🌟 استخدام android_id لجلب المعرف الفعلي والثابت للأندرويد
        const androidIdPlugin = AndroidId();
        final String? androidId = await androidIdPlugin.getId();
        return androidId ?? 'unknown_android';
      }
    } catch (e) {
      debugPrint('Error getting device ID: $e');
    }
    return 'unknown_device';
  }

  // ==========================================
  // دالة تنفيذ تسجيل الدخول
  // ==========================================
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // 🌟 جلب معرف الجهاز قبل الإرسال
    String deviceId = await _getUniqueDeviceId();

    // 🌟 تمرير المعرف كمعامل ثالث للبروفايدر
    bool success = await authProvider.login(
      _usernameController.text.trim(),
      _passwordController.text,
      deviceId,
    );

    if (success) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: const Color(0xFFF5F7FA),
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(30.w),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Image.asset(
                          'assets/images/SLOGAN_STATION_ALHASN9.png',
                          width: 150.w,
                          height: 150.w,
                          fit: BoxFit.contain,
                        ),
                        SizedBox(height: 20.h),
                        Text(
                          'تسجيل الدخول',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A5276),
                          ),
                        ),
                        SizedBox(height: 10.h),
                        Text(
                          'تطبيق محصلي وقارئي العدادات',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: 50.h),
                        TextFormField(
                          controller: _usernameController,
                          validator: (value) => value == null || value.isEmpty
                              ? 'يرجى إدخال اسم المستخدم'
                              : null,
                          decoration: InputDecoration(
                            labelText: 'اسم المستخدم',
                            prefixIcon: const Icon(Icons.person,
                                color: Color(0xFF1A5276)),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15.r)),
                          ),
                        ),
                        SizedBox(height: 20.h),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          validator: (value) => value == null || value.isEmpty
                              ? 'يرجى إدخال كلمة المرور'
                              : null,
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            prefixIcon: const Icon(Icons.lock,
                                color: Color(0xFF1A5276)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(
                                    () => _obscurePassword = !_obscurePassword);
                              },
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15.r)),
                          ),
                        ),
                        SizedBox(height: 40.h),
                        SizedBox(
                          height: 55.h,
                          child: ElevatedButton(
                            onPressed:
                                authProvider.isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A5276),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15.r),
                              ),
                              elevation: 5,
                            ),
                            child: authProvider.isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : Text(
                                    'دخول',
                                    style: TextStyle(
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
