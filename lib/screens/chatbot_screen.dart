import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/rag_service.dart'; // Import the service we just made

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final RagService _ragService = RagService();
  final TextEditingController _controller = TextEditingController();
  
  // State variables
  List<Map<String, String>> messages = []; // Stores {role: "user"|"bot", text: "..."}
  bool _isUploading = false;
  bool _isTyping = false;
  String? _uploadedFileName;

  // 1. Pick and Upload PDF
  Future<void> _pickAndUploadPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      
      setState(() => _isUploading = true);
      
      try {
        await _ragService.uploadPdf(file);
        
        setState(() {
          _uploadedFileName = result.files.single.name;
          messages.add({
            "role": "bot", 
            "text": "I've studied $_uploadedFileName! Ask me anything about it."
          });
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  // 2. Send Message
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Add user message to UI
    setState(() {
      messages.add({"role": "user", "text": text});
      _isTyping = true;
      _controller.clear();
    });

    // Get answer from Python
    final answer = await _ragService.askQuestion(text);

    // Add bot response to UI
    setState(() {
      _isTyping = false;
      messages.add({"role": "bot", "text": answer});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Study Assistant"),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _isUploading ? null : _pickAndUploadPdf,
            tooltip: "Upload PDF",
          ),
        ],
      ),
      body: Column(
        children: [
          // Info Banner
          if (_uploadedFileName != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.green.shade100,
              width: double.infinity,
              child: Text(
                "Active Source: $_uploadedFileName",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.green),
              ),
            ),

          // Chat Area
          Expanded(
            child: messages.isEmpty
                ? const Center(child: Text("Upload a PDF to start learning!"))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isUser = msg['role'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isUser ? Colors.blue : Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            msg['text']!,
                            style: TextStyle(color: isUser ? Colors.white : Colors.black),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          // Loading Indicator
          if (_isTyping || _isUploading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),

          // Input Field
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Ask a question...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: (_uploadedFileName == null || _isTyping) ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}