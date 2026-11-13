import 'dart:io';
import 'dart:convert';
import 'dart:async'; // 🌟 لاستخدام المؤقت (Timer) في المزامنة التلقائية
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sqflite/sqflite.dart';
import 'package:dio/dio.dart';
import '../database/database_helper.dart';
import '../models/customer.dart';
import '../core/utils/secure_storage_helper.dart'; // 🌟 لحفظ وقراءة وقت المزامنة

class SyncProvider extends ChangeNotifier {
  // فصل المتغيرات لكي لا يتداخل التحميل بين الزرين
  bool _isPulling = false;
  bool _isPushing = false;
  String _syncMessage = '';

  bool get isPulling => _isPulling;
  bool get isPushing => _isPushing;
  // متغير لمعرفة ما إذا كانت أي عملية قيد التنفيذ لإيقاف الزر الآخر مؤقتاً
  bool get isSyncing => _isPulling || _isPushing;
  String get syncMessage => _syncMessage;

  final String _pullUrl = 'https://saleh.me.ye/api/pull_customers.php';
  final String _pushUrl = 'https://saleh.me.ye/api/push_data.php';
  final String _uploadImageUrl = 'https://saleh.me.ye/api/upload_image.php';

  // 🌟 مفتاح الحماية الأمني الموحد مع السيرفر
  final Map<String, dynamic> _apiHeaders = {
    'App-Secret-Key': 'Saleh#2026@Secure',
  };

  Timer? _autoSyncTimer; // 🌟 متغير المؤقت للمزامنة التلقائية

  void _updateStatus(String message) {
    _syncMessage = message;
    notifyListeners();
  }

