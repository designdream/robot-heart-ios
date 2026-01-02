import Foundation

// MARK: - Meshtastic BLE Protocol Constants
// Based on https://meshtastic.org/docs/development/device/client-api/

struct MeshtasticBLE {
    // Main Meshtastic Service UUID
    static let serviceUUID = "6ba1b218-15a8-461f-9fa8-5dcae273eafd"
    
    // Characteristic UUIDs
    struct Characteristics {
        // FromRadio - Read packets from device (up to 512 bytes)
        static let fromRadio = "2c55e69e-4993-11ed-b878-0242ac120002"
        
        // ToRadio - Write packets to device (up to 512 bytes)
        static let toRadio = "f75c76d2-129e-4dad-a1dd-7866124401e7"
        
        // FromNum - Notifies when new data available in FromRadio
        static let fromNum = "ed9da18c-a800-4f66-a670-aa7547e34453"
        
        // LogRecord - Debug log messages (optional)
        static let logRecord = "5a3d6e49-06e6-4423-9944-e9de8cdf9547"
    }
    
    // Streaming protocol header bytes
    struct StreamHeader {
        static let start1: UInt8 = 0x94
        static let start2: UInt8 = 0xc3
        static let maxPacketSize = 512
    }
    
    // Device name patterns for auto-discovery
    static let deviceNamePatterns = [
        "Meshtastic",
        "T1000",
        "SenseCAP",
        "RAK",
        "TLORA",
        "TBEAM",
        "Heltec"
    ]
}

// MARK: - Meshtastic Packet Types
// Simplified protobuf-like structures (full implementation would use SwiftProtobuf)

enum MeshtasticPortNum: UInt32 {
    case unknown = 0
    case textMessage = 1
    case remoteHardware = 2
    case position = 3
    case nodeInfo = 4
    case routing = 5
    case admin = 6
    case textMessageCompressed = 7
    case waypoint = 8
    case audio = 9
    case detectionSensor = 10
    case reply = 32
    case ipTunnel = 33
    case paxcounter = 34
    case serial = 64
    case storeForward = 65
    case rangeTest = 66
    case telemetry = 67
    case zps = 68
    case simulator = 69
    case traceroute = 70
    case neighborInfo = 71
    case atak = 72
    case mapReport = 73
    case powerStress = 74
    case privateApp = 256
    case atakForwarder = 257
    case max = 511
}

// MARK: - Position Data
struct MeshtasticPosition: Codable {
    var latitudeI: Int32 = 0  // Latitude in 1e-7 degrees
    var longitudeI: Int32 = 0 // Longitude in 1e-7 degrees
    var altitude: Int32 = 0   // Altitude in meters
    var time: UInt32 = 0      // Unix timestamp
    var locationSource: UInt32 = 0
    var altitudeSource: UInt32 = 0
    var timestamp: UInt32 = 0
    var timestampMillisAdjust: Int32 = 0
    var altitudeHae: Int32 = 0
    var altitudeGeoidalSeparation: Int32 = 0
    var pdop: UInt32 = 0
    var hdop: UInt32 = 0
    var vdop: UInt32 = 0
    var gpsAccuracy: UInt32 = 0
    var groundSpeed: UInt32 = 0
    var groundTrack: UInt32 = 0
    var fixQuality: UInt32 = 0
    var fixType: UInt32 = 0
    var satsInView: UInt32 = 0
    var sensorId: UInt32 = 0
    var nextUpdate: UInt32 = 0
    var seqNumber: UInt32 = 0
    var precisionBits: UInt32 = 0
    
    var latitude: Double {
        Double(latitudeI) / 1e7
    }
    
    var longitude: Double {
        Double(longitudeI) / 1e7
    }
    
    init() {}
    
    init(latitude: Double, longitude: Double, altitude: Int32 = 0) {
        self.latitudeI = Int32(latitude * 1e7)
        self.longitudeI = Int32(longitude * 1e7)
        self.altitude = altitude
        self.time = UInt32(Date().timeIntervalSince1970)
    }
}

