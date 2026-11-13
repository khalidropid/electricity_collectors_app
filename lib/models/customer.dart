class Customer {
  final int idCustomer;
  final String nameCustomer;
  final String?
      numPhone; // 🌟 تم التعديل إلى String للحفاظ على الصفر في بداية الرقم
  final String? addressCustomer;
  final String? nextCustomer;
  final String? streetCustomer;
  final String? typeWork;
  final String? setCustomer;
  final int? numAccount;
  final String?
      numAddaad; // 🌟 تم التعديل إلى String لتجنب الأخطاء إذا كان فيه حروف
  final int? idState;
  final String? tc;
  double?
      instantBalance; // 🌟 تم التعديل إلى double وإلغاء final لتحديث الرصيد محلياً
  int? takeReading; // 🌟 تم إلغاء final لتحديث حالة القراءة محلياً

  Customer({
    required this.idCustomer,
    required this.nameCustomer,
    this.numPhone,
    this.addressCustomer,
    this.nextCustomer,
    this.streetCustomer,
    this.typeWork,
    this.setCustomer,
    this.numAccount,
    this.numAddaad,
    this.idState,
    this.tc,
    this.instantBalance,
    this.takeReading,
  });

  // ==========================================
  // 🌟 دالة التحويل الآمنة (مضادة للانهيار)
  // ==========================================
  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      // تحويل آمن لمعالجة أي نوع بيانات قادم من السيرفر أو SQLite
      idCustomer: int.tryParse(json['id_customer']?.toString() ?? '0') ?? 0,
      nameCustomer: json['name_customer']?.toString() ?? 'غير معروف',
      numPhone: json['num_phone']?.toString(),
      addressCustomer: json['address_customer']?.toString(),
      nextCustomer: json['next_customer']?.toString(),
      streetCustomer: json['Street_customer']?.toString(),
      typeWork: json['type_work']?.toString(),
      setCustomer: json['Set_customer']?.toString(),
      numAccount: int.tryParse(json['num_account']?.toString() ?? ''),
      numAddaad: json['num_addaad']?.toString(),
      idState: int.tryParse(json['id_state']?.toString() ?? ''),
      tc: json['TC']?.toString(),
      instantBalance:
          double.tryParse(json['Instant_balance']?.toString() ?? '0.0'),
      takeReading: int.tryParse(json['Take_reading']?.toString() ?? '0'),
    );
  }

  // ==========================================
  // 🌟 تجهيز البيانات للحفظ
  // ==========================================
  Map<String, dynamic> toJson() {
    return {
      'id_customer': idCustomer,
      'name_customer': nameCustomer,
      'num_phone': numPhone,
      'address_customer': addressCustomer,
      'next_customer': nextCustomer,
      'Street_customer': streetCustomer,
      'type_work': typeWork,
      'Set_customer': setCustomer,
      'num_account': numAccount,
      'num_addaad': numAddaad,
      'id_state': idState,
      'TC': tc,
      'Instant_balance': instantBalance,
      'Take_reading': takeReading,
    };
  }
}
