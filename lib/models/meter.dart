//  جدول العداد

class Meter {
  final int id;
  final int? centralId;
  final String meterNo;
  final int subscriberId;
  final double initialReading;
  final double lastReading;
  final String? lastReadingDate;
  final String status;

  Meter({
    required this.id,
    this.centralId,
    required this.meterNo,
    required this.subscriberId,
    required this.initialReading,
    required this.lastReading,
    this.lastReadingDate,
    required this.status,
  });

  factory Meter.fromJson(Map<String, dynamic> json) {
    return Meter(
      id: json['id'] ?? 0,
      centralId: json['central_id'],
      meterNo: json['meter_no'] ?? '',
      subscriberId: json['subscriber_id'] ?? 0,
      initialReading: double.parse(json['initial_reading']?.toString() ?? '0'),
      lastReading: double.parse(json['last_reading']?.toString() ?? '0'),
      lastReadingDate: json['last_reading_date'],
      status: json['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'central_id': centralId,
      'meter_no': meterNo,
      'subscriber_id': subscriberId,
      'initial_reading': initialReading,
      'last_reading': lastReading,
      'last_reading_date': lastReadingDate,
      'status': status,
    };
  }
}
