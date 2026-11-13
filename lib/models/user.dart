class User {
  final int id;
  final String name;
  final String username;
  final String role;
  final int status;
  // أضفنا هذه الحقول لأن المستخدم سيكون "متحصل" في الغالب
  final String? collectorCode;
  final String? phone;
  final int? areaId;

  User({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    required this.status,
    this.collectorCode,
    this.phone,
    this.areaId,
  });

  // دالة لتحويل البيانات القادمة من السيرفر (JSON) إلى كائن Dart
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      username: json['username'] ?? '',
      role: json['role'] ?? 'collector',
      status: json['status'] ?? 1,
      collectorCode: json['collector_code'],
      phone: json['phone'],
      areaId: json['area_id'],
    );
  }

  // دالة لتحويل الكائن إلى JSON لإرساله للسيرفر
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'role': role,
      'status': status,
      'collector_code': collectorCode,
      'phone': phone,
      'area_id': areaId,
    };
  }
}
