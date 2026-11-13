import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  // ============================================================
  // الألوان
  // ============================================================

  static const Color primaryColor = Color(0xFF06DEB7);
  static const Color darkColor = Color(0xFF17202A);
  static const Color backgroundColor = Color(0xFFF5F7FA);

  // ============================================================
  // إعدادات الطابعة
  // ============================================================

  String _paperSize = '58mm';
  String _alignment = 'center';

  double _fontSize = 2;
  double _lineSpacing = 1.0;
  double _density = 0.0;

  bool _autoConnect = true;
  bool _autoReconnect = true;

  // هذه الخيارات إجبارية دائمًا
  bool _showCollector = true;
  bool _showReceiptNumber = true;
  bool _showDateTime = true;

  // هذه الخيارات يمكن للمستخدم التحكم بها
  bool _showNumericAmount = true;
  bool _showWrittenAmount = true;
  bool _showNotes = true;

  bool _autoCut = false;
  bool _rtl = true;

  int _copies = 1;

  // ============================================================
  // Bluetooth
  // ============================================================

  List<BluetoothInfo> _devices = [];

  BluetoothInfo? _selectedPrinter;

  bool _isLoadingDevices = false;
  bool _isConnecting = false;
  bool _isPrinting = false;
  bool _isConnected = false;
  bool _bluetoothEnabled = false;
  bool _permissionGranted = true;

  // ============================================================
  // SharedPreferences
  // ============================================================

  SharedPreferences? _prefs;

  // ============================================================
  // Lifecycle
  // ============================================================

  @override
  void initState() {
    super.initState();

    _initialize();
  }

  Future<void> _initialize() async {
    await _loadSettings();
    await _checkBluetooth();
    await _loadPrinters();

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // تحميل الإعدادات
  // ============================================================

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();

    _paperSize = _prefs?.getString('printer_paper_size') ?? '58mm';

    _alignment = _prefs?.getString('printer_alignment') ?? 'center';

    _fontSize = _prefs?.getDouble('printer_font_size') ?? 2;

    _lineSpacing = _prefs?.getDouble('printer_line_spacing') ?? 1.0;

    _density = _prefs?.getDouble('printer_density') ?? 0.0;

    _autoConnect = _prefs?.getBool('printer_auto_connect') ?? true;

    _autoReconnect = _prefs?.getBool('printer_auto_reconnect') ?? true;

    // ============================================================
    // هذه الخيارات إجبارية
    // لا يتم تحميل قيمتها القديمة من SharedPreferences
    // ============================================================

    _showCollector = true;
    _showReceiptNumber = true;
    _showDateTime = true;

    // ============================================================
    // الخيارات القابلة للتغيير
    // ============================================================

    _showNumericAmount = _prefs?.getBool('printer_show_numeric_amount') ?? true;

    _showWrittenAmount = _prefs?.getBool('printer_show_written_amount') ?? true;

    _showNotes = _prefs?.getBool('printer_show_notes') ?? true;

    _autoCut = _prefs?.getBool('printer_auto_cut') ?? false;

    _rtl = _prefs?.getBool('printer_rtl') ?? true;

    _copies = _prefs?.getInt('printer_copies') ?? 1;

    // ============================================================
    // الطابعة المحفوظة
    // ============================================================

    final String? printerName = _prefs?.getString('printer_name');

    final String? printerMac = _prefs?.getString('printer_mac');

    if (printerName != null && printerMac != null) {
      _selectedPrinter = BluetoothInfo(
        name: printerName,
        macAdress: printerMac,
      );
    }
  }

  // ============================================================
  // حفظ الإعدادات
  // ============================================================

  Future<void> _saveSettings() async {
    _prefs ??= await SharedPreferences.getInstance();

    await _prefs!.setString(
      'printer_paper_size',
      _paperSize,
    );

    await _prefs!.setString(
      'printer_alignment',
      _alignment,
    );

    await _prefs!.setDouble(
      'printer_font_size',
      _fontSize,
    );

    await _prefs!.setDouble(
      'printer_line_spacing',
      _lineSpacing,
    );

    await _prefs!.setDouble(
      'printer_density',
      _density,
    );

    await _prefs!.setBool(
      'printer_auto_connect',
      _autoConnect,
    );

    await _prefs!.setBool(
      'printer_auto_reconnect',
      _autoReconnect,
    );

    // ============================================================
    // هذه الخيارات إجبارية دائمًا
    // ============================================================

    await _prefs!.setBool(
      'printer_show_collector',
      true,
    );

    await _prefs!.setBool(
      'printer_show_receipt_number',
      true,
    );

    await _prefs!.setBool(
      'printer_show_date_time',
      true,
    );

    // ============================================================
    // الخيارات القابلة للتغيير
    // ============================================================

    await _prefs!.setBool(
      'printer_show_numeric_amount',
      _showNumericAmount,
    );

    await _prefs!.setBool(
      'printer_show_written_amount',
      _showWrittenAmount,
    );

    await _prefs!.setBool(
      'printer_show_notes',
      _showNotes,
    );

    await _prefs!.setBool(
      'printer_auto_cut',
      _autoCut,
    );

    await _prefs!.setBool(
      'printer_rtl',
      _rtl,
    );

    await _prefs!.setInt(
      'printer_copies',
      _copies,
    );

    // ============================================================
    // حفظ الطابعة المحددة
    // ============================================================

    if (_selectedPrinter != null) {
      await _prefs!.setString(
        'printer_name',
        _selectedPrinter!.name,
      );

      await _prefs!.setString(
        'printer_mac',
        _selectedPrinter!.macAdress,
      );
    }
  }

  // ============================================================
  // Bluetooth
  // ============================================================

  Future<void> _checkBluetooth() async {
    try {
      final bool enabled = await PrintBluetoothThermal.bluetoothEnabled;

      final bool permission =
          await PrintBluetoothThermal.isPermissionBluetoothGranted;

      final bool connected = await PrintBluetoothThermal.connectionStatus;

      if (!mounted) return;

      setState(() {
        _bluetoothEnabled = enabled;
        _permissionGranted = permission;
        _isConnected = connected;
      });
    } catch (e) {
      debugPrint('Bluetooth check error: $e');
    }
  }

  Future<void> _loadPrinters() async {
    if (_isLoadingDevices) return;

    setState(() {
      _isLoadingDevices = true;
    });

    try {
      await _checkBluetooth();

      if (!_bluetoothEnabled) {
        if (mounted) {
          setState(() {
            _devices = [];
            _isLoadingDevices = false;
          });
        }

        return;
      }

      if (!_permissionGranted) {
        if (mounted) {
          setState(() {
            _devices = [];
            _isLoadingDevices = false;
          });
        }

        return;
      }

      final List<BluetoothInfo> devices =
          await PrintBluetoothThermal.pairedBluetooths;

      if (!mounted) return;

      setState(() {
        _devices = devices;
        _isLoadingDevices = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingDevices = false;
      });

      _showMessage(
        'تعذر قراءة أجهزة Bluetooth',
        isError: true,
      );
    }
  }

  // ============================================================
  // الاتصال بالطابعة
  // ============================================================

  Future<void> _connectPrinter(
    BluetoothInfo printer,
  ) async {
    if (_isConnecting) return;

    setState(() {
      _isConnecting = true;
    });

    try {
      final bool result = await PrintBluetoothThermal.connect(
        macPrinterAddress: printer.macAdress,
      );

      if (!mounted) return;

      if (result) {
        setState(() {
          _selectedPrinter = printer;
          _isConnected = true;
        });

        await _saveSettings();

        HapticFeedback.mediumImpact();

        _showMessage(
          'تم الاتصال بالطابعة ${printer.name}',
        );
      } else {
        setState(() {
          _isConnected = false;
        });

        _showMessage(
          'فشل الاتصال بالطابعة',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isConnected = false;
      });

      _showMessage(
        'حدث خطأ أثناء الاتصال بالطابعة',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  // ============================================================
  // فصل الطابعة
  // ============================================================

  Future<void> _disconnectPrinter() async {
    try {
      await PrintBluetoothThermal.disconnect;

      if (!mounted) return;

      setState(() {
        _isConnected = false;
      });

      _showMessage('تم فصل الطابعة');
    } catch (e) {
      _showMessage(
        'تعذر فصل الطابعة',
        isError: true,
      );
    }
  }

  // ============================================================
  // اختبار الطباعة
  // ============================================================

  Future<void> _testPrint() async {
    if (_isPrinting) return;

    final bool connected = await PrintBluetoothThermal.connectionStatus;

    if (!connected) {
      _showMessage(
        'قم بالاتصال بالطابعة أولاً',
        isError: true,
      );

      return;
    }

    setState(() {
      _isPrinting = true;
    });

    try {
      final String text = '''
--------------------------------
        اختبار الطباعة
--------------------------------

اسم الطابعة:
${_selectedPrinter?.name ?? 'غير محدد'}

حجم الورق:
$_paperSize

حجم الخط:
${_fontSize.toInt()}

اسم المحصل:
إجباري

رقم السند:
إجباري

التاريخ والوقت:
إجباري

RTL:
${_rtl ? 'مفعل' : 'غير مفعل'}

--------------------------------
        تم بنجاح
--------------------------------


''';

      await PrintBluetoothThermal.writeString(
        printText: PrintTextSize(
          size: _fontSize.toInt().clamp(1, 5),
          text: text,
        ),
      );

      if (!mounted) return;

      HapticFeedback.mediumImpact();

      _showMessage(
        'تم إرسال اختبار الطباعة',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'فشل اختبار الطباعة',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
    }
  }

  // ============================================================
  // الرسائل
  // ============================================================

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              isError ? Colors.red.shade700 : Colors.green.shade700,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  // ============================================================
  // واجهة الشاشة
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: darkColor,
          centerTitle: true,
          title: const Text(
            'إعدادات الطابعة',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 19,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'حفظ',
              onPressed: () async {
                await _saveSettings();

                if (!mounted) return;

                HapticFeedback.lightImpact();

                _showMessage(
                  'تم حفظ إعدادات الطابعة',
                );
              },
              icon: const Icon(
                Icons.save_outlined,
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              32,
            ),
            children: [
              _buildPrinterStatusCard(),
              const SizedBox(height: 16),
              _buildSectionTitle(
                icon: Icons.bluetooth,
                title: 'اتصال الطابعة',
              ),
              const SizedBox(height: 10),
              _buildPrinterSelectionCard(),
              const SizedBox(height: 20),
              _buildSectionTitle(
                icon: Icons.receipt_long_outlined,
                title: 'إعدادات الفاتورة',
              ),
              const SizedBox(height: 10),
              _buildReceiptSettingsCard(),
              const SizedBox(height: 20),
              _buildSectionTitle(
                icon: Icons.text_fields,
                title: 'تنسيق النص',
              ),
              const SizedBox(height: 10),
              _buildTextSettingsCard(),
              const SizedBox(height: 20),
              _buildSectionTitle(
                icon: Icons.tune,
                title: 'خيارات الطباعة',
              ),
              const SizedBox(height: 10),
              _buildPrintingOptionsCard(),
              const SizedBox(height: 20),
              _buildAdvancedSection(),
              const SizedBox(height: 20),
              _buildSaveButton(),
              const SizedBox(height: 12),
              _buildResetButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // بطاقة حالة الطابعة
  // ============================================================

  Widget _buildPrinterStatusCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            primaryColor,
            primaryColor.withOpacity(.72),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.20),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.print_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الطابعة الحرارية',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _selectedPrinter?.name ?? 'لم يتم اختيار طابعة',
                      style: TextStyle(
                        color: Colors.white.withOpacity(.90),
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _buildConnectionBadge(),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildStatusItem(
                  icon: Icons.bluetooth,
                  title: 'Bluetooth',
                  value: _bluetoothEnabled ? 'مفعل' : 'غير مفعل',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatusItem(
                  icon: Icons.receipt_long,
                  title: 'الورق',
                  value: _paperSize,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isPrinting ? null : _testPrint,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withOpacity(.7),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _isPrinting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.print_outlined,
                        ),
                  label: Text(
                    _isPrinting ? 'جاري الطباعة...' : 'اختبار الطباعة',
                  ),
                ),
              ),
              if (_isConnected) ...[
                const SizedBox(width: 10),
                IconButton(
                  tooltip: 'فصل الطابعة',
                  onPressed: _disconnectPrinter,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(.18),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(
                    Icons.link_off,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  _isConnected ? Colors.white : Colors.white.withOpacity(.55),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _isConnected ? 'متصلة' : 'غير متصلة',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.14),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.75),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // اختيار الطابعة
  // ============================================================

  Widget _buildPrinterSelectionCard() {
    return _buildCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _selectedPrinter == null
                      ? 'لم يتم اختيار طابعة'
                      : _selectedPrinter!.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'تحديث',
                onPressed: _isLoadingDevices ? null : _loadPrinters,
                icon: _isLoadingDevices
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                      ),
              ),
            ],
          ),
          const Divider(height: 20),
          if (!_permissionGranted)
            _buildInfoMessage(
              icon: Icons.lock_outline,
              title: 'صلاحية Bluetooth غير مفعلة',
              message: 'اسمح للتطبيق بالوصول إلى Bluetooth ثم حاول مرة أخرى.',
            )
          else if (!_bluetoothEnabled)
            _buildInfoMessage(
              icon: Icons.bluetooth_disabled,
              title: 'Bluetooth غير مفعل',
              message: 'قم بتفعيل Bluetooth في الهاتف ثم اضغط تحديث.',
            )
          else if (_devices.isEmpty && !_isLoadingDevices)
            _buildInfoMessage(
              icon: Icons.print_disabled_outlined,
              title: 'لا توجد طابعات مقترنة',
              message: 'قم بربط الطابعة من إعدادات Bluetooth في الهاتف أولاً.',
            )
          else
            ..._devices.map(
              (printer) => _buildPrinterTile(printer),
            ),
        ],
      ),
    );
  }

  Widget _buildPrinterTile(
    BluetoothInfo printer,
  ) {
    final bool selected = _selectedPrinter?.macAdress == printer.macAdress;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _isConnecting ? null : () => _connectPrinter(printer),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? primaryColor.withOpacity(.10) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? primaryColor : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected ? primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.print_rounded,
                color: selected ? Colors.white : darkColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    printer.name.isEmpty ? 'طابعة بدون اسم' : printer.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    printer.macAdress,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (_isConnecting && selected)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            else
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.chevron_left_rounded,
                color: selected ? primaryColor : Colors.grey.shade500,
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // إعدادات الفاتورة
  // ============================================================

  Widget _buildReceiptSettingsCard() {
    return _buildCard(
      child: Column(
        children: [
          // ======================================================
          // اسم المحصل - إجباري
          // ======================================================

          _buildLockedSetting(
            icon: Icons.person_outline,
            title: 'اسم المحصل',
            subtitle: 'سيتم إظهار اسم المحصل دائمًا على السند',
          ),

          _buildDivider(),

          // ======================================================
          // رقم السند - إجباري
          // ======================================================

          _buildLockedSetting(
            icon: Icons.confirmation_number_outlined,
            title: 'رقم السند',
            subtitle: 'سيتم إظهار رقم السند دائمًا على الفاتورة',
          ),

          _buildDivider(),

          // ======================================================
          // التاريخ والوقت - إجباري
          // ======================================================

          _buildLockedSetting(
            icon: Icons.calendar_today_outlined,
            title: 'التاريخ والوقت',
            subtitle: 'سيتم إظهار تاريخ ووقت التحصيل دائمًا',
          ),

          _buildDivider(),

          // ======================================================
          // المبلغ رقميًا
          // ======================================================

          _buildSettingSwitch(
            icon: Icons.numbers_outlined,
            title: 'إظهار المبلغ رقميًا',
            subtitle: 'مثال: 3,500 ريال يمني',
            value: _showNumericAmount,
            onChanged: (value) {
              setState(() {
                _showNumericAmount = value;
              });
            },
          ),

          _buildDivider(),

          // ======================================================
          // المبلغ كتابيًا
          // ======================================================

          _buildSettingSwitch(
            icon: Icons.translate_outlined,
            title: 'إظهار المبلغ كتابيًا',
            subtitle: 'مثال: ثلاثة آلاف وخمسمائة ريال يمني',
            value: _showWrittenAmount,
            onChanged: (value) {
              setState(() {
                _showWrittenAmount = value;
              });
            },
          ),

          _buildDivider(),

          // ======================================================
          // الملاحظات
          // ======================================================

          _buildSettingSwitch(
            icon: Icons.notes_outlined,
            title: 'إظهار الملاحظات',
            subtitle: 'عرض الملاحظات في نهاية السند',
            value: _showNotes,
            onChanged: (value) {
              setState(() {
                _showNotes = value;
              });
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // عنصر إعداد إجباري
  // ============================================================

  Widget _buildLockedSetting({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        children: [
          _buildIconBox(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'إجباري',
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 10.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.lock_outline_rounded,
              color: Colors.grey.shade600,
              size: 19,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // تنسيق النص
  // ============================================================

  Widget _buildTextSettingsCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(
            icon: Icons.straighten,
            title: 'حجم الورق',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildChoiceButton(
                  title: '58 mm',
                  selected: _paperSize == '58mm',
                  onTap: () {
                    setState(() {
                      _paperSize = '58mm';
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildChoiceButton(
                  title: '80 mm',
                  selected: _paperSize == '80mm',
                  onTap: () {
                    setState(() {
                      _paperSize = '80mm';
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSlider(
            title: 'حجم الخط',
            value: '${_fontSize.toInt()} / 5',
            sliderValue: _fontSize,
            min: 1,
            max: 5,
            divisions: 4,
            onChanged: (value) {
              setState(() {
                _fontSize = value;
              });
            },
          ),
          const SizedBox(height: 12),
          _buildSlider(
            title: 'تباعد الأسطر',
            value: _lineSpacing.toStringAsFixed(1),
            sliderValue: _lineSpacing,
            min: 0.5,
            max: 2.0,
            divisions: 6,
            onChanged: (value) {
              setState(() {
                _lineSpacing = value;
              });
            },
          ),
          const SizedBox(height: 12),
          _buildLabel(
            icon: Icons.format_align_right,
            title: 'محاذاة النص',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildAlignmentButton(
                  icon: Icons.format_align_right,
                  title: 'يمين',
                  value: 'right',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAlignmentButton(
                  icon: Icons.format_align_center,
                  title: 'وسط',
                  value: 'center',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAlignmentButton(
                  icon: Icons.format_align_left,
                  title: 'يسار',
                  value: 'left',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // خيارات الطباعة
  // ============================================================

  Widget _buildPrintingOptionsCard() {
    return _buildCard(
      child: Column(
        children: [
          _buildSettingSwitch(
            icon: Icons.login_outlined,
            title: 'الاتصال التلقائي',
            subtitle: 'محاولة الاتصال بالطابعة عند فتح التطبيق',
            value: _autoConnect,
            onChanged: (value) {
              setState(() {
                _autoConnect = value;
              });
            },
          ),
          _buildDivider(),
          _buildSettingSwitch(
            icon: Icons.sync_rounded,
            title: 'إعادة الاتصال تلقائيًا',
            subtitle: 'إعادة الاتصال عند انقطاع Bluetooth',
            value: _autoReconnect,
            onChanged: (value) {
              setState(() {
                _autoReconnect = value;
              });
            },
          ),
          _buildDivider(),
          _buildSettingSwitch(
            icon: Icons.content_cut_outlined,
            title: 'القص التلقائي',
            subtitle: 'إرسال أمر قص الورق بعد الطباعة',
            value: _autoCut,
            onChanged: (value) {
              setState(() {
                _autoCut = value;
              });
            },
          ),
          _buildDivider(),
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 6,
            ),
            child: Row(
              children: [
                _buildIconBox(
                  Icons.copy_all_outlined,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'عدد النسخ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'عدد مرات طباعة السند',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildCopiesCounter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopiesCounter() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: _copies <= 1
                ? null
                : () {
                    setState(() {
                      _copies--;
                    });
                  },
            icon: const Icon(
              Icons.remove,
              size: 18,
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$_copies',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: _copies >= 5
                ? null
                : () {
                    setState(() {
                      _copies++;
                    });
                  },
            icon: const Icon(
              Icons.add,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // إعدادات متقدمة
  // ============================================================

  Widget _buildAdvancedSection() {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16,
          ),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.settings_outlined,
              color: primaryColor,
            ),
          ),
          title: const Text(
            'إعدادات متقدمة',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: const Text(
            'إعدادات RTL وكثافة الطباعة',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
          children: [
            _buildSettingSwitch(
              icon: Icons.format_textdirection_r_to_l,
              title: 'النص من اليمين إلى اليسار',
              subtitle: 'تفعيل تنسيق RTL للسند العربي',
              value: _rtl,
              onChanged: (value) {
                setState(() {
                  _rtl = value;
                });
              },
            ),
            const SizedBox(height: 15),
            _buildSlider(
              title: 'كثافة الطباعة',
              value: '${(_density * 100).toInt()}%',
              sliderValue: _density,
              min: 0,
              max: 1,
              divisions: 10,
              onChanged: (value) {
                setState(() {
                  _density = value;
                });
              },
            ),
            const SizedBox(height: 10),
            _buildInfoMessage(
              icon: Icons.info_outline,
              title: 'ملاحظة',
              message:
                  'إعدادات RTL تعتمد أيضًا على طريقة تجهيز النص العربي داخل خدمة الطباعة.',
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // زر الحفظ
  // ============================================================

  Widget _buildSaveButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: () async {
          await _saveSettings();

          if (!mounted) return;

          HapticFeedback.mediumImpact();

          _showMessage(
            'تم حفظ جميع إعدادات الطابعة',
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: darkColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
        icon: const Icon(
          Icons.save_rounded,
        ),
        label: const Text(
          'حفظ الإعدادات',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // زر إعادة الضبط
  // ============================================================

  Widget _buildResetButton() {
    return TextButton.icon(
      onPressed: _resetSettings,
      style: TextButton.styleFrom(
        foregroundColor: Colors.red.shade700,
      ),
      icon: const Icon(
        Icons.restore_outlined,
      ),
      label: const Text(
        'إعادة الإعدادات الافتراضية',
      ),
    );
  }

  // ============================================================
  // إعادة الإعدادات الافتراضية
  // ============================================================

  Future<void> _resetSettings() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'إعادة الإعدادات',
            textDirection: TextDirection.rtl,
          ),
          content: const Text(
            'هل تريد إعادة جميع إعدادات الطباعة إلى الوضع الافتراضي؟',
            textDirection: TextDirection.rtl,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text(
                'إلغاء',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text(
                'إعادة الضبط',
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      _paperSize = '58mm';
      _alignment = 'center';

      _fontSize = 2;
      _lineSpacing = 1.0;
      _density = 0.0;

      _autoConnect = true;
      _autoReconnect = true;

      // ========================================================
      // إجبارية
      // ========================================================

      _showCollector = true;
      _showReceiptNumber = true;
      _showDateTime = true;

      // ========================================================
      // قابلة للتغيير
      // ========================================================

      _showNumericAmount = true;
      _showWrittenAmount = true;
      _showNotes = true;

      _autoCut = false;
      _rtl = true;

      _copies = 1;
    });

    await _saveSettings();

    _showMessage(
      'تمت إعادة الإعدادات الافتراضية',
    );
  }

  // ============================================================
  // Widgets مساعدة
  // ============================================================

  Widget _buildCard({
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            color: primaryColor,
            size: 21,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: darkColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        children: [
          _buildIconBox(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 10.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: primaryColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildIconBox(
    IconData icon,
  ) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: darkColor,
        size: 20,
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 14,
      color: Colors.grey.shade200,
    );
  }

  Widget _buildLabel({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: darkColor,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceButton({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 180,
        ),
        padding: const EdgeInsets.symmetric(
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: selected ? primaryColor.withOpacity(.12) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? primaryColor : Colors.grey.shade200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected ? primaryColor : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: selected ? darkColor : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlignmentButton({
    required IconData icon,
    required String title,
    required String value,
  }) {
    final bool selected = _alignment == value;

    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: () {
        setState(() {
          _alignment = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 180,
        ),
        padding: const EdgeInsets.symmetric(
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: selected ? primaryColor.withOpacity(.12) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? primaryColor : Colors.grey.shade200,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 19,
              color: selected ? primaryColor : Colors.grey.shade700,
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider({
    required String title,
    required String value,
    required double sliderValue,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value,
                style: const TextStyle(
                  color: darkColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: primaryColor,
            thumbColor: primaryColor,
            overlayColor: primaryColor.withOpacity(.12),
            inactiveTrackColor: Colors.grey.shade200,
            trackHeight: 4,
          ),
          child: Slider(
            value: sliderValue,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoMessage({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.blue.withOpacity(.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Colors.blue.shade700,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
