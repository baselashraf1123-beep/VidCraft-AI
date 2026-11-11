"""Deploy the backend to a free Hugging Face Space.
Usage:  HF_TOKEN=hf_xxx PEXELS_API_KEY=xxx python3 deploy_hf.py [space-name]
The HF token needs 'write' access (https://huggingface.co/settings/tokens).
"""
import os, sys, shutil, tempfile
from pathlib import Path
from huggingface_hub import HfApi

tok = os.environ["HF_TOKEN"]
name = sys.argv[1] if len(sys.argv) > 1 else "vidcraft-ai"
api = HfApi(token=tok)
user = api.whoami()["name"]
repo = f"{user}/{name}"
api.create_repo(repo, repo_type="space", space_sdk="docker", exist_ok=True)
for k in ("PEXELS_API_KEY", "PIXABAY_API_KEY", "GEMINI_API_KEY", "POLLINATIONS_KEY"):
    if os.environ.get(k):
        api.add_space_secret(repo, k, os.environ[k])
src = Path(__file__).parent
with tempfile.TemporaryDirectory() as t:
    dst = Path(t) / "s"
    shutil.copytree(src, dst, ignore=shutil.ignore_patterns("outputs", "__pycache__", ".env", "deploy_hf.py", "SPACE_README.md", ".dockerignore"))
    shutil.copy(src / "SPACE_README.md", dst / "README.md")
    api.upload_folder(folder_path=str(dst), repo_id=repo, repo_type="space")
print("Space:", f"https://huggingface.co/spaces/{repo}")
print("API URL:", f"https://{user.lower()}-{name.lower()}.hf.space")
