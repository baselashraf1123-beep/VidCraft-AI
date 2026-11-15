"""Entry point for a free Hugging Face *Gradio-SDK* Space (Docker SDK is paid now).
The Space just runs this file; we serve our FastAPI app on port 7860 ourselves."""
import os
import uvicorn
from main import app  # noqa: F401

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=int(os.getenv("PORT", "7860")))
