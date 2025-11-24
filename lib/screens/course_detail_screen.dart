import 'package:elearning_management_app/providers/announcement_provider.dart';
import 'package:elearning_management_app/providers/assignment_provider.dart';
import 'package:elearning_management_app/providers/course_material_provider.dart';
import 'package:elearning_management_app/providers/quiz_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/course.dart';
import '../models/user_model.dart';
import '../providers/content_provider.dart';
import 'instructor/create_announcement_screen.dart';
import 'instructor/create_assignment_screen.dart';
import 'instructor/create_quiz_screen.dart';
import 'instructor/create_material_screen.dart';
import 'instructor/question_bank_screen.dart';
import 'instructor/quiz_results_screen.dart';
import 'instructor/assignment_results_screen.dart';
import '../models/assignment.dart';
import '../models/quiz.dart';
import '../models/course_material.dart';

// Added for student navigation + forum
import 'student/assignment_submission_screen.dart';
import 'student/quiz_taking_screen.dart';
import 'student/material_viewer_screen.dart';
import 'shared/forum_screen.dart';
import 'shared/course_people_tab.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadContent();
  }

  Future<void> _loadContent() async {
    // ✅ FIX: Load ALL content types, not just announcements
    // Using Future.wait to load them in parallel for better performance
    await Future.wait([
      context.read<AnnouncementProvider>().loadAnnouncements(widget.course.id),
      context.read<AssignmentProvider>().loadAssignments(widget.course.id),
      context.read<QuizProvider>().loadQuizzes(widget.course.id),
      context.read<CourseMaterialProvider>().loadCourseMaterials(widget.course.id),
    ]);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isInstructor = widget.user.role == 'instructor';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.course.name, style: GoogleFonts.poppins(fontSize: 18)),
            Text(widget.course.code, style: GoogleFonts.poppins(fontSize: 12)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Stream', icon: Icon(Icons.stream)),
            Tab(text: 'Classwork', icon: Icon(Icons.assignment)),
            Tab(text: 'People', icon: Icon(Icons.people)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.forum),
            tooltip: 'Forum',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ForumScreen(course: widget.course, user: widget.user),
                ),
              );
            },
          ),
          if (isInstructor)
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'announcement':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateAnnouncementScreen(
                          course: widget.course,
                          instructorId: widget.user.id,
                        ),
                      ),
                    ).then((_) => _loadContent());
                    break;
                  case 'assignment':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateAssignmentScreen(
                          course: widget.course,
                          instructorId: widget.user.id,
                        ),
                      ),
                    ).then((_) => _loadContent());
                    break;
                  case 'quiz':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateQuizScreen(
                          course: widget.course,
                          instructorId: widget.user.id,
                        ),
                      ),
                    ).then((_) => _loadContent());
                    break;
                  case 'material':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateMaterialScreen(
                          course: widget.course,
                          instructorId: widget.user.id,
                        ),
                      ),
                    ).then((_) => _loadContent());
                    break;
                  case 'question_bank':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            QuestionBankScreen(course: widget.course),
                      ),
                    );
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'announcement',
                  child: Row(
                    children: [
                      Icon(Icons.announcement),
                      SizedBox(width: 8),
                      Text('Create Announcement'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'assignment',
                  child: Row(
                    children: [
                      Icon(Icons.assignment),
                      SizedBox(width: 8),
                      Text('Create Assignment'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'quiz',
                  child: Row(
                    children: [
                      Icon(Icons.quiz),
                      SizedBox(width: 8),
                      Text('Create Quiz'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'material',
                  child: Row(
                    children: [
                      Icon(Icons.folder),
                      SizedBox(width: 8),
                      Text('Add Material'),
                    ],
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: 'question_bank',
                  child: Row(
                    children: [
                      Icon(Icons.help_outline),
                      SizedBox(width: 8),
                      Text('Question Bank'),
                    ],
                  ),
                ),
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
                Icon(
                  Icons.announcement_outlined,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No announcements yet',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
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
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                announcement.title,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _formatDate(announcement.createdAt),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      announcement.content,
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                    if (announcement.fileAttachments.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: announcement.fileAttachments.map((file) {
                          return Chip(
                            avatar: const Icon(Icons.attach_file, size: 16),
                            label: Text(
                              'Attachment ${announcement.fileAttachments.indexOf(file) + 1}',
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.visibility,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${announcement.viewCount ?? 0} views',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.comment, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${announcement.commentCount ?? 0} comments',
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
            );
          },
        );
      },
    );
  }

  Widget _buildClassworkTab() {
    return Consumer3<AssignmentProvider, QuizProvider, CourseMaterialProvider>(
      builder: (context, assignmentProvider, quizProvider,
          courseMaterialProvider, child) {
        if (assignmentProvider.isLoading ||
            quizProvider.isLoading ||
            courseMaterialProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

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
                Icon(
                  Icons.assignment_outlined,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No classwork yet',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        final isStudent = widget.user.role == 'student';
        final isInstructor = widget.user.role == 'instructor';

        return ListView.builder(
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
                          label: const Text('Past Due'),
                          backgroundColor: Colors.red[100],
                        )
                      : Chip(
                          label: const Text('Open'),
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
            } else if (type == 'quiz') {
              final quiz = item as Quiz;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple[100],
                    child: Icon(Icons.quiz, color: Colors.purple[700]),
                  ),
                  title: Text(
                    quiz.title,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    isInstructor
                        ? 'Submissions: ${quiz.submissionCount ?? 0}'
                        : 'Closes: ${_formatDate(quiz.closeTime)}',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  trailing: quiz.isPastDue
                      ? Chip(
                          label: const Text('Closed'),
                          backgroundColor: Colors.red[100],
                        )
                      : quiz.isOpen
                          ? Chip(
                              label: const Text('Open'),
                              backgroundColor: Colors.green[100],
                            )
                          : Chip(
                              label: const Text('Scheduled'),
                              backgroundColor: Colors.orange[100],
                            ),
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
                        );
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
                      // Is instructor
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => QuizResultsScreen(quiz: quiz),
                        ),
                      );
                    }
                  },
                ),
              );
            } else {
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
        );
      },
    );
  }

  Widget _buildPeopleTab() {
    return CoursePeopleTab(course: widget.course, user: widget.user);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}