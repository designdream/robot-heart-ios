import Foundation
import CoreLocation

/// Service responsible for encoding and decoding Meshtastic protocol buffers.
/// This is a stateless service that handles all protocol-level operations.
class MeshtasticProtocolService {
    
    // MARK: - Singleton
    
    static let shared = MeshtasticProtocolService()
    
    private init() {}
    
    // MARK: - Message Encoding
    
    /// Encode a text message for transmission over Meshtastic
    func encodeTextMessage(_ text: String, to nodeID: UInt32?, wantAck: Bool = false) throws -> Data {
        // Create a simple packet structure
        // In a full implementation, this would use SwiftProtobuf
        
        var packet = Data()
        
        // Add packet header
        packet.append(MeshtasticBLE.StreamHeader.start1)
        packet.append(MeshtasticBLE.StreamHeader.start2)
        
        // Add destination node ID (0 = broadcast)
        let destination = nodeID ?? 0
        packet.append(contentsOf: withUnsafeBytes(of: destination.littleEndian) { Data($0) })
        
        // Add port number (text message)
        let portNum = MeshtasticPortNum.textMessage.rawValue
        packet.append(contentsOf: withUnsafeBytes(of: portNum.littleEndian) { Data($0) })
        
        // Add want_ack flag
        packet.append(wantAck ? 1 : 0)
        
        // Add message payload
        guard let messageData = text.data(using: .utf8) else {
            throw MeshtasticProtocolError.encodingFailed("Failed to encode text as UTF-8")
        }
        
        // Add payload length
        let payloadLength = UInt16(messageData.count)
        packet.append(contentsOf: withUnsafeBytes(of: payloadLength.littleEndian) { Data($0) })
        
        // Add payload
        packet.append(messageData)
        
        return packet
    }
    
    /// Encode a position update for transmission
    func encodePosition(_ location: CLLocation) throws -> Data {
        var packet = Data()
        
        // Add packet header
        packet.append(MeshtasticBLE.StreamHeader.start1)
        packet.append(MeshtasticBLE.StreamHeader.start2)
        
        // Destination: broadcast (0)
        packet.append(contentsOf: withUnsafeBytes(of: UInt32(0).littleEndian) { Data($0) })
        
        // Port number: position
        let portNum = MeshtasticPortNum.position.rawValue
        packet.append(contentsOf: withUnsafeBytes(of: portNum.littleEndian) { Data($0) })
        
        // Want ack: false for position updates
        packet.append(0)
        
        // Encode position data
        let latitudeI = Int32(location.coordinate.latitude * 1e7)
        let longitudeI = Int32(location.coordinate.longitude * 1e7)
        let altitude = Int32(location.altitude)
        let time = UInt32(location.timestamp.timeIntervalSince1970)
        
        var positionData = Data()
        positionData.append(contentsOf: withUnsafeBytes(of: latitudeI.littleEndian) { Data($0) })
        positionData.append(contentsOf: withUnsafeBytes(of: longitudeI.littleEndian) { Data($0) })
        positionData.append(contentsOf: withUnsafeBytes(of: altitude.littleEndian) { Data($0) })
        positionData.append(contentsOf: withUnsafeBytes(of: time.littleEndian) { Data($0) })
        
        // Add payload length
        let payloadLength = UInt16(positionData.count)
        packet.append(contentsOf: withUnsafeBytes(of: payloadLength.littleEndian) { Data($0) })
        
        // Add payload
        packet.append(positionData)
        
        return packet
    }
    
