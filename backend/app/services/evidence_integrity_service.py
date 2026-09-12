import hashlib
import json
from typing import Any


class EvidenceIntegrityService:
    """Deterministic SHA-256 canonicalization and hash-chain helpers."""

    @staticmethod
    def canonical_record_data(record: dict[str, Any]) -> str:
        fields = {
            "captured_at": record.get("captured_at"),
            "evidence_id": record.get("id"),
            "image_sha256": record.get("image_sha256"),
            "latitude": record.get("latitude"),
            "longitude": record.get("longitude"),
            "operator_id": record.get("operator_id"),
            "test_id": record.get("test_id"),
            "gps_accuracy": record.get("gps_accuracy"),
        }
        return json.dumps(fields, sort_keys=True, separators=(",", ":"), ensure_ascii=True)

    @classmethod
    def record_hash(cls, record: dict[str, Any], previous_record_hash: str | None) -> str:
        canonical = cls.canonical_record_data(record)
        chain_input = f"{canonical}|{previous_record_hash or ''}".encode("utf-8")
        return hashlib.sha256(chain_input).hexdigest()

    @classmethod
    def verify_record(cls, record: dict[str, Any], previous_record_hash: str | None) -> bool:
        expected = cls.record_hash(record, previous_record_hash)
        return record.get("record_hash") == expected and record.get("previous_record_hash") == previous_record_hash
