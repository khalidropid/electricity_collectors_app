import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'dart:convert'; // 🌟 تمت الإضافة للتعامل مع الصلاحيات

// استدعاء الشاشات والمزودات
import '../features/change_password_screen.dart';
import '../features/dashboard_screen.dart';
import '../features/customer_search_screen.dart';
import '../features/reports_screen.dart';
import '../features/sync_screen.dart';
import '../features/settings_screen.dart';
import '../features/login_screen.dart';
import '../features/modification_request_screen.dart';
import '../providers/auth_provider.dart';
import '../core/utils/secure_storage_helper.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String _collectorName = 'جاري التحميل...';
  String _roleTitle = 'جاري التحميل...';
  int _currentEmpId = 1;

  // 🌟 متغيرات الصلاحيات
  Map<String, dynamic> _permissions = {};

  @override
  void initState() {
    super.initState();
    _loadCollectorData();
  }

  Future<void> _loadCollectorData() async {
    String? name = await SecureStorageHelper.getEmpName();
    String? empIdStr = await SecureStorageHelper.getEmpId();
    String? role = await SecureStorageHelper.getUserRole();

    // 🌟 جلب الصلاحيات من الذاكرة المخفية
    String? permsString = await SecureStorageHelper.getPermissions();

    if (mounted) {
      setState(() {
        _collectorName = name ?? 'مستخدم مجهول';

        if (role == 'admin') {
          _roleTitle = 'المدير العام - كافة الصلاحيات';
        } else {
          _roleTitle = 'متصل - نظام المحصلين';
        }

        if (empIdStr != null) {
          _currentEmpId = int.tryParse(empIdStr) ?? 1;
        }

        // 🌟 فك تشفير الصلاحيات وحفظها في المتغير
        if (permsString != null) {
          _permissions = jsonDecode(permsString);
        }
      });
    }
  }

  // ==========================================
  // نافذة تأكيد الخروج
  // ==========================================
  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r)),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.exit_to_app,
                      color: Colors.red, size: 28),
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
                onPressed: () => Navigator.of(dialogContext)
                    .pop(), // إغلاق النافذة فقط عند الإلغاء
                child: Text('إلغاء',
                    style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(); // إغلاق النافذة
                  _handleLogout(); // تنفيذ الخروج
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r)),
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
  // تنفيذ عملية الخروج والانتقال
  // ==========================================
  Future<void> _handleLogout() async {
    // نأخذ المزود قبل أي عملية انتظار (await) لضمان عدم فقدانه
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();

    if (!mounted) return;

    // مسح جميع الشاشات السابقة (بما فيها القائمة الجانبية) والانتقال لشاشة الدخول
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🌟 قراءة حالة الصلاحيات للتحكم بالظهور (تكون مسموحة افتراضياً إذا لم تُسحب)
    bool canAddPayment = _permissions['can_add_payment'] ?? true;
    bool canAddReading = _permissions['can_add_reading'] ?? true;
    bool canRequestMod =
        _permissions['can_request_modification'] ?? true; // صلاحية تعديل الطلب
    bool hideSearch = _permissions['hide_search_icon'] == 1 ||
        _permissions['hide_search_icon'] == true;

    return Drawer(
      backgroundColor: const Color(0xFFF4F7FB),
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF144563),
                  Color(0xFF1A5276),
                  Color(0xFF2980B9)
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
            accountName: Text(
              _collectorName,
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
            accountEmail: Row(
              children: [
                Container(
                    width: 8.w,
                    height: 8.w,
                    decoration: BoxDecoration(
                        color: _roleTitle.contains('المدير')
                            ? Colors.orangeAccent
                            : Colors.greenAccent,
                        shape: BoxShape.circle)),
                SizedBox(width: 6.w),
                Text(_roleTitle,
                    style: TextStyle(fontSize: 13.sp, color: Colors.white70)),
              ],
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Icon(Icons.person, size: 40.w, color: Colors.white),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
              children: [
                _buildDrawerItem('الرئيسية', Icons.home_rounded, context),
                Divider(height: 20.h, color: Colors.grey.shade300),

                // 🌟 إخفاء البحث من القائمة الجانبية
                if (!hideSearch)
                  _buildDrawerItem(
                      'بحث المشتركين', Icons.search_rounded, context),
                // 🌟 إخفاء زر "طلب تعديل بيانات" بناءً على الصلاحية
                if (canRequestMod)
                  _buildDrawerItem(
                      'طلب تعديل بيانات', Icons.edit_document, context),

                // 🌟 إخفاء زر "القراءات" بناءً على الصلاحية
                if (canAddReading)
                  _buildDrawerItem('القراءات', Icons.speed_rounded, context),

                // 🌟 إخفاء زر "التحصيل" بناءً على الصلاحية
                if (canAddPayment)
                  _buildDrawerItem(
                      'التحصيل', Icons.account_balance_wallet_rounded, context),

                _buildDrawerItem('التقارير', Icons.bar_chart_rounded, context),
                _buildDrawerItem('المزامنة', Icons.sync_rounded, context),

                Divider(height: 20.h, color: Colors.grey.shade300),

                _buildDrawerItem('الإعدادات', Icons.settings_rounded, context),
                _buildDrawerItem(
                    'تغيير كلمة السر', Icons.lock_outline_rounded, context),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 15.h),
            color: Colors.white,
            child: ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.r)),
              tileColor: Colors.red.withOpacity(0.05),
              leading: const Icon(Icons.logout_rounded, color: Colors.red),
              title: Text('تسجيل الخروج',
                  style: TextStyle(
                      fontSize: 15.sp,
                      color: Colors.red,
                      fontWeight: FontWeight.bold)),
              onTap: () {
                _showLogoutConfirmation();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(String title, IconData icon, BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      leading: Icon(icon, color: const Color(0xFF1A5276), size: 24.w),
      title: Text(
        title,
        style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.bold,
            color: Colors.black87),
      ),
      hoverColor: Colors.blue.shade50,
      onTap: () {
        Navigator.pop(context);

        if (title == 'الرئيسية') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
                builder: (context) => DashboardScreen(empId: _currentEmpId)),
            (route) => false,
          );
        } else if (title == 'بحث المشتركين' ||
            title == 'القراءات' ||
            title == 'التحصيل') {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      CustomerSearchScreen(empId: _currentEmpId)));
        } else if (title == 'طلب تعديل بيانات') {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ModificationRequestScreen()));
        } else if (title == 'التقارير') {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const ReportsScreen()));
        } else if (title == 'المزامنة') {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => SyncScreen(empId: _currentEmpId)));
        } else if (title == 'الإعدادات') {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()));
        } else if (title == 'تغيير كلمة السر') {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ChangePasswordScreen()));
        }
      },
    );
  }
}
