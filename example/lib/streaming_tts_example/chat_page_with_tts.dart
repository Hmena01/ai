import 'package:flutter/material.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'audio_player_service.dart';
import 'tts_service.dart';
import 'llm_provider_setup_tts.dart';
import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

final _log = Logger('ChatPageWithTts');

class ChatPageWithTts extends StatefulWidget {
  const ChatPageWithTts({super.key, required this.title});
  final String title;

  @override
  State<ChatPageWithTts> createState() => _ChatPageWithTtsState();
}

class _ChatPageWithTtsState extends State<ChatPageWithTts> {
  late final LlmProvider llmProvider;
  late final AudioPlayerService audioPlayerService;
  late final TtsService ttsService;

  int? _lastSpokenLlmMessageContentHash;
  bool _audioContextResumed = false;

  static const String googleTtsLanguageCode = "en-US";

  @override
  void initState() {
    super.initState();

    try {
      llmProvider = createGeminiProviderForTts();
    } catch (e, s) {
      _log.severe("Failed to create LLM Provider: $e", e, s);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("LLM Provider Error: $e. Check API Key."),
              duration: Duration(seconds: 10),
            ),
          );
        }
      });
      throw Exception("LLM Provider could not be initialized.");
    }

    audioPlayerService = AudioPlayerService();
    ttsService = TtsService(audioPlayerService);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Initialize audio asynchronously without blocking UI
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            audioPlayerService
                .initSoLoud()
                .then((_) {
                  if (mounted) {
                    _log.info("Audio service initialized successfully");
                  }
                })
                .catchError((e) {
                  _log.warning(
                    "Audio initialization delayed, will retry when needed: $e",
                  );
                  // Don't show error to user immediately, TTS will handle initialization when needed
                });
          }
        });
      }
    });

    llmProvider.addListener(_handleLlmUpdate);
  }

  @override
  void dispose() {
    llmProvider.removeListener(_handleLlmUpdate);
    if (llmProvider is ChangeNotifier) {
      (llmProvider as ChangeNotifier).dispose();
    }
    ttsService.dispose();
    audioPlayerService.dispose();
    super.dispose();
  }

  /// Speak text with proper error handling and user feedback
  Future<void> _speakWithErrorHandling(String text, int messageHash) async {
    try {
      await ttsService.speakStream(text, googleTtsLanguageCode);
      _lastSpokenLlmMessageContentHash = messageHash;
    } catch (e, s) {
      _log.severe("TTS Error: $e", e, s);
      if (mounted) {
        String userMessage = "Speech synthesis failed";
        if (e.toString().contains('API key')) {
          userMessage =
              "Please configure your Google Cloud API key in the .env file";
        } else if (e.toString().contains('401')) {
          userMessage =
              "Invalid Google Cloud API key. Please check your .env file";
        } else if (e.toString().contains('429')) {
          userMessage =
              "Google Cloud API rate limit exceeded. Please try again later";
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _resumeAudioContextIfNeeded() async {
    if (kIsWeb && !_audioContextResumed) {
      try {
        _audioContextResumed = true;
        await SoLoud.instance.resumeAudioContextIfNeeded();

        // SoLoud handles web audio context management internally
      } catch (e) {
        // Continue anyway, audio might still work
      }
    }
  }

  void _handleLlmUpdate() {
    final history = llmProvider.history;
    if (history.isEmpty) {
      return;
    }

    final lastMessage = history.last;

    if (lastMessage.origin == MessageOrigin.llm) {
      final llmText = lastMessage.text;

      if (llmText != null && llmText.trim().isNotEmpty) {
        final currentMessageContentHash = llmText.trim().hashCode;

        if (currentMessageContentHash != _lastSpokenLlmMessageContentHash) {
          ttsService.stopCurrentStream().then((_) {
            if (mounted && llmText.trim().isNotEmpty) {
              if (kIsWeb) {
                _resumeAudioContextIfNeeded().then((_) {
                  if (mounted) {
                    _speakWithErrorHandling(
                      llmText.trim(),
                      currentMessageContentHash,
                    );
                  }
                });
              } else {
                _speakWithErrorHandling(
                  llmText.trim(),
                  currentMessageContentHash,
                );
              }
            }
          });
        }
      } else {
        if (llmText == null || llmText.trim().isEmpty) {
          _lastSpokenLlmMessageContentHash = null;
        }
      }
    }
  }

  Stream<String> _sendMessage(
    String message, {
    Iterable<Attachment>? attachments,
  }) async* {
    await _resumeAudioContextIfNeeded();

    yield* llmProvider.sendMessageStream(
      message,
      attachments: attachments ?? [],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(
              ttsService.isSpeaking
                  ? Icons.stop_circle_outlined
                  : Icons.play_circle_outline,
            ),
            tooltip: ttsService.isSpeaking ? "Stop TTS" : "TTS Idle",
            onPressed: () async {
              await _resumeAudioContextIfNeeded();

              if (ttsService.isSpeaking) {
                await ttsService.stopCurrentStream();
                _lastSpokenLlmMessageContentHash = null;
              }
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () async {
          await _resumeAudioContextIfNeeded();
        },
        behavior: HitTestBehavior.translucent,
        child: LlmChatView(
          provider: llmProvider,
          welcomeMessage: 'Hello! I will speak the LLM responses.',
          suggestions: const [
            'Tell me a short story.',
            'What is the capital of France?',
            'Explain quantum computing simply.',
          ],
          messageSender: _sendMessage,
        ),
      ),
    );
  }
}
