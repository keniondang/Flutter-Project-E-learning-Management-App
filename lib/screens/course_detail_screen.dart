import 'package:elearning_management_app/providers/announcement_provider.dart';
import 'package:elearning_management_app/providers/assignment_provider.dart';
import 'package:elearning_management_app/providers/course_material_provider.dart';
import 'package:elearning_management_app/providers/quiz_provider.dart';
import 'package:elearning_management_app/providers/student_provider.dart';
import 'package:elearning_management_app/providers/student_quiz_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// Models
import '../models/course.dart';
import '../models/user_model.dart';
import '../models/assignment.dart';
import '../models/quiz.dart';
import '../models/course_material.dart';

// Screens - Instructor
import 'instructor/create_announcement_screen.dart';
import 'instructor/create_assignment_screen.dart';
import 'instructor/create_quiz_screen.dart';
import 'instructor/create_material_screen.dart';
import 'instructor/question_bank_screen.dart';
import 'instructor/quiz_results_screen.dart';
import 'instructor/assignment_results_screen.dart';

// Screens - Student
import 'student/assignment_submission_screen.dart';
import 'student/quiz_taking_screen.dart';
import 'student/material_viewer_screen.dart';

// Screens - Shared
import 'package:elearning_management_app/screens/shared/announcement_detail_screen.dart';
import 'shared/course_people_tab.dart';
import 'shared/forum_screen.dart';

class CourseDetailScreen extends StatefulWidget {
  final Course course;
  final UserModel user;

