import Foundation
import CoreBluetooth
import Combine

/// Manages connection and communication with Meshtastic devices
/// Implements the Meshtastic BLE protocol for T1000-E and other devices
class MeshtasticManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isConnected = false
    @Published var connectedDevice: String?
    @Published var connectedDeviceModel: MeshtasticHardwareModel = .unset
    @Published var campMembers: [CampMember] = []
    @Published var messages: [Message] = []
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var myNodeInfo: MeshtasticMyNodeInfo?
    @Published var nodes: [UInt32: MeshtasticNodeInfo] = [:]
    @Published var batteryLevel: Int?
    @Published var lastError: String?
    @Published var isConfigured = false
    
    // MARK: - Connection Status
    enum ConnectionStatus: Equatable {
        case disconnected
        case bluetoothOff
        case scanning
        case connecting
        case connected
        case configuring
        case ready
        
        var description: String {
            switch self {
            case .disconnected: return "Disconnected"
            case .bluetoothOff: return "Bluetooth Off"
            case .scanning: return "Scanning..."
            case .connecting: return "Connecting..."
            case .connected: return "Connected"
            case .configuring: return "Configuring..."
            case .ready: return "Ready"
            }
        }
        
        var isActive: Bool {
            switch self {
            case .connected, .configuring, .ready: return true
            default: return false
            }
        }
    }
    
    // MARK: - Discovered Device
    struct DiscoveredDevice: Identifiable {
        let id: UUID
        let peripheral: CBPeripheral
        let name: String
        let rssi: Int
        var lastSeen: Date
        
        var signalStrength: SignalStrength {
            switch rssi {
            case -50...0: return .excellent
            case -70..<(-50): return .good
            case -85..<(-70): return .fair
            default: return .weak
            }
        }
        
        enum SignalStrength: String {
            case excellent = "Excellent"
            case good = "Good"
            case fair = "Fair"
            case weak = "Weak"
        }
    }
    
    // MARK: - BLE UUIDs
    private let meshtasticServiceUUID = CBUUID(string: MeshtasticBLE.serviceUUID)
    private let fromRadioUUID = CBUUID(string: MeshtasticBLE.Characteristics.fromRadio)
    private let toRadioUUID = CBUUID(string: MeshtasticBLE.Characteristics.toRadio)
    private let fromNumUUID = CBUUID(string: MeshtasticBLE.Characteristics.fromNum)
    
    // MARK: - Private Properties
    private var centralManager: CBCentralManager?
    private var connectedPeripheral: CBPeripheral?
    private var fromRadioCharacteristic: CBCharacteristic?
    private var toRadioCharacteristic: CBCharacteristic?
    private var fromNumCharacteristic: CBCharacteristic?
    private var cancellables = Set<AnyCancellable>()
    private var configRequestId: UInt32 = 0
    private var pendingPackets: [Data] = []
    private var receiveBuffer = Data()
    private let userDefaults = UserDefaults.standard
    private let nodesKey = "meshtastic_nodes"
    private let messagesKey = "meshtastic_messages"
    
    // MARK: - Initialization
    override init() {
        super.init()
        loadPersistedData()
        setupBluetooth()
        
        // Load demo data if no real members exist (for testing without device)
        if campMembers.isEmpty {
            loadDemoMembers()
        }
    }
    
    /// Load demo camp members for testing without a Meshtastic device
    private func loadDemoMembers() {
        campMembers = [
            CampMember(
                id: "demo-1",
                name: "Felipe",
                role: .lead,
                location: nil,
                lastSeen: Date(),
                batteryLevel: 85,
                status: .connected,
                currentShift: nil
            ),
            CampMember(
                id: "demo-2",
                name: "DJ Sparkle",
                role: .bus,
                location: nil,
                lastSeen: Date().addingTimeInterval(-300),
                batteryLevel: 72,
                status: .connected,
                currentShift: nil
            ),
            CampMember(
                id: "demo-3",
                name: "Luna",
                role: .shadyBot,
                location: nil,
                lastSeen: Date().addingTimeInterval(-1800),
                batteryLevel: 45,
                status: .recent,
                currentShift: nil
            ),
            CampMember(
                id: "demo-4",
                name: "Dusty Dave",
                role: .build,
                location: nil,
                lastSeen: Date().addingTimeInterval(-7200),
                batteryLevel: nil,
                status: .offline,
                currentShift: nil
            ),
            CampMember(
                id: "demo-5",
                name: "Playa Princess",
                role: .general,
                location: nil,
                lastSeen: Date().addingTimeInterval(-600),
                batteryLevel: 92,
                status: .connected,
                currentShift: nil
            ),
            CampMember(
                id: "demo-6",
                name: "Ranger Rick",
                role: .perimeter,
                location: nil,
                lastSeen: Date().addingTimeInterval(-120),
                batteryLevel: 68,
                status: .connected,
                currentShift: nil
            )
        ]
        print("[Meshtastic] Loaded \(campMembers.count) demo members for testing")
    }
    
    // MARK: - Bluetooth Setup
    private func setupBluetooth() {
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [
            CBCentralManagerOptionShowPowerAlertKey: true
        ])
    }
    
    // MARK: - Public Methods
    
    /// Start scanning for Meshtastic devices
    func startScanning() {
        guard centralManager?.state == .poweredOn else {
            connectionStatus = .bluetoothOff
            lastError = "Bluetooth is not available"
            return
        }
        
        connectionStatus = .scanning
        discoveredDevices.removeAll()
        lastError = nil
        
        // Scan for Meshtastic service
        centralManager?.scanForPeripherals(
            withServices: [meshtasticServiceUUID],
            options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: false
            ]
        )
        
        // Also scan without filter to catch devices that don't advertise service UUID
        centralManager?.scanForPeripherals(
            withServices: nil,
            options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: false
            ]
        )
        
        print("[Meshtastic] Started scanning for devices...")
    }
    
    /// Stop scanning for devices
    func stopScanning() {
        centralManager?.stopScan()
        if connectionStatus == .scanning {
            connectionStatus = .disconnected
        }
        print("[Meshtastic] Stopped scanning")
    }
    
    /// Connect to a discovered device
    func connect(to device: DiscoveredDevice) {
        stopScanning()
        connectionStatus = .connecting
        connectedDevice = device.name
        lastError = nil
        
        centralManager?.connect(device.peripheral, options: [
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
        ])
        
        print("[Meshtastic] Connecting to \(device.name)...")
    }
    
    /// Disconnect from current device
    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        resetConnection()
    }
    
    /// Send a text message over the mesh
    func sendMessage(_ content: String, type: Message.MessageType = .text) {
        let messageId = UUID().uuidString
        let message = Message(
            id: messageId,
            from: myNodeInfo?.myNodeNum.nodeIdString ?? "!local",
            fromName: "You",
            content: content,
            timestamp: Date(),
            messageType: type,
            deliveryStatus: .queued,
            location: nil
        )
        
        messages.insert(message, at: 0)
        saveMessages()
        
        // Encode and send via BLE
        let packetData = MeshtasticPacketCodec.encodeTextMessage(content)
        sendToRadio(packetData)
        
        // Update status after short delay (actual ACK would come from device)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateMessageStatus(messageId, status: .sent)
        }
    }
    
    /// Send location update over the mesh
    func sendLocationUpdate(_ location: CampMember.Location) {
        let position = MeshtasticPosition(
            latitude: location.latitude,
            longitude: location.longitude,
            altitude: 0
        )
        
        let packetData = MeshtasticPacketCodec.encodePosition(position)
        sendToRadio(packetData)
        
        print("[Meshtastic] Sent position: \(location.latitude), \(location.longitude)")
    }
    
    /// Send emergency alert
    func sendEmergency() {
        sendMessage("🚨 EMERGENCY - Need assistance at my location!", type: .emergency)
    }
    
    /// Request full configuration from device
    func requestConfig() {
        guard connectionStatus == .connected || connectionStatus == .ready else { return }
        
        connectionStatus = .configuring
        configRequestId = UInt32.random(in: 1...UInt32.max)
        
        let configRequest = MeshtasticPacketCodec.encodeWantConfig(configId: configRequestId)
        sendToRadio(configRequest)
        
        print("[Meshtastic] Requested config with ID: \(configRequestId)")
    }
    
    // MARK: - Private Methods
    
    private func sendToRadio(_ data: Data) {
        guard let characteristic = toRadioCharacteristic,
              let peripheral = connectedPeripheral else {
            print("[Meshtastic] Cannot send - not connected")
            pendingPackets.append(data)
            return
        }
        
        // Write with response for reliability
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        print("[Meshtastic] Sent \(data.count) bytes to radio")
    }
    
    private func readFromRadio() {
        guard let characteristic = fromRadioCharacteristic,
              let peripheral = connectedPeripheral else { return }
        
        peripheral.readValue(for: characteristic)
    }
    
    private func processReceivedData(_ data: Data) {
        guard !data.isEmpty else {
            // Empty packet means no more data
            if connectionStatus == .configuring {
                connectionStatus = .ready
                isConfigured = true
                print("[Meshtastic] Configuration complete")
            }
            return
        }
        
        print("[Meshtastic] Received \(data.count) bytes")
        
        // Parse the FromRadio packet
        if let packet = MeshtasticPacketCodec.decodeFromRadio(data) {
            handleFromRadioPacket(packet)
        }
        
        // Continue reading if there might be more
        readFromRadio()
    }
    
    private func handleFromRadioPacket(_ packet: FromRadioPacket) {
        switch packet.payloadType {
        case .myNodeInfo:
            print("[Meshtastic] Received MyNodeInfo")
            // Would parse and store myNodeInfo here
            
        case .nodeInfo:
            print("[Meshtastic] Received NodeInfo")
            // Would parse and add to nodes dictionary
            
        case .meshPacket:
            print("[Meshtastic] Received MeshPacket")
            // Would parse and handle message/position/etc
            
        case .configComplete:
            print("[Meshtastic] Config complete (ID: \(packet.configCompleteId))")
            if packet.configCompleteId == configRequestId {
                connectionStatus = .ready
                isConfigured = true
                updateCampMembersFromNodes()
            }
            
        case .channel:
            print("[Meshtastic] Received Channel config")
            
        case .config:
            print("[Meshtastic] Received Config")
            
        case .rebooted:
            print("[Meshtastic] Device rebooted")
            requestConfig()
            
        default:
            print("[Meshtastic] Received packet type: \(packet.payloadType)")
        }
    }
    
    private func updateCampMembersFromNodes() {
        // Convert Meshtastic nodes to CampMember format
        var members: [CampMember] = []
        
        for (_, nodeInfo) in nodes {
            let status: CampMember.ConnectionStatus = {
                guard let lastSeen = nodeInfo.lastSeenDate else { return .offline }
                let interval = Date().timeIntervalSince(lastSeen)
                if interval < 900 { return .connected }
                if interval < 3600 { return .recent }
                return .offline
            }()
            
            let location: CampMember.Location? = nodeInfo.position.latitudeI != 0 ? CampMember.Location(
                latitude: nodeInfo.position.latitude,
                longitude: nodeInfo.position.longitude,
                timestamp: Date(timeIntervalSince1970: TimeInterval(nodeInfo.position.time)),
                accuracy: nil
            ) : nil
            
            let member = CampMember(
                id: nodeInfo.nodeIdString,
                name: nodeInfo.user.longName.isEmpty ? nodeInfo.nodeIdString : nodeInfo.user.longName,
                role: .general,
                location: location,
                lastSeen: nodeInfo.lastSeenDate ?? Date.distantPast,
                batteryLevel: nodeInfo.deviceMetrics.batteryLevel > 0 ? Int(nodeInfo.deviceMetrics.batteryLevel) : nil,
                status: status,
                currentShift: nil
            )
            members.append(member)
        }
        
        campMembers = members
    }
    
    private func resetConnection() {
        connectedPeripheral = nil
        fromRadioCharacteristic = nil
        toRadioCharacteristic = nil
        fromNumCharacteristic = nil
        isConnected = false
        connectedDevice = nil
        connectionStatus = .disconnected
        isConfigured = false
        receiveBuffer.removeAll()
    }
    
    private func updateMessageStatus(_ id: String, status: Message.DeliveryStatus) {
        if let index = messages.firstIndex(where: { $0.id == id }) {
            let oldMessage = messages[index]
            messages[index] = Message(
                id: oldMessage.id,
                from: oldMessage.from,
                fromName: oldMessage.fromName,
                content: oldMessage.content,
                timestamp: oldMessage.timestamp,
                messageType: oldMessage.messageType,
                deliveryStatus: status,
                location: oldMessage.location
            )
            saveMessages()
        }
    }
    
    // MARK: - Persistence
    
    private func loadPersistedData() {
        // Load saved messages
        if let data = userDefaults.data(forKey: messagesKey),
           let decoded = try? JSONDecoder().decode([Message].self, from: data) {
            messages = decoded
        }
    }
    
    private func saveMessages() {
        if let encoded = try? JSONEncoder().encode(messages) {
            userDefaults.set(encoded, forKey: messagesKey)
        }
    }
    
    // MARK: - Helper to check if device name matches Meshtastic patterns
    private func isMeshtasticDevice(name: String?) -> Bool {
        guard let name = name else { return false }
        return MeshtasticBLE.deviceNamePatterns.contains { name.localizedCaseInsensitiveContains($0) }
    }
}

