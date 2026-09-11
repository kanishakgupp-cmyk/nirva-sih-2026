from typing import Any

from postgrest.exceptions import APIError
from supabase import Client


class CaseNotFoundError(Exception):
    pass


class DuplicateCaseNumberError(Exception):
    pass


class CaseService:
    def __init__(self, client: Client):
        self._client = client

    def list_cases(self, user_id: str) -> list[dict[str, Any]]:
        response = (
            self._client.table("cases")
            .select("*")
            .eq("created_by", user_id)
            .order("created_at", desc=True)
            .execute()
        )
        return list(response.data or [])

    def create_case(
        self,
        user_id: str,
        case_number: str,
        title: str,
        description: str | None,
    ) -> dict[str, Any]:
        payload = {
            "case_number": case_number.strip(),
            "title": title.strip(),
            "description": description.strip() if description and description.strip() else None,
            "created_by": user_id,
        }
        try:
            response = (
                self._client.table("cases")
                .insert(payload)
                .select("*")
                .single()
                .execute()
            )
        except APIError as exc:
            if getattr(exc, "code", None) == "23505":
                raise DuplicateCaseNumberError from exc
            raise
        return response.data

    def get_case(self, user_id: str, case_id: str) -> dict[str, Any]:
        response = (
            self._client.table("cases")
            .select("*")
            .eq("id", case_id)
            .eq("created_by", user_id)
            .maybe_single()
            .execute()
        )
        if response.data is None:
            raise CaseNotFoundError
        return response.data