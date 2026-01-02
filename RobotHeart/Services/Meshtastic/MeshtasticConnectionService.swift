import Foundation
import CoreBluetooth
import Combine

/// Handles BLE connection to Meshtastic devices.
/// Responsible for scanning, connecting, and managing the BLE peripheral.
///
/// Single Responsibility: BLE connection lifecycle
@MainActor
class MeshtasticConnectionService: NSObject, ObservableObject {
    
    // MARK: - Published State
    
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var connectedDevice: String?
    @Published var lastError: String?
    
    enum ConnectionStatus: Equatable {
        case disconnected
        case bluetoothOff
        case scanning
        case connecting
        case connected
        case ready
        
        var description: String {
            switch self {
            case .disconnected: return "Disconnected"
            case .bluetoothOff: return "Bluetooth Off"
            case .scanning: return "Scanning..."
            case .connecting: return "Connecting..."
            case .connected: return "Connected"
            case .ready: return "Ready"
            }
        }
        
        var isActive: Bool {
            switch self {
            case .connected, .ready: return true
            default: return false
            }
        }
    }
    
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
    
    // MARK: - Callbacks
    
    var onDataReceived: ((Data) -> Void)?
    var onConnectionReady: (() -> Void)?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Public Methods
    
    func startScanning() {
        guard centralManager?.state == .poweredOn else {
            connectionStatus = .bluetoothOff
            return
        }
        
        connectionStatus = .scanning
        discoveredDevices.removeAll()
        
        centralManager?.scanForPeripherals(
            withServices: [meshtasticServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        
        print("📡 [MeshtasticConnection] Started scanning for devices")
    }
    
    func stopScanning() {
        centralManager?.stopScan()
        
        if connectionStatus == .scanning {
            connectionStatus = .disconnected
        }
        
        print("📡 [MeshtasticConnection] Stopped scanning")
    }
    
    func connect(to device: DiscoveredDevice) {
        stopScanning()
        connectionStatus = .connecting
        connectedDevice = device.name
        
        centralManager?.connect(device.peripheral, options: nil)
        
        print("📡 [MeshtasticConnection] Connecting to \(device.name)")
    }
    
    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        
        connectedPeripheral = nil
        fromRadioCharacteristic = nil
        toRadioCharacteristic = nil
        fromNumCharacteristic = nil
        connectedDevice = nil
        connectionStatus = .disconnected
        
        print("📡 [MeshtasticConnection] Disconnected")
    }
    
    func sendData(_ data: Data) -> Bool {
        guard let characteristic = toRadioCharacteristic,
              let peripheral = connectedPeripheral else {
            print("📡 [MeshtasticConnection] Cannot send: not connected")
            return false
        }
        
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        return true
    }
    
    // MARK: - Connection State
    
    var isConnected: Bool {
        connectionStatus.isActive
    }
}

// MARK: - CBCentralManagerDelegate

extension MeshtasticConnectionService: CBCentralManagerDelegate {
    
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                print("📡 [MeshtasticConnection] Bluetooth powered on")
                if connectionStatus == .bluetoothOff {
                    connectionStatus = .disconnected
                }
                
            case .poweredOff:
                connectionStatus = .bluetoothOff
                lastError = "Bluetooth is turned off"
                print("📡 [MeshtasticConnection] Bluetooth powered off")
                
            case .unauthorized:
                connectionStatus = .bluetoothOff
                lastError = "Bluetooth permission denied"
                print("📡 [MeshtasticConnection] Bluetooth unauthorized")
                
            case .unsupported:
                connectionStatus = .bluetoothOff
                lastError = "Bluetooth not supported"
                print("📡 [MeshtasticConnection] Bluetooth unsupported")
                
            default:
                break
            }
        }
    }
    
    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        Task { @MainActor in
            let name = peripheral.name ?? "Unknown Device"
            
            // Update or add device
            if let index = discoveredDevices.firstIndex(where: { $0.id == peripheral.identifier }) {
                discoveredDevices[index].lastSeen = Date()
            } else {
                let device = DiscoveredDevice(
                    id: peripheral.identifier,
                    peripheral: peripheral,
                    name: name,
                    rssi: RSSI.intValue,
                    lastSeen: Date()
                )
                discoveredDevices.append(device)
                print("📡 [MeshtasticConnection] Discovered: \(name) (RSSI: \(RSSI))")
            }
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            connectionStatus = .connected
            connectedPeripheral = peripheral
            peripheral.delegate = self
            
            // Discover services
            peripheral.discoverServices([meshtasticServiceUUID])
            
            print("📡 [MeshtasticConnection] Connected to \(peripheral.name ?? "device")")
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            connectionStatus = .disconnected
            connectedDevice = nil
            lastError = error?.localizedDescription ?? "Failed to connect"
            
            print("📡 [MeshtasticConnection] Failed to connect: \(error?.localizedDescription ?? "unknown")")
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            connectionStatus = .disconnected
            connectedDevice = nil
            connectedPeripheral = nil
            
            if let error = error {
                lastError = error.localizedDescription
                print("📡 [MeshtasticConnection] Disconnected with error: \(error.localizedDescription)")
            } else {
                print("📡 [MeshtasticConnection] Disconnected")
            }
        }
    }
}

// MARK: - CBPeripheralDelegate

extension MeshtasticConnectionService: CBPeripheralDelegate {
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            guard error == nil else {
                lastError = error?.localizedDescription
                return
            }
            
            guard let service = peripheral.services?.first(where: { $0.uuid == meshtasticServiceUUID }) else {
                lastError = "Meshtastic service not found"
                disconnect()
                return
            }
            
            // Discover characteristics
            peripheral.discoverCharacteristics([fromRadioUUID, toRadioUUID, fromNumUUID], for: service)
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task { @MainActor in
            guard error == nil else {
                lastError = error?.localizedDescription
                return
            }
            
            guard let characteristics = service.characteristics else { return }
            
            for characteristic in characteristics {
                switch characteristic.uuid {
                case fromRadioUUID:
                    fromRadioCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                    print("📡 [MeshtasticConnection] Subscribed to fromRadio")
                    
                case toRadioUUID:
                    toRadioCharacteristic = characteristic
                    print("📡 [MeshtasticConnection] Found toRadio")
                    
                case fromNumUUID:
                    fromNumCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                    print("📡 [MeshtasticConnection] Subscribed to fromNum")
                    
                default:
                    break
                }
            }
            
            // Connection is ready
            if fromRadioCharacteristic != nil && toRadioCharacteristic != nil {
                connectionStatus = .ready
                onConnectionReady?()
                print("📡 [MeshtasticConnection] Connection ready")
            }
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            guard error == nil, let data = characteristic.value else { return }
            
            // Forward data to message service
            onDataReceived?(data)
        }
    }
}
