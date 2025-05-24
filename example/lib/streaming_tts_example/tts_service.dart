import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'audio_player_service.dart';
import 'package:logging/logging.dart';

final _log = Logger('TtsService');

/// Google Cloud Text-to-Speech Service
///
/// Provides streaming text-to-speech functionality using Google Cloud TTS API
/// with optimized audio playback through SoLoud.
class TtsService {
  final AudioPlayerService _audioPlayerService;
  final String _apiKey;
  final http.Client _client;

  StreamSubscription<List<int>>? _currentStreamSubscription;
  bool _isSpeaking = false;
  int _chunkCount = 0;

  bool get isSpeaking => _isSpeaking;

  TtsService(this._audioPlayerService)
    : _apiKey = dotenv.env['GOOGLE_CLOUD_API_KEY'] ?? '',
      _client = http.Client() {
    if (_apiKey.isEmpty) {
      _log.severe('''
=== GOOGLE CLOUD API KEY MISSING ===
Please create a .env file in the project root with:
GOOGLE_CLOUD_API_KEY=your_api_key_here

Get your API key from: https://cloud.google.com/text-to-speech
Free tier: 1M characters/month for standard voices!
===================================''');
    }
  }

  Future<void> speakStream(String text, String voiceLanguageCode) async {
    if (_apiKey.isEmpty) {
      _log.severe('Error: Google Cloud API key is missing. Cannot speak.');
      throw Exception(
        'Google Cloud API key is not configured. Please check your .env file.',
      );
    }
    if (text.trim().isEmpty) {
      _log.warning('Warning: Attempted to speak empty text.');
      return;
    }

    await stopCurrentStream();
    _isSpeaking = true;
    _chunkCount = 0;

    await _audioPlayerService.prepareStreamingPlayback();

    final url = Uri.parse(
      'https://texttospeech.googleapis.com/v1/text:synthesize?key=$_apiKey',
    );

    final headers = {'Content-Type': 'application/json'};

    final body = jsonEncode({
      'input': {'text': text},
      'voice': {
        'languageCode':
            voiceLanguageCode.isNotEmpty ? voiceLanguageCode : 'en-US',
        'name': _getVoiceName(
          voiceLanguageCode.isNotEmpty ? voiceLanguageCode : 'en-US',
        ),
      },
      'audioConfig': {
        'audioEncoding': 'LINEAR16',
        'sampleRateHertz': 22050,
        'speakingRate': 1.3,
        'effectsProfileId': ['headphone-class-device'],
      },
    });

    try {
      final response = await _client
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final audioContent = responseData['audioContent'];

        if (audioContent != null) {
          final audioBytes = base64Decode(audioContent);
          _streamAudioData(audioBytes);
        } else {
          throw Exception('No audio content received from Google TTS');
        }
      } else {
        String errorMessage = 'Google TTS API Error: ${response.statusCode}';
        try {
          final errorBody = response.body;
          _log.severe('Error Body: $errorBody');

          if (response.statusCode == 401) {
            errorMessage =
                'Google Cloud API Authentication Failed (401). Please check your API key in the .env file.';
          } else if (response.statusCode == 403) {
            errorMessage =
                'Google Cloud API Access Forbidden (403). Check your API key permissions.';
          } else if (response.statusCode == 429) {
            errorMessage =
                'Google Cloud API Rate Limit Exceeded (429). Please try again later.';
          } else {
            errorMessage =
                'Google TTS API Error: ${response.statusCode} - $errorBody';
          }
        } catch (e) {
          _log.severe('Failed to read error body: $e');
        }

        _log.severe(errorMessage);
        _isSpeaking = false;
        await _audioPlayerService.stopStreamingPlayback();
        throw Exception(errorMessage);
      }
    } catch (e, s) {
      _log.severe('Error sending TTS request or processing stream: $e', e, s);
      _isSpeaking = false;
      await _audioPlayerService.stopStreamingPlayback();
      rethrow;
    }
  }

  String _getVoiceName(String languageCode) {
    switch (languageCode.toLowerCase()) {
      case 'en-us':
        return 'en-US-Studio-Q';
      case 'en-gb':
        return 'en-GB-Neural2-A';
      case 'fr-fr':
        return 'fr-FR-Neural2-A';
      case 'de-de':
        return 'de-DE-Neural2-A';
      case 'es-es':
        return 'es-ES-Neural2-A';
      case 'it-it':
        return 'it-IT-Neural2-A';
      case 'pt-br':
        return 'pt-BR-Neural2-A';
      case 'ja-jp':
        return 'ja-JP-Neural2-A';
      case 'ko-kr':
        return 'ko-KR-Neural2-A';
      default:
        return 'en-US-Studio-Q';
    }
  }

  void _streamAudioData(Uint8List audioData) {
    const chunkSize = 8192;
    int offset = 0;
    final totalChunks = (audioData.length / chunkSize).ceil();

    _log.info(
      'Starting audio stream: ${audioData.length} bytes, $totalChunks chunks expected',
    );

    Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (!_isSpeaking) {
        timer.cancel();
        return;
      }

      if (offset >= audioData.length) {
        timer.cancel();
        _log.info(
          'TTS stream completed: $_chunkCount/$totalChunks chunks sent, ${audioData.length} total bytes',
        );

        Future.delayed(const Duration(milliseconds: 500), () {
          if (_isSpeaking) {
            _log.info('Signaling end of stream...');
            _audioPlayerService.signalEndOfStream().then((_) {
              _audioPlayerService.playbackCompletion
                  ?.then((_) {
                    _log.info('Audio playback fully completed');
                    _isSpeaking = false;
                  })
                  .catchError((e) {
                    _log.warning('Audio playback completion error: $e');
                    _isSpeaking = false;
                  });
            });
          }
        });
        return;
      }

      final endOffset =
          (offset + chunkSize < audioData.length)
              ? offset + chunkSize
              : audioData.length;

      final chunk = audioData.sublist(offset, endOffset);
      offset = endOffset;
      _chunkCount++;

      if (_chunkCount == 1 || _chunkCount % 20 == 0) {
        _log.info('Processing chunk #$_chunkCount (${chunk.length} bytes)');
      }

      _audioPlayerService.feedAudioChunk(chunk);
    });
  }

  Future<void> stopCurrentStream() async {
    if (_currentStreamSubscription != null) {
      await _currentStreamSubscription!.cancel();
      _currentStreamSubscription = null;
    }
    _isSpeaking = false;
    await _audioPlayerService.stopStreamingPlayback();
  }

  void dispose() {
    _client.close();
    stopCurrentStream();
  }

  Future<bool> verifyApiKey() async {
    if (_apiKey.isEmpty) {
      _log.severe('Error: Google Cloud API key is missing. Cannot verify.');
      return false;
    }

    try {
      final url = Uri.parse(
        'https://texttospeech.googleapis.com/v1/text:synthesize?key=$_apiKey',
      );

      final headers = {'Content-Type': 'application/json'};

      final body = jsonEncode({
        'input': {'text': 'test'},
        'voice': {'languageCode': 'en-US', 'name': 'en-US-Standard-A'},
        'audioConfig': {'audioEncoding': 'LINEAR16'},
      });

      final response = await _client.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        return true;
      } else {
        _log.severe(
          'API key verification failed. Status: ${response.statusCode}',
        );
        return false;
      }
    } catch (e, s) {
      _log.severe('Error verifying API key: $e', e, s);
      return false;
    }
  }
}
