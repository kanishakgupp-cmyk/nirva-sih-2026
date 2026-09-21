from uuid import UUID
from datetime import datetime

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile

from app.core.auth import get_current_user_id
from app.db.client import get_configured_supabase_client
from app.schemas.analysis import AnalysisResponse, AuditEventResponse, FinalizeResponse, IntegrityResponse
from app.services.analysis_service import EvidenceAnalysisService, EvidenceNotFoundError, EvidenceStateError

router = APIRouter(prefix="/evidence", tags=["evidence"])


def get_evidence_service() -> EvidenceAnalysisService:
    return EvidenceAnalysisService(get_configured_supabase_client())


def _service_or_404(service: EvidenceAnalysisService, evidence_id: UUID, user_id: str) -> dict:
    try:
        return service.get_owned(str(evidence_id), user_id)
    except EvidenceNotFoundError:
        raise HTTPException(status_code=404, detail="Evidence not found.")


@router.get("/{evidence_id}", response_model=AnalysisResponse)
def get_evidence(
    evidence_id: UUID,
    user_id: str = Depends(get_current_user_id),
    service: EvidenceAnalysisService = Depends(get_evidence_service),
) -> dict:
    return _service_or_404(service, evidence_id, user_id)


@router.post("", response_model=AnalysisResponse, status_code=201)
async def create_evidence(
    test_id: UUID = Form(...),
    captured_at: datetime = Form(...),
    image_quality_score: float = Form(..., ge=0, le=100),
    blur_score: float = Form(..., ge=0, le=100),
    brightness_score: float = Form(..., ge=0, le=100),
    latitude: float | None = Form(default=None),
    longitude: float | None = Form(default=None),
    gps_accuracy: float | None = Form(default=None, ge=0),
    image: UploadFile = File(...),
    user_id: str = Depends(get_current_user_id),
    service: EvidenceAnalysisService = Depends(get_evidence_service),
) -> dict:
    if image.content_type not in {"image/jpeg", "image/png"}:
        raise HTTPException(status_code=422, detail="Evidence image must be JPEG or PNG.")
    image_bytes = await image.read()
    if not image_bytes:
        raise HTTPException(status_code=422, detail="Evidence image is empty.")
    try:
        return service.create_evidence(
            user_id=user_id,
            test_id=str(test_id),
            image_bytes=image_bytes,
            captured_at=captured_at,
            latitude=latitude,
            longitude=longitude,
            gps_accuracy=gps_accuracy,
            image_quality_score=image_quality_score,
            blur_score=blur_score,
            brightness_score=brightness_score,
        )
    except EvidenceNotFoundError:
        raise HTTPException(status_code=404, detail="Test session not found.")
    except EvidenceStateError as error:
        raise HTTPException(status_code=409, detail=str(error))


@router.post("/{evidence_id}/validate", response_model=AnalysisResponse)
def validate_evidence(
    evidence_id: UUID,
    user_id: str = Depends(get_current_user_id),
    service: EvidenceAnalysisService = Depends(get_evidence_service),
) -> dict:
    try:
        return service.validate(str(evidence_id), user_id)
    except EvidenceNotFoundError:
        raise HTTPException(status_code=404, detail="Evidence not found.")
    except EvidenceStateError as error:
        raise HTTPException(status_code=409, detail=str(error))


@router.post("/{evidence_id}/analyze", response_model=AnalysisResponse)
def analyze_evidence(
    evidence_id: UUID,
    user_id: str = Depends(get_current_user_id),
    service: EvidenceAnalysisService = Depends(get_evidence_service),
) -> dict:
    try:
        return service.analyze(str(evidence_id), user_id)
    except EvidenceNotFoundError:
        raise HTTPException(status_code=404, detail="Evidence not found.")
    except EvidenceStateError as error:
        raise HTTPException(status_code=409, detail=str(error))


@router.post("/{evidence_id}/finalize", response_model=FinalizeResponse)
def finalize_evidence(
    evidence_id: UUID,
    user_id: str = Depends(get_current_user_id),
    service: EvidenceAnalysisService = Depends(get_evidence_service),
) -> dict:
    try:
        return service.finalize(str(evidence_id), user_id)
    except EvidenceNotFoundError:
        raise HTTPException(status_code=404, detail="Evidence not found.")
    except EvidenceStateError as error:
        raise HTTPException(status_code=409, detail=str(error))


@router.get("/{evidence_id}/audit", response_model=list[AuditEventResponse])
def evidence_audit(
    evidence_id: UUID,
    user_id: str = Depends(get_current_user_id),
    service: EvidenceAnalysisService = Depends(get_evidence_service),
) -> list[dict]:
    try:
        return service.audit(str(evidence_id), user_id)
    except EvidenceNotFoundError:
        raise HTTPException(status_code=404, detail="Evidence not found.")


@router.get("/{evidence_id}/integrity", response_model=IntegrityResponse)
def evidence_integrity(
    evidence_id: UUID,
    user_id: str = Depends(get_current_user_id),
    service: EvidenceAnalysisService = Depends(get_evidence_service),
) -> dict:
    try:
        return service.integrity(str(evidence_id), user_id)
    except EvidenceNotFoundError:
        raise HTTPException(status_code=404, detail="Evidence not found.")
