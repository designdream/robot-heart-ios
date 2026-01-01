import SwiftUI

struct MessagesView: View {
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @State private var messageText = ""
    @State private var showingTemplates = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Messages list
                    ScrollView {
                        LazyVStack(spacing: Theme.Spacing.sm) {
                            ForEach(meshtasticManager.messages) { message in
                                MessageBubble(message: message)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                        .padding()
                    }
                    .rotationEffect(.degrees(180))
                    
                    Divider()
                        .background(Theme.Colors.backgroundLight)
                    
                    // Input area
                    inputView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Messages")
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.Colors.robotCream)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingTemplates.toggle() }) {
                        Image(systemName: "text.badge.plus")
                            .foregroundColor(Theme.Colors.sunsetOrange)
                    }
                }
            }
            .sheet(isPresented: $showingTemplates) {
                MessageTemplatesSheet(
                    onSelect: { template in
                        sendMessage(template.content, type: template.type)
                        showingTemplates = false
                    }
                )
            }
        }
    }
    
    private var inputView: some View {
        HStack(spacing: Theme.Spacing.sm) {
            TextField("Message camp...", text: $messageText)
                .focused($isInputFocused)
                .textFieldStyle(PlainTextFieldStyle())
                .padding()
                .background(Theme.Colors.backgroundMedium)
                .cornerRadius(Theme.CornerRadius.lg)
                .foregroundColor(Theme.Colors.robotCream)
            
            Button(action: sendCurrentMessage) {
                Image(systemName: messageText.isEmpty ? "mic.fill" : "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(messageText.isEmpty ? Theme.Colors.robotCream.opacity(0.5) : Theme.Colors.sunsetOrange)
            }
            .disabled(messageText.isEmpty)
        }
        .padding()
        .background(Theme.Colors.backgroundDark)
    }
    
    private func sendCurrentMessage() {
        guard !messageText.isEmpty else { return }
        sendMessage(messageText, type: .text)
        messageText = ""
        isInputFocused = false
    }
    
    private func sendMessage(_ content: String, type: Message.MessageType) {
        withAnimation(Theme.Animations.standard) {
            meshtasticManager.sendMessage(content, type: type)
        }
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: Message
    
    var isFromMe: Bool {
        message.from == "!local"
    }
    
    var body: some View {
        HStack {
            if isFromMe { Spacer() }
            
            VStack(alignment: isFromMe ? .trailing : .leading, spacing: Theme.Spacing.xs) {
                // Sender name and type indicator
                if !isFromMe {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: message.messageType.icon)
                            .font(.caption2)
                            .foregroundColor(messageTypeColor)
                        
                        Text(message.fromName)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    }
                }
                
                // Message content
                Text(message.displayContent)
                    .font(Theme.Typography.body)
                    .foregroundColor(isFromMe ? .white : Theme.Colors.robotCream)
                    .padding(Theme.Spacing.md)
                    .background(isFromMe ? Theme.Colors.sunsetOrange : Theme.Colors.backgroundMedium)
                    .cornerRadius(Theme.CornerRadius.md)
                
                // Timestamp and delivery status
                HStack(spacing: Theme.Spacing.xs) {
                    Text(timeString(from: message.timestamp))
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    
                    if isFromMe {
                        Image(systemName: message.deliveryStatus.icon)
                            .font(.caption2)
                            .foregroundColor(deliveryStatusColor)
                    }
                }
            }
            .frame(maxWidth: 280, alignment: isFromMe ? .trailing : .leading)
            
            if !isFromMe { Spacer() }
        }
        .rotationEffect(.degrees(180))
    }
    
    private var messageTypeColor: Color {
        switch message.messageType {
        case .text: return Theme.Colors.turquoise
        case .announcement: return Theme.Colors.sunsetOrange
        case .emergency: return Theme.Colors.disconnected
        case .locationShare: return Theme.Colors.connected
        case .shiftUpdate: return Theme.Colors.dustyPink
        }
    }
    
    private var deliveryStatusColor: Color {
        switch message.deliveryStatus {
        case .queued: return Theme.Colors.warning
        case .sent: return Theme.Colors.turquoise
        case .delivered: return Theme.Colors.connected
        case .failed: return Theme.Colors.disconnected
        }
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Message Templates Sheet
struct MessageTemplatesSheet: View {
    let onSelect: (Message.Template) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.sm) {
                        ForEach(Message.Template.allCases, id: \.self) { template in
                            TemplateCard(template: template, onSelect: onSelect)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Quick Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Theme.Colors.sunsetOrange)
                }
            }
        }
    }
}

// MARK: - Template Card
struct TemplateCard: View {
    let template: Message.Template
    let onSelect: (Message.Template) -> Void
    
    var body: some View {
        Button(action: { onSelect(template) }) {
            HStack {
                Image(systemName: template.type.icon)
                    .foregroundColor(iconColor)
                    .font(.title3)
                    .frame(width: 40)
                
                Text(template.content)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.robotCream)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    .font(.caption)
            }
            .padding()
            .background(Theme.Colors.backgroundMedium)
            .cornerRadius(Theme.CornerRadius.md)
        }
    }
    
    private var iconColor: Color {
        switch template.type {
        case .text: return Theme.Colors.turquoise
        case .announcement: return Theme.Colors.sunsetOrange
        case .emergency: return Theme.Colors.disconnected
        case .locationShare: return Theme.Colors.connected
        case .shiftUpdate: return Theme.Colors.dustyPink
        }
    }
}

#Preview {
    MessagesView()
        .environmentObject(MeshtasticManager())
}
