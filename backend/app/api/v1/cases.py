from fastapi import APIRouter, Depends, HTTPException, Path, status

from app.core.auth import get_current_user_id
from app.db.client import get_configured_supabase_client
from app.schemas.cases import CaseCreate, CaseResponse
from app.services.case_service import (
    CaseNotFoundError,
    CaseService,
    DuplicateCaseNumberError,
)

router = APIRouter(prefix="/cases", tags=["cases"])


def get_case_service() -> CaseService:
    return CaseService(get_configured_supabase_client())


@router.get("", response_model=list[CaseResponse])
def list_cases(
    user_id: str = Depends(get_current_user_id),
    service: CaseService = Depends(get_case_service),
) -> list[dict]:
    return service.list_cases(user_id)


@router.post("", response_model=CaseResponse, status_code=status.HTTP_201_CREATED)
def create_case(
    case: CaseCreate,
    user_id: str = Depends(get_current_user_id),
    service: CaseService = Depends(get_case_service),
) -> dict:
    try:
        return service.create_case(
            user_id=user_id,
            case_number=case.case_number,
            title=case.title,
            description=case.description,
        )
    except DuplicateCaseNumberError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Case number already exists.",
        )


@router.get("/{case_id}", response_model=CaseResponse)
def get_case(
    case_id: str = Path(min_length=1),
    user_id: str = Depends(get_current_user_id),
    service: CaseService = Depends(get_case_service),
) -> dict:
    try:
        return service.get_case(user_id, case_id)
    except CaseNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Case not found.",
        )