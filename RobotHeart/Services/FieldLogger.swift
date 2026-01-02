import Foundation
import os.log
import UIKit

// MARK: - Field Logger
/// Lightweight logging system for off-grid deployment.
/// Logs are stored locally and can be exported for debugging.
/// Designed to be battery-efficient and not require network connectivity.

final class FieldLogger: ObservableObject {
    static let shared = FieldLogger()
    
    // MARK: - Published Properties
    @Published private(set) var recentLogs: [LogEntry] = []
    @Published private(set) var errorCount: Int = 0
    @Published private(set) var warningCount: Int = 0
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let logsKey = "fieldLogs"
    private let maxLogEntries = 500
    private let osLog = OSLog(subsystem: "com.robotheart.app", category: "FieldLogger")
    
    // Performance metrics
    private var startupTime: Date?
    private var lastMemoryCheck: Date?
    
    // MARK: - Log Entry
    struct LogEntry: Identifiable, Codable {
        let id: UUID
        let timestamp: Date
        let level: LogLevel
        let category: String
        let message: String
        let metadata: [String: String]?
        
        init(level: LogLevel, category: String, message: String, metadata: [String: String]? = nil) {
            self.id = UUID()
            self.timestamp = Date()
            self.level = level
            self.category = category
            self.message = message
            self.metadata = metadata
        }
        
