# Slacker Application Architecture

## 🎯 **Vision**
Transform Slacker from a simple Ollama chat app into a comprehensive Slack assistant that processes incoming Slack messages via webhooks, generates AI responses using local Ollama, and provides a streamlined workflow for managing and sending responses back to Slack.

## 🏗️ **Application Structure**

### **Main Navigation Flow**
```
SlackerApp
├── SlackerOffView (NEW MAIN VIEW - Primary Interface)
│   ├── Webhook Server Status Indicator
│   ├── Slack Message Feed/Queue
│   ├── AI Response Generation & Management
│   ├── Action Buttons (Copy, Edit, Send, Dismiss)
│   └── "Chat with Slacker" Navigation Button
└── ChatView (EXISTING - Secondary Interface)
    ├── Traditional AI Chat Interface
    └── "Back to Slacker-off" Navigation Button
```

### **Navigation Implementation**
- Use `NavigationStack` with programmatic navigation
- Two distinct workflows: reactive message processing vs interactive chat
- Seamless transition between modes with context preservation

## 🔌 **Webhook Infrastructure**

### **NGrok Tunnel Setup**
- **Static URL**: `https://relaxing-sensibly-ghost.ngrok-free.app/`
- **Local Command**: `ngrok http --url=relaxing-sensibly-ghost.ngrok-free.app 8080`
- **Local Endpoint**: `localhost:8080`
- **Webhook Path**: `/zapier-webhook`

### **Zapier Integration Flow**
```
Slack Event → Zapier Trigger → NGrok Tunnel → Slacker App → Ollama → Response → Zapier Action → Slack
```

1. **Slack Trigger**: New mention, DM, or channel message
2. **Zapier Webhook**: POST to `https://relaxing-sensibly-ghost.ngrok-free.app/zapier-webhook`
3. **NGrok Tunnel**: Routes to `localhost:8080/zapier-webhook`
4. **Slacker Processing**: Receive → Queue → Process with Ollama → Respond
5. **Zapier Action**: Send Channel Message or Direct Message back to Slack

## 📊 **Data Models**

### **SlackMessage Model**
```swift
@Model
final class SlackMessage: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    
    // Slack Data
    var text: String
    var channelId: String
    var channelName: String?
    var userId: String
    var userName: String?
    var threadTS: String?
    var slackTimestamp: String
    
    // Processing Data
    var status: MessageStatus = .pending
    var aiResponse: String?
    var error: String?
    
    // Metadata
    var receivedAt: Date = Date.now
    var processedAt: Date?
    var sentAt: Date?
    
    init(from zapierPayload: ZapierPayload) {
        // Initialize from incoming webhook data
    }
}

enum MessageStatus: String, CaseIterable {
    case pending = "pending"
    case processing = "processing" 
    case completed = "completed"
    case sent = "sent"
    case error = "error"
    case dismissed = "dismissed"
}
```

### **Webhook Payload Structure**
```swift
struct ZapierPayload: Codable {
    let text: String
    let channelId: String
    let channelName: String?
    let userId: String
    let userName: String?
    let threadTS: String?
    let timestamp: String
}

struct WebhookResponse: Codable {
    let replyText: String
    let channelId: String
    let threadTS: String?
    let status: String
}
```

## 🎨 **User Interface Design**

### **SlackerOffView Layout**
```
┌─────────────────────────────────────────────────────────┐
│ 🟢 Webhook Server: Running on :8080     [Chat w/ Slacker]│
│ 🌐 NGrok: relaxing-sensibly-ghost.ngrok-free.app        │
├─────────────────────────────────────────────────────────┤
│ 📨 Slack Messages Queue (3 pending, 1 processing)       │
├─────────────────────────────────────────────────────────┤
│ 💬 #general - @john: "Can you help with the API docs?"  │
│ 🤖 AI Response: "I'd be happy to help with that..."     │
│ [📋 Copy] [✏️  Edit in Chat] [✅ Send] [❌ Dismiss]      │
├─────────────────────────────────────────────────────────┤
│ 💬 DM - @sarah: "What's the status of the deployment?"  │
│ ⏳ Generating response... [🛑 Cancel]                   │
├─────────────────────────────────────────────────────────┤
│ 💬 #dev - @mike: "Meeting notes from yesterday?"        │
│ ⏸️  Queued [▶️ Process Now] [❌ Dismiss]                │
└─────────────────────────────────────────────────────────┘
```

### **Message Card Component Structure**
- **Header**: Channel/DM indicator, user info, timestamp
- **Original Message**: Slack message content with context
- **AI Response Section**: Generated response with status indicator
- **Action Bar**: Copy, Edit, Send, Dismiss buttons
- **Status Indicators**: Visual feedback for processing states

## ⚙️ **Technical Implementation**

