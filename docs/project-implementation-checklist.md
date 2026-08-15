# CarePath India — implementation checklist

Last reviewed: 15 August 2026  
Basis: `post-discharge-day-plan-prd.md` and the current repository implementation.

## Status legend

- [x] Complete in the repository
- [~] Partially implemented or needs live/integration verification
- [ ] Not implemented / deferred
- [!] Decision or documentation gap

## 1. Discharge-document intake and plan creation [~]

### App

- [x] Let a user choose one PDF, PNG, JPG, or JPEG file with `file_picker`.
- [x] Show the selected file name and offer the bundled synthetic document.
- [x] Let the user select English, Bengali, or Hindi.
- [x] Prevent plan creation until a document or sample has been selected.
- [x] Show the required medical-safety disclaimer on the upload screen.
- [~] Restrict the picker to supported extensions; client-side 10 MB validation is not implemented.
- [~] A selected real file currently triggers the matching bundled JSON fixture, rather than uploading the selected bytes to the API.

### Backend

- [x] Provide `POST /api/v1/plans` with multipart language, `useSample`, and optional file fields.
- [x] Accept PDF, PNG, JPG, and JPEG uploads only, checking both extension and MIME type.
- [x] Enforce the 10 MB upload limit.
- [x] Return safe `INVALID_FILE` and `FILE_TOO_LARGE` error envelopes.
- [x] Keep upload bytes in request memory; no database or document logging is implemented.

## 2. Safe extraction and multilingual structured plan [~]

### App

- [x] Load deterministic English, Bengali, and Hindi synthetic plans from bundled assets.
- [x] Parse known plan-status and timing enum values strictly, failing on unknown values.
- [~] Parse the core plan shape, evidence, and applicable-day bounds; the Dart model does not yet validate every contract field (for example confidence, document type, categories/types, or all required string/list shapes).
- [~] Use only the first timing when a medication contains multiple timings; the contract supports a list, so all timings are not yet represented in the daily timeline.
- [x] Show a safe retry state if fixture loading or parsing fails.

### Backend

- [x] Define strict Pydantic data models with forbidden extra fields, supported enums, evidence requirements, and 1–7 day bounds.
- [x] Require an uncertainty reason for non-confirmed evidence.
- [x] Return deterministic, Pydantic-validated sample plans for all three languages without a provider credential.
- [x] Implement a server-only Gemini extraction adapter with a schema-constrained response, 25-second SDK timeout, and one validation-repair retry.
- [x] Validate provider output with Pydantic before returning it.
- [x] Map unreadable/unsupported documents, provider unavailability, and invalid model responses to safe errors.
- [~] Real-provider extraction requires `GEMINI_API_KEY`; the paid live test is present but was not run in this review.

## 3. Seven-day recovery-plan experience [~]

### App

- [x] Display patient/hospital context, overview, and a Day 1–Day 7 selector.
- [x] Expand recurring items onto every applicable day and group displayed items by morning, afternoon, evening, bedtime, and anytime.
- [x] Display medication and care/activity items in the selected-day timeline.
- [x] Display follow-ups/tests and source-backed warning signs.
- [x] Make source evidence expandable for timeline items, follow-ups, and warning signs.
- [x] Show the confirmation queue ahead of the daily timeline.
- [~] Flag all non-confirmed timeline items visually, but conflicts are labelled `NEEDS CONFIRMATION` rather than being identified distinctly as conflicts.
- [~] Show medication dose, frequency, and duration when supplied; route and special instructions are not rendered.
- [~] Show follow-ups as a global section rather than associating one-time follow-ups with a relevant plan day.
- [ ] Provide a print-friendly seven-day checklist.
- [ ] Store “today” progress or task-checkbox completion locally.

### Backend

- [x] Return medications, care instructions, follow-ups, warnings, confirmation issues, and extraction warnings in the contract.
- [x] Preserve source evidence on every evidence-backed material item in the schema.
- [x] Preserve missing information as nullable fields and reject unconfirmed evidence without a reason.
- [~] The provider prompt directs source fidelity and conflict preservation; this requires live clinician/provider-output validation before it can be considered proven.

