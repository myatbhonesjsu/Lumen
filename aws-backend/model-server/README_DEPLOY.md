Docker build and push instructions for the model server.

1) Build locally

```bash
cd aws-backend/model-server
docker build -t lumen-skin-model:latest .
```

2) Create ECR repo and push (replace ACCOUNT_ID and REGION)

```bash
ACCOUNT_ID=YOUR_AWS_ACCOUNT_ID
REGION=us-east-1
REPO=lumen-skin-model

aws ecr create-repository --repository-name $REPO --region $REGION || true
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com
docker tag lumen-skin-model:latest $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO:latest
docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO:latest
```

3) Terraform deploy (from `aws-backend/infra`)

Fill a small `terraform.tfvars` with:
```
aws_region = "us-east-1"
account_id = "YOUR_AWS_ACCOUNT_ID"
image_tag  = "latest"
```

Then:

```bash
cd aws-backend/infra
terraform init
terraform apply -auto-approve -var='aws_region=us-east-1'
```

4) Get ALB DNS from Terraform output and set Lambda env var `CUSTOM_MODEL_URL` to `http://<alb_dns>/predict`.

5) Tear down when done:

```bash
terraform destroy -auto-approve -var='aws_region=us-east-1'
```