### **HTTP Server Implementation**
- **Library**: Swifter (lightweight, macOS-friendly)
- **Port**: 8080 (configurable)
- **Endpoints**:
  - `POST /zapier-webhook` - Primary webhook receiver
  - `GET /health` - Health check for NGrok/Zapier testing
  - `GET /status` - Server status and statistics

### **State Management**
```swift
@Observable
final class SlackerOffViewModel {
    // Server State
    var isServerRunning: Bool = false
    var serverPort: Int = 8080
    var ngrokUrl: String = "https://relaxing-sensibly-ghost.ngrok-free.app"
    
    // Message Management
    var messages: [SlackMessage] = []
    var processingQueue: [UUID] = []
    var processingCount: Int = 0
    var errorCount: Int = 0
    
    // Settings
    var autoProcessMessages: Bool = true
    var maxConcurrentProcessing: Int = 3
    var defaultSystemPrompt: String = "You are a helpful Slack assistant..."
}
```

### **Background Processing**
- **Concurrent Processing**: TaskGroup for handling multiple messages
- **Queue Management**: FIFO processing with priority options
- **Error Handling**: Comprehensive error states with retry logic
- **Progress Tracking**: Real-time status updates for UI

## 🔄 **Message Processing Pipeline**

### **Phase 1: Webhook Reception**
1. Receive POST from Zapier via NGrok
2. Validate and parse JSON payload
3. Create SlackMessage model instance
4. Add to processing queue
5. Return immediate HTTP response to Zapier

### **Phase 2: AI Processing**
1. Extract message from queue
2. Update status to "processing"
3. Prepare context and system prompt
4. Send to Ollama via existing chat infrastructure
5. Handle response and errors
6. Update message with AI response

### **Phase 3: User Review & Action**
1. Display message and AI response in UI
2. User can: Copy, Edit in Chat, Send, or Dismiss
3. If "Send" selected, return response data to Zapier
4. Update message status based on action taken

## 🚀 **Development Phases**

### **Phase 1: Foundation (MVP)**
- [ ] Create SlackerOffView and basic UI
- [ ] Implement HTTP server with Swifter
- [ ] Set up NGrok integration and testing
- [ ] Create SlackMessage model and basic data flow
- [ ] Add navigation between SlackerOff and Chat views

### **Phase 2: Core Functionality**
- [ ] Implement webhook endpoint and payload parsing
- [ ] Integrate with existing Ollama chat functionality
- [ ] Build message queue and processing pipeline
- [ ] Add basic user actions (copy, dismiss)
- [ ] Implement status tracking and error handling

### **Phase 3: Advanced Features**
- [ ] Add "Edit in Chat" functionality with context passing
- [ ] Implement automatic response sending back to Zapier
- [ ] Add message persistence and history
- [ ] Build settings and configuration UI
- [ ] Add notification system for new messages

### **Phase 4: Polish & Optimization**
- [ ] Performance optimization for high message volumes
- [ ] Advanced filtering and message management
- [ ] Response templates and customization
- [ ] Analytics and usage tracking
- [ ] Comprehensive error recovery

## 🔧 **Configuration & Settings**

### **Server Configuration**
- NGrok URL management
- Local port configuration
- Webhook endpoint paths
- Health check intervals

### **Message Processing**
- Auto-processing toggle
- Concurrent processing limits
- Default system prompts per channel/context
- Response timeout settings

### **UI Preferences**
- Message display options
- Color coding for different channels
- Notification preferences
- Keyboard shortcuts

## 🧪 **Testing Strategy**

### **Webhook Testing**
- Use NGrok's web interface for request inspection
- Manual webhook testing with curl/Postman
- Zapier webhook testing tools
- Error case simulation

### **Integration Testing**
- End-to-end Slack → Zapier → App → Ollama flow
- Error handling at each stage
- Performance testing with multiple concurrent messages
- NGrok reliability and failover scenarios

## 📋 **Deployment Checklist**

### **Initial Setup**
1. Start NGrok: `ngrok http --url=relaxing-sensibly-ghost.ngrok-free.app 8080`
2. Configure Zapier webhook URL: `https://relaxing-sensibly-ghost.ngrok-free.app/zapier-webhook`
3. Launch Slacker app and verify server starts on port 8080
4. Test webhook reception with Zapier test feature
5. Verify Ollama is running and accessible on port 11434

### **Production Considerations**
- NGrok account management and URL persistence
- Error monitoring and alerting
- Performance monitoring for high-volume usage
- Backup webhook endpoints for redundancy
- Rate limiting and abuse prevention

## 🎯 **Success Metrics**

- **Webhook Reliability**: >99% successful webhook receptions
- **Processing Speed**: <30 seconds average response generation
- **User Satisfaction**: Streamlined workflow reduces manual Slack response time
- **System Integration**: Seamless flow between all components
- **Error Recovery**: Graceful handling of failures at any stage

---

*This architecture document serves as the master blueprint for Slacker development. Update as implementation progresses and requirements evolve.* 