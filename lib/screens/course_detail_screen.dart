import 'package:elearning_management_app/providers/announcement_provider.dart';
import 'package:elearning_management_app/providers/assignment_provider.dart';
import 'package:elearning_management_app/providers/course_material_provider.dart';
import 'package:elearning_management_app/providers/quiz_provider.dart';
import 'package:elearning_management_app/providers/student_provider.dart';
import 'package:elearning_management_app/providers/student_quiz_provider.dart';
import 'package:elearning_management_app/screens/shared/announcement_detail_screen.dart';
import 'package:elearning_management_app/screens/shared/forum_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/assignment.dart';
import '../models/course.dart';
import '../models/course_material.dart';
import '../models/quiz.dart';
import '../models/user_model.dart';
import '../providers/assignment_submission_provider.dart';
import '../providers/quiz_attempt_provider.dart';
import '../services/csv_export_service.dart';
import 'instructor/assignment_results_screen.dart';
import 'instructor/create_announcement_screen.dart';
import 'instructor/create_assignment_screen.dart';
import 'instructor/create_material_screen.dart';
import 'instructor/create_quiz_screen.dart';
import 'instructor/question_bank_screen.dart';
import 'instructor/quiz_results_screen.dart';
import 'shared/course_people_tab.dart';
import 'shared/material_viewer_screen.dart';
import 'student/assignment_submission_screen.dart';
import 'student/quiz_taking_screen.dart';

class CourseDetailScreen extends StatefulWidget {
  final Course course;
  final UserModel user;

  const CourseDetailScreen(
      {super.key, required this.course, required this.user});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // CSV export loading state
  bool _isExportingCsv = false;

  // --- STREAM FILTERING ---
  final TextEditingController _streamSearchController = TextEditingController();
  bool _streamSortNewestFirst = true;

