# Flutter AI Streaming TTS Setup Guide

This Flutter web application demonstrates streaming text-to-speech using Google Cloud Text-to-Speech API and SoLoud audio playback.

## Setup Instructions

### 1. Google Cloud TTS API Key Setup

1. **Get your API key:**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project or select an existing one
   - Enable the Text-to-Speech API
   - Go to APIs & Services > Credentials
   - Create an API key (restrict it to Text-to-Speech API for security)

2. **Create a .env file:**
   ```bash
   # In the example/ directory, create a file named .env
   touch .env
   ```

3. **Add your API key to the .env file:**
   ```env
   GOOGLE_CLOUD_API_KEY=your_actual_api_key_here
   ```

### 2. Running the Application

1. **Install dependencies:**
   ```bash
   flutter pub get
   ```

2. **Run on web (recommended for this example):**
   ```bash
   flutter run -d chrome
   ```

   Or use the TTS-specific entry point:
   ```bash
   flutter run -d chrome -t lib/streaming_tts_example/main_tts.dart
   ```

### 3. Audio Permissions

- **Web browsers require user interaction** before audio can play
- Click anywhere on the page or interact with the UI before trying to play audio
- This is a browser security requirement and cannot be bypassed

### 4. Pricing & Free Tier

Google Cloud Text-to-Speech offers generous free usage:
- **1 million characters per month** for Standard voices (FREE)
- **100,000 characters per month** for WaveNet voices (FREE)
- After free tier: Very affordable per-character pricing
- Much more cost-effective than most alternatives

### 5. Troubleshooting

#### "401 API Authentication Failed"
- Check that your .env file exists in the example/ directory
- Verify your Google Cloud API key is correct
- Ensure the Text-to-Speech API is enabled in your project
- Ensure the .env file format is exactly: `GOOGLE_CLOUD_API_KEY=your_key_here`

#### "AudioContext was not allowed to start"
- This is normal - click somewhere on the page first
- The app will automatically resume audio after user interaction

#### "Module_soloud._isInited is not a function"
- This typically resolves after proper user interaction
- Try refreshing the page and clicking before attempting audio playback

#### "Stories cut off before finishing"
- Fixed in latest version with improved completion detection
- Long stories now supported with 5-minute playback monitoring
- 60-second API timeout for full story generation

### 6. File Structure

```
example/
├── .env                          # Your API key (create this)
├── lib/
│   └── streaming_tts_example/
│       ├── main_tts.dart         # Main TTS app entry point
│       ├── audio_player_service.dart
│       ├── tts_service.dart      # Google Cloud TTS service
│       └── chat_page_with_tts.dart
└── web/
    ├── index.html                # Includes SoLoud scripts
    └── flutter_bootstrap.js      # Audio context handling
```

### 7. Features

- Streaming text-to-speech from Google Cloud TTS
- Real-time audio playback with SoLoud
- Web audio context management
- Error handling and user feedback
- Flutter web compatibility
- Multiple language support
- Optimized for speed and reliability

### 8. Voice Options & Speed

The app automatically selects high-quality voices for optimal performance:

- **English (US)**: Studio-Q (ultra-fast studio voice)
- **English (UK)**: Neural2-A (optimized for speed)
- **French**: Neural2-A (fast processing)
- **German**: Neural2-A 
- **Spanish**: Neural2-A
- **Italian**: Neural2-A
- **Portuguese (Brazil)**: Neural2-A
- **Japanese**: Neural2-A
- **Korean**: Neural2-A

**Speed Optimizations Applied:**
- Fast voices: Neural2 and Studio voices for low latency
- Streaming: 8KB chunks every 20ms for reliable delivery
- Enhanced speech rate: 1.3x speaking rate for quicker responses
- Smart audio config: 22kHz sample rate, headphone optimization
- Extended timeouts: 60-second API response for long content

To change the language, modify `googleTtsLanguageCode` in `chat_page_with_tts.dart`.

### 9. Notes

- This example is optimized for web browsers
- Audio streaming requires a stable internet connection
- Google Cloud TTS usage counts towards your free tier/quota
- The app handles audio context suspension/resumption automatically
- Optimized for speed and cost-effectiveness 