import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'dart:convert'; // 🌟 للتعامل مع الصلاحيات

import '../providers/customer_provider.dart';
import 'customer_details_screen.dart';
import '../widgets/app_drawer.dart';
import '../models/customer.dart';
import '../core/utils/secure_storage_helper.dart'; // 🌟 استيراد ملف التخزين

class CustomerSearchScreen extends StatefulWidget {
  final int? empId;
  const CustomerSearchScreen({super.key, this.empId});

  @override
  State<CustomerSearchScreen> createState() => _CustomerSearchScreenState();
}

class _CustomerSearchScreenState extends State<CustomerSearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  // 🌟 متغيرات الصلاحيات
  Map<String, dynamic> _permissions = {};
  bool _isLoadingPermissions = true;

  @override
  void initState() {
    super.initState();
    _loadPermissions(); // 🌟 تحميل الصلاحيات عند فتح الشاشة

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<CustomerProvider>(context, listen: false);
      provider.loadCustomers(); // تحميل كل المشتركين المحفوظين محلياً
    });
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🌟 قراءة حالة إخفاء البحث بالكامل
    bool hideSearch = _permissions['hide_search_icon'] == 1 ||
        _permissions['hide_search_icon'] == true;

    // 🌟 التحقق من صلاحية البحث برقم الهاتف لتغيير النص الإرشادي
    bool allowPhoneSearch = _permissions['allow_phone_search'] == 1 ||
        _permissions['allow_phone_search'] == true;
    String searchHint = allowPhoneSearch
        ? 'ابحث بالاسم، الهاتف، رقم المشترك، أو العداد...'
        : 'ابحث بالاسم، رقم المشترك، أو العداد...';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        drawer: const AppDrawer(),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A5276),
          elevation: 0,
          title: Text('قائمة المشتركين',
              style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _isLoadingPermissions
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // 🌟 إخفاء شريط البحث بالكامل إذا كانت الصلاحية مسحوبة
                  if (!hideSearch)
                    Container(
                      color: const Color(0xFF1A5276),
                      padding: EdgeInsets.only(
                          left: 20.w, right: 20.w, bottom: 20.h),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15.r),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10)
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) => Provider.of<CustomerProvider>(
                                  context,
                                  listen: false)
                              .searchCustomers(value),
                          decoration: InputDecoration(
                            hintText:
                                searchHint, // 🌟 استخدام النص الإرشادي الديناميكي
                            hintStyle: TextStyle(
                                color: Colors.grey.shade400, fontSize: 13.sp),
                            prefixIcon: const Icon(Icons.search,
                                color: Color(0xFF1A5276)),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear,
                                        color: Colors.grey),
                                    onPressed: () {
                                      _searchController.clear();
                                      Provider.of<CustomerProvider>(context,
                                              listen: false)
                                          .searchCustomers('');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding:
                                EdgeInsets.symmetric(vertical: 15.h),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Consumer<CustomerProvider>(
                      builder: (context, provider, child) {
                        if (provider.isLoading) {
                          return const Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFF1A5276)));
                        }

                        if (provider.customers.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_off_rounded,
                                    size: 80.w, color: Colors.grey.shade300),
                                SizedBox(height: 15.h),
                                Text('لا يوجد مشتركون مطابقون للبحث',
                                    style: TextStyle(
                                        fontSize: 16.sp,
                                        color: Colors.grey.shade500)),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16.w, vertical: 15.h),
                          itemCount: provider.customers.length,
                          itemBuilder: (context, index) {
                            final customer = provider.customers[index];
                            return _buildCustomerCard(
                                customer, context, provider);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCustomerCard(
      Customer customer, BuildContext context, CustomerProvider provider) {
    bool isRead = customer.takeReading == 1;

    return InkWell(
      onTap: () async {
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => CustomerDetailsScreen(
                    customer: customer, empId: widget.empId ?? 1)));
        provider.refreshCustomers();
      },
      borderRadius: BorderRadius.circular(15.r),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(15.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15.r),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            CircleAvatar(
                radius: 25.r,
                backgroundColor:
                    isRead ? Colors.green.shade50 : Colors.blue.shade50,
                child: Icon(Icons.person,
                    color: isRead ? Colors.green : const Color(0xFF1A5276),
                    size: 28.w)),
            SizedBox(width: 15.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(customer.nameCustomer,
                      style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Icon(Icons.confirmation_number_outlined,
                          size: 14.w, color: Colors.grey.shade500),
                      SizedBox(width: 5.w),
                      Text(customer.idCustomer.toString(),
                          style: TextStyle(
                              fontSize: 12.sp, color: Colors.grey.shade600)),
                      SizedBox(width: 15.w),
                      Icon(Icons.speed,
                          size: 14.w, color: Colors.grey.shade500),
                      SizedBox(width: 5.w),
                      Text(customer.numAddaad?.toString() ?? "غير متوفر",
                          style: TextStyle(
                              fontSize: 12.sp, color: Colors.grey.shade600)),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
              decoration: BoxDecoration(
                color: isRead ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                    color: isRead
                        ? Colors.green.shade200
                        : Colors.orange.shade200),
              ),
              child: Text(
                isRead ? 'مقروء' : 'ينتظر',
                style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                    color: isRead
                        ? Colors.green.shade700
                        : Colors.orange.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
