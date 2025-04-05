import 'dart:io';

import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../utils/logger.dart';

part 'transcription_service.g.dart';

@riverpod
TranscriptionService transcriptionService(TranscriptionServiceRef ref) {
  return TranscriptionService();
}

/// Service responsible for handling audio transcription.
class TranscriptionService {
  final String _openaiApiKey =
      "YOUR_OPENAI_API_KEY"; // IMPORTANT: Securely manage API keys!

  /// Transcribes the audio file at the given path.
  /// Returns the transcript text or null if transcription fails.
  Future<String?> transcribeAudioFile(String filePath) async {
    logger.info('TranscriptionService: Starting transcription for $filePath');

    // TODO: Implement local Whisper.cpp integration for macOS/Android

    // --- Placeholder: OpenAI Whisper API --- //
    // IMPORTANT: Requires user consent and secure API key management.
    // This is a basic example and lacks proper error handling, retries, etc.

    if (_openaiApiKey == "YOUR_OPENAI_API_KEY" || _openaiApiKey.isEmpty) {
      logger.warning(
        'TranscriptionService: OpenAI API Key not set. Skipping API transcription.',
      );
      return "[Transcription via API requires API Key]"; // Placeholder message
    }

    File audioFile = File(filePath);
    if (!await audioFile.exists()) {
      logger.error('TranscriptionService: Audio file not found at $filePath');
      return null;
    }

    // 1. (Optional) Convert audio file to a format supported by Whisper API (e.g., mp3, wav)
    //    Using ffmpeg_kit_flutter
    // String convertedFilePath = await _convertToMp3(filePath); // Example
    // if (convertedFilePath == null) return null;
    // File fileToSend = File(convertedFilePath);

    // Using original file for now, assuming it's compatible (e.g., AAC might work)
    File fileToSend = audioFile;

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.openai.com/v1/audio/transcriptions'),
      );
      request.headers['Authorization'] = 'Bearer $_openaiApiKey';
      request.fields['model'] = 'whisper-1'; // Specify the model
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          fileToSend.path,
          // filename: p.basename(fileToSend.path), // Optional: provide filename
        ),
      );

      logger.info(
        'TranscriptionService: Sending request to OpenAI Whisper API...',
      );
      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        // Parse the response (assuming JSON with a 'text' field)
        // import 'dart:convert';
        // final decoded = jsonDecode(responseBody);
        // final transcript = decoded['text'] as String?;
        logger.info(
          'TranscriptionService: Received successful response from API.',
        );
        // logger.info('Transcript: $transcript');
        // return transcript ?? "[API returned empty text]";
        return responseBody; // For now, return raw response for debugging
      } else {
        logger.error(
          'TranscriptionService: OpenAI API request failed with status ${response.statusCode}: $responseBody',
        );
        return "[API Error: ${response.statusCode}]";
      }
    } catch (e, stack) {
      logger.error(
        'TranscriptionService: Error calling OpenAI API',
        error: e,
        stackTrace: stack,
      );
      return "[Network/Request Error]";
    }
    // --- End Placeholder --- //
  }

  // Example conversion function using ffmpeg_kit_flutter
  Future<String?> _convertToMp3(String inputPath) async {
    final outputPath =
        '${inputPath.substring(0, inputPath.lastIndexOf('.'))}.mp3';
    logger.info('Attempting to convert $inputPath to $outputPath');
    final command =
        '-i "$inputPath" -vn -acodec libmp3lame -q:a 2 "$outputPath" -y'; // -y overwrites

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      logger.info('FFmpeg conversion successful: $outputPath');
      // Optionally delete the original file after conversion
      // await File(inputPath).delete();
      return outputPath;
    } else {
      logger.error('FFmpeg conversion failed. Return code: $returnCode');
      final logs = await session.getLogsAsString();
      logger.error('FFmpeg logs: $logs');
      return null;
    }
  }
}
