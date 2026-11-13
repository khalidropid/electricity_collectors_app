// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:intl/intl.dart' hide TextDirection;
// import 'package:dio/dio.dart';

// import '../database/database_helper.dart';
// import '../models/customer.dart';

// class SmsBillsScreen extends StatefulWidget {
//   const SmsBillsScreen({super.key});

//   @override
//   State<SmsBillsScreen> createState() => _SmsBillsScreenState();
// }

// class _SmsBillsScreenState extends State<SmsBillsScreen> {
//   List<Customer> _customers = [];
//   List<Customer> _filteredCustomers = [];
//   final Set<int> _selectedCustomerIds = {};
//   bool _isLoading = true;
//   bool _isSending = false;
//   final TextEditingController _searchController = TextEditingController();

//   // 🌟 بيانات المحطة للرسائل
//   final String stationName = "محطة الحسن ";
//   final String stationPhone = "77XXXXXXX"; // قم بتعديله لرقم المحطة

//   @override
//   void initState() {
//     super.initState();
//     _loadCustomers();
//   }

//   Future<void> _loadCustomers() async {
//     final db = await DatabaseHelper().database;
//     final List<Map<String, dynamic>> maps = await db.query('customers');

//     setState(() {
//       _customers = maps.map((c) => Customer.fromMap(c)).toList();
//       // استبعاد العملاء الذين رصيدهم صفر أو أقل
//       _filteredCustomers =
//           _customers.where((c) => (c.instantBalance ?? 0) > 0).toList();
//       _isLoading = false;
//     });
//   }

//   void _filterSearch(String query) {
//     setState(() {
//       _filteredCustomers = _customers
//           .where((c) => (c.instantBalance ?? 0) > 0)
//           .where((c) =>
//               c.name.contains(query) ||
//               (c.subscriberNo?.contains(query) ?? false))
//           .toList();
//     });
//   }

//   void _toggleSelectAll() {
//     setState(() {
//       if (_selectedCustomerIds.length == _filteredCustomers.length) {
//         _selectedCustomerIds.clear();
//       } else {
//         _selectedCustomerIds.addAll(_filteredCustomers.map((c) => c.id));
//       }
//     });
//   }

//   // ==========================================
//   // نافذة اختيار نوع الرسالة (فاتورة أو إنذار)
//   // ==========================================
//   void _showMessageTypeDialog() {
//     if (_selectedCustomerIds.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('الرجاء تحديد مشترك واحد على الأقل')),
//       );
//       return;
//     }

//     showModalBottomSheet(
//       context: context,
//       shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
//       builder: (context) {
//         return Directionality(
//           textDirection: TextDirection.rtl,
//           child: Container(
//             padding: EdgeInsets.all(20.w),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text('اختر نوع الرسالة',
//                     style: TextStyle(
//                         fontSize: 18.sp, fontWeight: FontWeight.bold)),
//                 SizedBox(height: 20.h),

//                 // 1. خيار إرسال الفاتورة الشهرية المفصلة
//                 ListTile(
//                   leading: const Icon(Icons.receipt_long, color: Colors.blue),
//                   title: const Text('إرسال فاتورة شهرية مفصلة'),
//                   subtitle: const Text('قراءة سابقة، حالية، واستهلاك'),
//                   onTap: () {
//                     Navigator.pop(context);
//                     _sendBulkSms(messageType: 'bill');
//                   },
//                 ),
//                 Divider(color: Colors.grey.shade200),

//                 // 2. خيار إرسال رسالة إنذار فصل
//                 ListTile(
//                   leading: const Icon(Icons.warning_amber_rounded,
//                       color: Colors.red),
//                   title: const Text('إرسال إنذار فصل'),
//                   subtitle: const Text('رسالة تحذيرية بالمبلغ المتبقي'),
//                   onTap: () {
//                     Navigator.pop(context);
//                     _showWarningDayDialog(); // نطلب منه تحديد يوم الفصل أولاً
//                   },
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   // نافذة فرعية لتحديد يوم الفصل في حال اختار "إنذار"
//   void _showWarningDayDialog() {
//     String selectedDay = 'الاثنين';
//     final List<String> days = [
//       'السبت',
//       'الأحد',
//       'الاثنين',
//       'الثلاثاء',
//       'الأربعاء',
//       'الخميس',
//       'الجمعة'
//     ];

//     showDialog(
//       context: context,
//       builder: (context) {
//         return Directionality(
//           textDirection: TextDirection.rtl,
//           child: AlertDialog(
//             title: const Text('تحديد يوم الفصل'),
//             content: DropdownButtonFormField<String>(
//               value: selectedDay,
//               items: days
//                   .map((day) => DropdownMenuItem(value: day, child: Text(day)))
//                   .toList(),
//               onChanged: (value) => selectedDay = value!,
//               decoration: const InputDecoration(border: OutlineInputBorder()),
//             ),
//             actions: [
//               TextButton(
//                   onPressed: () => Navigator.pop(context),
//                   child: const Text('إلغاء')),
//               ElevatedButton(
//                 onPressed: () {
//                   Navigator.pop(context);
//                   _sendBulkSms(messageType: 'warning', warningDay: selectedDay);
//                 },
//                 child: const Text('إرسال الإنذار'),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   // ==========================================
//   // دالة الإرسال الفعلية للسيرفر
//   // ==========================================
//   Future<void> _sendBulkSms(
//       {required String messageType, String? warningDay}) async {
//     setState(() => _isSending = true);

//     try {
//       List<Map<String, dynamic>> smsData = [];

