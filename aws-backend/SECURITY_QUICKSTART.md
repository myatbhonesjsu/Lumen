# Security Quick Fixes (30 Minutes)

These are the **minimum** security improvements you should make before any public deployment.

## Quick Fix #1: Restrict CORS (5 minutes)

**Current Risk**: Anyone can call your API from any website.

### Fix:

Edit `terraform/s3.tf` line 62:

```terraform
# BEFORE:
allowed_origins = ["*"] # Restrict to your app domain in production

# AFTER:
allowed_origins = ["lumen://"]  # Only your iOS app
```

Then redeploy:
```bash
cd terraform
terraform apply
```

---

## Quick Fix #2: Add User ID Validation (10 minutes)

**Current Risk**: Anyone can view any analysis result.

### Fix:

Edit `lambda/handler.py` in the `handle_get_analysis` function (around line 536):

```python
# ADD THIS CODE after line 549:

def handle_get_analysis(event):
    try:
        # Extract analysis_id from path
        path_params = event.get('pathParameters', {})
        analysis_id = path_params.get('id')

        if not analysis_id:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Missing analysis_id'})
            }

        # ⚠️ ADD THIS: Get user_id from headers
        headers = event.get('headers', {})
        request_user_id = headers.get('x-user-id', 'anonymous')

        # Query DynamoDB
        response = analyses_table.get_item(
            Key={
                'analysis_id': analysis_id,
                'user_id': request_user_id  # CHANGED: Use request user
            }
        )

        if 'Item' not in response:
            # ⚠️ ADD THIS: Return 403 if not found (user doesn't own it)
            return {
                'statusCode': 403,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Forbidden'})
            }

        # Rest of function...
```

Rebuild and update Lambda:
```bash
cd aws-backend
./scripts/build-lambda.sh
aws lambda update-function-code \
  --function-name lumen-skincare-dev-analyze-skin \
  --zip-file fileb://lambda/lambda_deployment.zip
```

---

## Quick Fix #3: Add API Key Requirement (15 minutes)

**Current Risk**: Unlimited API access, potential cost abuse.

### Fix:

Edit `terraform/api_gateway.tf`:

```terraform
# Add API key resource
resource "aws_api_gateway_api_key" "main" {
  name = "${local.prefix}-api-key"
}

# Update usage plan to require API key
resource "aws_api_gateway_usage_plan" "main" {
  name = "${local.prefix}-usage-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = aws_api_gateway_stage.main.stage_name
  }

  throttle_settings {
    burst_limit = 100
    rate_limit  = 50
  }

  quota_settings {
    limit  = 10000
    period = "DAY"
  }
}

# Associate API key with usage plan
resource "aws_api_gateway_usage_plan_key" "main" {
  key_id        = aws_api_gateway_api_key.main.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.main.id
}

# Update methods to require API key
resource "aws_api_gateway_method" "upload_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.upload.id
  http_method   = "POST"
  authorization = "NONE"
  api_key_required = true  # ADD THIS
}

resource "aws_api_gateway_method" "analysis_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.analysis_id.id
  http_method   = "GET"
  authorization = "NONE"
  api_key_required = true  # ADD THIS
}

# Output API key
output "api_key_value" {
  description = "API Key for iOS app"
  value       = aws_api_gateway_api_key.main.value
  sensitive   = true
}
```

Deploy:
```bash
cd terraform
terraform apply
```

Get your API key:
```bash
terraform output -raw api_key_value
```

Update iOS app (`AWSBackendService.swift`):
```swift
var request = URLRequest(url: url, timeoutInterval: AWSConfig.requestTimeout)
request.httpMethod = "POST"
request.setValue("YOUR_API_KEY_HERE", forHTTPHeaderField: "x-api-key")  // ADD THIS
```

---

## Quick Security Test

After implementing fixes, test:

```bash
# Test 1: Without API key should fail
curl -X POST "https://YOUR_API_URL/dev/upload-image"
# Expected: {"message":"Forbidden"}

# Test 2: With wrong user_id should fail
curl -X GET "https://YOUR_API_URL/dev/analysis/test-123" \
  -H "x-api-key: YOUR_KEY" \
  -H "x-user-id: wrong-user"
# Expected: {"error":"Forbidden"}

# Test 3: CORS check
curl -X OPTIONS "https://YOUR_API_URL/dev/upload-image" \
  -H "Origin: http://malicious-site.com"
# Expected: Should NOT have Access-Control-Allow-Origin
```

---

## What This Achieves

✅ **CORS locked down** - Only your iOS app can call API
✅ **API key required** - Prevents unauthorized access
✅ **User validation** - Users can only see their own data
✅ **Rate limiting** - Prevents abuse (already had this)

## What's Still Missing

❌ User authentication (AWS Cognito) - See SECURITY_AUDIT.md
❌ Certificate pinning in iOS app
❌ Input validation in Lambda
❌ WAF protection
❌ Security monitoring

---

## For Academic Project / MVP

These 3 quick fixes are **sufficient** for:
- ✅ Class project demonstration
- ✅ Beta testing with trusted users
- ✅ Portfolio demo

## For Public Production

You **still need** to implement:
- AWS Cognito for proper user authentication
- Privacy policy and terms of service
- Data deletion API (GDPR/CCPA)
- Security monitoring and alerts

See full details in `SECURITY_AUDIT.md`.

---

## Need Help?

Check logs if something breaks:
```bash
aws logs tail /aws/lambda/lumen-skincare-dev-analyze-skin --follow
```

Rollback if needed:
```bash
cd terraform
terraform apply -target=aws_api_gateway_stage.main
```
