import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// شاشة كشف الحساب

class AccountStatementScreen extends StatelessWidget {
  const AccountStatementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // بيانات وهمية مطابقة للصورة لتجربة الجدول
    final List<Map<String, dynamic>> _transactions = [
      {
        'date': '2024-05-25',
        'desc': 'فاتورة',
        'debit': '70,000',
        'credit': '0',
        'balance': '70,000'
      },
      {
        'date': '2024-05-25',
        'desc': 'تحصيل',
        'debit': '0',
        'credit': '40,000',
        'balance': '30,000'
      },
      {
        'date': '2024-05-10',
        'desc': 'تحصيل',
        'debit': '0',
        'credit': '15,000',
        'balance': '15,000'
      },
      {
        'date': '2024-04-25',
        'desc': 'فاتورة',
        'debit': '50,000',
        'credit': '0',
        'balance': '65,000'
      },
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A5276),
          title: Column(
            children: [
              Text(
                'عبدالله أحمد علي', // اسم المشترك
                style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              Text(
                '100245', // رقم المشترك
                style: TextStyle(fontSize: 12.sp, color: Colors.white70),
              ),
            ],
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {},
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 15.h),

            // 1. ملخص الحساب (البطاقات العلوية الثلاث)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 15.w),
              child: Row(
                children: [
                  Expanded(
                      child: _buildSummaryCard(
                          'الرصيد المتبقي', '65,000', Colors.orange.shade700)),
                  SizedBox(width: 8.w),
                  Expanded(
                      child: _buildSummaryCard(
                          'إجمالي المدفوعات', '55,000', Colors.green.shade700)),
                  SizedBox(width: 8.w),
                  Expanded(
                      child: _buildSummaryCard(
                          'إجمالي الفواتير', '120,000', Colors.red.shade700)),
                ],
              ),
            ),
            SizedBox(height: 25.h),

            // عنوان الجدول
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 15.w),
              child: Text(
                'تفاصيل الحركات',
                style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
            ),
            SizedBox(height: 10.h),

            // 2. ترويسة الجدول (عناوين الأعمدة)
            Container(
              color: Colors.grey.shade100,
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
              child: Row(
                children: [
                  _buildTableHeader('الرصيد', flex: 2),
                  _buildTableHeader('دائن', flex: 2),
                  _buildTableHeader('مدين', flex: 2),
                  _buildTableHeader('البيان', flex: 2),
                  _buildTableHeader('التاريخ', flex: 3),
                ],
              ),
            ),

            // 3. صفوف البيانات (الجدول)
            Expanded(
              child: ListView.separated(
                itemCount: _transactions.length,
                separatorBuilder: (context, index) =>
                    Divider(color: Colors.grey.shade200, height: 1),
                itemBuilder: (context, index) {
                  final item = _transactions[index];
                  return Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10.w, vertical: 15.h),
                    child: Row(
                      children: [
                        _buildTableCell(item['balance']!,
                            flex: 2, isBold: true),
                        _buildTableCell(item['credit']!,
                            flex: 2, color: Colors.green.shade700),
                        _buildTableCell(item['debit']!,
                            flex: 2, color: Colors.red.shade700),
                        _buildTableCell(item['desc']!, flex: 2),
                        _buildTableCell(item['date']!,
                            flex: 3, fontSize: 11.sp),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- دوال مساعدة لبناء واجهة كشف الحساب ---

  // تصميم بطاقات الملخص العلوية
  Widget _buildSummaryCard(String title, String amount, Color amountColor) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 5.w),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 2),
            )
          ]),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 10.sp,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8.h),
          Text(
            amount,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: amountColor),
          ),
        ],
      ),
    );
  }

  // تصميم عناوين أعمدة الجدول
  Widget _buildTableHeader(String title, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
            color: Colors.black87),
      ),
    );
  }

  // تصميم خلايا الجدول
  Widget _buildTableCell(String value,
      {required int flex,
      Color? color,
      bool isBold = false,
      double? fontSize}) {
    return Expanded(
      flex: flex,
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: fontSize ?? 12.sp,
          color: color ?? Colors.black87,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