  // ==========================================
  // 1. التنزيل الذكي (Delta Pull) - يجلب التحديثات فقط
  // ==========================================
  Future<bool> pullData(int currentEmpId) async {
    _isPulling = true;
    _updateStatus('جاري التحقق من التحديثات الجديدة...');
    notifyListeners();

    try {
      // 🌟 جلب وقت آخر مزامنة من الذاكرة (سيكون null في أول مرة)
      String? lastSyncTime = await SecureStorageHelper.getLastSyncTime();

      final dio = Dio();
      final response = await dio.post(
        _pullUrl,
        data: {
          'emp_id': currentEmpId,
          'last_sync_time': lastSyncTime ?? '', // 🌟 إرسال الوقت للسيرفر
        },
        options: Options(headers: _apiHeaders),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          List<dynamic> serverCustomers = data['customers'] ?? [];
          List<dynamic> serverChits = data['chits'] ?? [];
          List<dynamic> serverSandaat = data['sandaat'] ?? [];
          List<dynamic> serverMonths = data['months'] ?? [];
          List<dynamic> serverStreets = data['streets'] ?? [];

          final db = await DatabaseHelper().database;

          await db.transaction((txn) async {
            try {
              for (var item in serverCustomers) {
                final cleanCustomer = Customer.fromJson(item).toJson();
                await txn.insert('Customer', cleanCustomer,
                    conflictAlgorithm: ConflictAlgorithm.replace);
              }

              for (var item in serverChits) {
                await txn.insert(
                    'Take_up_Chits', Map<String, Object?>.from(item),
                    conflictAlgorithm: ConflictAlgorithm.replace);
              }

              for (var item in serverSandaat) {
                await txn.insert(
                    'Sandaat_paying_up', Map<String, Object?>.from(item),
                    conflictAlgorithm: ConflictAlgorithm.replace);
              }

              for (var item in serverMonths) {
                await txn.insert('Months', Map<String, Object?>.from(item),
                    conflictAlgorithm: ConflictAlgorithm.replace);
              }

              for (var item in serverStreets) {
                await txn.insert(
                    'Streets_Line', Map<String, Object?>.from(item),
                    conflictAlgorithm: ConflictAlgorithm.replace);
              }
            } catch (e, stacktrace) {
              debugPrint('🚨 خطأ فادح أثناء حفظ البيانات في SQLite: $e');
            }
          });

          // 🌟 بعد الحفظ بنجاح، نحفظ وقت السيرفر الجديد للمزامنة القادمة
          if (data['server_time'] != null) {
            await SecureStorageHelper.saveLastSyncTime(data['server_time']);
          }

          int updatesCount = serverCustomers.length + serverSandaat.length;
          if (updatesCount > 0) {
            _updateStatus('تم سحب وتحديث ($updatesCount) سجل بنجاح ✓');
          } else {
            _updateStatus('قاعدة البيانات لديك محدثة بالفعل ✓');
          }
          return true;
        } else {
          _updateStatus(data['message'] ?? 'فشل في جلب البيانات');
          return false;
        }
      } else {
        _updateStatus('خطأ في الاتصال بالخادم');
        return false;
      }
    } catch (e) {
      debugPrint('Sync Error (Pull): $e');
      _updateStatus('حدث خطأ أثناء التنزيل: تأكد من الاتصال بالإنترنت');
      return false;
    } finally {
      _isPulling = false;
      notifyListeners();
    }
  }

  // ==========================================
  // 2. رفع التحصيلات والقراءات (Push)
  // ==========================================
  Future<bool> pushData(int currentEmpId) async {
    _isPushing = true;
    _updateStatus('جاري تحديد الموقع وتجهيز البيانات المعلقة لرفعها...');
    notifyListeners();

    try {
      double? latitude;
      double? longitude;
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse) {
            Position position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 5),
            );
            latitude = position.latitude;
            longitude = position.longitude;
          }
        }
      } catch (locError) {
        debugPrint('⚠️ تعذر جلب الموقع الجغرافي أو انتهى الوقت: $locError');
      }

      final db = await DatabaseHelper().database;

      final pendingPayments =
          await db.query('app_collections', where: "status = 'pending'");
      final List<Map<String, dynamic>> rawReadings =
          await db.query('app_readings', where: "status = 'pending'");
      final pendingModifications =
          await db.query('modification_requests', where: "status = 'pending'");
      final pendingInvoices = await db
          .query('app_invoices', where: "sync_status = ?", whereArgs: [0]);

      if (pendingPayments.isEmpty &&
          rawReadings.isEmpty &&
          pendingModifications.isEmpty &&
          pendingInvoices.isEmpty) {
        _updateStatus('لا توجد بيانات جديدة لرفعها.');
        return true;
      }

      final dio = Dio();
      List<Map<String, dynamic>> processedReadings = [];

      for (var reading in rawReadings) {
        Map<String, dynamic> readingData = Map.from(reading);
        String? localImagePath =
            readingData['image_path'] ?? readingData['imagePath'];

        readingData['image_path'] = '';
        readingData['imagePath'] = '';

        if (localImagePath != null && localImagePath.isNotEmpty) {
          File imageFile = File(localImagePath);
          if (await imageFile.exists()) {
            try {
              _updateStatus('جاري رفع صورة العداد...');
              String fileName = imageFile.path.split('/').last;

              FormData formData = FormData.fromMap({
                'image': await MultipartFile.fromFile(imageFile.path,
                    filename: fileName),
              });

              var uploadResponse = await dio.post(
                _uploadImageUrl,
                data: formData,
                options: Options(headers: _apiHeaders),
              );
              var responseData = uploadResponse.data;

              if (responseData is String) {
                try {
                  responseData = jsonDecode(responseData);
                } catch (formatError) {
                  responseData = {
                    'success': false,
                    'message': 'رد غير متوقع من السيرفر'
                  };
                }
              }

              if (uploadResponse.statusCode == 200 &&
                  responseData['success'] == true) {
                readingData['image_path'] = responseData['image_url'];
              } else {
                debugPrint('❌ فشل رفع الصورة للسيرفر');
              }
            } catch (imgError) {
              debugPrint('❌ انهيار أثناء الاتصال لرفع الصورة: $imgError');
            }
          }
        }
        processedReadings.add(readingData);
      }

      _updateStatus('جاري إرسال البيانات النهائية مع الموقع...');

      final response = await dio.post(
        _pushUrl,
        data: {
          'emp_id': currentEmpId,
          'latitude': latitude?.toString(),
          'longitude': longitude?.toString(),
          'collections': pendingPayments,
          'readings': processedReadings,
          'modifications': pendingModifications,
          'invoices': pendingInvoices,
        },
        options: Options(headers: _apiHeaders),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          await db.transaction((txn) async {
            for (var payment in pendingPayments) {
              await txn.update('app_collections', {'status': 'synced'},
                  where: 'id = ?', whereArgs: [payment['id']]);
            }
            for (var reading in rawReadings) {
              await txn.update('app_readings', {'status': 'synced'},
                  where: 'id = ?', whereArgs: [reading['id']]);
            }
            for (var mod in pendingModifications) {
              await txn.update('modification_requests', {'status': 'synced'},
                  where: 'id = ?', whereArgs: [mod['id']]);
            }
            for (var invoice in pendingInvoices) {
              await txn.update('app_invoices', {'sync_status': 1},
                  where: 'id = ?', whereArgs: [invoice['id']]);
            }
          });

          _updateStatus('تمت المزامنة ورفع البيانات بنجاح ✓');
          return true;
        } else {
          _updateStatus(data['message'] ?? 'فشل رفع البيانات');
          return false;
        }
      } else {
        _updateStatus('خطأ في الاتصال بالخادم أثناء الرفع');
        return false;
      }
    } catch (e) {
      debugPrint('Sync Error (Push): $e');
      _updateStatus('حدث خطأ أثناء الرفع: تأكد من الاتصال بالإنترنت');
      return false;
    } finally {
      _isPushing = false;
      notifyListeners();
    }
  }

  // ==========================================
  // 3. المزامنة التلقائية (Auto-Sync) كل 10 دقائق
  // ==========================================
  void startAutoSync(int currentEmpId, {int intervalMinutes = 10}) {
    stopAutoSync();
    debugPrint('⏳ تم تشغيل المزامنة التلقائية كل $intervalMinutes دقائق');

    _autoSyncTimer =
        Timer.periodic(Duration(minutes: intervalMinutes), (timer) async {
      if (!isSyncing) {
        debugPrint('🔄 بدء المزامنة الدورية التلقائية...');

        bool pushSuccess = await pushData(currentEmpId);

        if (pushSuccess) {
          await pullData(currentEmpId);
        }

        Future.delayed(const Duration(seconds: 3), () {
          _updateStatus('');
        });
      }
    });
  }

  void stopAutoSync() {
    if (_autoSyncTimer != null && _autoSyncTimer!.isActive) {
      _autoSyncTimer!.cancel();
      debugPrint('🛑 تم إيقاف المزامنة التلقائية');
    }
  }

  // ==========================================
  // 🌟 4. المزامنة الفورية عند الحفظ (Sync-on-Save)
  // ==========================================
  Future<void> syncImmediately(int currentEmpId) async {
    if (isSyncing) return;

    try {
      debugPrint('⚡ بدء المزامنة الفورية في الخلفية...');
      bool pushSuccess = await pushData(currentEmpId);

      if (pushSuccess) {
        await pullData(currentEmpId);
      }
    } catch (e) {
      debugPrint('⚠️ خطأ في المزامنة الفورية: $e');
    }
  }
}
