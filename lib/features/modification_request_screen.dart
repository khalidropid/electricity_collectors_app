import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../database/database_helper.dart';
import '../core/utils/secure_storage_helper.dart';
import '../models/customer.dart';
import '../widgets/app_drawer.dart';
import '../providers/sync_provider.dart';

class ModificationRequestScreen extends StatefulWidget {
  final String? initialSubNo;
  final String? initialName;
  final String? initialAddress;

  const ModificationRequestScreen({
    super.key,
    this.initialSubNo,
    this.initialName,
    this.initialAddress,
  });

  @override
  State<ModificationRequestScreen> createState() =>
      _ModificationRequestScreenState();
}

class _ModificationRequestScreenState extends State<ModificationRequestScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _subNoController;
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _notesController;

  String _selectedModType = 'تعديل اسم';
  final List<String> _modTypes = [
    'تعديل اسم',
    'تعديل عنوان',
    'خطأ في العداد',
    'أخرى'
  ];

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _subNoController = TextEditingController(text: widget.initialSubNo ?? '');
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _addressController =
        TextEditingController(text: widget.initialAddress ?? '');
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _subNoController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _showCustomerSearchDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return _CustomerSearchModal(
          onCustomerSelected: (Customer customer) {
            setState(() {
              _subNoController.text = customer.idCustomer.toString();
              _nameController.text = customer.nameCustomer ?? '';
              _addressController.text = customer.addressCustomer ?? '';
            });
          },
        );
      },
    );
  }

  Future<void> _submitRequest() async {
    if (_isSubmitting) return; // 🌟 حماية صارمة لمنع التكرار

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      String? empIdStr = await SecureStorageHelper.getEmpId();
      int empId = int.parse(empIdStr ?? '0');
      int customerId = int.tryParse(_subNoController.text) ?? 0;

      Map<String, dynamic> requestData = {
        'id_geathers': empId,
        'id_customer': customerId,
        'name_customer': _nameController.text,
        'address_customer': _addressController.text,
        'mod_type': _selectedModType,
        'notes': _notesController.text,
        'request_date': DateTime.now().toIso8601String(),
        'status': 'pending',
        'sync_status': 0,
      };

      final db = await DatabaseHelper().database;

      // 1. الحفظ محلياً
      await db.insert('modification_requests', requestData);

      // 2. إطلاق المزامنة الفورية في الخلفية
      if (empId > 0) {
        Provider.of<SyncProvider>(context, listen: false)
            .syncImmediately(empId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الطلب وإرساله للإدارة بنجاح ✓'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء حفظ الطلب: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        drawer: const AppDrawer(),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A5276),
          title: Text('طلب تعديل بيانات',
              style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(20.w),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                            'يرجى تعبئة بيانات الطلب وسوف يتم حفظه ومراجعته من قبل الإدارة بعد المزامنة.',
                            style: TextStyle(
                                fontSize: 13.sp, color: Colors.blue.shade900)),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                          controller: _subNoController,
                          label: 'رقم المشترك',
                          icon: Icons.numbers,
                          isNumber: true),
                    ),
                    SizedBox(width: 10.w),
                    ElevatedButton.icon(
                      onPressed: _showCustomerSearchDialog,
                      icon: const Icon(Icons.search, color: Colors.white),
                      label: const Text('بحث',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A5276),
                        padding: EdgeInsets.symmetric(
                            horizontal: 15.w, vertical: 15.h),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r)),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15.h),
                _buildTextField(
                    controller: _nameController,
                    label: 'الاسم الصحيح / الجديد',
                    icon: Icons.person_outline),
                SizedBox(height: 15.h),
                _buildTextField(
                    controller: _addressController,
                    label: 'العنوان الصحيح',
                    icon: Icons.location_on_outlined),
                SizedBox(height: 15.h),
                DropdownButtonFormField<String>(
                  value: _selectedModType,
                  decoration: InputDecoration(
                    labelText: 'نوع التعديل',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.category, color: Colors.grey),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                  items: _modTypes
                      .map((type) =>
                          DropdownMenuItem(value: type, child: Text(type)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedModType = value);
                  },
                ),
                SizedBox(height: 15.h),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  validator: (value) => value == null || value.isEmpty
                      ? 'يرجى كتابة التعديل المطلوب'
                      : null,
                  decoration: InputDecoration(
                    labelText: 'التعديل المطلوب بالتفصيل',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r)),
                  ),
                ),
                SizedBox(height: 30.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A5276),
                      padding: EdgeInsets.symmetric(vertical: 15.h),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r)),
                    ),
                    child: _isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text('حفظ الطلب',
                            style: TextStyle(
                                fontSize: 16.sp,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isNumber = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      validator: (value) =>
          value == null || value.isEmpty ? 'هذا الحقل مطلوب' : null,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: BorderSide(color: Colors.grey.shade300)),
      ),
    );
  }
}

class _CustomerSearchModal extends StatefulWidget {
  final Function(Customer) onCustomerSelected;

  const _CustomerSearchModal({required this.onCustomerSelected});

  @override
  State<_CustomerSearchModal> createState() => _CustomerSearchModalState();
}

class _CustomerSearchModalState extends State<_CustomerSearchModal> {
  List<Customer> _allCustomers = [];
  List<Customer> _filteredCustomers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _searchController.addListener(_filterCustomers);
  }

  Future<void> _loadCustomers() async {
    try {
      final db = await DatabaseHelper().database;
      final List<Map<String, dynamic>> maps = await db.query('Customer');
      setState(() {
        _allCustomers = maps.map((e) => Customer.fromJson(e)).toList();
        _filteredCustomers = _allCustomers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _filterCustomers() {
    String query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredCustomers = _allCustomers.where((cust) {
        String name = cust.nameCustomer?.toLowerCase() ?? '';
        String id = cust.idCustomer.toString();
        String meter = cust.numAddaad?.toString() ?? '';
        return name.contains(query) ||
            id.contains(query) ||
            meter.contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('اختر المشترك'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400.h,
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'ابحث بالاسم، الرقم، أو العداد...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r)),
                ),
              ),
              SizedBox(height: 10.h),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredCustomers.isEmpty
                        ? const Center(child: Text('لا يوجد مشتركين مطابقين'))
                        : ListView.builder(
                            itemCount: _filteredCustomers.length,
                            itemBuilder: (context, index) {
                              Customer cust = _filteredCustomers[index];
                              return ListTile(
                                title: Text(cust.nameCustomer ?? 'بدون اسم',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                    'رقم: ${cust.idCustomer} | العداد: ${cust.numAddaad ?? "لا يوجد"}'),
                                onTap: () {
                                  widget.onCustomerSelected(cust);
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}
