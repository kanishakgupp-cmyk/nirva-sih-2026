from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class CaseCreate(BaseModel):
    case_number: str = Field(min_length=1)
    title: str = Field(min_length=1)
    description: str | None = None


class CaseResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    case_number: str
    title: str
    description: str | None
    created_by: UUID
    created_at: datetime