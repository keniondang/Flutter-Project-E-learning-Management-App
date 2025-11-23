import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/rag_service.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final RagService _ragService = RagService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Initial Greeting
  List<Map<String, String>> messages = [
    {
      "role": "bot", 
      "text": "Hello! I have studied the Course Guide. You can ask me questions about it directly, or upload your own PDF for specific help!"
    }
  ];
  
  bool _isUploading = false;
  bool _isTyping = false;
  String? _uploadedFileName;

  // 1. Pick and Upload PDF (Optional now)
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
            "text": "I've added $_uploadedFileName to my knowledge! Ask me about it."
          });
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  // 2. Send Message (Unlocked)
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Add user message to UI
    setState(() {
      messages.add({"role": "user", "text": text});
      _isTyping = true;
      _controller.clear();
    });
    
    // Scroll to bottom
    _scrollToBottom();

    // Get answer from Python
    final answer = await _ragService.askQuestion(text);

    // Add bot response to UI
    if (mounted) {
      setState(() {
        _isTyping = false;
        messages.add({"role": "bot", "text": answer});
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
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
            tooltip: "Upload Custom PDF",
          ),
        ],
      ),
      body: Column(
        children: [
          // Info Banner (Dynamic)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            width: double.infinity,
            color: _uploadedFileName != null ? Colors.green.shade100 : Colors.blue.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _uploadedFileName != null ? Icons.attach_file : Icons.library_books,
                  size: 16,
                  color: _uploadedFileName != null ? Colors.green[800] : Colors.blue[800],
                ),
                const SizedBox(width: 8),
                Text(
                  _uploadedFileName != null 
                    ? "Focus: $_uploadedFileName + Guide" 
                    : "Focus: General Course Guide",
                  style: TextStyle(
                    color: _uploadedFileName != null ? Colors.green[900] : Colors.blue[900],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Chat Area
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
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
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue : Colors.grey[200],
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(12),
                        topRight: const Radius.circular(12),
                        bottomLeft: isUser ? const Radius.circular(12) : Radius.zero,
                        bottomRight: isUser ? Radius.zero : const Radius.circular(12),
                      ),
                    ),
                    child: Text(
                      msg['text']!,
                      style: TextStyle(color: isUser ? Colors.white : Colors.black87),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Loading Indicator
          if (_isTyping || _isUploading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16, height: 16, 
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(_isUploading ? "Reading PDF..." : "AI is thinking...", style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),

          // Input Field
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 5,
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _isTyping ? null : _sendMessage(),
                    decoration: const InputDecoration(
                      hintText: "Ask a question...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Colors.blue,
                  // FIX: Button is now enabled unless AI is currently typing
                  onPressed: _isTyping ? null : _sendMessage, 
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}