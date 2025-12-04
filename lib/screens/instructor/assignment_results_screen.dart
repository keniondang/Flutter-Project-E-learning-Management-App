import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/assignment.dart';
import '../../models/student.dart';
import '../../models/user_model.dart';
import '../../providers/assignment_submission_provider.dart';
import '../../providers/student_provider.dart';
import 'grading_screen.dart';

class AssignmentResultsScreen extends StatefulWidget {
  final Assignment assignment;
  final UserModel instructor;

  const AssignmentResultsScreen({
    Key? key,
    required this.assignment,
    required this.instructor,
  }) : super(key: key);

  @override
  State<AssignmentResultsScreen> createState() =>
      _AssignmentResultsScreenState();
}

class _AssignmentResultsScreenState extends State<AssignmentResultsScreen> {
  late Future<List<Student>> _studentsFuture;
  final _searchController = TextEditingController();
  List<Student> _allStudents = [];
  List<Student> _filteredStudents = [];

  @override
  void initState() {
    super.initState();
    // Assign future synchronously to prevent late init error
    _studentsFuture = context.read<StudentProvider>().loadStudentsInCourse(
          widget.assignment.courseId,
        );

    _loadData();
    _searchController.addListener(_filterStudents);
  }

  Future<void> _loadData() async {
    // Load submissions into the provider
    final submissionProvider = context.read<AssignmentSubmissionProvider>();
    await submissionProvider.loadAllSubmissions(widget.assignment.id);

    // Await the future
    _allStudents = await _studentsFuture;
    _filterStudents();

    if (mounted) {
      setState(() {});
    }
  }

  void _filterStudents() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStudents = _allStudents.where((student) {
        return student.fullName.toLowerCase().contains(query) ||
            student.username.toLowerCase().contains(query);
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
            Text('Submissions', style: GoogleFonts.poppins(fontSize: 18)),
            Text(
              widget.assignment.title,
              style: GoogleFonts.poppins(fontSize: 12),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
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
          Expanded(
            child: FutureBuilder<List<Student>>(
              future: _studentsFuture,
              builder: (context, studentSnapshot) {
                if (studentSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (studentSnapshot.hasError) {
                  return Center(child: Text('Error: ${studentSnapshot.error}'));
                }
                if (!studentSnapshot.hasData || studentSnapshot.data!.isEmpty) {
                  return Center(
                    child: Text('No students enrolled in this course.'),
                  );
                }

                // Students loaded, now listen to submissions
                return Consumer<AssignmentSubmissionProvider>(
                  builder: (context, submissionProvider, child) {
                    if (submissionProvider.isLoading &&
                        _filteredStudents.isEmpty) {
                      // Only show full loading if student list is also empty
                      return const Center(child: CircularProgressIndicator());
                    }

                    return ListView.builder(
                      itemCount: _filteredStudents.length,
                      itemBuilder: (context, index) {
                        final student = _filteredStudents[index];
                        final submission = submissionProvider
                            .getSubmissionForStudent(student.id);

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

  Widget _buildSubmissionTile(
    Student student,
    AssignmentSubmission? submission,
  ) {
    String status;
    Color statusColor;
    Widget trailing;

    if (submission == null) {
      status = 'Not Submitted';
      statusColor = Colors.red;
      trailing = Icon(Icons.close, color: statusColor);
    } else if (submission.grade != null) {
      status = 'Graded: ${submission.grade}/${widget.assignment.totalPoints}';
      statusColor = Colors.green;
      trailing = Icon(Icons.check_circle, color: statusColor);
    } else if (submission.isLate) {
      status = 'Submitted (Late)';
      statusColor = Colors.orange;
      trailing = Icon(Icons.warning, color: statusColor);
    } else {
      status = 'Submitted (On Time)';
      statusColor = Colors.blue;
      trailing = Icon(Icons.pending, color: statusColor);
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(child: Text(student.fullName[0].toUpperCase())),
        title: Text(
          student.fullName,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          status,
          style: GoogleFonts.poppins(
            color: statusColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: trailing,
        onTap: () {
          if (submission != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GradingScreen(
                  submission: submission,
                  assignment: widget.assignment,
                  student: student,
                  instructorId: widget.instructor.id,
                ),
              ),
            ).then((_) => _loadData()); // Refresh after grading
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Student has not submitted yet.')),
            );
          }
        },
      ),
    );
  }
}
