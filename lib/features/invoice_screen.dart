import 'dart:io';

import 'package:electricity_collectors_app/features/printer_settings_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:permission_handler/permission_handler.dart';
import 'package:charset_converter/charset_converter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/customer.dart';
import '../models/payment.dart';
import '../database/database_helper.dart';
import '../core/utils/secure_storage_helper.dart';

class InvoiceScreen extends StatefulWidget {
  final Customer customer;
  final Payment payment;

  const InvoiceScreen({
    super.key,
    required this.customer,
    required this.payment,
  });

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  // ============================================================
  // Bluetooth
  // ============================================================

  List<BluetoothInfo> _devices = [];

  BluetoothInfo? _selectedDevice;

  bool _connected = false;

  bool _isProcessing = false;

  // ============================================================
  // بيانات المحصل
  // ============================================================

  String _collectorName = 'جاري التحميل...';

  // ============================================================
  // بيانات المحطة
  // ============================================================

  final String stationName = "محطة الحسن لتوليد الطاقة الكهربائية";

  final String stationAddress = "ذمار - منطقة الجامعة - ";

  final String stationPhones = "770999225 - 783771077";

  // ============================================================
  // إعدادات الطابعة
  // ============================================================

  String _paperSize = '58mm';

  String _alignment = 'center';

  double _fontSize = 2;

  double _lineSpacing = 1.0;

  bool _autoConnect = true;

  bool _autoReconnect = true;

  bool _showCollector = true;

  bool _showReceiptNumber = true;

  bool _showDateTime = true;

  bool _showNumericAmount = true;

  bool _showWrittenAmount = true;

  bool _showNotes = true;

  bool _autoCut = false;

  bool _rtl = true;

  int _copies = 1;

  // ============================================================
  // SharedPreferences
  // ============================================================

  SharedPreferences? _prefs;

  String? _savedPrinterMac;

  String? _savedPrinterName;

  // ============================================================
  // بدء الشاشة
  // ============================================================

  @override
  void initState() {
    super.initState();

    _initialize();
  }

  Future<void> _initialize() async {
    await _loadPrinterSettings();

    await _loadCollectorName();

    await _initBluetooth();
  }

  // ============================================================
  // تحميل اسم المحصل
  // ============================================================

  Future<void> _loadCollectorName() async {
    final String? name = await SecureStorageHelper.getEmpName();

    if (!mounted) return;

    setState(() {
      _collectorName = name ?? 'غير معروف';
    });
  }

  // ============================================================
  // تحميل إعدادات الطابعة
  // ============================================================

