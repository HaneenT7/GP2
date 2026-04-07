import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;

import '../services/pdf_text_extractor.dart';
import '../models/folder_file.dart';
import '../services/gemini_service.dart';
import 'quiz_page.dart';

class PdfViewerPage extends StatefulWidget {
  final FolderFile file;

  const PdfViewerPage({super.key, required this.file});

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  late WebViewController _webViewController;

  bool _isLoading = true;
  bool _isGeneratingQuiz = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    final pdfUrl = widget.file.fileUrl;

    final viewerUrl =
        'https://docs.google.com/viewer?url=${Uri.encodeComponent(pdfUrl)}&embedded=true';

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(viewerUrl));

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _generateQuizFromPdf() async {
    setState(() {
      _isGeneratingQuiz = true;
    });

    try {
      Uint8List pdfBytes;

      final pdfPath = widget.file.fileUrl;

      /// إذا كان الرابط من الإنترنت
      if (pdfPath.startsWith("http")) {
        final response = await http.get(Uri.parse(pdfPath));

        if (response.statusCode != 200) {
          throw Exception("Failed to download PDF");
        }

        pdfBytes = response.bodyBytes;
      }

      /// إذا كان ملف محلي
      else {
        final file = File(pdfPath);
        pdfBytes = await file.readAsBytes();
      }

      /// استخراج النص من PDF
      final extractedText = extractTextFromPdf(pdfBytes);

      final shortenedText = extractedText.length > 3000
          ? extractedText.substring(0, 3000)
          : extractedText;

      /// إرسال النص إلى Gemini لتوليد الكويز
      final quiz = await generateQuiz(shortenedText);

      if (!mounted) return;

      /// فتح صفحة الكويز
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuizPage(quiz: quiz),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error generating quiz: $e")),
      );
    }

    setState(() {
      _isGeneratingQuiz = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.file.fileName),
        actions: [
          IconButton(
            icon: const Icon(Icons.quiz),
            onPressed: _isGeneratingQuiz ? null : _generateQuizFromPdf,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : WebViewWidget(controller: _webViewController),
    );
  }
}