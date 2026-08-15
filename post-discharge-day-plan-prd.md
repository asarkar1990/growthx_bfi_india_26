# Product Requirements Document: CarePath India

**Product:** Post-discharge Day-by-Day Plan  
**Artifact type:** Buildathon MVP specification  
**Platform:** Flutter mobile-web demo with a FastAPI backend boundary
**Version:** 1.2
**Target build window:** 4 hours  
**Primary audience:** AI coding agents and engineers implementing the demo

---

## 1. Product summary

CarePath India converts a hospital discharge summary into a simple, day-by-day recovery plan in the patient's preferred language.

The user uploads or photographs a discharge summary, selects a language, and receives:

- a daily medication schedule;
- follow-up appointments and tests;
- diet, activity, and wound-care instructions;
- warning signs copied or faithfully simplified from the source;
- uncertain or missing information that must be confirmed with a clinician; and
- a printable seven-day checklist.

The product is an **instruction organiser**, not a diagnostic or treatment system. It must never invent, modify, recommend, or discontinue treatment.

### Platform decision: Flutter

The project currently pins **Flutter 3.44.9** through FVM and declares Dart `^3.13.0` in `app/pubspec.yaml`. It is mobile-web-first and intended to run in Chrome for the live demo; the repository also includes the generated Android host project. iOS is not configured or tested in this project.

At the time of this update, Flutter 3.44.9 ships Dart 3.12.2, so package resolution cannot succeed until the FVM Flutter version is upgraded to one that supplies Dart 3.13 or later (for example, the previously intended Flutter 3.47.0). This is a project configuration gap, not a supported demo capability.

The app is a single dark-themed Material experience backed by bundled synthetic data, which makes the demo deterministic. A FastAPI service provides the validated server boundary for future real-document processing, but no multimodal provider is configured in the current demo.

## 2. Problem

Discharge summaries are frequently dense, technical, written in English, and difficult to translate into everyday actions. Patients and caregivers must manually work out what to do, when to do it, and which instructions are important. This creates avoidable confusion during a vulnerable transition from hospital to home.

### Core user problem

> “I have been given several pages of medical instructions. Tell me what I need to do each day, in language I understand, without changing what the hospital said.”

### Why this matters for the demo

The application creates an immediately visible transformation:

`complex discharge document -> structured, understandable recovery plan`

This supports a strong three-minute demonstration while remaining achievable within the four-hour build window.

## 3. Goals and success criteria

### MVP goals

1. Accept one discharge-summary image or PDF.
2. Extract supported discharge instructions into a strict structured schema.
3. Generate a seven-day plan in English, Bengali, or Hindi.
4. Preserve traceability between each generated instruction and the source text.
5. Clearly flag uncertainty, missing details, and conflicting instructions.
6. Provide a polished, personalised mobile experience suitable for a live demo.
7. Let the user review privacy-safe reminder candidates from confirmed plan items.

### Demo success criteria

The demo is successful when a first-time user can:

1. upload the provided sample document;
2. select Bengali or Hindi;
3. generate a readable plan within 20 seconds;
4. understand today's actions without reading the original document; and
5. identify which items require confirmation with a doctor.

### Suggested product metrics for a future pilot

- Percentage of uploaded documents successfully converted into a valid plan
- Percentage of plan items with source evidence
- Medication extraction precision on a clinician-reviewed test set
- Percentage of users who correctly answer “What must I do today?”
- Percentage of users who notice an intentionally flagged uncertainty
- Time from upload to usable plan

These are future validation metrics. The buildathon MVP does not require analytics.

## 4. Users and primary scenario

### Primary user

A patient or family caregiver in India who received a discharge summary containing English medical terminology and needs a simpler plan in a familiar language.

### Secondary user

A nurse or discharge coordinator who wants to provide patients with a more accessible instruction sheet.

### Primary scenario

1. A caregiver receives a two-page discharge summary.
2. They open CarePath India on a phone.
3. They upload a photo or PDF and choose Bengali.
4. They choose the bundled synthetic demo document and create the plan.
5. The caregiver generates a seven-day plan.
6. The plan shows daily tasks, source excerpts, and confirmation warnings.

