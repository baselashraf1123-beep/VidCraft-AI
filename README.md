# VidCraft AI

Turn a text idea into a vertical short video (script, voice-over, visuals, burned-in Arabic/English subtitles).

## Architecture
- `lib/` Flutter app (Arabic RTL, Material 3): Android + Web.
- `backend/` FastAPI service: script (LLM) -> edge-tts voice -> stock/AI images -> ASS subtitles -> FFmpeg.

## Run the backend
    cd backend && pip install -r requirements.txt && uvicorn main:app --host 0.0.0.0 --port 8000
Needs `ffmpeg` on PATH. Optional keys: see `backend/.env.example` (export them as environment variables).

## Run the app
    flutter run -d chrome --dart-define=API_BASE=http://localhost:8000
    flutter build apk --release --dart-define=API_BASE=https://YOUR-SERVER

## Free hosting (backend) - verified status (Nov 2026)
- Hugging Face Docker SDK is now paid; the **Gradio SDK** Space is free (no card). `backend/app.py`,
  `backend/packages.txt` (ffmpeg) and `backend/SPACE_README.md` (copied to README.md) are ready:
  `HF_TOKEN=hf_xxx PEXELS_API_KEY=... GEMINI_API_KEY=... python3 backend/deploy_hf.py vidcraft-ai`
  (token needs *write* access; the deploy script has not been run against a live account yet).
- Free Spaces sleep when idle. Videos are deleted after 6 h by design.
- Render / Koyeb / Northflank / Fly.io need a payment card. Locally: `uvicorn main:app --host 0.0.0.0`.

## Known limits of the free tiers
- Pollinations free text API: 1 script per ~45 s per server IP, so concurrent users queue.
  Set `GEMINI_API_KEY` to remove this bottleneck.
- Without `PEXELS_API_KEY` images come from Wikimedia Commons (keyless): licensed and legal, but relevance is average.
- AI images (Pollinations) free tier: 1 image / 45 s and a logo. Use a key for real use.
- Image credits (CC BY / CC BY-SA) are returned in `credits`: show them in the video description.
