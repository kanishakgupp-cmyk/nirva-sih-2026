from uuid import UUID
from datetime import datetime

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile

from app.core.auth import get_current_user_id
from app.db.client import get_configured_supabase_client
from app.schemas.analysis import AnalysisResponse, AuditEventResponse, FinalizeResponse, IntegrityResponse
from app.services.analysis_service import EvidenceAnalysisService, EvidenceNotFoundError, EvidenceStateError

MAX_EVIDENCE_UPLOAD_BYTES = 10 * 1024 * 1024
_ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png"}

router = APIRouter(prefix="/evidence", tags=["evidence"])


def _validate_uploaded_image(image: UploadFile, image_bytes: bytes) -> None:
    if image.content_type not in _ALLOWED_IMAGE_TYPES:
        raise HTTPException(status_code=422, detail="Evidence image must be JPEG or PNG.")
    if not image_bytes:
        raise HTTPException(status_code=422, detail="Evidence image is empty.")
    if len(image_bytes) > MAX_EVIDENCE_UPLOAD_BYTES:
        raise HTTPException(
            status_code=422,
            detail="Evidence image is too large. Maximum size is 10 MB.",
        )

    signature_ok = (
        image_bytes.startswith(b"\x89PNG\r\n\x1a\n")
        or image_bytes.startswith(b"\xff\xd8\xff")
    )
    if not signature_ok:
        raise HTTPException(
            status_code=422,
            detail="Uploaded file is not a valid JPEG or PNG image.",
        )

    filename = (image.filename or "").lower()
    if filename and not (filename.endswith(".jpg") or filename.endswith(".jpeg") or filename.endswith(".png")):
        raise HTTPException(
            status_code=422,
            detail="Evidence image filename must end with .jpg, .jpeg, or .png.",
        )


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
    client_operation_id: str | None = Form(default=None, max_length=100),
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
    image_bytes = await image.read()
    _validate_uploaded_image(image, image_bytes)
    try:
        return service.create_evidence(
            user_id=user_id,
            test_id=str(test_id),
            client_operation_id=client_operation_id,
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
