"""VidCraft AI - zero-cost video generation pipeline.

Stages:  script (LLM) -> voice (edge-tts) -> visuals (AI images) -> subtitles (ASS)
         -> render (FFmpeg Ken-Burns + burned subtitles) -> final MP4
All providers used here are free and need no API key. Optional PEXELS_API_KEY
is only used as a visual fallback.
"""
import asyncio
import json
import os
import random
import re
import shutil
import subprocess
import threading
import time
import urllib.parse
from pathlib import Path
from typing import Callable, Optional

import edge_tts
import requests
from PIL import Image, ImageDraw

BASE = Path(__file__).parent
FONT_DIR = BASE / "fonts"
FONT_NAME = "Tajawal"
W, H, FPS = 720, 1280, 30

TEXT_API = "https://text.pollinations.ai/openai"
IMAGE_API = "https://image.pollinations.ai/prompt/"

STYLES = {
    "cinematic": "cinematic lighting, dramatic, highly detailed, 35mm film",
    "realistic": "photorealistic, natural light, sharp focus, high quality photo",
    "anime": "anime style, vibrant colors, studio ghibli inspired, detailed background",
    "3d": "3D render, pixar style, soft lighting, colorful, octane render",
    "illustration": "digital illustration, flat vector art, bold colors, clean shapes",
    "dark": "dark moody atmosphere, neon accents, cyberpunk, high contrast",
}

ProgressCb = Callable[[int, str], None]


class PipelineError(Exception):
    pass


# --------------------------------------------------------------------------- script
def _repair_json(txt: str) -> str:
    # "keywords":"a","b","c"  ->  "keywords":"a, b, c"   (model sometimes splits a string value)
    def fix(m):
        vals = re.findall(r'"([^"]*)"', m.group(2))
        return f'"{m.group(1)}":"{", ".join(vals)}"'
    txt = re.sub(r'"(keywords|visual)"\s*:\s*("[^"]*"(?:\s*,\s*"[^"]*"(?!\s*:))+)', fix, txt)
    txt = re.sub(r",\s*([}\]])", r"\1", txt)  # trailing commas
    return txt


def _extract_json(text: str):
    text = text.strip()
    text = re.sub(r"^```(?:json)?|```$", "", text, flags=re.M).strip()
    m = re.search(r"\{.*\}", text, re.S)
    if not m:
        raise ValueError("no json")
    raw = m.group(0)
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return json.loads(_repair_json(raw))


def _gemini(prompt: str) -> Optional[str]:
    key = os.getenv("GEMINI_API_KEY")
    if not key:
        return None
    try:
        r = requests.post(
            f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={key}",
            json={"contents": [{"parts": [{"text": prompt}]}], "generationConfig": {"temperature": 0.9}},
            timeout=45,
        )
        r.raise_for_status()
        return r.json()["candidates"][0]["content"]["parts"][0]["text"]
    except Exception:  # noqa: BLE001
        return None


_LLM_LOCK = threading.Lock()
_LLM_LAST = [0.0]
_LLM_GAP = 46.0  # free Pollinations text tier: 1 reply / 45 s per IP -> serialize + space calls


def _llm(prompt: str, timeout: int = 45) -> str:
    g = _gemini(prompt)
    if g:
        return g
    last = None
    for attempt in range(3):
        for model in ("openai-fast",):
            with _LLM_LOCK:
                wait = _LLM_GAP - (time.time() - _LLM_LAST[0])
                if wait > 0:
                    time.sleep(wait)
                _LLM_LAST[0] = time.time()
            try:
                r = requests.post(
                    TEXT_API,
                    json={"model": model, "max_tokens": 3500, "reasoning_effort": "low", "messages": [{"role": "user", "content": prompt}]},
                    timeout=timeout,
                )
                if r.status_code in (402, 429):
                    last = "rate limited"
                    with _LLM_LOCK:
                        _LLM_LAST[0] = time.time() + min(int(r.headers.get("Retry-After", "45")), 50) - _LLM_GAP
                    continue
                r.raise_for_status()
                choice = r.json()["choices"][0]
                content = choice["message"]["content"]
                if choice.get("finish_reason") == "length":
                    last = "response truncated (max_tokens)"
                    continue  # truncated JSON is useless: try the next model/attempt
                if content and content.strip():
                    return content
            except Exception as e:  # noqa: BLE001
                last = e
    raise PipelineError(f"LLM unavailable: {last}")


