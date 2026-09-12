from datetime import datetime, timezone
from typing import Any

from supabase import Client


class SupervisorEvidenceNotFoundError(Exception):
    pass


class SupervisorReviewStateError(Exception):
    pass


class SupervisorService:
    def __init__(self, client: Client):
        self._client = client

    def overview(self) -> dict[str, int]:
        return {
            "total_cases": self._count("cases"),
            "total_test_sessions": self._count("test_sessions"),
            "total_evidence_records": self._count("evidence_records"),
            "pending_review": self._count("evidence_records", "review_status", "PENDING"),
            "analyzed_evidence": self._count("evidence_records", "evidence_status", "ANALYZED"),
            "finalized_evidence": self._count("evidence_records", "evidence_status", "FINALIZED"),
            "flagged_evidence": self._count("evidence_records", "review_status", "FLAGGED"),
            "returned_evidence": self._count("evidence_records", "review_status", "RETURNED"),
        }

    def list_evidence(self, page: int, page_size: int, search: str | None, status: str | None) -> dict[str, Any]:
        query = self._client.table("evidence_records").select("*", count="exact")
        if status and status != "ALL":
            query = query.eq("review_status", status)
        if search:
            search = search.replace(",", " ")
            query = query.or_(f"id.ilike.%{search}%,test_id.ilike.%{search}%")
        offset = (page - 1) * page_size
        response = query.order("captured_at", desc=True).range(offset, offset + page_size - 1).execute()
        return {"items": [self._summary(self._enrich(row)) for row in response.data or []], "page": page,
                "page_size": page_size, "total": response.count or 0}

    def get_evidence(self, evidence_id: str) -> dict[str, Any]:
        response = self._client.table("evidence_records").select("*").eq("id", evidence_id).maybe_single().execute()
        if not response.data:
            raise SupervisorEvidenceNotFoundError
        row = self._enrich(dict(response.data))
        audit = self._client.table("audit_events").select("*").eq("test_id", row["test_id"]).order("created_at").execute()
        detail = self._summary(row)
        detail.update({
            "operator_id": row["operator_id"], "latitude": row.get("latitude"), "longitude": row.get("longitude"),
            "gps_accuracy": row.get("gps_accuracy"), "image_quality_score": row.get("image_quality_score"),
            "blur_score": row.get("blur_score"), "brightness_score": row.get("brightness_score"),
            "image_sha256": row.get("image_sha256"), "reference_card_status": row.get("reference_card_status"),
            "calibration_status": row.get("calibration_status"), "calibration_error": row.get("calibration_error"),
            "analysis_uncertainty": row.get("analysis_uncertainty"),
            "model_version": row.get("analysis_model_version") or row.get("model_version"),
            "legal_label": row.get("legal_label"), "previous_record_hash": row.get("previous_record_hash"),
            "record_hash": row.get("record_hash"), "signature": row.get("signature"),
            "signature_algorithm": row.get("signature_algorithm"), "key_id": row.get("key_id"),
            "audit_history": list(audit.data or []),
        })
        if row.get("image_path"):
            signed = self._client.storage.from_("evidence").create_signed_url(row["image_path"], 300)
            detail["image_url"] = signed.get("signedURL") or signed.get("signedUrl")
        return detail

    def review(self, evidence_id: str, supervisor_id: str, action: str, reason: str | None) -> dict[str, Any]:
        record = self._record(evidence_id)
        previous = record.get("review_status", "PENDING")
        transitions = {
            "PENDING": {"APPROVE": "APPROVED", "FLAG": "FLAGGED", "RETURN": "RETURNED"},
            "RETURNED": {"APPROVE": "APPROVED", "FLAG": "FLAGGED"},
            "FLAGGED": {"APPROVE": "APPROVED", "RETURN": "RETURNED"},
        }
        new_status = transitions.get(previous, {}).get(action)
        if new_status is None:
            raise SupervisorReviewStateError(f"Evidence cannot be {action.lower()} from {previous}.")
        now = datetime.now(timezone.utc).isoformat()
        updated = self._client.table("evidence_records").update({
            "review_status": new_status, "review_reason": reason, "reviewed_by": supervisor_id, "reviewed_at": now,
        }).eq("id", evidence_id).eq("review_status", previous).select("*").execute()
        if not updated.data:
            raise SupervisorReviewStateError("Evidence review state changed; refresh and try again.")
        event_type = {
            "APPROVE": "SUPERVISOR_APPROVED",
            "FLAG": "SUPERVISOR_FLAGGED",
            "RETURN": "SUPERVISOR_RETURNED",
        }[action]
        self._client.table("audit_events").insert({
            "test_id": record["test_id"], "operator_id": supervisor_id, "event_type": event_type,
            "event_data": {"action": action, "previous_status": previous, "new_status": new_status,
                            "supervisor_id": supervisor_id, "timestamp": now, "reason": reason},
        }).execute()
        return self.get_evidence(evidence_id)

    def _record(self, evidence_id: str) -> dict[str, Any]:
        response = self._client.table("evidence_records").select("*").eq("id", evidence_id).maybe_single().execute()
        if not response.data:
            raise SupervisorEvidenceNotFoundError
        return dict(response.data)

    def _summary(self, row: dict[str, Any]) -> dict[str, Any]:
        return {
            "id": row["id"], "test_id": row["test_id"], "test_number": row.get("test_number"),
            "case_number": row.get("case_number"), "operator": row.get("operator"), "captured_at": row.get("captured_at"),
            "evidence_status": row.get("evidence_status", "CAPTURED"), "review_status": row.get("review_status", "PENDING"),
            "analysis_result": row.get("analysis_result") or row.get("result"),
            "confidence": row.get("analysis_confidence") or row.get("confidence"),
            "integrity_status": "CHAIN VALID" if row.get("record_hash") else "NOT FINALIZED",
            "finalized": row.get("evidence_status") == "FINALIZED",
        }

    def _enrich(self, row: dict[str, Any]) -> dict[str, Any]:
        session = (
            self._client.table("test_sessions").select("test_number,case_id")
            .eq("id", row["test_id"]).maybe_single().execute()
        ).data or {}
        case = (
            self._client.table("cases").select("case_number")
            .eq("id", session.get("case_id")).maybe_single().execute()
        ).data or {}
        profile = (
            self._client.table("profiles").select("display_name")
            .eq("id", row["operator_id"]).maybe_single().execute()
        ).data or {}
        row["test_number"] = session.get("test_number")
        row["case_number"] = case.get("case_number")
        row["operator"] = profile.get("display_name") or row.get("operator_id")
        return row

    def _count(self, table: str, field: str | None = None, value: str | None = None) -> int:
        query = self._client.table(table).select("id", count="exact")
        if field and value:
            query = query.eq(field, value)
        response = query.limit(1).execute()
        return int(response.count or 0)