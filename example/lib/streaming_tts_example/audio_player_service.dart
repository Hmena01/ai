import 'dart:async';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';

final _log = Logger('AudioPlayerService');

extension SoLoudWebExtension on SoLoud {
  Future<void> resumeAudioContextIfNeeded() async {
    if (kIsWeb) {
      try {
        // SoLoud handles web audio context management internally
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (e) {
        _log.info('Web audio context initialization completed');
      }
    }
  }
}

class AudioPlayerService {
  final SoLoud _soloud = SoLoud.instance;
  AudioSource? _audioStreamSource;
  SoundHandle? _activeSoundHandle;
  Completer<void>? _playbackCompleter;
  Timer? _endOfStreamCheckTimer;
  bool _isInitialized = false;
  bool _isInternalInitDone = false;

  bool get isPlaying {
    return _isInitialized &&
        _activeSoundHandle != null &&
        _soloud.getIsValidVoiceHandle(_activeSoundHandle!);
  }

  Future<void> initSoLoud() async {
    if (_isInternalInitDone && _isInitialized) {
      return;
    }

    try {
      await _soloud.init();
      _isInternalInitDone = true;
      _isInitialized = true;

      if (kIsWeb) {
        await _soloud.resumeAudioContextIfNeeded();
      }
    } catch (e) {
      _log.severe('Failed to initialize SoLoud: $e');
      _isInternalInitDone = false;
      _isInitialized = false;
      rethrow;
    }
  }

  Future<void> prepareStreamingPlayback() async {
    if (!_isInternalInitDone || !_isInitialized) {
      await initSoLoud();
    }

    if (kIsWeb) {
      await _soloud.resumeAudioContextIfNeeded();
      await Future.delayed(const Duration(milliseconds: 100));
    }

    await stopStreamingPlayback();
    _playbackCompleter = Completer<void>();

    try {
      if (_audioStreamSource != null) {
        try {
          _soloud.disposeSource(_audioStreamSource!);
        } catch (e) {
          // Ignore dispose errors
        }
        _audioStreamSource = null;
      }

      _audioStreamSource = _soloud.setBufferStream(
        sampleRate: 24000,
        channels: Channels.mono,
        format: BufferType.s16le,
        bufferingType: BufferingType.preserved,
      );

      if (_audioStreamSource == null) {
        throw Exception("Failed to create audio stream source");
      }

      _activeSoundHandle = await _soloud.play(
        _audioStreamSource!,
        paused: false,
        volume: 1.0,
      );
    } catch (e) {
      _clearPlaybackState(error: e);
      rethrow;
    }
  }

  Future<void> feedAudioChunk(Uint8List chunk) async {
    if (!_isInitialized ||
        _audioStreamSource == null ||
        _activeSoundHandle == null) {
      return;
    }

    try {
      bool isHandleValid = _soloud.getIsValidVoiceHandle(_activeSoundHandle!);
      if (!isHandleValid) {
        _clearPlaybackState(error: "Audio handle became invalid during feed");
        return;
      }
    } catch (e) {
      // Assume valid if we can't check
    }

    try {
      _soloud.addAudioDataStream(_audioStreamSource!, chunk);
    } catch (e) {
      _clearPlaybackState(error: e);
    }
  }

