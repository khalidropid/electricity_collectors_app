import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:charset_converter/charset_converter.dart';
import 'dart:convert';

import '../providers/reports_provider.dart';
import '../widgets/app_drawer.dart';
import '../core/utils/secure_storage_helper.dart'; // 🌟 جلب اسم المحصل والصلاحيات

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const Color primaryColor = Color(0xFF1A5276);
  static const Color backgroundColor = Color(0xFFF4F7FA);

  // 🌟 متغيرات الطباعة
  List<BluetoothInfo> _devices = [];
  bool _connected = false;
  String _collectorName = 'جاري التحميل...';
  Map<String, dynamic> _permissions = {};

  final String stationName = "محطة الحسن لتوليد الطاقة الكهربائية";

  @override
  void initState() {
    super.initState();

    _loadCollectorNameAndPermissions();
    _initBluetooth();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ReportsProvider>(
        context,
        listen: false,
      ).loadDailyReport();
    });
  }

  // 🌟 دالة جلب اسم المحصل والصلاحيات (لمنع الطباعة إن لزم)
  Future<void> _loadCollectorNameAndPermissions() async {
    String? name = await SecureStorageHelper.getEmpName();
    String? permsStr = await SecureStorageHelper.getPermissions();

    if (mounted) {
      setState(() {
        _collectorName = name ?? 'غير معروف';
        if (permsStr != null) {
          _permissions = jsonDecode(permsStr);
        }
      });
    }
  }

  // 🌟 تهيئة البلوتوث
  void _initBluetooth() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses[Permission.bluetoothConnect]!.isGranted ||
        statuses[Permission.bluetoothScan]!.isGranted ||
        statuses[Permission.location]!.isGranted) {
      bool isConnected = await PrintBluetoothThermal.connectionStatus;
      List<BluetoothInfo> devices = [];
      try {
        devices = await PrintBluetoothThermal.pairedBluetooths;
      } catch (e) {
        debugPrint("Error fetching devices: $e");
      }

      if (!mounted) return;
      setState(() {
        _devices = devices;
        _connected = isConnected;
      });
    }
  }

  // 🌟 دوال الطباعة
  Future<List<int>> _arabic(String text) async {
    final encoded = await CharsetConverter.encode('windows-1256', text);
    return encoded.toList();
  }

  void _showPrinterDialog(ReportsProvider provider) async {
    // تحديث الصلاحيات لحظياً قبل الطباعة
    String? latestPermsStr = await SecureStorageHelper.getPermissions();
    if (latestPermsStr != null && mounted) {
      setState(() => _permissions = jsonDecode(latestPermsStr));
    }

    if (_permissions['hide_print_button'] == true ||
        _permissions['hide_print_button'] == 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم إيقاف صلاحية الطباعة من قبل الإدارة.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: EdgeInsets.all(20.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bluetooth, color: Colors.blue),
                    SizedBox(width: 10.w),
                    Text('اختر طابعة البلوتوث',
                        style: TextStyle(
                            fontSize: 18.sp, fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 15.h),
                _devices.isEmpty
                    ? Padding(
                        padding: EdgeInsets.all(20.w),
                        child: const Text(
                            'لم يتم العثور على طابعات مقترنة. يرجى الإقران من إعدادات الهاتف.',
                            textAlign: TextAlign.center),
                      )
                    : Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _devices.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              leading: const Icon(Icons.print,
                                  color: Colors.black54),
                              title: Text(
                                  _devices[index].name ?? 'طابعة غير معروفة',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(_devices[index].macAdress),
                              onTap: () async {
                                Navigator.pop(context);
                                _connectAndPrintReport(
                                    _devices[index], provider);
                              },
                            );
                          },
                        ),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _connectAndPrintReport(
      BluetoothInfo device, ReportsProvider provider) async {
    try {
      bool connected = await PrintBluetoothThermal.connect(
          macPrinterAddress: device.macAdress);
      if (connected) {
        setState(() => _connected = true);
        await _printDailyReport(provider);
      } else {
        throw "فشل الاتصال بالطابعة";
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('فشل الاتصال: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _printDailyReport(ReportsProvider provider) async {
    bool isConnected = await PrintBluetoothThermal.connectionStatus;
    if (!isConnected) return;

    List<int> bytes = [];

    // تهيئة الطابعة
    bytes.addAll([0x1B, 0x40]);
    // دعم اللغة العربية
    bytes.addAll([0x1B, 0x74, 0x21]);

    // توسيط النص للترويسة
    bytes.addAll([0x1B, 0x61, 0x01]);
    bytes.addAll(await _arabic('$stationName\n'));
    bytes.addAll(await _arabic('ملخص التحصيل\n'));
    bytes.addAll(await _arabic('--------------------------------\n'));

    // محاذاة النص لليمين للبيانات المطلوبة
    bytes.addAll([0x1B, 0x61, 0x02]);
    bytes.addAll(await _arabic('اسم المتحصل: $_collectorName\n'));
    bytes.addAll(await _arabic(
        'إجمالي التحصيل: ${_formatNumber(provider.totalCollectedToday)} ريال\n'));
    bytes.addAll(await _arabic('--------------------------------\n\n\n'));

    await PrintBluetoothThermal.writeBytes(bytes);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تمت الطباعة بنجاح ✓'),
        backgroundColor: Colors.green,
      ));
    }
  }

  String _formatNumber(dynamic value) {
    try {
      final number = num.tryParse(value?.toString() ?? '0') ?? 0;
      return NumberFormat('#,##0').format(number);
    } catch (_) {
      return '0';
    }
  }

  String _formatDateTime(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return 'الوقت غير متوفر';
    }

    try {
      final date = DateTime.parse(value.toString());

      return DateFormat(
        'yyyy/MM/dd - hh:mm a',
      ).format(date);
    } catch (_) {
      return value.toString();
    }
  }

  String _todayDate() {
    return DateFormat(
      'yyyy/MM/dd',
    ).format(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        drawer: const AppDrawer(),
        appBar: _buildAppBar(),
        body: Consumer<ReportsProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return _buildLoading();
            }

            return RefreshIndicator(
              color: primaryColor,
              onRefresh: () async {
                await provider.loadDailyReport();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  16.w,
                  16.h,
                  16.w,
                  30.h,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildReportHeader(provider),
                    SizedBox(height: 18.h),
                    _buildMainCollectionCard(provider),
                    SizedBox(height: 18.h),
                    _buildStatisticsGrid(provider),
                    SizedBox(height: 24.h),
                    _buildSectionTitle(
                      title: 'تفاصيل العمليات',
                      subtitle: 'جميع العمليات المسجلة خلال اليوم',
                      icon: Icons.analytics_outlined,
                    ),
                    SizedBox(height: 12.h),
                    _buildPaymentsSection(provider),
                    SizedBox(height: 12.h),
                    _buildReadingsSection(provider),
                    SizedBox(height: 12.h),
                    _buildModificationsSection(provider),
                    SizedBox(height: 24.h),
                    _buildReportSummary(provider),
                    SizedBox(height: 20.h),
                    _buildRefreshButton(provider),
                    SizedBox(height: 10.h),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: primaryColor,
      elevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(
        color: Colors.white,
      ),
      leading: Builder(
        builder: (context) {
          return IconButton(
            tooltip: 'القائمة',
            icon: const Icon(
              Icons.menu_rounded,
              color: Colors.white,
            ),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          );
        },
      ),
      title: Text(
        'التقارير اليومية',
        style: TextStyle(
          fontSize: 19.sp,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'رجوع',
          icon: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 19.sp,
            color: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 70.w,
            height: 70.w,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: primaryColor,
                strokeWidth: 3,
              ),
            ),
          ),
          SizedBox(height: 18.h),
          Text(
            'جاري تحميل التقرير...',
            style: TextStyle(
              fontSize: 15.sp,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportHeader(ReportsProvider provider) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52.w,
            height: 52.w,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(15.r),
            ),
            child: Icon(
              Icons.calendar_month_rounded,
              color: primaryColor,
              size: 27.w,
            ),
          ),
          SizedBox(width: 13.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تقرير اليوم',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  _todayDate(),
                  style: TextStyle(
                    fontSize: 18.sp,
                    color: Colors.black87,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 10.w,
              vertical: 7.h,
            ),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.09),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7.w,
                  height: 7.w,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 5.w),
                Text(
                  'محدث',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainCollectionCard(ReportsProvider provider) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(22.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF174A6B),
            Color(0xFF1A5276),
            Color(0xFF2475A5),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: -15.w,
            bottom: -25.h,
            child: Icon(
              Icons.account_balance_wallet_rounded,
              size: 115.w,
              color: Colors.white.withOpacity(0.055),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(13.r),
                    ),
                    child: Icon(
                      Icons.payments_rounded,
                      color: Colors.white,
                      size: 24.w,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'إجمالي النقدية المحصلة',
                      style: TextStyle(
                        fontSize: 15.sp,
                        color: Colors.white.withOpacity(0.86),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 9.w,
                      vertical: 5.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      'اليوم',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 22.h),
              Text(
                _formatNumber(provider.totalCollectedToday),
                style: TextStyle(
                  fontSize: 35.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              SizedBox(height: 7.h),
              Text(
                'ريال يمني',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.white.withOpacity(0.78),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 18.h),
              Container(
                height: 1,
                color: Colors.white.withOpacity(0.12),
              ),
              SizedBox(height: 14.h),
              Row(
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    color: Colors.white.withOpacity(0.75),
                    size: 18.w,
                  ),
                  SizedBox(width: 7.w),
                  Text(
                    '${provider.paymentsCountToday} سند اليوم',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.82),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  // 🌟 زر طباعة التقرير المختصر
                  InkWell(
                    onTap: () => _showPrinterDialog(provider),
                    borderRadius: BorderRadius.circular(8.r),
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.print_rounded,
                              color: Colors.white, size: 16.w),
                          SizedBox(width: 5.w),
                          Text('طباعة',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsGrid(ReportsProvider provider) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildInteractiveStatCard(
                title: 'السندات',
                value: '${provider.paymentsCountToday}',
                subtitle: 'عملية تحصيل',
                icon: Icons.receipt_long_rounded,
                color: Colors.green,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildInteractiveStatCard(
                title: 'تمت القراءة',
                value: '${provider.readingsCountToday}',
                subtitle: 'عداد تمت قراءته',
                icon: Icons.speed_rounded,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _buildInteractiveStatCard(
                title: 'المتبقي',
                value: '${provider.remainingReadingsCount}',
                subtitle: 'قراءة متبقية',
                icon: Icons.hourglass_bottom_rounded,
                color: Colors.red,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildInteractiveStatCard(
                title: 'المشتركون',
                value: '${provider.totalCustomersCount}',
                subtitle: 'إجمالي المشتركين',
                icon: Icons.groups_rounded,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInteractiveStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(18.r),
        onTap: () {},
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: Colors.grey.shade100,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.025),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 43.w,
                    height: 43.w,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(13.r),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 22.w,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.more_horiz_rounded,
                    color: Colors.grey.shade400,
                    size: 21.w,
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              Text(
                value,
                style: TextStyle(
                  fontSize: 25.sp,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 3.h),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10.sp,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          width: 43.w,
          height: 43.w,
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.09),
            borderRadius: BorderRadius.circular(13.r),
          ),
          child: Icon(
            icon,
            color: primaryColor,
            size: 23.w,
          ),
        ),
        SizedBox(width: 11.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentsSection(ReportsProvider provider) {
    return _buildExpansionSection(
      title: 'عمليات التحصيل',
      subtitle: '${provider.todayPaymentsList.length} سند',
      icon: Icons.payments_rounded,
      color: Colors.green,
      initiallyExpanded: true,
      child: _buildPaymentItems(
        provider.todayPaymentsList,
      ),
    );
  }

  Widget _buildReadingsSection(ReportsProvider provider) {
    return _buildExpansionSection(
      title: 'عمليات القراءة',
      subtitle: '${provider.todayReadingsList.length} قراءة',
      icon: Icons.speed_rounded,
      color: Colors.orange,
      initiallyExpanded: false,
      child: _buildReadingItems(
        provider.todayReadingsList,
      ),
    );
  }

  Widget _buildModificationsSection(ReportsProvider provider) {
    final items = provider.todayModificationsList ?? [];

    return _buildExpansionSection(
      title: 'طلبات التعديل',
      subtitle: '${items.length} طلب',
      icon: Icons.edit_note_rounded,
      color: Colors.blue,
      initiallyExpanded: false,
      child: _buildModificationItems(items),
    );
  }

  Widget _buildExpansionSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget child,
    required bool initiallyExpanded,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: color.withOpacity(0.04),
          highlightColor: color.withOpacity(0.02),
        ),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: EdgeInsets.symmetric(
            horizontal: 15.w,
            vertical: 5.h,
          ),
          childrenPadding: EdgeInsets.only(
            bottom: 7.h,
          ),
          leading: Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(13.r),
            ),
            child: Icon(
              icon,
              color: color,
              size: 23.w,
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          subtitle: Padding(
            padding: EdgeInsets.only(top: 3.h),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 11.sp,
                color: Colors.grey.shade500,
              ),
            ),
          ),
          iconColor: color,
          collapsedIconColor: Colors.grey.shade500,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  // 🌟 عكس قائمة التحصيل لتظهر أحدث العمليات أولاً
  Widget _buildPaymentItems(
    List<Map<String, dynamic>> items,
  ) {
    if (items.isEmpty) {
      return _buildEmptyState(
        icon: Icons.receipt_long_outlined,
        message: 'لا توجد عمليات تحصيل مسجلة اليوم',
      );
    }

    final reversedItems = items.reversed.toList();

    return Column(
      children: reversedItems.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;

        return _buildPaymentItem(
          item,
          index,
          reversedItems.length,
        );
      }).toList(),
    );
  }

  Widget _buildPaymentItem(
    Map<String, dynamic> item,
    int index,
    int total,
  ) {
    final customerName = item['customer_name'] ??
        item['name_customer'] ??
        'مشترك رقم (${item['id_customer'] ?? ''})';

    final amount = item['amount'] ?? 0;
    final paymentMethod = item['payment_method']?.toString() ?? 'نقدي';
    final receiptNo = item['receipt_no']?.toString() ?? 'غير متوفر';
    final dateTime = _formatDateTime(item['payment_date']);

    return InkWell(
      borderRadius: BorderRadius.circular(14.r),
      onTap: () {
        _showPaymentDetails(item);
      },
      child: Container(
        margin: EdgeInsets.only(
          bottom: index == total - 1 ? 0 : 7.h,
        ),
        padding: EdgeInsets.all(13.w),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FBFC),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: Colors.grey.shade100,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 43.w,
              height: 43.w,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_downward_rounded,
                color: Colors.green.shade700,
                size: 22.w,
              ),
            ),
            SizedBox(width: 11.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customerName.toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
                    ),
                  ),
                  SizedBox(height: 5.h),
                  Row(
                    children: [
                      Icon(
                        Icons.receipt_outlined,
                        size: 13.w,
                        color: Colors.grey.shade500,
                      ),
                      SizedBox(width: 4.w),
                      Flexible(
                        child: Text(
                          'السند: $receiptNo',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5.sp,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 3.h),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 13.w,
                        color: Colors.grey.shade500,
                      ),
                      SizedBox(width: 4.w),
                      Flexible(
                        child: Text(
                          dateTime,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5.sp,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatNumber(amount),
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.green.shade700,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'ريال',
                  style: TextStyle(
                    fontSize: 9.sp,
                    color: Colors.grey.shade500,
                  ),
                ),
                SizedBox(height: 4.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 6.w,
                    vertical: 3.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(7.r),
                  ),
                  child: Text(
                    paymentMethod,
                    style: TextStyle(
                      fontSize: 9.sp,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 🌟 عكس قائمة القراءات لتظهر أحدث العمليات أولاً
  Widget _buildReadingItems(
    List<Map<String, dynamic>> items,
  ) {
    if (items.isEmpty) {
      return _buildEmptyState(
        icon: Icons.speed_outlined,
        message: 'لا توجد قراءات مسجلة اليوم',
      );
    }

    final reversedItems = items.reversed.toList();

    return Column(
      children: reversedItems.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;

        return _buildReadingItem(
          item,
          index,
          reversedItems.length,
        );
      }).toList(),
    );
  }

  Widget _buildReadingItem(
    Map<String, dynamic> item,
    int index,
    int total,
  ) {
    final customerName = item['customer_name'] ??
        item['name_customer'] ??
        'مشترك رقم (${item['id_customer'] ?? ''})';

    final meterNumber = item['num_addaad']?.toString() ?? 'غير متوفر';
    final readingValue = item['reading_value']?.toString() ?? '0';
    final dateTime = _formatDateTime(item['reading_date']);

    return InkWell(
      borderRadius: BorderRadius.circular(14.r),
      onTap: () {
        _showReadingDetails(item);
      },
      child: Container(
        margin: EdgeInsets.only(
          bottom: index == total - 1 ? 0 : 7.h,
        ),
        padding: EdgeInsets.all(13.w),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF5),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: Colors.orange.withOpacity(0.10),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 43.w,
              height: 43.w,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.11),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.speed_rounded,
                color: Colors.orange.shade700,
                size: 22.w,
              ),
            ),
            SizedBox(width: 11.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customerName.toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
                    ),
                  ),
                  SizedBox(height: 5.h),
                  Row(
                    children: [
                      Icon(
                        Icons.speed_outlined,
                        size: 13.w,
                        color: Colors.grey.shade500,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'العداد: $meterNumber',
                        style: TextStyle(
                          fontSize: 10.5.sp,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 3.h),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 13.w,
                        color: Colors.grey.shade500,
                      ),
                      SizedBox(width: 4.w),
                      Flexible(
                        child: Text(
                          dateTime,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5.sp,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  readingValue,
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.orange.shade700,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  'قراءة العداد',
                  style: TextStyle(
                    fontSize: 9.sp,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 🌟 عكس قائمة طلبات التعديل لتظهر الأحدث أولاً
  Widget _buildModificationItems(
    List<Map<String, dynamic>> items,
  ) {
    if (items.isEmpty) {
      return _buildEmptyState(
        icon: Icons.edit_document,
        message: 'لا توجد طلبات تعديل مسجلة اليوم',
      );
    }

    final reversedItems = items.reversed.toList();

    return Column(
      children: reversedItems.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;

        return _buildModificationItem(
          item,
          index,
          reversedItems.length,
        );
      }).toList(),
    );
  }

  Widget _buildModificationItem(
    Map<String, dynamic> item,
    int index,
    int total,
  ) {
    final customerName =
        item['name_customer'] ?? 'مشترك رقم (${item['id_customer'] ?? ''})';

    final modType = item['mod_type'] ?? 'تعديل بيانات';
    final dateTime = _formatDateTime(item['request_date']);
    final notes = item['notes']?.toString() ?? '';

    return InkWell(
      borderRadius: BorderRadius.circular(14.r),
      onTap: () {
        _showModificationDetails(item);
      },
      child: Container(
        margin: EdgeInsets.only(
          bottom: index == total - 1 ? 0 : 7.h,
        ),
        padding: EdgeInsets.all(13.w),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAFF),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: Colors.blue.withOpacity(0.10),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 43.w,
              height: 43.w,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.edit_note_rounded,
                color: Colors.blue.shade700,
                size: 22.w,
              ),
            ),
            SizedBox(width: 11.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customerName.toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(7.r),
                    ),
                    child: Text(
                      modType.toString(),
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 13.w,
                        color: Colors.grey.shade500,
                      ),
                      SizedBox(width: 4.w),
                      Flexible(
                        child: Text(
                          dateTime,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5.sp,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (notes.isNotEmpty) ...[
                    SizedBox(height: 5.h),
                    Text(
                      notes,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_left_rounded,
              color: Colors.grey.shade400,
              size: 22.w,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: 24.h,
        horizontal: 15.w,
      ),
      child: Column(
        children: [
          Container(
            width: 55.w,
            height: 55.w,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.grey.shade400,
              size: 27.w,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportSummary(ReportsProvider provider) {
    final payments = provider.paymentsCountToday;
    final readings = provider.readingsCountToday;
    final remaining = provider.remainingReadingsCount;
    final customers = provider.totalCustomersCount;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.summarize_rounded,
                color: primaryColor,
                size: 22.w,
              ),
              SizedBox(width: 8.w),
              Text(
                'ملخص التقرير',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 15.h),
          _buildSummaryRow(
            'إجمالي السندات',
            '$payments سند',
            Icons.receipt_long_outlined,
            Colors.green,
          ),
          _buildSummaryDivider(),
          _buildSummaryRow(
            'إجمالي القراءات',
            '$readings قراءة',
            Icons.speed_outlined,
            Colors.orange,
          ),
          _buildSummaryDivider(),
          _buildSummaryRow(
            'القراءات المتبقية',
            '$remaining قراءة',
            Icons.hourglass_empty_rounded,
            Colors.red,
          ),
          _buildSummaryDivider(),
          _buildSummaryRow(
            'إجمالي المشتركين',
            '$customers مشترك',
            Icons.groups_outlined,
            Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 34.w,
          height: 34.w,
          decoration: BoxDecoration(
            color: color.withOpacity(0.09),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(
            icon,
            color: color,
            size: 18.w,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.black87,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryDivider() {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: 10.h,
      ),
      child: Divider(
        height: 1,
        color: Colors.grey.shade100,
      ),
    );
  }

  Widget _buildRefreshButton(ReportsProvider provider) {
    return SizedBox(
      width: double.infinity,
      height: 52.h,
      child: ElevatedButton.icon(
        onPressed: provider.isLoading
            ? null
            : () async {
                await provider.loadDailyReport();
              },
        icon: const Icon(
          Icons.refresh_rounded,
        ),
        label: Text(
          'تحديث بيانات التقرير',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.r),
          ),
        ),
      ),
    );
  }

  void _showPaymentDetails(
    Map<String, dynamic> item,
  ) {
    final customerName =
        item['customer_name'] ?? item['name_customer'] ?? 'غير معروف';
    final amount = item['amount'] ?? 0;
    final receiptNo = item['receipt_no']?.toString() ?? 'غير متوفر';
    final paymentMethod = item['payment_method']?.toString() ?? 'نقدي';
    final dateTime = _formatDateTime(item['payment_date']);

    _showDetailsDialog(
      title: 'تفاصيل عملية التحصيل',
      icon: Icons.payments_rounded,
      color: Colors.green,
      children: [
        _buildDialogInfoRow(
          'المشترك',
          customerName.toString(),
          Icons.person_outline_rounded,
        ),
        _buildDialogInfoRow(
          'رقم السند',
          receiptNo,
          Icons.receipt_long_outlined,
        ),
        _buildDialogInfoRow(
          'المبلغ',
          '${_formatNumber(amount)} ريال',
          Icons.payments_outlined,
        ),
        _buildDialogInfoRow(
          'طريقة الدفع',
          paymentMethod,
          Icons.account_balance_wallet_outlined,
        ),
        _buildDialogInfoRow(
          'التاريخ والوقت',
          dateTime,
          Icons.access_time_rounded,
        ),
      ],
    );
  }

  void _showReadingDetails(
    Map<String, dynamic> item,
  ) {
    final customerName =
        item['customer_name'] ?? item['name_customer'] ?? 'غير معروف';
    final meterNumber = item['num_addaad']?.toString() ?? 'غير متوفر';
    final readingValue = item['reading_value']?.toString() ?? '0';
    final dateTime = _formatDateTime(item['reading_date']);

    _showDetailsDialog(
      title: 'تفاصيل قراءة العداد',
      icon: Icons.speed_rounded,
      color: Colors.orange,
      children: [
        _buildDialogInfoRow(
          'المشترك',
          customerName.toString(),
          Icons.person_outline_rounded,
        ),
        _buildDialogInfoRow(
          'رقم العداد',
          meterNumber,
          Icons.speed_outlined,
        ),
        _buildDialogInfoRow(
          'القراءة',
          readingValue,
          Icons.show_chart_rounded,
        ),
        _buildDialogInfoRow(
          'التاريخ والوقت',
          dateTime,
          Icons.access_time_rounded,
        ),
      ],
    );
  }

  void _showModificationDetails(
    Map<String, dynamic> item,
  ) {
    final customerName = item['name_customer'] ?? 'غير معروف';
    final modType = item['mod_type'] ?? 'تعديل بيانات';
    final dateTime = _formatDateTime(item['request_date']);
    final notes = item['notes']?.toString() ?? '';

    _showDetailsDialog(
      title: 'تفاصيل طلب التعديل',
      icon: Icons.edit_note_rounded,
      color: Colors.blue,
      children: [
        _buildDialogInfoRow(
          'المشترك',
          customerName.toString(),
          Icons.person_outline_rounded,
        ),
        _buildDialogInfoRow(
          'نوع التعديل',
          modType.toString(),
          Icons.category_outlined,
        ),
        _buildDialogInfoRow(
          'التاريخ والوقت',
          dateTime,
          Icons.access_time_rounded,
        ),
        if (notes.isNotEmpty)
          _buildDialogInfoRow(
            'الملاحظات',
            notes,
            Icons.notes_outlined,
          ),
      ],
    );
  }

  void _showDetailsDialog({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            backgroundColor: Colors.white,
            insetPadding: EdgeInsets.symmetric(
              horizontal: 18.w,
              vertical: 24.h,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22.r),
            ),
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48.w,
                        height: 48.w,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        child: Icon(
                          icon,
                          color: color,
                          size: 25.w,
                        ),
                      ),
                      SizedBox(width: 11.w),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: Icon(
                          Icons.close_rounded,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 15.h),
                  Divider(
                    color: Colors.grey.shade100,
                    height: 1,
                  ),
                  SizedBox(height: 10.h),
                  ...children,
                  SizedBox(height: 10.h),
                  SizedBox(
                    width: double.infinity,
                    height: 45.h,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        'إغلاق',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  Widget _buildDialogInfoRow(
    String title,
    String value,
    IconData icon,
  ) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(
        horizontal: 12.w,
        vertical: 10.h,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(11.r),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 19.w,
            color: primaryColor,
          ),
          SizedBox(width: 9.w),
          Text(
            '$title:',
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 7.w),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.black87,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
