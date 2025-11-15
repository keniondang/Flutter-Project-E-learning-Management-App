import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/assignment.dart';
import '../../models/student.dart';
import '../../providers/assignment_submission_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class GradingScreen extends StatefulWidget {
  final AssignmentSubmission submission;
  final Assignment assignment;
  final Student student;
  final String instructorId;

  const GradingScreen({
    Key? key,
    required this.submission,
    required this.assignment,
    required this.student,
    required this.instructorId,
  }) : super(key: key);

  @override
  State<GradingScreen> createState() => _GradingScreenState();
}

class _GradingScreenState extends State<GradingScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _gradeController;
  late TextEditingController _feedbackController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _gradeController = TextEditingController(
      text: widget.submission.grade?.toString() ?? '',
    );
    _feedbackController = TextEditingController(
      text: widget.submission.feedback ?? '',
    );
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }

  Future<void> _submitGrade() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      
      final grade = double.tryParse(_gradeController.text);
      if (grade == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid grade'), backgroundColor: Colors.red),
        );
        setState(() => _isSaving = false);
        return;
      }
      
      final success = await context.read<AssignmentSubmissionProvider>().gradeSubmission(
        submissionId: widget.submission.id,
        grade: grade,
        feedback: _feedbackController.text,
        instructorId: widget.instructorId,
      );
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grade saved successfully'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save grade'), backgroundColor: Colors.red),
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
            // Student Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.student.fullName,
                      style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Submitted: ${DateFormat('MMM dd, yyyy HH:mm').format(widget.submission.submittedAt)}',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    if (widget.submission.isLate)
                      Text(
                        ' (LATE)',
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Submission Content
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Submission', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                    
                    if (widget.submission.submissionText != null && widget.submission.submissionText!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Submitted Text:', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                      Container(
                        padding: const EdgeInsets.all(12),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(widget.submission.submissionText!),
                      ),
                    ],

                    if (widget.submission.submissionFiles.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('Submitted Files:', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                      ...widget.submission.submissionFiles.map((fileUrl) {
                        return ListTile(
                          leading: const Icon(Icons.insert_drive_file),
                          title: Text(fileUrl.split('/').last, style: GoogleFonts.poppins(fontSize: 14)),
                          onTap: () => _openLink(fileUrl),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Grading Form
            Form(
              key: _formKey,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Grade & Feedback', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _gradeController,
                        decoration: InputDecoration(
                          labelText: 'Grade',
                          suffixText: '/ ${widget.assignment.totalPoints}',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                          if (grade < 0 || grade > widget.assignment.totalPoints) {
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        maxLines: 4,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _submitGrade,
                          child: _isSaving
                              ? const CircularProgressIndicator(color: Colors.white)
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