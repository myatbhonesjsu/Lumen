Model Server for Lumen
=====================

This folder provides a minimal FastAPI server to host your trained PyTorch model.

What I added
------------
- `app.py` - FastAPI app that loads TorchScript or full PyTorch model and exposes `/predict` and `/health`.
- `models/` - place your `model_ts.pt` (TorchScript) or `model_full.pt` (torch.save(model)) here.
- `labels.json` - label list used by the server.
- `scripts/convert_state_dict.py` - convert a state_dict to a full model (no pretrained weights).
- `scripts/export_torchscript.py` - convert full model to TorchScript.
- `scripts/convert_state_dict_pretrained.py` - convert state_dict using pretrained base weights.
- `Dockerfile` - container image to run the server.
- `requirements.txt` - Python runtime requirements for the model server.

Quick local steps
-----------------
1) Convert your state_dict to a full model (use the pretrained script if you want to initialize with ImageNet weights):

   python aws-backend/model-server/scripts/convert_state_dict.py --state /path/to/skin_issues_10class_model.pt --out aws-backend/model-server/models/model_full.pt

   or (use pretrained base weights during model construction):

   python aws-backend/model-server/scripts/convert_state_dict_pretrained.py --state /path/to/skin_issues_10class_model.pt --out aws-backend/model-server/models/model_full.pt

2) Convert to TorchScript for faster serving (optional but recommended):

   python aws-backend/model-server/scripts/export_torchscript.py --model aws-backend/model-server/models/model_full.pt --out aws-backend/model-server/models/model_ts.pt

3) Install dependencies and run locally:

   pip install -r aws-backend/model-server/requirements.txt
   uvicorn aws-backend.model-server.app:app --host 0.0.0.0 --port 8080

4) Docker run (optional):

   docker build -t lumen-model-server -f aws-backend/model-server/Dockerfile aws-backend/model-server
   docker run -p 8080:8080 -v $(pwd)/aws-backend/model-server/models:/app/models lumen-model-server

5) Update your Lambda environment variable `CUSTOM_MODEL_URL` to point to the public URL of `/predict` on this server.

Notes
-----
- The server expects an input file field named `file` and returns JSON with `top_prediction`, `confidence`, and `all_predictions`.
- If you plan to deploy the model server publicly, secure it (authentication, TLS) before setting `CUSTOM_MODEL_URL` in production.
