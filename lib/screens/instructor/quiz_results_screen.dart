import 'package:elearning_management_app/providers/quiz_attempt_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/quiz.dart';
import '../../models/student.dart';
import '../../providers/student_provider.dart';

class QuizResultsScreen extends StatefulWidget {
  final Quiz quiz;

  const QuizResultsScreen({super.key, required this.quiz});

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

    _studentsFuture = widget.quiz.scopeType == 'all'
        ? context.read<StudentProvider>().loadStudentsInCourse(
              widget.quiz.courseId,
            )
        : context
            .read<StudentProvider>()
            .loadStudentsInGroups(widget.quiz.targetGroups);

    _loadData();
    _searchController.addListener(_filterSubmissions);
  }

  Future<void> _loadData() async {
    final submissionProvider = context.read<QuizAttemptProvider>();
    await submissionProvider.loadSubmissions(widget.quiz.id);

    _allStudents = await _studentsFuture;

    final query = _searchController.text.toLowerCase();
    _filteredStudents = _allStudents.where((student) {
      final studentName = student.fullName.toLowerCase();
      return studentName.contains(query);
    }).toList();

    if (mounted) {
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
              final provider = context.read<QuizAttemptProvider>();
              final error = await provider.exportSubmissionsToCSV(
                widget.quiz,
                _allStudents,
              );
              if (error != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error), backgroundColor: Colors.red),
                );
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Results exported successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            tooltip: 'Export to CSV',
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Summary
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Consumer<QuizAttemptProvider>(
              builder: (context, provider, child) {
                final totalStudents = _allStudents.length;
                final submittedCount = _allStudents
                    .where(
                        (s) => provider.getSubmissionForStudent(s.id) != null)
                    .length;
                final notSubmittedCount = totalStudents - submittedCount;

                // Calculate average of highest scores
                double totalScore = 0;
                int scoredCount = 0;
                for (var student in _allStudents) {
                  final submission =
                      provider.getSubmissionForStudent(student.id);
                  if (submission != null && submission.score != null) {
                    totalScore += submission.score!;
                    scoredCount++;
                  }
                }
                final averageScore =
                    scoredCount > 0 ? totalScore / scoredCount : 0.0;

                return Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Students',
                        totalStudents.toString(),
                        Icons.people,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Submitted',
                        submittedCount.toString(),
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Not Submitted',
                        notSubmittedCount.toString(),
                        Icons.pending,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Avg Score',
                        '${averageScore.toStringAsFixed(1)}/${widget.quiz.totalPoints}',
                        Icons.analytics,
                        Colors.purple,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

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
                  return const Center(
                    child: Text('No students enrolled in this course.'),
                  );
                }

                return Consumer<QuizAttemptProvider>(
                  builder: (context, submissionProvider, child) {
                    if (submissionProvider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (_filteredStudents.isEmpty &&
                        _searchController.text.isNotEmpty) {
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
                        // This now returns the HIGHEST scoring attempt
                        final submission = submissionProvider
                            .getSubmissionForStudent(student.id);

                        return _buildSubmissionTile(
                          student,
                          submission,
                          submissionProvider,
                        );
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

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionTile(
    Student student,
    QuizAttempt? submission,
    QuizAttemptProvider provider,
  ) {
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
      // Get all attempts to show total count
      final allAttempts =
          provider.submissions.where((s) => s.studentId == student.id).toList();
      final attemptCount = allAttempts.length;

      status = 'Submitted';
      statusColor = Colors.green;
      scoreText =
          '${(submission.score ?? 0.0).toStringAsFixed(1)} / ${widget.quiz.totalPoints}';
      scoreColor = _getScoreColor(
        (submission.score ?? 0.0) / widget.quiz.totalPoints * 100,
      );
      subtitle =
          'Best of $attemptCount attempt${attemptCount > 1 ? 's' : ''} • Last: ${DateFormat('MMM dd, HH:mm').format(submission.submittedAt!)}';
    }

    final percentage = submission?.score != null
        ? (submission!.score! / widget.quiz.totalPoints) * 100
        : 0.0;

    // Check for avatar bytes
    final hasAvatar =
        student.avatarBytes != null && student.avatarBytes!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          if (submission != null) {
            _showStudentAttemptsDialog(student, provider);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // UPDATED: Use Avatar Bytes if available
              CircleAvatar(
                backgroundColor: statusColor.withOpacity(0.1),
                backgroundImage: hasAvatar
                    ? MemoryImage(student.avatarBytes! as Uint8List)
                    : null,
                child: hasAvatar
                    ? null
                    : Text(
                        student.fullName.isNotEmpty
                            ? student.fullName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (submission != null) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getScoreColor(percentage),
                        ),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    scoreText,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                  if (submission != null)
                    Text(
                      '${percentage.toStringAsFixed(0)}%',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getScoreColor(double percentage) {
    if (percentage >= 80) return Colors.green[700]!;
    if (percentage >= 60) return Colors.blue[700]!;
    if (percentage >= 40) return Colors.orange[700]!;
    return Colors.red[700]!;
  }

  void _showStudentAttemptsDialog(
    Student student,
    QuizAttemptProvider provider,
  ) {
    final attempts = provider.submissions
        .where((s) => s.studentId == student.id)
        .toList()
      ..sort((a, b) => a.attemptNumber.compareTo(b.attemptNumber));

    final highestAttempt = provider.getSubmissionForStudent(student.id);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${student.fullName}\'s Attempts',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (attempts.isEmpty)
                const Text('No attempts found')
              else
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: attempts.length,
                  itemBuilder: (context, index) {
                    final attempt = attempts[index];
                    final isHighest = attempt.id == highestAttempt?.id;
                    final percentage =
                        (attempt.score ?? 0.0) / widget.quiz.totalPoints * 100;

                    return Card(
                      color: isHighest ? Colors.amber[50] : null,
                      child: ListTile(
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  _getScoreColor(percentage).withOpacity(0.1),
                              child: Text(
                                '#${attempt.attemptNumber}',
                                style: TextStyle(
                                  color: _getScoreColor(percentage),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isHighest)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber[700],
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.emoji_events,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Row(
                          children: [
                            Text(
                              'Attempt ${attempt.attemptNumber}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (isHighest) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber[700],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'HIGHEST',
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          DateFormat('MMM dd, HH:mm')
                              .format(attempt.submittedAt!),
                          style: GoogleFonts.poppins(fontSize: 11),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${attempt.score?.toStringAsFixed(1)}',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _getScoreColor(percentage),
                              ),
                            ),
                            Text(
                              '${percentage.toStringAsFixed(0)}%',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
