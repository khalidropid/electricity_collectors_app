import 'dart:async'; // 🌟 تمت الإضافة: لاستخدام المؤقت (Timer)
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'dart:convert';

import 'customer_search_screen.dart';
import 'reports_screen.dart';
import 'sync_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'invoices_list_screen.dart';
import 'modification_request_screen.dart';
import 'manager_reports_screen.dart';

import '../providers/auth_provider.dart';
import '../providers/sync_provider.dart';
import '../database/database_helper.dart';
import '../core/utils/secure_storage_helper.dart';
import '../widgets/app_drawer.dart';

class DashboardScreen extends StatefulWidget {
  final int? empId;
  const DashboardScreen({super.key, this.empId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _collectorName = 'جاري التحميل...';
  int? _currentEmpId;
  bool _canPayAll = false;

  Map<String, dynamic> _permissions = {};

  // 🌟 تمت الإضافة: متغير المؤقت اللحظي
  Timer? _instantCheckTimer;

  @override
  void initState() {
    super.initState();
    _currentEmpId = widget.empId;
    _loadData();
    _silentPermissionCheck();

    // 🌟 تمت الإضافة: تشغيل الفحص اللحظي كل 10 ثوانٍ بصمت
    _instantCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _silentPermissionCheck();
    });
  }

