import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class EvidenceHashService {
  const EvidenceHashService();

  String sha256Bytes(List<int> bytes) {
    return sha256.convert(bytes).toString();
  }

  Uint8List utf8Bytes(String value) => Uint8List.fromList(utf8.encode(value));
}
