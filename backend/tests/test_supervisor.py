from datetime import datetime, timezone
from types import SimpleNamespace
from uuid import uuid4

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient

from app.api.v1.supervisor import get_supervisor_service
from app.core.auth import get_current_user_id, require_supervisor
from app.main import app
from app.schemas.supervisor import SupervisorOverview
from app.services.supervisor_service import (
    SupervisorEvidenceNotFoundError,
    SupervisorReviewStateError,
    SupervisorService,
)


class FakeSupervisorService:
    def __init__(self, evidence: dict):
        self.evidence = evidence
        self.last_action = None
        self.last_reason = None
        self.last_search = None
        self.last_status = None

    def overview(self) -> dict:
        return {
            "total_cases": 12,
            "total_test_sessions": 8,
            "total_evidence_records": 6,
            "pending_review": 3,
            "analyzed_evidence": 5,
            "finalized_evidence": 4,
            "flagged_evidence": 1,
            "returned_evidence": 1,
        }

    def list_evidence(self, page: int, page_size: int, search: str | None, status: str | None) -> dict:
        self.last_search = search
        self.last_status = status
        valid_statuses = {"PENDING", "APPROVED", "FLAGGED", "RETURNED"}
        if status and status != "ALL" and status not in valid_statuses:
            return {"items": [], "page": page, "page_size": page_size, "total": 0}
        if search == "non-matching-query":
            return {"items": [], "page": page, "page_size": page_size, "total": 0}

        return {
            "items": [{
                "id": self.evidence["id"],
                "test_id": self.evidence["test_id"],
                "test_number": self.evidence.get("test_number", "NIRVA-TEST-001"),
                "case_number": self.evidence.get("case_number", "CASE-001"),
                "operator": self.evidence.get("operator", "Officer Test"),
                "captured_at": self.evidence.get("captured_at"),
                "evidence_status": self.evidence.get("evidence_status", "FINALIZED"),
                "review_status": self.evidence.get("review_status", "PENDING"),
                "review_reason": self.evidence.get("review_reason"),
                "analysis_result": self.evidence.get("analysis_result", "DEMO_CLASS_A"),
                "confidence": self.evidence.get("confidence", 0.86),
                "integrity_status": "CHAIN VALID",
                "finalized": True,
            }],
            "page": page,
            "page_size": page_size,
            "total": 1,
        }

    def get_evidence(self, evidence_id: str) -> dict:
        if str(evidence_id) != str(self.evidence["id"]):
            raise SupervisorEvidenceNotFoundError
        return {
            **self.evidence,
            "test_number": "NIRVA-TEST-001",
            "case_number": "CASE-001",
            "operator": "Officer Test",
            "integrity_status": "CHAIN VALID",
            "finalized": True,
            "audit_history": [
                {"event_type": "IMAGE_CAPTURED", "created_at": "2026-09-12T10:00:00Z"},
                {"event_type": "EVIDENCE_FINALIZED", "created_at": "2026-09-12T10:05:00Z"},
            ],
        }

    def review(self, evidence_id: str, supervisor_id: str, action: str, reason: str | None) -> dict:
        if str(evidence_id) != str(self.evidence["id"]):
            raise SupervisorEvidenceNotFoundError
        if self.evidence.get("review_status") == "APPROVED" and action in {"FLAG", "RETURN"}:
            raise SupervisorReviewStateError(f"Evidence cannot be {action.lower()} from APPROVED.")
        self.last_action = action
        self.last_reason = reason
        new_status = {
            "APPROVE": "APPROVED",
            "FLAG": "FLAGGED",
            "RETURN": "RETURNED",
        }[action]
        self.evidence["review_status"] = new_status
        self.evidence["review_reason"] = reason
        self.evidence["reviewed_by"] = supervisor_id
        self.evidence["reviewed_at"] = datetime.now(timezone.utc).isoformat()
        return self.get_evidence(evidence_id)


@pytest.fixture
def supervisor_user_id() -> str:
    return str(uuid4())


@pytest.fixture
def officer_user_id() -> str:
    return str(uuid4())


@pytest.fixture
def sample_evidence(supervisor_user_id) -> dict:
    evidence_id = str(uuid4())
    test_id = str(uuid4())
    operator_id = str(uuid4())
    return {
        "id": evidence_id,
        "test_id": test_id,
        "operator_id": operator_id,
        "captured_at": datetime.now(timezone.utc).isoformat(),
        "evidence_status": "FINALIZED",
        "review_status": "PENDING",
        "review_reason": None,
        "analysis_result": "DEMO_CLASS_A",
        "confidence": 0.86,
        "image_sha256": "a" * 64,
        "legal_label": "INDICATIVE ONLY - LABORATORY CONFIRMATION REQUIRED",
        "record_hash": "b" * 64,
    }


