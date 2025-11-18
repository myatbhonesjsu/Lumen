"""
Convert a PyTorch state_dict (saved via model.state_dict()) into a full model file.

Usage:
  python convert_state_dict.py --state state_dict.pth --out models/model_full.pt

Place your state_dict in the working directory or provide full path.
"""
import argparse
import torch
from torchvision import models
import torch.nn as nn
import os

FINAL_CLASSES = [
    "acne", "blackheads", "whiteheads", "dark spots", "pores",
    "wrinkles", "dry skin", "oily skin", "eyebags", "skin redness"
]


def build_model(num_classes: int):
    model = models.efficientnet_b0(weights=None)
    num_features = model.classifier[1].in_features
    model.classifier[1] = nn.Linear(num_features, num_classes)
    return model


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--state", required=True, help="Path to state_dict .pth/.pt file")
    p.add_argument("--out", default="models/model_full.pt", help="Output full model path")
    args = p.parse_args()

    state_path = args.state
    out_path = args.out

    if not os.path.exists(state_path):
        raise SystemExit(f"State dict not found: {state_path}")

    print("Loading state dict:", state_path)
    sd = torch.load(state_path, map_location="cpu")

    model = build_model(len(FINAL_CLASSES))
    model.load_state_dict(sd)
    model.eval()

    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    torch.save(model, out_path)
    print("Saved full model to:", out_path)


if __name__ == "__main__":
    main()
