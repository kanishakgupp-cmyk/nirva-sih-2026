from datetime import datetime, timezone
from uuid import uuid4

import pytest

from app.services.evidence_integrity_service import EvidenceIntegrityService


@pytest.fixture
def record() -> dict:
    return {
        "id": str(uuid4()),
        "test_id": str(uuid4()),
        "operator_id": str(uuid4()),
        "captured_at": datetime(2026, 9, 12, tzinfo=timezone.utc).isoformat(),
        "image_sha256": "a" * 64,
        "latitude": 12.3,
        "longitude": 45.6,
        "gps_accuracy": 4.2,
    }


def test_same_canonical_record_has_same_hash(record) -> None:
    service = EvidenceIntegrityService()
    assert service.record_hash(record, None) == service.record_hash(dict(record), None)


def test_changed_canonical_record_changes_hash(record) -> None:
    service = EvidenceIntegrityService()
    changed = {**record, "image_sha256": "b" * 64}
    assert service.record_hash(record, None) != service.record_hash(changed, None)


def test_valid_chain_link_verifies(record) -> None:
    service = EvidenceIntegrityService()
    record["previous_record_hash"] = None
    record["record_hash"] = service.record_hash(record, None)
    assert service.verify_record(record, None)


def test_broken_chain_fails(record) -> None:
    service = EvidenceIntegrityService()
    record["previous_record_hash"] = "wrong"
    record["record_hash"] = service.record_hash(record, "previous")
    assert not service.verify_record(record, "previous")