// MARK: - User Info
struct MeshtasticUser: Codable {
    var id: String = ""
    var longName: String = ""
    var shortName: String = ""
    var macaddr: Data = Data()
    var hwModel: UInt32 = 0
    var isLicensed: Bool = false
    var role: UInt32 = 0
    var publicKey: Data = Data()
    
    init() {}
    
    init(id: String, longName: String, shortName: String) {
        self.id = id
        self.longName = longName
        self.shortName = shortName
    }
}

// MARK: - Node Info
struct MeshtasticNodeInfo: Codable, Identifiable {
    var num: UInt32 = 0
    var user: MeshtasticUser = MeshtasticUser()
    var position: MeshtasticPosition = MeshtasticPosition()
    var snr: Float = 0
    var lastHeard: UInt32 = 0
    var deviceMetrics: MeshtasticDeviceMetrics = MeshtasticDeviceMetrics()
    var channel: UInt32 = 0
    var viaMqtt: Bool = false
    var hopsAway: UInt32 = 0
    var isFavorite: Bool = false
    
    var id: UInt32 { num }
    
    var nodeIdString: String {
        String(format: "!%08x", num)
    }
    
    var lastSeenDate: Date? {
        guard lastHeard > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(lastHeard))
    }
}

// MARK: - Device Metrics
struct MeshtasticDeviceMetrics: Codable {
    var batteryLevel: UInt32 = 0
    var voltage: Float = 0
    var channelUtilization: Float = 0
    var airUtilTx: Float = 0
    var uptimeSeconds: UInt32 = 0
}

// MARK: - My Node Info
struct MeshtasticMyNodeInfo: Codable {
    var myNodeNum: UInt32 = 0
    var rebootCount: UInt32 = 0
    var minAppVersion: UInt32 = 0
    var messageTimeoutMsec: UInt32 = 0
    var firmwareVersion: String = ""
    var errorCode: UInt32 = 0
    var errorAddress: UInt32 = 0
    var errorCount: UInt32 = 0
    var packetIdBits: UInt32 = 0
    var currentPacketId: UInt32 = 0
    var nodeNumBits: UInt32 = 0
    var maxChannels: UInt32 = 0
    var hasWifi: Bool = false
    var hasBluetooth: Bool = false
    var hasEthernet: Bool = false
    var positionFlags: UInt32 = 0
    var hwModel: UInt32 = 0
    var hasRemoteHardware: Bool = false
}

// MARK: - Mesh Packet
struct MeshtasticMeshPacket: Identifiable {
    var from: UInt32 = 0
    var to: UInt32 = 0
    var channel: UInt32 = 0
    var id: UInt32 = 0
    var rxTime: UInt32 = 0
    var rxSnr: Float = 0
    var hopLimit: UInt32 = 3
    var wantAck: Bool = false
    var priority: UInt32 = 0
    var rxRssi: Int32 = 0
    var delayed: UInt32 = 0
    var viaMqtt: Bool = false
    var hopStart: UInt32 = 0
    var publicKey: Data = Data()
    var pkiEncrypted: Bool = false
    
    // Payload
    var portNum: MeshtasticPortNum = .unknown
    var payload: Data = Data()
    
    var fromNodeIdString: String {
        String(format: "!%08x", from)
    }
    
    var toNodeIdString: String {
        if to == 0xFFFFFFFF {
            return "^all"
        }
        return String(format: "!%08x", to)
    }
    
    var receivedDate: Date? {
        guard rxTime > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(rxTime))
    }
}

// MARK: - Channel Settings
struct MeshtasticChannel: Codable, Identifiable {
    var index: UInt32 = 0
    var role: UInt32 = 0 // 0=disabled, 1=primary, 2=secondary
    var name: String = ""
    var psk: Data = Data() // Pre-shared key
    var uplinkEnabled: Bool = false
    var downlinkEnabled: Bool = false
    
