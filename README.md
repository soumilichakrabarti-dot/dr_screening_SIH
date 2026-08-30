# Explainable AI for Diabetic Retinopathy Screening — SIH 2026 (PS #26038)

## What's here
- `backend/model.py` — EfficientNet-B0, 5-class DR grading (ICDR scale)
- `backend/train.py` — fine-tuning script for APTOS 2019 / IDRiD-style CSV+image datasets
- `backend/gradcam.py` — Grad-CAM++ heatmap + plain-language explanation generator
- `backend/app.py` — FastAPI server exposing `POST /predict`
- `frontend/index.html` — single-file demo UI (upload image → grade + heatmap + triage)

## Setup
```bash
cd dr-screening
pip install -r requirements.txt
```

## 1. Get data
Download **APTOS 2019 Blindness Detection** from Kaggle (has `train.csv` with
`id_code,diagnosis` columns — matches `train.py` defaults) or **IDRiD** (also
gives lesion segmentation masks — use these to make the explanation far
stronger than the grid-zone heuristic currently in `gradcam.py`).

Put images in `data/aptos/train_images/`, csv at `data/aptos/train.csv`.

## 2. Train
```bash
cd backend
python train.py --data_dir ../data/aptos/train_images --csv ../data/aptos/train.csv --epochs 15
```
This saves the best checkpoint to `checkpoints/dr_effnet_b0.pt`.

## 3. Point the API at your checkpoint
In `backend/app.py`, set:
```python
WEIGHTS_PATH = "checkpoints/dr_effnet_b0.pt"
```

## 4. Run the backend
```bash
cd backend
uvicorn app:app --host 0.0.0.0 --port 8000 --reload
```

## 5. Open the frontend
Just open `frontend/index.html` in a browser (no build step needed).
Upload a fundus image, hit Analyze.

---

## Roadmap for the hackathon (priority order)
1. **Get a trained baseline working end-to-end** (even a few epochs) — this is
   the single most important thing, everything else builds on it.
2. **Swap the grid-zone explanation for real lesion overlap** using IDRiD's
   lesion masks (microaneurysms / hemorrhages / exudates) and report IoU or
   simple overlap % between Grad-CAM hot regions and actual lesion masks.
   This is what will make your explainability story credible to judges vs.
   "we added Grad-CAM."
2b. Consider adding LIME or SHAP as a second explanation method to show
   agreement/consistency between methods — a nice slide, not required.
3. **Quantize the model** (ONNX or TFLite export) and show it running fast
   on CPU only — ties directly into the "rural, low-bandwidth, low-cost
   hardware" part of the problem statement.
4. **Multilingual explanation text** — even a simple dictionary-based
   translation of the explanation templates into Hindi/regional language
   goes a long way for the "who actually uses this" narrative.
5. **Triage/referral output** — you already get this from `TRIAGE` in
   `model.py`; consider rendering it as a printable/shareable referral slip.
6. **Quality-check gate** — reject blurry/underexposed images before
   diagnosis (simple Laplacian-variance blur check is enough) — shows you
   understand real capture conditions, not just clean benchmark images.

## Not a medical device
Keep this disclaimer visible in the demo — judges will ask about liability
and regulatory pathway (CDSCO / ICMR guidelines) even briefly, so have one
sentence ready on how a real deployment would need clinical validation and
ophthalmologist sign-off, not full autonomy.
