import Foundation
import CoreBluetooth
import Combine

/// Manages connection and communication with Meshtastic devices
class MeshtasticManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isConnected = false
    @Published var connectedDevice: String?
    @Published var campMembers: [CampMember] = []
    @Published var messages: [Message] = []
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    // MARK: - Private Properties
    private var centralManager: CBCentralManager?
    private var connectedPeripheral: CBPeripheral?
    private var cancellables = Set<AnyCancellable>()
    
    enum ConnectionStatus {
        case disconnected
        case scanning
        case connecting
        case connected
        
        var description: String {
            switch self {
            case .disconnected: return "Disconnected"
            case .scanning: return "Scanning..."
            case .connecting: return "Connecting..."
            case .connected: return "Connected"
            }
        }
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupBluetooth()
        
        // Load mock data for prototype
        loadMockData()
    }
    
    // MARK: - Bluetooth Setup
    private func setupBluetooth() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Public Methods
    func startScanning() {
        connectionStatus = .scanning
        // In production: scan for Meshtastic devices
        // centralManager?.scanForPeripherals(withServices: [meshtasticServiceUUID], options: nil)
        
        // For prototype: simulate connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.simulateConnection()
        }
    }
    
    func stopScanning() {
        centralManager?.stopScan()
        connectionStatus = .disconnected
    }
    
    func sendMessage(_ content: String, type: Message.MessageType = .text) {
        let message = Message(
            id: UUID().uuidString,
            from: "!local",
            fromName: "You",
            content: content,
            timestamp: Date(),
            messageType: type,
            deliveryStatus: .queued,
            location: nil
        )
        
        messages.insert(message, at: 0)
        
        // Simulate sending over mesh
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.updateMessageStatus(message.id, status: .sent)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.updateMessageStatus(message.id, status: .delivered)
        }
    }
    
    func sendLocationUpdate(_ location: CampMember.Location) {
        // In production: send location packet via Meshtastic
        print("Sending location: \(location.latitude), \(location.longitude)")
    }
    
    func sendEmergency() {
        sendMessage("Need assistance at my location", type: .emergency)
    }
    
    // MARK: - Private Methods
    private func simulateConnection() {
        connectionStatus = .connecting
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.isConnected = true
            self?.connectedDevice = "Meshtastic-A1B2"
            self?.connectionStatus = .connected
        }
    }
    
    private func loadMockData() {
        campMembers = CampMember.mockMembers
        messages = Message.mockMessages
        
        // Simulate periodic updates
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateMemberStatus()
            }
            .store(in: &cancellables)
    }
    
    private func updateMemberStatus() {
        // Simulate status updates for connected members
        for i in 0..<campMembers.count {
            if campMembers[i].status == .connected {
                campMembers[i].lastSeen = Date()
            }
        }
    }
    
    private func updateMessageStatus(_ id: String, status: Message.DeliveryStatus) {
        if let index = messages.firstIndex(where: { $0.id == id }) {
            var updatedMessage = messages[index]
            messages[index] = Message(
                id: updatedMessage.id,
                from: updatedMessage.from,
                fromName: updatedMessage.fromName,
                content: updatedMessage.content,
                timestamp: updatedMessage.timestamp,
                messageType: updatedMessage.messageType,
                deliveryStatus: status,
                location: updatedMessage.location
            )
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension MeshtasticManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
        case .poweredOff:
            print("Bluetooth is powered off")
            connectionStatus = .disconnected
        case .unauthorized:
            print("Bluetooth is unauthorized")
        case .unsupported:
            print("Bluetooth is unsupported")
        default:
            break
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Handle discovered Meshtastic devices
        print("Discovered peripheral: \(peripheral.name ?? "Unknown")")
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to peripheral: \(peripheral.name ?? "Unknown")")
        connectedPeripheral = peripheral
        isConnected = true
        connectionStatus = .connected
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
        connectionStatus = .disconnected
    }
}