    var id: UInt32 { index }
    
    var isEnabled: Bool {
        role > 0
    }
}

// MARK: - Config Request/Response
struct MeshtasticConfigRequest {
    var wantConfigId: UInt32 = 0
}

// MARK: - Simple Packet Encoder/Decoder
// Note: For production, use SwiftProtobuf library for proper protobuf encoding
class MeshtasticPacketCodec {
    
    // MARK: - Encode Text Message
    static func encodeTextMessage(_ text: String, to: UInt32 = 0xFFFFFFFF, channel: UInt32 = 0) -> Data {
        var data = Data()
        
        // Header
        data.append(MeshtasticBLE.StreamHeader.start1)
        data.append(MeshtasticBLE.StreamHeader.start2)
        
        // Build the packet payload
        var payload = Data()
        
        // Port number (text message = 1)
        payload.append(contentsOf: encodeVarint(UInt64(MeshtasticPortNum.textMessage.rawValue)))
        
        // Text content
        let textData = text.data(using: .utf8) ?? Data()
        payload.append(contentsOf: textData)
        
        // Length (2 bytes, big endian)
        let length = UInt16(payload.count)
        data.append(UInt8((length >> 8) & 0xFF))
        data.append(UInt8(length & 0xFF))
        
        // Payload
        data.append(payload)
        
        return data
    }
    
    // MARK: - Encode Position
    static func encodePosition(_ position: MeshtasticPosition) -> Data {
        var data = Data()
        
        // Header
        data.append(MeshtasticBLE.StreamHeader.start1)
        data.append(MeshtasticBLE.StreamHeader.start2)
        
        // Build position payload
        var payload = Data()
        
        // Port number (position = 3)
        payload.append(contentsOf: encodeVarint(UInt64(MeshtasticPortNum.position.rawValue)))
        
        // Latitude (field 1, wire type 0 = varint, but we use fixed for precision)
        payload.append(0x08) // field 1, wire type 0
        payload.append(contentsOf: encodeSignedVarint(Int64(position.latitudeI)))
        
        // Longitude (field 2)
        payload.append(0x10) // field 2, wire type 0
        payload.append(contentsOf: encodeSignedVarint(Int64(position.longitudeI)))
        
        // Altitude (field 3)
        if position.altitude != 0 {
            payload.append(0x18) // field 3, wire type 0
            payload.append(contentsOf: encodeSignedVarint(Int64(position.altitude)))
        }
        
        // Time (field 4)
        if position.time != 0 {
            payload.append(0x20) // field 4, wire type 0
            payload.append(contentsOf: encodeVarint(UInt64(position.time)))
        }
        
        // Length
        let length = UInt16(payload.count)
        data.append(UInt8((length >> 8) & 0xFF))
        data.append(UInt8(length & 0xFF))
        
        // Payload
        data.append(payload)
        
        return data
    }
    
    // MARK: - Encode Want Config (Initial handshake)
    static func encodeWantConfig(configId: UInt32 = UInt32.random(in: 1...UInt32.max)) -> Data {
        var data = Data()
        
        // Header
        data.append(MeshtasticBLE.StreamHeader.start1)
        data.append(MeshtasticBLE.StreamHeader.start2)
        
        // ToRadio with want_config_id
        var payload = Data()
        
        // Field 3 (want_config_id), wire type 0 (varint)
        payload.append(0x18) // (3 << 3) | 0
        payload.append(contentsOf: encodeVarint(UInt64(configId)))
        
        // Length
        let length = UInt16(payload.count)
        data.append(UInt8((length >> 8) & 0xFF))
        data.append(UInt8(length & 0xFF))
        
        // Payload
        data.append(payload)
        
        return data
    }
    
