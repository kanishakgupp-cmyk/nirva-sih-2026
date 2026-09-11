from fastapi import APIRouter

from app.api.v1.cases import router as cases_router

router = APIRouter(prefix="/api/v1")
router.include_router(cases_router)