class Reading {
  final int id;
  final int? numAddaad; // رقم العداد
  final double readingValue;
  final String? readingDate;
  final String? currentMonth;
  final int? idCustomer;
  final int? idGeathers;
  final String status;
  final String? imagePath;
  final int syncStatus;

  Reading({
    required this.id,
    this.numAddaad,
    required this.readingValue,
    this.readingDate,
    this.currentMonth,
    this.idCustomer,
    this.idGeathers,
    this.status = 'pending',
    this.imagePath,
    this.syncStatus = 0,
  });

  factory Reading.fromJson(Map<String, dynamic> json) {
    return Reading(
      id: json['id'] ?? 0,
      numAddaad: json['num_addaad'],
      readingValue:
          double.tryParse(json['reading_value']?.toString() ?? '0') ?? 0.0,
      readingDate: json['reading_date'],
      currentMonth: json['current_month'],
      idCustomer: json['id_customer'],
      idGeathers: json['id_geathers'],
      status: json['status'] ?? 'pending',
      imagePath: json['image_path'],
      syncStatus: json['sync_status'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'num_addaad': numAddaad,
      'reading_value': readingValue,
      'reading_date': readingDate,
      'current_month': currentMonth,
      'id_customer': idCustomer,
      'id_geathers': idGeathers,
      'status': status,
      'image_path': imagePath,
      'sync_status': syncStatus,
    };
  }
}
