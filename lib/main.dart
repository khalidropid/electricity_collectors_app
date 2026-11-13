import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'providers/payment_provider.dart';
import 'providers/reading_provider.dart';
import 'providers/reports_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/auth_provider.dart';
import 'features/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SyncProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => ReadingProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
        ChangeNotifierProvider(create: (_) => ReportsProvider()),
      ],
      child: const ElectricityCollectorApp(),
    ),
  );
}

class ElectricityCollectorApp extends StatelessWidget {
  const ElectricityCollectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'محطة الكهرباء - تطبيق المتحصلين',
          theme: ThemeData(
            primaryColor: const Color(0xFF1A5276),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}