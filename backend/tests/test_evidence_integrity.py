from datetime import datetime, timezone
from types import SimpleNamespace
from uuid import uuid4

import pytest

from app.services.evidence_integrity_service import EvidenceIntegrityService
from app.services.analysis_service import EvidenceAnalysisService


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


def test_create_evidence_uses_execute_rows_without_singleton_methods() -> None:
    test_id = str(uuid4())
    operator_id = str(uuid4())

    class Query:
        def __init__(self, table: str):
            self.table = table
            self.payload = None

        def select(self, *_args):
            return self

        def eq(self, *_args):
            return self

        def insert(self, payload):
            self.payload = payload
            return self

        def execute(self):
            if self.table == "test_sessions":
                return SimpleNamespace(data=[{"id": test_id}])
            if self.table == "evidence_records":
                return SimpleNamespace(data=[{
                    "id": str(uuid4()),
                    "test_id": test_id,
                    "operator_id": operator_id,
                    "image_sha256": self.payload["image_sha256"],
                    "evidence_status": "CAPTURED",
                }])
            return SimpleNamespace(data=[])

    class StorageBucket:
        def upload(self, *_args, **_kwargs):
            return SimpleNamespace()

    class Storage:
        def from_(self, _bucket):
            return StorageBucket()

    class Client:
        storage = Storage()

        def table(self, table):
            return Query(table)

    service = EvidenceAnalysisService(Client())
    result = service.create_evidence(
        user_id=operator_id,
        test_id=test_id,
        image_bytes=b"demo-image",
        captured_at=datetime.now(timezone.utc),
        latitude=None,
        longitude=None,
        gps_accuracy=None,
        image_quality_score=80,
        blur_score=75,
        brightness_score=78,
    )

    assert result["test_id"] == test_id
    assert len(result["image_sha256"]) == 64
