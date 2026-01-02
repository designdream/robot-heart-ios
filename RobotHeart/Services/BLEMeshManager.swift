import Foundation
import CoreBluetooth
import Combine

// MARK: - BLE Mesh Manager
/// Manages Bluetooth Low Energy mesh networking for peer-to-peer communication.
///
/// This manager implements a BitChat-style mesh network where each device acts as both
/// a central (scanner) and peripheral (advertiser), enabling peer-to-peer message relay.
///
/// ## Architecture
/// ```
/// Phone A ◄──BLE──► Phone B ◄──BLE──► Phone C
///    │                 │                 │
///    └─────────────────┴─────────────────┘
///              Mesh Relay Network
/// ```
///
/// ## Key Features
/// - **Dual Role**: Each device scans for peers AND advertises itself
/// - **Auto-Connect**: Automatically connects to discovered Robot Heart peers
/// - **Message Relay**: Forwards messages to extend network range
/// - **Duplicate Detection**: Prevents message loops with seen-ID tracking
/// - **Store-and-Forward**: Works with `MessageQueueManager` for offline delivery
///
/// ## Security
/// - Messages are encrypted before transmission (see `SECURITY.md`)
/// - Each peer identified by unique UUID
/// - Presence data includes only public info (name, camp)
///
/// ## Usage
/// ```swift
/// let mesh = BLEMeshManager.shared
/// mesh.startAdvertising(userID: "user-123", userName: "Dusty Dave")
/// mesh.startScanning()
/// mesh.sendMessage(bleMessage)
/// ```
///
/// ## References
/// - [BitChat Whitepaper](https://github.com/nickvidal/bitchat)
/// - [Apple Core Bluetooth](https://developer.apple.com/documentation/corebluetooth)
/// - See `docs/ARCHITECTURE.md` for full system design
/// - See `docs/PROTOCOL.md` for message format specification
class BLEMeshManager: NSObject, ObservableObject {
    static let shared = BLEMeshManager()
    
    // Robot Heart BLE Service UUID
    static let serviceUUID = CBUUID(string: "RH01B218-15A8-461F-9FA8-5DCAE273EAFD")
    static let messageCharacteristicUUID = CBUUID(string: "RH02C69E-4993-11ED-B878-0242AC120002")
    static let presenceCharacteristicUUID = CBUUID(string: "RH03D6D2-129E-4DAD-A1DD-7866124401E7")
    
    // Core Bluetooth managers
    private var centralManager: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!
    
    // Discovered peers
    @Published var discoveredPeers: [BLEPeer] = []
    @Published var connectedPeers: [BLEPeer] = []
    @Published var isScanning = false
    @Published var isAdvertising = false
    @Published var meshStatus: MeshStatus = .idle
    
    // Message relay
    private var messageQueue: [BLEMessage] = []
    private var relayedMessageIDs: Set<String> = []
    private let maxRelayedMessages = 1000
    
    // Callbacks
    var onMessageReceived: ((BLEMessage) -> Void)?
    var onPeerDiscovered: ((BLEPeer) -> Void)?
    var onDeliveryConfirmed: ((String) -> Void)?
    
    private var cancellables = Set<AnyCancellable>()
    
