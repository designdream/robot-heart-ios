import SwiftUI

/// SwiftUI view for generating and displaying QR codes.
/// Allows users to share their contact info, mesh node, or camp invite.
struct QRCodeGeneratorView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    
    enum QRType {
        case contact
        case meshNode
        case campInvite
    }
    
    @State private var selectedType: QRType = .contact
    @State private var qrImage: UIImage?
    @State private var qrString: String = ""
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Type selector
                    Picker("QR Code Type", selection: $selectedType) {
                        Text("Contact").tag(QRType.contact)
                        Text("Mesh Node").tag(QRType.meshNode)
                        Text("Camp Invite").tag(QRType.campInvite)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .onChange(of: selectedType) { _ in
                        generateQRCode()
                    }
                    
                    // QR Code display
                    if let qrImage = qrImage {
                        VStack(spacing: 16) {
                            Image(uiImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 300, height: 300)
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(radius: 4)
                            
                            Text(descriptionForType(selectedType))
                                .font(.subheadline)
                                .foregroundColor(Theme.Colors.robotCream)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    } else {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            
                            Text("Generating QR code...")
                                .foregroundColor(Theme.Colors.robotCream)
                        }
                        .frame(height: 300)
                    }
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: { showingShareSheet = true }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share QR Code")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.Colors.sunsetOrange)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(qrImage == nil)
                        
                        Button(action: saveToPhotos) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("Save to Photos")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.Colors.turquoise)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(qrImage == nil)
                    }
                    .padding(.horizontal)
                    
                    // Info section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How to use:")
                            .font(.headline)
                            .foregroundColor(Theme.Colors.robotCream)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                Text("1.")
                                Text("Select the type of QR code you want to share")
                            }
                            HStack(alignment: .top) {
                                Text("2.")
                                Text("Show the QR code to another Robot Heart user")
                            }
                            HStack(alignment: .top) {
                                Text("3.")
                                Text("They scan it with their app to connect")
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.8))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Theme.Colors.backgroundDark.opacity(0.5))
                    )
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Theme.Colors.backgroundDark)
            .navigationTitle("Share QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Theme.Colors.sunsetOrange)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let qrImage = qrImage {
                    ShareSheet(items: [qrImage, qrString])
                }
            }
        }
        .onAppear {
            generateQRCode()
        }
    }
    
    // MARK: - QR Code Generation
    
    private func generateQRCode() {
        Task {
            let string = await generateQRString(for: selectedType)
            qrString = string
            
            let image = QRCodeScanner.generateQRCode(from: string, size: CGSize(width: 600, height: 600))
            
            await MainActor.run {
                qrImage = image
            }
        }
    }
    
    private func generateQRString(for type: QRType) async -> String {
        switch type {
        case .contact:
            let contact = QRContact(
                id: UserDefaults.standard.string(forKey: "userID") ?? UUID().uuidString,
                name: UserDefaults.standard.string(forKey: "userName") ?? "Anonymous",
                role: UserDefaults.standard.string(forKey: "userRole"),
                meshtasticNodeID: nil, // TODO: Get from MeshtasticManager
                campID: "robot-heart"
            )
            return contact.toQRString() ?? "error"
            
        case .meshNode:
            // TODO: Get actual node info from MeshtasticManager
            let node = QRMeshNode(
                nodeID: 0x12345678,
                nodeName: "RH-\(UserDefaults.standard.string(forKey: "userName") ?? "Node")",
                hardwareModel: "T1000-E",
                firmwareVersion: "2.3.0",
                publicKey: nil
            )
            return node.toQRString() ?? "error"
            
        case .campInvite:
            let invite = QRCampInvite(
                campID: "robot-heart",
                campName: "Robot Heart",
                inviteCode: UUID().uuidString.prefix(8).uppercased(),
                expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: Date())
            )
            return invite.toQRString() ?? "error"
        }
    }
    
    private func descriptionForType(_ type: QRType) -> String {
        switch type {
        case .contact:
            return "Share your contact info with other Robot Heart members"
        case .meshNode:
            return "Allow others to connect to your mesh node"
        case .campInvite:
            return "Invite someone to join the Robot Heart camp"
        }
    }
    
    // MARK: - Actions
    
    private func saveToPhotos() {
        guard let qrImage = qrImage else { return }
        
        UIImageWriteToSavedPhotosAlbum(qrImage, nil, nil, nil)
        
        // TODO: Show success message
        print("💾 [QRGenerator] Saved QR code to Photos")
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Preview

struct QRCodeGeneratorView_Previews: PreviewProvider {
    static var previews: some View {
        QRCodeGeneratorView()
            .environmentObject(AppEnvironment())
    }
}