## 5. Scope

### Current demo scope (implemented)

- File selection for one image or PDF
- Server-side file validation at the FastAPI boundary
- Language selection: English, Bengali, Hindi
- Pydantic validation of the deterministic sample response and strict Dart parsing
- Review screen showing extracted patient/discharge context
- Seven-day plan grouped by day and time of day
- Sections for medications, care/activity, follow-ups/tests, and warning signs
- Visible uncertainty and “confirm with your doctor” states
- Source evidence accessible for every material instruction
- Loading, failure, and retry states
- One bundled sample discharge summary and deterministic demo fallback
- Responsive mobile-web UI with a custom dark Material theme
- Language-specific synthetic plan content in English, Bengali, and Hindi
- Reminder-candidate review UI; no notification permission or scheduling

### Deferred future work

- Print-friendly plan
- Download plan as JSON
- Edit/correct extracted text before plan generation
- Remember selected language and accessibility preferences on device
- “Today” highlight and task checkboxes stored locally
- Reminder management screen with enable, disable, and reschedule controls
- Caregiver mode with larger text and simplified navigation
- Real server-side multimodal extraction and provider configuration
- Client API integration for real uploads
- Persisted preferences and local notification scheduling
- Android release packaging and HTTPS backend deployment

### Explicit non-goals

- Diagnosis, symptom assessment, or medical recommendations
- Medication interaction checking
- Medication substitutions or dosage calculations
- OCR perfection for handwritten prescriptions
- User accounts, authentication, databases, or cloud history
- Hospital/EHR integration
- Remote push notifications, SMS, WhatsApp, or server-driven reminders
- Multiple patient profiles
- Real-time clinician communication
- Production compliance claims
- Supporting every Indian language in the MVP

Remote notifications remain out of scope. Local notifications and on-device preferences are also deferred: the required packages and platform integrations are not present in the current demo.

## 6. Product principles and safety requirements

### 6.1 Source fidelity

- Every medication, follow-up, test, restriction, warning sign, and care instruction must have a `sourceEvidence` value copied from the uploaded document.
- The model must not infer a treatment instruction from general medical knowledge.
- Simplification and translation may change wording but not clinical meaning.

### 6.2 Uncertainty over confidence theatre

- Missing dose, route, frequency, date, or duration must remain `null`; never fill it with a likely value.
- Illegible or ambiguous content must be flagged as `needs_confirmation`.
- Conflicting instructions must be shown together and flagged; the system must not decide which one is correct.

### 6.3 No medical advice

Display this message on upload and result screens:

> CarePath organises instructions from your discharge document. It does not provide medical advice or replace your doctor. Confirm unclear or conflicting information with your care team.

### 6.4 Privacy for the demo

- Do not persist uploaded documents or generated plans to a database.
- Process the document in memory and discard it after the request.
- Do not log document contents, patient names, IDs, phone numbers, or model prompts containing patient data.
- The bundled fixture must use synthetic patient information.

## 7. User experience

### Screen 1: Upload

**Purpose:** Get a document and language with minimal friction.

Required elements:

- Product name and one-line value proposition
- Upload drop zone with camera-friendly file picker
- Accepted types: PDF, PNG, JPG, JPEG
- Maximum file size: 10 MB
- Preferred-language selector
- Privacy note and medical disclaimer
- “Use sample document” button
- Primary action: **Create my recovery plan**

Validation:

- Prevent submission without a file or selected sample.
- Reject unsupported type or oversized file with an actionable message.

### Screen 2: Processing

Show a three-stage progress indicator:

1. Reading the document
2. Organising instructions
3. Creating the day-by-day plan

Use honest indeterminate progress. Do not display fabricated percentages.

### Screen 3: Review and plan

Display, in order:

1. Patient/discharge summary header
2. Prominent items requiring confirmation
3. Day selector: Day 1 through Day 7
4. Selected day's timeline: morning, afternoon, evening, bedtime, anytime
5. Follow-ups and tests
6. Warning signs from the document
7. Source-evidence drawer
8. Print action, if implemented
9. **Enable private reminders** action after the user has reviewed confirmation issues