        var formattedTimestamp: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            return formatter.string(from: timestamp)
        }
    }
    
    enum LogLevel: String, Codable, CaseIterable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"
        case critical = "CRIT"
        
        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .critical: return "🚨"
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        startupTime = Date()
        loadLogs()
        log(.info, category: "System", message: "App started", metadata: [
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        ])
    }
    
    // MARK: - Logging Methods
    
    func log(_ level: LogLevel, category: String, message: String, metadata: [String: String]? = nil) {
        let entry = LogEntry(level: level, category: category, message: message, metadata: metadata)
        
        DispatchQueue.main.async { [weak self] in
            self?.addEntry(entry)
        }
        
        // Also log to system console in debug
        #if DEBUG
        os_log("%{public}@ [%{public}@] %{public}@", log: osLog, type: osLogType(for: level),
               level.emoji, category, message)
        #endif
    }
    
    func debug(_ category: String, _ message: String, metadata: [String: String]? = nil) {
        log(.debug, category: category, message: message, metadata: metadata)
    }
    
    func info(_ category: String, _ message: String, metadata: [String: String]? = nil) {
        log(.info, category: category, message: message, metadata: metadata)
    }
    
    func warning(_ category: String, _ message: String, metadata: [String: String]? = nil) {
        log(.warning, category: category, message: message, metadata: metadata)
        warningCount += 1
    }
    
    func error(_ category: String, _ message: String, metadata: [String: String]? = nil) {
        log(.error, category: category, message: message, metadata: metadata)
        errorCount += 1
    }
    
    func critical(_ category: String, _ message: String, metadata: [String: String]? = nil) {
        log(.critical, category: category, message: message, metadata: metadata)
        errorCount += 1
    }
    
    // MARK: - Performance Monitoring
    
    func logPerformance(_ operation: String, duration: TimeInterval) {
        let durationMs = duration * 1000
        let level: LogLevel = durationMs > 1000 ? .warning : (durationMs > 100 ? .info : .debug)
        log(level, category: "Performance", message: "\(operation) took \(String(format: "%.2f", durationMs))ms")
    }
    
    func measureBlock<T>(_ operation: String, block: () throws -> T) rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let duration = CFAbsoluteTimeGetCurrent() - start
        logPerformance(operation, duration: duration)
        return result
    }
    
    func logMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1024 / 1024
            let level: LogLevel = usedMB > 200 ? .warning : .info
            log(level, category: "Memory", message: "Using \(String(format: "%.1f", usedMB)) MB")
        }
    }
    
    func logBatteryStatus() {
        #if os(iOS)
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        let state = UIDevice.current.batteryState
        
        let stateString: String
        switch state {
        case .charging: stateString = "charging"
        case .full: stateString = "full"
        case .unplugged: stateString = "unplugged"
        default: stateString = "unknown"
        }
        
        let logLevel: LogLevel = level < 0.2 && state == .unplugged ? .warning : .info
        log(logLevel, category: "Battery", message: "\(Int(level * 100))% (\(stateString))")
        #endif
    }
    
    // MARK: - Mesh/BLE Logging
    
    func logMeshEvent(_ event: String, nodeId: String? = nil, success: Bool = true) {
        let level: LogLevel = success ? .info : .warning
        var metadata: [String: String] = ["success": String(success)]
        if let nodeId = nodeId {
            metadata["nodeId"] = nodeId
        }
        log(level, category: "Mesh", message: event, metadata: metadata)
    }
    
    func logBLEEvent(_ event: String, deviceId: String? = nil, rssi: Int? = nil) {
        var metadata: [String: String] = [:]
        if let deviceId = deviceId {
            metadata["deviceId"] = deviceId
        }
        if let rssi = rssi {
            metadata["rssi"] = String(rssi)
        }
        log(.info, category: "BLE", message: event, metadata: metadata)
    }
    
    // MARK: - Export
    
    func exportLogs() -> String {
        var output = "=== Robot Heart Field Logs ===\n"
        output += "Exported: \(Date())\n"
        output += "Uptime: \(uptimeString)\n"
        output += "Errors: \(errorCount), Warnings: \(warningCount)\n"
        output += "================================\n\n"
        
        for entry in recentLogs {
            output += "[\(entry.formattedTimestamp)] \(entry.level.emoji) [\(entry.category)] \(entry.message)\n"
            if let metadata = entry.metadata {
                for (key, value) in metadata {
                    output += "  → \(key): \(value)\n"
                }
            }
        }
        
        return output
    }
    
    func clearLogs() {
        recentLogs.removeAll()
        errorCount = 0
        warningCount = 0
        saveLogs()
    }
    
    // MARK: - Diagnostics
    
    var uptimeString: String {
        guard let start = startupTime else { return "unknown" }
        let interval = Date().timeIntervalSince(start)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    var diagnosticSummary: String {
        """
        Uptime: \(uptimeString)
        Logs: \(recentLogs.count)
        Errors: \(errorCount)
        Warnings: \(warningCount)
        """
    }
    
    // MARK: - Private Methods
    
    private func addEntry(_ entry: LogEntry) {
        recentLogs.insert(entry, at: 0)
        
        // Trim to max entries
        if recentLogs.count > maxLogEntries {
            recentLogs = Array(recentLogs.prefix(maxLogEntries))
        }
        
        // Save periodically (every 10 entries) to reduce disk writes
        if recentLogs.count % 10 == 0 {
            saveLogs()
        }
    }
    
    private func saveLogs() {
        if let encoded = try? JSONEncoder().encode(recentLogs) {
            userDefaults.set(encoded, forKey: logsKey)
        }
    }
    
    private func loadLogs() {
        if let data = userDefaults.data(forKey: logsKey),
           let decoded = try? JSONDecoder().decode([LogEntry].self, from: data) {
            recentLogs = decoded
            errorCount = decoded.filter { $0.level == .error || $0.level == .critical }.count
            warningCount = decoded.filter { $0.level == .warning }.count
        }
    }
    
    private func osLogType(for level: LogLevel) -> OSLogType {
        switch level {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }
}

// MARK: - Convenience Extensions

extension FieldLogger {
    func logNavigation(to screen: String) {
        debug("Navigation", "→ \(screen)")
    }
    
    func logUserAction(_ action: String, details: String? = nil) {
        info("User", action + (details.map { ": \($0)" } ?? ""))
    }
    
    func logDataSync(_ operation: String, itemCount: Int, success: Bool) {
        let level: LogLevel = success ? .info : .error
        log(level, category: "Sync", message: "\(operation): \(itemCount) items", metadata: [
            "success": String(success),
            "count": String(itemCount)
        ])
    }
}