  const CourseDetailScreen({super.key, required this.course, required this.user});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 3 Tabs: Stream (Announcements), Classwork, People
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // logic from File 2: Handles Student Groups correctly
  Future<void> _loadData() async {
    if (!mounted) return;

    if (widget.user.role == 'student') {
      // Fetch the specific group ID for the student in this course
      final groupId = context
          .read<StudentProvider>()
          .fetchStudentGroupIdInCourse(widget.user.id, widget.course.id);

      final resolvedGroupId = await groupId;

      if (!mounted) return;

      await Future.wait([
        // Assuming loadAnnouncements handles the group filtering
        context.read<AnnouncementProvider>().loadAllAnnouncements(widget.course.id, widget.user.id),
        context.read<AssignmentProvider>().loadAssignments(widget.course.id, resolvedGroupId),
        context.read<QuizProvider>().loadQuizzes(widget.course.id, resolvedGroupId),
        context.read<CourseMaterialProvider>().loadCourseMaterials(widget.course.id),
        context.read<StudentQuizProvider>().loadQuizzesForStudent(widget.course.id, widget.user.id),
      ]);
    } else {
      // Instructor Logic
      await Future.wait([
        // Use loadAllAnnouncements for instructors/admins
        context.read<AnnouncementProvider>().loadAllAnnouncements(widget.course.id, widget.user.id),
        context.read<AssignmentProvider>().loadAllAssignments(widget.course.id),
        context.read<QuizProvider>().loadAllQuizzes(widget.course.id),
        context.read<CourseMaterialProvider>().loadCourseMaterials(widget.course.id),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 200.0,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  widget.course.name,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      const Shadow(offset: Offset(0, 1), blurRadius: 3.0, color: Colors.black45),
                    ],
                  ),
                ),
                background: widget.course.coverImage != null
                    ? Image.network(
                        widget.course.coverImage!,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: Colors.blue,
                        child: const Center(
                          child: Icon(Icons.school, size: 60, color: Colors.white24),
                        ),
                      ),
              ),
              actions: [
                // Forum Button (From File 2)
                IconButton(
                  icon: const Icon(Icons.forum),
                  tooltip: 'Forum',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ForumScreen(course: widget.course, user: widget.user),
                      ),
                    );
                  },
                ),
                // Refresh Button (From File 1)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadData,
                ),
              ],
            ),
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.blue,
                  tabs: const [
                    Tab(text: 'Stream'),
                    Tab(text: 'Classwork'),
                    Tab(text: 'People'),
                  ],
                ),
              ),
              pinned: true,
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildStreamTab(),    // Combined Logic
            _buildClassworkTab(), // Detailed Logic from File 2
            _buildPeopleTab(),    // Standard
          ],
        ),
      ),
      // Instructor FAB (From File 1, but updated with File 2 options)
      floatingActionButton: widget.user.isInstructor
          ? FloatingActionButton(
              onPressed: _showCreateOptions,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  // --- STREAM TAB (Announcements) ---
  // UI from File 1 (Clickable Cards), Data logic integrated
  Widget _buildStreamTab() {
    return Consumer<AnnouncementProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.announcements.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.campaign_outlined, size: 60, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No announcements yet',
                  style: GoogleFonts.poppins(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: provider.announcements.length,
          itemBuilder: (context, index) {
            final announcement = provider.announcements[index];
            // Safe access for optional properties
            final hasViewed = announcement.hasViewed ?? false;

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  // Navigate to Detail Screen (From File 1)
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AnnouncementDetailScreen(
                        announcement: announcement,
                        currentUser: widget.user,
                      ),
                    ),
                  ).then((_) => _loadData()); 
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
                            child: Icon(Icons.person, size: 20, color: Colors.blue[700]),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  announcement.title,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Posted on ${_formatDate(announcement.createdAt)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12, 
                                    color: Colors.grey[600]
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!hasViewed && widget.user.isStudent)
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
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
                          Icon(Icons.remove_red_eye, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${announcement.viewCount ?? 0} views',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.comment_outlined, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${announcement.commentCount ?? 0} comments',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                          ),
                          const Spacer(),
                          if (announcement.fileAttachments.isNotEmpty) ...[
                             Icon(Icons.attach_file, size: 16, color: Colors.grey[600]),
                             Text(
                              ' ${announcement.fileAttachments.length}',
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                             )
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
    );
  }

  // --- CLASSWORK TAB ---
  // Detailed Logic from File 2 (Score colors, Attempts, Past Due checks)
  Widget _buildClassworkTab() {
    final assignmentProvider = context.watch<AssignmentProvider>();
    final quizProvider = context.watch<QuizProvider>();
    final courseMaterialProvider = context.watch<CourseMaterialProvider>();
    final studentQuizProvider = context.watch<StudentQuizProvider>();

    if (assignmentProvider.isLoading ||
        quizProvider.isLoading ||
        courseMaterialProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isStudent = widget.user.role == 'student';
    final isInstructor = widget.user.role == 'instructor';

    // Combine all items into one list
    final allContent = [
      ...assignmentProvider.assignments
          .map((a) => {'type': 'assignment', 'item': a}),
      ...quizProvider.quizzes.map((q) => {'type': 'quiz', 'item': q}),
      ...courseMaterialProvider.materials
          .map((m) => {'type': 'material', 'item': m}),
    ];

    if (allContent.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No classwork yet',
              style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // RefreshIndicator for pull-to-refresh behavior
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: allContent.length,
        itemBuilder: (context, index) {
          final content = allContent[index];
          final type = content['type'];
          final item = content['item'];

          // 1. ASSIGNMENT CARD
          if (type == 'assignment') {
            final assignment = item as Assignment;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green[100],
                  child: Icon(Icons.assignment, color: Colors.green[700]),
                ),
                title: Text(
                  assignment.title,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  isInstructor
                      ? 'Submissions: ${assignment.submissionCount ?? 0}'
                      : 'Due: ${_formatDate(assignment.dueDate)}',
                  style: GoogleFonts.poppins(fontSize: 12),
                ),
                trailing: assignment.isPastDue
                    ? Chip(
                        label: const Text('Past Due', style: TextStyle(fontSize: 10)),
                        backgroundColor: Colors.red[100],
                      )
                    : Chip(
                        label: const Text('Open', style: TextStyle(fontSize: 10)),
                        backgroundColor: Colors.green[100],
                      ),
                onTap: () {
                  if (isStudent) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AssignmentSubmissionScreen(
                          assignment: assignment,
                          student: widget.user,
                        ),
                      ),
                    );
                  }
                  if (isInstructor) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AssignmentResultsScreen(
                          assignment: assignment,
                          instructor: widget.user,
                        ),
                      ),
                    );
                  }
                },
              ),
            );
          } 
          
          // 2. QUIZ CARD (Detailed)
          else if (type == 'quiz') {
            final quiz = item as Quiz;

            int attemptCount = 0;
            double? highestScore;
            int remainingAttempts = quiz.maxAttempts;

            if (isStudent) {
              final attempts = studentQuizProvider.getAttemptsForQuiz(quiz.id);
              attemptCount = attempts.where((a) => a.isCompleted).length;
              highestScore = studentQuizProvider.getHighestScore(quiz.id);
              remainingAttempts = studentQuizProvider.getRemainingAttempts(quiz.id);
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () {
                  if (isStudent) {
                    if (quiz.isOpen) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => QuizTakingScreen(
                            quiz: quiz,
                            student: widget.user,
                          ),
                        ),
                      ).then((_) => _loadData()); // Refresh after taking quiz
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            quiz.isPastDue
                                ? 'This quiz is closed.'
                                : 'This quiz is not open yet.',
                          ),
                        ),
                      );
                    }
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QuizResultsScreen(quiz: quiz),
                      ),
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.purple[100],
                            child: Icon(Icons.quiz, color: Colors.purple[700]),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  quiz.title,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isInstructor
                                      ? 'Submissions: ${quiz.submissionCount ?? 0}'
                                      : 'Closes: ${_formatDate(quiz.closeTime)}',
                                  style: GoogleFonts.poppins(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          quiz.isPastDue
                              ? Chip(
                                  label: const Text('Closed', style: TextStyle(fontSize: 10)),
                                  backgroundColor: Colors.red[100],
                                )
                              : quiz.isOpen
                                  ? Chip(
                                      label: const Text('Open', style: TextStyle(fontSize: 10)),
                                      backgroundColor: Colors.green[100],
                                    )
                                  : Chip(
                                      label: const Text('Scheduled', style: TextStyle(fontSize: 10)),
                                      backgroundColor: Colors.orange[100],
                                    ),
                        ],
                      ),
                      // Student specific statistics
                      if (isStudent) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Attempts Box
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: remainingAttempts > 0 ? Colors.blue[50] : Colors.green[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: remainingAttempts > 0 ? Colors.blue : Colors.green,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.replay,
                                      size: 16,
                                      color: remainingAttempts > 0 ? Colors.blue[700] : Colors.green[700],
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '$attemptCount/${quiz.maxAttempts} attempts',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: remainingAttempts > 0 ? Colors.blue[700] : Colors.green[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Score Box
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: highestScore == null
                                      ? Colors.grey[100]
                                      : _getScoreColor(highestScore, quiz.totalPoints.toDouble()).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: highestScore == null
                                        ? Colors.grey
                                        : _getScoreColor(highestScore, quiz.totalPoints.toDouble()),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      highestScore == null ? Icons.block : Icons.emoji_events,
                                      size: 16,
                                      color: highestScore == null
                                          ? Colors.grey[600]
                                          : _getScoreColor(highestScore, quiz.totalPoints.toDouble()),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        highestScore == null
                                            ? 'Not attempted'
                                            : '${highestScore.toStringAsFixed(1)}/${quiz.totalPoints} (${((highestScore / quiz.totalPoints) * 100).toStringAsFixed(0)}%)',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: highestScore == null
                                              ? Colors.grey[600]
                                              : _getScoreColor(highestScore, quiz.totalPoints.toDouble()),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          } 
          
          // 3. MATERIAL CARD
          else {
            final material = item as CourseMaterial;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Icon(Icons.folder, color: Colors.blue[700]),
                ),
                title: Text(
                  material.title,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  material.description ?? 'No description',
                  style: GoogleFonts.poppins(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MaterialViewerScreen(
                        material: material,
                        student: widget.user,
                      ),
                    ),
                  );
                },
              ),
            );
          }
        },
      ),
    );
  }

  // --- PEOPLE TAB ---
  Widget _buildPeopleTab() {
    return CoursePeopleTab(course: widget.course, user: widget.user);
  }

  // --- INSTRUCTOR ACTIONS ---
  // Using BottomSheet from File 1, but added Question Bank from File 2
  void _showCreateOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40, height: 5,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
          ),
          ListTile(
            leading: const Icon(Icons.campaign, color: Colors.orange),
            title: const Text('Announcement'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => CreateAnnouncementScreen(course: widget.course, instructorId: widget.user.id))).then((_) => _loadData());
            },
          ),
          ListTile(
            leading: const Icon(Icons.assignment, color: Colors.green),
            title: const Text('Assignment'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => CreateAssignmentScreen(course: widget.course, instructorId: widget.user.id))).then((_) => _loadData());
            },
          ),
          ListTile(
            leading: const Icon(Icons.quiz, color: Colors.purple),
            title: const Text('Quiz'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => CreateQuizScreen(course: widget.course, instructorId: widget.user.id))).then((_) => _loadData());
            },
          ),
           ListTile(
            leading: const Icon(Icons.book, color: Colors.blue),
            title: const Text('Material'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => CreateMaterialScreen(course: widget.course, instructorId: widget.user.id))).then((_) => _loadData());
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.help_outline, color: Colors.teal),
            title: const Text('Question Bank'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => QuestionBankScreen(course: widget.course)));
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // --- HELPERS ---
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _getScoreColor(double score, double totalPoints) {
    if (totalPoints == 0) return Colors.grey;
    final percentage = (score / totalPoints) * 100;
    if (percentage >= 80) return Colors.green[700]!;
    if (percentage >= 60) return Colors.blue[700]!;
    if (percentage >= 40) return Colors.orange[700]!;
    return Colors.red[700]!;
  }
}

// Helper for SliverAppBar TabBar (From File 1)
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}