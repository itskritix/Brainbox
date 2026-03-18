# Brainbox

A native macOS AI chat app. Runs locally — no server, no account, no cloud. Bring your own API keys and start chatting.

Supports **OpenAI**, **Anthropic**, **Google**, **Mistral**, **xAI**, **DeepSeek**, and **Groq**.

## Setup

1. Clone the repo and open `Brainbox.xcodeproj` in Xcode
2. Build and run (Cmd+R)
3. Go to **Settings > API Keys**, enter a key for any provider
4. Pick a model and start chatting

Requires **macOS 15+** and **Xcode 26+**.

## How it works

- **Storage** — SwiftData (local SQLite). Conversations, messages, profiles all persist on your Mac.
- **Streaming** — Direct HTTPS to provider APIs using Server-Sent Events. No middleware.
- **API Keys** — Stored in the macOS Keychain. Encrypted at rest, never leave your device.
- **Attachments** — Images and PDFs saved locally in Application Support.

## Features

- Multi-provider AI chat with streaming responses
- Conversation history with search and date grouping
- Chat profiles for separate contexts
- Image and PDF attachments (drag, drop, or paste)
- Quick Chat overlay (Option+Space)
- 8 color themes with Liquid Glass support
- Keyboard shortcuts for everything

## Project structure

```
Brainbox/
  Models/SwiftData/    # SDConversation, SDMessage, SDAttachment, SDProfile
  Services/            # DataService, StreamingService, KeychainService, SSEParser
  ViewModels/          # ChatViewModel, ConversationListViewModel, ProfileViewModel
  Views/               # SwiftUI views (Chat, Sidebar, Settings, QuickChat)
  Theme/               # ThemeManager, 8 theme presets
```

## License

MIT
