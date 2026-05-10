import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/folder_file.dart';
import '../services/gemini_service.dart';
import '../services/pdf_text_extractor.dart';
import 'quiz_page.dart';

class PdfViewerPage extends StatefulWidget {
  final FolderFile file;

  const PdfViewerPage({super.key, required this.file});

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  late final Future<Uint8List> _pdfBytesFuture;

  bool _isGeneratingQuiz = false;

  @override
  void initState() {
    super.initState();
    _pdfBytesFuture = _loadPdfBytes();
  }

  Future<Uint8List> _loadPdfBytes() async {
    final pathOrUrl = widget.file.fileUrl;
    if (pathOrUrl.startsWith('http')) {
      final response = await http.get(Uri.parse(pathOrUrl));
      if (response.statusCode != 200) {
        throw Exception(
          'Could not download file (HTTP ${response.statusCode})',
        );
      }
      return response.bodyBytes;
    }
    if (kIsWeb) {
      throw Exception('Local file paths are not supported on web.');
    }
    final file = File(pathOrUrl);
    if (!await file.exists()) {
      throw Exception('File not found.');
    }
    return file.readAsBytes();
  }

  Future<void> _openExternally() async {
    final uri = Uri.parse(widget.file.fileUrl);
    if (!await canLaunchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this link')),
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _generateQuizFromPdf() async {
    setState(() {
      _isGeneratingQuiz = true;
    });

    try {
      Uint8List pdfBytes;

      final pdfPath = widget.file.fileUrl;

      if (pdfPath.startsWith('http')) {
        final response = await http.get(Uri.parse(pdfPath));

        if (response.statusCode != 200) {
          throw Exception('Failed to download PDF');
        }

        pdfBytes = response.bodyBytes;
      } else {
        final file = File(pdfPath);
        pdfBytes = await file.readAsBytes();
      }

      final extractedText = extractTextFromPdf(pdfBytes);

      final shortenedText = extractedText.length > 3000
          ? extractedText.substring(0, 3000)
          : extractedText;

      final quiz = await generateQuiz(shortenedText);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuizPage(
            quiz: quiz,
            onExit: () => Navigator.pop(context),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating quiz: $e')),
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
        title: Text(
          widget.file.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (widget.file.fileUrl.startsWith('http'))
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Open in browser',
              onPressed: _openExternally,
            ),
          IconButton(
            icon: const Icon(Icons.quiz),
            onPressed: _isGeneratingQuiz ? null : _generateQuizFromPdf,
          ),
        ],
      ),
      body: FutureBuilder<Uint8List>(
        future: _pdfBytesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Could not load this PDF',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    if (widget.file.fileUrl.startsWith('http')) ...[
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _openExternally,
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Open in browser'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }
          final bytes = snapshot.data!;
          return SfPdfViewer.memory(
            bytes,
            enableTextSelection: false,
            canShowHyperlinkDialog: false,
            enableHyperlinkNavigation: false,
            canShowSignaturePadDialog: false,
          );
        },
      ),
    );
  }
}