Each plan item must display:

- task or medicine name;
- timing and duration when stated;
- simplified instruction in the selected language;
- status badge when confirmation is required; and
- an expandable “From your document” source excerpt.

### Screen 4: Reminder review (implemented UI; scheduling deferred)

**Purpose:** Turn confirmed, time-specific plan items into a personalised recovery routine.

The current app presents eligible reminder candidates after a valid sample plan is available. It does not request notification permission, persist preferences, or schedule notifications. The following behaviour is a future implementation requirement:

- Enter this screen only after a valid plan is available.
- Explain that reminders stay on the device and can be changed or disabled.
- Show only items with `confirmed_from_source`, explicit timing, and applicable days.
- Let the user enable or disable each reminder before scheduling.
- Ask for operating-system notification permission only when the user taps **Enable reminders**.
- If permission is denied, keep the care plan fully usable and show how to enable permission later.
- Never schedule reminders for `needs_confirmation`, `conflict`, or unclear timing.
- Use neutral notification copy such as “CarePath reminder: Check your recovery plan for the scheduled instruction.” Do not expose medicine names or diagnoses on the lock screen by default.
- Store scheduled notification identifiers locally so reminders can be cancelled or replaced.

For a future live demo, a **Preview reminder in 10 seconds** action may use synthetic sample data. It must be clearly labelled as a demo preview and must not change the medical schedule.

### Empty and error states

- **Unreadable document:** Ask the user to upload a clearer image or use the sample.
- **Not a discharge summary:** Explain that no usable discharge instructions were detected.
- **Schema validation failure:** Offer one automatic retry, then show a safe failure state.
- **Provider unavailable:** Allow the sample fixture to demonstrate the complete UI.
- **Partial extraction:** Show reliable items and clearly label omitted/uncertain sections.

## 8. Functional requirements

### FR-01: Select document

The client uses `file_picker` to select one file and retains its display name for the demo flow. The FastAPI endpoint accepts `multipart/form-data` with `language`, `useSample`, and an optional `file`; it validates supported PDF/PNG/JPG/JPEG uploads and the 10 MB limit when invoked.

### FR-02: Select output language

Supported language codes:

- `en` - English
- `bn` - Bengali
- `hi` - Hindi

The language affects simplified instructions and UI plan content. Medication names, measurements, and source evidence must remain faithful to the source.

### FR-03: Provide structured instructions

The current Flutter flow loads the language-specific bundled plan fixture. The FastAPI endpoint returns an equivalent deterministic Pydantic-validated sample response when `useSample=true`. Real document uploads return the safe `MODEL_UNAVAILABLE` error until a backend-only multimodal provider adapter is configured.

### FR-04: Validate and parse

The current backend validates the sample response with Pydantic and the Flutter app parses it into explicit Dart models. When a provider is added, the backend must:

1. parse the model response;
2. validate it with Pydantic;
3. reject unsupported or unsafe shapes;
4. normalise IDs and ordering without changing clinical content; and
5. return a typed response to the client.

### FR-05: Display a seven-day plan

Recurring instructions must appear on each applicable day. One-time events must appear only on their relevant day. When an exact schedule cannot be derived from the source, show the item under “Schedule unclear” instead of guessing.

### FR-06: Preserve evidence

Every material plan item must expose its original `sourceEvidence`. Items without evidence must not appear as confirmed instructions.

### FR-07: Confirmation queue

The result must provide a consolidated list of:

- ambiguous text;
- missing required medication details;
- conflicting instructions; and
- dates or durations that could not be resolved.

### FR-08: Use sample fixture

The sample flow must return a deterministic valid response even if the external AI provider is unavailable. It must be visually marked as demo data.

### FR-09: Personalise the plan (deferred)

When a patient display name exists, use it only in private in-app headings such as “Arun's recovery plan.” Do not include the name in lock-screen notification content. Persist language, text-size preference, and reminder privacy preference locally; do not persist the uploaded document.

### FR-10: Schedule local reminders (deferred)

The Flutter client must derive eligible reminders from confirmed plan items, request notification permission at the moment of user intent, and schedule them using the device time zone.

