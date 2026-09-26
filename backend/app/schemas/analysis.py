from datetime import datetime
from typing import Any, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


EvidenceStatus = Literal["CAPTURED", "VALIDATING", "ANALYZED", "FINALIZED", "INVALID"]
CalibrationStatus = Literal["PASS", "WARNING", "FAIL"]


class AnalysisResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    test_id: UUID
    operator_id: UUID
    device_id: str | None = None
    captured_at: datetime | None = None
    latitude: float | None = None
    longitude: float | None = None
    gps_accuracy: float | None = None
    image_path: str | None = None
    image_quality_score: float | None = None
    blur_score: float | None = None
    brightness_score: float | None = None
    glare_score: float | None = None
    evidence_status: EvidenceStatus
    reference_card_status: str | None = None
    calibration_status: CalibrationStatus | None = None
    calibration_error: float | None = None
    normalized_image_path: str | None = None
    analysis_status: str | None = None
    analysis_result: str | None = None
    analysis_confidence: float | None = Field(default=None, ge=0, le=1)
    analysis_uncertainty: float | None = Field(default=None, ge=0, le=1)
    analysis_model_version: str | None = None
    analysis_features: dict[str, Any] | None = None
    analysis_explanation: dict[str, Any] | None = None
    analysis_completed_at: datetime | None = None
    image_sha256: str | None = None
    previous_record_hash: str | None = None
    record_hash: str | None = None
    signature: str | None = None
    signature_algorithm: str | None = None
    key_id: str | None = None
    legal_label: str | None = None


class IntegrityResponse(BaseModel):
    evidence_id: UUID
    chain_valid: bool
    status: Literal["INTEGRITY VERIFIED", "INTEGRITY VERIFICATION FAILED"]
    previous_record_hash: str | None = None
    record_hash: str | None = None
    reason: str | None = None
    image_hash_verified: bool | None = None
    record_hash_verified: bool | None = None
    previous_record_link_verified: bool | None = None
    signature_verified: bool | None = None
    signature_status: str | None = None


class AuditEventResponse(BaseModel):
    id: UUID
    test_id: UUID
    operator_id: UUID
    event_type: str
    event_data: dict[str, Any] | None = None
    created_at: datetime


class FinalizeResponse(AnalysisResponse):
    finalization_reason: str | None = None
