import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class RagService {
  // ANDROID EMULATOR uses 10.0.2.2 to access localhost
  // iOS Simulator / Web uses 127.0.0.1 or localhost
  static final String _baseUrl = Platform.isAndroid 
      ? 'http://10.0.2.2:8000' 
      : 'http://127.0.0.1:8000';

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
        return data['answer']; // Returns the answer from Llama 3
      } else {
        return "Error: ${response.body}";
      }
    } catch (e) {
      return "Could not connect to AI. Is the Python script running?";
    }
  }
}