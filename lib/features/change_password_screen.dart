import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../widgets/app_drawer.dart';

class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        drawer: const AppDrawer(),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A5276),
          title: Text('تغيير كلمة المرور', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.white)),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(30.w),
            child: Container(
              padding: EdgeInsets.all(30.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                    child: Icon(Icons.admin_panel_settings_rounded, size: 80.w, color: const Color(0xFF1A5276)),
                  ),
                  SizedBox(height: 30.h),
                  Text('إجراء أمني', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: const Color(0xFF1A5276))),
                  SizedBox(height: 15.h),
                  Text(
                    'لضمان أمان النظام ولأن التطبيق يعمل بنظام المزامنة الذكية، يرجى مراجعة "مدير النظام" في حال رغبتك بتغيير أو استعادة كلمة المرور الخاصة بك ليتم تحديثها مباشرة في السيرفر المركزي.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15.sp, color: Colors.grey.shade700, height: 1.6),
                  ),
                  SizedBox(height: 30.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A5276),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                      ),
                      child: Text('العودة للرئيسية', style: TextStyle(fontSize: 16.sp, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}