class Payment {
  final int id;
  final String? receiptNo;
  final double amount;
  final String? paymentDate;
  final String paymentMethod;
  final int? idCustomer;
  final int? idGeathers;
  final String status; // 'pending' أو 'synced' (للتوافق القديم)
  final int syncStatus; // الأساسي للأوفلاين

  Payment({
    required this.id,
    this.receiptNo,
    required this.amount,
    this.paymentDate,
    this.paymentMethod = 'نقدي',
    this.idCustomer,
    this.idGeathers,
    this.status = 'pending',
    this.syncStatus = 0,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] ?? 0,
      receiptNo: json['receipt_no'],
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      paymentDate: json['payment_date'],
      paymentMethod: json['payment_method'] ?? 'نقدي',
      idCustomer: json['id_customer'],
      idGeathers: json['id_geathers'],
      status: json['status'] ?? 'pending',
      syncStatus: json['sync_status'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'receipt_no': receiptNo,
      'amount': amount,
      'payment_date': paymentDate,
      'payment_method': paymentMethod,
      'id_customer': idCustomer,
      'id_geathers': idGeathers,
      'status': status,
      'sync_status': syncStatus,
    };
  }
}
