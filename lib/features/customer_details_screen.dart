import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:convert'; // 🌟 تمت الإضافة للتعامل مع الصلاحيات

import '../models/customer.dart';
import '../database/database_helper.dart';
import 'add_reading_screen.dart';
import 'payment_screen.dart';
import '../widgets/app_drawer.dart';
import 'modification_request_screen.dart';
import '../core/utils/secure_storage_helper.dart'; // 🌟 جلب ملف التخزين لقراءة الصلاحيات

class CustomerDetailsScreen extends StatefulWidget {
  final Customer customer;
  final int empId;

  const CustomerDetailsScreen({
    super.key,
    required this.customer,
    this.empId = 1,
  });

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  bool _isLoading = true;
  double _consumption = 0.0;
  double _costRest = 0.0;
  double _latesCost = 0.0;
  double _totalFactorh = 0.0;
  String _monthName = '';

  // 🌟 متغيرات الصلاحيات
  Map<String, dynamic> _permissions = {};
  bool _isLoadingPermissions = true;

  @override
  void initState() {
    super.initState();
    _loadPermissions(); // 🌟 استدعاء دالة الصلاحيات أولاً
    _fetchCustomerChitsLocal();
  }

  // 🌟 دالة جلب الصلاحيات من الذاكرة المخفية
  Future<void> _loadPermissions() async {
    String? permsString = await SecureStorageHelper.getPermissions();
    if (permsString != null && mounted) {
      setState(() {
        _permissions = jsonDecode(permsString);
        _isLoadingPermissions = false;
      });
    } else {
      if (mounted) setState(() => _isLoadingPermissions = false);
    }
  }