def generate_script(idea: str, language: str, scenes: int) -> dict:
    lang_name = "Arabic (Modern Standard, simple and engaging)" if language == "ar" else "English"
    prompt = f"""You are a viral short-video scriptwriter. Write a script for a vertical short video about:
"{idea}"

Rules:
- Narration language: {lang_name}.
- Exactly {scenes} scenes. Each scene narration is 1-2 short sentences (12-25 words), engaging, with a strong hook in scene 1 and a call-to-action in the last scene.
- For each scene give "visual": an ENGLISH image-generation prompt (concrete subject, setting, mood; no text in image).
- For each scene give "keywords": ONE single JSON string of 2-3 plain ENGLISH words separated by spaces (e.g. "glass water morning"). Concrete real-world objects only. Never use a list.
- Also give top-level "topic": the overall subject as 1-2 plain ENGLISH nouns (e.g. "coffee", "volcano", "sleep").
- Return ONLY valid JSON, no markdown:
{{"title": "short title in the narration language", "topic": "...", "scenes": [{{"narration": "...", "visual": "...", "keywords": "..."}}]}}"""
    for _ in range(3):
        try:
            data = _extract_json(_llm(prompt))
            sc = [
                {"narration": str(x["narration"]).strip(), "visual": str(x.get("visual", idea)).strip(),
                 "keywords": str(x.get("keywords") or x.get("visual") or idea).strip()}
                for x in data["scenes"]
                if str(x.get("narration", "")).strip()
            ]
            if sc:
                return {"title": str(data.get("title") or idea)[:80], "topic": str(data.get("topic") or "").strip(), "scenes": sc[:scenes], "fallback": False}
        except Exception:  # noqa: BLE001
            continue
    return _fallback_script(idea, language, scenes)


_GENERIC_KW = ["sunrise mountains", "city skyline", "forest river", "ocean waves", "night stars", "library books", "garden flowers", "desert dunes"]


def _fallback_script(idea: str, language: str, scenes: int) -> dict:
    """Offline fallback so the pipeline never dies if the LLM is down."""
    if language == "ar":
        lines = [
            f"هل تعلم هذه الحقيقة المدهشة عن {idea}؟",
            f"دعنا نأخذك في رحلة سريعة لنكتشف أهم ما يخص {idea}.",
            "التفاصيل الصغيرة هي التي تصنع الفرق الكبير دائماً.",
            "وكلما تعمقت أكثر ستجد أشياء لم تخطر على بالك.",
            "شارك الفيديو مع من يهمه الأمر وتابعنا للمزيد.",
        ]
    else:
        lines = [
            f"Did you know this amazing fact about {idea}?",
            f"Let's take a quick journey to discover what matters most about {idea}.",
            "Small details always make the biggest difference.",
            "The deeper you look, the more surprises you find.",
            "Share this video and follow us for more.",
        ]
    sc = [{"narration": lines[i % len(lines)], "visual": f"{idea}, beautiful composition", "keywords": _GENERIC_KW[i % len(_GENERIC_KW)]} for i in range(scenes)]
    return {"title": idea[:60], "topic": "", "scenes": sc, "fallback": True}


# --------------------------------------------------------------------------- voice
async def _tts(text: str, voice: str, out: Path, rate: str):
    last = None
    for _ in range(3):
        try:
            await edge_tts.Communicate(text, voice, rate=rate).save(str(out))
            if out.exists() and out.stat().st_size > 500:
                return
        except Exception as e:  # noqa: BLE001
            last = e
            await asyncio.sleep(1)
    raise PipelineError(f"TTS failed: {last}")


