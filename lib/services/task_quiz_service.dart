import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// TaskQuizService generates a quiz for a specific revision task.
/// Instead of uploading a PDF, we provide task context (title, subject, topic)
/// to Gemini to generate relevant quiz questions.
class TaskQuizService {
  /// Generate a quiz based on task context.
  /// 
  /// Parameters:
  /// - taskTitle: The task name (e.g., "Revise Chapter 9")
  /// - subject: The subject/course (e.g., "Math 106")
  /// - topic: Optional topic description or pages (e.g., "Chapter 9, pages 45-67")
  /// - materialTitle: The material/file name for additional context
  static Future<List<dynamic>> generateTaskQuiz({
    required String taskTitle,
    required String subject,
    String? topic,
    String? materialTitle,
  }) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? 'Key not found';

    final url = Uri.parse(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey",
    );

    // Build context string from task information
    final context = _buildContextFromTask(
      taskTitle: taskTitle,
      subject: subject,
      topic: topic,
      materialTitle: materialTitle,
    );

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {
                "text": "Create 10 multiple choice questions for this study task. "
                    "Return ONLY JSON in this format:\n"
                    "[{\"question\":\"\",\"options\":[\"\",\"\",\"\",\"\"],\"answer\":\"\"}]\n\n"
                    "Context: $context"
              }
            ]
          }
        ]
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    // API returned an error
    if (data.containsKey('error')) {
      final err = data['error'] as Map<String, dynamic>?;
      final message = err?['message']?.toString() ?? response.body;
      throw Exception('Gemini API error: $message');
    }

    if (response.statusCode != 200) {
      throw Exception('Request failed: ${response.statusCode}');
    }

    final candidates = data['candidates'];
    if (candidates == null || candidates is! List || candidates.isEmpty) {
      throw Exception('No quiz content from Gemini. Try again.');
    }

    final first = candidates[0] as Map<String, dynamic>?;
    final content = first?['content'];
    if (content == null || content is! Map<String, dynamic>) {
      throw Exception('Invalid response from Gemini. Try again.');
    }

    final parts = content['parts'];
    if (parts == null || parts is! List || parts.isEmpty) {
      throw Exception('No quiz text from Gemini. Try again.');
    }

    final textPart = parts[0] as Map<String, dynamic>?;
    final rawTextResponse = textPart?['text']?.toString();
    if (rawTextResponse == null || rawTextResponse.isEmpty) {
      throw Exception('Empty quiz from Gemini. Try again.');
    }

    // Strip markdown code fences if present
    String textResponse = rawTextResponse.trim();
    if (textResponse.startsWith('```')) {
      final firstNewline = textResponse.indexOf('\n');
      if (firstNewline != -1) {
        textResponse = textResponse.substring(firstNewline + 1);
      }
      if (textResponse.endsWith('```')) {
        textResponse = textResponse.substring(0, textResponse.length - 3);
      }
    }

    final quiz = jsonDecode(textResponse);
    if (quiz is! List || quiz.isEmpty) {
      throw Exception('Empty quiz from Gemini. Try again.');
    }

    return quiz;
  }

  /// Build a natural language context string from task information
  /// This helps Gemini understand what kind of questions to generate
  static String _buildContextFromTask({
    required String taskTitle,
    required String subject,
    String? topic,
    String? materialTitle,
  }) {
    final parts = [
      'Task: $taskTitle',
      'Subject: $subject',
    ];

    if (topic != null && topic.isNotEmpty) {
      parts.add('Topic/Pages: $topic');
    }

    if (materialTitle != null && materialTitle.isNotEmpty) {
      parts.add('Material: $materialTitle');
    }

    return parts.join('\n');
  }
}
