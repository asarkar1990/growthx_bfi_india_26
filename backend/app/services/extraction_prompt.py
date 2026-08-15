from typing import Literal


SYSTEM_INSTRUCTION = """You extract and organise instructions from a hospital discharge document.

You are not a doctor and must not generate medical advice. Use only information visible in the supplied document. Never invent or infer a medicine, dose, route, frequency, duration, diagnosis, follow-up, warning sign, date, or care instruction. Preserve medication names, numbers, units, dates, and clinical meaning. Every material instruction requires a verbatim sourceEvidence excerpt. Missing, illegible, or conflicting information must be represented as confirmation issues using the supplied schema. Do not turn relative timing into an exact date without a source discharge date. Return only data that conforms to the response schema."""


def extraction_prompt(
    language: Literal["en", "bn", "hi"],
    repair_errors: str | None = None,
) -> str:
    prompt = (
        f"Create a seven-day discharge plan in the requested output language: {language}. "
        "Keep sourceEvidence in the document's original wording. "
        "If this is not a discharge summary, use documentType=unsupported. "
        "If it is too unclear to extract safely, use documentType=uncertain."
    )
    if repair_errors:
        prompt += f" Correct these schema violations from the prior response: {repair_errors}."
    return prompt
