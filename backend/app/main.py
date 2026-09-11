import logging

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.health import router as health_router
from app.config import get_settings

settings = get_settings()
logger = logging.getLogger(__name__)

app = FastAPI(
    title="NIRVA API",
    description="Backend foundation for the NIRVA field evidence platform.",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)

app.include_router(health_router)


@app.exception_handler(Exception)
def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    logger.exception("Unhandled API error for %s %s", request.method, request.url.path)
    detail = "Internal server error."
    if settings.environment.lower() in {"development", "dev", "test"}:
        detail = "Internal server error. Check server logs for details."
    return JSONResponse(status_code=500, content={"detail": detail})
