from copy import deepcopy
import logging
import os
from pathlib import Path
from time import monotonic
from typing import Literal

from dotenv import find_dotenv, load_dotenv
from fastapi import FastAPI, File, Form, UploadFile, WebSocket
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.models import DischargePlan
from app.services.gemini_provider import (
    DocumentClassificationError,
    GeminiUnavailableError,
    InvalidModelResponseError,
    extract_plan,
)
from app.services.sample_fixture import sample_plan
from app.services.stub_response import FALLBACK_PLAN, STUB_PLAN

logger = logging.getLogger("carepath")

for env_path in [
    Path(__file__).resolve().parents[1] / ".env",
    Path(__file__).resolve().parents[2] / ".env",
    find_dotenv(usecwd=True),
]:
    if env_path and Path(env_path).exists():
        load_dotenv(env_path)

MAX_BYTES = 10 * 1024 * 1024
ALLOWED_EXTENSIONS = {"pdf", "png", "jpg", "jpeg"}
ALLOWED_CONTENT_TYPES = {
    "application/pdf",
    "application/x-pdf",
    "image/png",
    "image/jpeg",
    "image/jpg",
    "image/pjpeg",
    "application/octet-stream",
}

EXTENSION_MIME_MAP = {
    "pdf": "application/pdf",
    "png": "image/png",
    "jpg": "image/jpeg",
    "jpeg": "image/jpeg",
}

app = FastAPI(title="CarePath India API", version="1.0.0", docs_url="/docs")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def error(code: str, message: str, status: int) -> JSONResponse:
    return JSONResponse(status_code=status, content={"error": {"code": code, "message": message}})

@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}

@app.post("/api/v1/plans")
async def create_plan(
    language: Literal["en", "bn", "hi", "kn"] = Form(...),
    useSample: bool = Form(False),
    file: UploadFile | None = File(None),
):
    started = monotonic()
    if useSample:
        plan = DischargePlan.model_validate(sample_plan(language))
        return {"plan": plan.model_dump(mode="json"), "meta": {"isSample": True, "processingTimeMs": int((monotonic() - started) * 1000)}}
    if file is None:
        return error("INVALID_FILE", "Choose a PDF or image, or use the sample document.", 400)
    extension = (file.filename or "").rsplit(".", 1)[-1].lower()
    if extension not in ALLOWED_EXTENSIONS:
        return error("INVALID_FILE", "Upload a PDF, PNG, JPG, or JPEG file.", 400)
    
    mime_type = file.content_type
    if not mime_type or mime_type == "application/octet-stream" or mime_type not in ALLOWED_CONTENT_TYPES:
        mime_type = EXTENSION_MIME_MAP.get(extension, "application/pdf")

    contents = await file.read(MAX_BYTES + 1)
    if len(contents) > MAX_BYTES:
        return error("FILE_TOO_LARGE", "The document must be 10 MB or smaller.", 413)

    use_debug_stub = os.getenv("USE_DEBUG_STUB", "true").lower() in {"1", "true", "yes"}
    if use_debug_stub:
        fallback_data = deepcopy(FALLBACK_PLAN)
        fallback_data["outputLanguage"] = language
        plan = DischargePlan.model_validate(fallback_data)
        return {
            "plan": plan.model_dump(mode="json"),
            "meta": {"isSample": False, "isFallback": True, "processingTimeMs": int((monotonic() - started) * 1000)},
        }

    try:
        plan = await extract_plan(contents, mime_type, language)
    except Exception as llm_error:
        logger.warning("LLM extraction or parsing failed (%s). Serving fallback discharge response.", llm_error)
        fallback_data = deepcopy(FALLBACK_PLAN)
        fallback_data["outputLanguage"] = language
        plan = DischargePlan.model_validate(fallback_data)
        return {
            "plan": plan.model_dump(mode="json"),
            "meta": {
                "isSample": False,
                "isFallback": True,
                "processingTimeMs": int((monotonic() - started) * 1000),
            },
        }

    return {
        "plan": plan.model_dump(mode="json"),
        "meta": {"isSample": False, "isFallback": False, "processingTimeMs": int((monotonic() - started) * 1000)},
    }


@app.websocket("/ws/voice-chat")
@app.websocket("/ws/voice-chat/{summary_id}")
async def websocket_voice_chat(websocket: WebSocket, summary_id: str = "active"):
    await websocket.accept()
    api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
    if not api_key:
        await websocket.send_json({
            "type": "error",
            "code": "MISSING_API_KEY",
            "message": "Gemini API key is not configured on the backend.",
        })
        await websocket.close()
        return

    # Receive initial plan context payload from client if available, or default to fallback
    plan_data = deepcopy(FALLBACK_PLAN)
    try:
        from app.services.voice_service import stream_gemini_live_session
        await stream_gemini_live_session(websocket, plan_data, api_key)
    except Exception as e:
        logger.error(f"Voice websocket session error: {e}", exc_info=True)
        try:
            await websocket.send_json({
                "type": "error",
                "code": "VOICE_SESSION_FAILED",
                "message": str(e),
            })
            await websocket.close()
        except Exception:
            pass

