import SwiftUI
import AVFoundation

/// SwiftUI view for scanning QR codes.
/// Displays camera preview and handles scanned codes.
struct QRCodeScannerView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject private var scanner = QRCodeScanner()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingResult = false
    @State private var resultMessage = ""
    @State private var isProcessing = false
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreview(scanner: scanner)
                .edgesIgnoringSafeArea(.all)
            
            // Overlay
            VStack {
                // Top bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                    
                    Spacer()
                    
                    Text("Scan QR Code")
                        .font(.headline)
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                    
                    Spacer()
                    
                    // Placeholder for symmetry
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .opacity(0)
                }
                .padding()
                
                Spacer()
                
                // Scanning frame
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Theme.Colors.turquoiseSky, lineWidth: 3)
                    .frame(width: 250, height: 250)
                    .overlay(
                        VStack {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 60))
                                .foregroundColor(Theme.Colors.turquoiseSky)
                            
                            Text("Position QR code in frame")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.top, 8)
                        }
                    )
                
                Spacer()
                
                // Instructions
                VStack(spacing: 12) {
                    Text("Scan a Robot Heart QR code to:")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Add a contact")
                        }
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                            Text("Connect to a mesh node")
                        }
                        HStack {
                            Image(systemName: "tent.fill")
                            Text("Join a camp")
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(Theme.Colors.robotCream)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.6))
                )
                .padding()
            }
            
            // Processing overlay
            if isProcessing {
                Color.black.opacity(0.7)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text("Processing...")
                        .foregroundColor(.white)
                        .font(.headline)
                }
            }
            
            // Error message
            if let error = scanner.error {
                VStack {
                    Spacer()
                    
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error.localizedDescription)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red.opacity(0.8))
                    )
                    .padding()
                }
            }
        }
        .alert("QR Code Scanned", isPresented: $showingResult) {
            Button("OK") {
                // Resume scanning
                Task {
                    await scanner.startScanning()
                }
            }
        } message: {
            Text(resultMessage)
        }
        .task {
            await scanner.startScanning()
        }
        .onDisappear {
            scanner.stopScanning()
        }
        .onChange(of: scanner.scannedCode) { newValue in
            if let code = newValue {
                handleScannedCode(code)
            }
        }
    }
    
    // MARK: - Code Handling
    
    private func handleScannedCode(_ code: String) {
        scanner.stopScanning()
        isProcessing = true
        
        Task {
            do {
                // Try to parse as contact
                if let contact = QRContact.fromQRString(code) {
                    try await handleContact(contact)
                    return
                }
                
                // Try to parse as mesh node
                if let node = QRMeshNode.fromQRString(code) {
                    try await handleMeshNode(node)
                    return
                }
                
                // Try to parse as camp invite
                if let invite = QRCampInvite.fromQRString(code) {
                    try await handleCampInvite(invite)
                    return
                }
                
                // Unknown format
                await MainActor.run {
                    resultMessage = "Unknown QR code format"
                    showingResult = true
                    isProcessing = false
                }
                
            } catch {
                await MainActor.run {
                    resultMessage = "Error: \(error.localizedDescription)"
                    showingResult = true
                    isProcessing = false
                }
            }
        }
    }
    
    private func handleContact(_ contact: QRContact) async throws {
        // Use QRCodeManager to process contact
        try await appEnvironment.qrCodeManager.handleScannedContact(contact)
        
        await MainActor.run {
            resultMessage = "Added contact: \(contact.name)"
            showingResult = true
            isProcessing = false
        }
    }
    
    private func handleMeshNode(_ node: QRMeshNode) async throws {
        // Use QRCodeManager to process mesh node
        try await appEnvironment.qrCodeManager.handleScannedMeshNode(node)
        
        await MainActor.run {
            resultMessage = "Connected to mesh node: \(node.nodeName)"
            showingResult = true
            isProcessing = false
        }
    }
    
    private func handleCampInvite(_ invite: QRCampInvite) async throws {
        // Use QRCodeManager to process camp invite
        try await appEnvironment.qrCodeManager.handleScannedCampInvite(invite)
        
        await MainActor.run {
            resultMessage = "Joined camp: \(invite.campName)"
            showingResult = true
            isProcessing = false
        }
    }
}

// MARK: - Camera Preview

struct CameraPreview: UIViewRepresentable {
    let scanner: QRCodeScanner
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Add preview layer if available
        if let previewLayer = scanner.getPreviewLayer() {
            // Remove existing layers
            uiView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
            
            // Add new layer
            previewLayer.frame = uiView.bounds
            uiView.layer.addSublayer(previewLayer)
        }
    }
}

// MARK: - Preview

struct QRCodeScannerView_Previews: PreviewProvider {
    static var previews: some View {
        QRCodeScannerView()
            .environmentObject(AppEnvironment())
    }
}
