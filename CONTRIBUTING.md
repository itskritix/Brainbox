# Contributing

Thanks for your interest in Brainbox. Here's how to get involved.

## Getting started

1. Fork the repo
2. Clone your fork and open `Brainbox.xcodeproj`
3. Create a branch for your work (`git checkout -b my-feature`)
4. Make your changes and run the tests
5. Push and open a Pull Request

## Running tests

```
xcodebuild -project Brainbox.xcodeproj -scheme Brainbox -destination 'platform=macOS' test
```

## Guidelines

- Keep PRs focused — one feature or fix per PR
- Follow existing code style (SwiftUI, `@Observable`, no third-party deps unless necessary)
- Add tests for new services or parsers
- Don't commit API keys or secrets

## Architecture notes

- **DataServiceProtocol** is the data access layer. All ViewModels go through it. If you're adding a new backend, implement this protocol.
- **StreamingService** handles direct HTTP SSE to AI providers. To add a provider, add its config in `ProviderConfig.config(for:)` and a parser case in `SSEParser` if needed.
- **KeychainService** manages API keys. Adding a provider means adding it to `KeychainService.providers` and `AIModel.swift`.

## Reporting issues

Open an issue on GitHub. Include what you expected, what happened, and your macOS version.
