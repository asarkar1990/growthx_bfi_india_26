import asyncio
import os
from typing import Callable, Literal

from google import genai
from google.genai import types
from pydantic import ValidationError

from app.models import DischargePlan
from app.services.extraction_prompt import SYSTEM_INSTRUCTION, extraction_prompt

MODEL = "gemini-3.6-flash"
SDK_TIMEOUT_MS = 25_000
ENDPOINT_TIMEOUT_SECONDS = 30


def _gemini_response_schema() -> dict:
    """Return Gemini-compatible JSON Schema while retaining local strict validation."""
    schema = DischargePlan.model_json_schema()

    def remove_unsupported_keywords(value):
        if isinstance(value, dict):
            value.pop("additionalProperties", None)
            for child in value.values():
                remove_unsupported_keywords(child)
        elif isinstance(value, list):
            for child in value:
                remove_unsupported_keywords(child)

    remove_unsupported_keywords(schema)
    return schema


GEMINI_RESPONSE_SCHEMA = _gemini_response_schema()


class GeminiUnavailableError(Exception):
    pass


class InvalidModelResponseError(Exception):
    pass


class DocumentClassificationError(Exception):
    def __init__(self, code: Literal["UNREADABLE_DOCUMENT", "UNSUPPORTED_DOCUMENT"]):
        self.code = code
        super().__init__(code)


def _validation_summary(error: ValidationError) -> str:
    return "; ".join(
        f"{'.'.join(str(part) for part in issue['loc'])}: {issue['type']}"
        for issue in error.errors(include_url=False)
    )


def _extract_plan(
    file_bytes: bytes,
    mime_type: str,
    language: Literal["en", "bn", "hi"],
    client_factory: Callable[..., genai.Client] = genai.Client,
) -> DischargePlan:
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise GeminiUnavailableError("Gemini API key is not configured")

    client = client_factory(api_key=api_key)
    repair_errors: str | None = None
    for attempt in range(2):
        try:
            response = client.models.generate_content(
                model=MODEL,
                contents=[
                    types.Part.from_bytes(data=file_bytes, mime_type=mime_type),
                    extraction_prompt(language, repair_errors),
                ],
                config=types.GenerateContentConfig(
                    systemInstruction=SYSTEM_INSTRUCTION,
                    responseMimeType="application/json",
                    responseJsonSchema=GEMINI_RESPONSE_SCHEMA,
                    httpOptions=types.HttpOptions(timeout=SDK_TIMEOUT_MS),
                ),
            )
            response_text = response.text
        except Exception as error:
            raise GeminiUnavailableError("Gemini request failed") from error

        try:
            plan = DischargePlan.model_validate_json(response_text)
        except (ValidationError, TypeError, ValueError) as error:
            if attempt == 0 and isinstance(error, ValidationError):
                repair_errors = _validation_summary(error)
                continue
            raise InvalidModelResponseError("Gemini returned an invalid plan") from error

        if plan.documentType == "unsupported":
            raise DocumentClassificationError("UNSUPPORTED_DOCUMENT")
        if plan.documentType == "uncertain":
            raise DocumentClassificationError("UNREADABLE_DOCUMENT")
        return plan

    raise InvalidModelResponseError("Gemini returned an invalid plan")


async def extract_plan(
    file_bytes: bytes,
    mime_type: str,
    language: Literal["en", "bn", "hi"],
) -> DischargePlan:
    try:
        return await asyncio.wait_for(
            asyncio.to_thread(_extract_plan, file_bytes, mime_type, language),
            timeout=ENDPOINT_TIMEOUT_SECONDS,
        )
    except TimeoutError as error:
        raise GeminiUnavailableError("Gemini request timed out") from error
