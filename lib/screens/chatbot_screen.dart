import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/rag_service.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({Key? key}) : super(key: key);

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final RagService _ragService = const RagService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;

  final List<_ChatMessage> _messages = [
    _ChatMessage(
      text: "Welcome! Upload a PDF to begin learning.",
      isUser: false,
    )
  ];

  // =====================================================
  // SEND MESSAGE
  // =====================================================
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _controller.clear();
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final answer = await _ragService.askQuestion(text);
      setState(() {
        _messages.add(_ChatMessage(text: answer, isUser: false));
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(
          text: "Error: $e",
          isUser: false,
          isError: true,
        ));
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // =====================================================
  // UPLOAD PDF FUNCTION (FULLY RESTORED)
  // =====================================================
  Future<void> _uploadPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ["pdf"],
      );

      if (result == null) return;

      final fileBytes = result.files.single.bytes!;
      final filename = result.files.single.name;

      setState(() {
        _messages.add(_ChatMessage(
          text: "Uploading $filename...",
          isUser: false,
        ));
      });
      _scrollToBottom();

      await _ragService.uploadPdf(fileBytes, filename);

      setState(() {
        _messages.add(_ChatMessage(
          text: "Uploaded and added to knowledge base!",
          isUser: false,
        ));
      });
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(
          text: "Upload error: $e",
          isUser: false,
          isError: true,
        ));
      });
    }
  }

  // =====================================================
  // RESET CHAT
  // =====================================================
  Future<void> _resetChat() async {
    await _ragService.resetChat();
    setState(() {
      _messages.clear();
      _messages.add(_ChatMessage(
        text: "Chat reset. Upload a PDF or ask a question.",
        isUser: false,
      ));
    });
    _scrollToBottom();
  }

  // Scroll helper
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  // =====================================================
  // UI LAYOUT
  // =====================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Learning Assistant",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: "Upload PDF",
            onPressed: _uploadPdf,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Reset conversation",
            onPressed: _resetChat,
          ),
        ],
      ),

      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _ChatBubble(message: _messages[index]);
              },
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),

          SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    decoration: const InputDecoration(
                      hintText: "Ask something…",
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  });
}

class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;

  const _ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final alignment =
        message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    final bubbleColor = message.isError
        ? Colors.red.shade100
        : message.isUser
            ? Colors.blue.shade300
            : Colors.grey.shade300;

    final textColor =
        message.isUser ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxWidth: 600),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(message.text, style: TextStyle(color: textColor)),
        ),
      ],
    );
  }
}