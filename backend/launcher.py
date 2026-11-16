#!/usr/bin/env python3
"""VidCraft AI launcher: starts the server, prints LAN URLs + a QR code to open it on a phone.
   python launcher.py               # LAN only (phone on the same Wi-Fi)
   python launcher.py --tunnel      # also a public https URL via cloudflared (works on mobile data)
"""
import argparse, os, shutil, socket, subprocess, sys, threading, re, time
from pathlib import Path

HERE = Path(__file__).parent


def lan_ips():
    ips = []
    try:  # the interface used for the default route
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80)); ips.append(s.getsockname()[0]); s.close()
    except OSError:
        pass
    try:
        for ip in socket.gethostbyname_ex(socket.gethostname())[2]:
            if ip not in ips and not ip.startswith("127."):
                ips.append(ip)
    except OSError:
        pass
    return [i for i in ips if not i.startswith("169.254")]


def qr(url):
    try:
        import segno
        segno.make(url, error="m").terminal(compact=True)
    except Exception:
        print("(pip install segno  to show a QR code)")


def load_env():
    f = HERE / ".env"
    if f.exists():
        for line in f.read_text(encoding="utf-8").splitlines():
            if "=" in line and not line.lstrip().startswith("#"):
                k, v = line.split("=", 1)
                if v.strip():
                    os.environ.setdefault(k.strip(), v.strip())


def tunnel(port):
    exe = shutil.which("cloudflared") or str(HERE / "cloudflared")
    if not Path(exe).exists() and not shutil.which("cloudflared"):
        print("! --tunnel needs cloudflared: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/")
        return
    p = subprocess.Popen([exe, "tunnel", "--url", f"http://localhost:{port}", "--no-autoupdate"],
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    for line in p.stdout:
        m = re.search(r"https://[a-z0-9-]+\.trycloudflare\.com", line)
        if m:
            print(f"\n  PUBLIC URL (works anywhere, changes every run): {m.group(0)}")
            qr(m.group(0))
            break
    for _ in p.stdout:  # keep draining
        pass


def main():
    try:
        sys.stdout.reconfigure(line_buffering=True)
    except Exception:
        pass
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=int(os.getenv("PORT", "8000")))
    ap.add_argument("--tunnel", action="store_true")
    a = ap.parse_args()
    load_env()
    if not shutil.which("ffmpeg"):
        sys.exit("ffmpeg is required (Windows: winget install Gyan.FFmpeg | Linux: apt install ffmpeg | Termux: pkg install ffmpeg)")
    ips = lan_ips()
    print("\n  VidCraft AI is starting...")
    print(f"  On this computer : http://localhost:{a.port}")
    for ip in ips:
        print(f"  On your phone    : http://{ip}:{a.port}   (same Wi-Fi)")
    if ips:
        print("\n  Scan with the phone camera to open the web app:")
        qr(f"http://{ips[0]}:{a.port}")
        print("  Android app: Settings > 'بحث تلقائي عن الخادم' (finds it by itself)\n")
    if a.tunnel:
        threading.Thread(target=tunnel, args=(a.port,), daemon=True).start()
    sys.path.insert(0, str(HERE))
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=a.port, log_level="warning")


if __name__ == "__main__":
    main()
