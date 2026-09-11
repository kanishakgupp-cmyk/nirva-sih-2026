class CaseModel {
  const CaseModel({
    required this.id,
    required this.caseNumber,
    required this.title,
    required this.description,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String caseNumber;
  final String title;
  final String? description;
  final String createdBy;
  final DateTime createdAt;

  factory CaseModel.fromMap(Map<String, dynamic> map) {
    return CaseModel(
      id: map['id'] as String? ?? '',
      caseNumber: map['case_number'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      createdBy: map['created_by'] as String? ?? '',
      createdAt: _parseDateTime(map['created_at']),
    );
  }

  static DateTime _parseDateTime(Object? value) {
    if (value is DateTime) {
      return value.toLocal();
    }
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
