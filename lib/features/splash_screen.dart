import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../core/utils/secure_storage_helper.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginAndNavigate();
  }

  Future<void> _checkLoginAndNavigate() async {
    final results = await Future.wait([
      Future.delayed(const Duration(seconds: 2)),
      _safeCheckLogin(),
    ]);

    if (!mounted) return;

    bool isLoggedIn = results[1] as bool;

    if (isLoggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  // 🌟 تم التحديث للتحقق من الذاكرة المحلية الآمنة مباشرة
  Future<bool> _safeCheckLogin() async {
    try {
      return await SecureStorageHelper.isLoggedIn().timeout(
        const Duration(seconds: 3),
        onTimeout: () => false,
      );
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A5276),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/SLOGAN_STATION_ALHASN9.png',
              width: 150.w,
              height: 150.w,
              fit: BoxFit.contain,
            ),
            SizedBox(height: 20.h),
            Text(
              'تطبيق المتحصلين',
              style: TextStyle(
                fontSize: 28.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 40.h),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}