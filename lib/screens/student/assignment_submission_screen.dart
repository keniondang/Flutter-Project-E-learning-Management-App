import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/assignment.dart';
import '../../models/user_model.dart';

class AssignmentSubmissionScreen extends StatefulWidget {
  final Assignment assignment;
  final UserModel student;

  const AssignmentSubmissionScreen({
    Key? key,
    required this.assignment,
    required this.student,
  }) : super(key: key);

  @override
  State<AssignmentSubmissionScreen> createState() => _AssignmentSubmissionScreenState();
}

class _AssignmentSubmissionScreenState extends State<AssignmentSubmissionScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _submissionTextController = TextEditingController();
  
  List<String> _submissionFiles = [];
  AssignmentSubmission? _existingSubmission;
  bool _isLoading = true;
  int _currentAttempt = 1;

  @override
  void initState() {
    super.initState();
    _loadExistingSubmission();
  }

  Future<void> _loadExistingSubmission() async {
    try {
      final response = await _supabase
          .from('assignment_submissions')
          .select()
          .eq('assignment_id', widget.assignment.id)
          .eq('student_id', widget.student.id)
          .order('attempt_number', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _existingSubmission = AssignmentSubmission.fromJson({
            ...response,
            'student_name': widget.student.fullName,
          });
          _currentAttempt = (_existingSubmission!.attemptNumber) + 1;
          _submissionTextController.text = _existingSubmission!.submissionText ?? '';
        });
      }
    } catch (e) {
      print('Error loading submission: $e');
    } finally {
      setState(() => _isLoading = false);
    }
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

    try {
      await _supabase.from('assignment_submissions').insert({
        'assignment_id': widget.assignment.id,
        'student_id': widget.student.id,
        'submission_text': _submissionTextController.text,
        'submission_files': _submissionFiles,
        'attempt_number': _currentAttempt,
        'is_late': isLate,
        'submitted_at': now.toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting assignment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final now = DateTime.now();
    final isLate = now.isAfter(widget.assignment.dueDate);
    final daysUntilDue = widget.assignment.dueDate.difference(now).inDays;
    final hoursUntilDue = widget.assignment.dueDate.difference(now).inHours % 24;

    return Scaffold(
      appBar: AppBar(
        title: Text('Submit Assignment', style: GoogleFonts.poppins()),
      ),
      body: SingleChildScrollView(
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
                    Divider(),
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
                                color: isLate ? Colors.orange[700] : Colors.blue[700],
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

            // File upload section
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
                          'Attachments',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            // TODO: Implement file picker
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('File upload will be implemented later'),
                              ),
                            );
                          },
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
                    if (_submissionFiles.isEmpty)
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
                              Icon(Icons.cloud_upload, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text(
                                'No files attached',
                                style: GoogleFonts.poppins(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: widget.assignment.isOpen ? _submitAssignment : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.assignment.isOpen ? Colors.blue : Colors.grey,
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
      ),
    );
  }
}