  // 🌟 تمت الإضافة: إيقاف المؤقت عند الخروج من الشاشة لمنع استهلاك الموارد
  @override
  void dispose() {
    _instantCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _silentPermissionCheck() async {
    try {
      String? deviceId = await SecureStorageHelper.getDeviceId();
      if (deviceId == null) return;

      final dio = Dio();
      final response = await dio.post(
        'https://saleh.me.ye/api/check_status.php',
        data: {'device_id': deviceId},
      );

      if (response.statusCode == 200) {
        final data = response.data;

        if (data['force_logout'] == true) {
          // إيقاف المؤقتات لتجنب الأخطاء عند الطرد
          _instantCheckTimer?.cancel();
          Provider.of<SyncProvider>(context, listen: false).stopAutoSync();
          await SecureStorageHelper.clearAll();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(data['message'] ?? 'تم إيقاف حسابك من الإدارة'),
                  backgroundColor: Colors.red.shade700),
            );
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          }
          return;
        }

        if (data['success'] == true && data['permissions'] != null) {
          String updatedPermissions = jsonEncode(data['permissions']);
          await SecureStorageHelper.savePermissions(updatedPermissions);
          if (mounted) {
            setState(() {
              _permissions = data['permissions'];
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Silent check failed: $e");
    }
  }

  Future<void> _loadData() async {
    String? name = await SecureStorageHelper.getEmpName();
    String? canPayAllStr = await SecureStorageHelper.getCanPayAll();
    String? permsString = await SecureStorageHelper.getPermissions();

    if (_currentEmpId == null) {
      String? savedEmpId = await SecureStorageHelper.getEmpId();
      if (savedEmpId != null) {
        _currentEmpId = int.tryParse(savedEmpId);
      }
    }

    if (mounted) {
      setState(() {
        _collectorName = name ?? 'متحصل مجهول';
        _canPayAll = (canPayAllStr == '1');
        if (permsString != null) {
          _permissions = jsonDecode(permsString);
        }
      });

      if (_currentEmpId != null) {
        final syncProvider = Provider.of<SyncProvider>(context, listen: false);

        Future.delayed(const Duration(seconds: 1), () async {
          if (mounted) {
            debugPrint('🔄 بدء المزامنة الذكية الفورية عند فتح لوحة التحكم...');
            bool pushSuccess = await syncProvider.pushData(_currentEmpId!);
            if (pushSuccess) {
              await syncProvider.pullData(_currentEmpId!);
            }
          }
        });

        syncProvider.startAutoSync(_currentEmpId!, intervalMinutes: 10);
      }
    }
  }

  Future<void> _handleLogoutPressed() async {
    final db = await DatabaseHelper().database;
    final readings = await db
        .query('app_readings', where: 'status = ?', whereArgs: ['pending']);
    final payments = await db
        .query('app_collections', where: 'status = ?', whereArgs: ['pending']);
    final modRequests = await db.query('modification_requests',
        where: 'status = ?', whereArgs: ['pending']);
    final invoices = await db
        .query('app_invoices', where: 'sync_status = ?', whereArgs: [0]);

    int pendingCount = readings.length +
        payments.length +
        modRequests.length +
        invoices.length;

    if (pendingCount > 0) {
      _showPendingDataWarning(pendingCount);
    } else {
      _showLogoutConfirmation();
    }
  }

  void _showPendingDataWarning(int count) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
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
                      color: Colors.orange.withOpacity(0.2),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.sync_problem,
                      color: Colors.orange, size: 28),
                ),
                SizedBox(width: 10.w),
                Text('تنبيه هام!',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18.sp,
                        color: Colors.orange.shade800)),
              ],
            ),
            content: Text(
                'يوجد لديك ($count) عمليات لم يتم رفعها للسيرفر.\nيرجى مزامنتها أولاً قبل تسجيل الخروج لضمان عدم ضياعها.',
                style: TextStyle(fontSize: 15.sp, height: 1.6)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إلغاء',
                      style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              SyncScreen(empId: _currentEmpId ?? 1)));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r)),
                ),
                child: const Text('الذهاب للمزامنة',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r)),
            title: Row(
              children: [
                const Icon(Icons.exit_to_app, color: Colors.red, size: 28),
                SizedBox(width: 10.w),
                Text('تسجيل الخروج',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18.sp)),
              ],
            ),
            content: Text('هل أنت متأكد أنك تريد تسجيل الخروج من النظام؟',
                style: TextStyle(fontSize: 15.sp)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _logout();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r)),
                ),
                child:
                    const Text('خروج', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _logout() async {
    _instantCheckTimer?.cancel();
    Provider.of<SyncProvider>(context, listen: false).stopAutoSync();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        drawer: const AppDrawer(),
        appBar: AppBar(
          backgroundColor: const Color(0xFF144563),
          elevation: 0,
          title: Text('لوحة التحكم',
              style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
                icon: const Icon(Icons.power_settings_new),
                onPressed: _handleLogoutPressed)
          ],
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 25.w, vertical: 30.h),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF144563),
                    Color(0xFF1A5276),
                    Color(0xFF2980B9)
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30.r),
                    bottomRight: Radius.circular(30.r)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5))
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(3.w),
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: CircleAvatar(
                        radius: 32.r,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: Icon(Icons.person,
                            size: 40.w, color: const Color(0xFF144563))),
                  ),
                  SizedBox(width: 15.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_collectorName,
                          style: TextStyle(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      SizedBox(height: 5.h),
                      Row(
                        children: [
                          Container(
                              width: 10.w,
                              height: 10.w,
                              decoration: const BoxDecoration(
                                  color: Colors.greenAccent,
                                  shape: BoxShape.circle)),
                          SizedBox(width: 5.w),
                          Text('النظام متصل',
                              style: TextStyle(
                                  fontSize: 12.sp, color: Colors.white70)),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (_canPayAll)
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.star_rounded,
                              color: Colors.white, size: 18.w),
                          SizedBox(width: 4.w),
                          Text(
                            'تسديد عام',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 30.h),
            Expanded(
              child: GridView.count(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                crossAxisCount: 3,
                crossAxisSpacing: 15.w,
                mainAxisSpacing: 15.h,
                childAspectRatio: 0.85,
                children: [
// 🌟 إخفاء زر البحث إذا كانت قيمة hide_search_icon تساوي 1 أو true
                  if (_permissions['hide_search_icon'] != 1 &&
                      _permissions['hide_search_icon'] != true)
                    _buildMenuItem('بحث المشتركين', Icons.search_rounded,
                        Colors.blue, context),
                  if (_permissions['can_add_payment'] ?? true)
                    _buildMenuItem(
                        'التحصيل',
                        Icons.account_balance_wallet_rounded,
                        Colors.green,
                        context),
                  if (_permissions['can_add_reading'] ?? true)
                    _buildMenuItem('القراءات', Icons.speed_rounded,
                        Colors.orange, context),
                  _buildMenuItem('المزامنة', Icons.sync_rounded,
                      const Color(0xFF1A5276), context),
                  _buildMenuItem('التقارير', Icons.bar_chart_rounded,
                      Colors.indigo, context),
                  _buildMenuItem('السندات', Icons.receipt_long_rounded,
                      Colors.teal, context),
                  _buildMenuItem(
                      'طلب تعديل', Icons.edit_document, Colors.purple, context),
                  if (_currentEmpId == 0)
                    _buildMenuItem(
                        'تقارير المشرف',
                        Icons.admin_panel_settings_rounded,
                        Colors.deepOrange,
                        context),
                  _buildMenuItem('الإعدادات', Icons.settings_rounded,
                      Colors.blueGrey, context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
      String title, IconData icon, Color color, BuildContext context) {
    return InkWell(
      onTap: () {
        if (title == 'بحث المشتركين' ||
            title == 'القراءات' ||
            title == 'التحصيل') {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      CustomerSearchScreen(empId: _currentEmpId ?? 1)));
        } else if (title == 'التقارير') {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const ReportsScreen()));
        } else if (title == 'المزامنة') {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => SyncScreen(empId: _currentEmpId ?? 1)));
        } else if (title == 'السندات') {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const InvoicesListScreen()));
        } else if (title == 'طلب تعديل') {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ModificationRequestScreen()));
        } else if (title == 'تقارير المشرف') {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ManagerReportsScreen()));
        } else if (title == 'الإعدادات') {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()));
        }
      },
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.1),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28.w),
            ),
            SizedBox(height: 12.h),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}
