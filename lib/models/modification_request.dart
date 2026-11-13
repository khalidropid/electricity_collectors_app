class ModificationRequest {
  final int id;
  final int? idGeathers;
  final int? idCustomer;
  final String? nameCustomer;
  final String? addressCustomer;
  final String? modType;
  final String? notes;
  final String? requestDate;
  final String status;
  final int syncStatus;

  ModificationRequest({
    required this.id,
    this.idGeathers,
    this.idCustomer,
    this.nameCustomer,
    this.addressCustomer,
    this.modType,
    this.notes,
    this.requestDate,
    this.status = 'pending',
    this.syncStatus = 0,
  });

  factory ModificationRequest.fromJson(Map<String, dynamic> json) {
    return ModificationRequest(
      id: json['id'] ?? 0,
      idGeathers: json['id_geathers'],
      idCustomer: json['id_customer'],
      nameCustomer: json['name_customer'],
      addressCustomer: json['address_customer'],
      modType: json['mod_type'],
      notes: json['notes'],
      requestDate: json['request_date'],
      status: json['status'] ?? 'pending',
      syncStatus: json['sync_status'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'id_geathers': idGeathers,
      'id_customer': idCustomer,
      'name_customer': nameCustomer,
      'address_customer': addressCustomer,
      'mod_type': modType,
      'notes': notes,
      'request_date': requestDate,
      'status': status,
      'sync_status': syncStatus,
    };
  }
}
