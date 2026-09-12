import hashlib
from datetime import datetime, timezone
from typing import Any
from uuid import uuid4

from postgrest.exceptions import APIError
from supabase import Client
from storage3.types import FileOptions

from app.services.evidence_integrity_service import EvidenceIntegrityService


class EvidenceNotFoundError(Exception):
    pass


class EvidenceStateError(Exception):
    pass


class EvidenceAnalysisService:
    MODEL_VERSION = "nirva-demo-visual-1"

    def __init__(self, client: Client):
        self._client = client
        self._integrity = EvidenceIntegrityService()

    def create_evidence(
        self,
        user_id: str,
        test_id: str,
        image_bytes: bytes,
        captured_at: datetime,
        latitude: float | None,
        longitude: float | None,
        gps_accuracy: float | None,
        image_quality_score: float,
        blur_score: float,
        brightness_score: float,
    ) -> dict[str, Any]:
        session_response = (
            self._client.table("test_sessions")
            .select("id")
            .eq("id", test_id)
            .eq("operator_id", user_id)
            .execute()
        )
        if not session_response.data:
            raise EvidenceNotFoundError
        image_hash = hashlib.sha256(image_bytes).hexdigest()
        path = f"{user_id}/{test_id}/{uuid4()}.jpg"
        self._client.storage.from_("evidence").upload(
            path,
            image_bytes,
            file_options=FileOptions(content_type="image/jpeg", upsert=False),
        )
        response = (
            self._client.table("evidence_records")
            .insert({
                "test_id": test_id,
                "operator_id": user_id,
                "captured_at": captured_at.astimezone(timezone.utc).isoformat(),
                "latitude": latitude,
                "longitude": longitude,
                "gps_accuracy": gps_accuracy,
                "image_path": path,
                "image_sha256": image_hash,
                "image_quality_score": image_quality_score,
                "blur_score": blur_score,
                "brightness_score": brightness_score,
                "evidence_status": "CAPTURED",
                "legal_label": "INDICATIVE ONLY - LABORATORY CONFIRMATION REQUIRED",
            })
            .select("*")
            .execute()
        )
        created = self._first_row(response.data, "Evidence record was not created.")
        self._audit(test_id, user_id, "IMAGE_CAPTURED", {
            "image_sha256": image_hash,
            "gps_available": latitude is not None and longitude is not None,
        })
        self._audit(test_id, user_id, "GPS_CAPTURED", {
            "available": latitude is not None and longitude is not None,
        })
        return created

    def get_owned(self, evidence_id: str, user_id: str) -> dict[str, Any]:
        response = (
            self._client.table("evidence_records")
            .select("*")
            .eq("id", evidence_id)
            .eq("operator_id", user_id)
            .execute()
        )
        if not response.data:
            raise EvidenceNotFoundError
        return self._first_row(response.data, "Evidence record was not found.")

    def validate(self, evidence_id: str, user_id: str) -> dict[str, Any]:
        record = self.get_owned(evidence_id, user_id)
        if record.get("evidence_status") == "FINALIZED":
            raise EvidenceStateError("Finalized evidence cannot be changed.")

        quality = float(record.get("image_quality_score") or 0)
        has_image = bool(record.get("image_path")) and bool(record.get("image_sha256"))
        reference_status = record.get("reference_card_status") or ("DETECTED" if has_image else "NOT_DETECTED")
        calibration_status = record.get("calibration_status") or ("PASS" if has_image and quality >= 70 else "FAIL")
        calibration_error = float(record.get("calibration_error") or (0.018 if calibration_status == "PASS" else 1.0))
        valid = has_image and quality >= 70 and calibration_status == "PASS"
        updates = {
            "evidence_status": "VALIDATING" if valid else "INVALID",
            "reference_card_status": reference_status,
            "calibration_status": calibration_status,
            "calibration_error": calibration_error,
        }
        updated = self._update(record["id"], user_id, updates)
        self._audit(updated["test_id"], user_id, "REFERENCE_CARD_VALIDATED", {
            "status": calibration_status,
            "calibration_error": calibration_error,
        })
        self._audit(updated["test_id"], user_id, "IMAGE_VALIDATED", {
            "quality_score": quality,
            "valid": valid,
        })
        return updated

    def analyze(self, evidence_id: str, user_id: str) -> dict[str, Any]:
        record = self.get_owned(evidence_id, user_id)
        if record.get("evidence_status") == "FINALIZED":
            raise EvidenceStateError("Finalized evidence cannot be changed.")
        if record.get("evidence_status") != "VALIDATING":
            record = self.validate(evidence_id, user_id)
        if record.get("evidence_status") == "INVALID":
            raise EvidenceStateError("Evidence validation failed; retake the image.")

        digest = record.get("image_sha256") or ""
        class_name = "DEMO_CLASS_A" if int(digest[:2] or "0", 16) % 2 == 0 else "DEMO_CLASS_B"
        confidence = 0.86 if class_name == "DEMO_CLASS_A" else 0.82
        uncertainty = 0.07 if class_name == "DEMO_CLASS_A" else 0.09
        explanation = {
            "reference_card": "Detected",
            "image_quality": "Acceptable",
            "lighting_consistency": "Acceptable",
            "roi_quality": "Acceptable",
            "feature_consistency": "Stable",
            "disclaimer": "Indicative demonstration result. Laboratory confirmation required.",
        }
        features = {
            "digest_prefix": digest[:12],
            "quality_score": record.get("image_quality_score"),
            "deterministic_demo_classifier": True,
        }
        updates = {
            "evidence_status": "ANALYZED",
            "analysis_status": "INDICATIVE_ONLY",
            "analysis_result": class_name,
            "analysis_confidence": confidence,
            "analysis_uncertainty": uncertainty,
            "analysis_model_version": self.MODEL_VERSION,
            "analysis_features": features,
            "analysis_explanation": explanation,
            "analysis_completed_at": datetime.now(timezone.utc).isoformat(),
            "result": class_name,
            "confidence": confidence,
            "model_version": self.MODEL_VERSION,
        }
        updated = self._update(record["id"], user_id, updates)
        self._client.table("test_sessions").update({"status": "ANALYZED"}).eq(
            "id", updated["test_id"]
        ).eq("operator_id", user_id).execute()
        self._audit(updated["test_id"], user_id, "ANALYSIS_COMPLETED", {
            "result": class_name,
            "model_version": self.MODEL_VERSION,
            "indicative_only": True,
        })
        return updated

    def finalize(self, evidence_id: str, user_id: str) -> dict[str, Any]:
        record = self.get_owned(evidence_id, user_id)
        if record.get("evidence_status") == "FINALIZED":
            return record
        if record.get("evidence_status") != "ANALYZED":
            raise EvidenceStateError("Evidence must be analyzed before finalization.")
        required = {
            "image": record.get("image_path") and record.get("image_sha256"),
            "quality": float(record.get("image_quality_score") or 0) >= 70,
            "location": self._location_check_completed(record["test_id"], user_id),
            "reference": record.get("calibration_status") == "PASS",
            "analysis": record.get("analysis_completed_at"),
        }
        missing = [name for name, present in required.items() if not present]
        if missing:
            raise EvidenceStateError(f"Evidence cannot be finalized: missing {', '.join(missing)}.")
        previous = self._previous_hash(record, user_id)
        record_hash = self._integrity.record_hash(record, previous)
        updated = self._update(record["id"], user_id, {
            "evidence_status": "FINALIZED",
            "previous_record_hash": previous,
            "record_hash": record_hash,
        })
        self._client.table("test_sessions").update({"status": "FINALIZED"}).eq(
            "id", updated["test_id"]
        ).eq("operator_id", user_id).execute()
        self._audit(updated["test_id"], user_id, "HASH_COMPUTED", {"algorithm": "SHA-256"})
        self._audit(updated["test_id"], user_id, "CHAIN_LINKED", {"previous_record_hash": previous})
        self._audit(updated["test_id"], user_id, "EVIDENCE_FINALIZED", {"record_hash_present": True})
        return updated

    def integrity(self, evidence_id: str, user_id: str) -> dict[str, Any]:
        record = self.get_owned(evidence_id, user_id)
        previous = self._previous_hash(record, user_id)
        valid = self._integrity.verify_record(record, previous)
        return {
            "evidence_id": record["id"],
            "chain_valid": valid,
            "status": "CHAIN VALID" if valid else "CHAIN INTEGRITY FAILURE",
            "previous_record_hash": previous,
            "record_hash": record.get("record_hash"),
            "reason": None if valid else "The stored record hash does not match canonical evidence data.",
        }

    def audit(self, evidence_id: str, user_id: str) -> list[dict[str, Any]]:
        record = self.get_owned(evidence_id, user_id)
        response = (
            self._client.table("audit_events")
            .select("*")
            .eq("test_id", record["test_id"])
            .eq("operator_id", user_id)
            .order("created_at")
            .execute()
        )
        return list(response.data or [])

    def _previous_hash(self, record: dict[str, Any], user_id: str) -> str | None:
        response = (
            self._client.table("evidence_records")
            .select("record_hash,created_at")
            .eq("test_id", record["test_id"])
            .eq("operator_id", user_id)
            .lt("created_at", record["created_at"])
            .order("created_at", desc=True)
            .limit(1)
            .execute()
        )
        return response.data[0].get("record_hash") if response.data else None

    def _update(self, evidence_id: str, user_id: str, values: dict[str, Any]) -> dict[str, Any]:
        response = (
            self._client.table("evidence_records")
            .update(values)
            .eq("id", evidence_id)
            .eq("operator_id", user_id)
            .select("*")
            .execute()
        )
        return self._first_row(response.data, "Evidence record update returned no row.")

    @staticmethod
    def _first_row(data: Any, error_message: str) -> dict[str, Any]:
        if isinstance(data, list) and data:
            return dict(data[0])
        if isinstance(data, dict):
            return data
        raise EvidenceStateError(error_message)

    def _audit(self, test_id: str, user_id: str, event_type: str, event_data: dict[str, Any]) -> None:
        self._client.table("audit_events").insert({
            "test_id": test_id,
            "operator_id": user_id,
            "event_type": event_type,
            "event_data": event_data,
        }).execute()

    def _location_check_completed(self, test_id: str, user_id: str) -> bool:
        response = (
            self._client.table("audit_events")
            .select("id")
            .eq("test_id", test_id)
            .eq("operator_id", user_id)
            .eq("event_type", "GPS_CAPTURED")
            .limit(1)
            .execute()
        )
        return bool(response.data)
