import 'package:elearning_management_app/providers/assignment_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/assignment.dart';
import '../../models/student.dart';
import '../../providers/assignment_submission_provider.dart';

class GradingScreen extends StatefulWidget {
  final AssignmentSubmission submission;
  final Assignment assignment;
  final Student student;
  final String instructorId;

  const GradingScreen({
    super.key,
    required this.submission,
    required this.assignment,
    required this.student,
    required this.instructorId,
  });

  @override
  State<GradingScreen> createState() => _GradingScreenState();
}

class _GradingScreenState extends State<GradingScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _gradeController;
  late TextEditingController _feedbackController;
  bool _isSaving = false;

  // --- NEW: State for History ---
  late AssignmentSubmission _selectedSubmission;
  List<AssignmentSubmission> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _initializeControllers();
  }

  void _initializeControllers() {
    _gradeController = TextEditingController(
      text: _selectedSubmission.grade?.toString() ?? '',
    );
    _feedbackController = TextEditingController(
      text: _selectedSubmission.feedback ?? '',
    );
  }

  void _updateControllers() {
    setState(() {
      _gradeController.text = _selectedSubmission.grade?.toString() ?? '';
      _feedbackController.text = _selectedSubmission.feedback ?? '';
    });
  }

  void _loadHistory() {
    final provider = context.read<AssignmentSubmissionProvider>();
    
    // 1. Get all submissions for this student from the provider
    // (Provider was already loaded in the previous screen)
    final allSubmissions = provider.submissions
        .where((s) => s.studentId == widget.student.id)
        .toList();

    // 2. Sort by attempt number descending (Latest first)
    allSubmissions.sort((a, b) => b.attemptNumber.compareTo(a.attemptNumber));

    // 3. Initialize state
    setState(() {
      _history = allSubmissions;
      
      // If for some reason history is empty, fallback to the passed submission
      if (_history.isEmpty) {
        _history = [widget.submission];
      }

      // Default to the passed submission if possible, otherwise the first (latest)
      try {
        _selectedSubmission = _history.firstWhere((s) => s.id == widget.submission.id);
      } catch (e) {
        _selectedSubmission = _history.first;
      }
    });
  }

  // --- Helper to clean filename ---
  String _cleanFileName(String path) {
    final fullName = path.split('/').last;
    final regex = RegExp(r'^\d+_(.+)');
    final match = regex.firstMatch(fullName);
    if (match != null) {
      return match.group(1) ?? fullName;
    }
    return fullName;
  }

  Future<void> _handleFileDownload(String url) async {
    final fileName = _cleanFileName(url); // Clean name for saving

    final bytes = await context
        .read<AssignmentSubmissionProvider>()
        .fetchFileAttachment(url);

    if (bytes != null) {
      await FilePicker.platform.saveFile(fileName: fileName, bytes: bytes);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error downloading $fileName'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _submitGrade() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      final grade = double.tryParse(_gradeController.text);
      if (grade == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid grade'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSaving = false);
        return;
      }

      final success =
          await context.read<AssignmentSubmissionProvider>().gradeSubmission(
                submissionId: _selectedSubmission.id, // Grade the SELECTED version
                grade: grade,
                feedback: _feedbackController.text,
                instructorId: widget.instructorId,
              );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Grade saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // We don't pop immediately so they can keep editing or change versions
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save grade'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Grade Assignment', style: GoogleFonts.poppins()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Student Info Card ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.student.fullName,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // --- VERSION SELECTOR ---
                    if (_history.length > 1) ...[
                      DropdownButtonFormField<AssignmentSubmission>(
                        value: _selectedSubmission,
                        decoration: InputDecoration(
                          labelText: 'Select Version to Grade',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: _history.map((submission) {
                          final isLatest = submission.attemptNumber == _history.first.attemptNumber;
                          return DropdownMenuItem(
                            value: submission,
                            child: Text(
                              'Attempt ${submission.attemptNumber}${isLatest ? ' (Latest)' : ''}',
                              style: GoogleFonts.poppins(fontWeight: isLatest ? FontWeight.bold : FontWeight.normal),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedSubmission = value;
                              _updateControllers(); // Update form with this version's data
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          'Submitted: ${DateFormat('MMM dd, yyyy HH:mm').format(_selectedSubmission.submittedAt)}',
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                      ],
                    ),
                    if (_selectedSubmission.isLate)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'LATE SUBMISSION',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- Submission Content ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Submission Content',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    
                    // Text Submission
                    if (_selectedSubmission.submissionText != null &&
                        _selectedSubmission.submissionText!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Student Answer:',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(12),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Text(_selectedSubmission.submissionText!),
                      ),
                    ],

                    // File Attachments
                    if (_selectedSubmission.submissionFiles.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Attached Files:',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 4),
                      ..._selectedSubmission.submissionFiles.map((fileUrl) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[200]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
                            title: Text(
                              _cleanFileName(fileUrl),
                              style: GoogleFonts.poppins(fontSize: 14),
                            ),
                            trailing: const Icon(Icons.download_rounded),
                            onTap: () => _handleFileDownload(fileUrl),
                          ),
                        );
                      }),
                    ] else if (_selectedSubmission.submissionText == null || _selectedSubmission.submissionText!.isEmpty) ...[
                       const Padding(
                         padding: EdgeInsets.symmetric(vertical: 16.0),
                         child: Center(child: Text("No content submitted.")),
                       )
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- Grading Form ---
            Form(
              key: _formKey,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Grade & Feedback',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _gradeController,
                        decoration: InputDecoration(
                          labelText: 'Grade',
                          suffixText: '/ ${widget.assignment.totalPoints}',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a grade';
                          }
                          final grade = double.tryParse(value);
                          if (grade == null) {
                            return 'Invalid number';
                          }
                          if (grade < 0 ||
                              grade > widget.assignment.totalPoints) {
                            return 'Grade must be between 0 and ${widget.assignment.totalPoints}';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _feedbackController,
                        decoration: InputDecoration(
                          labelText: 'Feedback (Optional)',
                          hintText: 'Provide feedback for the student...',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        maxLines: 4,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _submitGrade,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Save Grade'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}