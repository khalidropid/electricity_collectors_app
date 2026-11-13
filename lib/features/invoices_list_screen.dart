import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../models/invoice.dart';
import '../database/database_helper.dart';

class InvoicesListScreen extends StatefulWidget {
  const InvoicesListScreen({super.key});

  @override
  State<InvoicesListScreen> createState() => _InvoicesListScreenState();
}

class _InvoicesListScreenState extends State<InvoicesListScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Invoice> _allInvoices = [];
  List<Invoice> _filteredInvoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==========================================
  // جلب السندات من قاعدة البيانات
  // ==========================================
  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper().database;
      // 🌟 التحديث هنا: جلب السندات من جدول app_invoices
      final List<Map<String, dynamic>> maps =
          await db.query('app_invoices', orderBy: 'id DESC');

      final invoices = maps.map((e) => Invoice.fromJson(e)).toList();

      if (mounted) {
        setState(() {
          _allInvoices = invoices;
          _filteredInvoices = invoices;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("خطأ في جلب السندات: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ==========================================
  // دالة البحث الذكي
  // ==========================================
  void _filterInvoices(String query) {
    if (query.isEmpty) {
      setState(() => _filteredInvoices = _allInvoices);
      return;
    }

    setState(() {
      _filteredInvoices = _allInvoices.where((invoice) {
        // 🌟 التحديث هنا: استخدام الحماية من القيم الفارغة (Null Safety)
        final nameMatch = (invoice.customerName ?? '')
            .toLowerCase()
            .contains(query.toLowerCase());
        final meterMatch =
            (invoice.meterNo ?? '').toLowerCase().contains(query.toLowerCase());
        return nameMatch || meterMatch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A5276),
          title: Text('سجل السندات',
              style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Column(
          children: [
            // مربع البحث
            Container(
              padding: EdgeInsets.all(15.w),
              color: Colors.white,
              child: TextField(
                controller: _searchController,
                onChanged: _filterInvoices,
                decoration: InputDecoration(
                  hintText: 'ابحث باسم المشترك أو رقم العداد...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            _filterInvoices('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 0, horizontal: 15.w),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // قائمة السندات
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredInvoices.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(
                              horizontal: 15.w, vertical: 10.h),
                          itemCount: _filteredInvoices.length,
                          itemBuilder: (context, index) {
                            final invoice = _filteredInvoices[index];
                            return _buildInvoiceCard(invoice);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // تصميم بطاقة السند في القائمة
  // ==========================================
  Widget _buildInvoiceCard(Invoice invoice) {
    DateTime parsedDate =
        DateTime.tryParse(invoice.paymentDate ?? '') ?? DateTime.now();
    String formattedDate = DateFormat('yyyy-MM-dd').format(parsedDate);
    String formattedTime = DateFormat('hh:mm a').format(parsedDate);

    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 12.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: () => _showInvoiceDetailsBottomSheet(invoice),
        child: Padding(
          padding: EdgeInsets.all(15.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      invoice.receiptNo,
                      style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.sp),
                    ),
                  ),
                  Text(
                    '$formattedDate | $formattedTime',
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 12.sp),
                  ),
                ],
              ),
              Divider(height: 20.h, color: Colors.grey.shade200),
              Text(
                invoice.customerName ?? 'غير معروف',
                style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              SizedBox(height: 5.h),
              Row(
                children: [
                  Icon(Icons.speed, size: 16.w, color: Colors.grey.shade600),
                  SizedBox(width: 5.w),
                  Text(
                    'رقم العداد: ${(invoice.meterNo ?? '').isNotEmpty ? invoice.meterNo : "غير متوفر"}',
                    style:
                        TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
                  ),
                ],
              ),
              SizedBox(height: 15.h),
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildAmountColumn('المدفوع', invoice.amountPaid,
                        Colors.green.shade700, true),
                    Container(
                        height: 30.h, width: 1, color: Colors.grey.shade300),
                    _buildAmountColumn('السابق', invoice.totalAmount,
                        Colors.grey.shade700, false),
                    Container(
                        height: 30.h, width: 1, color: Colors.grey.shade300),
                    _buildAmountColumn('المتبقي', invoice.remainingAmount,
                        Colors.red.shade700, false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountColumn(
      String label, double amount, Color color, bool isHighlight) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600)),
        SizedBox(height: 2.h),
        Text(
          NumberFormat('#,##0').format(amount),
          style: TextStyle(
            fontSize: isHighlight ? 16.sp : 14.sp,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80.w, color: Colors.grey.shade300),
          SizedBox(height: 15.h),
          Text(
            _searchController.text.isEmpty
                ? 'لا توجد سندات محفوظة بعد'
                : 'لم يتم العثور على نتائج للبحث',
            style: TextStyle(
                fontSize: 16.sp,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 🌟 النافذة السفلية لعرض تفاصيل السند (عرض فقط) 🌟
  // ==========================================
  void _showInvoiceDetailsBottomSheet(Invoice invoice) {
    DateTime parsedDate =
        DateTime.tryParse(invoice.paymentDate ?? '') ?? DateTime.now();
    String displayDateTime =
        DateFormat('yyyy-MM-dd | hh:mm a').format(parsedDate);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: EdgeInsets.all(25.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50.w,
                  height: 5.h,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10.r)),
                ),
                SizedBox(height: 20.h),
                Text('تفاصيل السند',
                    style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A5276))),
                SizedBox(height: 25.h),
                _buildDetailRow('رقم السند المرجعي', invoice.receiptNo),
                _buildDetailRow(
                    'اسم المشترك', invoice.customerName ?? 'غير معروف',
                    isBold: true),
                _buildDetailRow(
                    'رقم العداد',
                    (invoice.meterNo ?? '').isNotEmpty
                        ? invoice.meterNo!
                        : 'غير متوفر'),
                _buildDetailRow('الوقت والتاريخ', displayDateTime),
                _buildDetailRow(
                    'المحصل',
                    (invoice.collectorName ?? '').isNotEmpty
                        ? invoice.collectorName!
                        : 'غير معروف'),
                Divider(height: 30.h, color: Colors.grey.shade300),
                _buildDetailRow('الديون السابقة',
                    '${NumberFormat('#,##0').format(invoice.totalAmount)} ريال'),
                _buildDetailRow('المبلغ المدفوع',
                    '${NumberFormat('#,##0').format(invoice.amountPaid)} ريال',
                    isHighlight: true),
                _buildDetailRow('الرصيد المتبقي',
                    '${NumberFormat('#,##0').format(invoice.remainingAmount)} ريال',
                    isBold: true),
                SizedBox(height: 10.h),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value,
      {bool isBold = false, bool isHighlight = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600)),
          Text(
            value,
            style: TextStyle(
              fontSize: isHighlight ? 16.sp : 14.sp,
              fontWeight:
                  isBold || isHighlight ? FontWeight.bold : FontWeight.normal,
              color: isHighlight ? Colors.green.shade700 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
