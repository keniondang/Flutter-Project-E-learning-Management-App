import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class RagService {
  // Use 10.0.2.2 for Android Emulator
  // Use '127.0.0.1' for iOS Simulator or Web
  static final String _baseUrl = Platform.isAndroid 
      ? 'http://10.0.2.2:8000' 
      : 'http://127.0.0.1:8000';

  /// Sends a question to the backend and gets the answer + citations
  Future<String> askQuestion(String query) async {
    final uri = Uri.parse('$_baseUrl/ask');
    try {
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"query": query}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // The backend now formats everything into this 'answer' key
        return data['answer']; 
      } else {
        return "Error: Server responded with ${response.statusCode}";
      }
    } catch (e) {
      return "Connection error: Is the Python backend running?";
    }
  }

  /// Uploads a PDF to the backend to add to the knowledge base
  Future<String> uploadPdf(File pdfFile) async {
    final uri = Uri.parse('$_baseUrl/upload-pdf');
    var request = http.MultipartRequest('POST', uri);

    request.files.add(await http.MultipartFile.fromPath(
      'file',
      pdfFile.path,
      contentType: MediaType('application', 'pdf'),
    ));

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return "Success";
      } else {
        throw Exception('Failed to upload: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error connecting to AI Server: $e');
    }
  }

  /// Clears the AI's conversation memory
  Future<void> clearMemory() async {
    try {
      await http.post(Uri.parse('$_baseUrl/reset'));
    } catch (e) {
      print("Failed to reset memory: $e");
    }
  }
}