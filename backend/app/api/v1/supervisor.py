from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query

from app.core.auth import require_supervisor
from app.db.client import get_configured_supabase_client
from app.schemas.supervisor import SupervisorEvidenceDetail, SupervisorEvidencePage, SupervisorOverview, SupervisorReviewAction
from app.services.supervisor_service import SupervisorEvidenceNotFoundError, SupervisorReviewStateError, SupervisorService

router = APIRouter(prefix="/supervisor", tags=["supervisor"])


def get_supervisor_service() -> SupervisorService:
    return SupervisorService(get_configured_supabase_client())


@router.get("/overview", response_model=SupervisorOverview)
def overview(_: str = Depends(require_supervisor), service: SupervisorService = Depends(get_supervisor_service)):
    return service.overview()


@router.get("/evidence", response_model=SupervisorEvidencePage)
def evidence_queue(
    page: int = Query(1, ge=1), page_size: int = Query(20, ge=1, le=100),
    search: str | None = Query(None, max_length=100), status: str | None = Query(None),
    _: str = Depends(require_supervisor), service: SupervisorService = Depends(get_supervisor_service),
):
    return service.list_evidence(page, page_size, search, status)


@router.get("/evidence/{evidence_id}", response_model=SupervisorEvidenceDetail)
def evidence_detail(evidence_id: UUID, _: str = Depends(require_supervisor), service: SupervisorService = Depends(get_supervisor_service)):
    try:
        return service.get_evidence(str(evidence_id))
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
    try:
        return service.review(str(evidence_id), supervisor_id, normalized, payload.reason if payload else None)
    except SupervisorEvidenceNotFoundError:
        raise HTTPException(status_code=404, detail="Evidence not found.")
    except SupervisorReviewStateError as error:
        raise HTTPException(status_code=409, detail=str(error))