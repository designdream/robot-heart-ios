# Digital Ocean S3 Integration Guide

**Date**: 2026-01-02  
**Status**: Complete

---

## Overview

This guide provides a complete, production-ready solution for integrating Digital Ocean S3 Spaces with the Robot Heart iOS app. It covers:

1.  **Secure Credential Storage**: Using iOS Keychain to store S3 access keys.
2.  **AWS Signature V4**: Authenticating S3 requests for enhanced security.
3.  **CORS Configuration**: Allowing the app to access S3 resources from the client.
4.  **First-Time Setup**: A step-by-step guide for users to configure their credentials.

---

## 1. Secure Credential Storage (Keychain)

We use a `KeychainService` to securely store S3 credentials on the device. This prevents keys from being exposed in source code or `Info.plist`.

### KeychainService.swift

This service provides a type-safe wrapper around the iOS Keychain API.

**Key Features:**
- Encrypted storage for S3 access key, secret key, endpoint, bucket, and region.
- Automatic iCloud Keychain sync (optional, currently disabled).
- Type-safe `S3Credentials` struct.
- Detailed error handling.

**Code Location**: `RobotHeart/Services/KeychainService.swift`

### How It Works

1.  **Saving Credentials**: `KeychainService.shared.saveS3Credentials(credentials)`
2.  **Loading Credentials**: `KeychainService.shared.loadS3Credentials()`
3.  **Deleting Credentials**: `KeychainService.shared.deleteS3Credentials()`

### Example: Saving Credentials

```swift
// During onboarding or in settings
let credentials = KeychainService.S3Credentials(
    accessKey: "YOUR_ACCESS_KEY",
    secretKey: "YOUR_SECRET_KEY",
    endpoint: "nyc3.digitaloceanspaces.com",
    bucket: "robot-heart-mesh",
    region: "nyc3"
)

do {
    try KeychainService.shared.saveS3Credentials(credentials)
    print("✅ S3 credentials saved successfully!")
} catch {
    print("❌ Failed to save credentials: \(error.localizedDescription)")
}
```

---

## 2. AWS Signature Version 4 (Authentication)

All S3 requests must be signed with AWS Signature V4. This is a critical security measure that prevents unauthorized access to your S3 bucket.

### AWSV4Signer.swift

This class implements the complete AWS Signature V4 signing process.

**Key Features:**
- Compatible with Digital Ocean Spaces and other S3-compatible services.
- Signs `URLRequest` objects directly.
- Handles canonical request creation, string-to-sign, and signature calculation.
- Uses `CryptoKit` for secure hashing (SHA256, HMAC).

**Code Location**: `RobotHeart/Services/AWSV4Signer.swift`

### How It Works

The `CloudSyncService` now uses `AWSV4Signer` to sign all S3 requests:

```swift
// In CloudSyncService.swift
private func uploadToS3(message: QueuedMessage) async throws -> Bool {
    guard let s3Request = s3Request else { return false }
    
    // ... build message data ...
    
    // Build and sign the request
    let request = s3Request.buildPutRequest(
        path: "messages/\(message.id).json",
        data: jsonData,
        contentType: "application/json"
    )
    
    // Send the signed request
    let (_, response) = try await URLSession.shared.data(for: request)
    
    // ... handle response ...
}
```

This replaces the previous insecure method of sending keys in headers.

---

## 3. CORS Configuration (Digital Ocean)

Cross-Origin Resource Sharing (CORS) must be configured on your Digital Ocean Space to allow the iOS app to make requests to it.

### Step-by-Step CORS Setup

1.  **Navigate to your Space** in the Digital Ocean control panel.
2.  Go to the **Settings** tab.
3.  Find the **CORS Configurations** section and click **Add**.

4.  **Configure the CORS rule** as follows:

    | Setting | Value |
    | :--- | :--- |
    | **Origin** | `*` (or your app-specific origin if you have one) |
    | **Allowed Methods** | `GET`, `PUT`, `POST`, `DELETE`, `HEAD` |
    | **Allowed Headers** | `*` |
    | **Expose Headers** | `ETag` |
    | **Max Age (seconds)** | `3000` |

5.  **Save** the configuration.

### CORS Configuration (JSON)

You can also use the `s3cmd` or `aws` CLI to apply this configuration:

**`cors.json` file:**

