import asyncio
import base64
import json
import logging
import os
from typing import Any, Dict

from fastapi import WebSocket, WebSocketDisconnect
from google import genai
from google.genai import types

logger = logging.getLogger(__name__)


def build_voice_system_prompt(plan_data: Dict[str, Any]) -> str:
    """Builds a strict clinical grounding system prompt for the Gemini Live Voice Agent."""
    patient = plan_data.get("patient", {})
    patient_name = patient.get("displayName", "Patient")
    hospital = patient.get("hospital", "Hospital")
    overview = plan_data.get("overview", "")
    medications = plan_data.get("medications", [])
    care_instructions = plan_data.get("careInstructions", [])
    follow_ups = plan_data.get("followUps", [])
    warning_signs = plan_data.get("warningSigns", [])
    language = plan_data.get("outputLanguage", "en")

    lang_instructions = {
        "en": "Respond in clear, warm, spoken English.",
        "hi": "Respond in conversational Hindi (हिन्दी) in a caring tone.",
        "bn": "Respond in conversational Bengali (বাংলা) in a caring tone.",
        "kn": "Respond in conversational Kannada (ಕನ್ನಡ) in a caring tone.",
    }.get(language, "Respond in clear spoken English.")

    meds_summary = []
    for m in medications:
        name = m.get("name", "")
        dose = m.get("dose", "")
        freq = m.get("frequency", "")
        timing = ", ".join(m.get("timing", []))
        instructions = m.get("simplifiedInstruction", "")
        source = m.get("sourceEvidence", "")
        meds_summary.append(
            f"- {name} {dose} (Timing: {timing}, Frequency: {freq}): {instructions} [Evidence: '{source}']"
        )

    followup_summary = [
        f"- {f.get('title', '')} ({f.get('relativeTiming', '') or f.get('date', '')}): {f.get('preparation', 'No prep')} [Evidence: '{f.get('sourceEvidence', '')}']"
        for f in follow_ups
    ]

    warnings_summary = [
        f"- Sign: {w.get('sign', '')} -> Action: {w.get('action', '')} [Evidence: '{w.get('sourceEvidence', '')}']"
        for w in warning_signs
    ]

    return f"""You are the CarePath AI Voice Assistant speaking with {patient_name} or their caregiver regarding their hospital discharge recovery plan from {hospital}.

LANGUAGE DIRECTIVE:
{lang_instructions}

CLINICAL GROUNDING RULES:
1. STRICT GROUNDING: You MUST only answer questions based on the extracted discharge summary details below. Do NOT invent dosages, medicines, or medical advice not present in the document.
2. VERBATIM ACCURACY: When discussing medications or instructions, accurately reference the exact details (timing, food instructions, duration).
3. EMERGENCY & WARNING SIGNS: If the user mentions experiencing any alarm symptoms (fever, bleeding, severe vomiting, shortness of breath, etc.), immediately advise them to take the emergency action specified in the warning signs and seek urgent medical care.
4. BOUNDARIES & DISCLAIMER: You are an informational assistant organizing the doctor's instructions. If the user asks for new medical diagnoses, prescription modifications, or unlisted symptom treatments, politely state that you cannot prescribe or change medications and direct them to contact their doctor or hospital.
5. CONCISE SPOKEN OUTPUT: Keep voice responses concise, conversational, reassuring, and easy to understand when spoken aloud.

PATIENT CLINICAL SUMMARY:
{overview}

CONFIRMED MEDICATIONS:
{chr(10).join(meds_summary) if meds_summary else "No medications listed."}

CARE & DIETARY INSTRUCTIONS:
{json.dumps(care_instructions, ensure_ascii=False)}

FOLLOW-UPS & LAB INVESTIGATIONS:
{chr(10).join(followup_summary) if followup_summary else "No follow-ups listed."}

WARNING SIGNS & EMERGENCY ACTIONS:
{chr(10).join(warnings_summary) if warnings_summary else "No specific warning signs listed."}
"""


async def stream_gemini_live_session(
    websocket: WebSocket,
    plan_data: Dict[str, Any],
    api_key: str,
) -> None:
    """Manages the bidirectional WebSocket bridge between Flutter client and Gemini Live API."""
    client = genai.Client(api_key=api_key, http_options={"api_version": "v1alpha"})
    system_prompt = build_voice_system_prompt(plan_data)

    config = types.LiveConnectConfig(
        response_modalities=[types.Modality.AUDIO],
        system_instruction=types.Content(
            parts=[types.Part.from_text(text=system_prompt)]
        ),
        speech_config=types.SpeechConfig(
            voice_config=types.VoiceConfig(
                prebuilt_voice_config=types.PrebuiltVoiceConfig(
                    voice_name="Puck"
                )
            )
        ),
    )

    live_model = os.getenv("GEMINI_LIVE_MODEL", "gemini-2.5-flash-native-audio-latest")

    try:
        async with client.aio.live.connect(
            model=live_model,
            config=config,
        ) as session:
            # Notify client that session is ready
            await websocket.send_json(
                {"type": "status", "status": "ready", "message": "Voice session active"}
            )

            async def client_to_gemini():
                try:
                    while True:
                        data = await websocket.receive()
                        if "bytes" in data and data["bytes"]:
                            # Send real-time raw PCM audio chunk to Gemini
                            await session.send_realtime_input(
                                media_chunks=[types.Blob(data=data["bytes"], mime_type="audio/pcm;rate=16000")]
                            )
                        elif "text" in data and data["text"]:
                            payload = json.loads(data["text"])
                            msg_type = payload.get("type")
                            if msg_type == "text":
                                text_content = payload.get("text", "")
                                if text_content:
                                    await session.send_client_content(
                                        turns=[types.Content(role="user", parts=[types.Part.from_text(text=text_content)])],
                                        turn_complete=True,
                                    )
                            elif msg_type == "audio":
                                audio_bytes = base64.b64decode(payload.get("data", ""))
                                await session.send_realtime_input(
                                    media_chunks=[types.Blob(data=audio_bytes, mime_type="audio/pcm;rate=16000")]
                                )
                except WebSocketDisconnect:
                    logger.info("Client disconnected from voice chat")
                except asyncio.CancelledError:
                    pass

            async def gemini_to_client():
                try:
                    async for response in session.receive():
                        server_content = response.server_content
                        if server_content is not None:
                            model_turn = server_content.model_turn
                            if model_turn is not None:
                                for part in model_turn.parts:
                                    if part.text:
                                        await websocket.send_json(
                                            {
                                                "type": "transcript",
                                                "role": "model",
                                                "text": part.text,
                                            }
                                        )
                                    if part.inline_data:
                                        # Stream binary audio chunk
                                        await websocket.send_bytes(part.inline_data.data)
                            if server_content.turn_complete:
                                await websocket.send_json(
                                    {"type": "turn_complete"}
                                )
                except WebSocketDisconnect:
                    logger.info("Client disconnected from voice session")
                except asyncio.CancelledError:
                    pass

            # Run client listener and gemini listener concurrently
            await asyncio.gather(client_to_gemini(), gemini_to_client())

    except Exception as e:
        logger.error(f"Error in Gemini Live voice session: {e}", exc_info=True)
        try:
            await websocket.send_json(
                {
                    "type": "error",
                    "code": "VOICE_SESSION_ERROR",
                    "message": f"Gemini Live session error: {str(e)}",
                }
            )
        except Exception:
            pass
