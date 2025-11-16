import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/course.dart';
import '../services/auth_service.dart';
import '../providers/semester_provider.dart';
import 'login_screen.dart';
import 'course_detail_screen.dart';
import 'student/student_dashboard_screen.dart';
import 'package:badges/badges.dart' as badges;
import 'shared/notification_screen.dart';
import '../../providers/notification_provider.dart';

class StudentHomeScreen extends StatefulWidget {
  final UserModel user;

  const StudentHomeScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final AuthService _authService = AuthService();
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Course> _enrolledCourses = [];
  bool _isLoading = true;
  String? _selectedSemesterId;

  @override
  void initState() {
    super.initState();
    _loadSemesters();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    await context.read<NotificationProvider>().loadNotifications(
      widget.user.id,
    );
  }

  Future<void> _loadSemesters() async {
    final semesterProvider = context.read<SemesterProvider>();
    await semesterProvider.loadSemesters();

    if (semesterProvider.semesters.isNotEmpty) {
      setState(() {
        _selectedSemesterId =
            semesterProvider.currentSemester?.id ??
            semesterProvider.semesters.first.id;
      });
      _loadEnrolledCourses();
    }
  }

  Future<void> _loadEnrolledCourses() async {
    if (_selectedSemesterId == null) return;

    setState(() => _isLoading = true);

    try {
      // Get enrolled courses for the student
      final response = await _supabase
          .from('enrollments')
          .select('''
            groups!inner(
              course_id,
              courses!inner(
                id,
                code,
                name,
                sessions,
                cover_image,
                semester_id,
                created_at
              )
            )
          ''')
          .eq('student_id', widget.user.id)
          .eq('groups.courses.semester_id', _selectedSemesterId!);

      final courses = <Course>[];
      final seenCourseIds = <String>{};

      for (var enrollment in response as List) {
        final courseData = enrollment['groups']['courses'];
        final courseId = courseData['id'];

        // Avoid duplicate courses (student might be in multiple groups)
        if (!seenCourseIds.contains(courseId)) {
          seenCourseIds.add(courseId);
          courses.add(Course.fromJson(courseData));
        }
      }

      setState(() {
        _enrolledCourses = courses;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading enrolled courses: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final semesterProvider = context.watch<SemesterProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('My Courses', style: GoogleFonts.poppins()),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentDashboardScreen(student: widget.user),
                ),
              );
            },
            tooltip: 'Dashboard',
          ),
          Consumer<NotificationProvider>(
            builder: (context, notificationProvider, child) {
              return badges.Badge(
                showBadge: notificationProvider.unreadCount > 0,
                badgeContent: Text(
                  notificationProvider.unreadCount.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
                badgeStyle: const badges.BadgeStyle(badgeColor: Colors.red),
                position: badges.BadgePosition.topEnd(top: 8, end: 8),
                child: IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NotificationScreen(user: widget.user),
                      ),
                    ).then((_) => _loadNotifications());
                  },
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              // TODO: Navigate to profile
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile coming soon')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.logout();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome and semester selector
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, ${widget.user.fullName}!',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Semester: ',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (semesterProvider.semesters.isNotEmpty)
                      DropdownButton<String>(
                        value: _selectedSemesterId,
                        items: semesterProvider.semesters.map((semester) {
                          return DropdownMenuItem(
                            value: semester.id,
                            child: Row(
                              children: [
                                Text(semester.name),
                                if (semester.isCurrent)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'Current',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (semesterId) {
                          setState(() {
                            _selectedSemesterId = semesterId;
                          });
                          _loadEnrolledCourses();
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Courses section
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _enrolledCourses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No enrolled courses',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You are not enrolled in any courses this semester',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.of(context).size.width > 600
                          ? 3
                          : 2,
                      childAspectRatio: 1.2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _enrolledCourses.length,
                    itemBuilder: (context, index) {
                      final course = _enrolledCourses[index];
                      return Card(
                        elevation: 3,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CourseDetailScreen(
                                  course: course,
                                  user: widget.user,
                                ),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Course header
                              Container(
                                height: 80,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.primaries[index %
                                          Colors.primaries.length],
                                      Colors
                                          .primaries[index %
                                              Colors.primaries.length]
                                          .withOpacity(0.7),
                                    ],
                                  ),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(4),
                                    topRight: Radius.circular(4),
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.book,
                                    size: 40,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ),
                              // Course info
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        course.code,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        course.name,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.schedule,
                                            size: 14,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${course.sessions} sessions',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
