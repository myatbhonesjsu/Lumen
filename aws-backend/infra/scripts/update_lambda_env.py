#!/usr/bin/env python3
"""
Small helper used by Terraform local-exec to merge and set Lambda environment variables.
This script uses the AWS CLI (requires `aws` to be configured) and Python stdlib only.

Usage:
  python3 update_lambda_env.py <lambda_function_name> <alb_dns> <aws_region>

Behavior:
  - Reads existing environment variables via `aws lambda get-function-configuration`.
  - Merges/sets CUSTOM_MODEL_URL to `http://<alb_dns>/predict`.
  - Calls `aws lambda update-function-configuration` with the merged variables.

Note: This will preserve existing env variables and only add/replace CUSTOM_MODEL_URL.
"""
import json
import subprocess
import sys
import shlex


def run(cmd):
    try:
        out = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT)
        return out.decode('utf-8')
    except subprocess.CalledProcessError as e:
        print(f"Command failed: {cmd}\nExit: {e.returncode}\nOutput: {e.output.decode('utf-8')}")
        sys.exit(2)


if __name__ == '__main__':
    if len(sys.argv) < 4:
        print("Usage: update_lambda_env.py <lambda_function_name> <alb_dns> <aws_region>")
        sys.exit(1)

    function_name = sys.argv[1]
    alb_dns = sys.argv[2]
    region = sys.argv[3]

    print(f"Updating Lambda '{function_name}' with CUSTOM_MODEL_URL=http://{alb_dns}/predict in region {region}")

    # Get existing env vars (may be null)
    get_cmd = f"aws lambda get-function-configuration --function-name {shlex.quote(function_name)} --region {shlex.quote(region)} --query 'Environment.Variables' --output json"
    out = run(get_cmd).strip()

    try:
        existing = json.loads(out) if out else {}
        if existing is None:
            existing = {}
    except json.JSONDecodeError:
        print("Warning: could not decode existing environment variables; starting from empty")
        existing = {}

    existing['CUSTOM_MODEL_URL'] = f"http://{alb_dns}/predict"

    env_payload = json.dumps({"Variables": existing})

    # Update the function configuration
    # Use --environment with a JSON string
    update_cmd = f"aws lambda update-function-configuration --function-name {shlex.quote(function_name)} --region {shlex.quote(region)} --environment '{env_payload}'"

    print("Running update:", update_cmd)
    out = run(update_cmd)
    print("Update result:\n", out)
    print("Lambda environment update finished.")
