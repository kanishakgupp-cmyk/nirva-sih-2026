from fastapi import APIRouter

router = APIRouter(tags=["health"])


@router.get("/health", summary="Check API health")
def health() -> dict[str, str]:
    return {
        "status": "ok",
        "service": "nirva-api",
        "version": "0.1.0",
    }
