import asyncio
import logging
import os
from pathlib import Path
from typing import Callable, Literal

from dotenv import find_dotenv, load_dotenv
from google import genai
from google.genai import types
from pydantic import ValidationError

from app.models import DischargePlan
from app.services.extraction_prompt import SYSTEM_INSTRUCTION, extraction_prompt

logger = logging.getLogger("carepath.gemini")

def _load_env():
    for env_path in [
        Path(__file__).resolve().parents[1] / ".env",
        Path(__file__).resolve().parents[2] / ".env",
        find_dotenv(usecwd=True),
    ]:
        if env_path and Path(env_path).exists():
            load_dotenv(env_path)

_load_env()

MODEL = os.getenv("GEMINI_MODEL", "gemini-3.6-flash")
SDK_TIMEOUT_MS = int(os.getenv("GEMINI_SDK_TIMEOUT_MS", "60000"))
ENDPOINT_TIMEOUT_SECONDS = int(os.getenv("GEMINI_ENDPOINT_TIMEOUT_SECONDS", "130"))



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


import re

def _clean_json_text(text: str | None) -> str:
    if not text:
        return "{}"
    clean = text.strip()
    if clean.startswith("```"):
        lines = clean.splitlines()
        if lines and lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].strip() == "```":
            lines = lines[:-1]
        clean = "\n".join(lines).strip()
    if "```" in clean:
        match = re.search(r"```(?:json)?(.*?)```", clean, re.DOTALL)
        if match:
            clean = match.group(1).strip()
    return clean

def _extract_plan(
    file_bytes: bytes,
    mime_type: str,
    language: Literal["en", "bn", "hi", "kn"],
    client_factory: Callable[..., genai.Client] = genai.Client,
) -> DischargePlan:
    _load_env()
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        logger.error("GEMINI_API_KEY is not configured in environment or .env")
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
            logger.warning("Gemini API generate_content attempt %d failed: %s", attempt + 1, error)
            if attempt == 0:
                continue
            raise GeminiUnavailableError("Gemini request failed") from error

        cleaned_text = _clean_json_text(response_text)
        try:
            plan = DischargePlan.model_validate_json(cleaned_text)
        except Exception as error:
            logger.warning("DischargePlan validation error on attempt %d: %s\nRaw output:\n%s", attempt + 1, error, response_text)
            if attempt == 0:
                if isinstance(error, ValidationError):
                    repair_errors = _validation_summary(error)
                else:
                    repair_errors = str(error)
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
    language: Literal["en", "bn", "hi", "kn"],
) -> DischargePlan:
    try:
        return await asyncio.wait_for(
            asyncio.to_thread(_extract_plan, file_bytes, mime_type, language),
            timeout=ENDPOINT_TIMEOUT_SECONDS,
        )
    except TimeoutError as error:
        raise GeminiUnavailableError("Gemini request timed out") from error