## 4. Processing, failure, and demo resilience [~]

### App

- [x] Show three honest processing stages without fabricated percentages.
- [x] Provide a failure screen with a retry path.
- [x] Keep the sample journey independent of the external provider.
- [~] The app has no API client, so backend errors such as unreadable document, unsupported document, and unavailable provider are not yet surfaced in the real Flutter flow.
- [~] The current processing stages are timed UI transitions for fixture loading; they do not reflect a real-upload request lifecycle.

### Backend

- [x] Provide a health endpoint.
- [x] Return safe actionable messages without stack traces, prompts, provider responses, or document content.
- [x] Cover deterministic samples, invalid uploads, oversized uploads, provider error mapping, schema retry, and timeout mapping with automated tests.

## 5. Reminder review and privacy [~]

### App

- [x] Provide a reminder-candidate review screen after a plan is available.
- [x] Include only confirmed, time-specific items with applicable days as candidates.
- [x] Let the user toggle individual candidate reminders.
- [x] Use neutral, privacy-safe reminder copy and state that patient, diagnosis, and medicine details are hidden on the lock screen.
- [x] Include a clearly labelled synthetic 10-second demo preview.
- [~] “Enable selected reminders” only shows a demo message; it does not request permission or schedule a local notification.
- [ ] Persist reminder selections, language, text-size, or privacy preferences locally.
- [ ] Manage scheduled reminder lifecycle: IDs, cancellation, plan replacement, rescheduling, and plan-window expiry.

### Backend

- [x] Keep notification scheduling out of the server boundary.
- [x] Do not include a notification provider, database, or remote messaging integration.

## 6. Quality, accessibility, delivery, and verification [~]

### App

- [x] Use a responsive, constrained mobile-web layout with Material controls and a custom dark theme.
- [x] Include Flutter model, Cubit, and widget tests in the repository.
- [~] Material controls supply basic keyboard support, but no explicit accessibility audit, screen-reader labels/semantics audit, or live-region implementation is evident for processing status.
- [~] Flutter analysis, tests, formatting, and web build were not verified in this review: FVM 3.44.9 attempted to write to its external cache and was denied by the workspace sandbox.
- [ ] Verify Android release packaging, iOS support, and hosted HTTPS deployment.

### Backend

- [x] Backend automated tests pass locally: **13 passed, 1 skipped** (the skipped test is the opt-in paid Gemini live test).
- [x] Keep provider credentials server-side via `GEMINI_API_KEY`; no client-side secret is present.
- [~] Add a live, credentialed extraction verification using the synthetic document before claiming real-upload readiness.

## Recommended next implementation sequence

1. [ ] Add a typed Flutter API client and send the chosen file, language, and sample flag to `POST /api/v1/plans`.
2. [ ] Map backend error codes to the app’s actionable failure states; retain the bundled sample as an explicit fallback.
3. [ ] Complete strict Dart contract validation and render multi-timing medications, routes, special instructions, and conflict status correctly.
4. [ ] Add client-side file-size validation and an accessibility pass, including processing live-region semantics.
5. [ ] Restore a usable FVM SDK/cache context, then run Flutter format, analysis, tests, and release web build.
6. [ ] Decide whether local reminders and printable/exportable plans remain deferred or move into the next milestone.

## Review notes requiring a product decision [!]

- The PRD describes real extraction and Flutter-to-backend networking as deferred/no-provider work, but the repository now includes a Gemini adapter and an opt-in live test. This checklist treats the code as the current source of implementation truth, while marking credentialed real extraction as unverified.
- The PRD’s implementation status says the 10-second reminder preview is deferred, while the app implements it as an in-app synthetic SnackBar preview. Decide whether to call this an implemented demo-only preview or remove it from the deferred list.
- The repository has pre-existing app configuration/build changes, including an app-local `.fvmrc`. They were not altered by this checklist review; reconcile the SDK pin and documentation before the next verification run.
