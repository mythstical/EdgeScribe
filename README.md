# EdgeScribe

EdgeScribe is a secure, local AI chat application built with Flutter and the Cactus SDK.

## Features
- **Local Inference**: Runs AI models directly on your device using Cactus SDK.
- **Privacy Focused**: No data leaves your device.
- **Secure**: Application code is obfuscated and sensitive data is stored securely.

## Getting Started

### Prerequisites
- Flutter SDK installed.
- Android device or emulator.
- A GGUF model file (e.g., Llama 3, Mistral) downloaded to your device.

### Installation
1. Clone the repository.
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```

### Usage
1. Launch the app.
2. Tap the **Settings** icon (gear) in the top right.
3. Enter the absolute path to your GGUF model file on the device (e.g., `/storage/emulated/0/Download/model.gguf`).
4. Tap **LOAD**.
5. Once loaded, start chatting!

## Security
- **Obfuscation**: Release builds are minified and obfuscated using ProGuard/R8.
- **Secure Storage**: `flutter_secure_storage` is used for sensitive data persistence.

## Development
- The AI service is located in `lib/services/ai_service.dart`.
- Currently, it contains a placeholder for the Cactus SDK integration. You will need to uncomment and adjust the code based on the specific Cactus SDK version and API you are using.