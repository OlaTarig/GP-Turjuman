# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Turjuman** is a Flutter app that bridges communication between deaf and hearing users via:
- Real-time Arabic Sign Language (ArSL) recognition from camera (on-device TFLite TCN model)
- Speech-to-text captioning during video meetings (Google Speech API)
- WebRTC video conferencing (Zego SDK)
- PDF transcript export

## Common Commands

```bash
flutter pub get                # Install/sync dependencies
flutter run                    # Run on connected device/emulator
flutter build apk              # Build release APK
flutter test                   # Run all tests
flutter test test/widget_test.dart  # Run a single test file
flutter analyze                # Static analysis
flutterfire configure          # Reconfigure Firebase (Android)
```

## Architecture

The app follows a **Models → Controllers → Views** pattern with a hybrid state management approach.

### State Management
- **ChangeNotifier + Provider**: Controllers extend `ChangeNotifier` and are consumed via `Provider` in views
- **Singletons**: `MeetingSessionManager` and `CaptionController` are singletons that coordinate cross-screen state
- **Firestore real-time listeners**: Views subscribe directly to Firestore streams for live meeting state (captions, screen-share permissions, active status)
- **Firebase Auth stream**: `AuthService` exposes `authStateChanges` for the login/logout router in `GUI.dart`
- **`setState()`**: Used in views for purely local UI state (loading indicators, tab indices)

### Key Controllers
| Controller | Role |
|---|---|
| `MeetingSessionManager` | Singleton orchestrator — starts/stops the entire meeting lifecycle, coordinates all other controllers |
| `ZegoSessionController` | WebRTC via Zego SDK — video/audio streams, screen sharing |
| `SignCaptioningController` | Sign recognition pipeline: camera frames → MediaPipe keypoints → TFLite TCN → Arabic sign label |
| `CaptionController` | Singleton — receives sign labels and speech-to-text results, writes caption entries to Firestore |
| `MeetingController` | Firestore CRUD for the `Meetings` collection |
| `FileTranscriptionController` | Generates and exports PDF transcripts from caption entries |

### Sign Recognition Pipeline
Manual-trigger: user presses "Sign" button → 3-second countdown → capture 48 frames → infer → show top-5.

1. **Native MediaPipe** (`SignRecognitionChannel.kt`, MethodChannel `com.example.turjuman/sign_recognition`): NV21 frame → PoseLandmarker + HandLandmarker → 225-float normalized keypoints returned to Dart
2. **Dart buffering** (`SignCaptioningController`): collects 48 frames during `CaptureState.capturing`
3. **TFLite inference**: `assets/model/tcn_48_clean_final.tflite`, input `[1,48,225]`, output `[1,N]`
4. **Label lookup**: `le_48_clean_final.json` (model-output-index → original-class-index) → `label_mapping.json` (original-index → Arabic word)
5. **UI**: top-1 chip overlay; tap to expand top-5 panel in `MeetingView`

**Required before first build:**
- Download `pose_landmarker_full.task` and `hand_landmarker.task` into `android/app/src/main/assets/` (see the README txt file there for URLs)
- Convert `assets/model/le_48_clean_final.npy` → `le_48_clean_final.json`:
  ```python
  import numpy as np, json
  json.dump(np.load('le_48_clean_final.npy', allow_pickle=True).tolist(),
            open('assets/model/le_48_clean_final.json','w'))
  ```

### Firestore Schema
- `/User/{userId}` — user profile & accessibility settings (`UserModel`)
- `/Meetings/{meetingId}` — meeting metadata, participant list, `isActive`, `screenShareAllowed` (`MeetingModel`)
- `/captionsFileTranscription/{docId}` — caption entries with timestamp/speaker, transcript files (`CaptionsAndTranscriptionModel`)

### Deep Links
Invitation links are handled by `deep_link_service.dart` (using `app_links` package). The `main.dart` sets up a navigator key and routes cold-start and warm-start deep links to `JoinMeetingView`.

## Key External Integrations
- **Firebase**: Auth, Firestore, Storage, Hosting
- **Zego SDK** (`zego_express_engine`): WebRTC backend — AppID/AppSign are in `ZegoSessionController`
- **Google Speech-to-Text**: Credentials at `assets/google_speech_credentials.json`
- **TensorFlow Lite**: Sign recognition model at `assets/model/tcn_48_clean_final.tflite`
- **MediaPipe Tasks Vision**: `SignRecognitionChannel.kt` uses `PoseLandmarker` + `HandLandmarker`; model files in `android/app/src/main/assets/`

## Android Configuration
- `minSdk = 24` (required by MediaPipe Tasks Vision), `targetSdk` from Flutter default
- Google Services plugin required (`google-services.json` in `android/app/`)
- Permissions needed: camera, microphone, internet, storage (handled at runtime via `SettingsController` using `permission_handler`)