// MARK: - Node ID String Extension
extension UInt32 {
    var nodeIdString: String {
        String(format: "!%08x", self)
    }
}

// MARK: - CBCentralManagerDelegate
extension MeshtasticManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async { [weak self] in
            switch central.state {
            case .poweredOn:
                print("[Meshtastic] Bluetooth is powered on")
                if self?.connectionStatus == .bluetoothOff {
                    self?.connectionStatus = .disconnected
                }
            case .poweredOff:
                print("[Meshtastic] Bluetooth is powered off")
                self?.connectionStatus = .bluetoothOff
                self?.lastError = "Please turn on Bluetooth"
            case .unauthorized:
                print("[Meshtastic] Bluetooth is unauthorized")
                self?.lastError = "Bluetooth permission required"
            case .unsupported:
                print("[Meshtastic] Bluetooth is unsupported")
                self?.lastError = "Bluetooth not supported on this device"
            case .resetting:
                print("[Meshtastic] Bluetooth is resetting")
            case .unknown:
                print("[Meshtastic] Bluetooth state unknown")
            @unknown default:
                break
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let deviceName = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown"
        
        // Check if this looks like a Meshtastic device
        guard isMeshtasticDevice(name: deviceName) else { return }
        
        print("[Meshtastic] Discovered: \(deviceName) (RSSI: \(RSSI))")
        
        DispatchQueue.main.async { [weak self] in
            // Check if already in list
            if let index = self?.discoveredDevices.firstIndex(where: { $0.peripheral.identifier == peripheral.identifier }) {
                self?.discoveredDevices[index].lastSeen = Date()
            } else {
                let device = DiscoveredDevice(
                    id: peripheral.identifier,
                    peripheral: peripheral,
                    name: deviceName,
                    rssi: RSSI.intValue,
                    lastSeen: Date()
                )
                self?.discoveredDevices.append(device)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("[Meshtastic] Connected to: \(peripheral.name ?? "Unknown")")
        
        DispatchQueue.main.async { [weak self] in
            self?.connectedPeripheral = peripheral
            self?.isConnected = true
            self?.connectionStatus = .connected
            
            // Set up peripheral delegate and discover services
            peripheral.delegate = self
            peripheral.discoverServices([self?.meshtasticServiceUUID].compactMap { $0 })
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("[Meshtastic] Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
        
        DispatchQueue.main.async { [weak self] in
            self?.lastError = error?.localizedDescription ?? "Connection failed"
            self?.resetConnection()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("[Meshtastic] Disconnected from: \(peripheral.name ?? "Unknown")")
        
        DispatchQueue.main.async { [weak self] in
            if let error = error {
                self?.lastError = "Disconnected: \(error.localizedDescription)"
            }
            self?.resetConnection()
        }
    }
}

// MARK: - CBPeripheralDelegate
extension MeshtasticManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("[Meshtastic] Error discovering services: \(error.localizedDescription)")
            lastError = error.localizedDescription
            return
        }
        
        guard let services = peripheral.services else { return }
        
        for service in services {
            print("[Meshtastic] Found service: \(service.uuid)")
            
            if service.uuid == meshtasticServiceUUID {
                // Discover all characteristics for Meshtastic service
                peripheral.discoverCharacteristics([
                    fromRadioUUID,
                    toRadioUUID,
                    fromNumUUID
                ], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("[Meshtastic] Error discovering characteristics: \(error.localizedDescription)")
            lastError = error.localizedDescription
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            print("[Meshtastic] Found characteristic: \(characteristic.uuid)")
            
            switch characteristic.uuid {
            case fromRadioUUID:
                fromRadioCharacteristic = characteristic
                print("[Meshtastic] Found FromRadio characteristic")
                
            case toRadioUUID:
                toRadioCharacteristic = characteristic
                print("[Meshtastic] Found ToRadio characteristic")
                
            case fromNumUUID:
                fromNumCharacteristic = characteristic
                // Subscribe to notifications for new data
                peripheral.setNotifyValue(true, for: characteristic)
                print("[Meshtastic] Found FromNum characteristic - subscribing to notifications")
                
            default:
                break
            }
        }
        
        // Once we have all characteristics, request MTU and start config
        if fromRadioCharacteristic != nil && toRadioCharacteristic != nil {
            // Request maximum MTU for better performance
            peripheral.maximumWriteValueLength(for: .withResponse)
            
            // Send any pending packets
            for packet in pendingPackets {
                sendToRadio(packet)
            }
            pendingPackets.removeAll()
            
            // Request device configuration
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.requestConfig()
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("[Meshtastic] Error reading characteristic: \(error.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value else { return }
        
        switch characteristic.uuid {
        case fromRadioUUID:
            processReceivedData(data)
            
        case fromNumUUID:
            // New data available notification - read from FromRadio
            print("[Meshtastic] FromNum notification - reading FromRadio")
            readFromRadio()
            
        default:
            break
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("[Meshtastic] Error writing to characteristic: \(error.localizedDescription)")
            lastError = error.localizedDescription
        } else {
            print("[Meshtastic] Successfully wrote to \(characteristic.uuid)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("[Meshtastic] Error updating notification state: \(error.localizedDescription)")
            return
        }
        
        if characteristic.isNotifying {
            print("[Meshtastic] Notifications enabled for \(characteristic.uuid)")
        } else {
            print("[Meshtastic] Notifications disabled for \(characteristic.uuid)")
        }
    }
}
