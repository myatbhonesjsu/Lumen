This folder contains Terraform to deploy the TorchScript model server to ECS/Fargate in us-east-1.

Overview
- Creates an ECR repository and pushes an image you build locally.
- Deploys an ECS cluster with a single Fargate service (0.25 vCPU / 0.5 GB) running your container.
- Attaches an Application Load Balancer (ALB) with a listener on port 80; health check path is `/health`.

Quick flow (what you run locally)
1. Build the Docker image locally (see `../model-server/README_DEPLOY.md`).
2. Push the image to ECR (commands are in that README).
3. Fill `terraform.tfvars` with your AWS account id and image tag (example below).
4. Run `terraform init && terraform apply -var='aws_region=us-east-1' -auto-approve`.

Security note
- This is a simple student-focused example. For production use you should tighten IAM policies, enable HTTPS on the ALB (ACM cert), and add autoscaling.

Example `terraform.tfvars`
```
aws_region = "us-east-1"
account_id = "123456789012"
image_tag  = "latest"
```

After apply
- Terraform outputs `alb_dns_name` which you can use as your `CUSTOM_MODEL_URL` as `http://<alb_dns_name>/predict`.

Optional: automatically update an existing Lambda's environment
-----------------------------------------------------------
This repo includes a small helper to update an existing Lambda function's environment variable `CUSTOM_MODEL_URL` to point at the ALB created by Terraform.

- The helper script is `scripts/update_lambda_env.py` inside this folder and uses the AWS CLI to merge and update env vars.
- The deploy script `../model-server/deploy.sh` will prompt after `terraform apply` and can run the helper for you (requires `aws` CLI and `python3` on PATH).
- Alternatively, set the env var manually in the Lambda console or via `aws lambda update-function-configuration`.

Teardown
- Run `terraform destroy -var='aws_region=us-east-1' -auto-approve` to remove resources.
