from fastapi import APIRouter

from app.api.v1.cases import router as cases_router
from app.api.v1.evidence import router as evidence_router
from app.api.v1.supervisor import router as supervisor_router

router = APIRouter(prefix="/api/v1")
router.include_router(cases_router)
router.include_router(evidence_router)
router.include_router(supervisor_router)