    /// Encode a node info request
    func encodeNodeInfoRequest(for nodeID: UInt32) throws -> Data {
        var packet = Data()
        
        // Add packet header
        packet.append(MeshtasticBLE.StreamHeader.start1)
        packet.append(MeshtasticBLE.StreamHeader.start2)
        
        // Destination: specific node
        packet.append(contentsOf: withUnsafeBytes(of: nodeID.littleEndian) { Data($0) })
        
        // Port number: nodeInfo
        let portNum = MeshtasticPortNum.nodeInfo.rawValue
        packet.append(contentsOf: withUnsafeBytes(of: portNum.littleEndian) { Data($0) })
        
        // Want ack: true for node info requests
        packet.append(1)
        
        // Empty payload for request
        packet.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Data($0) })
        
        return packet
    }
    
    // MARK: - Message Decoding
    
    /// Decode a received Meshtastic packet
    func decodePacket(_ data: Data) throws -> MeshtasticPacket {
        guard data.count >= 11 else { // Minimum packet size
            throw MeshtasticProtocolError.decodingFailed("Packet too small")
        }
        
        // Verify header
        guard data[0] == MeshtasticBLE.StreamHeader.start1,
              data[1] == MeshtasticBLE.StreamHeader.start2 else {
            throw MeshtasticProtocolError.decodingFailed("Invalid packet header")
        }
        
        // Extract fields
        let fromNodeID = data.subdata(in: 2..<6).withUnsafeBytes { $0.load(as: UInt32.self) }
        let portNum = data.subdata(in: 6..<10).withUnsafeBytes { $0.load(as: UInt32.self) }
        let wantAck = data[10] != 0
        let payloadLength = data.subdata(in: 11..<13).withUnsafeBytes { $0.load(as: UInt16.self) }
        
        guard data.count >= 13 + Int(payloadLength) else {
            throw MeshtasticProtocolError.decodingFailed("Incomplete payload")
        }
        
        let payload = data.subdata(in: 13..<(13 + Int(payloadLength)))
        
        return MeshtasticPacket(
            fromNodeID: fromNodeID,
            portNum: MeshtasticPortNum(rawValue: portNum) ?? .unknown,
            wantAck: wantAck,
            payload: payload
        )
    }
    
    /// Decode a text message from payload
    func decodeTextMessage(from payload: Data) throws -> String {
        guard let text = String(data: payload, encoding: .utf8) else {
            throw MeshtasticProtocolError.decodingFailed("Failed to decode text message")
        }
        return text
    }
    
    /// Decode a position update from payload
    func decodePosition(from payload: Data) throws -> CLLocation {
        guard payload.count >= 16 else { // Minimum position data size
            throw MeshtasticProtocolError.decodingFailed("Position payload too small")
        }
        
        let latitudeI = payload.subdata(in: 0..<4).withUnsafeBytes { $0.load(as: Int32.self) }
        let longitudeI = payload.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: Int32.self) }
        let altitude = payload.subdata(in: 8..<12).withUnsafeBytes { $0.load(as: Int32.self) }
        let time = payload.subdata(in: 12..<16).withUnsafeBytes { $0.load(as: UInt32.self) }
        
        let latitude = Double(latitudeI) / 1e7
        let longitude = Double(longitudeI) / 1e7
        let timestamp = Date(timeIntervalSince1970: TimeInterval(time))
        
        return CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: Double(altitude),
            horizontalAccuracy: 0,
            verticalAccuracy: 0,
            timestamp: timestamp
        )
    }
    
    // MARK: - Validation
    
    /// Validate that a packet is well-formed
    func validatePacket(_ data: Data) -> Bool {
        guard data.count >= 11 else { return false }
        guard data[0] == MeshtasticBLE.StreamHeader.start1,
              data[1] == MeshtasticBLE.StreamHeader.start2 else {
            return false
        }
        return true
    }
    
    /// Check if a node ID is valid (not broadcast, not reserved)
    func isValidNodeID(_ nodeID: UInt32) -> Bool {
        return nodeID > 0 && nodeID < 0xFFFFFFFF
    }
}

// MARK: - Supporting Types

struct MeshtasticPacket {
    let fromNodeID: UInt32
    let portNum: MeshtasticPortNum
    let wantAck: Bool
    let payload: Data
}

enum MeshtasticProtocolError: LocalizedError {
    case encodingFailed(String)
    case decodingFailed(String)
    case invalidPacket
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed(let reason):
            return "Encoding failed: \(reason)"
        case .decodingFailed(let reason):
            return "Decoding failed: \(reason)"
        case .invalidPacket:
            return "Invalid packet format"
        }
    }
}
