# CarePath India demo implementation plan

## Goal
Deliver a mobile-web-first, login-free Flutter demo that turns the bundled synthetic discharge summary into a traceable seven-day plan. The UI uses a dark violet theme and Cubit state management. A strict FastAPI boundary supports validated upload/sample requests without persisting patient data.

## Milestones

1. **Typed safety foundation**
   - Pin Flutter stable with FVM.
   - Implement strict Pydantic and Dart plan models, enums, day bounds, and evidence requirements.
   - Add deterministic multilingual synthetic fixture and sample document.
2. **Demo vertical slice**
   - Build upload/language selection, honest processing stages, and sample fallback.
   - Use one `CarePlanCubit` for upload, processing, plan, retry, and selected-day state.
3. **Traceable plan experience**
   - Render confirmation issues first, seven day navigation, time-grouped tasks, follow-ups, warning signs, and expandable source evidence.
   - Use a responsive centered shell tuned for 360–430 px mobile web widths and keyboard-accessible Material controls.
4. **API boundary and validation**
   - Add `POST /api/v1/plans` with MIME/extension/size/language validation and safe error envelopes.
   - Keep provider work server-only; sample mode remains deterministic and demo-safe.
5. **Demo hardening**
   - Test backend schemas, endpoint validation, Dart parsing, Cubit state flow, reminder eligibility/privacy, and compact UI rendering.
   - Run formatting, analysis, Flutter tests, pytest, and web build; document the three-minute demo path.

## Demo scope

Included: sample and local file selection, English/Bengali/Hindi plan content, seven-day timeline, uncertainty, evidence, follow-ups, warning signs, reminder eligibility preview, responsive web, and safe API skeleton.

Deferred after demo: production model provider credentials, OCR/PDF rendering, production notification scheduling on web, and hosted HTTPS deployment. The deterministic sample path never depends on these integrations.
