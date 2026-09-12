from uuid import uuid4

from fastapi.testclient import TestClient

from app.api.v1.evidence import get_evidence_service
from app.core.auth import get_current_user_id
from app.main import app


class UnusedEvidenceService:
    def get_owned(self, evidence_id: str, user_id: str) -> dict:
        raise AssertionError("authenticated dependency should be required")


def test_evidence_endpoints_require_authentication() -> None:
    previous_auth = app.dependency_overrides.pop(get_current_user_id, None)
    previous_service = app.dependency_overrides.get(get_evidence_service)
    app.dependency_overrides[get_evidence_service] = lambda: UnusedEvidenceService()
    try:
        response = TestClient(app).get(f"/api/v1/evidence/{uuid4()}")
    finally:
        app.dependency_overrides.pop(get_evidence_service, None)
        if previous_service is not None:
            app.dependency_overrides[get_evidence_service] = previous_service
        if previous_auth is not None:
            app.dependency_overrides[get_current_user_id] = previous_auth

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

    previous_auth = app.dependency_overrides.get(get_current_user_id)
    previous_service = app.dependency_overrides.get(get_evidence_service)
    app.dependency_overrides[get_current_user_id] = lambda: str(operator_id)
    app.dependency_overrides[get_evidence_service] = lambda: OwnedEvidenceService()
    try:
        response = TestClient(app).get(f"/api/v1/evidence/{evidence_id}")
    finally:
        if previous_auth is None:
            app.dependency_overrides.pop(get_current_user_id, None)
        else:
            app.dependency_overrides[get_current_user_id] = previous_auth
        if previous_service is None:
            app.dependency_overrides.pop(get_evidence_service, None)
        else:
            app.dependency_overrides[get_evidence_service] = previous_service

    assert response.status_code == 200
    assert response.json()["id"] == str(evidence_id)
    assert response.json()["test_id"] == str(test_id)
