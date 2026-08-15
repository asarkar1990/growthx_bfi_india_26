# CarePath India

A login-free, mobile-web-first Flutter demo that organises a synthetic hospital discharge summary into a traceable seven-day recovery plan. It never diagnoses or invents treatment.

## Demo

```bash
# Flutter 3.47.0 is pinned in .fvmrc
cd app
fvm flutter pub get
fvm flutter run -d chrome
```

Select English, বাংলা, or हिन्दी, choose **Use synthetic demo document**, and create the plan. Review the confirmation queue before the daily timeline, expand any item for its source evidence, then review privacy-safe reminder candidates.

## Backend

```bash
cd backend
python3.13 -m venv .venv
.venv/bin/pip install -r requirements.txt
export GEMINI_API_KEY='your-gemini-api-key'
.venv/bin/uvicorn app.main:app --reload
```

The deterministic `useSample=true` request works without credentials. Real PDF, PNG, and JPEG uploads up to 10 MB are sent in memory to Gemini `gemini-3.6-flash`, validated against the strict Pydantic plan schema, and are never persisted by this backend. Keep `GEMINI_API_KEY` in your environment or `backend/.env`; do not commit it. Without the key, real uploads return a safe `MODEL_UNAVAILABLE` response.

The Flutter app connects to `http://127.0.0.1:8000` by default (automatically translating to `http://10.0.2.2:8000` when running in Android emulators). You can customize the API root URL via `--dart-define=API_BASE_URL=http://127.0.0.1:8000` or interactively at runtime by tapping the **API** settings badge in the app header.

## Checks

```bash
cd app && fvm dart format --set-exit-if-changed . && fvm flutter analyze && fvm flutter test
cd backend && .venv/bin/pytest -q
```

To run the paid Gemini integration test against the synthetic document only, set `GEMINI_LIVE_TEST=1` together with `GEMINI_API_KEY` before running backend pytest.

See [`docs/implementation-plan.md`](docs/implementation-plan.md) for scope and milestones.
