# ⚡ Quick Deploy Guide

## One Command Deployment

```bash
cd aws-backend
./deploy.sh
```

**Time**: ~7 minutes  
**Cost**: ~$19/month (10K users)

---

## What Happens

1. ✅ Checks AWS CLI, Terraform, Python, Node
2. ✅ Builds Lambda package
3. ✅ Deploys infrastructure (S3, Lambda, API Gateway, DynamoDB)
4. ✅ Loads 12 products into database
5. ✅ Tests endpoints
6. ✅ Gives you API URL

---

## After Deployment

### Update iOS App

1. **Copy API URL** from deploy output
2. **Open** `AWSBackendService.swift`
3. **Replace**:
   ```swift
   static let apiEndpoint = "YOUR_URL_HERE"
   ```
4. **Add file** to Xcode project
5. **Replace** analysis call (see example in file)

### Test It

Take photo in app → See results in seconds!

---

## Optional: Enable Bedrock Agent

**For advanced AI with managed framework**:

1. AWS Console → Bedrock → Request access
2. Create agent with Claude 3 Sonnet
3. Update Lambda:
   ```bash
   aws lambda update-function-configuration \
     --function-name lumen-skincare-dev-analyze-skin \
     --environment Variables="{BEDROCK_AGENT_ID=YOUR_ID,...}"
   ```

See `README.md` for detailed steps.

---

## Monitoring

```bash
# View logs
aws logs tail /aws/lambda/lumen-skincare-dev-analyze-skin --follow

# Check DynamoDB
aws dynamodb scan --table-name lumen-skincare-dev-products --limit 5
```

---

## Cleanup (When Done)

```bash
cd terraform
terraform destroy
```

This removes all AWS resources and stops billing.

---

## Cost Control

- **Free tier**: First year ~50% off
- **Auto-cleanup**: Images deleted after 30 days
- **Pay-per-use**: Only charged for actual requests
- **No upfront**: No servers to provision

**Estimated**:
- Development: ~$5/month (low usage)
- Production: ~$19/month (10K users)
- With Bedrock: ~$109/month (10K users)

---

## Need Help?

- Full guide: `README.md`
- Architecture: `../AWS_ARCHITECTURE.md`
- Comparison: `../ARCHITECTURE_DECISION.md`

---

## Quick Commands

```bash
# Deploy everything
./deploy.sh

# Build Lambda only
./scripts/build-lambda.sh

# Load products only
cd scripts && node load-products.js

# Show outputs
cd terraform && terraform output

# Destroy everything
cd terraform && terraform destroy
```

---

**Ready?** Run `./deploy.sh` and follow prompts! 🚀

