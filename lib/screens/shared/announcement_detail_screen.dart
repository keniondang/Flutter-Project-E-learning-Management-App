import 'package:elearning_management_app/models/announcement.dart';
import 'package:elearning_management_app/models/user_model.dart';
import 'package:elearning_management_app/providers/announcement_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class AnnouncementDetailScreen extends StatefulWidget {
  final Announcement announcement;
  final UserModel currentUser;

  const AnnouncementDetailScreen({
    Key? key,
    required this.announcement,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<AnnouncementDetailScreen> createState() =>
      _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<AnnouncementComment> _comments = [];
  bool _isLoadingComments = true;
  bool _isPostingComment = false;

  @override
  void initState() {
    super.initState();
    _markAsViewed();
    _loadComments();
  }

  Future<void> _markAsViewed() async {
    // ✅ Fix: Pass the current user ID explicitly
    if (widget.announcement.hasViewed == false ||
        widget.announcement.hasViewed == null) {
      await context
          .read<AnnouncementProvider>()
          .markAsViewed(widget.announcement.id, widget.currentUser.id);
    }
  }

  Future<void> _loadComments() async {
    final comments = await context
        .read<AnnouncementProvider>()
        .loadComments(widget.announcement.id);
    if (mounted) {
      setState(() {
        _comments = comments;
        _isLoadingComments = false;
      });
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }
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

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isPostingComment = true);
    final text = _commentController.text.trim();

    try {
      _commentController.clear();
      FocusScope.of(context).unfocus();

      // ✅ Fix: Pass the current user ID explicitly
      final newComment = await context.read<AnnouncementProvider>().addComment(
            widget.announcement.id,
            text,
            widget.currentUser.id,
          );

      if (newComment != null && mounted) {
        setState(() {
          final displayComment = AnnouncementComment(
              id: newComment.id,
              announcementId: newComment.announcementId,
              userId: newComment.userId,
              userName: widget
                  .currentUser.fullName, // Use local name for instant feedback
              comment: newComment.comment,
              createdAt: newComment.createdAt);
          _comments.add(displayComment);
        });
        _scrollToBottom();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post: $e')),
      );
    } finally {
      if (mounted) setState(() => _isPostingComment = false);
    }
  }

  Future<void> _handleFileDownload(String url) async {
    final fileName = url.split('/').last;

    final bytes =
        await context.read<AnnouncementProvider>().fetchFileAttachment(url);

    if (bytes != null) {
      String? result =
          await FilePicker.platform.saveFile(fileName: fileName, bytes: bytes);
      print(result);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error downloading $fileName'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _showViewersSheet() {
    if (!widget.currentUser.isInstructor) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _ViewersBottomSheet(
        announcementId: widget.announcement.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Announcement', style: GoogleFonts.poppins()),
        actions: [
          if (widget.currentUser.isInstructor)
            IconButton(
              icon: const Icon(Icons.analytics_outlined),
              tooltip: 'See Viewers',
              onPressed: _showViewersSheet,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildContent(),
                  const SizedBox(height: 24),
                  _buildAttachments(),
                  const SizedBox(height: 24),
                  const Divider(thickness: 1),
                  _buildCommentsList(),
                ],
              ),
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final date = DateFormat('MMM dd, yyyy • HH:mm')
        .format(widget.announcement.createdAt);

    return Row(
      children: [
        CircleAvatar(
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
                widget.announcement.title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Posted on $date',
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
      data: widget.announcement.content,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: GoogleFonts.poppins(fontSize: 15, height: 1.5),
        h1: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold),
        h2: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
        listBullet: GoogleFonts.poppins(fontSize: 15),
      ),
    );
  }

  Widget _buildAttachments() {
    if (widget.announcement.fileAttachments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attachments',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.announcement.fileAttachments.map((url) {
            String fileName = url.split('/').last;

            if (fileName.length > 20) {
              fileName = '${fileName.substring(0, 15)}...';
            }

            return ActionChip(
              avatar:
                  const Icon(Icons.attach_file, size: 16, color: Colors.white),
              label: Text(
                fileName,
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              backgroundColor: Colors.blueAccent,
              onPressed: () => _handleFileDownload(url),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCommentsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comments (${_comments.length})',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoadingComments)
          const Center(child: CircularProgressIndicator())
        else if (_comments.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No comments yet. Be the first to reply!',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            ),
          )
        else
          ..._comments.map((comment) => _buildCommentItem(comment)),
      ],
    );
  }

  Widget _buildCommentItem(AnnouncementComment comment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey[300],
            child: Text(
              comment.userName.isNotEmpty
                  ? comment.userName[0].toUpperCase()
                  : '?',
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
                        comment.userName,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        DateFormat('MMM dd, HH:mm').format(comment.createdAt),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comment.comment,
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

  Widget _buildCommentInput() {
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
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Write a comment...',
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
            child: _isPostingComment
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _postComment,
                  ),
          ),
        ],
      ),
    );
  }
}

// --- Internal Widget for Viewers Sheet ---
class _ViewersBottomSheet extends StatelessWidget {
  final String announcementId;

  const _ViewersBottomSheet({Key? key, required this.announcementId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: context.read<AnnouncementProvider>().getViewers(announcementId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final viewers = snapshot.data ?? [];

        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Viewed by ${viewers.length} students',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (viewers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text('No views yet')),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: viewers.length,
                    itemBuilder: (context, index) {
                      final viewer = viewers[index];
                      final user = viewer['users'];
                      final viewedAt = DateTime.parse(viewer['viewed_at']);

                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            (user['full_name'] as String)[0].toUpperCase(),
                          ),
                        ),
                        title: Text(user['full_name']),
                        subtitle: Text(user['email']),
                        trailing: Text(
                          DateFormat('MMM dd, HH:mm').format(viewedAt),
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
