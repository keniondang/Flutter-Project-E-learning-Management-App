import 'package:elearning_management_app/providers/forum_provider.dart';
import 'package:elearning_management_app/screens/shared/forum_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/course.dart';
import '../../models/user_model.dart';

class ForumScreen extends StatefulWidget {
  final Course course;
  final UserModel user;

  const ForumScreen({super.key, required this.course, required this.user});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  final _searchController = TextEditingController();
  String _filterQuery = '';

  @override
  void initState() {
    super.initState();
    _loadForums();
  }

  Future<void> _loadForums() async {
    await context.read<ForumProvider>().loadForums(widget.course.id);
    // _forums = context.read<ForumProvider>().forums;
  }
  // Future<void> _loadTopics() async {
  //   setState(() => _isLoading = true);

  //   try {
  //     // First ensure forum exists for course
  //     var forumResponse = await _supabase
  //         .from('forums')
  //         .select()
  //         .eq('course_id', widget.course.id)
  //         .maybeSingle();

  //     String forumId;
  //     forumResponse ??= await _supabase
  //         .from('forums')
  //         .insert({
  //           'course_id': widget.course.id,
  //           'title': '${widget.course.name} Forum',
  //           'description': 'Discussion forum for ${widget.course.name}',
  //           'created_by': widget.user.id,
  //         })
  //         .select()
  //         .single();
  //     forumId = forumResponse['id'];

  //     // Load topics with user info and reply count
  //     final topics = await _supabase
  //         .from('forum_topics')
  //         .select('*, users!forum_topics_created_by_fkey(full_name)')
  //         .eq('forum_id', forumId)
  //         .order('is_pinned', ascending: false)
  //         .order('created_at', ascending: false);

  //     // Get reply counts
  //     for (var topic in topics) {
  //       final replyCount = await _supabase
  //           .from('forum_replies')
  //           .select('id')
  //           .eq('topic_id', topic['id']);
  //       topic['reply_count'] = (replyCount as List).length;
  //     }

  //     setState(() {
  //       _topics = List<Map<String, dynamic>>.from(topics);
  //       _filteredTopics = _topics;
  //       _isLoading = false;
  //     });
  //   } catch (e) {
  //     print('Error loading forum topics: $e');
  //     setState(() => _isLoading = false);
  //   }
  // }

  // void _filterTopics(String query) {
  //   setState(() {
  //     if (query.isEmpty) {
  //       _filteredTopics = _topics;
  //     } else {
  //       _filteredTopics = _topics.where((topic) {
  //         final title = topic['title'].toString().toLowerCase();
  //         final content = topic['content'].toString().toLowerCase();
  //         return title.contains(query.toLowerCase()) ||
  //             content.contains(query.toLowerCase());
  //       }).toList();
  //     }
  //   });
  // }

  void _showCreateTopicDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'New Topic',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Topic Title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentController,
                decoration: InputDecoration(
                  labelText: 'Content',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 5,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isEmpty ||
                  contentController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill all fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final success = await context.read<ForumProvider>().createForum(
                  widget.course.id,
                  titleController.text,
                  contentController.text,
                  widget.user);

              if (success && mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Topic created successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Error creating topic: ${context.read<ForumProvider>().error}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Widget _buildForums() {
    return Consumer<ForumProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.forums.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.forum_outlined,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No threads yet',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _showCreateTopicDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Create First Topic'),
                ),
              ],
            ),
          );
        }

        final forums = provider.forums
            .where((x) =>
                x.title.toLowerCase().contains(_filterQuery) ||
                x.content.toLowerCase().contains(_filterQuery))
            .toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: forums.length,
          itemBuilder: (context, index) {
            final forum = forums[index];

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 1,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Icon(
                    Icons.topic,
                    color: Colors.blue[700],
                  ),
                ),
                title: Text(
                  forum.title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      forum.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'By ${forum.createdByFullName}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.reply,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${forum.replyCount} replies',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat('MMM dd').format(forum.createdAt),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ForumDetailScreen(
                        forum: forum,
                        user: widget.user,
                      ),
                    ),
                  );

                  _loadForums();
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Course Forum', style: GoogleFonts.poppins())),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search topics...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (query) {
                setState(() {
                  _filterQuery = query;
                });
              },
            ),
          ),

          Expanded(child: _buildForums()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateTopicDialog,
        tooltip: 'New Topic',
        child: const Icon(Icons.add),
      ),
    );
  }
}
