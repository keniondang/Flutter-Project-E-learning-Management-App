import 'dart:typed_data';

import 'package:elearning_management_app/models/forum/forum.dart';
import 'package:elearning_management_app/models/forum/forum_reply.dart';
import 'package:elearning_management_app/models/user_model.dart';
import 'package:elearning_management_app/providers/forum_reply_provider.dart';
import 'package:elearning_management_app/providers/student_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ForumDetailScreen extends StatefulWidget {
  final Forum forum;
  final UserModel forumPoster;
  final UserModel currentUser;

  const ForumDetailScreen({
    super.key,
    required this.forum,
    required this.forumPoster,
    required this.currentUser,
  });

  @override
  State<ForumDetailScreen> createState() => _ForumDetailScreenState();
}

class _ForumDetailScreenState extends State<ForumDetailScreen> {
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadReplies();
  }

  Future<void> _loadReplies() async {
    await context.read<ForumReplyProvider>().loadForumReplies(widget.forum.id);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleSendReply() async {
    if (_replyController.text.trim().isEmpty) return;

    final text = _replyController.text.trim();

    _replyController.clear();
    FocusScope.of(context).unfocus();

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()));

    final success = await context.read<ForumReplyProvider>().createForumReply(
          widget.forum.id,
          text,
          widget.currentUser,
        );

    if (mounted) {
      Navigator.pop(context);

      if (success) {
        _scrollToBottom();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to post: ${context.read<ForumReplyProvider>().error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Topic Discussion', style: GoogleFonts.poppins()),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16.0),
                child: Consumer<ForumReplyProvider>(
                  builder: (context, provider, child) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        child!,
                        Text(
                          'Replies (${provider.forumReplies.length})',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (provider.isLoading)
                          const Center(child: CircularProgressIndicator())
                        else if (provider.forumReplies.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Text(
                                'No replies yet. Be the first to reply!',
                                style: GoogleFonts.poppins(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          _buildReplies(provider.forumReplies),
                      ],
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 16),
                      _buildContent(),
                      const SizedBox(height: 24),
                      const Divider(thickness: 1),
                    ],
                  ),
                )),
          ),
          _buildReplyInput(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final date =
        DateFormat('MMM dd, yyyy • HH:mm').format(widget.forum.createdAt);

    return Row(
      children: [
        (widget.forumPoster.hasAvatar)
            ? CircleAvatar(
                radius: 24,
                child: null,
                backgroundImage:
                    MemoryImage(widget.forumPoster.avatarBytes! as Uint8List))
            : CircleAvatar(
                radius: 24,
                backgroundColor: Colors.blue[100],
                child: const Icon(Icons.person, color: Colors.blue),
              ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.forum.title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Posted by ${widget.forumPoster.fullName} • $date',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return MarkdownBody(
      data: widget.forum.content,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: GoogleFonts.poppins(fontSize: 15, height: 1.5),
        h1: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold),
        h2: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
        listBullet: GoogleFonts.poppins(fontSize: 15),
      ),
    );
  }

  // Widget _buildRepliesList() {
  //   // Access replies from provider
  //   final replies = context.watch<ForumReplyProvider>().forumReplies;

  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Text(
  //         'Replies (${replies.length})',
  //         style: GoogleFonts.poppins(
  //           fontSize: 16,
  //           fontWeight: FontWeight.w600,
  //         ),
  //       ),
  //       const SizedBox(height: 16),
  //       if (_isLoadingReplies)
  //         const Center(child: CircularProgressIndicator())
  //       else if (replies.isEmpty)
  //         Center(
  //           child: Padding(
  //             padding: const EdgeInsets.symmetric(vertical: 20),
  //             child: Text(
  //               'No replies yet. Be the first to reply!',
  //               style: GoogleFonts.poppins(color: Colors.grey),
  //             ),
  //           ),
  //         )
  //       else
  //         ...replies.map((reply) => _buildReplyItem(reply)),
  //     ],
  //   );
  // }

  Widget _buildReplies(List<ForumReply> replies) {
    return FutureBuilder<List<MapEntry<String, UserModel?>>>(
      future: Future.wait(replies.map((x) => x.userId).toSet().map((x) async =>
          MapEntry(x, await context.read<StudentProvider>().fetchUser(x)))),
      builder: (context, snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.done:
            final userMap =
                Map.fromEntries(snapshot.data!.where((x) => x.value != null));

            replies.sort((a, b) => b.createdAt.compareTo(a.createdAt));

            return Column(
                children: replies
                    .map((x) => _buildReplyItem(x, userMap[x.userId]!))
                    .toList());
          default:
            return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  Widget _buildReplyItem(ForumReply reply, UserModel user) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user.hasAvatar)
            CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey[300],
                backgroundImage: user.avatarBytes != null
                    ? MemoryImage(user.avatarBytes! as Uint8List)
                    : null,
                child: user.avatarBytes != null
                    ? null
                    : Text(
                        user.fullName.isNotEmpty
                            ? user.fullName[0].toUpperCase()
                            : '?',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.black87),
                      ))
          else
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: Text(
                user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        user.fullName,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        DateFormat('MMM dd, HH:mm').format(reply.createdAt),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reply.content,
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 4,
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyController,
              decoration: InputDecoration(
                hintText: 'Write a reply...',
                hintStyle: GoogleFonts.poppins(fontSize: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              minLines: 1,
              maxLines: 3,
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Colors.blue,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: _handleSendReply,
            ),
          ),
        ],
      ),
    );
  }
}