  // ==========================================
  // دالة جلب الفواتير والاستهلاك من قاعدة البيانات المحلية
  // ==========================================
  Future<void> _fetchCustomerChitsLocal() async {
    try {
      final db = await DatabaseHelper().database;

      final List<Map<String, dynamic>> chits = await db.query(
        'Take_up_Chits',
        where: 'id_customer = ?',
        whereArgs: [widget.customer.idCustomer],
        orderBy: 'id_takeup_chit DESC',
        limit: 1,
      );

      if (chits.isNotEmpty) {
        final data = chits.first;

        double nowRead = (data['now_reead'] is num)
            ? (data['now_reead'] as num).toDouble()
            : 0.0;
        double lastRead = (data['last_read'] is num)
            ? (data['last_read'] as num).toDouble()
            : 0.0;

        if (mounted) {
          setState(() {
            _consumption = nowRead - lastRead;
            _costRest = (data['cost_rest'] is num)
                ? (data['cost_rest'] as num).toDouble()
                : 0.0;
            _latesCost = (data['lates_cost'] is num)
                ? (data['lates_cost'] as num).toDouble()
                : 0.0;
            _totalFactorh = (data['total_cost_fatoerh'] is num)
                ? (data['total_cost_fatoerh'] as num).toDouble()
                : 0.0;
            _monthName = data['Month_name']?.toString() ?? '';
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching local chits: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPermissions) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 🌟 قراءة الصلاحيات وتجهيزها للواجهة (الافتراضي true لو لم تُسحب)
    bool canAddPayment = _permissions['can_add_payment'] ?? true;
    bool canAddReading = _permissions['can_add_reading'] ?? true;
    bool canRequestMod = _permissions['can_request_modification'] ?? true;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        drawer: const AppDrawer(),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A5276),
          title: Text(
            'تفاصيل المشترك',
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
            // 🌟 إخفاء أيقونة طلب التعديل إذا سُحبت الصلاحية
            if (canRequestMod)
              IconButton(
                icon: const Icon(Icons.edit_document, color: Colors.white),
                tooltip: 'طلب تعديل بيانات المشترك',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ModificationRequestScreen(
                        initialSubNo: widget.customer.idCustomer.toString(),
                        initialName: widget.customer.nameCustomer,
                        initialAddress: widget.customer.streetCustomer ??
                            widget.customer.addressCustomer ??
                            '',
                      ),
                    ),
                  );
                },
              ),
            IconButton(
                icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                onPressed: () => Navigator.pop(context)),
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15.r),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5)),
                  ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 35.r,
                      backgroundColor: const Color(0xFF1A5276).withOpacity(0.1),
                      child: Icon(Icons.person,
                          size: 40.w, color: const Color(0xFF1A5276)),
                    ),
                    SizedBox(height: 15.h),
                    Text(widget.customer.nameCustomer,
                        style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                    SizedBox(height: 5.h),
                    Divider(height: 30.h, color: Colors.grey.shade200),
                    _buildDetailRow(Icons.confirmation_number_outlined,
                        'رقم المشترك', widget.customer.idCustomer.toString()),
                    _buildDetailRow(Icons.speed, 'رقم العداد',
                        widget.customer.numAddaad?.toString() ?? 'غير متوفر'),
                    _buildDetailRow(Icons.phone_outlined, 'رقم الهاتف',
                        widget.customer.numPhone?.toString() ?? 'غير متوفر'),
                    _buildDetailRow(
                        Icons.location_on_outlined,
                        'العنوان/الشارع',
                        widget.customer.streetCustomer ??
                            widget.customer.addressCustomer ??
                            'غير متوفر'),
                    Divider(height: 20.h, color: Colors.grey.shade200),
                    _isLoading
                        ? Padding(
                            padding: EdgeInsets.symmetric(vertical: 15.h),
                            child: const CircularProgressIndicator(),
                          )
                        : Column(
                            children: [
                              if (_monthName.isNotEmpty)
                                _buildDetailRow(Icons.calendar_month,
                                    'دورة الفاتورة', _monthName,
                                    valueColor: Colors.indigo),
                              _buildDetailRow(
                                  Icons.bolt, 'الاستهلاك', '$_consumption وحدة',
                                  valueColor: Colors.blue.shade700),
                              _buildDetailRow(Icons.receipt, 'إجمالي الفاتورة',
                                  '$_totalFactorh ريال',
                                  valueColor: Colors.black87),
                              _buildDetailRow(
                                  Icons.account_balance_wallet_outlined,
                                  'المتبقي عليه',
                                  '$_costRest ريال',
                                  valueColor: Colors.orange.shade800),
                              _buildDetailRow(Icons.money_off_outlined,
                                  'المتأخرات', '$_latesCost ريال',
                                  valueColor: Colors.red.shade700),
                            ],
                          ),
                    Divider(height: 20.h, color: Colors.grey.shade200),
                    _buildDetailRow(
                        Icons.check_circle_outline,
                        'حالة العداد',
                        widget.customer.takeReading == 1
                            ? 'تمت القراءة'
                            : 'لم يُقرأ بعد',
                        valueColor: widget.customer.takeReading == 1
                            ? Colors.green.shade700
                            : Colors.orange.shade700),
                  ],
                ),
              ),
              SizedBox(height: 30.h),

              // 🌟 الصف الخاص بالأزرار مع شرط إخفاء/إظهار ذكي يعتمد على الصلاحيات
              if (canAddReading || canAddPayment)
                Row(
                  children: [
                    if (canAddReading)
                      Expanded(
                        child: _buildActionButton(
                          context,
                          title: 'تسجيل قراءة',
                          icon: Icons.speed,
                          color: Colors.orange,
                          onTap: () async {
                            bool? updated = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => AddReadingScreen(
                                        customer: widget.customer)));
                            if (updated == true) Navigator.pop(context, true);
                          },
                        ),
                      ),
                    if (canAddReading && canAddPayment) SizedBox(width: 15.w),
                    if (canAddPayment)
                      Expanded(
                        child: _buildActionButton(
                          context,
                          title: 'تحصيل فاتورة',
                          icon: Icons.monetization_on_outlined,
                          color: Colors.green,
                          onTap: () async {
                            bool? updated = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => AddPaymentScreen(
                                        customer: widget.customer,
                                        empId: widget.empId)));
                            if (updated == true) Navigator.pop(context, true);
                          },
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        children: [
          Icon(icon, size: 20.w, color: Colors.grey.shade500),
          SizedBox(width: 10.w),
          Text(label,
              style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context,
      {required String title,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 15.h),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28.w),
            SizedBox(height: 8.h),
            Text(title,
                style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }
}
