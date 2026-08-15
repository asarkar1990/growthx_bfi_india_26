import json
import os
import asyncio
from datetime import datetime, timedelta
from pathlib import Path
import time
from zoneinfo import ZoneInfo

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

@pytest.fixture(autouse=True)
def disable_debug_stub(monkeypatch):
    monkeypatch.setenv("USE_DEBUG_STUB", "false")

def test_sample_is_deterministic_and_valid():
    first = client.post("/api/v1/plans", data={"language": "bn", "useSample": "true"})
    second = client.post("/api/v1/plans", data={"language": "bn", "useSample": "true"})
    assert first.status_code == 200
    assert first.json()["plan"] == second.json()["plan"]
    assert first.json()["meta"]["isSample"] is True

def test_kannada_sample_is_supported():
    response = client.post("/api/v1/plans", data={"language": "kn", "useSample": "true"})
    assert response.status_code == 200
    assert response.json()["plan"]["outputLanguage"] == "kn"
    assert "ಏಳು ದಿನಗಳ" in response.json()["plan"]["overview"]

def test_kannada_debug_stub_is_language_aware(monkeypatch):
    monkeypatch.setenv("USE_DEBUG_STUB", "true")
    response = client.post(
        "/api/v1/plans",
        data={"language": "kn"},
        files={"file": ("summary.pdf", b"pdf-bytes", "application/pdf")},
    )
    assert response.status_code == 200
    plan = response.json()["plan"]
    yesterday = datetime.now(ZoneInfo("Asia/Kolkata")).date() - timedelta(days=1)
    assert plan["outputLanguage"] == "kn"
    assert plan["patient"]["dischargeDate"] == yesterday.isoformat()
    assert all(2 in medication["applicableDays"] for medication in plan["medications"])
    assert all(
        any(day > 2 for day in medication["applicableDays"])
        for medication in plan["medications"]
    )

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
    monkeypatch.setenv("USE_DEBUG_STUB", "false")
    monkeypatch.delenv("GEMINI_API_KEY", raising=False)
    response = client.post("/api/v1/plans", data={"language": "en"}, files={"file": ("summary.pdf", b"synthetic", "application/pdf")})
    assert response.status_code == 200
    assert response.json()["meta"]["isFallback"] is True
    assert response.json()["plan"]["patient"]["displayName"] == "Mr. Arindam Sarkar"


def test_real_pdf_uses_provider_and_preserves_mime_and_language(monkeypatch):
    captured = {}

    async def successful_extract(file_bytes, mime_type, language):
        captured.update(bytes=file_bytes, mime_type=mime_type, language=language)
        return DischargePlan.model_validate(sample_plan(language))

    monkeypatch.setenv("USE_DEBUG_STUB", "false")
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


def test_real_pdf_forwards_kannada_to_provider(monkeypatch):
    captured = {}

    async def successful_extract(file_bytes, mime_type, language):
        captured["language"] = language
        return DischargePlan.model_validate(sample_plan(language))

    monkeypatch.setenv("USE_DEBUG_STUB", "false")
    monkeypatch.setattr("app.main.extract_plan", successful_extract)
    response = client.post(
        "/api/v1/plans",
        data={"language": "kn"},
        files={"file": ("summary.pdf", b"pdf-bytes", "application/pdf")},
    )

    assert response.status_code == 200
    assert captured["language"] == "kn"
    assert response.json()["plan"]["outputLanguage"] == "kn"


def test_real_image_uses_provider(monkeypatch):
    async def successful_extract(file_bytes, mime_type, language):
        return DischargePlan.model_validate(sample_plan(language))

    monkeypatch.setenv("USE_DEBUG_STUB", "false")
    monkeypatch.setattr("app.main.extract_plan", successful_extract)
    response = client.post(
        "/api/v1/plans",
        data={"language": "bn"},
        files={"file": ("summary.jpg", b"image-bytes", "image/jpeg")},
    )

    assert response.status_code == 200
    assert response.json()["plan"]["outputLanguage"] == "bn"


@pytest.mark.parametrize(
    "exception",
    [
        GeminiUnavailableError("unavailable"),
        InvalidModelResponseError("invalid"),
    ],
)
def test_provider_errors_serve_fallback_safely(monkeypatch, exception):
    monkeypatch.setenv("USE_DEBUG_STUB", "false")
    async def failing_extract(*_args):
        raise exception

    monkeypatch.setattr("app.main.extract_plan", failing_extract)
    response = client.post(
        "/api/v1/plans",
        data={"language": "en"},
        files={"file": ("summary.pdf", b"pdf-bytes", "application/pdf")},
    )

    assert response.status_code == 200
    assert response.json()["meta"]["isFallback"] is True
    assert response.json()["plan"]["patient"]["displayName"] == "Mr. Arindam Sarkar"


def test_llm_failure_serves_fallback_plan(monkeypatch):
    monkeypatch.setenv("ENABLE_FALLBACK", "true")
    monkeypatch.setenv("USE_DEBUG_STUB", "false")

    async def failing_extract(*_args):
        raise GeminiUnavailableError("Gemini is currently unavailable")

    monkeypatch.setattr("app.main.extract_plan", failing_extract)
    response = client.post(
        "/api/v1/plans",
        data={"language": "en"},
        files={"file": ("summary.pdf", b"pdf-bytes", "application/pdf")},
    )

    assert response.status_code == 200
    data = response.json()
    assert data["meta"]["isFallback"] is True
    assert data["plan"]["patient"]["displayName"] == "Mr. Arindam Sarkar"
    assert data["plan"]["patient"]["hospital"] == "Aster WHITEFIELD HOSPITAL"
    assert len(data["plan"]["medications"]) == 7


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


def test_build_voice_system_prompt_includes_grounding_and_medications():
    from app.services.voice_service import build_voice_system_prompt
    from app.services.stub_response import FALLBACK_PLAN

    prompt = build_voice_system_prompt(FALLBACK_PLAN)
    assert "CarePath AI Voice Assistant" in prompt
    assert "Mr. Arindam Sarkar" in prompt
    assert "TAXIM-O" in prompt
    assert "STRICT GROUNDING" in prompt
    assert "EMERGENCY & WARNING SIGNS" in prompt


def test_voice_websocket_missing_api_key_returns_error(monkeypatch):
    monkeypatch.delenv("GEMINI_API_KEY", raising=False)
    monkeypatch.delenv("GOOGLE_API_KEY", raising=False)

    with client.websocket_connect("/ws/voice-chat/summary_123") as websocket:
        data = websocket.receive_json()
        assert data["type"] == "error"
        assert data["code"] == "MISSING_API_KEY"