def test_unauthenticated_supervisor_endpoint_returns_401() -> None:
    client = TestClient(app)
    response = client.get("/api/v1/supervisor/overview")
    assert response.status_code == 401
    assert "detail" in response.json()


def test_require_supervisor_blocks_officer(officer_user_id, monkeypatch) -> None:
    class MockTable:
        def select(self, *_):
            return self

        def eq(self, *_):
            return self

        def maybe_single(self):
            return self

        def execute(self):
            return SimpleNamespace(data={"role": "OFFICER"})

    class MockClient:
        def table(self, _):
            return MockTable()

    from app.db import client as db_client
    monkeypatch.setattr(db_client, "get_configured_supabase_client", lambda: MockClient())

    with pytest.raises(HTTPException) as err:
        require_supervisor(user_id=officer_user_id)

    assert err.value.status_code == 403
    assert "Supervisor access required." in err.value.detail


def test_require_supervisor_allows_supervisor_and_admin(supervisor_user_id, monkeypatch) -> None:
    class MockTable:
        def __init__(self, role: str):
            self._role = role

        def select(self, *_):
            return self

        def eq(self, *_):
            return self

        def maybe_single(self):
            return self

        def execute(self):
            return SimpleNamespace(data={"role": self._role})

    from app.db import client as db_client

    monkeypatch.setattr(db_client, "get_configured_supabase_client", lambda: SimpleNamespace(table=lambda _: MockTable("SUPERVISOR")))
    assert require_supervisor(user_id=supervisor_user_id) == supervisor_user_id

    monkeypatch.setattr(db_client, "get_configured_supabase_client", lambda: SimpleNamespace(table=lambda _: MockTable("ADMIN")))
    assert require_supervisor(user_id=supervisor_user_id) == supervisor_user_id


def test_supervisor_overview_returns_metrics(supervisor_user_id, sample_evidence) -> None:
    fake_service = FakeSupervisorService(sample_evidence)
    app.dependency_overrides[require_supervisor] = lambda: supervisor_user_id
    app.dependency_overrides[get_supervisor_service] = lambda: fake_service
    client = TestClient(app)

    try:
        response = client.get("/api/v1/supervisor/overview")
        assert response.status_code == 200
        data = response.json()
        assert data["total_cases"] == 12
        assert data["total_test_sessions"] == 8
        assert data["total_evidence_records"] == 6
        assert data["pending_review"] == 3
        assert data["flagged_evidence"] == 1
        assert data["returned_evidence"] == 1
    finally:
        app.dependency_overrides.pop(require_supervisor, None)
        app.dependency_overrides.pop(get_supervisor_service, None)


def test_supervisor_evidence_queue_pagination_and_filters(supervisor_user_id, sample_evidence) -> None:
    fake_service = FakeSupervisorService(sample_evidence)
    app.dependency_overrides[require_supervisor] = lambda: supervisor_user_id
    app.dependency_overrides[get_supervisor_service] = lambda: fake_service
    client = TestClient(app)

    try:
        response = client.get("/api/v1/supervisor/evidence?page=1&page_size=20&status=PENDING")
        assert response.status_code == 200
        data = response.json()
        assert data["page"] == 1
        assert data["page_size"] == 20
        assert data["total"] == 1
        assert len(data["items"]) == 1
        assert fake_service.last_status == "PENDING"

        # Test invalid status filter
        response = client.get("/api/v1/supervisor/evidence?status=INVALID_STATUS")
        assert response.status_code == 200
        assert response.json()["items"] == []

        # Test safe search with non-matching query
        response = client.get("/api/v1/supervisor/evidence?search=non-matching-query")
        assert response.status_code == 200
        assert response.json()["items"] == []
    finally:
        app.dependency_overrides.pop(require_supervisor, None)
        app.dependency_overrides.pop(get_supervisor_service, None)


def test_supervisor_evidence_detail_and_not_found(supervisor_user_id, sample_evidence) -> None:
    fake_service = FakeSupervisorService(sample_evidence)
    app.dependency_overrides[require_supervisor] = lambda: supervisor_user_id
    app.dependency_overrides[get_supervisor_service] = lambda: fake_service
    client = TestClient(app)

    try:
        response = client.get(f"/api/v1/supervisor/evidence/{sample_evidence['id']}")
        assert response.status_code == 200
        assert response.json()["id"] == sample_evidence["id"]
        assert len(response.json()["audit_history"]) == 2

        response = client.get(f"/api/v1/supervisor/evidence/{uuid4()}")
        assert response.status_code == 404
        assert response.json()["detail"] == "Evidence not found."
    finally:
        app.dependency_overrides.pop(require_supervisor, None)
        app.dependency_overrides.pop(get_supervisor_service, None)


