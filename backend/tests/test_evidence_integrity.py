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
            self.status_filter = None

        def select(self, *_args):
            return self

        def eq(self, *_args):
            if _args[0] == "status":
                self.status_filter = _args[1]
            return self

        def update(self, payload):
            self.payload = payload
            return self

        def insert(self, payload):
            self.payload = payload
            return self

        def execute(self):
            if self.table == "test_sessions":
                if self.payload:
                    return SimpleNamespace(data=[{"id": test_id, "status": "CAPTURED"}])
                return SimpleNamespace(data=[{"id": test_id, "status": "RUNNING"}])
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


def test_first_capture_transitions_running_session_to_captured() -> None:
    test_id = str(uuid4())
    operator_id = str(uuid4())
    session = {"id": test_id, "status": "RUNNING"}

    class Query:
        def __init__(self, table: str):
            self.table = table
            self.payload = None

        def select(self, *_args):
            return self

        def eq(self, *_args):
            return self

        def update(self, payload):
            self.payload = payload
            session.update(payload)
            return self

        def insert(self, payload):
            self.payload = payload
            return self

        def execute(self):
            if self.table == "test_sessions":
                return SimpleNamespace(data=[session])
            if self.table == "evidence_records":
                return SimpleNamespace(data=[{
                    "id": str(uuid4()),
                    "test_id": test_id,
                    "operator_id": operator_id,
                    "image_sha256": "a" * 64,
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
    service.create_evidence(
        user_id=operator_id,
        test_id=test_id,
        image_bytes=b"demo-image",
        captured_at=datetime.now(timezone.utc),
        latitude=12.3,
        longitude=45.6,
        gps_accuracy=4.2,
        image_quality_score=80,
        blur_score=75,
        brightness_score=78,
    )

    assert session["status"] == "CAPTURED"


@pytest.mark.parametrize("initial_status", ["CREATED", "CAPTURED"])
def test_capture_rejects_sessions_that_are_not_running(initial_status: str) -> None:
    test_id = str(uuid4())
    operator_id = str(uuid4())

    class Query:
        def select(self, *_args):
            return self

        def eq(self, *_args):
            return self

        def execute(self):
            return SimpleNamespace(data=[{"id": test_id, "status": initial_status}])

    class Client:
        def table(self, _table):
            return Query()

    with pytest.raises(Exception, match="RUNNING"):
        EvidenceAnalysisService(Client()).create_evidence(
            user_id=operator_id,
            test_id=test_id,
            image_bytes=b"demo-image",
            captured_at=datetime.now(timezone.utc),
            latitude=12.3,
            longitude=45.6,
            gps_accuracy=4.2,
            image_quality_score=80,
            blur_score=75,
            brightness_score=78,
        )


def test_capture_rejects_non_running_session() -> None:
    test_id = str(uuid4())
    operator_id = str(uuid4())

    class Query:
        def select(self, *_args):
            return self

        def eq(self, *_args):
            return self

        def execute(self):
            return SimpleNamespace(data=[{"id": test_id, "status": "FINALIZED"}])

    class Client:
        def table(self, _table):
            return Query()

    with pytest.raises(Exception, match="RUNNING"):
        EvidenceAnalysisService(Client()).create_evidence(
            user_id=operator_id,
            test_id=test_id,
            image_bytes=b"demo-image",
            captured_at=datetime.now(timezone.utc),
            latitude=12.3,
            longitude=45.6,
            gps_accuracy=4.2,
            image_quality_score=80,
            blur_score=75,
            brightness_score=78,
        )
