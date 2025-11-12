# Demo Authentication Setup

## Overview

The Lumen API now has AWS Cognito authentication enabled. For demo purposes, a test user has been pre-configured so you don't need to implement sign-up/sign-in UI.

## What Was Implemented

### 1. AWS Cognito Setup
- **User Pool ID**: `us-east-1_NBBGEaCAW`
- **App Client ID**: `6kf024iqqn4hqopqn72hsvlmr7`
- **Identity Pool ID**: `us-east-1:3376c0f2-8e80-45cd-857f-874b0de51690`
- **Region**: `us-east-1`

### 2. API Gateway Changes
All three API endpoints now require Cognito authentication:
- `POST /upload-image` - Upload skin analysis image
- `GET /analysis/{id}` - Get analysis results
- `GET /products/recommendations` - Get product recommendations

### 3. Lambda Changes
The Lambda function now:
- Extracts user ID from Cognito JWT tokens
- Validates that users can only access their own data
- Stores user ID with all analysis records

### 4. Demo Test User
**Email**: demo@lumen-app.com
**Password**: DemoPass123!
**User ID (sub)**: c4d8d4d8-2081-7065-6ef4-48001d959f5b

## For iOS App Integration (Demo Mode)

You have two options for demo purposes:

### Option A: Hardcoded Demo Credentials (Simplest)
Create an authentication service that automatically signs in with the demo user:

```swift
import AWSCognitoIdentityProvider

class DemoAuthService {
    static let shared = DemoAuthService()

    private let userPoolId = "us-east-1_NBBGEaCAW"
    private let clientId = "6kf024iqqn4hqopqn72hsvlmr7"
    private let region = AWSRegionType.USEast1

    private var userPool: AWSCognitoIdentityUserPool?
    private var currentUser: AWSCognitoIdentityUser?
    private var idToken: String?

    init() {
        let serviceConfig = AWSServiceConfiguration(
            region: region,
            credentialsProvider: nil
        )
        let poolConfig = AWSCognitoIdentityUserPoolConfiguration(
            clientId: clientId,
            clientSecret: nil,
            poolId: userPoolId
        )
        AWSCognitoIdentityUserPool.register(
            with: serviceConfig,
            userPoolConfiguration: poolConfig,
            forKey: "UserPool"
        )
        userPool = AWSCognitoIdentityUserPool(forKey: "UserPool")
    }

    func authenticateDemo(completion: @escaping (String?, Error?) -> Void) {
        let user = userPool?.getUser("demo@lumen-app.com")

        user?.getSession("demo@lumen-app.com", password: "DemoPass123!", validationData: nil)
            .continueWith { task in
                if let error = task.error {
                    completion(nil, error)
                    return nil
                }

                if let session = task.result {
                    self.idToken = session.idToken?.tokenString
                    completion(self.idToken, nil)
                }

                return nil
            }
    }

    func getIdToken() -> String? {
        return idToken
    }
}
```

### Option B: Use AWS Amplify (Recommended for Production)
If you want a more robust solution:

1. Add AWS Amplify to your Podfile:
```ruby
pod 'Amplify'
pod 'AmplifyPlugins/AWSCognitoAuthPlugin'
```

2. Configure Amplify in your app:
```swift
import Amplify
import AWSCognitoAuthPlugin

func configureAmplify() {
    do {
        try Amplify.add(plugin: AWSCognitoAuthPlugin())
        try Amplify.configure()
    } catch {
        print("Error configuring Amplify: \(error)")
    }
}
```

3. Sign in with demo credentials:
```swift
func signInDemo() {
    Amplify.Auth.signIn(
        username: "demo@lumen-app.com",
        password: "DemoPass123!"
    ) { result in
        switch result {
        case .success:
            print("Demo user signed in successfully")
        case .failure(let error):
            print("Sign in failed: \(error)")
        }
    }
}
```

## Updating API Calls

Once authenticated, include the ID token in all API requests:

```swift
var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("application/json", forHTTPHeaderField: "Content-Type")

// Add Cognito authentication
if let idToken = DemoAuthService.shared.getIdToken() {
    request.setValue(idToken, forHTTPHeaderField: "Authorization")
}
```

## Testing Authentication

### Test 1: Unauthenticated Request (Should Fail)
```bash
curl -X POST "https://ylt3xkf8mf.execute-api.us-east-1.amazonaws.com/dev/upload-image"
# Expected: {"message":"Unauthorized"}
```

### Test 2: Get Cognito Token
```bash
aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id 6kf024iqqn4hqopqn72hsvlmr7 \
  --auth-parameters USERNAME=demo@lumen-app.com,PASSWORD=DemoPass123! \
  --region us-east-1
```

This will return an `IdToken` that you can use for testing.

### Test 3: Authenticated Request (Should Succeed)
```bash
curl -X POST "https://ylt3xkf8mf.execute-api.us-east-1.amazonaws.com/dev/upload-image" \
  -H "Authorization: <ID_TOKEN_FROM_STEP_2>"
```

## Security Notes

**IMPORTANT**: This demo setup is for project demonstration purposes only. For production:

1. Remove hardcoded credentials
2. Implement proper sign-up/sign-in UI
3. Store tokens securely in Keychain
4. Implement token refresh logic
5. Add proper error handling
6. Consider certificate pinning

## What This Achieves for Demo

✅ API endpoints are protected with authentication
✅ User data is isolated (users can only see their own analyses)
✅ Demo works without requiring user sign-up flow
✅ You can demonstrate security best practices

## Troubleshooting

### Token Expired Error
Tokens expire after 1 hour. Re-authenticate to get a new token.

### User Not Found
Make sure you're using the exact email: `demo@lumen-app.com`

### Unauthorized Error
Check that the Authorization header includes the ID token (not access token).

## Next Steps

1. Add AWS SDK or Amplify to your iOS app
2. Implement the demo authentication service
3. Update all API calls to include the Authorization header
4. Test the complete flow
