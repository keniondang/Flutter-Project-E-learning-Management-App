import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/course.dart';
import '../../models/group.dart';
import '../../providers/content_provider.dart';
import '../../providers/group_provider.dart';

class CreateAnnouncementScreen extends StatefulWidget {
  final Course course;
  final String instructorId;

  const CreateAnnouncementScreen({
    Key? key,
    required this.course,
    required this.instructorId,
  }) : super(key: key);

  @override
  State<CreateAnnouncementScreen> createState() =>
      _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  String _scopeType = 'all';
  List<String> _selectedGroups = [];
  List<String> _fileAttachments = [];
  List<Group> _availableGroups = [];

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    await context.read<GroupProvider>().loadGroups(widget.course.id);
    setState(() {
      _availableGroups = context.read<GroupProvider>().groups;
    });
  }

  Future<void> _createAnnouncement() async {
    if (_formKey.currentState!.validate()) {
      final success = await context.read<ContentProvider>().createAnnouncement(
        courseId: widget.course.id,
        instructorId: widget.instructorId,
        title: _titleController.text,
        content: _contentController.text,
        fileAttachments: _fileAttachments,
        scopeType: _scopeType,
        targetGroups: _selectedGroups,
      );

      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Announcement created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Announcement', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: _createAnnouncement,
            child: const Text('Post', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title field
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'Enter announcement title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Content field
              TextFormField(
                controller: _contentController,
                decoration: InputDecoration(
                  labelText: 'Content',
                  hintText: 'Enter announcement content',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 6,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter content';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Scope selection
              Text(
                'Target Audience',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              RadioListTile<String>(
                title: const Text('All students in course'),
                value: 'all',
                groupValue: _scopeType,
                onChanged: (value) {
                  setState(() {
                    _scopeType = value!;
                    _selectedGroups = [];
                  });
                },
              ),
              RadioListTile<String>(
                title: const Text('Specific groups'),
                value: 'specific',
                groupValue: _scopeType,
                onChanged: (value) {
                  setState(() {
                    _scopeType = value!;
                  });
                },
              ),

              // Group selection (if specific)
              if (_scopeType == 'specific') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Groups:',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      ..._availableGroups.map((group) {
                        return CheckboxListTile(
                          title: Text(group.name),
                          subtitle: Text('${group.studentCount ?? 0} students'),
                          value: _selectedGroups.contains(group.id),
                          onChanged: (checked) {
                            setState(() {
                              if (checked ?? false) {
                                _selectedGroups.add(group.id);
                              } else {
                                _selectedGroups.remove(group.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // File attachments
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Implement file picker
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('File upload will be implemented later'),
                    ),
                  );
                },
                icon: const Icon(Icons.attach_file),
                label: const Text('Attach Files'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
