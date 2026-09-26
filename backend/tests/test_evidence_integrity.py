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


def test_repeated_client_operation_returns_existing_evidence() -> None:
    test_id = str(uuid4())
    operator_id = str(uuid4())
    operation_id = "op-repeatable-1"
    evidence_id = str(uuid4())
    upload_count = 0
    inserted = False

    class Query:
        def __init__(self, table: str):
            self.table = table
            self.mode = "select"

        def select(self, *_args, **_kwargs):
            self.mode = "select"
            return self

        def eq(self, *_args):
            return self

        def lt(self, *_args):
            return self

        def order(self, *_args, **_kwargs):
            return self

        def limit(self, *_args):
            return self

        def insert(self, _payload):
            nonlocal inserted
            inserted = True
            self.mode = "insert"
            return self

        def update(self, _payload):
            return self

        def execute(self):
            if self.table == "evidence_records":
                if inserted:
                    return SimpleNamespace(data=[{
                        "id": evidence_id,
                        "test_id": test_id,
                        "operator_id": operator_id,
                        "image_sha256": "a" * 64,
                        "evidence_status": "CAPTURED",
                    }])
                return SimpleNamespace(data=[])
            if self.table == "test_sessions":
                return SimpleNamespace(data=[{"id": test_id, "status": "RUNNING"}])
            return SimpleNamespace(data=[])

    class StorageBucket:
        def upload(self, *_args, **_kwargs):
            nonlocal upload_count
            upload_count += 1
            return SimpleNamespace()

    class Storage:
        def from_(self, _bucket):
            return StorageBucket()

    class Client:
        storage = Storage()

        def table(self, table):
            return Query(table)

    service = EvidenceAnalysisService(Client())
    arguments = {
        "user_id": operator_id,
        "test_id": test_id,
        "image_bytes": b"demo-image",
        "captured_at": datetime.now(timezone.utc),
        "latitude": None,
        "longitude": None,
        "gps_accuracy": None,
        "image_quality_score": 80,
        "blur_score": 75,
        "brightness_score": 78,
        "client_operation_id": operation_id,
    }

    first = service.create_evidence(**arguments)
    second = service.create_evidence(**arguments)

    assert first["id"] == evidence_id
    assert second["id"] == evidence_id
    assert upload_count == 1


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


def test_verification_report_valid_chain_and_components() -> None:
    service = EvidenceIntegrityService()
    image_bytes = b"demo-image"
    record = {
        "id": str(uuid4()),
        "test_id": str(uuid4()),
        "operator_id": str(uuid4()),
        "captured_at": datetime(2026, 9, 12, tzinfo=timezone.utc).isoformat(),
        "image_sha256": __import__("hashlib").sha256(image_bytes).hexdigest(),
        "latitude": 12.3,
        "longitude": 45.6,
        "gps_accuracy": 4.2,
        "previous_record_hash": None,
    }
    record["record_hash"] = service.record_hash(record, None)
    report = service.verification_report(record, None, image_bytes)

    assert report["image_hash_verified"] is True
    assert report["record_hash_verified"] is True
    assert report["previous_record_link_verified"] is True
    assert report["chain_verified"] is True
    assert report["status"] == "INTEGRITY VERIFIED"


def test_verification_report_detects_hash_and_previous_link_failures() -> None:
    service = EvidenceIntegrityService()
    image_bytes = b"demo-image"
    record = {
        "id": str(uuid4()),
        "test_id": str(uuid4()),
        "operator_id": str(uuid4()),
        "captured_at": datetime(2026, 9, 12, tzinfo=timezone.utc).isoformat(),
        "image_sha256": __import__("hashlib").sha256(image_bytes).hexdigest(),
        "latitude": 12.3,
        "longitude": 45.6,
        "gps_accuracy": 4.2,
        "previous_record_hash": "wrong-previous-hash",
    }
    record["record_hash"] = service.record_hash(record, "different-previous")
    report = service.verification_report(record, "previous-hash", b"different-image")

    assert report["image_hash_verified"] is False
    assert report["record_hash_verified"] is False
    assert report["previous_record_link_verified"] is False
    assert report["chain_verified"] is False
    assert report["status"] == "INTEGRITY VERIFICATION FAILED"


def test_verification_report_tracks_signature_state() -> None:
    service = EvidenceIntegrityService()
    record = {
        "id": str(uuid4()),
        "signature": "demo-signature",
        "signature_algorithm": "RSA-PSS",
        "key_id": "kid-demo-1",
    }

    assert service.verify_signature(record) == {"signature_valid": False, "signature_status": "UNVERIFIED"}

    no_signature = {"signature": None}
    assert service.verify_signature(no_signature) == {"signature_valid": None, "signature_status": "NOT_AVAILABLE"}
