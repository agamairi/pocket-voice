# Pocket Voice 🎙️

**Pocket Voice** is a lightweight, fully offline Flutter Android application designed for creators to generate high-quality 24 kHz speech narration for YouTube videos and video editors directly on-device.

Speech synthesis is powered entirely by [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) using the **PocketTTS INT8** model (`sherpa-onnx-pocket-tts-int8-2026-01-26`).

---

## Key Features

- **100% Offline Inference**: No cloud APIs, no OpenAI/Google TTS, no Python runtime on phone, no local HTTP servers, no WebViews, no telemetry or tracking. Everything is synthesized on-device.
- **Reference-Audio Conditioning**: PocketTTS is conditioned with short WAV reference audio files (`bria.wav`, `loona.wav` included; custom WAV files can be imported).
- **Sensible Text Segmentation**: Large scripts are segmented automatically on paragraph and sentence boundaries, avoiding memory limits and inference timeouts.
- **Configurable Pauses**: Configurable sentence pauses (default ~180 ms) and paragraph pauses (default ~400 ms) to produce natural, click-free 24 kHz Microsoft PCM WAV narrations.
- **Script Markup Support**: Optional tags like `[normal]`, `[excited]`, `[whisper]` are parsed and preserved in the parser data structure while being cleanly stripped from spoken audio so they are never read aloud.
- **Background Isolate Inference**: Audio generation runs inside a background Dart isolate with FFI bindings so the Flutter UI thread never freezes.
- **Real-Time Generation UI**: Displays live percentage, paragraph counter, elapsed narration time, and cooperative cancellation.
- **Audio Studio & Library**: Playback controls, seek slider, renaming, and one-tap Android native sharing to video editors (CapCut, Premiere Rush, Lumafusion, etc.).
- **Responsive Layout**: Tailored for both Pixel Phones and Pixel Tablets (split-pane dual-column layout on wide screens).

---

## Architecture

```
lib/
├── main.dart                       # App entry point, M3 themes, navigation scaffold
├── features/
│   ├── tts/
│   │   ├── tts_page.dart           # Studio screen with script editor & responsive layout
│   │   ├── tts_controller.dart     # State management (script, playback, settings, voices)
│   │   ├── pocket_tts_service.dart # Background isolate PocketTTS runner, streaming progress
│   │   ├── model_manager.dart      # First-launch model download, verification & storage
│   │   ├── voice_manager.dart      # Bundled and custom imported voice management
│   │   └── widgets/
│   │       ├── script_stats_bar.dart           # Words, characters, estimated duration
│   │       ├── generation_progress_dialog.dart # Progress modal with paragraph counter & cancel
│   │       ├── audio_result_card.dart          # Audio player card with seek & share
│   │       ├── voice_selector_sheet.dart       # Voice profile switcher & WAV importer
│   │       └── settings_bottom_sheet.dart      # Pauses, CPU threads, model manager
│   └── library/
│       ├── audio_library_page.dart # Previous generations browser
│       └── library_service.dart    # Narration persistence and filesystem manager
└── shared/
    ├── models/
    │   ├── voice_profile.dart      # Voice metadata model
    │   ├── narration_item.dart     # Saved narration item model
    │   └── tts_settings.dart       # Inference & pause settings model
    ├── widgets/
    │   └── model_download_view.dart# First-launch model downloader & extractor
    └── utils/
        ├── text_segmenter.dart     # Paragraph & sentence segmentation & markup parser
        ├── wav_concatenator.dart   # 24 kHz WAV concatenator with boundary fading
        ├── filename_generator.dart # narration_YYYY-MM-DD_HH-mm-ss.wav formatter
        └── duration_formatter.dart # Time & byte size formatters
```

---

## Model Download & Storage

To keep the application download size minimal, the PocketTTS model is not bundled into the APK.

- On first launch, the app prompts to download the official PocketTTS INT8 archive:
  - **Archive URL**: `https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/sherpa-onnx-pocket-tts-int8-2026-01-26.tar.bz2`
  - **Download Size**: ~94 MB
  - **Unpacked Size**: ~203 MB
- The archive is extracted automatically in a background isolate and verified for completeness:
  - `lm_flow.int8.onnx`
  - `lm_main.int8.onnx`
  - `encoder.onnx`
  - `decoder.int8.onnx`
  - `text_conditioner.onnx`
  - `vocab.json`
  - `token_scores.json`
  - `test_wavs/` (`bria.wav`, `loona.wav`)
- **Storage Location**: Stored in app-private storage (`<app_documents_dir>/models/sherpa-onnx-pocket-tts-int8-2026-01-26`). Once downloaded, the application works completely offline.
- Users can view storage usage, delete, or re-download the model at any time under **Settings → Offline Model & Storage**.

---

## Audio Storage

Generated audio files are saved under the app-managed `Narrations` directory:
- **Path**: `<app_documents_dir>/Narrations/`
- **Default naming pattern**: `narration_YYYY-MM-DD_HH-mm-ss.wav`
- **Format**: Standard 16-bit Microsoft PCM mono WAV at 24,000 Hz.
- Files can be renamed, played, deleted, and exported via the Android standard share sheet to video editors or cloud drives.

---

## Building and Running

### Prerequisites
- Flutter 3.24+ / Dart 3.5+
- Android SDK (API 34+ recommended, minSdkVersion 21+)
- Java 17 or Java 21

### Run Tests
```bash
# Run all unit and integration tests
flutter test
```

### Static Analysis
```bash
flutter analyze
```

### Build Android Debug APK
```bash
flutter build apk --debug
```
Output location:
`build/app/outputs/flutter-apk/app-debug.apk`

### Build Android Release APK
```bash
flutter build apk --release
```

---

## Relevant Upstream Licenses

- **sherpa-onnx**: Apache License 2.0 (Copyright 2022-2026 Xiaomi Corporation / Next-gen Kaldi development team).
- **PocketTTS**: [Kyutai Labs PocketTTS](https://github.com/kyutai-labs/pocket-tts). Model weights and ONNX export are released under Creative Commons Non-Commercial / Attribution licenses.
- **Reference Voice Samples**: `bria.wav` and `loona.wav` are distributed under Creative Commons Attribution licenses from Kyutai Labs / sherpa-onnx.
- **User Custom Voices**: Imported custom reference audio files remain 100% private to the user's device and are never uploaded.

---

## Known Limitations & Future Work

- **v1 Platform Target**: Android (ARM64 primary; x86_64 emulator supported).
- **Script Markup in v1**: Tagged blocks such as `[normal]` or `[excited]` are parsed and cleanly removed from synthesized audio to prevent reading them aloud. In a future update, tags will be mapped to specific emotion/style voice references or tempo settings.
- **Memory Footprint**: Running the INT8 model requires ~300–500 MB of RAM during synthesis. Recommended for devices with 4 GB+ RAM.
