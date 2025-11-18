"""
Trace or script a full model into TorchScript for fast inference.

Usage:
  python export_torchscript.py --model models/model_full.pt --out models/model_ts.pt

This expects a full model file (not a state_dict). Use convert_state_dict.py first if needed.
"""
import argparse
import torch
import os


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--model", required=True, help="Path to full model (torch.save(model))")
    p.add_argument("--out", default="models/model_ts.pt", help="Output TorchScript path")
    args = p.parse_args()

    model_path = args.model
    out_path = args.out

    if not os.path.exists(model_path):
        raise SystemExit(f"Model file not found: {model_path}")

    print("Loading full model:", model_path)
    # The saved file may contain a full model object. Newer PyTorch
    # defaults may use weights-only loading; allow full-object loading
    # by setting weights_only=False (only do this for trusted files).
    model = torch.load(model_path, map_location="cpu", weights_only=False)
    model.eval()

    example = torch.randn(1, 3, 224, 224)
    print("Tracing model to TorchScript (this may take a few seconds)...")
    ts = torch.jit.trace(model, example)
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    ts.save(out_path)
    print("Saved TorchScript to:", out_path)


if __name__ == "__main__":
    main()