    // MARK: - Decode FromRadio Packet
    static func decodeFromRadio(_ data: Data) -> FromRadioPacket? {
        guard data.count >= 4 else { return nil }
        
        var offset = 0
        
        // Check for streaming header
        if data[0] == MeshtasticBLE.StreamHeader.start1 && 
           data[1] == MeshtasticBLE.StreamHeader.start2 {
            // Read length
            let length = (UInt16(data[2]) << 8) | UInt16(data[3])
            offset = 4
            
            guard data.count >= offset + Int(length) else { return nil }
        }
        
        // Parse the protobuf payload
        return parseFromRadioPayload(Data(data[offset...]))
    }
    
    // MARK: - Parse FromRadio Payload
    private static func parseFromRadioPayload(_ data: Data) -> FromRadioPacket? {
        guard !data.isEmpty else { return nil }
        
        var packet = FromRadioPacket()
        var offset = 0
        
        while offset < data.count {
            guard let (fieldNumber, wireType, newOffset) = decodeTag(data, offset: offset) else { break }
            offset = newOffset
            
            switch fieldNumber {
            case 1: // id
                if let (value, newOffset) = decodeVarint(data, offset: offset) {
                    packet.id = UInt32(value)
                    offset = newOffset
                }
            case 2: // packet (MeshPacket)
                packet.payloadType = .meshPacket
                // Would need full protobuf parsing here
            case 3: // my_info
                packet.payloadType = .myNodeInfo
            case 4: // node_info
                packet.payloadType = .nodeInfo
            case 5: // config
                packet.payloadType = .config
            case 6: // log_record
                packet.payloadType = .logRecord
            case 7: // config_complete_id
                if let (value, newOffset) = decodeVarint(data, offset: offset) {
                    packet.configCompleteId = UInt32(value)
                    packet.payloadType = .configComplete
                    offset = newOffset
                }
            case 8: // rebooted
                packet.payloadType = .rebooted
            case 9: // moduleConfig
                packet.payloadType = .moduleConfig
            case 10: // channel
                packet.payloadType = .channel
            case 11: // queueStatus
                packet.payloadType = .queueStatus
            case 12: // xmodemPacket
                packet.payloadType = .xmodemPacket
            case 13: // metadata
                packet.payloadType = .metadata
            case 14: // mqttClientProxyMessage
                packet.payloadType = .mqttClientProxyMessage
            case 15: // fileInfo
                packet.payloadType = .fileInfo
            case 16: // clientNotification
                packet.payloadType = .clientNotification
            default:
                // Skip unknown field
                break
            }
            
            // Skip the field value if we haven't consumed it
            if wireType == 2 { // Length-delimited
                if let (length, newOffset) = decodeVarint(data, offset: offset) {
                    offset = newOffset + Int(length)
                }
            }
        }
        
        packet.rawData = data
        return packet
    }
    
    // MARK: - Varint Encoding
    private static func encodeVarint(_ value: UInt64) -> [UInt8] {
        var result: [UInt8] = []
        var v = value
        while v > 127 {
            result.append(UInt8((v & 0x7F) | 0x80))
            v >>= 7
        }
        result.append(UInt8(v))
        return result
    }
    
    private static func encodeSignedVarint(_ value: Int64) -> [UInt8] {
        // ZigZag encoding for signed integers
        let zigzag = (value << 1) ^ (value >> 63)
        return encodeVarint(UInt64(bitPattern: zigzag))
    }
    
    // MARK: - Varint Decoding
    private static func decodeVarint(_ data: Data, offset: Int) -> (UInt64, Int)? {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        var currentOffset = offset
        
        while currentOffset < data.count {
            let byte = data[currentOffset]
            result |= UInt64(byte & 0x7F) << shift
            currentOffset += 1
            
            if byte & 0x80 == 0 {
                return (result, currentOffset)
            }
            
            shift += 7
            if shift > 63 {
                return nil // Overflow
            }
        }
        
        return nil
    }
    
