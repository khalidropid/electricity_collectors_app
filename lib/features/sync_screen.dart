import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../database/database_helper.dart';
import '../providers/sync_provider.dart';
import '../core/utils/secure_storage_helper.dart';

class SyncScreen extends StatefulWidget {
  final int empId;

  const SyncScreen({super.key, required this.empId});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  // عدادات البيانات المعلقة
  int _pendingReadingsCount = 0;
  int _pendingPaymentsCount = 0;
  int _pendingModRequestsCount = 0;
  int _pendingInvoicesCount = 0;

  String _lastSyncTime = 'لم تتم المزامنة بعد';

  @override
  void initState() {
    super.initState();
    _loadPendingData();
  }

  // 1. جلب البيانات المعلقة والوقت من الذاكرة المحلية
  Future<void> _loadPendingData() async {
    final db = await DatabaseHelper().database;

    final readings = await db
        .query('app_readings', where: 'status = ?', whereArgs: ['pending']);
    final payments = await db
        .query('app_collections', where: 'status = ?', whereArgs: ['pending']);
    final modRequests = await db.query('modification_requests',
        where: 'status = ?', whereArgs: ['pending']);
    final invoices = await db
        .query('app_invoices', where: 'sync_status = ?', whereArgs: [0]);

    String? time = await SecureStorageHelper.getLastSyncTime();

    if (mounted) {
      setState(() {
        _pendingReadingsCount = readings.length;
        _pendingPaymentsCount = payments.length;
        _pendingModRequestsCount = modRequests.length;
        _pendingInvoicesCount = invoices.length;

        if (time != null && time.isNotEmpty) {
          _lastSyncTime = time;
        }
      });
    }
  }

  // 2. دالة تنزيل البيانات (Pull)
  Future<void> _startPull() async {
    if (_pendingReadingsCount > 0 ||
        _pendingPaymentsCount > 0 ||
        _pendingModRequestsCount > 0 ||
        _pendingInvoicesCount > 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'تنبيه: يجب رفع البيانات المعلقة أولاً قبل تحديث السجلات.',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    final syncProvider = Provider.of<SyncProvider>(context, listen: false);
    bool pullSuccess = await syncProvider.pullData(widget.empId);

    // إعادة تحميل العدادات والوقت بعد انتهاء التنزيل
    await _loadPendingData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(syncProvider.syncMessage),
          backgroundColor: pullSuccess ? Colors.green : Colors.red,
        ),
      );
    }
  }

  // 3. دالة رفع البيانات المعلقة (Push)
  Future<void> _startPush() async {
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);

    if (_pendingReadingsCount == 0 &&
        _pendingPaymentsCount == 0 &&
        _pendingModRequestsCount == 0 &&
        _pendingInvoicesCount == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('لا توجد بيانات جديدة معلقة للرفع.'),
              backgroundColor: Colors.orange),
        );
      }
      return;
    }

    bool pushSuccess = await syncProvider.pushData(widget.empId);

    // 🌟 تحديث العدادات فوراً بعد الرفع لتتصفر في الشاشة
    await _loadPendingData();

    if (pushSuccess) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم رفع البيانات الجديدة للسيرفر بنجاح ✓'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(syncProvider.syncMessage),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🌟 استخدام Consumer للاستماع لتغيرات SyncProvider بشكل آمن تماماً بدون أخطاء الـ dispose
    return Consumer<SyncProvider>(
      builder: (context, syncProvider, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: const Color(0xFFF5F7FA),
            appBar: AppBar(
              backgroundColor: const Color(0xFF1A5276),
              title: Text(
                'مركز المزامنة',
                style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              centerTitle: true,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // بطاقة حالة المزامنة التلقائية والوقت
                  Container(
                    padding: EdgeInsets.all(15.w),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.cloud_sync,
                            color: Colors.blue.shade700, size: 35.w),
                        SizedBox(width: 15.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'المزامنة التلقائية مفعلة',
                                style: TextStyle(
                                    color: Colors.blue.shade800,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.sp),
                              ),
                              SizedBox(height: 5.h),
                              Text(
                                'آخر تحديث: $_lastSyncTime',
                                style: TextStyle(
                                    color: Colors.blue.shade600,
                                    fontSize: 12.sp),
                                textDirection: TextDirection.ltr,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),

                  Text(
                    'البيانات المعلقة في ذاكرة الهاتف',
                    style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20.h),

                  Expanded(
                    child: ListView(
                      children: [
                        _buildSyncCard(
                            title: 'قراءات العدادات',
                            count: _pendingReadingsCount,
                            icon: Icons.speed,
                            color: Colors.orange),
                        SizedBox(height: 12.h),
                        _buildSyncCard(
                            title: 'التحصيلات النقدية',
                            count: _pendingPaymentsCount,
                            icon: Icons.monetization_on_outlined,
                            color: Colors.green),
                        SizedBox(height: 12.h),
                        _buildSyncCard(
                            title: 'السندات المصدرة',
                            count: _pendingInvoicesCount,
                            icon: Icons.receipt_long,
                            color: Colors.teal),
                        SizedBox(height: 12.h),
                        _buildSyncCard(
                            title: 'طلبات التعديل',
                            count: _pendingModRequestsCount,
                            icon: Icons.edit_document,
                            color: Colors.blue),
                      ],
                    ),
                  ),

                  // رسالة السيرفر إن وجدت
                  if (syncProvider.syncMessage.isNotEmpty) ...[
                    Text(
                      syncProvider.syncMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10.h),
                  ],

                  // أزرار المزامنة اليدوية
                  Row(
                    children: [
                      // زر الرفع
                      Expanded(
                        child: SizedBox(
                          height: 55.h,
                          child: ElevatedButton(
                            onPressed:
                                syncProvider.isSyncing ? null : _startPush,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              disabledBackgroundColor: Colors.grey.shade400,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r)),
                            ),
                            child: syncProvider.isPushing
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.cloud_upload,
                                          color: Colors.white),
                                      SizedBox(width: 8.w),
                                      Text('رفع البيانات',
                                          style: TextStyle(
                                              fontSize: 15.sp,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white)),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      SizedBox(width: 15.w),
                      // زر التنزيل
                      Expanded(
                        child: SizedBox(
                          height: 55.h,
                          child: ElevatedButton(
                            onPressed:
                                syncProvider.isSyncing ? null : _startPull,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A5276),
                              disabledBackgroundColor: Colors.grey.shade400,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r)),
                            ),
                            child: syncProvider.isPulling
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.cloud_download,
                                          color: Colors.white),
                                      SizedBox(width: 8.w),
                                      Text('سحب الجديد',
                                          style: TextStyle(
                                              fontSize: 15.sp,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white)),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSyncCard(
      {required String title,
      required int count,
      required IconData icon,
      required Color color}) {
    return Container(
      padding: EdgeInsets.all(15.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28.w),
          ),
          SizedBox(width: 15.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 15.sp, fontWeight: FontWeight.bold)),
                SizedBox(height: 5.h),
                Text(
                  count > 0 ? 'يوجد $count بحاجة للرفع' : 'متزامن بالكامل',
                  style: TextStyle(
                      fontSize: 13.sp,
                      color: count > 0
                          ? Colors.red.shade600
                          : Colors.green.shade600,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          if (count > 0)
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade400),
          if (count == 0)
            Icon(Icons.check_circle, color: Colors.green.shade400),
        ],
      ),
    );
  }
}
