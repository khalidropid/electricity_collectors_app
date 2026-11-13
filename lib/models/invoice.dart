class Invoice {
  final int id;
  final String receiptNo;
  final int? idCustomer;
  final String? customerName;
  final String? meterNo;
  final double totalAmount;
  final double amountPaid;
  final double remainingAmount;
  final String? paymentDate;
  final int? idGeathers; // رقم المحصل
  final String? collectorName;
  final int syncStatus; // 0 = لم يرفع, 1 = تم الرفع

  Invoice({
    required this.id,
    required this.receiptNo,
    this.idCustomer,
    this.customerName,
    this.meterNo,
    required this.totalAmount,
    required this.amountPaid,
    required this.remainingAmount,
    this.paymentDate,
    this.idGeathers,
    this.collectorName,
    this.syncStatus = 0,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] ?? 0,
      receiptNo: json['receipt_no'] ?? '',
      idCustomer: json['id_customer'],
      customerName: json['customer_name'],
      meterNo: json['meter_no'],
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      amountPaid: double.tryParse(json['amount_paid']?.toString() ?? '0') ?? 0.0,
      remainingAmount: double.tryParse(json['remaining_amount']?.toString() ?? '0') ?? 0.0,
      paymentDate: json['payment_date'],
      idGeathers: json['id_geathers'],
      collectorName: json['collector_name'],
      syncStatus: json['sync_status'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'receipt_no': receiptNo,
      'id_customer': idCustomer,
      'customer_name': customerName,
      'meter_no': meterNo,
      'total_amount': totalAmount,
      'amount_paid': amountPaid,
      'remaining_amount': remainingAmount,
      'payment_date': paymentDate,
      'id_geathers': idGeathers,
      'collector_name': collectorName,
      'sync_status': syncStatus,
    };
  }
}