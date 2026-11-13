import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'dart:convert'; // 🌟 للتعامل مع JSON

import '../models/customer.dart';
import '../models/payment.dart';
import '../database/database_helper.dart';
import '../providers/sync_provider.dart';
import '../core/utils/secure_storage_helper.dart'; // 🌟 استيراد ملف التخزين
import 'invoice_screen.dart';

class AddPaymentScreen extends StatefulWidget {
  final Customer customer;
  final int empId;

  const AddPaymentScreen(
      {super.key, required this.customer, required this.empId});

  @override
  State<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends State<AddPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _receiptNoController = TextEditingController();

  late TextEditingController _dateController;
  DateTime _selectedDate = DateTime.now();
  String _selectedPaymentMethod = 'نقدي';

  final List<String> _paymentMethods = ['نقدي', 'تحويل بنكي', 'شبكة'];
  bool _isSaving = false;

  // 🌟 متغيرات الصلاحيات
  Map<String, dynamic> _permissions = {};
  bool _isLoadingPermissions = true;

  @override
  void initState() {
    super.initState();
    _loadPermissions(); // 🌟 تحميل الصلاحيات عند فتح الشاشة

    _receiptNoController.text =
        'REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    _dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd HH:mm:ss').format(_selectedDate),
    );
  }

  // 🌟 دالة جلب الصلاحيات من الذاكرة المحلية
  Future<void> _loadPermissions() async {
    String? permsString = await SecureStorageHelper.getPermissions();
    if (permsString != null) {
      if (mounted) {
        setState(() {
          _permissions = jsonDecode(permsString);
          _isLoadingPermissions = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoadingPermissions = false);
    }
  }

  // 🌟 دالة التحقق من أوقات العمل المسموحة
  bool _isTimeAllowed() {
    List<dynamic> allowedHours = _permissions['allowed_hours'] ?? [];
    if (allowedHours.isEmpty) return true; // إذا كانت فارغة نفترض السماح

    // سحب الساعة الحالية بصيغة خانتين (مثل 08 أو 15)
    String currentHour = DateTime.now().hour.toString().padLeft(2, '0');

    return allowedHours.any((h) => h.toString().padLeft(2, '0') == currentHour);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _receiptNoController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (pickedDate != null && mounted) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          _dateController.text =
              DateFormat('yyyy-MM-dd HH:mm:ss').format(_selectedDate);
        });
      }
    }
  }

  Future<void> _sendSmsReceiptInBackground({
    required String phone,
    required double paidAmount,
    required String receiptNo,
    required double remainingBalance,
  }) async {
    var status = await Permission.sms.status;
    if (!status.isGranted) {
      status = await Permission.sms.request();
    }

    if (status.isGranted) {
      final amountFormatted = NumberFormat('#,##0').format(paidAmount);
      final remainingFormatted = NumberFormat('#,##0').format(remainingBalance);

      String message =
          'تم سداد مبلغ $amountFormatted ريال\nالمرجع: $receiptNo\nالرصيد المتبقي: $remainingFormatted ريال\nمحطة الحسن 774130190';

      const platform = MethodChannel('com.alhasn.station/sms');

      try {
        await platform.invokeMethod('sendDirectSMS', {
          'phone': phone,
          'message': message,
        });
      } catch (e) {
        debugPrint("فشل إرسال الرسالة: $e");
      }
    }
  }

  // 🌟 تعديل دالة التأكيد لتشمل الحماية اللحظية القصوى
  Future<void> _confirmBeforeSave() async {
    // ========================================================
    // 🌟 1. التحديث اللحظي: جلب أحدث الصلاحيات في لحظة الضغط
    // ========================================================
    String? latestPermsStr = await SecureStorageHelper.getPermissions();
    if (latestPermsStr != null && mounted) {
      setState(() {
        _permissions = jsonDecode(latestPermsStr);
      });
    }

    // 🌟 2. الطرد من الشاشة إذا تم سحب صلاحية التحصيل وهو بداخلها
    if (_permissions['can_add_payment'] == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'عفواً، تم سحب صلاحية التحصيل منك للتو من قبل الإدارة.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      Navigator.pop(context); // إخراجه من شاشة التحصيل
      return;
    }

    // تشغيل الـ Validator (سيستخدم الآن الحدود المالية الجديدة إن تغيرت)
    if (!_formKey.currentState!.validate()) return;

    // 🌟 3. التحقق من صلاحية أوقات العمل
    if (!_isTimeAllowed()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'عذراً، الإدارة تمنع إضافة تسديدات في هذا الوقت من اليوم'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    // 🌟 4. التحقق من إجبارية الـ GPS
    bool requireGps = _permissions['require_gps_payment'] ?? true;
    if (requireGps) {
      var locationStatus = await Permission.locationWhenInUse.serviceStatus;
      var locationPermission = await Permission.locationWhenInUse.status;

      if (!locationStatus.isEnabled || !locationPermission.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'حسب صلاحياتك، يجب تفعيل الموقع الجغرافي (GPS) لإتمام العملية'),
            backgroundColor: Colors.red.shade700,
            action: SnackBarAction(
              label: 'تفعيل',
              textColor: Colors.white,
              onPressed: () => Permission.locationWhenInUse.request(),
            ),
          ),
        );
        return;
      }
    }

    final double amount = double.parse(_amountController.text);
    final formattedAmount = NumberFormat('#,##0').format(amount);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        bool isDialogSaving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                          color: Colors.green.withOpacity(0.2),
                          shape: BoxShape.circle),
                      child: Icon(Icons.help_outline_rounded,
                          color: Colors.green.shade700, size: 28),
                    ),
                    SizedBox(width: 10.w),
                    Text('تأكيد عملية التحصيل',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18.sp,
                            color: Colors.green.shade800)),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('هل أنت متأكد من تسجيل سند تحصيل للمشترك:',
                        style: TextStyle(
                            fontSize: 14.sp, color: Colors.grey.shade700)),
                    SizedBox(height: 6.h),
                    Text(widget.customer.nameCustomer,
                        style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A5276))),
                    Divider(height: 20.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('المبلغ المدفوع:'),
                        Text('$formattedAmount ريال',
                            style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700)),
                      ],
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                      onPressed: isDialogSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('تراجع',
                          style: TextStyle(color: Colors.grey))),
                  ElevatedButton(
                    onPressed: isDialogSaving
                        ? null
                        : () async {
                            setDialogState(() => isDialogSaving = true);
                            Navigator.of(context).pop();
                            await _savePayment();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r)),
                    ),
                    child: isDialogSaving
                        ? SizedBox(
                            width: 15.w,
                            height: 15.w,
                            child: const CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('نعم، تأكيد',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _savePayment() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      double amount = double.parse(_amountController.text);
      final db = await DatabaseHelper().database;

      Payment payment = Payment(
        id: 0,
        receiptNo: _receiptNoController.text,
        amount: amount,
        paymentDate: _dateController.text,
        paymentMethod: _selectedPaymentMethod,
        idCustomer: widget.customer.idCustomer,
        idGeathers: widget.empId,
        status: 'pending',
        syncStatus: 0,
      );

      Map<String, dynamic> paymentData = payment.toJson();
      paymentData.remove('id');

      await db.insert('app_collections', paymentData);

      double currentBalance = (widget.customer.instantBalance ?? 0).toDouble();
      double newBalance = currentBalance - amount;

      await db.update(
        'Customer',
        {'Instant_balance': newBalance},
        where: 'id_customer = ?',
        whereArgs: [widget.customer.idCustomer],
      );

      if (widget.empId > 0) {
        Provider.of<SyncProvider>(context, listen: false)
            .syncImmediately(widget.empId);
      }

      Customer updatedCustomer = Customer(
        idCustomer: widget.customer.idCustomer,
        nameCustomer: widget.customer.nameCustomer,
        numPhone: widget.customer.numPhone,
        addressCustomer: widget.customer.addressCustomer,
        nextCustomer: widget.customer.nextCustomer,
        streetCustomer: widget.customer.streetCustomer,
        typeWork: widget.customer.typeWork,
        setCustomer: widget.customer.setCustomer,
        numAccount: widget.customer.numAccount,
        numAddaad: widget.customer.numAddaad,
        idState: widget.customer.idState,
        tc: widget.customer.tc,
        instantBalance: newBalance,
        takeReading: widget.customer.takeReading,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => InvoiceScreen(
              customer: updatedCustomer,
              payment: payment,
            ),
          ),
        );
      }

      String? customerPhone = widget.customer.numPhone?.toString();
      if (customerPhone != null && customerPhone.isNotEmpty) {
        _sendSmsReceiptInBackground(
          phone: customerPhone,
          paidAmount: amount,
          receiptNo: _receiptNoController.text,
          remainingBalance: newBalance,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('حدث خطأ أثناء الحفظ: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPermissions) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    double currentBalance = (widget.customer.instantBalance ?? 0).toDouble();

    // سحب الحدود من الصلاحيات
    double maxPermittedPayment =
        (_permissions['max_payment'] ?? 100000).toDouble();
    double minPermittedPayment = (_permissions['min_payment'] ?? 0).toDouble();

    // دمج الحد الأدنى الإداري مع حد الـ 20% الخاص بالنظام
    double sysMinPayment = currentBalance > 0 ? (currentBalance * 0.2) : 0.0;
    double finalMinPayment = sysMinPayment > minPermittedPayment
        ? sysMinPayment
        : minPermittedPayment;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: Colors.green.shade700,
          title: Text('إضافة تحصيل',
              style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(20.w),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: EdgeInsets.all(15.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15.r),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.grey.withOpacity(0.1), blurRadius: 10)
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(widget.customer.nameCustomer,
                          style: TextStyle(
                              fontSize: 16.sp, fontWeight: FontWeight.bold)),
                      SizedBox(height: 5.h),
                      Text('رقم المشترك: ${widget.customer.idCustomer}',
                          style: TextStyle(
                              fontSize: 14.sp, color: Colors.grey.shade600)),
                      Divider(height: 20.h, color: Colors.grey.shade200),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              Text('الحد الأدنى للسداد',
                                  style: TextStyle(
                                      fontSize: 13.sp,
                                      color: Colors.orange.shade700)),
                              Text(
                                  '${NumberFormat('#,##0').format(finalMinPayment)}',
                                  style: TextStyle(
                                      fontSize: 20.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade700)),
                            ],
                          ),
                          Container(
                              height: 40.h,
                              width: 1.w,
                              color: Colors.grey.shade300),
                          Column(
                            children: [
                              Text('إجمالي المستحق',
                                  style: TextStyle(
                                      fontSize: 13.sp,
                                      color: Colors.red.shade700)),
                              Text(
                                  '${NumberFormat('#,##0').format(currentBalance)}',
                                  style: TextStyle(
                                      fontSize: 20.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade700)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 25.h),
                TextFormField(
                  controller: _receiptNoController,
                  decoration: InputDecoration(
                    labelText: 'رقم السند الدفتري (اختياري)',
                    prefixIcon:
                        const Icon(Icons.receipt_long, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                ),
                SizedBox(height: 15.h),
                TextFormField(
                  controller: _dateController,
                  readOnly: true,
                  onTap: _pickDateTime,
                  decoration: InputDecoration(
                    labelText: 'تاريخ ووقت التحصيل',
                    prefixIcon:
                        const Icon(Icons.calendar_today, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                ),
                SizedBox(height: 15.h),
                DropdownButtonFormField<String>(
                  value: _selectedPaymentMethod,
                  decoration: InputDecoration(
                    labelText: 'نوع الدفع',
                    prefixIcon: const Icon(Icons.payment, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                  items: _paymentMethods.map((method) {
                    return DropdownMenuItem(
                      value: method,
                      child: Text(method),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedPaymentMethod = value!;
                    });
                  },
                ),
                SizedBox(height: 20.h),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'يرجى إدخال المبلغ';
                    }
                    double? parsedAmount = double.tryParse(value);
                    if (parsedAmount == null) return 'المبلغ غير صحيح';
                    if (parsedAmount <= 0) {
                      return 'المبلغ يجب أن يكون أكبر من صفر';
                    }

                    // 🌟 الحماية اللحظية: سحب أحدث القيم ديناميكياً للتحقق
                    double currentMax =
                        (_permissions['max_payment'] ?? 100000).toDouble();
                    double currentMinLimit =
                        (_permissions['min_payment'] ?? 0).toDouble();
                    double currentSysMin =
                        currentBalance > 0 ? (currentBalance * 0.2) : 0.0;
                    double currentFinalMin = currentSysMin > currentMinLimit
                        ? currentSysMin
                        : currentMinLimit;

                    if (parsedAmount > currentMax) {
                      return 'يتجاوز الحد الأعلى المصرح لك: ${NumberFormat('#,##0').format(currentMax)} ريال';
                    }

                    if (currentFinalMin > 0 && parsedAmount < currentFinalMin) {
                      return 'لا يمكن سداد أقل من ${NumberFormat('#,##0').format(currentFinalMin)} ريال';
                    }

                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'المبلغ المحصل (ريال)',
                    prefixIcon: Icon(Icons.money, color: Colors.green.shade700),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide(color: Colors.green.shade200)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide:
                            BorderSide(color: Colors.green.shade700, width: 2)),
                  ),
                  style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 35.h),
                SizedBox(
                  height: 55.h,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _confirmBeforeSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r)),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text('تأكيد التحصيل',
                            style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
