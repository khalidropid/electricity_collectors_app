// جدول المنطقة

class Area {
  final int id;
  final int? centralId;
  final String areaCode;
  final String name;
  final int status;

  Area({
    required this.id,
    this.centralId,
    required this.areaCode,
    required this.name,
    required this.status,
  });

  factory Area.fromJson(Map<String, dynamic> json) {
    return Area(
      id: json['id'] ?? 0,
      centralId: json['central_id'],
      areaCode: json['area_code'] ?? '',
      name: json['name'] ?? '',
      status: json['status'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'central_id': centralId,
      'area_code': areaCode,
      'name': name,
      'status': status,
    };
  }
}