//       // تجهيز بيانات كل عميل محدد
//       for (var c in _filteredCustomers
//           .where((c) => _selectedCustomerIds.contains(c.id))) {
//         String? customMessage;

//         // إذا كان إنذار، نقوم بتجهيز النص محلياً كما في الصورة
//         if (messageType == 'warning') {
//           customMessage =
//               "لتفادي الفصل يوم $warningDay اخر موعد لتسديد مبلغ ${c.instantBalance?.toInt() ?? 0} $stationName $stationPhone";
//         }

//         // إذا كان فاتورة 'bill'، سنترك حقل الرسالة فارغاً ليقوم السيرفر بتجهيزه من القراءات

//         smsData.add({
//           'customer_id': c.id,
//           'phone': c.phone,
//           'message': customMessage,
//         });
//       }

//       final dio = Dio();
//       final response = await dio.post(
//         'https://saleh.me.ye/api/send_sms_api.php',
//         data: {
//           'type': messageType,
//           'station_name': stationName,
//           'station_phone': stationPhone,
//           'customers': smsData
//         },
//       );

//       if (response.statusCode == 200 && response.data['success'] == true) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//                 content: Text('تم إرسال الرسائل بنجاح ✓'),
//                 backgroundColor: Colors.green),
//           );
//           setState(() => _selectedCustomerIds.clear());
//         }
//       } else {
//         throw Exception(response.data['message'] ?? 'فشل الإرسال من السيرفر');
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() => _isSending = false);
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     bool isAllSelected =
//         _selectedCustomerIds.length == _filteredCustomers.length &&
//             _filteredCustomers.isNotEmpty;

//     return Directionality(
//       textDirection: TextDirection.rtl,
//       child: Scaffold(
//         backgroundColor: const Color(0xFFF5F7FA),
//         appBar: AppBar(
//           backgroundColor: const Color(0xFF1A5276),
//           title: Text('إرسال الرسائل',
//               style: TextStyle(
//                   fontSize: 18.sp,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.white)),
//           centerTitle: true,
//           iconTheme: const IconThemeData(color: Colors.white),
//         ),
//         body: _isLoading
//             ? const Center(child: CircularProgressIndicator())
//             : Column(
//                 children: [
//                   Container(
//                     padding: EdgeInsets.all(15.w),
//                     color: Colors.white,
//                     child: Column(
//                       children: [
//                         TextField(
//                           controller: _searchController,
//                           onChanged: _filterSearch,
//                           decoration: InputDecoration(
//                             hintText: 'بحث عن مشترك...',
//                             prefixIcon: const Icon(Icons.search),
//                             filled: true,
//                             fillColor: Colors.grey.shade100,
//                             border: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(10.r),
//                                 borderSide: BorderSide.none),
//                           ),
//                         ),
//                         SizedBox(height: 10.h),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Text('المديونين: ${_filteredCustomers.length}',
//                                 style: TextStyle(
//                                     fontWeight: FontWeight.bold,
//                                     color: Colors.grey.shade700)),
//                             TextButton.icon(
//                               onPressed: _toggleSelectAll,
//                               icon: Icon(
//                                   isAllSelected
//                                       ? Icons.check_box
//                                       : Icons.check_box_outline_blank,
//                                   color: const Color(0xFF1A5276)),
//                               label: Text(
//                                   isAllSelected ? 'إلغاء الكل' : 'تحديد الكل',
//                                   style: const TextStyle(
//                                       color: Color(0xFF1A5276))),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                   Expanded(
//                     child: ListView.builder(
//                       itemCount: _filteredCustomers.length,
//                       itemBuilder: (context, index) {
//                         final customer = _filteredCustomers[index];
//                         final isSelected =
//                             _selectedCustomerIds.contains(customer.id);

//                         return Card(
//                           margin: EdgeInsets.symmetric(
//                               horizontal: 10.w, vertical: 5.h),
//                           child: CheckboxListTile(
//                             activeColor: const Color(0xFF1A5276),
//                             title: Text(customer.name,
//                                 style: TextStyle(
//                                     fontWeight: FontWeight.bold,
//                                     fontSize: 15.sp)),
//                             subtitle: Text(
//                                 'الرصيد: ${NumberFormat('#,##0').format(customer.instantBalance)} ريال | الجوال: ${customer.phone ?? "لا يوجد"}'),
//                             value: isSelected,
//                             onChanged: (bool? value) {
//                               setState(() {
//                                 if (value == true) {
//                                   _selectedCustomerIds.add(customer.id);
//                                 } else {
//                                   _selectedCustomerIds.remove(customer.id);
//                                 }
//                               });
//                             },
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//                 ],
//               ),
//         floatingActionButton: _filteredCustomers.isNotEmpty
//             ? FloatingActionButton.extended(
//                 onPressed: _isSending
//                     ? null
//                     : _showMessageTypeDialog, // يفتح نافذة الاختيار
//                 backgroundColor: _selectedCustomerIds.isEmpty
//                     ? Colors.grey
//                     : Colors.blue.shade700,
//                 icon: _isSending
//                     ? const SizedBox(
//                         width: 20,
//                         height: 20,
//                         child: CircularProgressIndicator(
//                             color: Colors.white, strokeWidth: 2))
//                     : const Icon(Icons.send, color: Colors.white),
//                 label: Text('إرسال (${_selectedCustomerIds.length})',
//                     style: const TextStyle(
//                         color: Colors.white, fontWeight: FontWeight.bold)),
//               )
//             : null,
//       ),
//     );
//   }
// }
