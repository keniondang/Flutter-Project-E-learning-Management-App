import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class RagService {
  // TODO: Replace this with your Railway deployed backend
  static const String baseUrl = "https://your-app.up.railway.app";

  const RagService();

  // ================================
  // ASK QUESTION
  // ================================
  Future<String> askQuestion(String question) async {
    final url = Uri.parse("$baseUrl/ask");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"query": question}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["answer"] ?? "No response";
    } else {
      throw Exception(
          "Failed to get answer: ${response.statusCode} ${response.body}");
    }
  }

  // ================================
  // RESET CHAT MEMORY
  // ================================
  Future<void> resetChat() async {
    final url = Uri.parse("$baseUrl/reset");
    final response = await http.post(url);

    if (response.statusCode != 200) {
      throw Exception(
          "Failed to reset chat: ${response.statusCode} ${response.body}");
    }
  }

  // ================================
  // UPLOAD PDF FILE FUNCTION
  // ================================
  Future<void> uploadPdf(Uint8List fileBytes, String filename) async {
    final url = Uri.parse("$baseUrl/upload-pdf");

    final request = http.MultipartRequest("POST", url)
      ..files.add(
        http.MultipartFile.fromBytes(
          "file",
          fileBytes,
          filename: filename,
          contentType: MediaType("application", "pdf"),
        ),
      );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception("Upload failed: ${response.statusCode} ${response.body}");
    }
  }
}