import 'package:elearning_management_app/providers/announcement_provider.dart';
import 'package:elearning_management_app/providers/assignment_provider.dart';
import 'package:elearning_management_app/providers/course_material_provider.dart';
import 'package:elearning_management_app/providers/quiz_provider.dart';
import 'package:elearning_management_app/providers/student_provider.dart';
import 'package:elearning_management_app/providers/student_quiz_provider.dart';
import 'package:elearning_management_app/screens/shared/announcement_detail_screen.dart'; // ✅ Import this!
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/course.dart';
import '../models/user_model.dart';
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

// Student screens
import 'student/assignment_submission_screen.dart';
import 'student/quiz_taking_screen.dart';
import 'student/material_viewer_screen.dart';
import 'shared/course_people_tab.dart'; // Ensure this exists

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

Future<void> _loadData() async {
    final courseId = widget.course.id;
    // Load all necessary data
    await Future.wait([
      // ✅ Fix: Pass widget.user.id
      context.read<AnnouncementProvider>().loadAllAnnouncements(courseId, widget.user.id),
      context.read<AssignmentProvider>().loadAssignments(courseId),
      context.read<QuizProvider>().loadQuizzes(courseId),
      context.read<CourseMaterialProvider>().loadCourseMaterials(courseId),
      if (widget.user.isStudent) ...[
        context.read<StudentQuizProvider>().loadQuizzesForStudent(courseId, widget.user.id),
      ]
    ]);
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
                 IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadData,
                 )
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
            _buildStreamTab(),
            _buildClassworkTab(),
            _buildPeopleTab(),
          ],
        ),
      ),
      floatingActionButton: widget.user.isInstructor
          ? FloatingActionButton(
              onPressed: _showCreateOptions,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  // --- STREAM TAB (Announcements) ---
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
            final hasViewed = announcement.hasViewed ?? false;

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                // ✅ THIS IS THE MISSING PART THAT NAVIGATES TO THE DETAIL SCREEN
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AnnouncementDetailScreen(
                        announcement: announcement,
                        currentUser: widget.user,
                      ),
                    ),
                  ).then((_) => _loadData()); // Refresh when coming back
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
                              ' ${announcement.fileAttachments.length} attachments',
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
  Widget _buildClassworkTab() {
     // Simplified for brevity - assumes you have your existing implementation here
     // or you can copy your previous CourseClassworkTab logic directly here
     return SingleChildScrollView(
       child: Column(
         children: [
           // Assignments
           _buildSectionHeader('Assignments'),
           Consumer<AssignmentProvider>(
             builder: (context, provider, _) => Column(
               children: provider.assignments.map((assignment) => ListTile(
                 leading: const Icon(Icons.assignment, color: Colors.orange),
                 title: Text(assignment.title),
                 subtitle: Text('Due: ${_formatDate(assignment.dueDate)}'),
                 onTap: () {
                    // Navigate based on role
                    if (widget.user.isInstructor) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => AssignmentResultsScreen(assignment: assignment, instructor: widget.user)));
                    } else {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => AssignmentSubmissionScreen(assignment: assignment, student: widget.user)));
                    }
                 },
               )).toList(),
             ),
           ),
           
           // Quizzes
           _buildSectionHeader('Quizzes'),
           Consumer<QuizProvider>(
             builder: (context, provider, _) => Column(
               children: provider.quizzes.map((quiz) => ListTile(
                 leading: const Icon(Icons.quiz, color: Colors.purple),
                 title: Text(quiz.title),
                 subtitle: Text('${quiz.durationMinutes} mins'),
                 onTap: () {
                    if (widget.user.isInstructor) {
                       Navigator.push(context, MaterialPageRoute(builder: (_) => QuizResultsScreen(quiz: quiz)));
                    } else {
                       Navigator.push(context, MaterialPageRoute(builder: (_) => QuizTakingScreen(quiz: quiz, student: widget.user)));
                    }
                 },
               )).toList(),
             ),
           ),

           // Materials
           _buildSectionHeader('Materials'),
           Consumer<CourseMaterialProvider>(
             builder: (context, provider, _) => Column(
               children: provider.materials.map((material) => ListTile(
                 leading: const Icon(Icons.book, color: Colors.green),
                 title: Text(material.title),
                 onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MaterialViewerScreen(material: material, student: widget.user))),
               )).toList(),
             ),
           ),
         ],
       ),
     );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
           title,
           style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[800]),
        ),
      ),
    );
  }

  // --- PEOPLE TAB ---
  Widget _buildPeopleTab() {
    return CoursePeopleTab(course: widget.course, user: widget.user);
  }

  void _showCreateOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.campaign),
            title: const Text('Announcement'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => CreateAnnouncementScreen(course: widget.course, instructorId: widget.user.id))).then((_) => _loadData());
            },
          ),
          ListTile(
            leading: const Icon(Icons.assignment),
            title: const Text('Assignment'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => CreateAssignmentScreen(course: widget.course, instructorId: widget.user.id))).then((_) => _loadData());
            },
          ),
          ListTile(
            leading: const Icon(Icons.quiz),
            title: const Text('Quiz'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => CreateQuizScreen(course: widget.course, instructorId: widget.user.id))).then((_) => _loadData());
            },
          ),
           ListTile(
            leading: const Icon(Icons.book),
            title: const Text('Material'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => CreateMaterialScreen(course: widget.course, instructorId: widget.user.id))).then((_) => _loadData());
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    // Simple date formatter
    return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// Helper for SliverAppBar TabBar
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