# FinWise

A personal finance iOS app with AI-powered transaction parsing.

## Features

- **Smart Transaction Parsing**: Automatic parsing of SMS and email transactions using LLM
- **Multi-Currency Support**: Live exchange rates with automatic conversion
- **Budget Management**: Category-based budgets with rollover support
- **Analytics Dashboard**: 5-tab analytics (Trends, Categories, Income, Merchants, Payment)
- **Smart Insights**: Recurring bills detection, savings goals, budget alerts
- **Security**: Face ID/Touch ID app lock, encrypted backups

## Requirements

- Flutter SDK 3.0+
- Xcode 14+
- iOS 16+
- CocoaPods

## Setup

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   cd ios && pod install && cd ..
   ```
3. Open `ios/Runner.xcworkspace` in Xcode
4. Configure signing (your Apple Developer account)
5. Run the app:
   ```bash
   flutter run
   ```

## Build

### Debug
```bash
flutter run
```

### Release
```bash
flutter build ios --release
```

## Project Structure

```
FinWise/
├── lib/
│   ├── main.dart              # App entry point
│   ├── models/                # Data models
│   ├── screens/               # UI screens
│   ├── services/              # Business logic
│   ├── theme/                 # App theming
│   ├── utils/                 # Utilities
│   └── widgets/               # Reusable widgets
├── ios/
│   └── Runner/
│       ├── AppDelegate.swift  # iOS app delegate
│       └── *.swift            # Native Swift code
└── test/                      # Tests
```

## Configuration

### LLM Settings
Configure your LLM provider in the app settings:
- OpenRouter API
- NVIDIA API

### Gmail Integration
For email parsing, configure Google OAuth in the app settings.

## License

MIT
