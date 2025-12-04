import 'dart:io'; // Required for File object on Mobile/Desktop
import 'package:elearning_management_app/providers/announcement_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'; // Required for kIsWeb check
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/course.dart';
import '../../models/group.dart';
import '../../providers/group_provider.dart';

class CreateAnnouncementScreen extends StatefulWidget {
  final Course course;
  final String instructorId;

  const CreateAnnouncementScreen({
    super.key,
    required this.course,
    required this.instructorId,
  });

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

  List<PlatformFile> _pickedFiles = [];
  bool _isUploading = false;
  bool _showMarkdownHelp = false;

  List<Group> _availableGroups = [];

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    await context.read<GroupProvider>().loadGroups(widget.course.id);
    if (mounted) {
      setState(() {
        _availableGroups = context.read<GroupProvider>().groups;
      });
    }
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        withData: true, // Important: loads bytes for Web compatibility
      );

      if (result != null) {
        setState(() {
          // Creating a new list ensures the UI updates correctly
          _pickedFiles = [..._pickedFiles, ...result.files];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking files: $e')),
        );
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      _pickedFiles.removeAt(index);
    });
  }

  // --- Helper Methods for File Previews ---

  bool _isImage(String? extension) {
    if (extension == null) return false;
    final imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'];
    return imageExtensions.contains(extension.toLowerCase());
  }

  Widget _getImageWidget(PlatformFile file) {
    // 1. Try displaying from bytes (Web or when bytes are available)
    if (file.bytes != null) {
      return Image.memory(
        file.bytes!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, size: 20),
      );
    }
    // 2. Try displaying from path (Mobile/Desktop) - Only if NOT on web
    else if (file.path != null && !kIsWeb) {
      return Image.file(
        File(file.path!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, size: 20),
      );
    }
    // 3. Fallback
    return const Icon(Icons.image_not_supported);
  }

  Widget _buildFilePreview(PlatformFile file) {
    // If it's an image, show thumbnail
    if (_isImage(file.extension)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: 40,
          height: 40,
          child: _getImageWidget(file),
        ),
      );
    }

    // If it's not an image, show a relevant icon
    IconData icon;
    switch (file.extension?.toLowerCase()) {
      case 'pdf':
        icon = Icons.picture_as_pdf;
        break;
      case 'doc':
      case 'docx':
        icon = Icons.description;
        break;
      case 'zip':
      case 'rar':
        icon = Icons.folder_zip;
        break;
      case 'xls':
      case 'xlsx':
      case 'csv':
        icon = Icons.table_chart;
        break;
      default:
        icon = Icons.insert_drive_file;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, color: Colors.blue[700], size: 24),
    );
  }

  // -----------------------------------------

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_scopeType == 'specific' && _selectedGroups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one group')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      await context.read<AnnouncementProvider>().createAnnouncement(
            courseId: widget.course.id,
            instructorId: widget.instructorId,
            title: _titleController.text.trim(),
            content: _contentController.text.trim(),
            fileAttachments: _pickedFiles,
            scopeType: _scopeType,
            targetGroups: _selectedGroups,
          );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('New Announcement', style: GoogleFonts.poppins()),
        actions: [
          IconButton(
            icon: _isUploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check),
            onPressed: _isUploading ? null : _submit,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title Field
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.title),
                  labelStyle: GoogleFonts.poppins(),
                ),
                style: GoogleFonts.poppins(),
                validator: (val) => val!.isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),

              // Content Field with Markdown Support
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Content',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextButton.icon(
                        icon: Icon(
                          _showMarkdownHelp ? Icons.help : Icons.help_outline,
                          size: 16,
                        ),
                        label: Text(
                          'Markdown Guide',
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        onPressed: () {
                          setState(
                              () => _showMarkdownHelp = !_showMarkdownHelp);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_showMarkdownHelp)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Formatting Tips:',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildMarkdownTip('**bold text**', 'Bold'),
                          _buildMarkdownTip('*italic text*', 'Italic'),
                          _buildMarkdownTip('# Heading 1', 'Large Heading'),
                          _buildMarkdownTip('## Heading 2', 'Medium Heading'),
                          _buildMarkdownTip('- Item', 'Bullet list'),
                          _buildMarkdownTip('1. Item', 'Numbered list'),
                          _buildMarkdownTip('[Link](url)', 'Hyperlink'),
                        ],
                      ),
                    ),
                  TextFormField(
                    controller: _contentController,
                    decoration: InputDecoration(
                      hintText:
                          'Write your announcement content here...\n\nYou can use Markdown for formatting!',
                      hintStyle: GoogleFonts.poppins(
                          fontSize: 14, color: Colors.grey[400]),
                      border: const OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    style: GoogleFonts.poppins(),
                    maxLines: 8,
                    validator: (val) =>
                        val!.isEmpty ? 'Content is required' : null,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Scope Selection
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Send To',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      RadioListTile<String>(
                        title:
                            Text('All Students', style: GoogleFonts.poppins()),
                        value: 'all',
                        groupValue: _scopeType,
                        onChanged: (val) => setState(() => _scopeType = val!),
                      ),
                      RadioListTile<String>(
                        title: Text('Specific Groups',
                            style: GoogleFonts.poppins()),
                        value: 'specific',
                        groupValue: _scopeType,
                        onChanged: (val) => setState(() => _scopeType = val!),
                      ),
                      if (_scopeType == 'specific')
                        Padding(
                          padding: const EdgeInsets.only(left: 16, top: 8),
                          child: Column(
                            children: _availableGroups
                                .map((g) => CheckboxListTile(
                                      title: Text(g.name,
                                          style: GoogleFonts.poppins()),
                                      value: _selectedGroups.contains(g.id),
                                      onChanged: (selected) {
                                        setState(() {
                                          selected!
                                              ? _selectedGroups.add(g.id)
                                              : _selectedGroups.remove(g.id);
                                        });
                                      },
                                    ))
                                .toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // File Attachments
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Attachments',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.attach_file),
                            label:
                                Text('Add Files', style: GoogleFonts.poppins()),
                            onPressed: _pickFiles,
                          ),
                        ],
                      ),
                      if (_pickedFiles.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            children: _pickedFiles.asMap().entries.map((entry) {
                              final index = entry.key;
                              final file = entry.value;
                              return Column(
                                children: [
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    // UPDATED: Using our custom preview method
                                    leading: _buildFilePreview(file),
                                    title: Text(
                                      file.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500),
                                    ),
                                    subtitle: Text(
                                      '${(file.size / 1024).toStringAsFixed(1)} KB',
                                      style: GoogleFonts.poppins(fontSize: 11),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.close,
                                          color: Colors.red),
                                      onPressed: () => _removeFile(index),
                                    ),
                                  ),
                                  if (index != _pickedFiles.length - 1)
                                    const Divider(height: 1),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarkdownTip(String syntax, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.blue[300]!),
            ),
            child: Text(
              syntax,
              style: GoogleFonts.sourceCodePro(fontSize: 11),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            description,
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}
