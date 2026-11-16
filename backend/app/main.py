"""Ponto de entrada da API. Rode: uvicorn app.main:app --reload  (docs em /docs)."""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings

app = FastAPI(title="Checklist Guindaste API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGENS.split(","),
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/api/v1/health")
def health():
    return {"status": "ok", "versao": app.version}


# TODO (BE-03..BE-09): registrar os routers conforme docs/02-backend.md
# from app.routers import auth, template, checklists
# app.include_router(auth.router, prefix="/api/v1")
