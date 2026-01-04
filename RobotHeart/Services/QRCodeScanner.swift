import AVFoundation
import SwiftUI
import Combine

/// QR Code scanning service using AVFoundation.
/// Handles camera permissions, scanning, and QR code generation.
@MainActor
class QRCodeScanner: NSObject, ObservableObject {
    
    // MARK: - Published State
    
    @Published var isScanning = false
    @Published var scannedCode: String?
    @Published var error: ScannerError?
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    
    enum ScannerError: Error, LocalizedError {
        case cameraUnavailable
        case permissionDenied
        case invalidQRCode
        case sessionFailed
        
        var errorDescription: String? {
            switch self {
            case .cameraUnavailable:
                return "Camera is not available on this device"
            case .permissionDenied:
                return "Camera permission denied. Please enable in Settings."
            case .invalidQRCode:
                return "Invalid QR code format"
            case .sessionFailed:
                return "Failed to start camera session"
            }
        }
    }
    
    // MARK: - AVFoundation Components
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let sessionQueue = DispatchQueue(label: "com.robotheart.qr-scanner")
    
    // MARK: - Callbacks
    
    var onCodeScanned: ((String) -> Void)?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        checkCameraAuthorization()
    }
    
    // MARK: - Authorization
    
    func checkCameraAuthorization() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    func requestCameraPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            authorizationStatus = .authorized
            return true
            
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            authorizationStatus = granted ? .authorized : .denied
            return granted
            
        case .denied, .restricted:
            authorizationStatus = status
            error = .permissionDenied
            return false
            
        @unknown default:
            return false
        }
    }
    
    // MARK: - Scanning
    
    /// Start scanning for QR codes
    func startScanning() async {
        guard !isScanning else { return }
        
        // Check permission
        let hasPermission = await requestCameraPermission()
        guard hasPermission else {
            error = .permissionDenied
            return
        }
        
        // Setup capture session
        sessionQueue.async { [weak self] in
            self?.setupCaptureSession()
        }
    }
    
    /// Stop scanning
    func stopScanning() {
        guard isScanning else { return }
        
        sessionQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
            
            Task { @MainActor in
                self?.isScanning = false
                self?.captureSession = nil
                self?.previewLayer = nil
            }
        }
    }
    
    private func setupCaptureSession() {
        let session = AVCaptureSession()
        
        // Get camera device
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            Task { @MainActor in
                self.error = .cameraUnavailable
            }
            return
        }
        
        // Create input
        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            Task { @MainActor in
                self.error = .sessionFailed
            }
            return
        }
        
        // Add input to session
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            Task { @MainActor in
                self.error = .sessionFailed
            }
            return
        }
        
        // Create output
        let metadataOutput = AVCaptureMetadataOutput()
        
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            Task { @MainActor in
                self.error = .sessionFailed
            }
            return
        }
        
        // Store session
        Task { @MainActor in
            self.captureSession = session
            self.isScanning = true
        }
        
        // Start session
        session.startRunning()
    }
    
    /// Get the preview layer for displaying camera feed
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        guard let session = captureSession else { return nil }
        
        if previewLayer == nil {
            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            previewLayer = layer
        }
        
        return previewLayer
    }
    
    // MARK: - QR Code Generation
    
    /// Generate a QR code image from a string
    static func generateQRCode(from string: String, size: CGSize = CGSize(width: 300, height: 300)) -> UIImage? {
        let data = string.data(using: .utf8)
        
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction
        
        guard let ciImage = filter.outputImage else { return nil }
        
        // Scale the image
        let scaleX = size.width / ciImage.extent.width
        let scaleY = size.height / ciImage.extent.height
        let transformedImage = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        // Convert to UIImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension QRCodeScanner: AVCaptureMetadataOutputObjectsDelegate {
    
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        // Find QR code
        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else {
            return
        }
        
        // Notify on main thread
        Task { @MainActor in
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            // Update state
            self.scannedCode = stringValue
            self.onCodeScanned?(stringValue)
            
            print("📷 [QRScanner] Scanned: \(stringValue)")
        }
    }
}

// MARK: - QR Code Data Models

/// Represents a contact that can be shared via QR code
struct QRContact: Codable {
    let id: String
    let name: String
    let role: String?
    let meshtasticNodeID: UInt32?
    let campID: String
    
    /// Encode to JSON string for QR code
    func toQRString() -> String? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return "robotheart://contact/\(json)"
    }
    
    /// Decode from QR code string
    static func fromQRString(_ string: String) -> QRContact? {
        guard string.hasPrefix("robotheart://contact/") else { return nil }
        
        let jsonString = string.replacingOccurrences(of: "robotheart://contact/", with: "")
        guard let data = jsonString.data(using: .utf8) else { return nil }
        
        let decoder = JSONDecoder()
        return try? decoder.decode(QRContact.self, from: data)
    }
}

/// Represents a mesh node that can be shared via QR code
struct QRMeshNode: Codable {
    let nodeID: UInt32
    let nodeName: String
    let hardwareModel: String
    let firmwareVersion: String?
    let publicKey: String?
    
    /// Encode to JSON string for QR code
    func toQRString() -> String? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return "robotheart://node/\(json)"
    }
    
    /// Decode from QR code string
    static func fromQRString(_ string: String) -> QRMeshNode? {
        guard string.hasPrefix("robotheart://node/") else { return nil }
        
        let jsonString = string.replacingOccurrences(of: "robotheart://node/", with: "")
        guard let data = jsonString.data(using: .utf8) else { return nil }
        
        let decoder = JSONDecoder()
        return try? decoder.decode(QRMeshNode.self, from: data)
    }
}

/// Represents a camp invite that can be shared via QR code
struct QRCampInvite: Codable {
    let campID: String
    let campName: String
    let inviteCode: String
    let expiresAt: Date?
    
    /// Encode to JSON string for QR code
    func toQRString() -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return "robotheart://invite/\(json)"
    }
    
    /// Decode from QR code string
    static func fromQRString(_ string: String) -> QRCampInvite? {
        guard string.hasPrefix("robotheart://invite/") else { return nil }
        
        let jsonString = string.replacingOccurrences(of: "robotheart://invite/", with: "")
        guard let data = jsonString.data(using: .utf8) else { return nil }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(QRCampInvite.self, from: data)
    }
}