Eligibility rules:

1. `status == confirmed_from_source`;
2. at least one applicable day exists;
3. timing can be mapped to an explicit user-approved clock time; and
4. the item is not marked ambiguous or conflicting.

Default time-of-day mappings are UI suggestions, not medical interpretations:

- morning: 8:00 AM
- afternoon: 1:00 PM
- evening: 6:00 PM
- bedtime: 9:00 PM

The user must review and approve these clock times before scheduling. `anytime` items are never scheduled automatically.

### FR-11: Manage reminder lifecycle (deferred)

- Keep a local mapping of plan-item ID to notification ID.
- Re-generating or replacing a plan must prompt before cancelling existing reminders.
- Disabling reminders must cancel all CarePath notifications.
- Expired Day 1-7 reminders must not repeat beyond the plan window.

## 9. Technical architecture

### Implemented stack

- **Flutter client:** Flutter `3.44.9` pinned by `.fvmrc`, with Dart `^3.13.0` declared by the app, Material UI, and a custom dark `ThemeData`. The pinned SDK currently supplies Dart 3.12.2 and must be upgraded before dependency resolution and Flutter verification can run.
- **Target:** Mobile-web-first, demonstrated with Chrome. The generated Android host project is included; iOS, an Android release build, and hosting are not part of the verified demo.
- **State management:** `flutter_bloc` `9.1.1` with one `CarePlanCubit`, `CarePlanState`, and `Equatable` `2.0.7` value equality.
- **Navigation:** One `MaterialApp` rooted at `UploadScreen`; phase changes within the Cubit select the upload, processing, plan, and reminder-review views. No router package is used.
- **File input:** `file_picker` `10.3.2` for selecting a document.
- **Demo data:** A synthetic discharge-summary PDF plus `sample_plan_en.json`, `sample_plan_bn.json`, and `sample_plan_hi.json` in Flutter assets, loaded with `rootBundle`.
- **Backend:** Python FastAPI `0.116.1`, Pydantic `2.11.7`, `python-multipart` `0.0.20`, Uvicorn `0.35.0`, pytest `8.4.1`, and HTTPX `0.28.1`.
- **Testing:** Flutter unit and widget tests, plus pytest endpoint/schema tests.

`Dio`, `go_router`, `shared_preferences`, `flutter_local_notifications`, `timezone`, Firebase, and a model-provider SDK are not dependencies of this project. They remain possible future additions, not part of the current stack.

### High-level flow

```text
Flutter app
  -> choose a file or the synthetic demo document and output language
  -> current demo: load the matching bundled JSON fixture with rootBundle
  -> future client integration: POST /api/v1/plans (multipart language, useSample, optional file)
FastAPI
  -> useSample=true: validate and return deterministic Pydantic sample data
  -> real upload: validate type and 10 MB limit, then return safe MODEL_UNAVAILABLE
Flutter app
  -> parse typed DTO
  -> render seven-day plan, source evidence, and confirmation issues
  -> show reminder candidates only; notification scheduling is deferred
```

### Security boundary

The Flutter binary must never contain an AI provider API key. If a provider is configured later, all model calls must occur in the FastAPI backend and its secrets must remain in backend environment variables. The current backend contains no provider credentials or provider call.

The backend must not persist uploads or log document contents. Use short request timeouts, bounded file size, and generated request IDs that contain no patient information.

### Actual project structure

```text
app/
  lib/
    main.dart
    src/
      care_plan_cubit.dart
      models.dart
      upload_screen.dart
      plan_screen.dart
      theme.dart
  assets/samples/
    synthetic_discharge_summary.pdf
    sample_plan_en.json
    sample_plan_bn.json
    sample_plan_hi.json
  test/
    care_plan_cubit_test.dart
    models_test.dart
    widget_test.dart
backend/
  app/
    main.py
    models/discharge_plan.py
    services/sample_fixture.py
  tests/
    test_api.py
```

Keep the single `CarePlanCubit` flow and lightweight file layout unless a new capability justifies a larger boundary. No database, authentication, background server, preferences service, or notification framework is currently implemented.

## 10. Data contracts