def test_supervisor_review_actions_and_reason_persistence(supervisor_user_id, sample_evidence) -> None:
    fake_service = FakeSupervisorService(dict(sample_evidence))
    app.dependency_overrides[require_supervisor] = lambda: supervisor_user_id
    app.dependency_overrides[get_supervisor_service] = lambda: fake_service
    client = TestClient(app)

    try:
        # 1. Flag with reason
        response = client.post(
            f"/api/v1/supervisor/evidence/{sample_evidence['id']}/flag",
            json={"reason": "Sample card reflection needs review"},
        )
        assert response.status_code == 200
        assert response.json()["review_status"] == "FLAGGED"
        assert response.json()["review_reason"] == "Sample card reflection needs review"
        assert fake_service.last_action == "FLAG"
        assert fake_service.last_reason == "Sample card reflection needs review"

        # 2. Return with reason
        response = client.post(
            f"/api/v1/supervisor/evidence/{sample_evidence['id']}/return",
            json={"reason": "Please recapture with proper lighting"},
        )
        assert response.status_code == 200
        assert response.json()["review_status"] == "RETURNED"
        assert response.json()["review_reason"] == "Please recapture with proper lighting"

        # 3. Approve without reason
        response = client.post(
            f"/api/v1/supervisor/evidence/{sample_evidence['id']}/approve",
            json={},
        )
        assert response.status_code == 200
        assert response.json()["review_status"] == "APPROVED"

        # 4. Invalid review action
        response = client.post(
            f"/api/v1/supervisor/evidence/{sample_evidence['id']}/unsupported_action",
            json={},
        )
        assert response.status_code == 422

        # 5. Invalid transition from APPROVED to FLAGGED
        response = client.post(
            f"/api/v1/supervisor/evidence/{sample_evidence['id']}/flag",
            json={"reason": "Late flag"},
        )
        assert response.status_code == 409
        assert "Evidence cannot be flag from APPROVED" in response.json()["detail"]
    finally:
        app.dependency_overrides.pop(require_supervisor, None)
        app.dependency_overrides.pop(get_supervisor_service, None)


def test_supervisor_service_review_state_machine() -> None:
    evidence_id = str(uuid4())
    test_id = str(uuid4())
    supervisor_id = str(uuid4())

    record = {
        "id": evidence_id,
        "test_id": test_id,
        "operator_id": str(uuid4()),
        "review_status": "PENDING",
        "review_reason": None,
        "captured_at": datetime.now(timezone.utc).isoformat(),
        "evidence_status": "FINALIZED",
    }
    audit_log = []

    class MockQuery:
        def __init__(self, table: str):
            self.table = table
            self.payload = None

        def select(self, *_args, **_kwargs):
            return self

        def eq(self, key, val):
            return self

        def order(self, *_args, **_kwargs):
            return self

        def maybe_single(self):
            return self

        def update(self, payload):
            self.payload = payload
            record.update(payload)
            return self

        def insert(self, payload):
            audit_log.append(payload)
            return self

        def execute(self):
            if self.table == "evidence_records":
                return SimpleNamespace(data=[record])
            if self.table == "audit_events":
                return SimpleNamespace(data=audit_log)
            if self.table == "test_sessions":
                return SimpleNamespace(data={"test_number": "NIRVA-TEST-001", "case_id": "case-1"})
            if self.table == "cases":
                return SimpleNamespace(data={"case_number": "CASE-001"})
            if self.table == "profiles":
                return SimpleNamespace(data={"display_name": "Test Officer"})
            return SimpleNamespace(data=[])

    class MockStorage:
        def from_(self, _):
            return SimpleNamespace(create_signed_url=lambda path, _: {"signedURL": f"https://example.com/{path}"})

    class MockClient:
        storage = MockStorage()

        def table(self, table_name: str):
            return MockQuery(table_name)

    service = SupervisorService(MockClient())

    # 1. PENDING -> FLAGGED with reason
    result = service.review(evidence_id, supervisor_id, "FLAG", "Lighting check required")
    assert result["review_status"] == "FLAGGED"
    assert result["review_reason"] == "Lighting check required"
    assert audit_log[-1]["event_type"] == "SUPERVISOR_FLAGGED"
    assert audit_log[-1]["event_data"]["reason"] == "Lighting check required"

    # 2. FLAGGED -> RETURN
    result = service.review(evidence_id, supervisor_id, "RETURN", "Retake requested")
    assert result["review_status"] == "RETURNED"
    assert result["review_reason"] == "Retake requested"
    assert audit_log[-1]["event_type"] == "SUPERVISOR_RETURNED"

    # 3. RETURNED -> APPROVE
    result = service.review(evidence_id, supervisor_id, "APPROVE", None)
    assert result["review_status"] == "APPROVED"
    assert audit_log[-1]["event_type"] == "SUPERVISOR_APPROVED"

    # 4. APPROVED -> invalid transition
    with pytest.raises(SupervisorReviewStateError):
        service.review(evidence_id, supervisor_id, "FLAG", "Cannot flag approved")
