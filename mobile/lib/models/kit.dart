class Kit {
  const Kit({
    required this.id,
    required this.kitCode,
    required this.batchNumber,
    required this.expiryDate,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String kitCode;
  final String? batchNumber;
  final DateTime? expiryDate;
  final String status;
  final DateTime? createdAt;

  factory Kit.fromMap(Map<String, dynamic> map) {
    return Kit(
      id: map['id'] as String? ?? '',
      kitCode: map['kit_code'] as String? ?? '',
      batchNumber: map['batch_number'] as String?,
      expiryDate: _parseDate(map['expiry_date']),
      status: map['status'] as String? ?? 'INACTIVE',
      createdAt: _parseDate(map['created_at']),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is DateTime) {
      return value.toLocal();
    }
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }
}
