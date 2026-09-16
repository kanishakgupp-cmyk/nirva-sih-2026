from collections.abc import Callable
from typing import Any
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from postgrest.exceptions import APIError

from app.core.auth import require_supervisor
from app.db.client import get_configured_supabase_client
from app.schemas.supervisor import SupervisorEvidenceDetail, SupervisorEvidencePage, SupervisorOverview, SupervisorReviewAction
from app.services.supervisor_service import (
    SupervisorEvidenceNotFoundError,
    SupervisorReasonRequiredError,
    SupervisorReviewStateError,
    SupervisorService,
)

router = APIRouter(prefix="/supervisor", tags=["supervisor"])

# PostgREST/PostgreSQL codes raised when a migration has not been applied.
_SCHEMA_NOT_READY_CODES = {"42703", "42P01", "PGRST204", "PGRST205"}


def get_supervisor_service() -> SupervisorService:
    return SupervisorService(get_configured_supabase_client())


def _raise_schema_not_ready(error: APIError) -> None:
    raise HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail=(
            "Supervisor review schema is not available on this Supabase project. "
            "Apply supabase/migrations/006_supervisor_review.sql and "
            "supabase/migrations/007_supervisor_hardening.sql."
        ),
    ) from error


def _run(call: Callable[[], Any]) -> Any:
    try:
        return call()
    except APIError as error:
        if getattr(error, "code", None) in _SCHEMA_NOT_READY_CODES:
            _raise_schema_not_ready(error)
        raise


@router.get("/overview", response_model=SupervisorOverview)
def overview(_: str = Depends(require_supervisor), service: SupervisorService = Depends(get_supervisor_service)):
    return _run(service.overview)


@router.get("/evidence", response_model=SupervisorEvidencePage)
def evidence_queue(
    page: int = Query(1, ge=1), page_size: int = Query(20, ge=1, le=100),
    search: str | None = Query(None, max_length=100), status: str | None = Query(None),
    _: str = Depends(require_supervisor), service: SupervisorService = Depends(get_supervisor_service),
):
    return _run(lambda: service.list_evidence(page, page_size, search, status))


@router.get("/evidence/{evidence_id}", response_model=SupervisorEvidenceDetail)
def evidence_detail(evidence_id: UUID, _: str = Depends(require_supervisor), service: SupervisorService = Depends(get_supervisor_service)):
    try:
        return _run(lambda: service.get_evidence(str(evidence_id)))
    except SupervisorEvidenceNotFoundError:
        raise HTTPException(status_code=404, detail="Evidence not found.")



@router.post("/evidence/{evidence_id}/{action}", response_model=SupervisorEvidenceDetail)
def review_evidence(
    evidence_id: UUID, action: str, payload: SupervisorReviewAction | None = None,
    supervisor_id: str = Depends(require_supervisor), service: SupervisorService = Depends(get_supervisor_service),
):
    normalized = action.upper()
    if normalized not in {"APPROVE", "FLAG", "RETURN"}:
        raise HTTPException(status_code=422, detail="Unsupported supervisor action.")
    if payload and payload.action and payload.action.strip().upper() != normalized:
        raise HTTPException(
            status_code=422,
            detail="Review action does not match the requested endpoint.",
        )
    try:
        return _run(
            lambda: service.review(
                str(evidence_id), supervisor_id, normalized, payload.reason if payload else None
            )
        )
    except SupervisorEvidenceNotFoundError:
        raise HTTPException(status_code=404, detail="Evidence not found.")
    except SupervisorReasonRequiredError as error:
        raise HTTPException(status_code=422, detail=str(error))
    except SupervisorReviewStateError as error:
        raise HTTPException(status_code=409, detail=str(error))
