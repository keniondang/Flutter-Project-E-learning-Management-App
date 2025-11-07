import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/course.dart';
import '../../models/user_model.dart';

class ForumScreen extends StatefulWidget {
  final Course course;
  final UserModel user;

  const ForumScreen({
    Key? key,
    required this.course,
    required this.user,
  }) : super(key: key);

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _topics = [];
  List<Map<String, dynamic>> _filteredTopics = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    setState(() => _isLoading = true);

    try {
      // First ensure forum exists for course
      var forumResponse = await _supabase
          .from('forums')
          .select()
          .eq('course_id', widget.course.id)
          .maybeSingle();

      String forumId;
      if (forumResponse == null) {
        // Create forum if it doesn't exist
        forumResponse = await _supabase
            .from('forums')
            .insert({
              'course_id': widget.course.id,
              'title': '${widget.course.name} Forum',
              'description': 'Discussion forum for ${widget.course.name}',
              'created_by': widget.user.id,
            })
            .select()
            .single();
      }
      forumId = forumResponse['id'];

      // Load topics with user info and reply count
      final topics = await _supabase
          .from('forum_topics')
          .select('*, users!forum_topics_created_by_fkey(full_name)')
          .eq('forum_id', forumId)
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false);

      // Get reply counts
      for (var topic in topics) {
        final replyCount = await _supabase
            .from('forum_replies')
            .select('id')
            .eq('topic_id', topic['id']);
        topic['reply_count'] = (replyCount as List).length;
      }

      setState(() {
        _topics = List<Map<String, dynamic>>.from(topics);
        _filteredTopics = _topics;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading forum topics: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterTopics(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredTopics = _topics;
      } else {
        _filteredTopics = _topics.where((topic) {
          final title = topic['title'].toString().toLowerCase();
          final content = topic['content'].toString().toLowerCase();
          return title.contains(query.toLowerCase()) ||
                 content.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

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
              if (titleController.text.isEmpty || contentController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill all fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                // Get forum ID
                final forum = await _supabase
                    .from('forums')
                    .select('id')
                    .eq('course_id', widget.course.id)
                    .single();

                await _supabase.from('forum_topics').insert({
                  'forum_id': forum['id'],
                  'title': titleController.text,
                  'content': contentController.text,
                  'created_by': widget.user.id,
                });

                Navigator.pop(context);
                _loadTopics();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Topic created successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error creating topic: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Course Forum', style: GoogleFonts.poppins()),
      ),
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
              onChanged: _filterTopics,
            ),
          ),

          // Topics list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTopics.isEmpty
                    ? Center(
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
                              'No topics yet',
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
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredTopics.length,
                        itemBuilder: (context, index) {
                          final topic = _filteredTopics[index];
                          final isPinned = topic['is_pinned'] ?? false;
                          final isLocked = topic['is_locked'] ?? false;
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: isPinned ? 3 : 1,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isPinned
                                    ? Colors.orange[100]
                                    : Colors.blue[100],
                                child: Icon(
                                  isPinned ? Icons.push_pin : Icons.topic,
                                  color: isPinned
                                      ? Colors.orange[700]
                                      : Colors.blue[700],
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      topic['title'],
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (isLocked)
                                    Icon(
                                      Icons.lock,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    topic['content'],
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        'By ${topic['users']['full_name']}',
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
                                        '${topic['reply_count']} replies',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        DateFormat('MMM dd').format(
                                          DateTime.parse(topic['created_at']),
                                        ),
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              onTap: () {
                                // Navigate to topic detail
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ForumTopicDetailScreen(
                                      topic: topic,
                                      user: widget.user,
                                    ),
                                  ),
                                ).then((_) => _loadTopics());
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateTopicDialog,
        child: const Icon(Icons.add),
        tooltip: 'New Topic',
      ),
    );
  }
}

// Forum Topic Detail Screen would be another file
class ForumTopicDetailScreen extends StatelessWidget {
  final Map<String, dynamic> topic;
  final UserModel user;

  const ForumTopicDetailScreen({
    Key? key,
    required this.topic,
    required this.user,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Implementation for viewing topic and replies
    return Scaffold(
      appBar: AppBar(
        title: Text('Topic', style: GoogleFonts.poppins()),
      ),
      body: Center(
        child: Text('Topic detail implementation here'),
      ),
    );
  }
}