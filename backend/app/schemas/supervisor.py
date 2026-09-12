from datetime import datetime
from typing import Any, Literal
from uuid import UUID

from pydantic import BaseModel, Field


ReviewStatus = Literal["PENDING", "APPROVED", "FLAGGED", "RETURNED"]


class SupervisorOverview(BaseModel):
    total_cases: int
    total_test_sessions: int
    total_evidence_records: int
    pending_review: int
    analyzed_evidence: int
    finalized_evidence: int
    flagged_evidence: int
    returned_evidence: int


class SupervisorEvidenceSummary(BaseModel):
    id: UUID
    test_id: UUID
    test_number: str | None = None
    case_number: str | None = None
    operator: str | None = None
    captured_at: datetime | None = None
    evidence_status: str
    review_status: ReviewStatus
    review_reason: str | None = None
    analysis_result: str | None = None
    confidence: float | None = Field(default=None, ge=0, le=1)
    integrity_status: str
    finalized: bool


class SupervisorEvidencePage(BaseModel):
    items: list[SupervisorEvidenceSummary]
    page: int
    page_size: int
    total: int


class SupervisorEvidenceDetail(SupervisorEvidenceSummary):
    operator_id: UUID
    latitude: float | None = None
    longitude: float | None = None
    gps_accuracy: float | None = None
    image_quality_score: float | None = None
    blur_score: float | None = None
    brightness_score: float | None = None
    image_sha256: str | None = None
    image_url: str | None = None
    reference_card_status: str | None = None
    calibration_status: str | None = None
    calibration_error: float | None = None
    analysis_uncertainty: float | None = None
    model_version: str | None = None
    legal_label: str | None = None
    previous_record_hash: str | None = None
    record_hash: str | None = None
    signature: str | None = None
    signature_algorithm: str | None = None
    key_id: str | None = None
    reviewed_by: UUID | None = None
    reviewed_at: datetime | None = None
    audit_history: list[dict[str, Any]]


class SupervisorReviewAction(BaseModel):
    reason: str | None = Field(default=None, max_length=1000)