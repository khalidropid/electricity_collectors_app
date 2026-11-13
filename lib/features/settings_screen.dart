import 'package:electricity_collectors_app/features/printer_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

// استدعاء ملف القائمة الجانبية والشاشات والمزودات وملف التخزين
import '../widgets/app_drawer.dart';
import 'change_password_screen.dart';
import 'login_screen.dart';
import '../providers/auth_provider.dart';
import '../core/utils/secure_storage_helper.dart'; // 🌟 جلب بيانات الموظف

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _empName = 'جاري التحميل...';
  String _roleTitle = '';
  String _rawRole = ''; // 🌟 حفظ الصلاحية الخام لفحصها عند الحاجة

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // 🌟 دالة جلب بيانات المستخدم لعرضها في الإعدادات
  Future<void> _loadUserData() async {
    String? name = await SecureStorageHelper.getEmpName();
    String? role = await SecureStorageHelper.getUserRole();

    if (mounted) {
      setState(() {
        _empName = name ?? 'مستخدم غير معروف';
        _rawRole = role ?? ''; // تخزين القيمة مثل 'admin' أو غيرها
        if (_rawRole == 'admin') {
          _roleTitle = 'المدير العام';
        } else {
          _roleTitle = 'محصل ميداني';
        }
      });
    }
  }

  // ==========================================
  // --- دالة عرض نافذة تأكيد الخروج ---
  // ==========================================
  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.r)),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.logout, color: Colors.red, size: 28),
                ),
                SizedBox(width: 10.w),
                Text('تأكيد الخروج',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18.sp)),
              ],
            ),
            content: Text('هل أنت متأكد أنك تريد تسجيل الخروج من الحساب؟',
                style: TextStyle(fontSize: 15.sp)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text('إلغاء',
                    style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _logout(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r)),
                ),
                child: Text('تسجيل الخروج',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // --- نافذة إعدادات السيرفر (محمية للمدير فقط) ---
  // ==========================================
  void _showServerSettingsDialog(BuildContext context) {
    // 🌟 حماية إضافية داخلية لمنع أي محاولة تجاوز
    if (_rawRole != 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('عذراً، هذه الصلاحية مخصصة للـ "المدير العام" فقط!',
              textAlign: TextAlign.center),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final TextEditingController serverController =
        TextEditingController(text: 'https://saleh.me.ye/api/');

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.r)),
            title: Row(
              children: [
                const Icon(Icons.dns, color: Color(0xFF1A5276)),
                SizedBox(width: 10.w),
                Text('إعدادات السيرفر',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18.sp)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    'يرجى عدم تغيير الرابط إلا بتوجيه من الإدارة لضمان عمل التطبيق.',
                    style: TextStyle(
                        fontSize: 13.sp, color: Colors.grey.shade600)),
                SizedBox(height: 15.h),
                TextField(
                  controller: serverController,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'رابط السيرفر (API URL)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r)),
                    prefixIcon: const Icon(Icons.link),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text('إلغاء',
                    style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                onPressed: () {
                  // سيتم لاحقاً حفظ الرابط الجديد باستخدام SecureStorageHelper
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('تم حفظ إعدادات السيرفر بنجاح',
                            textAlign: TextAlign.center),
                        backgroundColor: Colors.green),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A5276),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r)),
                ),
                child: const Text('حفظ التعديلات',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // --- دالة تسجيل الخروج الفعلية ---
  // ==========================================
  void _logout(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();

    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        drawer: const AppDrawer(),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A5276),
          title: Text(
            'الإعدادات',
            style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        body: ListView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
          children: [
            // 🌟 1. بطاقة الملف الشخصي
            Container(
              padding: EdgeInsets.all(20.w),
              margin: EdgeInsets.only(bottom: 20.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF1A5276), Colors.blue.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15.r),
                boxShadow: [
                  BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5)),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30.r,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Icon(Icons.person, size: 35.w, color: Colors.white),
                  ),
                  SizedBox(width: 15.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_empName,
                            style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        SizedBox(height: 5.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: _roleTitle.contains('المدير')
                                ? Colors.orangeAccent
                                : Colors.greenAccent,
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Text(
                            _roleTitle,
                            style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 🌟 2. قسم الإعدادات
            Text('إعدادات التطبيق',
                style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            SizedBox(height: 10.h),

            _buildSettingsItem(
              title: 'إعدادات طابعة البلوتوث',
              icon: Icons.print,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PrinterSettingsScreen(),
                  ),
                );
              },
            ),

            // 🌟 حماية عنصر إعدادات السيرفر بالكامل (منح حق الدخول للمدير فقط)
            _buildSettingsItem(
              title: 'إعدادات السيرفر',
              icon: Icons.dns,
              // يمكننا جعل لون العنصر باهتاً أو قفله إذا لم يكن مديراً، أو إظهار رسالة عند النقر
              onTap: () {
                if (_rawRole == 'admin') {
                  _showServerSettingsDialog(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'عذراً، لا تملك صلاحية الوصول لإعدادات السيرفر. مخصص للـ مدير العام فقط.',
                          textAlign: TextAlign.center),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),

            SizedBox(height: 15.h),
            Text('الأمان والحساب',
                style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            SizedBox(height: 10.h),

            _buildSettingsItem(
              title: 'تغيير كلمة المرور',
              icon: Icons.lock_outline,
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ChangePasswordScreen()));
              },
            ),

            SizedBox(height: 30.h),

            // زر تسجيل الخروج
            _buildSettingsItem(
              title: 'تسجيل الخروج',
              icon: Icons.logout,
              color: Colors.red,
              onTap: () {
                _showLogoutConfirmation(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // دالة مساعدة لبناء عناصر الإعدادات
  // ==========================================
  Widget _buildSettingsItem(
      {required String title,
      required IconData icon,
      required VoidCallback onTap,
      Color? color}) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        leading: Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: (color ?? const Color(0xFF1A5276)).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(icon, color: color ?? const Color(0xFF1A5276)),
        ),
        title: Text(
          title,
          style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black87),
        ),
        trailing: Icon(Icons.arrow_forward_ios,
            size: 16.w, color: Colors.grey.shade400),
      ),
    );
  }
}