The JSON response contract below is authoritative. Define it once as Pydantic models in the backend and mirror it with immutable Dart DTOs in Flutter. The agent may use `json_serializable` if code generation already works reliably; otherwise implement explicit `fromJson` parsing. It must not weaken required safety fields.

```python
from datetime import date
from enum import Enum
from pydantic import BaseModel, ConfigDict, Field

class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

class Confidence(str, Enum):
    high = "high"
    medium = "medium"
    low = "low"

class ItemStatus(str, Enum):
    confirmed = "confirmed_from_source"
    needs_confirmation = "needs_confirmation"
    conflict = "conflict"

class Evidence(StrictModel):
    sourceEvidence: str = Field(min_length=1)
    page: int | None = Field(default=None, ge=1)
    confidence: Confidence
    status: ItemStatus
    uncertaintyReason: str | None = None

class Medication(Evidence):
    id: str = Field(min_length=1)
    name: str = Field(min_length=1)
    dose: str | None = None
    route: str | None = None
    frequency: str | None = None
    timing: list[str]  # morning|afternoon|evening|bedtime|anytime
    duration: str | None = None
    specialInstructions: str | None = None
    simplifiedInstruction: str = Field(min_length=1)
    applicableDays: list[int]

class CareInstruction(Evidence):
    id: str
    category: str  # diet|activity|wound_care|equipment|other
    instruction: str
    simplifiedInstruction: str
    timing: str
    applicableDays: list[int]

class FollowUp(Evidence):
    id: str
    type: str  # appointment|test|procedure|other
    title: str
    date: date | None = None
    relativeTiming: str | None = None
    locationOrDepartment: str | None = None
    preparation: str | None = None

class WarningSign(Evidence):
    id: str
    sign: str
    action: str | None = None

class ConfirmationIssue(StrictModel):
    id: str
    severity: str  # important|advisory
    title: str
    questionForCareTeam: str
    sourceEvidence: str | None = None

class Patient(StrictModel):
    displayName: str | None = None
    dischargeDate: date | None = None
    hospital: str | None = None
    department: str | None = None
    primaryConditionAsWritten: str | None = None

class DischargePlan(StrictModel):
    schemaVersion: str = "1.0"
    documentType: str  # discharge_summary|unsupported|uncertain
    outputLanguage: str  # en|bn|hi
    patient: Patient
    overview: str
    medications: list[Medication]
    careInstructions: list[CareInstruction]
    followUps: list[FollowUp]
    warningSigns: list[WarningSign]
    confirmationIssues: list[ConfirmationIssue]
    extractionWarnings: list[str]
```

The implementation must tighten comment-listed string fields with `Literal` or enums and validate every `applicableDays` value as 1-7. The abbreviated model above defines field semantics; it is not permission to accept arbitrary values.

Flutter must represent the same enum values and reject unknown safety-critical enum values as a parsing failure. A client parsing failure must show a safe retry state, never a partially parsed plan.

### API contract

#### `POST /api/v1/plans`

Request: `multipart/form-data`

- `file`: required unless `useSample=true`
- `language`: `en | bn | hi`
- `useSample`: optional boolean string

Success response: HTTP `200`

```json
{
  "plan": {},
  "meta": {
    "isSample": false,
    "processingTimeMs": 8400
  }
}
```

Error response:

```json
{
  "error": {
    "code": "UNREADABLE_DOCUMENT",
    "message": "We could not read enough of this document. Upload a clearer image or try the sample."
  }
}
```

Allowed error codes:

- `INVALID_FILE`
- `FILE_TOO_LARGE`
- `UNSUPPORTED_DOCUMENT`
- `UNREADABLE_DOCUMENT`
- `MODEL_UNAVAILABLE`
- `INVALID_MODEL_RESPONSE`
- `INTERNAL_ERROR`

Do not return stack traces, provider responses, prompts, or document text in error payloads.

## 11. AI extraction specification

### System instruction

Use the following behaviour as the basis of `extraction-prompt.ts`:

```text
You extract and organise instructions from a hospital discharge document.

You are not a doctor and must not generate medical advice.

Rules:
1. Use only information visible in the supplied document.
2. Never invent or infer a medicine, dose, route, frequency, duration,
   diagnosis, follow-up, warning sign, date, or care instruction.
3. If a value is absent or illegible, return null and create a confirmation issue.
4. Preserve medication names, numbers, units, dates, and clinical meaning.
5. Translate or simplify only explanatory text into the requested language.
6. Every material instruction must include a verbatim sourceEvidence excerpt.
7. If two source instructions conflict, preserve both and mark them conflict.
8. Do not convert relative timing into an exact date unless dischargeDate is explicit.
9. Warning signs and emergency actions must come from the source document only.
10. Return JSON matching the supplied schema and nothing else.
```

### Generation strategy

Prefer a single structured extraction call for the MVP. Do not create a multi-agent workflow. Set temperature low. Use provider-enforced JSON/schema output when available, then validate locally with Pydantic regardless.

If validation fails:

1. Perform at most one repair retry using the validation errors.
2. Do not include additional patient data beyond the original request context.
3. If retry fails, return `INVALID_MODEL_RESPONSE`.

### Schedule normalisation rules

- The model extracts facts; deterministic application code expands them into the seven-day display.
- `applicableDays` must contain only values 1-7.
- An item with unclear applicable days belongs in the confirmation queue, not every day.
- Do not infer that “BD” means particular clock times; display the frequency as written unless the document states times.
- Keep “as needed” instructions under `anytime` and preserve stated limits.

## 12. UI and visual requirements

### Design direction

- Calm, trustworthy, and accessible rather than clinical or futuristic
- Mobile-first layout with a maximum desktop content width around 960 px
- High contrast and minimum 16 px body text
- Large touch targets
- Green/blue primary palette; amber for uncertainty; red only for source-backed urgent warning signs
- Avoid animated medical imagery, chat interfaces, or dashboard complexity

### Accessibility

- All functionality must be keyboard accessible.
- Upload input must have a visible label.
- Progress status must use an appropriate live region.
- Tabs must use correct tab semantics or simple buttons with clear selected state.
- Status must never rely on colour alone.
- Bengali and Hindi text must use a font stack that renders their scripts correctly.

## 13. Current demo acceptance criteria

### Upload and processing

- [x] A user can select a supported file or use the bundled synthetic document.
- [x] The FastAPI endpoint rejects unsupported and oversized uploads when called.
- [x] The sample workflow functions without an external model call or credentials.
- [x] The processing UI remains responsive while loading bundled fixture data.

### Extraction safety

- [x] Bundled plans are validated by Pydantic at the backend boundary and strictly parsed by Dart models.
- [x] Sample items expose source evidence and confirmation issues.
- [x] The backend returns safe error messages without uploaded document contents.

### Plan experience

- [x] The result displays Day 1 through Day 7, grouped by time of day.
- [x] Users can reveal source evidence and see confirmation issues before the daily plan.
- [x] English, Bengali, and Hindi fixtures are available.
- [x] The layout is designed for mobile web and can be run in Chrome.

### Deferred notification and preference work

No notification or local-preference acceptance criteria apply to the current demo. These require additional packages, platform configuration, and tests before being enabled.

### Error handling

- [x] Unsupported uploads and unavailable real processing produce safe actionable errors.
- [x] Provider-unavailable responses do not expose document contents or provider details.

## 14. Test fixtures and automated coverage

Create a synthetic discharge summary containing:

- one medicine with complete dose/frequency/duration;
- one medicine with missing duration;
- one care instruction;
- one follow-up expressed as relative timing;
- two source-backed warning signs; and
- one deliberately unclear line.

Expected fixture behaviour:

- Complete medicine appears in the daily timeline.
- Incomplete medicine appears with `needs_confirmation`.
- Relative follow-up remains relative unless a discharge date is present.
- Unclear line creates a confirmation issue and is not converted into a confirmed instruction.

Implemented automated coverage:

1. Flutter Cubit tests cover language selection, document/sample selection, processing states, and fixture loading.
2. Flutter model tests cover typed plan parsing and safety-related fields.
3. Flutter widget tests cover the primary app shell and sample-plan flow.
4. Backend tests cover health, deterministic sample responses, file validation, the 10 MB limit, and the safe unavailable-provider response.

