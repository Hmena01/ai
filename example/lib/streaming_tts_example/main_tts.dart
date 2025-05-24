import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';
import 'dart:developer' as dev;
import 'package:flutter_soloud/flutter_soloud.dart';

import 'chat_page_with_tts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // Log error loading .env file - this is expected if no .env file exists
    Logger('MainTTS').info('No .env file found or error loading: $e');
  }

  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    dev.log(
      record.message,
      time: record.time,
      level: record.level.value,
      name: record.loggerName,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  });

  final log = Logger('MainTTS');

  // Initialize SoLoud asynchronously without blocking app startup
  // This prevents white screen issues
  Future.delayed(const Duration(milliseconds: 100), () async {
    try {
      if (!SoLoud.instance.isInitialized) {
        await SoLoud.instance.init();
        log.info("SoLoud initialized successfully");
      } else {
        log.info("SoLoud was already initialized");
      }
    } catch (e) {
      log.severe("Failed to initialize SoLoud: $e");
      log.info("Audio features will be initialized when needed");
    }
  });

  // Start the app immediately without waiting for audio initialization
  runApp(const StreamingTtsApp());
}

class StreamingTtsApp extends StatelessWidget {
  const StreamingTtsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter AI Streaming TTS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurpleAccent),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurpleAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const ChatPageWithTts(title: 'AI Chat with Streaming TTS'),
      debugShowCheckedModeBanner: false,
    );
  }
}