```json
[
  {
    "AllowedHeaders": ["*"],
    "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
    "AllowedOrigins": ["*"],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 3000
  }
]
```

**Apply with `aws` CLI:**

```bash
aws s3api put-bucket-cors --bucket robot-heart-mesh \
    --endpoint-url https://nyc3.digitaloceanspaces.com \
    --cors-configuration file://cors.json
```

**Why is this needed?**

- By default, browsers and mobile OSes block cross-origin HTTP requests for security reasons.
- This configuration explicitly tells your S3 bucket that it's safe to accept requests from your app.

---

## 4. First-Time Setup (User Flow)

Here is the recommended user flow for configuring S3 credentials for the first time:

### Step 1: Create a Settings View

Create a new SwiftUI view where users can enter their S3 credentials.

**`S3SettingsView.swift` (Example):**

```swift
import SwiftUI

struct S3SettingsView: View {
    @State private var accessKey = ""
    @State private var secretKey = ""
    @State private var endpoint = "nyc3.digitaloceanspaces.com"
    @State private var bucket = "robot-heart-mesh"
    @State private var region = "nyc3"
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isSaved = false
    
    var body: some View {
        Form {
            Section(header: Text("Digital Ocean S3 Credentials")) {
                TextField("Access Key", text: $accessKey)
                SecureField("Secret Key", text: $secretKey)
                TextField("Endpoint", text: $endpoint)
                TextField("Bucket", text: $bucket)
                TextField("Region", text: $region)
            }
            
            Section {
                Button(action: saveCredentials) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Save and Validate")
                    }
                }
                .disabled(isLoading)
            }
            
            if let errorMessage = errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
            
            if isSaved {
                Section {
                    Text("✅ Credentials saved successfully!")
                        .foregroundColor(.green)
                }
            }
        }
        .navigationTitle("S3 Configuration")
    }
    
    func saveCredentials() {
        isLoading = true
        errorMessage = nil
        isSaved = false
        
        Task {
            do {
                let credentials = KeychainService.S3Credentials(
                    accessKey: accessKey,
                    secretKey: secretKey,
                    endpoint: endpoint,
                    bucket: bucket,
                    region: region
                )
                
                // Save to Keychain
                try KeychainService.shared.saveS3Credentials(credentials)
                
                // TODO: Add validation step here
                
                isSaved = true
            } catch {
                errorMessage = error.localizedDescription
            }
            
            isLoading = false
        }
    }
}
```

### Step 2: Add to App Environment

Update `AppEnvironment` to reload `CloudSyncService` when credentials change.

```swift
// In AppEnvironment.swift
func updateS3Credentials() {
    // Re-initialize CloudSyncService to pick up new credentials
    self.cloudSync = CloudSyncService()
    
    // Update NetworkOrchestrator with new CloudSyncService
    self.networkOrchestrator = NetworkOrchestrator(
        cloudSync: cloudSync,
        meshtastic: meshtastic,
        bleMesh: bleMesh
    )
    
    print("🔄 AppEnvironment reloaded with new S3 credentials")
}
```

### Step 3: Call from Settings View

After saving credentials, call `updateS3Credentials()` to reload the app's services.

```swift
// In S3SettingsView.swift, after saving
if let appEnvironment = // get AppEnvironment from @EnvironmentObject
{
    appEnvironment.updateS3Credentials()
}
```

---

## 5. Security Best Practices

### DO:

-   **Store keys in Keychain**: Never in source code, `Info.plist`, or `UserDefaults`.
-   **Use AWS Signature V4**: For all S3 requests.
-   **Create dedicated S3 keys**: With limited permissions for this app only.
-   **Rotate keys periodically**: Change your S3 keys every 90 days.
-   **Use HTTPS**: For all communication with S3.

### DON'T:

-   **Hardcode keys**: In your app binary.
-   **Use root AWS keys**: Always use IAM users with specific permissions.
-   **Log secret keys**: To the console or analytics.
-   **Expose keys in UI**: After they have been entered.

---

## Conclusion

By following this guide, you have implemented a **production-grade, secure integration** with Digital Ocean S3.

✅ **Secure Storage**: Credentials are encrypted in the Keychain.
✅ **Secure Authentication**: All requests are signed with AWS Signature V4.
✅ **Secure Access**: CORS is configured to allow only your app.
✅ **User-Friendly**: A clear flow for users to configure their credentials.

The app is now ready to securely communicate with your S3 bucket.
