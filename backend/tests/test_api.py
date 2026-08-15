import json
import os
import asyncio
from pathlib import Path
import time

from fastapi.testclient import TestClient
from pydantic import ValidationError
import pytest

from app.main import app
from app.models import DischargePlan
from app.services.gemini_provider import (
    GEMINI_RESPONSE_SCHEMA,
    GeminiUnavailableError,
    InvalidModelResponseError,
    _extract_plan,
    extract_plan,
)
from app.services.sample_fixture import sample_plan

client = TestClient(app)

def test_sample_is_deterministic_and_valid():
    first = client.post("/api/v1/plans", data={"language": "bn", "useSample": "true"})
    second = client.post("/api/v1/plans", data={"language": "bn", "useSample": "true"})
    assert first.status_code == 200
    assert first.json()["plan"] == second.json()["plan"]
    assert first.json()["meta"]["isSample"] is True

def test_missing_evidence_fails():
    payload = sample_plan("en")
    payload["medications"][0]["sourceEvidence"] = ""
    with pytest.raises(ValidationError):
        DischargePlan.model_validate(payload)

def test_invalid_day_fails():
    payload = sample_plan("en")
    payload["medications"][0]["applicableDays"] = [8]
    with pytest.raises(ValidationError):
        DischargePlan.model_validate(payload)

def test_unsupported_file_is_rejected():
    response = client.post("/api/v1/plans", data={"language": "en"}, files={"file": ("notes.txt", b"hello", "text/plain")})
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "INVALID_FILE"

def test_real_file_fails_safely_when_gemini_key_is_unconfigured(monkeypatch):
    monkeypatch.delenv("GEMINI_API_KEY", raising=False)
    response = client.post("/api/v1/plans", data={"language": "en"}, files={"file": ("summary.pdf", b"synthetic", "application/pdf")})
    assert response.status_code == 503
    assert set(response.json()["error"]) == {"code", "message"}


def test_real_pdf_uses_provider_and_preserves_mime_and_language(monkeypatch):
    captured = {}

    async def successful_extract(file_bytes, mime_type, language):
        captured.update(bytes=file_bytes, mime_type=mime_type, language=language)
        return DischargePlan.model_validate(sample_plan(language))

    monkeypatch.setattr("app.main.extract_plan", successful_extract)
    response = client.post(
        "/api/v1/plans",
        data={"language": "hi"},
        files={"file": ("summary.pdf", b"pdf-bytes", "application/pdf")},
    )

    assert response.status_code == 200
    assert response.json()["meta"]["isSample"] is False
    assert captured == {
        "bytes": b"pdf-bytes",
        "mime_type": "application/pdf",
        "language": "hi",
    }


def test_real_image_uses_provider(monkeypatch):
    async def successful_extract(file_bytes, mime_type, language):
        return DischargePlan.model_validate(sample_plan(language))

    monkeypatch.setattr("app.main.extract_plan", successful_extract)
    response = client.post(
        "/api/v1/plans",
        data={"language": "bn"},
        files={"file": ("summary.jpg", b"image-bytes", "image/jpeg")},
    )

    assert response.status_code == 200
    assert response.json()["plan"]["outputLanguage"] == "bn"


@pytest.mark.parametrize(
    ("exception", "code", "status"),
    [
        (GeminiUnavailableError("unavailable"), "MODEL_UNAVAILABLE", 503),
        (InvalidModelResponseError("invalid"), "INVALID_MODEL_RESPONSE", 502),
    ],
)
def test_provider_errors_are_safe(monkeypatch, exception, code, status):
    async def failing_extract(*_args):
        raise exception

    monkeypatch.setattr("app.main.extract_plan", failing_extract)
    response = client.post(
        "/api/v1/plans",
        data={"language": "en"},
        files={"file": ("summary.pdf", b"pdf-bytes", "application/pdf")},
    )

    assert response.status_code == status
    assert response.json()["error"]["code"] == code
    assert set(response.json()["error"]) == {"code", "message"}


def test_provider_retries_once_after_schema_failure(monkeypatch):
    monkeypatch.setenv("GEMINI_API_KEY", "test-key")
    calls = []

    class Response:
        def __init__(self, text):
            self.text = text

    class Models:
        def generate_content(self, **kwargs):
            calls.append(kwargs)
            text = "{}" if len(calls) == 1 else json.dumps(sample_plan("en"))
            return Response(text)

    class FakeClient:
        def __init__(self, **_kwargs):
            self.models = Models()

    plan = _extract_plan(b"pdf-bytes", "application/pdf", "en", client_factory=FakeClient)

    assert plan.outputLanguage == "en"
    assert len(calls) == 2
    assert calls[0]["contents"][0].inline_data.mime_type == "application/pdf"
    assert calls[0]["contents"][0].inline_data.data == b"pdf-bytes"
    assert "Correct these schema violations" in calls[1]["contents"][1]


def test_gemini_schema_removes_unsupported_additional_properties():
    def contains_additional_properties(value):
        if isinstance(value, dict):
            return "additionalProperties" in value or any(
                contains_additional_properties(child) for child in value.values()
            )
        if isinstance(value, list):
            return any(contains_additional_properties(child) for child in value)
        return False

    assert not contains_additional_properties(GEMINI_RESPONSE_SCHEMA)


def test_provider_rejects_invalid_response_after_one_retry(monkeypatch):
    monkeypatch.setenv("GEMINI_API_KEY", "test-key")
    calls = []

    class Response:
        text = "{}"

    class Models:
        def generate_content(self, **_kwargs):
            calls.append(True)
            return Response()

    class FakeClient:
        def __init__(self, **_kwargs):
            self.models = Models()

    with pytest.raises(InvalidModelResponseError):
        _extract_plan(b"pdf-bytes", "application/pdf", "en", client_factory=FakeClient)

    assert len(calls) == 2


def test_provider_timeout_is_mapped_to_unavailable(monkeypatch):
    def slow_extract(*_args):
        time.sleep(0.05)

    monkeypatch.setattr("app.services.gemini_provider._extract_plan", slow_extract)
    monkeypatch.setattr("app.services.gemini_provider.ENDPOINT_TIMEOUT_SECONDS", 0.001)

    with pytest.raises(GeminiUnavailableError):
        asyncio.run(extract_plan(b"pdf-bytes", "application/pdf", "en"))


@pytest.mark.skipif(
    os.getenv("GEMINI_LIVE_TEST") != "1" or not os.getenv("GEMINI_API_KEY"),
    reason="Set GEMINI_LIVE_TEST=1 and GEMINI_API_KEY to run the paid live Gemini test.",
)
def test_live_gemini_extracts_synthetic_pdf():
    pdf_path = Path(__file__).parents[2] / "app/assets/samples/synthetic_discharge_summary.pdf"
    with pdf_path.open("rb") as document:
        response = client.post(
            "/api/v1/plans",
            data={"language": "en"},
            files={"file": (pdf_path.name, document, "application/pdf")},
        )

    assert response.status_code == 200
    assert response.json()["meta"]["isSample"] is False
