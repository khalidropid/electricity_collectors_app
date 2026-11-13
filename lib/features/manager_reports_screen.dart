import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart' hide TextDirection;

// 🌟 مكتبات تصدير الإكسل للهواتف
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/utils/secure_storage_helper.dart';
import '../widgets/app_drawer.dart';

class ManagerReportsScreen extends StatefulWidget {
  const ManagerReportsScreen({super.key});

  @override
  State<ManagerReportsScreen> createState() => _ManagerReportsScreenState();
}

class _ManagerReportsScreenState extends State<ManagerReportsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _collectorsList = [];
  int _selectedCollectorId = 0; // القيمة 0 تعني "الكل" للمنسدلة الرئيسية
  int _activeSubCollectorId = 0; // تبويب المحصل الفرعي

  List<dynamic> _collectorPayments = [];
  List<dynamic> _collectorReadings = [];
  double _collectorTotalAmount = 0.0;

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  int _currentTabIndex = 0; // 0: سندات، 1: قراءات

  Map<String, dynamic> _permissions = {};
  final String stationName = "محطة الحسن لتوليد الطاقة الكهربائية";

  @override
  void initState() {
    super.initState();
    _fetchCollectorsAndReport();
    _loadPermissions();
  }

  // 🌟 تحميل الصلاحيات
  Future<void> _loadPermissions() async {
    String? permsStr = await SecureStorageHelper.getPermissions();
    if (permsStr != null && mounted) {
      setState(() {
        _permissions = jsonDecode(permsStr);
      });
    }
  }

  Future<void> _fetchCollectorsAndReport() async {
    setState(() {
      _isLoading = true;
      _activeSubCollectorId = 0;
    });

    try {
      final dio = Dio();
      dio.options.validateStatus = (status) => true;

      String formattedStart = DateFormat('yyyy-MM-dd').format(_startDate);
      String formattedEnd = DateFormat('yyyy-MM-dd').format(_endDate);

      final response = await dio.post(
        'https://saleh.me.ye/api/manager_collector_report.php',
        data: {
          'emp_id': _selectedCollectorId == 0 ? null : _selectedCollectorId,
          'start_date': formattedStart,
          'end_date': formattedEnd,
        },
        options: Options(headers: {
          'App-Secret-Key': 'Saleh#2026@Secure',
        }),
      );

      if (response.statusCode == 200) {
        var responseData = response.data;
        if (responseData is String) {
          try {
            responseData = jsonDecode(responseData);
          } catch (_) {}
        }

        if (responseData is Map && responseData['success'] == true) {
          List rawCollectors = responseData['collectors'] ?? [];

          Map<int, Map<String, dynamic>> uniqueMap = {};
          for (var c in rawCollectors) {
            int empId = int.tryParse(c['id_emp']?.toString() ?? '0') ?? 0;
            if (empId != 0) {
              uniqueMap[empId] = {
                'emp_id': empId,
                'emp_name': c['name_emp']?.toString() ?? 'متحصل بدون اسم',
                'total_customers':
                    int.tryParse(c['total_customers']?.toString() ?? '0') ?? 0,
                'read_meters':
                    int.tryParse(c['read_meters']?.toString() ?? '0') ?? 0,
                'unread_meters':
                    int.tryParse(c['unread_meters']?.toString() ?? '0') ?? 0,
                'assigned_areas':
                    c['assigned_areas']?.toString() ?? 'غير محددة',
              };
            }
          }

          setState(() {
            _collectorsList = uniqueMap.values.toList();
            _collectorPayments = responseData['payments'] ?? [];
            _collectorReadings = responseData['readings'] ?? [];

            var totalRaw = responseData['total_amount'];
            _collectorTotalAmount = totalRaw != null
                ? double.tryParse(totalRaw.toString()) ?? 0.0
                : 0.0;
          });
        }
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Theme(
            data: ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF144563),
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fetchCollectorsAndReport();
    }
  }

  List<dynamic> _getFilteredData(List<dynamic> sourceData) {
    if (_selectedCollectorId != 0 || _activeSubCollectorId == 0) {
      return sourceData;
    }
    String targetName = _collectorsList.firstWhere(
        (c) => c['emp_id'] == _activeSubCollectorId,
        orElse: () => {'emp_name': ''})['emp_name'];

    return sourceData
        .where((item) => item['collector_name'] == targetName)
        .toList();
  }

  Map<String, dynamic> _getCurrentProgressStats() {
    int targetId = _selectedCollectorId != 0
        ? _selectedCollectorId
        : _activeSubCollectorId;

    if (targetId == 0) {
      int totalCustomers = 0;
      int totalRead = 0;
      int totalUnread = 0;
      for (var c in _collectorsList) {
        totalCustomers += (c['total_customers'] as int? ?? 0);
        totalRead += (c['read_meters'] as int? ?? 0);
        totalUnread += (c['unread_meters'] as int? ?? 0);
      }
      return {
        'total': totalCustomers,
        'read': totalRead,
        'unread': totalUnread,
        'areas': 'كافة مناطق التغطية الموزعة',
      };
    } else {
      var collector = _collectorsList.firstWhere((c) => c['emp_id'] == targetId,
          orElse: () => {
                'total_customers': 0,
                'read_meters': 0,
                'unread_meters': 0,
                'assigned_areas': 'غير متوفر'
              });
      return {
        'total': collector['total_customers'],
        'read': collector['read_meters'],
        'unread': collector['unread_meters'],
        'areas': collector['assigned_areas'],
      };
    }
  }

  // ==========================================
  // 🌟 دالة تصدير الإكسل الشاملة (السندات + القراءات + فصل المحصلين)
  // ==========================================
  Future<void> _exportToExcel() async {
    try {
      var excel = Excel.createExcel();
      String sheetName = 'تقرير الأداء الشامل';
      excel.rename('Sheet1', sheetName);
      Sheet sheetObject = excel[sheetName];

      List<dynamic> filteredPayments = _getFilteredData(_collectorPayments);
      List<dynamic> filteredReadings = _getFilteredData(_collectorReadings);

      // 1. ترويسة التقرير
      sheetObject.appendRow([TextCellValue(stationName)]);
      sheetObject
          .appendRow([TextCellValue('تقرير أداء وتحصيل المحصلين المفصل')]);
      sheetObject.appendRow([
        TextCellValue(
            'الفترة من: ${DateFormat('yyyy/MM/dd').format(_startDate)} إلى: ${DateFormat('yyyy/MM/dd').format(_endDate)}')
      ]);
      sheetObject.appendRow([TextCellValue('')]);

      // 2. جدول تفاصيل سندات التحصيل (مفصولة بأسماء المحصلين)
      sheetObject
          .appendRow([TextCellValue('=== أولاً: تفاصيل سندات التحصيل ===')]);
      if (filteredPayments.isEmpty) {
        sheetObject.appendRow(
            [TextCellValue('لا توجد سندات تحصيل مسجلة في هذه الفترة')]);
      } else {
        sheetObject.appendRow([
          TextCellValue('رقم السند'),
          TextCellValue('اسم المحصل'),
          TextCellValue('اسم المشترك'),
          TextCellValue('رقم المشترك'),
          TextCellValue('المبلغ (ريال)'),
          TextCellValue('طريقة الدفع'),
          TextCellValue('تاريخ السداد')
        ]);

        for (var payment in filteredPayments.reversed) {
          String receiptNo = payment['receipt_no']?.toString() ?? '---';
          String collectorName =
              payment['collector_name']?.toString() ?? 'غير معروف';
          String customerName = payment['customer_name'] ??
              payment['id_customer']?.toString() ??
              '';
          String customerId = payment['id_customer']?.toString() ?? '';
          double amt =
              double.tryParse(payment['amount']?.toString() ?? '0') ?? 0.0;
          String paymentMethod =
              payment['payment_method']?.toString() ?? 'نقدي';
          String paymentDate = payment['payment_date'] ?? '';

          sheetObject.appendRow([
            TextCellValue(receiptNo),
            TextCellValue(collectorName),
            TextCellValue(customerName),
            TextCellValue(customerId),
            DoubleCellValue(amt),
            TextCellValue(paymentMethod),
            TextCellValue(paymentDate),
          ]);
        }
      }

      sheetObject.appendRow([TextCellValue('')]);

      // 3. جدول تفاصيل قراءات العدادات (مفصولة بأسماء المحصلين)
      sheetObject
          .appendRow([TextCellValue('=== ثانياً: تفاصيل قراءات العدادات ===')]);
      if (filteredReadings.isEmpty) {
        sheetObject
            .appendRow([TextCellValue('لا توجد قراءات مسجلة في هذه الفترة')]);
      } else {
        sheetObject.appendRow([
          TextCellValue('اسم المحصل'),
          TextCellValue('اسم المشترك'),
          TextCellValue('رقم المشترك'),
          TextCellValue('رقم العداد'),
          TextCellValue('قراءة العداد'),
          TextCellValue('تاريخ القراءة')
        ]);

        for (var reading in filteredReadings.reversed) {
          String collectorName =
              reading['collector_name']?.toString() ?? 'غير معروف';
          String customerName = reading['customer_name'] ??
              reading['id_customer']?.toString() ??
              '';
          String customerId = reading['id_customer']?.toString() ?? '';
          String meterNo = reading['num_addaad']?.toString() ?? '---';
          String readVal = reading['reading_value']?.toString() ??
              reading['now_reead']?.toString() ??
              '0';
          String readDate = reading['reading_date'] ?? '';

          sheetObject.appendRow([
            TextCellValue(collectorName),
            TextCellValue(customerName),
            TextCellValue(customerId),
            TextCellValue(meterNo),
            TextCellValue(readVal),
            TextCellValue(readDate),
          ]);
        }
      }

      // 4. حفظ ومشاركة الملف للهواتف
      var fileBytes = excel.save();
      if (fileBytes != null) {
        String fileName =
            "Manager_Report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx";

        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);

        await file.writeAsBytes(fileBytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تم إعداد ملف الإكسل المفصل بنجاح ✓'),
            backgroundColor: Colors.green,
          ));
        }

        await Share.shareXFiles([XFile(filePath)],
            text: 'تقرير أداء وتحصيل المحصلين الشامل');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ أثناء تصدير الإكسل: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }
  // ==========================================

  @override
  Widget build(BuildContext context) {
    bool collectorExists = _selectedCollectorId == 0 ||
        _collectorsList.any((c) => c['emp_id'] == _selectedCollectorId);
    int safeDropdownValue = collectorExists ? _selectedCollectorId : 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        appBar: AppBar(
          backgroundColor: const Color(0xFF144563),
          elevation: 0,
          title: Text(
            'تقارير أداء المحصلين',
            style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchCollectorsAndReport,
              tooltip: 'تحديث البيانات',
            ),
          ],
        ),
        body: Column(
          children: [
            // منطقة الفلاتر العلوية
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
              decoration: BoxDecoration(
                color: const Color(0xFF144563),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30.r),
                  bottomRight: Radius.circular(30.r),
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5))
                ],
              ),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 15.w),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: safeDropdownValue,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down,
                            color: Color(0xFF144563)),
                        items: [
                          DropdownMenuItem<int>(
                            value: 0,
                            child: Row(
                              children: [
                                const Icon(Icons.groups,
                                    color: Color(0xFF1A5276)),
                                SizedBox(width: 10.w),
                                Text('جميع المحصلين (الكل)',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14.sp,
                                        color: const Color(0xFF1A5276))),
                              ],
                            ),
                          ),
                          ..._collectorsList
                              .map<DropdownMenuItem<int>>((collector) {
                            return DropdownMenuItem<int>(
                              value: collector['emp_id'],
                              child: Row(
                                children: [
                                  const Icon(Icons.person, color: Colors.grey),
                                  SizedBox(width: 10.w),
                                  Text(collector['emp_name'].toString(),
                                      style: TextStyle(fontSize: 14.sp)),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedCollectorId = val);
                            _fetchCollectorsAndReport();
                          }
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 15.h),
                  InkWell(
                    onTap: () => _selectDateRange(context),
                    borderRadius: BorderRadius.circular(12.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 15.w, vertical: 12.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.date_range, color: Colors.white),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text(
                              'من: ${DateFormat('yyyy/MM/dd').format(_startDate)}   إلى: ${DateFormat('yyyy/MM/dd').format(_endDate)}',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Icon(Icons.edit,
                              color: Colors.white70, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (!_isLoading) ...[
              // 🌟 تبويبات المحصلين
              if (_selectedCollectorId == 0 && _collectorsList.isNotEmpty)
                Container(
                  height: 45.h,
                  margin: EdgeInsets.only(top: 15.h, bottom: 5.h),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    children: [
                      _buildSubTabChip(0, 'الكل'),
                      ..._collectorsList.map((collector) {
                        return _buildSubTabChip(
                            collector['emp_id'], collector['emp_name']);
                      }).toList(),
                    ],
                  ),
                ),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchCollectorsAndReport,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      // الإحصائيات المالية العلوية
                      Padding(
                        padding: EdgeInsets.fromLTRB(16.w, 15.h, 16.w, 10.h),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildStatCard(
                                title: 'إجمالي التحصيلات',
                                value:
                                    '${NumberFormat('#,##0').format(_collectorTotalAmount)}',
                                unit: 'ريال',
                                icon: Icons.account_balance_wallet,
                                color: Colors.green.shade600,
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              flex: 1,
                              child: _buildStatCard(
                                title: 'السندات',
                                value: '${_collectorPayments.length}',
                                icon: Icons.receipt_long,
                                color: Colors.blue.shade600,
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              flex: 1,
                              child: _buildStatCard(
                                title: 'القراءات',
                                value: '${_collectorReadings.length}',
                                icon: Icons.speed,
                                color: Colors.orange.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 🌟 زر استخراج التقرير إلى إكسل
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 16.w, vertical: 5.h),
                        child: ElevatedButton.icon(
                          onPressed: _exportToExcel,
                          icon: const Icon(Icons.file_download,
                              color: Colors.white),
                          label: Text('تصدير كملف إكسل (Excel)',
                              style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.r)),
                              minimumSize: const Size(double.infinity, 45)),
                        ),
                      ),

                      // بطاقة إحصائيات إنجاز القراءات والمناطق
                      _buildReadingProgressCard(),

                      // التبويبات الرئيسية (سندات / قراءات)
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 16.w, vertical: 10.h),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              _buildMainTabButton(0, 'السندات المحصلة'),
                              Container(
                                  width: 1,
                                  height: 30.h,
                                  color: Colors.grey.shade300),
                              _buildMainTabButton(1, 'القراءات المسجلة'),
                            ],
                          ),
                        ),
                      ),

                      // عرض القوائم (معكوسة لتظهر الأحدث أولاً)
                      _currentTabIndex == 0
                          ? _buildPaymentsList()
                          : _buildReadingsList(),
                      SizedBox(height: 30.h),
                    ],
                  ),
                ),
              ),
            ] else
              const Expanded(
                child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF144563))),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      {required String title,
      required String value,
      String? unit,
      required IconData icon,
      required Color color}) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 15.h, horizontal: 5.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15.r),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24.w),
          ),
          SizedBox(height: 10.h),
          Text(title,
              style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          SizedBox(height: 5.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: color)),
              if (unit != null) ...[
                SizedBox(width: 2.w),
                Text(unit,
                    style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600)),
              ]
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReadingProgressCard() {
    Map<String, dynamic> stats = _getCurrentProgressStats();
    int total = stats['total'] ?? 0;
    int read = stats['read'] ?? 0;
    int unread = stats['unread'] ?? 0;
    String areas = stats['areas'] ?? '';

    double progress = total > 0 ? (read / total) : 0.0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 5.h),
      padding: EdgeInsets.all(15.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15.r),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_rounded,
                  color: const Color(0xFF1A5276), size: 22.w),
              SizedBox(width: 8.w),
              Text('إحصائيات إنجاز القراءات',
                  style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A5276))),
            ],
          ),
          Divider(height: 20.h, color: Colors.grey.shade200),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildProgressStat(Icons.people, 'إجمالي المشتركين',
                  total.toString(), Colors.blue),
              _buildProgressStat(Icons.check_circle, 'تمت القراءة',
                  read.toString(), Colors.green),
              _buildProgressStat(Icons.pending_actions, 'المتبقي (لم تُقرأ)',
                  unread.toString(), Colors.red),
            ],
          ),
          SizedBox(height: 15.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10.h,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress == 1.0 ? Colors.green : Colors.orange,
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Center(
            child: Text('نسبة الإنجاز: ${(progress * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700)),
          ),
          Divider(height: 20.h, color: Colors.grey.shade200),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on, color: Colors.red.shade400, size: 18.w),
              SizedBox(width: 5.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('المناطق/الشوارع المسؤولة:',
                        style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 2.h),
                    Text(areas,
                        style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.black87,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStat(
      IconData icon, String label, String value, MaterialColor color) {
    return Column(
      children: [
        Icon(icon, color: color.shade600, size: 20.w),
        SizedBox(height: 4.h),
        Text(value,
            style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: color.shade700)),
        Text(label,
            style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildMainTabButton(int index, String title) {
    bool isSelected = _currentTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentTabIndex = index),
        borderRadius: BorderRadius.horizontal(
            right: Radius.circular(index == 0 ? 12.r : 0),
            left: Radius.circular(index == 1 ? 12.r : 0)),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF144563) : Colors.transparent,
            borderRadius: BorderRadius.horizontal(
                right: Radius.circular(index == 0 ? 12.r : 0),
                left: Radius.circular(index == 1 ? 12.r : 0)),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey.shade600),
          ),
        ),
      ),
    );
  }

  Widget _buildSubTabChip(int id, String name) {
    bool isSelected = _activeSubCollectorId == id;
    return Padding(
      padding: EdgeInsets.only(left: 8.w),
      child: ChoiceChip(
        label: Text(name,
            style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 12.sp)),
        selected: isSelected,
        selectedColor: const Color(0xFF2980B9),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
            side: BorderSide(
                color: isSelected ? Colors.transparent : Colors.grey.shade300)),
        onSelected: (selected) {
          setState(() {
            _activeSubCollectorId = id;
          });
        },
      ),
    );
  }

  Widget _buildPaymentsList() {
    List<dynamic> displayList = _getFilteredData(_collectorPayments);

    if (displayList.isEmpty) {
      return _buildEmptyState(
          'لا توجد سندات تحصيل لهذه التصفية', Icons.receipt_long);
    }

    // 🌟 عكس القائمة لتظهر أحدث السندات أولاً
    final reversedItems = displayList.reversed.toList();

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 0),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: reversedItems.length,
      itemBuilder: (context, index) {
        final payment = reversedItems[index];
        double amountVal =
            double.tryParse(payment['amount']?.toString() ?? '0') ?? 0.0;

        return InkWell(
          onTap: () => _showPaymentDetailsDialog(payment, amountVal),
          borderRadius: BorderRadius.circular(15.r),
          child: Container(
            margin: EdgeInsets.only(bottom: 12.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15.r),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(15.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.receipt_long,
                              color: Colors.green.shade600, size: 20.w),
                          SizedBox(width: 8.w),
                          Text(
                              'سند #${payment['receipt_no'] ?? payment['receiptNo'] ?? '---'}',
                              style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87)),
                        ],
                      ),
                      Text('${NumberFormat('#,##0.00').format(amountVal)} ريال',
                          style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700)),
                    ],
                  ),
                  Divider(height: 20.h, color: Colors.grey.shade200),
                  _buildInfoRow(Icons.person, 'المشترك:',
                      '${payment['customer_name'] ?? payment['id_customer'] ?? ''}'),
                  SizedBox(height: 6.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoRow(Icons.admin_panel_settings, 'المحصل:',
                          '${payment['collector_name'] ?? 'غير معروف'}'),
                      Text(
                          payment['payment_date'] ??
                              payment['paymentDate'] ??
                              '',
                          style: TextStyle(
                              fontSize: 11.sp, color: Colors.grey.shade500)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReadingsList() {
    List<dynamic> displayList = _getFilteredData(_collectorReadings);

    if (displayList.isEmpty) {
      return _buildEmptyState('لا توجد قراءات لهذه التصفية', Icons.speed);
    }

    // 🌟 عكس القائمة لتظهر أحدث القراءات أولاً
    final reversedItems = displayList.reversed.toList();

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 0),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: reversedItems.length,
      itemBuilder: (context, index) {
        final reading = reversedItems[index];
        bool hasImage = reading['image_path'] != null &&
            reading['image_path'].toString().isNotEmpty;

        return InkWell(
          onTap: () => _showReadingDetailsDialog(reading, hasImage),
          borderRadius: BorderRadius.circular(15.r),
          child: Container(
            margin: EdgeInsets.only(bottom: 12.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15.r),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(15.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.speed,
                                color: Colors.orange.shade600, size: 20.w),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                  '${reading['customer_name'] ?? reading['id_customer'] ?? ''}',
                                  style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(20.r)),
                        child: Text(
                            '${reading['reading_value'] ?? reading['now_reead'] ?? '0'}',
                            style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700)),
                      ),
                    ],
                  ),
                  Divider(height: 20.h, color: Colors.grey.shade200),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _buildInfoRow(
                            Icons.admin_panel_settings,
                            'المحصل:',
                            '${reading['collector_name'] ?? 'مجهول'}'),
                      ),
                      if (hasImage)
                        Row(
                          children: [
                            Icon(Icons.image,
                                color: Colors.blue.shade400, size: 16.w),
                            SizedBox(width: 4.w),
                            Text('مرفق صورة',
                                style: TextStyle(
                                    fontSize: 11.sp,
                                    color: Colors.blue.shade700)),
                          ],
                        ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(reading['reading_date'] ?? '',
                      style: TextStyle(
                          fontSize: 11.sp, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // =====================================
  // 🌟 النوافذ المنبثقة للتفاصيل
  // =====================================

  void _showPaymentDetailsDialog(Map<String, dynamic> payment, double amount) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25.r))),
      backgroundColor: Colors.white,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.only(
                top: 25.w,
                left: 25.w,
                right: 25.w,
                bottom: MediaQuery.of(context).viewInsets.bottom + 25.w,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                        width: 50.w,
                        height: 5.h,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10.r))),
                  ),
                  SizedBox(height: 20.h),
                  Row(
                    children: [
                      Container(
                          padding: EdgeInsets.all(10.w),
                          decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              shape: BoxShape.circle),
                          child: Icon(Icons.receipt_long,
                              color: Colors.green.shade700)),
                      SizedBox(width: 15.w),
                      Text('تفاصيل السند',
                          style: TextStyle(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                    ],
                  ),
                  Divider(height: 30.h, color: Colors.grey.shade200),
                  _buildPopupDetailRow('رقم السند الدفتري:',
                      '${payment['receipt_no'] ?? 'غير متوفر'}'),
                  _buildPopupDetailRow('المبلغ:',
                      '${NumberFormat('#,##0.00').format(amount)} ريال',
                      isHighlight: true, color: Colors.green.shade700),
                  _buildPopupDetailRow(
                      'اسم المشترك:', '${payment['customer_name'] ?? ''}'),
                  _buildPopupDetailRow(
                      'رقم المشترك:', '${payment['id_customer'] ?? ''}'),
                  _buildPopupDetailRow(
                      'المحصل:', '${payment['collector_name'] ?? 'مجهول'}'),
                  _buildPopupDetailRow(
                      'طريقة الدفع:', '${payment['payment_method'] ?? 'نقدي'}'),
                  _buildPopupDetailRow(
                      'تاريخ السداد:', '${payment['payment_date'] ?? ''}'),
                  SizedBox(height: 20.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF144563),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r)),
                          padding: EdgeInsets.symmetric(vertical: 12.h)),
                      child: Text('إغلاق',
                          style:
                              TextStyle(color: Colors.white, fontSize: 16.sp)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showReadingDetailsDialog(Map<String, dynamic> reading, bool hasImage) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25.r))),
      backgroundColor: Colors.white,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.only(
                top: 25.w,
                left: 25.w,
                right: 25.w,
                bottom: MediaQuery.of(context).viewInsets.bottom + 25.w,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                        width: 50.w,
                        height: 5.h,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10.r))),
                  ),
                  SizedBox(height: 20.h),
                  Row(
                    children: [
                      Container(
                          padding: EdgeInsets.all(10.w),
                          decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              shape: BoxShape.circle),
                          child:
                              Icon(Icons.speed, color: Colors.orange.shade700)),
                      SizedBox(width: 15.w),
                      Text('تفاصيل القراءة',
                          style: TextStyle(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                    ],
                  ),
                  Divider(height: 30.h, color: Colors.grey.shade200),
                  _buildPopupDetailRow('القراءة المسجلة:',
                      '${reading['reading_value'] ?? reading['now_reead'] ?? '0'}',
                      isHighlight: true, color: Colors.orange.shade700),
                  _buildPopupDetailRow(
                      'اسم المشترك:', '${reading['customer_name'] ?? ''}'),
                  _buildPopupDetailRow(
                      'رقم المشترك:', '${reading['id_customer'] ?? ''}'),
                  _buildPopupDetailRow(
                      'رقم العداد:', '${reading['num_addaad'] ?? 'غير متوفر'}'),
                  _buildPopupDetailRow(
                      'المحصل:', '${reading['collector_name'] ?? 'مجهول'}'),
                  _buildPopupDetailRow(
                      'تاريخ القراءة:', '${reading['reading_date'] ?? ''}'),
                  if (hasImage)
                    Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green, size: 18.w),
                          SizedBox(width: 5.w),
                          Text('يوجد صورة مرفقة للعداد تم رفعها بنجاح.',
                              style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 13.sp)),
                        ],
                      ),
                    ),
                  SizedBox(height: 20.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF144563),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r)),
                          padding: EdgeInsets.symmetric(vertical: 12.h)),
                      child: Text('إغلاق',
                          style:
                              TextStyle(color: Colors.white, fontSize: 16.sp)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPopupDetailRow(String label, String value,
      {bool isHighlight = false, Color? color}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 120.w,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600))),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: isHighlight ? 18.sp : 14.sp,
                    fontWeight: FontWeight.bold,
                    color: color ?? Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14.w, color: Colors.grey.shade500),
        SizedBox(width: 6.w),
        Text(label,
            style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600)),
        SizedBox(width: 4.w),
        Flexible(
            child: Text(value,
                style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
                overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: 40.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80.w, color: Colors.grey.shade300),
            SizedBox(height: 15.h),
            Text(message,
                style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}
