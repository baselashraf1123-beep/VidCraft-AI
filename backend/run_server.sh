#!/usr/bin/env bash
# One-command local server for VidCraft AI (free, no hosting needed).
# Usage: ./run_server.sh   (optional: put PEXELS_API_KEY / GEMINI_API_KEY in backend/.env)
set -e
cd "$(dirname "$0")"
command -v ffmpeg >/dev/null || { echo "ffmpeg is required: apt/pkg/brew install ffmpeg"; exit 1; }
[ -d .venv ] || python3 -m venv .venv
. .venv/bin/activate
pip install -q -r requirements.txt
[ -f .env ] && { set -a; . ./.env; set +a; }
IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo "Server URL for the app Settings screen:  http://${IP:-YOUR-IP}:8000"
exec python launcher.py "$@"
