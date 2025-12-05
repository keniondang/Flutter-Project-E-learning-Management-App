import 'dart:io'; // Required for File object
import 'package:elearning_management_app/providers/assignment_provider.dart';
import 'package:elearning_management_app/providers/assignment_submission_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'; // Required for kIsWeb
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/assignment.dart';
import '../../models/user_model.dart';

class AssignmentSubmissionScreen extends StatefulWidget {
  final Assignment assignment;
  final UserModel student;

  const AssignmentSubmissionScreen({
    super.key,
    required this.assignment,
    required this.student,
  });

  @override
  State<AssignmentSubmissionScreen> createState() =>
      _AssignmentSubmissionScreenState();
}

class _AssignmentSubmissionScreenState
    extends State<AssignmentSubmissionScreen> {
  final _submissionTextController = TextEditingController();

  List<PlatformFile> _submissionFiles = [];

  AssignmentSubmission? _existingSubmission;
  int _currentAttempt = 1;

  bool _isLoadingSubmission = true;

  @override
  void initState() {
    super.initState();
    _loadExistingSubmission();
  }

  Future<void> _loadExistingSubmission() async {
    final submission = await context
        .read<AssignmentSubmissionProvider>()
        .fetchStudentSubmission(widget.assignment.id, widget.student.id);

    if (submission != null) {
      setState(() {
        _existingSubmission = submission;
        _currentAttempt = (_existingSubmission!.attemptNumber) + 1;
        _submissionTextController.text =
            _existingSubmission!.submissionText ?? '';
      });
    }

    setState(() => _isLoadingSubmission = false);
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: widget.assignment.allowedFileTypes
            .map((x) => x.substring(1))
            .toList(),
        withData: true, // Important for Web
      );

      if (result != null) {
        final files =
            result.files.where((x) => x.size < widget.assignment.maxFileSize);

        if (files.isNotEmpty) {
          setState(() {
            _submissionFiles.addAll(files);
          });
        }
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
      _submissionFiles.removeAt(index);
    });
  }

  bool _isImage(String? extension) {
    if (extension == null) return false;
    final imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'];
    return imageExtensions.contains(extension.toLowerCase());
  }

  Widget _getImageWidget(PlatformFile file) {
    if (file.bytes != null) {
      return Image.memory(file.bytes!, fit: BoxFit.cover);
    } else if (file.path != null && !kIsWeb) {
      return Image.file(File(file.path!), fit: BoxFit.cover);
    }
    return const Icon(Icons.image_not_supported);
  }

  Widget _buildFilePreview(PlatformFile file) {
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

  Future<void> _submitAssignment() async {
    if (_submissionTextController.text.isEmpty && _submissionFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add submission text or files'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_currentAttempt > widget.assignment.maxAttempts) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum attempts exceeded'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final now = DateTime.now();
    final isLate = now.isAfter(widget.assignment.dueDate);

    if (!widget.assignment.isOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assignment is closed for submissions'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
              child: CircularProgressIndicator(),
            ));

    final success = await context
        .read<AssignmentSubmissionProvider>()
        .createSubmission(
            assignmentId: widget.assignment.id,
            studentId: widget.student.id,
            submissionText: _submissionTextController.text,
            submissionFiles: _submissionFiles,
            attemptNumber: _currentAttempt,
            isLate: isLate,
            submittedAt: now);

    if (mounted) {
      Navigator.pop(context);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Error submitting assignment: ${context.read<AssignmentSubmissionProvider>().error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleFileDownload(String url) async {
    final fileName = url.split('/').last;

    final bytes =
        await context.read<AssignmentProvider>().fetchFileAttachment(url);

    if (bytes != null) {
      // Note: saveFile might behave differently on Web/Mobile,
      // but keeping it as requested in previous snippets.
      await FilePicker.platform.saveFile(fileName: fileName, bytes: bytes);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error downloading $fileName'),
            backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildAttachments() {
    if (widget.assignment.fileAttachments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Course Attachments',
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
          children: widget.assignment.fileAttachments.map((url) {
            String fileName = url.split('/').last;

            if (fileName.length > 20) {
              fileName = '${fileName.substring(0, 15)}...';
            }

            return ActionChip(
              avatar: const Icon(Icons.download, size: 16, color: Colors.white),
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

  Widget _buildBody() {
    final now = DateTime.now();
    final isLate = now.isAfter(widget.assignment.dueDate);
    final daysUntilDue = widget.assignment.dueDate.difference(now).inDays;
    final hoursUntilDue =
        widget.assignment.dueDate.difference(now).inHours % 24;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Assignment info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.assignment.title,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.assignment.description,
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  const SizedBox(height: 16),

                  // --- Integrated Attachments Display (Course Materials) ---
                  _buildAttachments(),
                  if (widget.assignment.fileAttachments.isNotEmpty)
                    const SizedBox(height: 16),
                  // --------------------------------------------------------

                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.event, size: 20, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Due: ${DateFormat('MMM dd, yyyy HH:mm').format(widget.assignment.dueDate)}',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.score, size: 20, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Points: ${widget.assignment.totalPoints}',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.replay, size: 20, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Attempt: $_currentAttempt / ${widget.assignment.maxAttempts}',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                    ],
                  ),
                  if (!widget.assignment.isPastDue)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isLate ? Colors.orange[50] : Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.timer,
                            size: 16,
                            color: isLate ? Colors.orange : Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isLate
                                ? 'Late submission'
                                : 'Time remaining: $daysUntilDue days, $hoursUntilDue hours',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: isLate
                                  ? Colors.orange[700]
                                  : Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Previous submission (if exists)
          if (_existingSubmission != null) ...[
            Card(
              color: Colors.grey[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.history, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Previous Submission',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Submitted: ${DateFormat('MMM dd, yyyy HH:mm').format(_existingSubmission!.submittedAt)}',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    if (_existingSubmission!.grade != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Grade: ${_existingSubmission!.grade}/${widget.assignment.totalPoints}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_existingSubmission!.feedback != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Feedback: ${_existingSubmission!.feedback}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Submission form
          Text(
            'Your Submission',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _submissionTextController,
            decoration: InputDecoration(
              labelText: 'Submission Text',
              hintText: 'Enter your answer or description...',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            maxLines: 8,
          ),
          const SizedBox(height: 16),

          // --- Student File Upload Section ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your Attachments',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _pickFiles, // Now calls the pick logic
                        icon: const Icon(Icons.attach_file, size: 18),
                        label: const Text('Add File'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Allowed types: ${widget.assignment.allowedFileTypes.join(", ")}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    'Max size: ${(widget.assignment.maxFileSize / 1048576).toStringAsFixed(1)} MB',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),

                  // Display Student's Selected Files
                  if (_submissionFiles.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: _submissionFiles.asMap().entries.map((entry) {
                          final index = entry.key;
                          final file = entry.value;
                          return Column(
                            children: [
                              ListTile(
                                dense: true,
                                leading: _buildFilePreview(file),
                                title: Text(
                                  file.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13),
                                ),
                                subtitle: Text(
                                  '${(file.size / 1024).toStringAsFixed(1)} KB',
                                  style: GoogleFonts.poppins(fontSize: 11),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red),
                                  onPressed: () => _removeFile(index),
                                ),
                              ),
                              if (index != _submissionFiles.length - 1)
                                const Divider(height: 1),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ] else ...[
                    // Empty State
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.cloud_upload,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No files attached',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // -----------------------------------

          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: widget.assignment.isOpen ? _submitAssignment : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    widget.assignment.isOpen ? Colors.blue : Colors.grey,
              ),
              child: Text(
                widget.assignment.isOpen
                    ? 'Submit Assignment'
                    : 'Assignment Closed',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Submit Assignment', style: GoogleFonts.poppins()),
        ),
        body: _isLoadingSubmission
            ? const Center(child: CircularProgressIndicator())
            : _buildBody());
  }
}
