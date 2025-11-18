import os
import sys
import torch
from collections import OrderedDict

MODEL_PATH = "/Users/shefalisaini/Lumen/aws-backend/model-server/input/skin_issues_state_dict.pt"
OUT_PATH = "/Users/shefalisaini/Lumen/aws-backend/model-server/input/skin_issues_state_dict_extracted.pt"

if not os.path.exists(MODEL_PATH):
    print(f"Model file not found: {MODEL_PATH}")
    sys.exit(2)

print("Loading:", MODEL_PATH)
try:
    obj = torch.load(MODEL_PATH, map_location='cpu')
except Exception as e:
    print("torch.load failed:", e)
    sys.exit(1)

print("Loaded type:", type(obj))

if isinstance(obj, (dict, OrderedDict)):
    keys = list(obj.keys())
    print("Top-level keys (sample 30):", keys[:30])

    # Heuristics: state_dict has parameter-like keys
    param_like = any(('weight' in k or 'bias' in k or 'running_mean' in k or 'running_var' in k or '.' in k) for k in keys)
    nested_state = None
    for candidate in ('model_state', 'model_state_dict', 'state_dict', 'model'):
        if candidate in obj:
            nested_state = obj[candidate]
            print(f"Found nested state under key: {candidate}")
            break

    if nested_state is not None:
        print("Saving nested state to:", OUT_PATH)
        torch.save(nested_state, OUT_PATH)
        print("Saved nested state. You can now run the conversion script on this file.")
        sys.exit(0)

    if param_like:
        print("Looks like a state_dict (parameter keys detected). Saving to:", OUT_PATH)
        torch.save(obj, OUT_PATH)
        print("Saved extracted state_dict. Run convert_state_dict_pretrained.py next.")
        sys.exit(0)

    print("Dict loaded but does not look like a state_dict. Inspect keys above to decide next steps.")
    sys.exit(0)

# If it's a module instance
try:
    import torch.nn as nn
    if isinstance(obj, nn.Module):
        print("Loaded object is a torch.nn.Module (full model). Saving to models/model_full.pt")
        out = "/Users/shefalisaini/Lumen/aws-backend/model-server/models/model_full.pt"
        os.makedirs(os.path.dirname(out), exist_ok=True)
        torch.save(obj, out)
        print("Saved full model to:", out)
        sys.exit(0)
except Exception:
    pass

print("Loaded object is of type", type(obj), "— not directly handled. You may need to inspect it manually.")
print(obj)
