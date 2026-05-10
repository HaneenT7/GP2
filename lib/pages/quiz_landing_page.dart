import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../services/pdf_text_extractor.dart';
import '../services/gemini_service.dart';
import 'quiz_page.dart';

class QuizLandingPage extends StatefulWidget {
  const QuizLandingPage({super.key});

  @override
  State<QuizLandingPage> createState() => _QuizLandingPageState();
}

class _QuizLandingPageState extends State<QuizLandingPage> {
  String? _selectedQuizFileName;
  Uint8List? _selectedQuizFileBytes;
  bool _isGeneratingQuiz = false;
  List? _generatedQuiz;

  Future<void> _pickQuizFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes != null && bytes.isNotEmpty) {
        setState(() {
          _selectedQuizFileName = file.name;
          _selectedQuizFileBytes = bytes;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read file. Please try again.')),
        );
      }
    }
  }

  Future<void> _startQuizFromPdf() async {
    final bytes = _selectedQuizFileBytes;
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a PDF file first.')));
      return;
    }
    setState(() => _isGeneratingQuiz = true);
    try {
      final extractedText = extractTextFromPdf(bytes);
      if (extractedText.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not extract text from this PDF.')));
        return;
      }
      final shortenedText = extractedText.length > 3000 ? extractedText.substring(0, 3000) : extractedText;
      final quiz = await generateQuiz(shortenedText);
      if (quiz.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not generate quiz.')));
        return;
      }
      if (!mounted) return;
      
      setState(() {
        _generatedQuiz = quiz;
      });
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isGeneratingQuiz = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_generatedQuiz != null) {
      return QuizPage(
        quiz: _generatedQuiz!,
        onExit: () {
          setState(() {
            _generatedQuiz = null;
          });
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12), 
                      _buildQuizUploadZone(),
                      if (_selectedQuizFileName != null) ...[
                        const SizedBox(height: 24),
                        _buildSelectedFileAndStartButton(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuizUploadZone() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _pickQuizFile,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border.all(color: Colors.grey.shade300, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(Icons.cloud_upload_outlined, size: 56, color: Colors.purple.shade300),
              const SizedBox(height: 20),
              const Text('Select your file or drag and drop', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Text('Only PDF files are accepted', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(color: const Color(0xFFE9D5FF), borderRadius: BorderRadius.circular(8)),
                child: Text('Browse Files', style: TextStyle(color: Colors.purple.shade900, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedFileAndStartButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
              const SizedBox(width: 12),
              Expanded(child: Text(_selectedQuizFileName!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              IconButton(onPressed: _pickQuizFile, icon: const Icon(Icons.refresh, size: 20)),
              IconButton(onPressed: () => setState(() { _selectedQuizFileName = null; _selectedQuizFileBytes = null; }), icon: const Icon(Icons.close, size: 20)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isGeneratingQuiz ? null : _startQuizFromPdf,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9333EA), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: _isGeneratingQuiz ? const CircularProgressIndicator(color: Colors.white) : const Text('Generate Quiz Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}