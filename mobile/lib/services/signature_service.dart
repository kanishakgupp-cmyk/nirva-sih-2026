abstract interface class EvidenceSignatureService {
  String get mode;

  String? get algorithm;

  String? get keyId;

  Future<String?> sign(List<int> canonicalBytes);
}

/// Web demonstrator boundary. It deliberately does not fabricate a signature.
class DemonstrationSignatureService implements EvidenceSignatureService {
  const DemonstrationSignatureService();

  @override
  String get mode => 'SIGNATURE MODE: DEMONSTRATION';

  @override
  String? get algorithm => null;

  @override
  String? get keyId => null;

  @override
  Future<String?> sign(List<int> canonicalBytes) async => null;
}
