// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'receipt_screen.dart'; // تم إضافة الاستدعاء هنا

//    شاشة تسجيل التحصيل القديمة

// class CollectPaymentScreen extends StatefulWidget {
//   const CollectPaymentScreen({super.key});

//   @override
//   State<CollectPaymentScreen> createState() => _CollectPaymentScreenState();
// }

// class _CollectPaymentScreenState extends State<CollectPaymentScreen> {
//   final TextEditingController _amountController =
//       TextEditingController(text: '40000');
//   final TextEditingController _notesController = TextEditingController();

//   String _selectedPaymentMethod = 'نقدي';
//   final List<String> _paymentMethods = [
//     'نقدي',
//     'تحويل بنكي',
//     'شيك',
//     'إلكتروني'
//   ];

//   @override
//   void dispose() {
//     _amountController.dispose();
//     _notesController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Directionality(
//       textDirection: TextDirection.rtl,
//       child: Scaffold(
//         backgroundColor: Colors.white,
//         appBar: AppBar(
//           backgroundColor: const Color(0xFF1A5276),
//           title: Text(
//             'تسجيل تحصيل',
//             style: TextStyle(
//                 fontSize: 18.sp,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.white),
//           ),
//           centerTitle: true,
//           iconTheme: const IconThemeData(color: Colors.white),
//           actions: [
//             IconButton(
//               icon: const Icon(Icons.search_outlined),
//               onPressed: () {},
//             ),
//           ],
//         ),
//         body: SingleChildScrollView(
//           padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // 1. بطاقة معلومات المشترك والفاتورة
//               Container(
//                 padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 15.h),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   border: Border.all(color: Colors.grey.shade300),
//                   borderRadius: BorderRadius.circular(8.r),
//                 ),
//                 child: Column(
//                   children: [
//                     _buildInfoRow('المشترك', 'عبدالله أحمد علي'),
//                     SizedBox(height: 10.h),
//                     _buildInfoRow('الفاتورة', 'INV-2024-000125'),
//                   ],
//                 ),
//               ),
//               SizedBox(height: 20.h),

//               // 2. إجمالي الفاتورة المطلوب
//               Container(
//                 width: double.infinity,
//                 padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 15.h),
//                 decoration: BoxDecoration(
//                   color: Colors.grey.shade100,
//                   border: Border.all(color: Colors.grey.shade300),
//                   borderRadius: BorderRadius.circular(8.r),
//                 ),
//                 child: Text(
//                   '70,000',
//                   style: TextStyle(
//                       fontSize: 16.sp,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.black87),
//                 ),
//               ),
//               SizedBox(height: 20.h),

//               // 3. حقل إدخال مبلغ التحصيل
//               Text(
//                 'مبلغ التحصيل',
//                 style: TextStyle(
//                     fontSize: 14.sp,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.black87),
//               ),
//               SizedBox(height: 8.h),
//               TextField(
//                 controller: _amountController,
//                 keyboardType: TextInputType.number,
//                 style: TextStyle(
//                     fontSize: 16.sp,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.green.shade700),
//                 decoration: InputDecoration(
//                   contentPadding:
//                       EdgeInsets.symmetric(horizontal: 15.w, vertical: 15.h),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8.r),
//                     borderSide:
//                         const BorderSide(color: Colors.green, width: 1.5),
//                   ),
//                   enabledBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8.r),
//                     borderSide:
//                         const BorderSide(color: Colors.green, width: 1.5),
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8.r),
//                     borderSide: const BorderSide(color: Colors.green, width: 2),
//                   ),
//                 ),
//               ),
//               SizedBox(height: 20.h),

//               // 4. القائمة المنسدلة لطريقة الدفع
//               Text(
//                 'طريقة الدفع',
//                 style: TextStyle(
//                     fontSize: 14.sp,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.black87),
//               ),
//               SizedBox(height: 8.h),
//               DropdownButtonFormField<String>(
//                 value: _selectedPaymentMethod,
//                 icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
//                 dropdownColor: Colors.white, // تم تحديد لون خلفية القائمة بوضوح
//                 decoration: InputDecoration(
//                   contentPadding:
//                       EdgeInsets.symmetric(horizontal: 15.w, vertical: 15.h),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8.r),
//                     borderSide: BorderSide(color: Colors.grey.shade300),
//                   ),
//                   enabledBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8.r),
//                     borderSide: BorderSide(color: Colors.grey.shade300),
//                   ),
//                 ),
//                 items: _paymentMethods.map((String method) {
//                   return DropdownMenuItem<String>(
//                     value: method,
//                     child: Text(
//                       method,
//                       // تم إجبار النص على أخذ اللون الأسود الداكن ليظهر بوضوح
//                       style: TextStyle(fontSize: 14.sp, color: Colors.black87),
//                     ),
//                   );
//                 }).toList(),
//                 onChanged: (String? newValue) {
//                   setState(() {
//                     _selectedPaymentMethod = newValue!;
//                   });
//                 },
//               ),
//               SizedBox(height: 20.h),

//               // 5. حقل الملاحظات
//               Text(
//                 'ملاحظات',
//                 style: TextStyle(
//                     fontSize: 14.sp,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.black87),
//               ),
//               SizedBox(height: 8.h),
//               TextField(
//                 controller: _notesController,
//                 maxLines: 3,
//                 style: TextStyle(fontSize: 14.sp, color: Colors.black87),
//                 decoration: InputDecoration(
//                   hintText: 'اكتب ملاحظات (اختياري)',
//                   hintStyle:
//                       TextStyle(fontSize: 12.sp, color: Colors.grey.shade500),
//                   contentPadding:
//                       EdgeInsets.symmetric(horizontal: 15.w, vertical: 15.h),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8.r),
//                     borderSide: BorderSide(color: Colors.grey.shade300),
//                   ),
//                   enabledBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8.r),
//                     borderSide: BorderSide(color: Colors.grey.shade300),
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8.r),
//                     borderSide:
//                         const BorderSide(color: Color(0xFF1A5276), width: 1.5),
//                   ),
//                 ),
//               ),
//               SizedBox(height: 40.h),

//               // 6. زر تأكيد التحصيل
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: () {
//                     // --- إضافة الحدث هنا للانتقال إلى شاشة الإيصال ---
//                     Navigator.pushReplacement(
//                       context,
//                       MaterialPageRoute(
//                         builder: (context) => const ReceiptScreen(),
//                       ),
//                     );
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.green,
//                     padding: EdgeInsets.symmetric(vertical: 15.h),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(8.r),
//                     ),
//                   ),
//                   child: Text(
//                     'تأكيد التحصيل',
//                     style: TextStyle(
//                         fontSize: 16.sp,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.white),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // دالة مساعدة لصف المعلومات العلوي
//   Widget _buildInfoRow(String label, String value) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Text(
//           label,
//           style: TextStyle(
//               fontSize: 13.sp,
//               fontWeight: FontWeight.bold,
//               color: Colors.black87),
//         ),
//         Text(
//           value,
//           style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade700),
//         ),
//       ],
//     );
//   }
// }
