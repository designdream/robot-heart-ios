import SwiftUI

/// Settings view for configuring Digital Ocean S3 credentials.
/// Allows users to securely enter and save their S3 access keys.
struct S3SettingsView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    
    @State private var accessKey = ""
    @State private var secretKey = ""
    @State private var endpoint = "nyc3.digitaloceanspaces.com"
    @State private var bucket = "robot-heart-mesh"
    @State private var region = "nyc3"
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isSaved = false
    @State private var isValidating = false
    @State private var validationResult: ValidationResult?
    
    enum ValidationResult {
        case success
        case failure(String)
        
        var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }
    }
    
    var body: some View {
        Form {
            // Header Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cloud Sync Configuration")
                        .font(.headline)
                    
                    Text("Enter your Digital Ocean S3 credentials to enable cloud synchronization. Your keys are stored securely in the iOS Keychain.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Credentials Section
            Section(header: Text("Digital Ocean S3 Credentials")) {
                TextField("Access Key", text: $accessKey)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                SecureField("Secret Key", text: $secretKey)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                TextField("Endpoint", text: $endpoint)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                TextField("Bucket", text: $bucket)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                TextField("Region", text: $region)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            
            // Actions Section
            Section {
                Button(action: saveCredentials) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                        Text(isLoading ? "Saving..." : "Save Credentials")
                    }
                }
                .disabled(isLoading || !isFormValid)
                
                if KeychainService.shared.hasS3Credentials() {
                    Button(action: validateCredentials) {
                        HStack {
                            if isValidating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            }
                            Text(isValidating ? "Validating..." : "Validate Credentials")
                        }
                    }
                    .disabled(isValidating)
                    
                    Button(role: .destructive, action: deleteCredentials) {
                        Text("Delete Credentials")
                    }
                }
            }
            
            // Status Section
            if let errorMessage = errorMessage {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            
            if isSaved {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Credentials saved successfully!")
                            .foregroundColor(.green)
                    }
                }
            }
            
            if let validationResult = validationResult {
                Section {
                    switch validationResult {
                    case .success:
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Credentials validated successfully!")
                                .foregroundColor(.green)
                        }
                    case .failure(let message):
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text("Validation failed: \(message)")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            // Help Section
            Section(header: Text("Need Help?")) {
                Link(destination: URL(string: "https://docs.digitalocean.com/products/spaces/how-to/manage-access/")!) {
                    HStack {
                        Text("How to get S3 credentials")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                    }
                }
                
                Link(destination: URL(string: "https://cloud.digitalocean.com/spaces")!) {
                    HStack {
                        Text("Digital Ocean Spaces Console")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                    }
                }
            }
        }
        .navigationTitle("S3 Configuration")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadExistingCredentials)
    }
    
    // MARK: - Computed Properties
    
    var isFormValid: Bool {
        !accessKey.isEmpty && !secretKey.isEmpty && !endpoint.isEmpty && !bucket.isEmpty && !region.isEmpty
    }
    
    // MARK: - Actions
    
    func loadExistingCredentials() {
        do {
            let credentials = try KeychainService.shared.loadS3Credentials()
            accessKey = credentials.accessKey
            secretKey = String(repeating: "•", count: 20) // Mask existing secret
            endpoint = credentials.endpoint
            bucket = credentials.bucket
            region = credentials.region
        } catch {
            // No existing credentials, leave fields empty
        }
    }
    
    func saveCredentials() {
        isLoading = true
        errorMessage = nil
        isSaved = false
        validationResult = nil
        
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
                
                // Reload CloudSyncService with new credentials
                await MainActor.run {
                    appEnvironment.updateS3Credentials()
                    isSaved = true
                }
                
                // Auto-validate after saving
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
                await validateCredentials()
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    func validateCredentials() {
        isValidating = true
        validationResult = nil
        
        Task {
            do {
                let isValid = try await KeychainService.shared.validateS3Credentials()
                
                await MainActor.run {
                    if isValid {
                        validationResult = .success
                    } else {
                        validationResult = .failure("Invalid credentials or no access to bucket")
                    }
                }
            } catch {
                await MainActor.run {
                    validationResult = .failure(error.localizedDescription)
                }
            }
            
            await MainActor.run {
                isValidating = false
            }
        }
    }
    
    func deleteCredentials() {
        do {
            try KeychainService.shared.deleteS3Credentials()
            
            // Clear form
            accessKey = ""
            secretKey = ""
            endpoint = "nyc3.digitaloceanspaces.com"
            bucket = "robot-heart-mesh"
            region = "nyc3"
            
            isSaved = false
            validationResult = nil
            
            // Reload CloudSyncService
            appEnvironment.updateS3Credentials()
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview

struct S3SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            S3SettingsView()
                .environmentObject(AppEnvironment())
        }
    }
}
