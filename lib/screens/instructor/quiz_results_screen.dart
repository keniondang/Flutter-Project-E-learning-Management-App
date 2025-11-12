import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/quiz.dart';
import '../../models/student.dart';
import '../../providers/quiz_submission_provider.dart';
import '../../providers/student_provider.dart';

class QuizResultsScreen extends StatefulWidget {
  final Quiz quiz;

  const QuizResultsScreen({Key? key, required this.quiz}) : super(key: key);

  @override
  State<QuizResultsScreen> createState() => _QuizResultsScreenState();
}

class _QuizResultsScreenState extends State<QuizResultsScreen> {
  final _searchController = TextEditingController();
  
  late Future<List<Student>> _studentsFuture;
  List<Student> _allStudents = [];
  List<Student> _filteredStudents = [];

  @override
  void initState() {
    super.initState();
    
    // ✅ --- THIS IS THE FIX --- ✅
    // Assign _studentsFuture *synchronously* here, before _loadData is called.
    // This guarantees it is initialized before the build method runs.
    _studentsFuture = context
        .read<StudentProvider>()
        .loadStudentsInCourse(widget.quiz.courseId);

    _loadData(); // Now _loadData will load submissions and await the future
    _searchController.addListener(_filterSubmissions);
  }

  Future<void> _loadData() async {
    // Load submissions
    final submissionProvider = context.read<QuizSubmissionProvider>();
    await submissionProvider.loadSubmissions(widget.quiz.id);

    // Await the future that was already started in initState
    _allStudents = await _studentsFuture;
    
    // Call _filterSubmissions without setState here, as it's just populating the list
    final query = _searchController.text.toLowerCase();
    _filteredStudents = _allStudents.where((student) {
        final studentName = student.fullName.toLowerCase();
        return studentName.contains(query);
      }).toList();
    
    // We call setState *after* the async gap to rebuild
    if(mounted) {
      setState(() {});
    }
  }

  void _filterSubmissions() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredStudents = _allStudents.where((student) {
          final studentName = student.fullName.toLowerCase();
          return studentName.contains(query);
        }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quiz Results', style: GoogleFonts.poppins(fontSize: 18)),
            Text(widget.quiz.title, style: GoogleFonts.poppins(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () async {
              // Pass student list to export
              final provider = context.read<QuizSubmissionProvider>();
              final error = await provider.exportSubmissionsToCSV(widget.quiz, _allStudents);
              if (error != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error), backgroundColor: Colors.red),
                );
              }
            },
            tooltip: 'Export to CSV',
          ),
        ],
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
                hintText: 'Search by student name...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          
          // Submissions list
          Expanded(
            child: FutureBuilder<List<Student>>(
              future: _studentsFuture, // This is now safely initialized
              builder: (context, studentSnapshot) {
                if (studentSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (studentSnapshot.hasError) {
                  return Center(child: Text('Error: ${studentSnapshot.error}'));
                }
                if (!studentSnapshot.hasData || studentSnapshot.data!.isEmpty) {
                  return Center(child: Text('No students enrolled in this course.'));
                }

                // Students loaded, now listen to submissions
                return Consumer<QuizSubmissionProvider>(
                  builder: (context, submissionProvider, child) {
                    if (submissionProvider.isLoading) {
                      // Show a loading indicator but keep the student list
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (_filteredStudents.isEmpty && _searchController.text.isNotEmpty) {
                      return Center(
                        child: Text(
                          'No students found',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      );
                    }
                    
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredStudents.length,
                      itemBuilder: (context, index) {
                        final student = _filteredStudents[index];
                        final submission = submissionProvider.getSubmissionForStudent(student.id);
                        
                        return _buildSubmissionTile(student, submission);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionTile(Student student, QuizAttempt? submission) {
    String status;
    Color statusColor;
    String scoreText;
    Color scoreColor;
    String subtitle;

    if (submission == null) {
      status = 'Not Submitted';
      statusColor = Colors.red;
      scoreText = '- / ${widget.quiz.totalPoints}';
      scoreColor = Colors.red;
      subtitle = 'No attempt found';
    } else {
      status = 'Submitted';
      statusColor = Colors.green;
      scoreText = '${(submission.score ?? 0.0).toStringAsFixed(1)} / ${widget.quiz.totalPoints}';
      scoreColor = Colors.green[700]!;
      subtitle = 'Attempt ${submission.attemptNumber} • Submitted: ${DateFormat('MMM dd, HH:mm').format(submission.submittedAt!)}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(student.fullName[0].toUpperCase()),
        ),
        title: Text(
          student.fullName,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              scoreText,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: scoreColor,
              ),
            ),
            Text(
              status,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: statusColor,
              ),
            ),
          ],
        ),
        onTap: () {
          if (submission != null) {
            // TODO: Navigate to a detailed view if needed
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${student.fullName}: ${submission.score} points'),
              ),
            );
          }
        },
      ),
    );
  }
}