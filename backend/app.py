"""
FastAPI backend for the DR screening demo.

Run:
    uvicorn app:app --host 0.0.0.0 --port 8000 --reload

Endpoint:
    POST /predict  (multipart form, field name "file")
    -> {
         "grade": int, "label": str, "confidence": float,
         "triage": str, "explanation": str,
         "heatmap_base64": str  (PNG, base64-encoded overlay image)
       }

NOTE: without trained weights this will run but give meaningless
predictions — see train.py first. Set WEIGHTS_PATH once you have a
checkpoint.
"""
import base64
import io

import cv2
import numpy as np
import torch
from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from PIL import Image
from torchvision import transforms

from model import load_model, CLASS_NAMES, TRIAGE
from gradcam import generate_heatmap, describe_activation_regions, build_explanation

WEIGHTS_PATH = "checkpoints/dr_effnet_b0.pt"  # e.g. "checkpoints/dr_effnet_b0.pt" once trained
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
IMG_SIZE = 224

app = FastAPI(title="Explainable DR Screening API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # tighten this before any real deployment
    allow_methods=["*"],
    allow_headers=["*"],
)

model = load_model(WEIGHTS_PATH, device=DEVICE)

preprocess = transforms.Compose([
    transforms.Resize((IMG_SIZE, IMG_SIZE)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
])


@app.get("/health")
def health():
    return {"status": "ok", "device": DEVICE, "weights_loaded": WEIGHTS_PATH is not None}


@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    raw = await file.read()
    pil_img = Image.open(io.BytesIO(raw)).convert("RGB")

    # normalized tensor for the model
    input_tensor = preprocess(pil_img).unsqueeze(0).to(DEVICE)

    # 0..1 float RGB image at the same size, for the Grad-CAM overlay
    rgb_resized = pil_img.resize((IMG_SIZE, IMG_SIZE))
    rgb_float = np.array(rgb_resized).astype(np.float32) / 255.0

    with torch.no_grad():
        logits = model(input_tensor)
        probs = torch.softmax(logits, dim=1)[0]
        predicted_class = int(torch.argmax(probs).item())
        confidence = float(probs[predicted_class].item())

    # Grad-CAM needs gradients, so run it outside no_grad
    overlay, grayscale_cam = generate_heatmap(model, input_tensor, rgb_float, predicted_class)
    hot_zones = describe_activation_regions(grayscale_cam)
    explanation = build_explanation(predicted_class, confidence, hot_zones)

    # encode overlay as base64 PNG for the frontend
    overlay_bgr = cv2.cvtColor(overlay, cv2.COLOR_RGB2BGR)
    success, buf = cv2.imencode(".png", overlay_bgr)
    heatmap_b64 = base64.b64encode(buf.tobytes()).decode("utf-8") if success else None

    top3_idx = torch.topk(probs, k=min(3, len(CLASS_NAMES))).indices.tolist()
    top3 = [{"label": CLASS_NAMES[i], "confidence": round(float(probs[i]), 3)} for i in top3_idx]

    return JSONResponse({
        "grade": predicted_class,
        "label": CLASS_NAMES[predicted_class],
        "confidence": round(confidence, 3),
        "top3": top3,
        "triage": TRIAGE[predicted_class],
        "explanation": explanation,
        "heatmap_base64": heatmap_b64,
    })
