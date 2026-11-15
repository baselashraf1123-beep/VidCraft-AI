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

## Run everything locally (free, no card, no hosting)
1. Install Python 3.10+ and ffmpeg (Windows: `winget install Gyan.FFmpeg`; Linux: `apt install ffmpeg`; Termux: `pkg install python ffmpeg`).
2. Optional: copy `backend/.env.example` to `backend/.env` and add `PEXELS_API_KEY` (better photos) and `GEMINI_API_KEY` (better scripts).
3. Start: Windows `backend\run_server.bat`, Linux/macOS/Termux `backend/run_server.sh`. It prints the URL.
4. Use it:
   - **Browser (PC or phone on the same Wi-Fi):** open the printed URL. If `build/web` (or `backend/web`) exists the server serves the app itself, same origin, nothing to configure.
   - **Android APK:** install it, open Settings, set the server URL to the printed address (`http://PC-IP:8000`). Cleartext HTTP is allowed for this. On the emulator the default `http://10.0.2.2:8000` works as is.
   - Build the web UI once: `flutter build web --release`.

## Hosting status (verified Nov 2026)
- Hugging Face: `402 Payment Required` for Gradio/Docker Spaces on a free account (needs PRO), even with a card on file.
- Render / Koyeb / Northflank / Fly.io / Cloud Run need a payment card; `render.yaml` is provided for Render.

## Known limits of the free tiers
- Pollinations free text API: 1 script per ~45 s per server IP, so concurrent users queue.
  Set `GEMINI_API_KEY` to remove this bottleneck.
- Without `PEXELS_API_KEY` images come from Wikimedia Commons (keyless): licensed and legal, but relevance is average.
- AI images (Pollinations) free tier: 1 image / 45 s and a logo. Use a key for real use.
- Image credits (CC BY / CC BY-SA) are returned in `credits`: show them in the video description.