## 15. Implementation status

### Implemented

- Flutter project with FVM-pinned SDK, mobile-web target, dark Material UI, `CarePlanCubit`, explicit Dart models, and bundled fixtures.
- Deterministic English, Bengali, and Hindi sample-plan flow with processing, plan, source-evidence, confirmation, and reminder-candidate screens.
- FastAPI `POST /api/v1/plans` endpoint with language/form parsing, file validation, Pydantic-validated sample responses, and safe unavailable-provider errors.

### Deferred

- Client-to-backend networking, a multimodal AI provider adapter, and real document extraction.
- Notification scheduling, permissions, preview notifications, and persisted preferences.
- Android release builds, iOS support, and HTTPS deployment.

## 16. Verification commands

Run the following commands from the repository root to verify the implemented demo:

```bash
cd app && fvm dart format --set-exit-if-changed . && fvm flutter analyze && fvm flutter test
cd backend && .venv/bin/pytest -q
cd app && fvm flutter build web --release
```

These commands require FVM to resolve a Flutter SDK with Dart 3.13 or later. With the current Flutter 3.44.9 pin, `fvm flutter pub get` fails before analysis or tests can run.

### Agent constraints

- Do not modify the authoritative data contract without explaining why.
- Do not add a database, authentication, Docker, queues, analytics, or orchestration frameworks.
- Do not call a model from Flutter client code or bundle provider credentials in the app.
- Do not use unvalidated model output in the UI.
- Do not fabricate fallback medical content. Only the bundled synthetic fixture may be deterministic.
- Do not log document contents.
- Do not silently swallow extraction uncertainty.
- If notification support is added, do not schedule unclear, conflicting, or `anytime` instructions.
- If notification support is added, do not expose patient, condition, or medicine names by default.
- Prefer small pure functions and typed data over generalized abstractions.
- Use comments only for safety-critical or non-obvious reasoning.
- Keep deferred integrations out of the demo unless their tests and platform builds pass.

### Definition of done

The current demo is done when:

- the sample journey works end-to-end;
- the bundled synthetic document can produce the matching language-specific plan without a model call;
- all returned data passes backend Pydantic validation and strict Dart parsing;
- uncertainty and source evidence are visible;
- no secret is exposed to the client;
- required tests pass;
- `fvm dart format --set-exit-if-changed .`, `fvm flutter analyze`, `fvm flutter test`, backend pytest, and `fvm flutter build web --release` succeed; and
- the project can be demonstrated reliably within three minutes.

## 17. Demo script

### 0:00-0:30 - Problem

“A patient leaves the hospital with several pages of technical instructions. At home, the family must work out what to do each day, often across a language barrier.”

### 0:30-1:00 - User and input

Open CarePath India, select Bengali, and upload the synthetic discharge summary.

### 1:00-2:30 - Transformation

Show:

- the day-by-day medication and care timeline;
- the missing medication duration flagged for confirmation;
- the Bengali simplified instruction; and
- the original source excerpt behind a plan item.

Then open reminder review and demonstrate that confirmed and unclear instructions remain visibly distinct. Explain that notification permission, scheduling, and the 10-second preview are deferred from this demo.

### 2:30-3:00 - Trust and impact

“The product does not diagnose or invent instructions. It organises the synthetic discharge plan, preserves evidence, and tells the family what must be confirmed.”

## 18. Future roadmap

After user and clinician validation—not during the buildathon—the product could add:

- clinician review and approval;
- additional Indian languages;
- OCR quality scoring and human correction;
- remote caregiver sharing and coordinated reminder delivery;
- hospital discharge-workflow integration;
- longitudinal care-plan updates; and
- privacy, security, and regulatory controls appropriate for production healthcare use.

---

## Final product decision

For the buildathon, optimise for **one trustworthy transformation**, not feature breadth:

> Select one synthetic discharge summary and receive a traceable, multilingual seven-day plan that separates confirmed instructions from information requiring clinician confirmation. Local reminders are a future enhancement.