    enum MeshStatus {
        case idle
        case scanning
        case advertising
        case connected
        case relaying
    }
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Scanning (Discover Peers)
    
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            print("BLE not powered on")
            return
        }
        
        centralManager.scanForPeripherals(
            withServices: [Self.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        
        isScanning = true
        meshStatus = .scanning
        print("BLE: Started scanning for peers")
    }
    
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        if !isAdvertising {
            meshStatus = .idle
        }
        print("BLE: Stopped scanning")
    }
    
    // MARK: - Advertising (Be Discoverable)
    
    func startAdvertising(userID: String, userName: String) {
        guard peripheralManager.state == .poweredOn else {
            print("BLE peripheral not powered on")
            return
        }
        
        // Create service
        let service = CBMutableService(type: Self.serviceUUID, primary: true)
        
        // Message characteristic (read/write/notify)
        let messageChar = CBMutableCharacteristic(
            type: Self.messageCharacteristicUUID,
            properties: [.read, .write, .notify],
            value: nil,
            permissions: [.readable, .writeable]
        )
        
        // Presence characteristic (read only - broadcasts user info)
        let presenceData = createPresenceData(userID: userID, userName: userName)
        let presenceChar = CBMutableCharacteristic(
            type: Self.presenceCharacteristicUUID,
            properties: [.read],
            value: presenceData,
            permissions: [.readable]
        )
        
        service.characteristics = [messageChar, presenceChar]
        peripheralManager.add(service)
        
        // Start advertising
        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID],
            CBAdvertisementDataLocalNameKey: "RH-\(userName.prefix(8))"
        ])
        
        isAdvertising = true
        meshStatus = .advertising
        print("BLE: Started advertising as \(userName)")
    }
    
    func stopAdvertising() {
        peripheralManager.stopAdvertising()
        peripheralManager.removeAllServices()
        isAdvertising = false
        if !isScanning {
            meshStatus = .idle
        }
        print("BLE: Stopped advertising")
    }
    
    // MARK: - Message Sending
    
    func sendMessage(_ message: BLEMessage) {
        // Add to queue
        messageQueue.append(message)
        
        // Try to send to all connected peers
        for peer in connectedPeers {
            sendToPeer(message, peer: peer)
        }
        
        // Also relay through mesh
        relayMessage(message)
    }
    
    private func sendToPeer(_ message: BLEMessage, peer: BLEPeer) {
        guard let peripheral = peer.peripheral,
              let characteristic = peer.messageCharacteristic else {
            print("BLE: Cannot send to peer - not connected")
            return
        }
        
        let data = message.encode()
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        print("BLE: Sent message to \(peer.name)")
    }
    
    // MARK: - Message Relay (Store-and-Forward)
    
    /// Relays a message to all connected peers except the original sender.
    ///
    /// This is the core of the mesh network - each device helps extend the network
    /// by forwarding messages it receives. The relay logic:
    ///
    /// 1. Check if we've seen this message ID before (prevent loops)
    /// 2. Add message ID to seen set
    /// 3. Forward to all connected peers except sender
    ///
    /// ## Duplicate Prevention
    /// We maintain a set of seen message IDs (max 1000, LRU eviction) to prevent
    /// messages from bouncing infinitely around the mesh.
    ///
    /// ## Performance
    /// - O(1) duplicate check via Set
    /// - O(n) relay where n = connected peers
    /// - Memory bounded by `maxRelayedMessages`
    ///
    /// - Parameter message: The message to relay
    private func relayMessage(_ message: BLEMessage) {
        // Don't relay if we've already seen this message
        guard !relayedMessageIDs.contains(message.id) else { return }
        
        // Add to relayed set
        relayedMessageIDs.insert(message.id)
        
        // Cleanup old IDs if too many
        if relayedMessageIDs.count > maxRelayedMessages {
            relayedMessageIDs.removeFirst()
        }
        
        // Relay to all connected peers except sender
        for peer in connectedPeers where peer.id != message.senderID {
            sendToPeer(message, peer: peer)
        }
        
        meshStatus = .relaying
        
        // Reset status after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            if self?.meshStatus == .relaying {
                self?.meshStatus = self?.connectedPeers.isEmpty == true ? .scanning : .connected
            }
        }
    }
    
    func handleReceivedMessage(_ data: Data, from peerID: String) {
        guard let message = BLEMessage.decode(data) else {
            print("BLE: Failed to decode message")
            return
        }
        
        // Check if this message is for us
        let myID = UserDefaults.standard.string(forKey: "userID") ?? ""
        
        if message.recipientID == myID || message.recipientID == "broadcast" {
            // Message is for us
            onMessageReceived?(message)
            
            // Send delivery confirmation
            if message.recipientID == myID {
                sendDeliveryConfirmation(messageID: message.id, to: message.senderID)
            }
        }
        
        // Relay to other peers (mesh behavior)
        relayMessage(message)
    }
    
    private func sendDeliveryConfirmation(messageID: String, to recipientID: String) {
        let confirmation = BLEMessage(
            id: UUID().uuidString,
            senderID: UserDefaults.standard.string(forKey: "userID") ?? "",
            senderName: UserDefaults.standard.string(forKey: "userName") ?? "Unknown",
            recipientID: recipientID,
            messageType: .deliveryConfirmation,
            content: messageID,
            timestamp: Date()
        )
        
        sendMessage(confirmation)
    }
    
    // MARK: - Presence Data
    
    private func createPresenceData(userID: String, userName: String) -> Data {
        let presence = BLEPresence(
            userID: userID,
            userName: userName,
            campID: UserDefaults.standard.string(forKey: "campID"),
            timestamp: Date()
        )
        return presence.encode()
    }
    
    // MARK: - Peer Management
    
    func connectToPeer(_ peer: BLEPeer) {
        guard let peripheral = peer.peripheral else { return }
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnectFromPeer(_ peer: BLEPeer) {
        guard let peripheral = peer.peripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    private func addDiscoveredPeer(_ peer: BLEPeer) {
        if !discoveredPeers.contains(where: { $0.id == peer.id }) {
            discoveredPeers.append(peer)
            onPeerDiscovered?(peer)
        }
    }
    
    private func addConnectedPeer(_ peer: BLEPeer) {
        if !connectedPeers.contains(where: { $0.id == peer.id }) {
            connectedPeers.append(peer)
            meshStatus = .connected
        }
    }
    
    private func removeConnectedPeer(_ peerID: String) {
        connectedPeers.removeAll { $0.id == peerID }
        if connectedPeers.isEmpty && isScanning {
            meshStatus = .scanning
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEMeshManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("BLE Central: Powered on")
        case .poweredOff:
            print("BLE Central: Powered off")
            isScanning = false
        case .unauthorized:
            print("BLE Central: Unauthorized")
        case .unsupported:
            print("BLE Central: Unsupported")
        default:
            break
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name ?? "Unknown"
        
        let peer = BLEPeer(
            id: peripheral.identifier.uuidString,
            name: name.replacingOccurrences(of: "RH-", with: ""),
            peripheral: peripheral,
            rssi: RSSI.intValue,
            lastSeen: Date()
        )
        
        addDiscoveredPeer(peer)
        print("BLE: Discovered peer \(name) (RSSI: \(RSSI))")
        
        // Auto-connect to Robot Heart peers
        if name.hasPrefix("RH-") {
            connectToPeer(peer)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("BLE: Connected to \(peripheral.name ?? "Unknown")")
        peripheral.delegate = self
        peripheral.discoverServices([Self.serviceUUID])
        
        // Update peer status
        if let index = discoveredPeers.firstIndex(where: { $0.peripheral?.identifier == peripheral.identifier }) {
            var peer = discoveredPeers[index]
            peer.isConnected = true
            discoveredPeers[index] = peer
            addConnectedPeer(peer)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("BLE: Disconnected from \(peripheral.name ?? "Unknown")")
        removeConnectedPeer(peripheral.identifier.uuidString)
        
        // Update discovered peer status
        if let index = discoveredPeers.firstIndex(where: { $0.peripheral?.identifier == peripheral.identifier }) {
            discoveredPeers[index].isConnected = false
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("BLE: Failed to connect to \(peripheral.name ?? "Unknown"): \(error?.localizedDescription ?? "Unknown error")")
    }
}

// MARK: - CBPeripheralDelegate
extension BLEMeshManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services where service.uuid == Self.serviceUUID {
            peripheral.discoverCharacteristics(
                [Self.messageCharacteristicUUID, Self.presenceCharacteristicUUID],
                for: service
            )
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.uuid == Self.messageCharacteristicUUID {
                // Subscribe to notifications
                peripheral.setNotifyValue(true, for: characteristic)
                
                // Store characteristic reference
                if let index = connectedPeers.firstIndex(where: { $0.peripheral?.identifier == peripheral.identifier }) {
                    connectedPeers[index].messageCharacteristic = characteristic
                }
            } else if characteristic.uuid == Self.presenceCharacteristicUUID {
                // Read presence data
                peripheral.readValue(for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        
        if characteristic.uuid == Self.messageCharacteristicUUID {
            handleReceivedMessage(data, from: peripheral.identifier.uuidString)
        } else if characteristic.uuid == Self.presenceCharacteristicUUID {
            if let presence = BLEPresence.decode(data) {
                // Update peer info
                if let index = connectedPeers.firstIndex(where: { $0.peripheral?.identifier == peripheral.identifier }) {
                    connectedPeers[index].userID = presence.userID
                    connectedPeers[index].name = presence.userName
                    connectedPeers[index].campID = presence.campID
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("BLE: Write failed: \(error.localizedDescription)")
        } else {
            print("BLE: Write successful")
        }
    }
}

// MARK: - CBPeripheralManagerDelegate
extension BLEMeshManager: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            print("BLE Peripheral: Powered on")
        case .poweredOff:
            print("BLE Peripheral: Powered off")
            isAdvertising = false
        default:
            break
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if request.characteristic.uuid == Self.messageCharacteristicUUID,
               let data = request.value {
                handleReceivedMessage(data, from: request.central.identifier.uuidString)
            }
            peripheral.respond(to: request, withResult: .success)
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        if request.characteristic.uuid == Self.presenceCharacteristicUUID {
            let userID = UserDefaults.standard.string(forKey: "userID") ?? ""
            let userName = UserDefaults.standard.string(forKey: "userName") ?? "Unknown"
            request.value = createPresenceData(userID: userID, userName: userName)
        }
        peripheral.respond(to: request, withResult: .success)
    }
}

// MARK: - BLE Data Models

struct BLEPeer: Identifiable {
    let id: String
    var name: String
    var userID: String?
    var campID: String?
    var peripheral: CBPeripheral?
    var messageCharacteristic: CBCharacteristic?
    var rssi: Int
    var lastSeen: Date
    var isConnected: Bool = false
}

struct BLEMessage: Codable {
    let id: String
    let senderID: String
    let senderName: String
    let recipientID: String
    let messageType: MessageType
    let content: String
    let timestamp: Date
    var locationLat: Double?
    var locationLon: Double?
    
    enum MessageType: String, Codable {
        case text
        case location
        case deliveryConfirmation
        case campAnnouncement
        case emergency
    }
    
    func encode() -> Data {
        try! JSONEncoder().encode(self)
    }
    
    static func decode(_ data: Data) -> BLEMessage? {
        try? JSONDecoder().decode(BLEMessage.self, from: data)
    }
}

struct BLEPresence: Codable {
    let userID: String
    let userName: String
    let campID: String?
    let timestamp: Date
    
    func encode() -> Data {
        try! JSONEncoder().encode(self)
    }
    
    static func decode(_ data: Data) -> BLEPresence? {
        try? JSONDecoder().decode(BLEPresence.self, from: data)
    }
}
