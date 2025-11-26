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
  
  // Chat History
  List<Map<String, String>> messages = [
    {
      "role": "bot", 
      "text": "Hello! I am ready. Upload a PDF or ask me questions about existing documents."
    }
  ];
  
  bool _isUploading = false;
  bool _isTyping = false;
  String? _activeFile;

  // --- ACTIONS ---

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
        
        // Clear memory when new file is added to avoid context confusion
        await _ragService.clearMemory();
        
        setState(() {
          _activeFile = result.files.single.name;
          messages.add({
            "role": "bot", 
            "text": "✅ Analyzed $_activeFile. I'm ready to answer questions!"
          });
        });
      } catch (e) {
        _showError("Upload Error: $e");
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // 1. Add User Message
    setState(() {
      messages.add({"role": "user", "text": text});
      _isTyping = true;
      _controller.clear();
    });
    _scrollToBottom();

    // 2. Get AI Response
    final answer = await _ragService.askQuestion(text);

    // 3. Add Bot Message
    if (mounted) {
      setState(() {
        _isTyping = false;
        messages.add({"role": "bot", "text": answer});
      });
      _scrollToBottom();
    }
  }

  Future<void> _resetChat() async {
    await _ragService.clearMemory();
    setState(() {
      messages.clear();
      messages.add({
        "role": "bot", 
        "text": "Memory cleared. Starting a fresh conversation."
      });
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red,
    ));
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

  // --- UI BUILD ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Study Assistant"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetChat,
            tooltip: "Clear Memory",
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _isUploading ? null : _pickAndUploadPdf,
            tooltip: "Upload PDF",
          ),
        ],
      ),
      body: Column(
        children: [
          // File Status Banner
          if (_activeFile != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.green.shade100,
              child: Text(
                "Active Document: $_activeFile",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold),
              ),
            ),

          // Messages List
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
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12).copyWith(
                        bottomRight: isUser ? Radius.zero : null,
                        bottomLeft: isUser ? null : Radius.zero,
                      ),
                    ),
                    child: Text(
                      msg['text']!,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                        fontSize: 15,
                      ),
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
                  SizedBox(
                    width: 16, height: 16, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isUploading ? "Reading Document..." : "Thinking...",
                    style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),

          // Input Area
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _isTyping ? null : _sendMessage(),
                    decoration: InputDecoration(
                      hintText: "Ask about the document...",
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: _isTyping ? Colors.grey : Colors.blue,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _isTyping ? null : _sendMessage, 
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}