  Future<void> signalEndOfStream() async {
    _endOfStreamCheckTimer?.cancel();

    if (_audioStreamSource != null && _isInitialized) {
      try {
        _soloud.setDataIsEnded(_audioStreamSource!);
      } catch (e) {
        _log.warning("Error calling setDataIsEnded: $e");
      }
    }

    bool isHandleValid = false;
    try {
      isHandleValid =
          _activeSoundHandle != null &&
          _isInitialized &&
          _soloud.getIsValidVoiceHandle(_activeSoundHandle!);
    } catch (e) {
      isHandleValid = false;
    }

    if (isHandleValid) {
      final stopwatch = Stopwatch()..start();
      const checkInterval = Duration(milliseconds: 100);
      const maxWaitDuration = Duration(minutes: 5);
      int consecutiveInvalidChecks = 0;
      const maxConsecutiveInvalidChecks = 10;

      _log.info('Starting end-of-stream monitoring...');

      _endOfStreamCheckTimer = Timer.periodic(checkInterval, (timer) {
        bool isHandleCurrentlyValid = false;
        bool isHandleCurrentlyPlaying = false;

        try {
          isHandleCurrentlyValid =
              _activeSoundHandle != null &&
              _isInitialized &&
              _soloud.getIsValidVoiceHandle(_activeSoundHandle!);

          if (isHandleCurrentlyValid) {
            try {
              final voiceVolume = _soloud.getVolume(_activeSoundHandle!);
              isHandleCurrentlyPlaying = voiceVolume > 0;

              if (isHandleCurrentlyPlaying) {
                consecutiveInvalidChecks = 0;
              } else {
                consecutiveInvalidChecks++;
              }
            } catch (e) {
              consecutiveInvalidChecks++;
            }
          } else {
            consecutiveInvalidChecks++;
          }
        } catch (e) {
          consecutiveInvalidChecks++;
        }

        if (consecutiveInvalidChecks >= maxConsecutiveInvalidChecks ||
            stopwatch.elapsed > maxWaitDuration) {
          timer.cancel();
          stopwatch.stop();

          _log.info(
            'Audio playback completed after ${stopwatch.elapsed.inSeconds}s (invalid checks: $consecutiveInvalidChecks)',
          );

          if (_playbackCompleter != null && !_playbackCompleter!.isCompleted) {
            _playbackCompleter!.complete();
          }
          _clearPlaybackState();
        }
      });
    } else {
      if (_playbackCompleter != null && !_playbackCompleter!.isCompleted) {
        _playbackCompleter!.complete();
      }
      _clearPlaybackState();
    }
  }

  Future<void> stopStreamingPlayback() async {
    _endOfStreamCheckTimer?.cancel();

    bool isHandleValid = false;
    try {
      isHandleValid =
          _activeSoundHandle != null &&
          _isInitialized &&
          _soloud.getIsValidVoiceHandle(_activeSoundHandle!);
    } catch (e) {
      isHandleValid = false;
    }

    if (isHandleValid) {
      try {
        _soloud.stop(_activeSoundHandle!);
      } catch (e) {
        // Ignore stop errors
      }
    }

    _clearPlaybackState();
  }

  void _clearPlaybackState({dynamic error}) {
    _endOfStreamCheckTimer?.cancel();
    _endOfStreamCheckTimer = null;

    if (_activeSoundHandle != null) {
      bool isHandleValid = false;
      try {
        isHandleValid =
            _isInitialized &&
            _soloud.getIsValidVoiceHandle(_activeSoundHandle!);
      } catch (e) {
        isHandleValid = false;
      }

      if (isHandleValid) {
        try {
          _soloud.stop(_activeSoundHandle!);
        } catch (e) {
          // Ignore stop errors
        }
      }
      _activeSoundHandle = null;
    }

    if (_audioStreamSource != null) {
      if (_isInitialized && _isInternalInitDone) {
        try {
          _soloud.disposeSource(_audioStreamSource!);
        } catch (e) {
          // Ignore dispose errors
        }
      }
      _audioStreamSource = null;
    }

    if (_playbackCompleter != null && !_playbackCompleter!.isCompleted) {
      if (error != null) {
        _playbackCompleter!.completeError(error);
      } else {
        _playbackCompleter!.complete();
      }
    }
    _playbackCompleter = null;
  }

  Future<void>? get playbackCompletion => _playbackCompleter?.future;

  void dispose() {
    stopStreamingPlayback();
    _isInitialized = false;
    _isInternalInitDone = false;
  }
}
