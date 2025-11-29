# EdgeScribe - Hackathon Build Guide

## Building with Picovoice API Key

For hackathon judges to test the app seamlessly:

### Method 1: Build with Embedded Key (Recommended for Demo)

```bash
flutter build apk --dart-define=PICOVOICE_KEY=your_picovoice_access_key_here
```

**What this does**:
- Embeds your Picovoice AccessKey in the APK
- Judges can install and use immediately
- No setup required on their end

###Method 2: Runtime Key Entry (For Production)

If you build without the key:
```bash
flutter build apk
```

Users will be prompted to enter their own Picovoice AccessKey on first launch.

---

## Prerequisites

### 1. Picovoice AccessKey
- Sign up at https://console.picovoice.ai/
- Get your free AccessKey
- Free tier: 3 hours/month processing

### 2. Leopard Model File
Download the default English model:
```bash
wget https://github.com/Picovoice/leopard/raw/master/lib/common/leopard_params.pv
mv leopard_params.pv assets/leopard_model.pv
```

Or create custom model at https://console.picovoice.ai/

### 3. Update pubspec.yaml
Ensure this line is present:
```yaml
flutter:
  assets:
    - assets/leopard_model.pv
```

---

## Testing Both Services

The app supports **two transcription engines**:

| Feature | Whisper (Cactus) | Leopard (Picovoice) |
|---------|------------------|---------------------|
| Speed | ~2x real-time | ~0.5x real-time ⚡ |
| Accuracy | High | Very High |
| Model Size | ~1.5GB | ~100MB |
| API Key | None | Required |
| Offline | ✅ | ✅ |

### UI Toggle
Switch between services using the dropdown in the app.

---

## Quick Start

1. **Get your AccessKey**:
   ```
   Visit: https://console.picovoice.ai/
   ```

2. **Download model**:
   ```bash
   wget https://github.com/Picovoice/leopard/raw/master/lib/common/leopard_params.pv
   mv leopard_params.pv assets/leopard_model.pv
   ```

3. **Add asset to pubspec.yaml**:
   ```yaml
   flutter:
     assets:
       - assets/leopard_model.pv
   ```

4. **Build for hackathon**:
   ```bash
   flutter build apk --dart-define=PICOVOICE_KEY=your_key_here
   ```

5. **Install APK** on device and test!

---

## Troubleshooting

### "API key required" error
- Make sure you built with `--dart-define=PICOVOICE_KEY=...`
- Or enter key in Settings when app prompts

### "Model file not found"
- Check `assets/leopard_model.pv` exists
- Verify path in `pubspec.yaml`
- Run `flutter clean && flutter build apk`

### Key security
- Keys in build-time injection can be extracted (reverse engineering)
- For production, use runtime key entry
- Never commit keys to git!
