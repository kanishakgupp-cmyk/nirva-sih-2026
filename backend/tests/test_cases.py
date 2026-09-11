from datetime import datetime, timezone
from uuid import uuid4

from fastapi.testclient import TestClient

from app.api.v1.cases import get_case_service
from app.core.auth import get_current_user_id
from app.main import app
from app.services.case_service import CaseNotFoundError, DuplicateCaseNumberError


class FakeCaseService:
    def __init__(self, case: dict):
        self.case = case
        self.last_user_id = None

    def list_cases(self, user_id: str) -> list[dict]:
        self.last_user_id = user_id
        return [self.case]

    def create_case(self, user_id: str, case_number: str, title: str, description: str | None) -> dict:
        self.last_user_id = user_id
        return {**self.case, "case_number": case_number, "title": title, "description": description}

    def get_case(self, user_id: str, case_id: str) -> dict:
        self.last_user_id = user_id
        if case_id != self.case["id"]:
            raise CaseNotFoundError
        return self.case


user_id = str(uuid4())
case = {
    "id": str(uuid4()),
    "case_number": "CASE-001",
    "title": "Sample case",
    "description": "Description",
    "created_by": user_id,
    "created_at": datetime.now(timezone.utc).isoformat(),
}
fake_service = FakeCaseService(case)
app.dependency_overrides[get_current_user_id] = lambda: user_id
app.dependency_overrides[get_case_service] = lambda: fake_service
client = TestClient(app)


def teardown_module() -> None:
    app.dependency_overrides.clear()


def test_case_list_is_authenticated_and_scoped() -> None:
    response = client.get("/api/v1/cases")

    assert response.status_code == 200
    assert response.json()[0]["created_by"] == user_id
    assert fake_service.last_user_id == user_id


def test_case_creation_uses_verified_user_identity() -> None:
    response = client.post(
        "/api/v1/cases",
        json={
            "case_number": "CASE-002",
            "title": "Created case",
            "description": None,
            "created_by": str(uuid4()),
        },
    )

    assert response.status_code == 201
    assert response.json()["created_by"] == user_id
    assert fake_service.last_user_id == user_id


def test_case_details_returns_owned_case() -> None:
    response = client.get(f"/api/v1/cases/{case['id']}")

    assert response.status_code == 200
    assert response.json()["id"] == case["id"]


def test_cross_user_or_missing_case_is_not_found() -> None:
    response = client.get(f"/api/v1/cases/{uuid4()}")

    assert response.status_code == 404
    assert response.json()["detail"] == "Case not found."


def test_duplicate_case_number_is_conflict() -> None:
    class DuplicateService(FakeCaseService):
        def create_case(self, *args, **kwargs) -> dict:
            raise DuplicateCaseNumberError

    app.dependency_overrides[get_case_service] = lambda: DuplicateService(case)
    response = client.post(
        "/api/v1/cases",
        json={"case_number": "CASE-001", "title": "Duplicate"},
    )

    assert response.status_code == 409
    assert response.json()["detail"] == "Case number already exists."
    app.dependency_overrides[get_case_service] = lambda: fake_service


def test_missing_authentication_is_rejected() -> None:
    app.dependency_overrides.pop(get_current_user_id)
    response = client.get("/api/v1/cases")

    assert response.status_code == 401
    app.dependency_overrides[get_current_user_id] = lambda: user_id