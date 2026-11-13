"""VidCraft AI backend (FastAPI). Run:  uvicorn main:app --host 0.0.0.0 --port 8000"""
import os
import re
import shutil
import threading
import time
import uuid
from collections import defaultdict, deque
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field, field_validator

import pipeline

OUT = Path(__file__).parent / "outputs"
OUT.mkdir(exist_ok=True)
MAX_PARALLEL = 2
JOB_TTL = 60 * 60 * 6  # clean files after 6h (keeps free disk small)

app = FastAPI(title="VidCraft AI", version="1.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

# ---- abuse protection (the API is public and burns free-tier quotas) -------------------------------
RATE_PER_HOUR = int(os.getenv("RATE_PER_HOUR", "8"))      # new jobs per client IP per hour
MAX_ACTIVE = int(os.getenv("MAX_ACTIVE", "6"))            # queued + running jobs, whole server
_HITS: dict[str, deque] = defaultdict(deque)
_ID_RE = re.compile(r"^[0-9a-f]{12}$")
_RATE_RE = re.compile(r"^[+-](\d{1,2})%$")
_COLOR_RE = re.compile(r"^#[0-9A-Fa-f]{6}$")


def _client_ip(request: Request) -> str:
    fwd = request.headers.get("x-forwarded-for")
    return (fwd.split(",")[0].strip() if fwd else (request.client.host if request.client else "?"))[:64]


def _check_rate(ip: str):
    now = time.time()
    q = _HITS[ip]
    while q and now - q[0] > 3600:
        q.popleft()
    if len(q) >= RATE_PER_HOUR:
        raise HTTPException(429, f"تجاوزت الحد المسموح ({RATE_PER_HOUR} فيديوهات في الساعة). حاول لاحقاً.")
    q.append(now)


JOBS: dict[str, dict] = {}
LOCK = threading.Lock()
SEM = threading.Semaphore(MAX_PARALLEL)


class JobReq(BaseModel):
    idea: str = Field(min_length=3, max_length=500)
    language: str = Field("ar", pattern="^(ar|en)$")
    voice: Optional[str] = None
    style: str = "cinematic"
    scenes: int = Field(5, ge=2, le=8)
    visuals: str = Field("stock", pattern="^(stock|ai)$")
    rate: str = "+0%"
    subtitle_color: str = "#FFFFFF"
    watermark: Optional[str] = Field("VidCraft AI", max_length=30)

    @field_validator("voice")
    @classmethod
    def _voice(cls, v):
        if v is not None and v not in {x["id"] for x in VOICES}:
            raise ValueError("unknown voice")
        return v

    @field_validator("style")
    @classmethod
    def _style(cls, v):
        if v not in {x["id"] for x in STYLE_LIST}:
            raise ValueError("unknown style")
        return v

    @field_validator("rate")
    @classmethod
    def _rate(cls, v):
        m = _RATE_RE.match(v)
        if not m or int(m.group(1)) > 50:
            raise ValueError("rate must look like +10% (max 50)")
        return v

    @field_validator("subtitle_color")
    @classmethod
    def _color(cls, v):
        if not _COLOR_RE.match(v):
            raise ValueError("subtitle_color must be #RRGGBB")
        return v


VOICES = [
    {"id": "ar-EG-SalmaNeural", "name": "سلمى (مصر)", "lang": "ar", "gender": "female"},
    {"id": "ar-EG-ShakirNeural", "name": "شاكر (مصر)", "lang": "ar", "gender": "male"},
    {"id": "ar-SA-ZariyahNeural", "name": "زارية (السعودية)", "lang": "ar", "gender": "female"},
    {"id": "ar-SA-HamedNeural", "name": "حامد (السعودية)", "lang": "ar", "gender": "male"},
    {"id": "ar-AE-FatimaNeural", "name": "فاطمة (الإمارات)", "lang": "ar", "gender": "female"},
    {"id": "ar-AE-HamdanNeural", "name": "حمدان (الإمارات)", "lang": "ar", "gender": "male"},
    {"id": "en-US-AriaNeural", "name": "Aria (US)", "lang": "en", "gender": "female"},
    {"id": "en-US-GuyNeural", "name": "Guy (US)", "lang": "en", "gender": "male"},
]
STYLE_LIST = [
    {"id": "cinematic", "name": "سينمائي"},
    {"id": "realistic", "name": "واقعي"},
    {"id": "anime", "name": "أنمي"},
    {"id": "3d", "name": "ثلاثي الأبعاد"},
    {"id": "illustration", "name": "رسم رقمي"},
    {"id": "dark", "name": "داكن / نيون"},
]


def _cleanup():
    now = time.time()
    for d in OUT.iterdir():
        if d.is_dir() and now - d.stat().st_mtime > JOB_TTL:
            shutil.rmtree(d, ignore_errors=True)
            JOBS.pop(d.name, None)
    for k in [k for k, j in JOBS.items() if now - j.get("created", now) > JOB_TTL]:
        JOBS.pop(k, None)


def _worker(job_id: str, opts: dict):
    def progress(p: int, msg: str):
        with LOCK:
            JOBS[job_id].update(progress=p, message=msg, status="running")

    with SEM:
        try:
            result = pipeline.make_video(OUT / job_id, opts, progress)
            with LOCK:
                JOBS[job_id].update(status="done", progress=100, message="تم إنشاء الفيديو", result=result)
        except Exception as e:  # noqa: BLE001
            with LOCK:
                JOBS[job_id].update(status="error", message=str(e)[:400])


@app.get("/api/health")
def health():
    return {"ok": True, "service": "vidcraft-ai", "jobs": len(JOBS)}


@app.get("/api/options")
def options():
    return {"voices": VOICES, "styles": STYLE_LIST}


@app.post("/api/jobs")
def create_job(req: JobReq, request: Request):
    _cleanup()
    with LOCK:
        active = sum(1 for j in JOBS.values() if j["status"] in ("queued", "running"))
    if active >= MAX_ACTIVE:
        raise HTTPException(503, "الخادم مشغول حالياً، أعد المحاولة بعد دقيقة.")
    _check_rate(_client_ip(request))
    job_id = uuid.uuid4().hex[:12]
    with LOCK:
        JOBS[job_id] = {"id": job_id, "status": "queued", "progress": 0, "message": "في الطابور", "result": None, "created": time.time()}
    threading.Thread(target=_worker, args=(job_id, req.model_dump()), daemon=True).start()
    return {"id": job_id}


@app.get("/api/jobs/{job_id}")
def get_job(job_id: str):
    if not _ID_RE.match(job_id):
        raise HTTPException(404, "job not found")
    job = JOBS.get(job_id)
    if not job:
        raise HTTPException(404, "job not found")
    return job


@app.get("/api/jobs/{job_id}/video")
def get_video(job_id: str):
    if not _ID_RE.match(job_id):
        raise HTTPException(404, "video not ready")
    f = OUT / job_id / "final.mp4"
    if not f.exists():
        raise HTTPException(404, "video not ready")
    return FileResponse(f, media_type="video/mp4", filename=f"vidcraft_{job_id}.mp4")


@app.get("/api/jobs/{job_id}/thumb")
def get_thumb(job_id: str):
    if not _ID_RE.match(job_id):
        raise HTTPException(404, "not ready")
    f = OUT / job_id / "thumb.jpg"
    if not f.exists():
        raise HTTPException(404, "not ready")
    return FileResponse(f, media_type="image/jpeg")