def synth_voice(text: str, voice: str, out: Path, rate: str = "+0%"):
    asyncio.run(_tts(text, voice, out, rate))


def probe_duration(path: Path) -> float:
    r = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)],
        capture_output=True, text=True,
    )
    try:
        return float(r.stdout.strip())
    except ValueError:
        raise PipelineError(f"cannot probe {path.name}")


# --------------------------------------------------------------------------- visuals
def _fallback_image(path: Path, seed: int):
    rnd = random.Random(seed)
    c1 = tuple(rnd.randint(40, 140) for _ in range(3))
    c2 = tuple(rnd.randint(90, 230) for _ in range(3))
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)], fill=tuple(int(c1[i] * (1 - t) + c2[i] * t) for i in range(3)))
    img.save(path, "JPEG", quality=90)


def _valid_image(path: Path, min_w: int = 400) -> bool:
    try:
        with Image.open(path) as im:
            im.verify()
        with Image.open(path) as im:
            ok = im.size[0] >= min_w
        return ok and path.stat().st_size > 5000
    except Exception:  # noqa: BLE001
        return False


def _dl(url: str, path: Path, headers: Optional[dict] = None) -> bool:
    try:
        r = requests.get(url, timeout=40, headers=headers or {})
        if r.status_code == 200 and r.headers.get("content-type", "").startswith("image"):
            path.write_bytes(r.content)
            return _valid_image(path)
    except Exception:  # noqa: BLE001
        pass
    return False


def _pexels(q: str, path: Path, used: set) -> Optional[dict]:
    key = os.getenv("PEXELS_API_KEY")
    if not key:
        return None
    try:
        r = requests.get("https://api.pexels.com/v1/search", params={"query": q, "orientation": "portrait", "per_page": 15},
                         headers={"Authorization": key}, timeout=20)
        photos = [x for x in r.json().get("photos", []) if x["id"] not in used]
        random.shuffle(photos)
        for ph in photos[:3]:
            if _dl(ph["src"]["large2x"], path):
                used.add(ph["id"])
                return {"source": "pexels", "credit": f"Photo by {ph['photographer']} on Pexels"}
    except Exception:  # noqa: BLE001
        pass
    return None


def _pixabay(q: str, path: Path, used: set) -> Optional[dict]:
    key = os.getenv("PIXABAY_API_KEY")
    if not key:
        return None
    try:
        r = requests.get("https://pixabay.com/api/", params={"key": key, "q": q, "orientation": "vertical", "image_type": "photo",
                                                            "per_page": 15, "safesearch": "true"}, timeout=20)
        hits = [x for x in r.json().get("hits", []) if x["id"] not in used]
        random.shuffle(hits)
        for h in hits[:3]:
            if _dl(h.get("largeImageURL") or h["webformatURL"], path):
                used.add(h["id"])
                return {"source": "pixabay", "credit": f"Image by {h['user']} on Pixabay"}
    except Exception:  # noqa: BLE001
        pass
    return None


_STOP = {"facts", "fact", "about", "amazing", "tips", "best", "top", "video", "new", "idea", "invitation", "share",
         "energy", "concept", "symbolic", "person", "people", "with", "from", "that", "this", "your"}
_BAD_TITLE = re.compile(r"\b(map|factbook|flag|logo|diagram|stamp|manuscript|letter|cemetery|poster|coat of arms|scan|page|book|newspaper|document|impact|climate|chart|graph|report|figure|infographic|table|painting|drawing|sketch|engraving|illustration|efta\d+|porsche|macan|car|cars|auto|motor|metallic|bmw|audi|toyota|honda|ford|truck|bus|phone|laptop|wallpaper|screenshot|cover|album|song|film|movie|band|football|player)\b")
_OK_LICENSE = ("public domain", "cc0", "cc by", "cc-by", "pd")
WM_HEADERS = {"User-Agent": "VidCraftAI/1.0 (https://vidcraft.app; contact@vidcraft.app)"}


