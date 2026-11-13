"""API tests (no network/LLM needed: jobs are stubbed). Run: cd backend && python3 -m pytest -q"""
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
os.environ["RATE_PER_HOUR"] = "3"
os.environ["MAX_ACTIVE"] = "50"
import pytest
from fastapi.testclient import TestClient
import main, pipeline


@pytest.fixture(autouse=True)
def stub(monkeypatch):
    def fake(job_dir, opts, progress):
        job_dir.mkdir(parents=True, exist_ok=True)
        (job_dir / "final.mp4").write_bytes(b"x" * 20000)
        progress(50, "x")
        return {"title": "t", "scenes": [], "duration": 1, "size": 1, "image_sources": [], "credits": [], "script_fallback": False}
    monkeypatch.setattr(pipeline, "make_video", fake)
    main._HITS.clear()
    main.RATE_PER_HOUR = 3
    yield


c = TestClient(main.app)
OK = {"idea": "اختبار البراكين", "language": "ar", "scenes": 3, "rate": "+0%"}


def test_health_and_options():
    assert c.get("/api/health").json()["ok"] is True
    j = c.get("/api/options").json()
    assert len(j["voices"]) >= 6 and len(j["styles"]) >= 4


def test_job_lifecycle():
    r = c.post("/api/jobs", json=OK); assert r.status_code == 200
    jid = r.json()["id"]
    for _ in range(50):
        s = c.get(f"/api/jobs/{jid}").json()
        if s["status"] in ("done", "error"): break
        time.sleep(0.05)
    assert s["status"] == "done"
    v = c.get(f"/api/jobs/{jid}/video"); assert v.status_code == 200 and v.headers["content-type"] == "video/mp4"


@pytest.mark.parametrize("bad", [
    {"idea": "ab"}, {"idea": "x" * 501}, {"idea": "اختبار", "language": "fr"}, {"idea": "اختبار", "scenes": 99},
    {"idea": "اختبار", "voice": "evil"}, {"idea": "اختبار", "style": "../etc"}, {"idea": "اختبار", "rate": "+900%"},
    {"idea": "اختبار", "rate": "fast"}, {"idea": "اختبار", "subtitle_color": "red"}, {"idea": "اختبار", "visuals": "x"},
    {"idea": "اختبار", "watermark": "w" * 31},
])
def test_validation_rejects(bad):
    assert c.post("/api/jobs", json=bad).status_code == 422


@pytest.mark.parametrize("path", ["../../etc/passwd", "..%2F..%2Fetc%2Fpasswd", "ZZZZZZZZZZZZ", "abc", "a" * 40])
def test_path_traversal_blocked(path):
    for suffix in ("", "/video", "/thumb"):
        assert c.get(f"/api/jobs/{path}{suffix}").status_code in (404, 422)


def test_unknown_job_404():
    assert c.get("/api/jobs/0123456789ab").status_code == 404


def test_rate_limit():
    codes = [c.post("/api/jobs", json=OK).status_code for _ in range(5)]
    assert codes[:3] == [200, 200, 200] and codes[3:] == [429, 429]


def test_rate_limit_is_per_ip():
    for _ in range(3): c.post("/api/jobs", json=OK, headers={"x-forwarded-for": "1.1.1.1"})
    assert c.post("/api/jobs", json=OK, headers={"x-forwarded-for": "1.1.1.1"}).status_code == 429
    assert c.post("/api/jobs", json=OK, headers={"x-forwarded-for": "2.2.2.2"}).status_code == 200


def test_queue_cap(monkeypatch):
    monkeypatch.setattr(main, "MAX_ACTIVE", 0)
    assert c.post("/api/jobs", json=OK).status_code == 503
