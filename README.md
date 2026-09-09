# Explainable AI for Diabetic Retinopathy Screening

**Smart India Hackathon 2026 · Problem Statement #26038**

An AI-assisted screening system that grades diabetic retinopathy severity from retinal fundus photographs and explains its reasoning visually — built for deployment in low-resource, rural healthcare settings.

---

## Overview

Diabetic retinopathy is a leading cause of preventable blindness in India, but early screening requires ophthalmologist expertise that is scarce in rural areas. This project combines a deep learning classification pipeline with visual explainability, automated image quality control, and systems-level resource modeling to deliver a screening tool that is both clinically interpretable and practically deployable at scale.

## Key Features

- **DR Severity Grading** — classifies retinal images across the 5-level International Clinical Diabetic Retinopathy (ICDR) scale, from No DR to Proliferative DR
- **Visual Explainability** — Grad-CAM++ heatmaps show which regions of the image drove each prediction, paired with a plain-language explanation
- **Automated Triage** — every prediction includes a concrete referral recommendation, not just a raw grade
- **Image Quality Assessment** — rejects unusable photos (blur, poor illumination, bad framing) before diagnosis, with specific recapture feedback
- **Retinal Structure Extraction** — optic disc localization and vessel network extraction using classical image processing
- **District-Scale Resource Modeling** — Simulink simulation validating screening throughput and staffing requirements for 100,000+ patients/year

## Tech Stack

| Layer | Technology |
|---|---|
| Model | PyTorch, EfficientNet-B0 (transfer learning) |
| Explainability | Grad-CAM++ |
| Backend | FastAPI |
| Frontend | HTML/CSS/JavaScript |
| Image Quality & Structure Extraction | MATLAB (Image Processing Toolbox, Computer Vision Toolbox) |
| Systems Modeling | Simulink |
| Training Data | APTOS 2019 Blindness Detection (Kaggle) |

## System Architecture

```
Fundus Photograph
       │
       ▼
Image Quality Assessment (MATLAB)
       │  reject + recapture feedback, or
       │  CLAHE enhancement for borderline images
       ▼
DR Severity Classification (EfficientNet-B0)
       │
       ▼
Grad-CAM++ Explanation ──── Optic Disc / Vessel Extraction (MATLAB)
       │
       ▼
Triage Recommendation

Separately: Simulink model validates patient throughput vs.
ophthalmologist review capacity at district scale.
```

## Repository Structure

```
├── backend/              FastAPI server, model, training, Grad-CAM
│   ├── app.py
│   ├── model.py
│   ├── train.py
│   └── gradcam.py
├── frontend/              Web demo interface
│   └── index.html
├── notebook/              Model training (Google Colab)
│   └── DR_Screening_Learn_And_Build.ipynb
├── matlab/                Image quality, structure extraction, Simulink models
│   ├── assess_image_quality.m
│   ├── enhance_image.m
│   ├── locate_optic_disc.m
│   ├── extract_vessels.m
│   ├── build_screening_model.m
│   └── build_comparison_model.m
└── requirements.txt
```

## Getting Started

```bash
git clone <https://github.com/soumilichakrabarti-dot/dr_screening_SIH>
cd dr-screening
pip install -r requirements.txt
```

Train the model (or use a provided checkpoint):
```bash
cd backend
python train.py --data_dir <path-to-images> --csv <path-to-labels.csv> --epochs 20
```

Run the backend:
```bash
uvicorn app:app --host 0.0.0.0 --port 8000 --reload
```

Open `frontend/index.html` in a browser and upload a fundus image.

MATLAB scripts in `matlab/` are self-contained — open in MATLAB Online or Desktop and run directly.

## Results

- Trained on APTOS 2019 with class-weighted loss to correct for dataset imbalance
- Simulink resource model: AI-assisted review (≈60 images/hour/ophthalmologist) sustains zero backlog at 100,000+ patients/year with a single reviewing ophthalmologist; traditional manual review (≈6 images/hour) results in unbounded backlog growth under identical patient load
- Image quality module validated against known clear, disease-positive, and degraded test images with correct pass/reject behavior

## Limitations

- Trained on a limited public dataset; not yet validated to clinical sensitivity/specificity standards
- Full lesion-level segmentation (microaneurysms, neovascularization) is not implemented — a research-scale problem beyond this project's current scope
- Intended as a triage-assist tool; not a certified medical device. All outputs require ophthalmologist confirmation before any clinical decision.

## References

- [APTOS 2019 Blindness Detection Dataset](https://www.kaggle.com/c/aptos2019-blindness-detection) — Kaggle
- [IDRiD (Indian Diabetic Retinopathy Image Dataset)](https://idrid.grand-challenge.org/) — planned for future lesion-level validation
- Selvaraju et al., *Grad-CAM: Visual Explanations from Deep Networks via Gradient-based Localization*
- International Clinical Diabetic Retinopathy (ICDR) Severity Scale