def _wikimedia(q: str, path: Path, used: set, must: str = "") -> Optional[dict]:
    """Keyless real photos from Wikimedia Commons; only reusable licenses are accepted."""
    try:
        r = requests.get("https://commons.wikimedia.org/w/api.php", headers=WM_HEADERS, timeout=25, params={
            "action": "query", "generator": "search", "gsrsearch": f"filetype:bitmap {q}", "gsrnamespace": 6,
            "gsrlimit": 20, "prop": "imageinfo", "iiprop": "url|size|mime|extmetadata", "iiurlwidth": 1080, "format": "json"})
        pages = list(r.json().get("query", {}).get("pages", {}).values())
        random.shuffle(pages)
        kws = [w for w in re.findall(r"[a-z]{3,}", q.lower()) if w not in _STOP]
        for pg in pages:
            ii = pg["imageinfo"][0]
            title_l = pg.get("title", "").lower()
            if _BAD_TITLE.search(title_l):
                continue
            if must and not re.search(rf"\b{re.escape(must.lower().rstrip('s'))}s?\b", title_l):
                continue
            # relevance: whole-word match (plural-insensitive) on at least one concrete keyword
            if not kws or not any(re.search(rf"\b{re.escape(k.rstrip('s'))}s?\b", title_l) for k in kws):
                continue
            lic = (ii.get("extmetadata", {}).get("LicenseShortName", {}).get("value", "")).lower()
            if ii.get("mime") != "image/jpeg" or ii["width"] < 700 or pg["pageid"] in used:
                continue
            if not any(lic.startswith(x) for x in _OK_LICENSE) or "nc" in lic or "nd" in lic:
                continue
            if _dl(ii.get("thumburl") or ii["url"], path, WM_HEADERS):
                used.add(pg["pageid"])
                artist = re.sub(r"<[^>]+>", "", ii.get("extmetadata", {}).get("Artist", {}).get("value", "unknown"))[:60]
                return {"source": "wikimedia", "credit": f"{pg['title'][5:70]} - {artist} ({lic.upper()}), Wikimedia Commons"}
    except Exception:  # noqa: BLE001
        pass
    return None


def _pollinations(visual: str, style: str, path: Path, seed: int, patient: bool = True) -> Optional[dict]:
    """AI image. Free tier = 1 image / 45s per IP and a small logo; used only when asked (visuals='ai')."""
    prompt = f"{visual}, {STYLES.get(style, STYLES['cinematic'])}, vertical composition, no text"
    url = IMAGE_API + urllib.parse.quote(prompt) + f"?width=576&height=1024&seed={seed}"
    key = os.getenv("POLLINATIONS_KEY")
    hdr = {"Authorization": f"Bearer {key}"} if key else {}
    for _ in range(3 if patient else 1):
        try:
            r = requests.get(url, timeout=90, headers=hdr)
            if r.status_code == 200 and r.headers.get("content-type", "").startswith("image"):
                path.write_bytes(r.content)
                if _valid_image(path):
                    return {"source": "ai", "credit": "AI image via Pollinations"}
            elif r.status_code == 402 and patient:
                time.sleep(min(int(r.headers.get("Retry-After", "46")) + 1, 50))
        except Exception:  # noqa: BLE001
            pass
    return None


