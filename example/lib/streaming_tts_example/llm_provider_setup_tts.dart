import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as gen_ai;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';

final _log = Logger('LlmProviderSetupTts');

LlmProvider createGeminiProviderForTts() {
  final apiKey = dotenv.env['GEMINI_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    final errorMessage =
        'GEMINI_API_KEY not found in .env file for streaming_tts_example.';
    _log.severe(errorMessage);
    throw Exception(errorMessage);
  }
  _log.info("Gemini API Key loaded for streaming_tts_example.");

  final model = gen_ai.GenerativeModel(
    model:
        'gemini-1.5-flash-latest', // Using -latest is generally a good practice
    apiKey: apiKey,
    // safetySettings: [ // Optional: Configure safety settings if needed
    //   gen_ai.SafetySetting(gen_ai.HarmCategory.harassment, gen_ai.HarmBlockThreshold.blockNone),
    //   gen_ai.SafetySetting(gen_ai.HarmCategory.hateSpeech, gen_ai.HarmBlockThreshold.blockNone),
    // ],
  );

  return GeminiProvider(model: model);
}
