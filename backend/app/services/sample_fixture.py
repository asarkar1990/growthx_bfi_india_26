from copy import deepcopy

COPY = {
    "en": {"overview": "A seven-day recovery routine organised only from the discharge instructions.", "complete": "Take one tablet after breakfast as written.", "incomplete": "Take this tablet at bedtime; confirm how many days.", "walk": "Take a gentle 10-minute walk with support.", "issue": "Medicine duration is missing", "question": "How many days should Cefixime be taken?"},
    "bn": {"overview": "ডিসচার্জ নির্দেশনা থেকে সাজানো সাত দিনের সুস্থতার পরিকল্পনা।", "complete": "নির্দেশ অনুযায়ী সকালের খাবারের পরে একটি ট্যাবলেট নিন।", "incomplete": "রাতে ট্যাবলেটটি নিন; কত দিন নিতে হবে নিশ্চিত করুন।", "walk": "সহায়তা নিয়ে ধীরে ১০ মিনিট হাঁটুন।", "issue": "ওষুধের সময়কাল লেখা নেই", "question": "Cefixime কত দিন নিতে হবে?"},
    "hi": {"overview": "डिस्चार्ज निर्देशों से बनाई गई सात दिनों की रिकवरी योजना।", "complete": "लिखे निर्देश के अनुसार नाश्ते के बाद एक गोली लें।", "incomplete": "रात में यह गोली लें; कितने दिन लेना है, पुष्टि करें।", "walk": "सहारे के साथ धीरे-धीरे 10 मिनट चलें।", "issue": "दवा की अवधि नहीं लिखी है", "question": "Cefixime कितने दिन लेनी है?"},
}

def sample_plan(language: str) -> dict:
    text = COPY[language]
    return deepcopy({
        "schemaVersion": "1.0", "documentType": "discharge_summary", "outputLanguage": language,
        "patient": {"displayName": "Aarav", "dischargeDate": "2026-08-15", "hospital": "Swasthya Demo Hospital", "department": "General Medicine", "primaryConditionAsWritten": "Recovery after fever"},
        "overview": text["overview"],
        "medications": [
            {"id": "med-paracetamol", "name": "Paracetamol", "dose": "500 mg", "route": "oral", "frequency": "once daily after breakfast", "timing": ["morning"], "duration": "7 days", "specialInstructions": "After food", "simplifiedInstruction": text["complete"], "applicableDays": [1,2,3,4,5,6,7], "sourceEvidence": "Tab Paracetamol 500 mg orally once daily after breakfast for 7 days.", "page": 1, "confidence": "high", "status": "confirmed_from_source", "uncertaintyReason": None},
            {"id": "med-cefixime", "name": "Cefixime", "dose": "200 mg", "route": "oral", "frequency": "at bedtime", "timing": ["bedtime"], "duration": None, "specialInstructions": None, "simplifiedInstruction": text["incomplete"], "applicableDays": [1,2,3,4,5,6,7], "sourceEvidence": "Tab Cefixime 200 mg orally at bedtime. Duration: —", "page": 1, "confidence": "medium", "status": "needs_confirmation", "uncertaintyReason": "Duration is absent from the source."},
        ],
        "careInstructions": [{"id": "care-walk", "category": "activity", "instruction": "Walk gently for 10 minutes with support daily.", "simplifiedInstruction": text["walk"], "timing": "afternoon", "applicableDays": [1,2,3,4,5,6,7], "sourceEvidence": "Activity: gentle 10-minute supported walk daily.", "page": 2, "confidence": "high", "status": "confirmed_from_source", "uncertaintyReason": None}],
        "followUps": [{"id": "followup-1", "type": "appointment", "title": "General Medicine review", "date": None, "relativeTiming": "One week after discharge", "locationOrDepartment": "General Medicine OPD", "preparation": None, "sourceEvidence": "Follow up in General Medicine OPD one week after discharge.", "page": 2, "confidence": "high", "status": "confirmed_from_source", "uncertaintyReason": None}],
        "warningSigns": [
            {"id": "warning-1", "sign": "Fever above 102°F", "action": "Contact the care team", "sourceEvidence": "Seek help if fever rises above 102°F.", "page": 2, "confidence": "high", "status": "confirmed_from_source", "uncertaintyReason": None},
            {"id": "warning-2", "sign": "Difficulty breathing", "action": "Seek urgent care", "sourceEvidence": "Seek urgent care for difficulty breathing.", "page": 2, "confidence": "high", "status": "confirmed_from_source", "uncertaintyReason": None},
        ],
        "confirmationIssues": [
            {"id": "issue-duration", "severity": "important", "title": text["issue"], "questionForCareTeam": text["question"], "sourceEvidence": "Tab Cefixime 200 mg orally at bedtime. Duration: —"},
            {"id": "issue-illegible", "severity": "advisory", "title": "One handwritten line is unclear", "questionForCareTeam": "Please ask the care team to explain the handwritten instruction.", "sourceEvidence": "[illegible handwritten line]"},
        ],
        "extractionWarnings": ["One handwritten line was not converted into an instruction."],
    })