def fetch_image(scene: dict, style: str, mode: str, path: Path, seed: int, used: set, topic: str = "") -> dict:
    q = scene.get("keywords") or scene["visual"]
    tw = (topic.split() or [""])[-1] if topic else ""  # head noun of the topic, e.g. "coffee"
    chain = []
    if mode == "ai":
        chain.append(lambda: _pollinations(scene["visual"], style, path, seed))
    if tw:
        # every stock image must literally mention the video topic -> never off-topic
        chain.append(lambda: _pexels(f"{tw} {q}", path, used))
        chain.append(lambda: _pixabay(f"{tw} {q}", path, used))
        chain.append(lambda: _wikimedia(f"{tw} {q}", path, used, must=tw))
        for kw in q.split():
            if len(kw) >= 4 and kw.lower() != tw.lower():
                chain.append(lambda kw=kw: _wikimedia(f"{tw} {kw}", path, used, must=tw))
        chain.append(lambda: _wikimedia(tw, path, used, must=tw))
    else:
        chain += [lambda: _pexels(q, path, used), lambda: _pixabay(q, path, used), lambda: _wikimedia(q, path, used)]
        for kw in q.split():
            if len(kw) >= 4:
                chain.append(lambda kw=kw: _wikimedia(kw, path, used))
    if mode != "ai":
        chain.append(lambda: _pollinations(scene["visual"], style, path, seed, patient=False))
    for fn in chain:
        res = fn()
        if res:
            return res
    _fallback_image(path, seed)
    return {"source": "gradient", "credit": ""}


# --------------------------------------------------------------------------- subtitles
def _ass_time(t: float) -> str:
    cs = int(round(t * 100))
    return f"{cs // 360000}:{(cs // 6000) % 60:02d}:{(cs // 100) % 60:02d}.{cs % 100:02d}"


def split_phrases(text: str, max_words: int = 4) -> list[str]:
    words = text.split()
    out, cur = [], []
    for w in words:
        cur.append(w)
        if len(cur) >= max_words or re.search(r"[.!?؟،,]$", w):
            out.append(" ".join(cur))
            cur = []
    if cur:
        out.append(" ".join(cur))
    return out


