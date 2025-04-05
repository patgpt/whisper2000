# 🎧 Whisper2000 — A Real-Time Listening App

**Whisper2000** is a cross-platform Flutter application designed to enhance hearing, increase safety, and empower users with real-time audio clarity. It boosts human speech, suppresses background noise, and optionally transcribes recorded sound for accessibility, privacy, and monitoring purposes.

---

## 🔥 Features

- 🎙 Real-time voice boosting & background noise reduction
- 🎧 Bluetooth/earbuds audio streaming
- 🧠 Optional transcription with Whisper (offline & cloud)
- 📼 Save last 30s of sound and review it
- 🔐 Privacy-first: no cloud uploads unless enabled
- 🎛 Voice filters, mic gain control, and smart modes
- 💡 Keyword alerts, whisper mode, and emotion detection (future)

---

## 🛠️ Tech Stack

- Flutter 3.x (Cupertino-first, adaptive)
- Riverpod for state management
- FFMPEG & WebRTC for audio processing
- Whisper (cpp or cloud) for speech-to-text
- Hive for local storage
- macOS and Android supported (iOS stubbed)

---

## 🧪 Local Development

### 📱 Requirements

- Flutter 3.x
- macOS (for Desktop support)
- Android SDK + Emulator or Device

### ▶️ Run App

```bash
flutter pub get
flutter run
```

For macOS desktop:

```bash
flutter run -d macos
```

⸻

🤖 Directory Structure

/lib
/core → shared logic (audio, utils)
/features → feature-based folders: home, live_listening, etc.
/widgets → shared UI components
main.dart → entry point

⸻

✨ Contributing

All contributions must follow our coding standards and a11y/UX guidelines. See:
• .cursor/rules/flutter_rules.mdc
• .cursor/rules/ux_rules.mdc

⸻

⚖️ License

MIT License. Built with love, empathy, and weird late-night energy.

⸻

💌 Author

Patrick Kelly — @patgpt
Dreaming in signals, ghosting through code.

---

# 🎧 Whisper2000 — A Real-Time Listening App

**Whisper2000** is a cross-platform Flutter application designed to enhance hearing, increase safety, and empower users with real-time audio clarity. It boosts human speech, suppresses background noise, and optionally transcribes recorded sound for accessibility, privacy, and monitoring purposes.

---
