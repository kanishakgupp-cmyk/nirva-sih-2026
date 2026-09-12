from uuid import uuid4

from fastapi.testclient import TestClient

from app.api.v1.evidence import get_evidence_service
from app.core.auth import get_current_user_id
from app.main import app


class UnusedEvidenceService:
    def get_owned(self, evidence_id: str, user_id: str) -> dict:
        raise AssertionError("authenticated dependency should be required")


def test_evidence_endpoints_require_authentication() -> None:
    app.dependency_overrides[get_evidence_service] = lambda: UnusedEvidenceService()
    try:
        response = TestClient(app).get(f"/api/v1/evidence/{uuid4()}")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 401
    assert response.json()["detail"] == "A bearer token is required."


def test_owned_evidence_response_preserves_capture_fields() -> None:
    evidence_id = uuid4()
    test_id = uuid4()
    operator_id = uuid4()

    class OwnedEvidenceService:
        def get_owned(self, evidence_id: str, user_id: str) -> dict:
            return {
                "id": str(evidence_id),
                "test_id": str(test_id),
                "operator_id": str(operator_id),
                "evidence_status": "CAPTURED",
                "created_at": "2026-09-12T10:00:00Z",
                "legal_label": "INDICATIVE ONLY",
            }

    app.dependency_overrides[get_current_user_id] = lambda: str(operator_id)
    app.dependency_overrides[get_evidence_service] = lambda: OwnedEvidenceService()
    try:
        response = TestClient(app).get(f"/api/v1/evidence/{evidence_id}")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json()["id"] == str(evidence_id)
    assert response.json()["test_id"] == str(test_id)
