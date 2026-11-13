import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import 'dart:convert'; // 🌟 للتعامل مع الصلاحيات
import 'package:permission_handler/permission_handler.dart'; // 🌟 للتحقق من الـ GPS

import '../models/customer.dart';
import '../models/reading.dart';
import '../database/database_helper.dart';
import '../core/utils/secure_storage_helper.dart';
import '../providers/sync_provider.dart';

class AddReadingScreen extends StatefulWidget {
  final Customer customer;

  const AddReadingScreen({super.key, required this.customer});

  @override
  State<AddReadingScreen> createState() => _AddReadingScreenState();
}

class _AddReadingScreenState extends State<AddReadingScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _readingController = TextEditingController();
  final TextEditingController _lastReadController = TextEditingController();

  late TextEditingController _dateController;
  DateTime _selectedDate = DateTime.now();
  File? _meterImageFile;
  final ImagePicker _picker = ImagePicker();

  bool _isSaving = false;
  bool _isLoadingLastRead = true;
  int _currentEmpId = 0;
  double _lastReadValue = 0.0;

  // 🌟 متغيرات الصلاحيات
  Map<String, dynamic> _permissions = {};
  bool _isLoadingPermissions = true;

  @override
  void initState() {
    super.initState();
    _loadPermissions(); // 🌟 تحميل الصلاحيات
    _loadEmpId();
    _fetchLastReadLocal();
    _retrieveLostData();

    _dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd HH:mm:ss').format(_selectedDate),
    );
  }

  // 🌟 دالة جلب الصلاحيات من الذاكرة المحلية
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

  // 🌟 دالة التحقق من أوقات العمل المسموحة
  bool _isTimeAllowed() {
    List<dynamic> allowedHours = _permissions['allowed_hours'] ?? [];
    if (allowedHours.isEmpty) return true; // إذا كانت فارغة نفترض السماح

    // سحب الساعة الحالية بصيغة خانتين (مثل 08 أو 15)
    String currentHour = DateTime.now().hour.toString().padLeft(2, '0');
    return allowedHours.any((h) => h.toString().padLeft(2, '0') == currentHour);
  }

  Future<void> _retrieveLostData() async {
    if (Platform.isAndroid) {
      try {
        final LostDataResponse response = await _picker.retrieveLostData();
        if (response.isEmpty) return;
        if (response.file != null) {
          setState(() {
            _meterImageFile = File(response.file!.path);
          });
        }
      } catch (e) {
        debugPrint('خطأ في استرجاع الصورة المفقودة: $e');
      }
    }
  }

  Future<void> _loadEmpId() async {
    String? empIdStr = await SecureStorageHelper.getEmpId();
    if (mounted) {
      setState(() {
        _currentEmpId = int.tryParse(empIdStr ?? '0') ?? 0;
      });
    }
  }

  Future<void> _fetchLastReadLocal() async {
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
        final double lastReadingFromDb = (chits.first['now_reead'] is num)
            ? (chits.first['now_reead'] as num).toDouble()
            : 0.0;

        if (mounted) {
          setState(() {
            _lastReadValue = lastReadingFromDb;
            _lastReadController.text = _lastReadValue.toString();
            _isLoadingLastRead = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _lastReadValue = 0.0;
            _lastReadController.text = "0.0";
            _isLoadingLastRead = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching last read locally: $e');
      if (mounted) setState(() => _isLoadingLastRead = false);
    }
  }

  Future<void> _pickDateTime() async {
    if (widget.customer.takeReading == 1) return;

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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 60,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (pickedFile != null) {
        setState(() {
          _meterImageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('خطأ أثناء التقاط الصورة: $e');
    }
  }

  @override
  void dispose() {
    _readingController.dispose();
    _lastReadController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _saveReading() async {
    if (widget.customer.takeReading == 1) return;
    if (_isSaving) return;

    // ========================================================
    // 🌟 1. التحديث اللحظي: جلب أحدث الصلاحيات في لحظة الضغط
    // ========================================================
    String? latestPermsStr = await SecureStorageHelper.getPermissions();
    if (latestPermsStr != null && mounted) {
      setState(() {
        _permissions = jsonDecode(latestPermsStr);
      });
    }

    // 🌟 2. الطرد من الشاشة إذا تم سحب صلاحية القراءة وهو بداخلها
    if (_permissions['can_add_reading'] == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'عفواً، تم سحب صلاحية إدخال القراءات منك للتو من قبل الإدارة.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      Navigator.pop(context); // إخراجه من شاشة القراءة
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    // 🌟 3. التحقق من صلاحية أوقات العمل
    if (!_isTimeAllowed()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'عذراً، الإدارة تمنع إدخال القراءات في هذا الوقت من اليوم'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    // 🌟 4. التحقق من إجبارية التقاط الصورة (محدثة لحظياً)
    bool requirePhoto = _permissions['require_photo_reading'] ?? false;
    if (requirePhoto && _meterImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'حسب صلاحياتك المحدثة، يجب التقاط صورة للعداد قبل الحفظ'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    // 🌟 5. التحقق من صلاحية إجبارية الـ GPS (محدثة لحظياً)
    bool requireGps = _permissions['require_gps_reading'] ?? true;
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

    double readingValue = double.parse(_readingController.text);

    if (readingValue < _lastReadValue) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('خطأ: القراءة الحالية أقل من القراءة السابقة!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = await DatabaseHelper().database;

      Reading reading = Reading(
        id: 0,
        numAddaad: widget.customer.numAddaad != null
            ? int.tryParse(widget.customer.numAddaad.toString())
            : null,
        readingValue: readingValue,
        readingDate: _dateController.text,
        currentMonth: DateFormat('MM').format(_selectedDate),
        idCustomer: widget.customer.idCustomer,
        idGeathers: _currentEmpId,
        status: 'pending',
        imagePath: _meterImageFile?.path,
      );

      Map<String, dynamic> readingData = reading.toJson();
      readingData.remove('id');

      await db.insert('app_readings', readingData);

      await db.update(
        'Customer',
        {'Take_reading': 1},
        where: 'id_customer = ?',
        whereArgs: [widget.customer.idCustomer],
      );

      if (_currentEmpId > 0) {
        Provider.of<SyncProvider>(context, listen: false)
            .syncImmediately(_currentEmpId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ القراءة وإرسالها للسيرفر بنجاح ✓'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
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

    final bool isAlreadyRead = widget.customer.takeReading == 1;
    bool requirePhoto = _permissions['require_photo_reading'] ?? false;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A5276),
          title: Text('تسجيل القراءة',
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
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('رقم العداد:',
                              style: TextStyle(
                                  fontSize: 14.sp,
                                  color: Colors.grey.shade700)),
                          Text(
                              widget.customer.numAddaad?.toString() ??
                                  'غير متوفر',
                              style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1A5276))),
                        ],
                      ),
                      if (isAlreadyRead)
                        Container(
                          padding: EdgeInsets.all(8.w),
                          margin: EdgeInsets.only(top: 10.h),
                          decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(color: Colors.red.shade200)),
                          child: Row(
                            children: [
                              Icon(Icons.lock,
                                  color: Colors.red.shade700, size: 20.w),
                              SizedBox(width: 8.w),
                              Expanded(
                                  child: Text(
                                      'تم أخذ قراءة هذا المشترك مسبقاً في هذه الدورة ولا يمكن تعديلها.',
                                      style: TextStyle(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red.shade900))),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),
                _isLoadingLastRead
                    ? const Center(child: CircularProgressIndicator())
                    : TextFormField(
                        controller: _lastReadController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'القراءة السابقة',
                          prefixIcon:
                              const Icon(Icons.history, color: Colors.grey),
                          filled: true,
                          fillColor: Colors.grey.shade200,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.r),
                              borderSide: BorderSide.none),
                        ),
                        style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700),
                        textAlign: TextAlign.center,
                      ),
                SizedBox(height: 20.h),
                TextFormField(
                  controller: _dateController,
                  readOnly: true,
                  onTap: _pickDateTime,
                  decoration: InputDecoration(
                    labelText: 'تاريخ ووقت القراءة',
                    prefixIcon: Icon(Icons.calendar_today,
                        color: isAlreadyRead
                            ? Colors.grey
                            : const Color(0xFF1A5276)),
                    filled: true,
                    fillColor:
                        isAlreadyRead ? Colors.grey.shade200 : Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                ),
                SizedBox(height: 20.h),
                TextFormField(
                  controller: _readingController,
                  keyboardType: TextInputType.number,
                  enabled: !isAlreadyRead,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'يرجى إدخال القراءة';
                    }
                    if (double.tryParse(value) == null) {
                      return 'القراءة غير صحيحة';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'القراءة الحالية بالارقام',
                    prefixIcon: Icon(Icons.speed,
                        color: isAlreadyRead
                            ? Colors.grey
                            : const Color(0xFF1A5276)),
                    filled: true,
                    fillColor:
                        isAlreadyRead ? Colors.grey.shade200 : Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r)),
                  ),
                  style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                      color:
                          isAlreadyRead ? Colors.grey : const Color(0xFF1A5276),
                      letterSpacing: 2),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20.h),
                if (!isAlreadyRead)
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                requirePhoto
                                    ? 'صورة العداد (إجباري):'
                                    : 'صورة العداد (اختياري):',
                                style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                    color: requirePhoto
                                        ? Colors.red.shade700
                                        : Colors.grey.shade700)),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () =>
                                      _pickImage(ImageSource.camera),
                                  icon: const Icon(Icons.camera_alt,
                                      color: Color(0xFF1A5276)),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      _pickImage(ImageSource.gallery),
                                  icon: const Icon(Icons.photo_library,
                                      color: Colors.green),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (_meterImageFile != null) ...[
                          SizedBox(height: 10.h),
                          Stack(
                            alignment: Alignment.topRight,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8.r),
                                child: Image.file(
                                  _meterImageFile!,
                                  height: 150.h,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    setState(() => _meterImageFile = null),
                                icon: const Icon(Icons.remove_circle,
                                    color: Colors.red, size: 30),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                SizedBox(height: 30.h),
                SizedBox(
                  height: 55.h,
                  child: ElevatedButton(
                    onPressed:
                        (_isSaving || isAlreadyRead) ? null : _saveReading,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A5276),
                      disabledBackgroundColor: Colors.grey.shade400,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r)),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            isAlreadyRead
                                ? 'تم تسجيل القراءة مسبقاً'
                                : 'حفظ القراءة',
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