  @override
  Widget build(BuildContext context) {
    final isInstructor = widget.user.isInstructor;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.course.name,
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            Text(widget.course.code, style: GoogleFonts.poppins(fontSize: 12)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(text: 'Stream', icon: Icon(Icons.stream)),
            Tab(text: 'Classwork', icon: Icon(Icons.assignment)),
            Tab(text: 'People', icon: Icon(Icons.people)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.forum),
            tooltip: 'Forums',
            onPressed: () async {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        ForumScreen(course: widget.course, user: widget.user)),
              );
            },
          ),
          if (_isExportingCsv)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
            ),
          if (isInstructor)
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'export_csv':
                    _exportGradebook();
                    break;
                  case 'announcement':
                    Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => CreateAnnouncementScreen(
                                    course: widget.course,
                                    instructorId: widget.user.id)))
                        .then((_) => _loadData());
                    break;
                  case 'assignment':
                    Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => CreateAssignmentScreen(
                                    course: widget.course,
                                    instructorId: widget.user.id)))
                        .then((_) => _loadData());
                    break;
                  case 'quiz':
                    Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => CreateQuizScreen(
                                    course: widget.course,
                                    instructorId: widget.user.id)))
                        .then((_) => _loadData());
                    break;
                  case 'material':
                    Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => CreateMaterialScreen(
                                    course: widget.course,
                                    instructorId: widget.user.id)))
                        .then((_) => _loadData());
                    break;
                  case 'question_bank':
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                QuestionBankScreen(course: widget.course)));
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'export_csv',
                  child: Row(
                    children: [
                      Icon(Icons.table_chart, color: Colors.blue),
                      SizedBox(width: 8),
                      Text("Export Gradebook (CSV)"),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                    value: 'announcement',
                    child: Row(children: [
                      Icon(Icons.campaign, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Announcement')
                    ])),
                const PopupMenuItem(
                    value: 'assignment',
                    child: Row(children: [
                      Icon(Icons.assignment, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Assignment')
                    ])),
                const PopupMenuItem(
                    value: 'quiz',
                    child: Row(children: [
                      Icon(Icons.quiz, color: Colors.purple),
                      SizedBox(width: 8),
                      Text('Quiz')
                    ])),
                const PopupMenuItem(
                    value: 'material',
                    child: Row(children: [
                      Icon(Icons.book, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Material')
                    ])),
                const PopupMenuDivider(),
                const PopupMenuItem(
                    value: 'question_bank',
                    child: Row(children: [
                      Icon(Icons.help_outline, color: Colors.teal),
                      SizedBox(width: 8),
                      Text('Question Bank')
                    ])),
              ],
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStreamTab(),
          _buildClassworkTab(),
          _buildPeopleTab(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _streamSearchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  // ---------------- CLASSWORK TAB -----------------

  Widget _buildClassworkTab() {
    final assignmentProvider = context.watch<AssignmentProvider>();
    final quizProvider = context.watch<QuizProvider>();
    final materialProvider = context.watch<CourseMaterialProvider>();
    final studentQuizProvider = context.watch<StudentQuizProvider>();

    if (assignmentProvider.isLoading ||
        quizProvider.isLoading ||
        materialProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isStudent = widget.user.role == 'student';
    final isInstructor = widget.user.role == 'instructor';

    final allContent = [
      ...assignmentProvider.assignments
          .map((a) => {'type': 'assignment', 'item': a}),
      ...quizProvider.quizzes.map((q) => {'type': 'quiz', 'item': q}),
      ...materialProvider.materials.map((m) => {'type': 'material', 'item': m}),
    ];

    if (allContent.isEmpty) {
      return const Center(child: Text("No classwork yet"));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: allContent.length,
        itemBuilder: (context, index) {
          final content = allContent[index];
          final type = content['type'];
          final item = content['item'];

          if (type == 'assignment') {
            final assignment = item as Assignment;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                    backgroundColor: Colors.green[100],
                    child: Icon(Icons.assignment, color: Colors.green[700])),
                title: Text(assignment.title,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    isInstructor
                        ? 'Submissions: ${assignment.submissionCount ?? 0}'
                        : 'Due: ${_formatDate(assignment.dueDate)}',
                    style: GoogleFonts.poppins(fontSize: 12)),
                trailing: assignment.isPastDue
                    ? Chip(
                        label: const Text('Past Due'),
                        backgroundColor: Colors.red[100])
                    : Chip(
                        label: const Text('Open'),
                        backgroundColor: Colors.green[100]),
                onTap: () {
                  if (isStudent) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => AssignmentSubmissionScreen(
                                assignment: assignment, student: widget.user)));
                  } else {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => AssignmentResultsScreen(
                                assignment: assignment,
                                instructor: widget.user)));
                  }
                },
              ),
            );
          }

          if (type == 'quiz') {
            final quiz = item as Quiz;

            if (isStudent) {
              // Pre-calculate quiz attempts for better UX if needed
              // final attempts = studentQuizProvider.getAttemptsForQuiz(quiz.id);
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                    backgroundColor: Colors.purple[100],
                    child: Icon(Icons.quiz, color: Colors.purple[700])),
                title: Text(quiz.title,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    isInstructor
                        ? 'Submissions: ${quiz.submissionCount ?? 0}'
                        : 'Closes: ${_formatDate(quiz.closeTime)}',
                    style: GoogleFonts.poppins(fontSize: 12)),
                trailing: quiz.isPastDue
                    ? const Chip(label: Text('Closed'))
                    : quiz.isOpen
                        ? const Chip(label: Text('Open'))
                        : const Chip(label: Text('Scheduled')),
                onTap: () {
                  if (isStudent) {
                    if (quiz.isOpen) {
                      Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => QuizTakingScreen(
                                      quiz: quiz, student: widget.user)))
                          .then((_) => _loadData());
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("This quiz is closed")));
                    }
                  } else {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => QuizResultsScreen(quiz: quiz)));
                  }
                },
              ),
            );
          }

          // MATERIAL
          final material = item as CourseMaterial;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Icon(Icons.folder, color: Colors.blue[700])),
              title: Text(material.title,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              subtitle: Text(material.description ?? "No description"),
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => MaterialViewerScreen(
                            material: material, user: widget.user)));
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildPeopleTab() {
    return CoursePeopleTab(course: widget.course, user: widget.user);
  }

  Widget _buildStreamTab() {
    return Column(
      children: [
        // Search + Sorting Section (SAME ROW)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _streamSearchController,
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  onChanged: (val) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              // Compact Sort Button
              InkWell(
                onTap: () {
                  setState(() {
                    _streamSortNewestFirst = !_streamSortNewestFirst;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        _streamSortNewestFirst ? 'Newest' : 'Oldest',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _streamSortNewestFirst
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                        size: 18,
                        color: Colors.grey[800],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Announcement List
        Expanded(
          child: Consumer<AnnouncementProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              // filtering logic
              var filteredList = provider.announcements.where((a) {
                final query = _streamSearchController.text.toLowerCase();
                final matchesSearch = a.title.toLowerCase().contains(query) ||
                    a.content.toLowerCase().contains(query);

                return matchesSearch;
              }).toList();

              filteredList.sort((a, b) {
                return _streamSortNewestFirst
                    ? b.createdAt.compareTo(a.createdAt)
                    : a.createdAt.compareTo(b.createdAt);
              });

              if (filteredList.isEmpty) {
                return const Center(child: Text("No announcements"));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredList.length,
                itemBuilder: (context, index) {
                  final announcement = filteredList[index];

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AnnouncementDetailScreen(
                              announcement: announcement,
                              currentUser: widget.user,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.blue[100],
                                  radius: 16,
                                  child: Icon(Icons.announcement,
                                      size: 20, color: Colors.blue[700]),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        announcement.title,
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16),
                                      ),
                                      Text(
                                        'Posted on ${_formatDate(announcement.createdAt)}',
                                        style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              announcement.content,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(fontSize: 14),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.comment_outlined,
                                    size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                    '${announcement.commentCount ?? 0} comments'),
                                const Spacer(),
                                if (announcement
                                    .fileAttachments.isNotEmpty) ...[
                                  Icon(Icons.attach_file,
                                      size: 16, color: Colors.grey[600]),
                                  Text(
                                      ' ${announcement.fileAttachments.length}'),
                                ]
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _exportGradebook() async {
    setState(() => _isExportingCsv = true);

    try {
      final courseId = widget.course.id;

      final studentProvider = context.read<StudentProvider>();
      final assignmentProvider = context.read<AssignmentProvider>();
      final quizProvider = context.read<QuizProvider>();
      final submissionProvider = context.read<AssignmentSubmissionProvider>();
      final attemptProvider = context.read<QuizAttemptProvider>();

      await studentProvider.loadStudentsInCourse(courseId);
      final students = studentProvider.students;

      final assignments = assignmentProvider.assignments;
      final quizzes = quizProvider.quizzes;

      List<AssignmentSubmission> allSubs = [];
      List<QuizAttempt> allAttempts = [];

      for (var a in assignments) {
        await submissionProvider.loadAllSubmissions(a.id);
        allSubs.addAll(submissionProvider.submissions);
      }

      for (var q in quizzes) {
        await attemptProvider.loadSubmissions(q.id);
        allAttempts.addAll(attemptProvider.submissions);
      }

      await CsvExportService().exportCourseGradebook(
        courseName: widget.course.name,
        students: students,
        assignments: assignments,
        quizzes: quizzes,
        allSubmissions: allSubs,
        allAttempts: allAttempts,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("CSV Exported to Downloads")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Export failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _isExportingCsv = false);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    if (widget.user.role == 'student') {
      final groupId = await context
          .read<StudentProvider>()
          .fetchStudentGroupIdInCourse(widget.user.id, widget.course.id);

      if (!mounted) return;

      await Future.wait([
        context
            .read<AnnouncementProvider>()
            .loadAnnouncements(widget.course.id, widget.user.id, groupId),
        context
            .read<AssignmentProvider>()
            .loadAssignments(widget.course.id, groupId),
        context.read<QuizProvider>().loadQuizzes(widget.course.id, groupId),
        context
            .read<CourseMaterialProvider>()
            .loadCourseMaterials(widget.course.id),
        context
            .read<StudentQuizProvider>()
            .loadQuizzesForStudent(widget.course.id, widget.user.id),
      ]);
    } else {
      await Future.wait([
        context
            .read<AnnouncementProvider>()
            .loadAllAnnouncements(widget.course.id, widget.user.id),
        context.read<AssignmentProvider>().loadAllAssignments(widget.course.id),
        context.read<QuizProvider>().loadAllQuizzes(widget.course.id),
        context
            .read<CourseMaterialProvider>()
            .loadCourseMaterials(widget.course.id),
      ]);
    }
  }
}
