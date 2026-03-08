import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';

String extractTextFromPdf(Uint8List bytes) {

  final PdfDocument document = PdfDocument(inputBytes: bytes);

  String text = PdfTextExtractor(document).extractText();

  document.dispose();

  return text;
}