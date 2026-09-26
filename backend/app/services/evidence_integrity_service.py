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

    @classmethod
    def verify_image_hash(cls, record: dict[str, Any], image_bytes: bytes | None) -> bool | None:
        stored_hash = (record.get("image_sha256") or "").strip()
        if not stored_hash:
            return None
        if image_bytes is None:
            return None
        return hashlib.sha256(image_bytes).hexdigest() == stored_hash

    @classmethod
    def verify_previous_link(cls, record: dict[str, Any], previous_record_hash: str | None) -> bool:
        return bool(record.get("previous_record_hash") == previous_record_hash)

    @classmethod
    def verify_signature(cls, record: dict[str, Any]) -> dict[str, Any]:
        signature = record.get("signature")
        if signature in (None, ""):
            return {"signature_valid": None, "signature_status": "NOT_AVAILABLE"}

        algorithm = (record.get("signature_algorithm") or "").upper()
        key_id = record.get("key_id")
        if algorithm in {"", "DEMO", "DEMONSTRATION"} or not key_id:
            return {"signature_valid": False, "signature_status": "DEMONSTRATION_ONLY"}

        # No server-side signing key or trust chain is configured in this repository.
        # The application intentionally treats signatures as a demonstration boundary.
        return {"signature_valid": False, "signature_status": "UNVERIFIED"}

    @classmethod
    def verification_report(cls, record: dict[str, Any], previous_record_hash: str | None, image_bytes: bytes | None) -> dict[str, Any]:
        image_hash_valid = cls.verify_image_hash(record, image_bytes)
        record_hash_valid = cls.verify_record(record, previous_record_hash)
        previous_record_link_valid = cls.verify_previous_link(record, previous_record_hash)
        signature = cls.verify_signature(record)
        chain_valid = bool(image_hash_valid is True and record_hash_valid and previous_record_link_valid)
        return {
            "image_hash_verified": image_hash_valid,
            "record_hash_verified": record_hash_valid,
            "previous_record_link_verified": previous_record_link_valid,
            "signature_verified": signature["signature_valid"],
            "signature_status": signature["signature_status"],
            "chain_verified": chain_valid,
            "status": "INTEGRITY VERIFIED" if chain_valid else "INTEGRITY VERIFICATION FAILED",
            "previous_record_hash": previous_record_hash,
            "record_hash": record.get("record_hash"),
            "image_sha256": record.get("image_sha256"),
        }
