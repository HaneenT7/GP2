import 'dart:convert';
import 'package:http/http.dart' as http;

Future<List<dynamic>> generateQuiz(String text) async {
  const apiKey = "AIzaSyCnUQpxKOhjHmys-f1-c9CgZIcaCJ2ztPY";

  final url = Uri.parse(
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey",
  );

  final shortenedText =
      text.length > 3000 ? text.substring(0, 3000) : text;

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
              "text":
                  "Create 10 multiple choice questions from this text. "
                  "Return ONLY JSON in this format:\n"
                  "[{\"question\":\"\",\"options\":[\"\",\"\",\"\",\"\"],\"answer\":\"\"}]\n\n"
                  "$shortenedText"
            }
          ]
        }
      ]
    }),
  );

  final data = jsonDecode(response.body) as Map<String, dynamic>;

  // API returned an error (e.g. invalid key, rate limit, blocked content)
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

  // Some models wrap JSON in ```json ``` code fences; strip them if present.
  String textResponse = rawTextResponse.trim();
  if (textResponse.startsWith('```')) {
    // Remove first line with ``` or ```json
    final firstNewline = textResponse.indexOf('\n');
    if (firstNewline != -1) {
      textResponse = textResponse.substring(firstNewline + 1);
    }
    // Remove trailing ``` if present
    final lastFence = textResponse.lastIndexOf('```');
    if (lastFence != -1) {
      textResponse = textResponse.substring(0, lastFence);
    }
    textResponse = textResponse.trim();
  }

  final decoded = jsonDecode(textResponse);
  if (decoded is List) return decoded;
  if (decoded is Map && decoded['questions'] is List) {
    return decoded['questions'] as List<dynamic>;
  }
  return [];
}