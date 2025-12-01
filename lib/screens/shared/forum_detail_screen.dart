import 'package:elearning_management_app/models/forum/forum.dart';
import 'package:elearning_management_app/models/user_model.dart';
import 'package:elearning_management_app/providers/forum_reply_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class ForumDetailScreen extends StatefulWidget {
  final Forum forum;
  final UserModel user;

  const ForumDetailScreen({
    super.key,
    required this.forum,
    required this.user,
  });

  @override
  State<ForumDetailScreen> createState() => _ForumDetailScreenState();
}

class _ForumDetailScreenState extends State<ForumDetailScreen> {
  final TextEditingController _replyController = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Load replies when screen opens
    // Note: The method in your provider is named 'loadForums', but it loads replies based on the forumId
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ForumReplyProvider>().loadForumReplies(widget.forum.id);
    });
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _handleSendReply() async {
    if (_replyController.text.trim().isEmpty) return;

    setState(() => _isSending = true);

    final success = await context.read<ForumReplyProvider>().createForumReply(
          widget.forum.id,
          _replyController.text.trim(),
          widget.user,
        );

    setState(() => _isSending = false);

    if (success && mounted) {
      _replyController.clear();
      // Dismiss keyboard
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reply posted successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Failed to post reply: ${context.read<ForumReplyProvider>().error}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildTopicHeader() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    widget.forum.createdByFullName[0].toUpperCase(),
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, color: Colors.blue[800]),
                  ),
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
                        'Posted by ${widget.forum.createdByFullName} • ${DateFormat('MMM dd, yyyy').format(widget.forum.createdAt)}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              widget.forum.content,
              style: GoogleFonts.poppins(fontSize: 15, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyList(ForumReplyProvider provider) {
    // Combine header and replies into one list view
    final replies = provider
        .forumReplies; // Note: using snake_case getter from your provider

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: replies.length + 1, // +1 for the header
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopicHeader(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Replies (${replies.length})',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          );
        }

        final reply = replies[index - 1];
        final isMe = reply.userId == widget.user.id;

        return Card(
          elevation: 0,
          color: isMe ? Colors.blue[50] : Colors.white,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.grey[300],
                          child: Icon(Icons.person,
                              size: 16, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isMe
                              ? 'You'
                              : reply
                                  .userFullName, // Assumes userFullName exists in ForumReply
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: isMe ? Colors.blue[700] : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      DateFormat('MMM dd, HH:mm').format(reply.createdAt),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  reply.content,
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Topic Discussion', style: GoogleFonts.poppins()),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ForumReplyProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _buildReplyList(provider);
              },
            ),
          ),
          // Reply Input Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      decoration: InputDecoration(
                        hintText: 'Write a reply...',
                        hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: _isSending ? null : _handleSendReply,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
