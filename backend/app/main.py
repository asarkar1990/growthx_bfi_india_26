from time import monotonic
from typing import Literal

from fastapi import FastAPI, File, Form, UploadFile
from fastapi.responses import JSONResponse

from app.models import DischargePlan
from app.services.gemini_provider import (
    DocumentClassificationError,
    GeminiUnavailableError,
    InvalidModelResponseError,
    extract_plan,
)
from app.services.sample_fixture import sample_plan

MAX_BYTES = 10 * 1024 * 1024
ALLOWED_EXTENSIONS = {"pdf", "png", "jpg", "jpeg"}
ALLOWED_CONTENT_TYPES = {"application/pdf", "image/png", "image/jpeg"}

app = FastAPI(title="CarePath India API", version="1.0.0", docs_url="/docs")

def error(code: str, message: str, status: int) -> JSONResponse:
    return JSONResponse(status_code=status, content={"error": {"code": code, "message": message}})

@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}

@app.post("/api/v1/plans")
async def create_plan(
    language: Literal["en", "bn", "hi"] = Form(...),
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
    if extension not in ALLOWED_EXTENSIONS or file.content_type not in ALLOWED_CONTENT_TYPES:
        return error("INVALID_FILE", "Upload a PDF, PNG, JPG, or JPEG file.", 400)
    contents = await file.read(MAX_BYTES + 1)
    if len(contents) > MAX_BYTES:
        return error("FILE_TOO_LARGE", "The document must be 10 MB or smaller.", 413)
    try:
        plan = await extract_plan(contents, file.content_type, language)
    except DocumentClassificationError as extraction_error:
        messages = {
            "UNREADABLE_DOCUMENT": "We could not read enough of this document. Upload a clearer image or try the sample.",
            "UNSUPPORTED_DOCUMENT": "This does not appear to be a discharge summary. Upload a discharge document or try the sample.",
        }
        return error(extraction_error.code, messages[extraction_error.code], 422)
    except GeminiUnavailableError:
        return error("MODEL_UNAVAILABLE", "Document processing is temporarily unavailable. Try the sample document.", 503)
    except InvalidModelResponseError:
        return error("INVALID_MODEL_RESPONSE", "We could not safely create a plan from this document. Try a clearer upload or the sample document.", 502)
    return {
        "plan": plan.model_dump(mode="json"),
        "meta": {"isSample": False, "processingTimeMs": int((monotonic() - started) * 1000)},
    }



