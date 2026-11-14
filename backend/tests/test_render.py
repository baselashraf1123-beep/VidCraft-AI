"""Real ffmpeg test of concat(): crossfade + music + loudnorm (no network)."""
import os, subprocess, sys, tempfile
from pathlib import Path
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
import pipeline


def _clip(path, color, dur):
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "lavfi", "-i", f"color=c={color}:s=360x640:d={dur}:r=30",
                    "-f", "lavfi", "-i", f"sine=f=440:d={dur}:sample_rate=44100", "-shortest", "-c:v", "libx264",
                    "-pix_fmt", "yuv420p", "-c:a", "aac", "-ar", "44100", "-ac", "2", str(path)], check=True)


def _build(music):
    d = Path(tempfile.mkdtemp())
    parts = []
    for i, c in enumerate(["red", "green", "blue"]):
        p = d / f"p{i}.mp4"
        _clip(p, c, 3)
        parts.append(p)
    out = d / "final.mp4"
    pipeline.concat(parts, out, None, music)
    return out


def test_crossfade_duration_with_music():
    out = _build(True)
    # 3 clips x 3 s minus 2 cross-fades of XF
    assert abs(pipeline.probe_duration(out) - (9 - 2 * pipeline.XF)) < 0.25


def test_without_music_and_single_clip():
    out = _build(False)
    assert out.exists() and out.stat().st_size > 5000
    d = Path(tempfile.mkdtemp())
    p = d / "p0.mp4"
    _clip(p, "red", 2)
    pipeline.concat([p], d / "final.mp4", None, True)
    assert (d / "final.mp4").stat().st_size > 5000
