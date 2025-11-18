import io
import json
import os
from typing import Dict

from fastapi import FastAPI, File, UploadFile, HTTPException
import io
import json
import os
from typing import Dict

from fastapi import FastAPI, File, UploadFile, HTTPException
from pydantic import BaseModel
from PIL import Image
import torch
from torchvision import transforms, models

ROOT = os.path.dirname(__file__)
MODEL_DIR = os.path.join(ROOT, "models")
TS_MODEL_PATH = os.path.join(MODEL_DIR, "model_ts.pt")
FULL_MODEL_PATH = os.path.join(MODEL_DIR, "model_full.pt")
LABELS_PATH = os.path.join(ROOT, "labels.json")

app = FastAPI(title="Lumen Skin Model Server")


def load_labels():
    if not os.path.exists(LABELS_PATH):
        raise FileNotFoundError("labels.json not found in model-server folder")
    with open(LABELS_PATH, "r") as f:
        return json.load(f)


def build_model(num_classes: int):
    model = models.efficientnet_b0(weights=None)
    num_features = model.classifier[1].in_features
    model.classifier[1] = torch.nn.Linear(num_features, num_classes)
    return model


def load_model():
    labels = load_labels()
    num_classes = len(labels)

    # Prefer TorchScript for inference
    if os.path.exists(TS_MODEL_PATH):
        model = torch.jit.load(TS_MODEL_PATH, map_location="cpu")
        model.eval()
        return model, labels

    # Fallback to full model
    if os.path.exists(FULL_MODEL_PATH):
        model = torch.load(FULL_MODEL_PATH, map_location="cpu")
        model.eval()
        return model, labels

    # If only state_dict present, tell user to run conversion scripts
    raise FileNotFoundError("No model file found. Place TorchScript (`model_ts.pt`) or full model (`model_full.pt`) in `model-server/models/` and restart.")


MODEL, LABELS = None, None


def get_model():
    global MODEL, LABELS
    if MODEL is None:
        MODEL, LABELS = load_model()
    return MODEL, LABELS


transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
])


class PredictionResponse(BaseModel):
    top_prediction: str
    confidence: float
    all_predictions: Dict[str, float]


@app.post("/predict", response_model=PredictionResponse)
async def predict(file: UploadFile = File(...)):
    try:
        content = await file.read()
        image = Image.open(io.BytesIO(content)).convert("RGB")
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Cannot read image: {e}")

    model, labels = get_model()

    # Preprocess
    x = transform(image).unsqueeze(0)

    # Inference
    with torch.no_grad():
        out = model(x)
        probs = torch.softmax(out, dim=1)[0].cpu().numpy()

    # Build predictions
    all_preds = {label: float(probs[i]) for i, label in enumerate(labels)}
    top_idx = int(probs.argmax())
    top_label = labels[top_idx]
    confidence = float(probs[top_idx])

    return PredictionResponse(top_prediction=top_label, confidence=confidence, all_predictions=all_preds)


@app.get("/health")
def health():
    return {"status": "ok"}