def build_ass(text: str, duration: float, path: Path, sub_color: str):
    phrases = split_phrases(text)
    weights = [max(len(p), 1) for p in phrases]
    total = sum(weights)
    # BGR color for ASS
    hexc = sub_color.lstrip("#")
    bgr = hexc[4:6] + hexc[2:4] + hexc[0:2]
    header = f"""[Script Info]
ScriptType: v4.00+
PlayResX: {W}
PlayResY: {H}
WrapStyle: 0

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Main,{FONT_NAME},58,&H00{bgr},&H00FFFFFF,&H00000000,&H96000000,1,0,0,0,100,100,0,0,1,4,2,2,50,50,300,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""
    t = 0.0
    lines = []
    for p, wgt in zip(phrases, weights):
        d = duration * wgt / total
        lines.append(f"Dialogue: 0,{_ass_time(t)},{_ass_time(t + d)},Main,,0,0,0,,{p}")
        t += d
    path.write_text(header + "\n".join(lines) + "\n", encoding="utf-8")


# --------------------------------------------------------------------------- render
def _run(cmd: list[str], cwd: Optional[Path] = None):
    r = subprocess.run(cmd, capture_output=True, text=True, cwd=cwd)
    if r.returncode != 0:
        raise PipelineError("ffmpeg failed: " + r.stderr[-600:])


def render_scene(img: Path, audio: Path, ass: Path, dur: float, out: Path, idx: int):
    frames = max(int(dur * FPS), 1)
    zoom_in = idx % 2 == 0
    if zoom_in:
        z = f"min(1+0.0009*on,1.3)"
    else:
        z = f"max(1.3-0.0009*on,1)"
    vf = (
        f"scale={W * 2}:{H * 2}:force_original_aspect_ratio=increase,crop={W * 2}:{H * 2},"
        f"zoompan=z='{z}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={frames}:s={W}x{H}:fps={FPS},"
        f"ass={ass.name}:fontsdir={FONT_DIR}"
    )
    _run([
        "ffmpeg", "-y", "-loglevel", "error", "-loop", "1", "-i", str(img), "-i", str(audio),
        "-vf", vf, "-t", f"{dur:.3f}", "-r", str(FPS),
        "-c:v", "libx264", "-preset", "veryfast", "-crf", "23", "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "128k", "-ar", "44100", "-ac", "2", "-shortest", str(out),
    ], cwd=ass.parent)


def concat(parts: list[Path], out: Path, watermark: Optional[str]):
    lst = out.parent / "list.txt"
    lst.write_text("".join(f"file '{p.name}'\n" for p in parts))
    merged = out.parent / "merged.mp4"
    _run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", "list.txt", "-c", "copy", str(merged)], cwd=out.parent)
    if watermark:
        wm = out.parent / "wm.txt"
        wm.write_text(watermark, encoding="utf-8")
        vf = f"drawtext=textfile={wm.name}:fontfile={FONT_DIR / 'Tajawal-Bold.ttf'}:fontsize=30:fontcolor=white@0.7:x=w-tw-24:y=60:shadowcolor=black:shadowx=2:shadowy=2"
        _run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(merged), "-vf", vf, "-c:v", "libx264", "-preset", "veryfast",
              "-crf", "23", "-pix_fmt", "yuv420p", "-c:a", "copy", "-movflags", "+faststart", str(out)], cwd=out.parent)
    else:
        _run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(merged), "-c", "copy", "-movflags", "+faststart", str(out)], cwd=out.parent)


# --------------------------------------------------------------------------- orchestrator
def make_video(job_dir: Path, opts: dict, progress: ProgressCb) -> dict:
    job_dir.mkdir(parents=True, exist_ok=True)
    idea = opts["idea"].strip()
    language = opts.get("language", "ar")
    voice = opts.get("voice") or ("ar-EG-SalmaNeural" if language == "ar" else "en-US-AriaNeural")
    style = opts.get("style", "cinematic")
    n = max(2, min(int(opts.get("scenes", 5)), 8))
    rate = opts.get("rate", "+0%")
    sub_color = opts.get("subtitle_color", "#FFFFFF")
    watermark = opts.get("watermark")
    mode = opts.get("visuals", "stock")

    progress(5, "كتابة السكربت بالذكاء الاصطناعي")
    script = opts.get("script") or generate_script(idea, language, n)
    scenes = script["scenes"]
    (job_dir / "script.json").write_text(json.dumps(script, ensure_ascii=False, indent=2), encoding="utf-8")

    parts, sources, credits, used, total_dur = [], [], [], set(), 0.0
    seed0 = random.randint(1, 10**6)
    for i, sc in enumerate(scenes):
        base = 10 + int(75 * i / len(scenes))
        progress(base, f"المشهد {i + 1}/{len(scenes)}: توليد الصوت")
        audio = job_dir / f"a{i}.mp3"
        synth_voice(sc["narration"], voice, audio, rate)
        dur = probe_duration(audio) + 0.35

        progress(base + 3, f"المشهد {i + 1}/{len(scenes)}: توليد الصورة")
        img = job_dir / f"i{i}.jpg"
        info = fetch_image(sc, style, mode, img, seed0 + i, used, script.get("topic", ""))
        sources.append(info["source"])
        if info["credit"]:
            credits.append(info["credit"])

        progress(base + 7, f"المشهد {i + 1}/{len(scenes)}: المونتاج والترجمة")
        ass = job_dir / f"s{i}.ass"
        build_ass(sc["narration"], dur, ass, sub_color)
        part = job_dir / f"p{i}.mp4"
        render_scene(img, audio, ass, dur, part, i)
        parts.append(part)
        total_dur += dur

    progress(92, "دمج المشاهد والتصدير")
    final = job_dir / "final.mp4"
    concat(parts, final, watermark)
    shutil.rmtree(job_dir / "tmp", ignore_errors=True)
    if not final.exists() or final.stat().st_size < 10000:
        raise PipelineError("final video missing")
    thumb = job_dir / "thumb.jpg"
    _run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(final), "-ss", "0.5", "-frames:v", "1", "-vf", "scale=360:-2", str(thumb)])
    progress(100, "تم")
    return {
        "title": script["title"],
        "scenes": scenes,
        "duration": round(probe_duration(final), 2),
        "size": final.stat().st_size,
        "image_sources": sources,
        "credits": credits,
        "script_fallback": bool(script.get("fallback")),
    }