    private static func decodeTag(_ data: Data, offset: Int) -> (fieldNumber: Int, wireType: Int, newOffset: Int)? {
        guard let (tag, newOffset) = decodeVarint(data, offset: offset) else { return nil }
        let fieldNumber = Int(tag >> 3)
        let wireType = Int(tag & 0x07)
        return (fieldNumber, wireType, newOffset)
    }
}

// MARK: - FromRadio Packet Wrapper
struct FromRadioPacket {
    var id: UInt32 = 0
    var payloadType: PayloadType = .unknown
    var configCompleteId: UInt32 = 0
    var rawData: Data = Data()
    
    enum PayloadType {
        case unknown
        case meshPacket
        case myNodeInfo
        case nodeInfo
        case config
        case logRecord
        case configComplete
        case rebooted
        case moduleConfig
        case channel
        case queueStatus
        case xmodemPacket
        case metadata
        case mqttClientProxyMessage
        case fileInfo
        case clientNotification
    }
}

// MARK: - Hardware Model Enum
enum MeshtasticHardwareModel: UInt32 {
    case unset = 0
    case tloraV2 = 1
    case tloraV1 = 2
    case tloraV211P6 = 3
    case tbeam = 4
    case heltecV20 = 5
    case tbeamV0P7 = 6
    case tEcho = 7
    case tloraV11P3 = 8
    case rak4631 = 9
    case heltecV21 = 10
    case heltecV1 = 11
    case lilygoTbeamS3Core = 12
    case rak11200 = 13
    case nanoG1 = 14
    case tloraV211P8 = 15
    case tloraT3S3 = 16
    case nanoG1Explorer = 17
    case nanoG2Ultra = 18
    case loraType = 19
    case wiphone = 20
    case wio_wm1110 = 21
    case rak2560 = 22
    case heltecHruV1 = 23
    case stationG1 = 25
    case rakWisMeshPocket = 26
    case wioTracker1110 = 27
    case radioMasterBanditNano = 28
    case heltecWirelessPaperV10 = 29
    case heltecWirelessTrackerV10 = 30
    case heltecWirelessTrackerV11 = 31
    case unPhone = 32
    case tdDeck = 33
    case tWatchS3 = 34
    case picoMesh = 35
    case heltecWirelessPaper = 37
    case heltecWirelessTracker = 38
    case heltecMeshNode = 39
    case betaFpvElrs900Tx = 40
    case betaFpvElrs900Nano = 41
    case diyV1 = 42
    case nrf52840Dk = 43
    case ppr = 44
    case genieBlocks = 45
    case nrf52Unknown = 46
    case portduino = 47
    case androidSim = 48
    case diyV1Sim = 49
    case nrf52840Pca10059 = 50
    case drDev = 51
    case m5Stack = 52
    case heltecV3 = 53
    case heltecWslV3 = 54
    case betaFpvElrs2400Tx = 55
    case betaFpvElrs2400Nano = 56
    case rp2040Lora = 57
    case stationG2 = 58
    case loraRelayV1 = 59
    case nrf52840Promicro = 60
    case radioMasterBandit = 61
    case heltecCapsuleSensorV3 = 62
    case heltecVisionMasterT190 = 63
    case heltecVisionMasterE213 = 64
    case heltecVisionMasterE290 = 65
    case heltecMeshNodeT114 = 66
    case sensecapIndicator = 67
    case trackerT1000E = 68  // SenseCAP T1000-E
    case rakWisMeshTag = 69
    case privateHw = 255
    
    var displayName: String {
        switch self {
        case .trackerT1000E: return "SenseCAP T1000-E"
        case .rakWisMeshTag: return "RAK WisMesh Tag"
        case .rak4631: return "RAK4631"
        case .tbeam: return "T-Beam"
        case .heltecV3: return "Heltec V3"
        default: return "Meshtastic Device"
        }
    }
}