  Future<void> _loadPrinterSettings() async {
    _prefs ??= await SharedPreferences.getInstance();

    _paperSize = _prefs!.getString(
          'printer_paper_size',
        ) ??
        '58mm';

    _alignment = _prefs!.getString(
          'printer_alignment',
        ) ??
        'center';

    _fontSize = _prefs!.getDouble(
          'printer_font_size',
        ) ??
        2;

    _lineSpacing = _prefs!.getDouble(
          'printer_line_spacing',
        ) ??
        1.0;

    _autoConnect = _prefs!.getBool(
          'printer_auto_connect',
        ) ??
        true;

    _autoReconnect = _prefs!.getBool(
          'printer_auto_reconnect',
        ) ??
        true;

    _showCollector = _prefs!.getBool(
          'printer_show_collector',
        ) ??
        true;

    _showReceiptNumber = _prefs!.getBool(
          'printer_show_receipt_number',
        ) ??
        true;

    _showDateTime = _prefs!.getBool(
          'printer_show_date_time',
        ) ??
        true;

    _showNumericAmount = _prefs!.getBool(
          'printer_show_numeric_amount',
        ) ??
        true;

    _showWrittenAmount = _prefs!.getBool(
          'printer_show_written_amount',
        ) ??
        true;

    _showNotes = _prefs!.getBool(
          'printer_show_notes',
        ) ??
        true;

    _autoCut = _prefs!.getBool(
          'printer_auto_cut',
        ) ??
        false;

    _rtl = _prefs!.getBool(
          'printer_rtl',
        ) ??
        true;

    _copies = _prefs!.getInt(
          'printer_copies',
        ) ??
        1;

    if (_copies < 1) {
      _copies = 1;
    }

    if (_copies > 5) {
      _copies = 5;
    }

    _savedPrinterName = _prefs!.getString(
      'printer_name',
    );

    _savedPrinterMac = _prefs!.getString(
      'printer_mac',
    );

    debugPrint(
      'Saved printer: $_savedPrinterName',
    );

    debugPrint(
      'Saved printer MAC: $_savedPrinterMac',
    );

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // Bluetooth
  // ============================================================

  Future<void> _initBluetooth() async {
    try {
      final Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      final bool permissionGranted =
          statuses[Permission.bluetoothConnect]?.isGranted == true ||
              statuses[Permission.bluetoothScan]?.isGranted == true ||
              statuses[Permission.location]?.isGranted == true;

      if (!permissionGranted) {
        debugPrint(
          'Bluetooth permission not granted',
        );
        return;
      }

      final bool bluetoothEnabled =
          await PrintBluetoothThermal.bluetoothEnabled;

      if (!bluetoothEnabled) {
        debugPrint(
          'Bluetooth is disabled',
        );

        return;
      }

      final bool isConnected = await PrintBluetoothThermal.connectionStatus;

      List<BluetoothInfo> devices = [];

      try {
        devices = await PrintBluetoothThermal.pairedBluetooths;
      } catch (e) {
        debugPrint(
          'Error fetching Bluetooth devices: $e',
        );
      }

      BluetoothInfo? savedDevice;

      if (_savedPrinterMac != null && _savedPrinterMac!.isNotEmpty) {
        for (final device in devices) {
          if (device.macAdress == _savedPrinterMac) {
            savedDevice = device;
            break;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _devices = devices;

        _connected = isConnected;

        _selectedDevice = savedDevice;
      });

      // ========================================================
      // الاتصال التلقائي
      // ========================================================

      if (_autoConnect && savedDevice != null) {
        final bool currentlyConnected =
            await PrintBluetoothThermal.connectionStatus;

        if (!currentlyConnected) {
          await _connectToPrinter(
            savedDevice,
            showMessage: false,
          );
        }
      }
    } catch (e) {
      debugPrint(
        'Bluetooth initialization error: $e',
      );
    }
  }

  // ============================================================
  // الاتصال بالطابعة
  // ============================================================

  Future<bool> _connectToPrinter(
    BluetoothInfo device, {
    bool showMessage = true,
  }) async {
    try {
      if (mounted) {
        setState(() {
          _selectedDevice = device;
        });
      }

      final bool alreadyConnected =
          await PrintBluetoothThermal.connectionStatus;

      if (alreadyConnected) {
        if (mounted) {
          setState(() {
            _connected = true;
          });
        }

        await _saveSelectedPrinter(device);

        return true;
      }

      if (showMessage && mounted) {
        _showMessage(
          'جاري الاتصال بالطابعة...',
          backgroundColor: Colors.orange,
        );
      }

      final bool connected = await PrintBluetoothThermal.connect(
        macPrinterAddress: device.macAdress,
      );

      if (!mounted) {
        return connected;
      }

      if (connected) {
        setState(() {
          _connected = true;

          _selectedDevice = device;
        });

        await _saveSelectedPrinter(
          device,
        );

        if (showMessage) {
          _showMessage(
            'تم الاتصال بالطابعة بنجاح',
            backgroundColor: Colors.green,
          );
        }

        return true;
      }

      setState(() {
        _connected = false;
      });

      if (showMessage) {
        _showMessage(
          'فشل الاتصال بالطابعة',
          backgroundColor: Colors.red,
        );
      }

      return false;
    } catch (e) {
      if (mounted && showMessage) {
        _showMessage(
          'فشل الاتصال: $e',
          backgroundColor: Colors.red,
        );
      }

      return false;
    }
  }

  // ============================================================
  // حفظ الطابعة المختارة
  // ============================================================

  Future<void> _saveSelectedPrinter(
    BluetoothInfo device,
  ) async {
    _prefs ??= await SharedPreferences.getInstance();

    await _prefs!.setString(
      'printer_name',
      device.name,
    );

    await _prefs!.setString(
      'printer_mac',
      device.macAdress,
    );

    _savedPrinterName = device.name;

    _savedPrinterMac = device.macAdress;

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // عرض اختيار الطابعة
  // ============================================================

  void _showPrinterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20.r),
        ),
      ),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            height: 500.h,
            padding: EdgeInsets.all(20.w),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.bluetooth,
                      color: Colors.blue,
                    ),
                    SizedBox(
                      width: 10.w,
                    ),
                    Text(
                      'اختر طابعة البلوتوث',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 8.h,
                ),
                Text(
                  'اختر الطابعة التي تريد استخدامها للسندات',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(
                  height: 15.h,
                ),
                Expanded(
                  child: _devices.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.print_disabled_outlined,
                                size: 55,
                                color: Colors.grey.shade400,
                              ),
                              SizedBox(
                                height: 12.h,
                              ),
                              Text(
                                'لم يتم العثور على طابعات مقترنة',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              SizedBox(
                                height: 6.h,
                              ),
                              Text(
                                'يرجى إقران الطابعة من إعدادات Bluetooth في الهاتف.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _devices.length,
                          itemBuilder: (context, index) {
                            final device = _devices[index];

                            final bool selected =
                                _selectedDevice?.macAdress == device.macAdress;

                            return Container(
                              margin: EdgeInsets.only(
                                bottom: 8.h,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.blue.shade50
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(
                                  14.r,
                                ),
                                border: Border.all(
                                  color: selected
                                      ? Colors.blue
                                      : Colors.grey.shade200,
                                ),
                              ),
                              child: ListTile(
                                leading: Container(
                                  width: 45.w,
                                  height: 45.w,
                                  decoration: BoxDecoration(
                                    color:
                                        selected ? Colors.blue : Colors.white,
                                    borderRadius: BorderRadius.circular(
                                      12.r,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.print,
                                    color: selected
                                        ? Colors.white
                                        : Colors.black54,
                                  ),
                                ),
                                title: Text(
                                  device.name.isEmpty
                                      ? 'طابعة غير معروفة'
                                      : device.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  device.macAdress,
                                ),
                                trailing: selected
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      )
                                    : const Icon(
                                        Icons.chevron_left,
                                      ),
                                onTap: () async {
                                  Navigator.pop(
                                    context,
                                  );

                                  final bool connected =
                                      await _connectToPrinter(
                                    device,
                                  );

                                  if (connected) {
                                    final bool printed =
                                        await _printReceiptData();

                                    if (printed) {
                                      await _saveInvoiceToDb();
                                    }
                                  }
                                },
                              ),
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

  // ============================================================
  // طباعة وحفظ السند
  // ============================================================

  Future<void> _handlePrintAndSave() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await _loadPrinterSettings();

      bool connected = await PrintBluetoothThermal.connectionStatus;

      // ========================================================
      // لا توجد طابعة محفوظة
      // ========================================================

      if (!connected &&
          (_savedPrinterMac == null || _savedPrinterMac!.isEmpty)) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });

          _showPrinterDialog();
        }

        return;
      }

      // ========================================================
      // محاولة الاتصال بالطابعة المحفوظة
      // ========================================================

      if (!connected &&
          _savedPrinterMac != null &&
          _savedPrinterMac!.isNotEmpty) {
        BluetoothInfo? savedDevice;

        for (final device in _devices) {
          if (device.macAdress == _savedPrinterMac) {
            savedDevice = device;
            break;
          }
        }

        // ------------------------------------------------------
        // إعادة قراءة الأجهزة إذا لم نجد الطابعة
        // ------------------------------------------------------

        if (savedDevice == null) {
          try {
            _devices = await PrintBluetoothThermal.pairedBluetooths;

            for (final device in _devices) {
              if (device.macAdress == _savedPrinterMac) {
                savedDevice = device;
                break;
              }
            }
          } catch (e) {
            debugPrint(
              'Refresh printers error: $e',
            );
          }
        }

        // ------------------------------------------------------
        // الاتصال
        // ------------------------------------------------------

        if (savedDevice != null) {
          connected = await _connectToPrinter(
            savedDevice,
            showMessage: true,
          );
        }
      }

      // ========================================================
      // إعادة الاتصال إذا كان Auto Reconnect مفعلاً
      // ========================================================

      if (!connected &&
          _autoReconnect &&
          _savedPrinterMac != null &&
          _savedPrinterMac!.isNotEmpty) {
        try {
          final devices = await PrintBluetoothThermal.pairedBluetooths;

          for (final device in devices) {
            if (device.macAdress == _savedPrinterMac) {
              connected = await _connectToPrinter(
                device,
                showMessage: false,
              );

              if (connected) {
                break;
              }
            }
          }
        } catch (e) {
          debugPrint(
            'Auto reconnect error: $e',
          );
        }
      }

      // ========================================================
      // فشل الاتصال
      // ========================================================

      if (!connected) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });

          _showMessage(
            'تعذر الاتصال بالطابعة المحفوظة، اختر الطابعة مرة أخرى',
            backgroundColor: Colors.red,
          );

          _showPrinterDialog();
        }

        return;
      }

      // ========================================================
      // الطباعة
      // ========================================================

      final bool printed = await _printReceiptData();

      // ========================================================
      // الحفظ بعد نجاح الطباعة فقط
      // ========================================================

      if (printed) {
        await _saveInvoiceToDb();
      }
    } catch (e) {
      debugPrint(
        'Print and save error: $e',
      );

      if (mounted) {
        _showMessage(
          'حدث خطأ أثناء الطباعة: $e',
          backgroundColor: Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // ============================================================
  // تحويل الرقم إلى كلمات عربية
  // ============================================================

  String _convertNumberToArabicWords(
    double amount,
  ) {
    int num = amount.abs().toInt();

    if (num == 0) {
      return "صفر ريال يمني";
    }

    const List<String> units = [
      "",
      "واحد",
      "اثنان",
      "ثلاثة",
      "أربعة",
      "خمسة",
      "ستة",
      "سبعة",
      "ثمانية",
      "تسعة"
    ];

    const List<String> teens = [
      "عشرة",
      "أحد عشر",
      "اثنا عشر",
      "ثلاثة عشر",
      "أربعة عشر",
      "خمسة عشر",
      "ستة عشر",
      "سبعة عشر",
      "ثمانية عشر",
      "تسعة عشر"
    ];

    const List<String> tens = [
      "",
      "عشرة",
      "عشرون",
      "ثلاثون",
      "أربعون",
      "خمسون",
      "ستون",
      "سبعون",
      "ثمانون",
      "تسعون"
    ];

    const List<String> hundreds = [
      "",
      "مائة",
      "مئتان",
      "ثلاثمائة",
      "أربعمائة",
      "خمسمائة",
      "ستمائة",
      "سبعمائة",
      "ثمانمائة",
      "تسعمائة"
    ];

    String convertGroup(int n) {
      if (n == 0) return "";

      final int h = n ~/ 100;

      final int rem = n % 100;

      final int t = rem ~/ 10;

      final int u = rem % 10;

      String result = "";

      if (h > 0) {
        result += hundreds[h];
      }

      if (rem > 0) {
        if (result.isNotEmpty) {
          result += " و";
        }

        if (rem < 10) {
          result += units[u];
        } else if (rem < 20) {
          result += teens[rem - 10];
        } else {
          result += units[u];

          if (t > 0) {
            if (units[u].isNotEmpty) {
              result += " و";
            }

            result += tens[t];
          }
        }
      }

      return result;
    }

    if (num >= 1000000) {
      final int millions = num ~/ 1000000;

      final int remainder = num % 1000000;

      String mStr;

      if (millions == 1) {
        mStr = "مليون";
      } else if (millions == 2) {
        mStr = "مليونان";
      } else {
        mStr = "${convertGroup(millions)} ملايين";
      }

      if (remainder == 0) {
        return "$mStr ريال يمني";
      }

      return "$mStr و${_convertNumberToArabicWords(
        remainder.toDouble(),
      )}";
    }

    if (num >= 1000) {
      final int thousands = num ~/ 1000;

      final int remainder = num % 1000;

      String tStr = "";

      if (thousands == 1) {
        tStr = "ألف";
      } else if (thousands == 2) {
        tStr = "ألفان";
      } else if (thousands >= 3 && thousands <= 10) {
        tStr = "${units[thousands]} آلاف";
      } else {
        tStr = "${convertGroup(thousands)} ألفاً";
      }

      if (remainder == 0) {
        return "$tStr ريال يمني";
      }

      return "$tStr و${_convertNumberToArabicWords(
        remainder.toDouble(),
      )}";
    }

    return "${convertGroup(num)} ريال يمني";
  }

  // ============================================================
  // تنسيق المبلغ
  //
  // السالب:
  // 500 ريال يمني
  //
  // بدون علامة السالب.
  // ============================================================

  String _formatAmount(
    double amount, {
    bool forceNumeric = false,
  }) {
    final double displayAmount = amount.abs();

    final String numeric = NumberFormat('#,##0').format(
      displayAmount,
    );

    if (forceNumeric) {
      return '$numeric ريال يمني';
    }

    if (amount < 0) {
      return '$numeric ريال يمني';
    }

    return '$numeric ${_convertNumberToArabicWords(
      displayAmount,
    )}';
  }

  // ============================================================
  // تحويل العربي إلى Windows-1256
  // ============================================================

  Future<List<int>> _arabic(
    String text,
  ) async {
    final encoded = await CharsetConverter.encode(
      'windows-1256',
      text,
    );

    return encoded.toList();
  }

  // ============================================================
  // التباعد
  // ============================================================

  int _extraLines() {
    if (_lineSpacing <= 0.7) {
      return 0;
    }

    if (_lineSpacing <= 1.1) {
      return 1;
    }

    if (_lineSpacing <= 1.5) {
      return 2;
    }

    return 3;
  }

  // ============================================================
  // عرض السطر حسب حجم الورق
  // ============================================================

  int get _lineWidth {
    if (_paperSize == '80mm') {
      return 48;
    }

    return 32;
  }

  // ============================================================
  // الفاصل
  // ============================================================

  String _separator() {
    return '${'-' * _lineWidth}\n';
  }

  // ============================================================
  // المحاذاة
  // ============================================================

  List<int> _alignmentCommand(
    String alignment,
  ) {
    if (alignment == 'left') {
      return [
        0x1B,
        0x61,
        0x00,
      ];
    }

    if (alignment == 'right') {
      return [
        0x1B,
        0x61,
        0x02,
      ];
    }

    return [
      0x1B,
      0x61,
      0x01,
    ];
  }

  // ============================================================
  // حجم الخط
  // ============================================================

  List<int> _fontCommand({
    bool bold = false,
  }) {
    final int size = _fontSize.round().clamp(1, 5);

    int command = 0;

    switch (size) {
      case 1:
        command = 0x00;
        break;

      case 2:
        command = 0x08;
        break;

      case 3:
        command = 0x10;
        break;

      case 4:
        command = 0x20;
        break;

      case 5:
        command = 0x30;
        break;

      default:
        command = 0x08;
    }

    if (bold) {
      command |= 0x08;
    }

    return [
      0x1B,
      0x21,
      command,
    ];
  }

  // ============================================================
  // طباعة السند
  // ============================================================

  Future<bool> _printReceiptData() async {
    final bool isConnected = await PrintBluetoothThermal.connectionStatus;

    if (!isConnected) {
      if (mounted) {
        _showMessage(
          'الطابعة غير متصلة!',
          backgroundColor: Colors.red,
        );
      }

      return false;
    }

    // ========================================================
    // البيانات المالية
    // ========================================================

    final double currentDebt = (widget.customer.instantBalance ?? 0).toDouble();

    final double previousDebt = currentDebt + widget.payment.amount;

    // ========================================================
    // التاريخ
    // ========================================================

    DateTime parsedDate;

    try {
      parsedDate = DateTime.parse(
        widget.payment.paymentDate ?? DateTime.now().toString(),
      );
    } catch (_) {
      parsedDate = DateTime.now();
    }

    final String formattedDateTime = DateFormat(
      'yyyy/MM/dd HH:mm:ss',
    ).format(parsedDate);

    // ========================================================
    // المبالغ
    // ========================================================

    final String amountDisplay = _formatAmount(
      widget.payment.amount,
    );

    final String prevDebtDisplay = _formatAmount(
      previousDebt,
    );

    final String currentDebtDisplay = _formatAmount(
      currentDebt,
    );

    // ========================================================
    // الباقي
    // ========================================================

    final String remainingLabel =
        currentDebt < 0 ? 'الباقي لكم' : 'الباقي عليكم';

    // ========================================================
    // بناء السند
    // ========================================================

    final List<int> bytes = [];

    // --------------------------------------------------------
    // تهيئة الطابعة
    // --------------------------------------------------------

    bytes.addAll([
      0x1B,
      0x40,
    ]);

    // --------------------------------------------------------
    // Windows-1256 / XP-P810
    // --------------------------------------------------------

    bytes.addAll([
      0x1B,
      0x74,
      0x21,
    ]);

    // ========================================================
    // رأس السند
    // ========================================================

    bytes.addAll(
      _alignmentCommand(
        'center',
      ),
    );

    bytes.addAll(
      _fontCommand(
        bold: true,
      ),
    );

    bytes.addAll(
      await _arabic(
        '$stationName\n',
      ),
    );

    bytes.addAll(
      _fontCommand(),
    );

    bytes.addAll(
      await _arabic(
        '$stationAddress\n',
      ),
    );

    bytes.addAll(
      await _arabic(
        '$stationPhones\n\n',
      ),
    );

    // --------------------------------------------------------
    // عنوان السند
    // --------------------------------------------------------

    bytes.addAll(
      _fontCommand(
        bold: true,
      ),
    );

    bytes.addAll(
      await _arabic(
        'سند تحصيل\n',
      ),
    );

    bytes.addAll(
      _fontCommand(),
    );

    bytes.addAll(
      await _arabic(
        _separator(),
      ),
    );

    // ========================================================
    // بيانات السند
    // ========================================================

    bytes.addAll(
      _alignmentCommand(
        _rtl ? 'right' : _alignment,
      ),
    );

    // --------------------------------------------------------
    // رقم السند
    // --------------------------------------------------------

    if (_showReceiptNumber) {
      bytes.addAll(
        await _arabic(
          'رقم السند: ${widget.payment.receiptNo}\n',
        ),
      );
    }

    // --------------------------------------------------------
    // التاريخ
    // --------------------------------------------------------

    if (_showDateTime) {
      bytes.addAll(
        await _arabic(
          'تاريخ السند: $formattedDateTime\n',
        ),
      );
    }

    // --------------------------------------------------------
    // رقم المشترك
    // --------------------------------------------------------

    bytes.addAll(
      await _arabic(
        'رقم المشترك: ${widget.customer.idCustomer}\n',
      ),
    );

    // --------------------------------------------------------
    // اسم المشترك
    // --------------------------------------------------------

    bytes.addAll(
      await _arabic(
        'اسم المشترك: ${widget.customer.nameCustomer}\n',
      ),
    );

    // --------------------------------------------------------
    // الهاتف
    // --------------------------------------------------------

    if (widget.customer.numPhone != null) {
      bytes.addAll(
        await _arabic(
          'هاتف المشترك: ${widget.customer.numPhone}\n',
        ),
      );
    }

    // --------------------------------------------------------
    // طريقة الدفع
    // --------------------------------------------------------

    bytes.addAll(
      await _arabic(
        'طريقة الدفع: ${widget.payment.paymentMethod}\n',
      ),
    );

    bytes.addAll(
      await _arabic(
        _separator(),
      ),
    );

    // ========================================================
    // المبالغ
    // ========================================================

    if (_showNumericAmount || _showWrittenAmount) {
      // ------------------------------------------------------
      // مبلغ التسديد
      // ------------------------------------------------------

      if (_showNumericAmount && _showWrittenAmount) {
        bytes.addAll(
          await _arabic(
            'مبلغ التسديد: $amountDisplay\n',
          ),
        );
      } else if (_showNumericAmount) {
        bytes.addAll(
          await _arabic(
            'مبلغ التسديد: ${_formatAmount(
              widget.payment.amount,
              forceNumeric: true,
            )}\n',
          ),
        );
      } else if (_showWrittenAmount) {
        bytes.addAll(
          await _arabic(
            'مبلغ التسديد: ${_convertNumberToArabicWords(
              widget.payment.amount.abs(),
            )}\n',
          ),
        );
      }

      // ------------------------------------------------------
      // مبلغ الفاتورة
      // ------------------------------------------------------

      if (_showNumericAmount && _showWrittenAmount) {
        bytes.addAll(
          await _arabic(
            'مبلغ الفاتورة: $prevDebtDisplay\n',
          ),
        );
      } else if (_showNumericAmount) {
        bytes.addAll(
          await _arabic(
            'مبلغ الفاتورة: ${_formatAmount(
              previousDebt,
              forceNumeric: true,
            )}\n',
          ),
        );
      } else if (_showWrittenAmount) {
        bytes.addAll(
          await _arabic(
            'مبلغ الفاتورة: ${_convertNumberToArabicWords(
              previousDebt.abs(),
            )}\n',
          ),
        );
      }

      // ------------------------------------------------------
      // الباقي
      // ------------------------------------------------------

      if (_showNumericAmount && _showWrittenAmount) {
        bytes.addAll(
          await _arabic(
            '$remainingLabel: $currentDebtDisplay\n',
          ),
        );
      } else if (_showNumericAmount) {
        bytes.addAll(
          await _arabic(
            '$remainingLabel: ${_formatAmount(
              currentDebt,
              forceNumeric: true,
            )}\n',
          ),
        );
      } else if (_showWrittenAmount) {
        bytes.addAll(
          await _arabic(
            '$remainingLabel: ${_convertNumberToArabicWords(
              currentDebt.abs(),
            )}\n',
          ),
        );
      }
    }

    bytes.addAll(
      await _arabic(
        _separator(),
      ),
    );

    // ========================================================
    // المحصل
    // ========================================================

    if (_showCollector) {
      bytes.addAll(
        await _arabic(
          'اسم المتحصل: $_collectorName\n',
        ),
      );
    }

    // ========================================================
    // وقت الطباعة
    // ========================================================

    if (_showDateTime) {
      bytes.addAll(
        await _arabic(
          'وقت الطباعة: $formattedDateTime\n',
        ),
      );
    }

    bytes.addAll(
      await _arabic(
        _separator(),
      ),
    );

    // ========================================================
    // الملاحظة الأخيرة
    // ========================================================

    if (_showNotes) {
      bytes.addAll(
        _alignmentCommand(
          'center',
        ),
      );

      bytes.addAll(
        await _arabic(
          'هذا السند آلي حراري يجب تصويره للاحتفاظ به ولا\n'
          'يحتاج إلى ختم أو توقيع\n',
        ),
      );

      for (int i = 0; i < _extraLines(); i++) {
        bytes.addAll(
          await _arabic(
            '\n',
          ),
        );
      }
    }

    // ========================================================
    // قص الورق
    // ========================================================

    if (_autoCut) {
      bytes.addAll([
        0x1D,
        0x56,
        0x00,
      ]);
    }

    // ========================================================
    // الطباعة بعدد النسخ
    // ========================================================

    try {
      for (int copy = 0; copy < _copies; copy++) {
        await PrintBluetoothThermal.writeBytes(bytes);

        if (copy < _copies - 1) {
          await Future.delayed(
            const Duration(
              milliseconds: 700,
            ),
          );
        }
      }

      if (mounted) {
        _showMessage(
          _copies > 1 ? 'تمت طباعة $_copies نسخ بنجاح' : 'تمت الطباعة بنجاح',
          backgroundColor: Colors.green,
        );
      }

      return true;
    } catch (e) {
      debugPrint(
        'Printer write error: $e',
      );

      if (mounted) {
        _showMessage(
          'فشل إرسال السند للطابعة: $e',
          backgroundColor: Colors.red,
        );
      }

      return false;
    }
  }

  // ============================================================
  // حفظ السند في قاعدة البيانات
  // ============================================================

  Future<void> _saveInvoiceToDb() async {
    try {
      final db = await DatabaseHelper().database;

      final double currentDebt =
          (widget.customer.instantBalance ?? 0).toDouble();

      final double previousDebt = currentDebt + widget.payment.amount;

      final Map<String, dynamic> invoiceData = {
        'receipt_no': widget.payment.receiptNo,
        'id_customer': widget.customer.idCustomer,
        'customer_name': widget.customer.nameCustomer,
        'meter_no': widget.customer.numAddaad?.toString() ?? '',
        'total_amount': previousDebt,
        'amount_paid': widget.payment.amount,
        'remaining_amount': currentDebt,
        'payment_date': widget.payment.paymentDate,
        'id_geathers': widget.payment.idGeathers,
        'collector_name': _collectorName,
        'sync_status': 0,
      };

      await db.insert(
        'app_invoices',
        invoiceData,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(
            content: Text(
              'تم حفظ السند بنجاح ✓',
            ),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.of(context).popUntil(
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      debugPrint(
        "خطأ في حفظ الفاتورة: $e",
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ أثناء الحفظ: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============================================================
  // رسالة
  // ============================================================

  void _showMessage(
    String message, {
    Color backgroundColor = Colors.black87,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
          ),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ============================================================
  // الواجهة
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final double currentDebt = (widget.customer.instantBalance ?? 0).toDouble();

    final double previousDebt = currentDebt + widget.payment.amount;

    DateTime parsedDate;

    try {
      parsedDate = DateTime.parse(
        widget.payment.paymentDate ?? DateTime.now().toString(),
      );
    } catch (_) {
      parsedDate = DateTime.now();
    }

    final String displayDateTime = DateFormat(
      'yyyy/MM/dd HH:mm:ss',
    ).format(parsedDate);

    final String prevDebtDisplay = _formatAmount(
      previousDebt,
    );

    final String amountDisplay = _formatAmount(
      widget.payment.amount,
    );

    final String currentDebtDisplay = _formatAmount(
      currentDebt,
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A5276),
          title: Text(
            'سند التحصيل',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              tooltip: 'إعدادات الطابعة',
              icon: const Icon(
                Icons.print_outlined,
                color: Colors.white,
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrinterSettingsScreen(),
                  ),
                );

                await _loadPrinterSettings();

                await _initBluetooth();
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(20.w),
          child: Column(
            children: [
              // ==================================================
              // السند
              // ==================================================

              Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(
                    15.r,
                  ),
                  border: Border.all(
                    color: Colors.grey.shade300,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(.15),
                      blurRadius: 15,
                      offset: const Offset(
                        0,
                        5,
                      ),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      stationName,
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(
                          0xFF1A5276,
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(
                      height: 6.h,
                    ),
                    Text(
                      stationAddress,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      stationPhones,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(
                      height: 15.h,
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        vertical: 8.h,
                        horizontal: 20.w,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(
                          8.r,
                        ),
                      ),
                      child: Text(
                        'سند تحصيل',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(
                            0xFF1A5276,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 20.h,
                    ),
                    Row(
                      children: List.generate(
                        30,
                        (index) => Expanded(
                          child: Container(
                            color: index % 2 == 0
                                ? Colors.transparent
                                : Colors.grey.shade400,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 20.h,
                    ),
                    _buildInvoiceRow(
                      'رقم السند',
                      widget.payment.receiptNo ?? '',
                    ),
                    _buildInvoiceRow(
                      'تاريخ السند',
                      displayDateTime,
                    ),
                    _buildInvoiceRow(
                      'رقم المشترك',
                      '${widget.customer.idCustomer}',
                    ),
                    _buildInvoiceRow(
                      'اسم المشترك',
                      widget.customer.nameCustomer,
                      isBold: true,
                    ),
                    if (widget.customer.numPhone != null)
                      _buildInvoiceRow(
                        'هاتف المشترك',
                        '${widget.customer.numPhone}',
                      ),
                    _buildInvoiceRow(
                      'طريقة الدفع',
                      widget.payment.paymentMethod,
                    ),
                    SizedBox(
                      height: 15.h,
                    ),
                    Container(
                      padding: EdgeInsets.all(
                        16.w,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(
                          10.r,
                        ),
                        border: Border.all(
                          color: Colors.grey.shade200,
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildInvoiceRow(
                            'اسم المتحصل',
                            _collectorName,
                            isBold: true,
                          ),
                          Divider(
                            color: Colors.grey.shade300,
                            height: 15.h,
                          ),
                          _buildInvoiceRow(
                            'مبلغ التسديد',
                            amountDisplay,
                            isHighlight: true,
                          ),
                          Divider(
                            color: Colors.grey.shade300,
                            height: 15.h,
                          ),
                          _buildInvoiceRow(
                            'مبلغ الفاتورة',
                            prevDebtDisplay,
                          ),
                          Divider(
                            color: Colors.grey.shade300,
                            height: 15.h,
                          ),
                          _buildInvoiceRow(
                            currentDebt < 0 ? 'الباقي لكم' : 'الباقي عليكم',
                            currentDebtDisplay,
                            isBold: true,
                            isHighlight: true,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 15.h,
                    ),
                    Text(
                      'هذا السند آلي حراري .. يجب تصويره للاحتفاظ به ولا يحتاج إلى ختم أو توقيع ..',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              SizedBox(
                height: 30.h,
              ),

              // ==================================================
              // معلومات الطابعة
              // ==================================================

              if (_savedPrinterName != null && _savedPrinterMac != null)
                Container(
                  margin: EdgeInsets.only(
                    bottom: 15.h,
                  ),
                  padding: EdgeInsets.all(
                    12.w,
                  ),
                  decoration: BoxDecoration(
                    color: _connected
                        ? Colors.green.withOpacity(.08)
                        : Colors.orange.withOpacity(.08),
                    borderRadius: BorderRadius.circular(
                      12.r,
                    ),
                    border: Border.all(
                      color: _connected
                          ? Colors.green.withOpacity(.25)
                          : Colors.orange.withOpacity(.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _connected
                            ? Icons.print_rounded
                            : Icons.print_disabled_outlined,
                        color: _connected ? Colors.green : Colors.orange,
                      ),
                      SizedBox(
                        width: 10.w,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _savedPrinterName!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _connected
                                  ? 'الطابعة متصلة وجاهزة للطباعة'
                                  : 'الطابعة محفوظة ولكنها غير متصلة',
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // ==================================================
              // الأزرار
              // ==================================================

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _handlePrintAndSave,
                      icon: _isProcessing
                          ? SizedBox(
                              width: 20.w,
                              height: 20.w,
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.print,
                              color: Colors.white,
                            ),
                      label: Text(
                        _isProcessing ? 'جاري التنفيذ...' : 'طباعة وحفظ',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15.sp,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        padding: EdgeInsets.symmetric(
                          vertical: 16.h,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            12.r,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 15.w,
                  ),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _saveInvoiceToDb,
                      icon: const Icon(
                        Icons.save,
                        color: Colors.white,
                      ),
                      label: Text(
                        'حفظ السند',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15.sp,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF1A5276,
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: 16.h,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            12.r,
                          ),
                        ),
                      ),
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

  // ============================================================
  // صف بيانات السند
  // ============================================================

  Widget _buildInvoiceRow(
    String label,
    String value, {
    bool isBold = false,
    bool isHighlight = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: 12.h,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(
            width: 10.w,
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: isHighlight ? 14.sp : 13.sp,
                fontWeight:
                    isBold || isHighlight ? FontWeight.bold : FontWeight.w600,
                color: isHighlight ? Colors.green.shade700 : Colors.black87,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
