import SwiftUI

// MARK: - Diagnostics View
/// Hidden diagnostics screen for field debugging.
/// Access via Settings or long-press on version number.

struct DiagnosticsView: View {
    @StateObject private var logger = FieldLogger.shared
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @State private var showingExportSheet = false
    @State private var exportedLogs = ""
    @State private var selectedLevel: FieldLogger.LogLevel?
    
    var body: some View {
        ZStack {
            Theme.Colors.backgroundDark.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // Status Cards
                    HStack(spacing: Theme.Spacing.md) {
                        StatusCard(
                            title: "Uptime",
                            value: logger.uptimeString,
                            icon: "clock.fill",
                            color: Theme.Colors.turquoise
                        )
                        
                        StatusCard(
                            title: "Errors",
                            value: "\(logger.errorCount)",
                            icon: "exclamationmark.triangle.fill",
                            color: logger.errorCount > 0 ? Theme.Colors.emergency : Theme.Colors.connected
                        )
                        
                        StatusCard(
                            title: "Warnings",
                            value: "\(logger.warningCount)",
                            icon: "exclamationmark.circle.fill",
                            color: logger.warningCount > 0 ? Theme.Colors.warning : Theme.Colors.connected
                        )
                    }
                    
                    // System Info
                    SystemInfoCard()
                    
                    // Connection Status
                    ConnectionStatusCard()
                    
                    // Log Filter
                    LogFilterBar(selectedLevel: $selectedLevel)
                    
                    // Recent Logs
                    RecentLogsCard(logs: filteredLogs)
                    
                    // Actions
                    DiagnosticsActionsCard(
                        onExport: exportLogs,
                        onClear: { logger.clearLogs() },
                        onRefreshMemory: { logger.logMemoryUsage() },
                        onRefreshBattery: { logger.logBatteryStatus() }
                    )
                }
                .padding()
            }
        }
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingExportSheet) {
            LogExportSheet(logs: exportedLogs)
        }
    }
    
    private var filteredLogs: [FieldLogger.LogEntry] {
        if let level = selectedLevel {
            return logger.recentLogs.filter { $0.level == level }
        }
        return Array(logger.recentLogs.prefix(100))
    }
    
    private func exportLogs() {
        exportedLogs = logger.exportLogs()
        showingExportSheet = true
    }
}

// MARK: - Status Card
struct StatusCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.Colors.robotCream)
            
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
    }
}

// MARK: - System Info Card
struct SystemInfoCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(Theme.Colors.turquoise)
                Text("System Info")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
            }
            
            Divider().background(Theme.Colors.robotCream.opacity(0.2))
            
            InfoRow(label: "App Version", value: appVersion)
            InfoRow(label: "Build", value: buildNumber)
            InfoRow(label: "iOS Version", value: UIDevice.current.systemVersion)
            InfoRow(label: "Device", value: UIDevice.current.model)
            InfoRow(label: "Storage Mode", value: storageMode)
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
    }
    
    private var storageMode: String {
        UserDefaults.standard.string(forKey: "storageMode") ?? "Local Only"
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Theme.Colors.robotCream)
        }
    }
}

// MARK: - Connection Status Card
struct ConnectionStatusCard: View {
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(Theme.Colors.turquoise)
                Text("Connection Status")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
            }
            
            Divider().background(Theme.Colors.robotCream.opacity(0.2))
            
            InfoRow(label: "Mesh Status", value: meshtasticManager.isConnected ? "Connected" : "Disconnected")
            InfoRow(label: "Nodes", value: "\(meshtasticManager.nodes.count)")
            InfoRow(label: "Messages", value: "\(meshtasticManager.messages.count)")
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
    }
}

// MARK: - Log Filter Bar
struct LogFilterBar: View {
    @Binding var selectedLevel: FieldLogger.LogLevel?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                DiagFilterChip(label: "All", isSelected: selectedLevel == nil) {
                    selectedLevel = nil
                }
                
                ForEach(FieldLogger.LogLevel.allCases, id: \.self) { level in
                    DiagFilterChip(
                        label: "\(level.emoji) \(level.rawValue)",
                        isSelected: selectedLevel == level
                    ) {
                        selectedLevel = level
                    }
                }
            }
        }
    }
}

struct DiagFilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected ? Theme.Colors.backgroundDark : Theme.Colors.robotCream)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xs)
                .background(isSelected ? Theme.Colors.turquoise : Theme.Colors.backgroundLight)
                .cornerRadius(Theme.CornerRadius.full)
        }
    }
}

// MARK: - Recent Logs Card
struct RecentLogsCard: View {
    let logs: [FieldLogger.LogEntry]
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(Theme.Colors.turquoise)
                Text("Recent Logs (\(logs.count))")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
            }
            
            Divider().background(Theme.Colors.robotCream.opacity(0.2))
            
            if logs.isEmpty {
                Text("No logs to display")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    .padding()
            } else {
                ForEach(logs.prefix(50)) { entry in
                    LogEntryRow(entry: entry)
                }
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
    }
}

struct LogEntryRow: View {
    let entry: FieldLogger.LogEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(entry.level.emoji)
                    .font(.system(size: 10))
                
                Text("[\(entry.category)]")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(categoryColor)
                
                Spacer()
                
                Text(entry.formattedTimestamp)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.4))
            }
            
            Text(entry.message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Theme.Colors.robotCream.opacity(0.8))
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
    
    private var categoryColor: Color {
        switch entry.category {
        case "Error", "Critical": return Theme.Colors.emergency
        case "Warning": return Theme.Colors.warning
        case "Mesh", "BLE": return Theme.Colors.turquoise
        case "Performance": return Theme.Colors.goldenYellow
        default: return Theme.Colors.robotCream.opacity(0.6)
        }
    }
}

// MARK: - Diagnostics Actions Card
struct DiagnosticsActionsCard: View {
    let onExport: () -> Void
    let onClear: () -> Void
    let onRefreshMemory: () -> Void
    let onRefreshBattery: () -> Void
    
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                DiagButton(title: "Memory", icon: "memorychip", action: onRefreshMemory)
                DiagButton(title: "Battery", icon: "battery.100", action: onRefreshBattery)
            }
            
            HStack(spacing: Theme.Spacing.sm) {
                DiagButton(title: "Export", icon: "square.and.arrow.up", action: onExport)
                DiagButton(title: "Clear", icon: "trash", color: Theme.Colors.emergency, action: onClear)
            }
        }
    }
}

struct DiagButton: View {
    let title: String
    let icon: String
    var color: Color = Theme.Colors.turquoise
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(Theme.Typography.callout)
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.Colors.backgroundLight)
            .cornerRadius(Theme.CornerRadius.md)
        }
    }
}

// MARK: - Log Export Sheet
struct LogExportSheet: View {
    let logs: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                ScrollView {
                    Text(logs)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Theme.Colors.robotCream)
                        .padding()
                }
            }
            .navigationTitle("Exported Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.Colors.sunsetOrange)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: logs) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(Theme.Colors.turquoise)
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        DiagnosticsView()
            .environmentObject(MeshtasticManager())
    }
}
