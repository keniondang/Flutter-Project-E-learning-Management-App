import 'package:elearning_management_app/models/course.dart';
import 'package:elearning_management_app/providers/student_course_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/semester.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../providers/semester_provider.dart';
import 'login_screen.dart';
import 'course_detail_screen.dart';
import 'student/student_dashboard_screen.dart';
import 'package:badges/badges.dart' as badges;
import 'shared/notification_screen.dart';
import '../../providers/notification_provider.dart';

// Enum to define sort options
enum CourseSortOption { nameAsc, nameDesc, codeAsc, sessionsDesc }

class StudentHomeScreen extends StatefulWidget {
  final UserModel user;

  const StudentHomeScreen({super.key, required this.user});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  Semester? _selectedSemester;
  CourseSortOption _currentSortOption = CourseSortOption.nameAsc;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSemesters();
    _loadNotifications();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        _selectedSemester = semesterProvider.currentSemester;
      });
    }
  }

  Future<Widget> _buildCourses(StudentCourseProvider provider) async {
    if (provider.currentSemester != _selectedSemester!.id) {
      await provider.loadEnrolledCourses(widget.user.id, _selectedSemester!.id);
    }

    List<Course> courses = provider.courses;

    courses = courses.where((course) {
      final matchesName = course.name.toLowerCase().contains(_searchQuery);
      final matchesCode = course.code.toLowerCase().contains(_searchQuery);
      return matchesName || matchesCode;
    }).toList();

    courses.sort((a, b) {
      switch (_currentSortOption) {
        case CourseSortOption.nameAsc:
          return a.name.compareTo(b.name);
        case CourseSortOption.nameDesc:
          return b.name.compareTo(a.name);
        case CourseSortOption.codeAsc:
          return a.code.compareTo(b.code);
        case CourseSortOption.sessionsDesc:
          return b.sessions.compareTo(a.sessions); // Assuming 'sessions' is int
      }
    });

    if (courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'No enrolled courses'
                  : 'No courses match your search',
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: courses.length,
      itemBuilder: (context, index) {
        final course = courses[index];
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
                // Course header with gradient
                Container(
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.primaries[index % Colors.primaries.length],
                        Colors.primaries[index % Colors.primaries.length]
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
    );
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
                    );
                  },
                ),
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
          // Welcome and Controls Section
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

                // Semester Dropdown
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
                      Expanded(
                        child: DropdownButton<Semester>(
                          isExpanded: true, // Prevent overflow
                          value: _selectedSemester,
                          items: semesterProvider.semesters.map((semester) {
                            return DropdownMenuItem(
                              value: semester,
                              child: Row(
                                children: [
                                  Flexible(
                                      child: Text(semester.name,
                                          overflow: TextOverflow.ellipsis)),
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
                          onChanged: (semester) {
                            setState(() {
                              semesterProvider.setCurrentSemester(semester!);
                              _selectedSemester =
                                  semesterProvider.currentSemester;
                            });
                          },
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Search and Sort Row
                Row(
                  children: [
                    // Search Bar
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search courses...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.toLowerCase();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Sort Button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: PopupMenuButton<CourseSortOption>(
                        icon: const Icon(Icons.sort),
                        tooltip: "Sort Courses",
                        onSelected: (CourseSortOption result) {
                          setState(() {
                            _currentSortOption = result;
                          });
                        },
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<CourseSortOption>>[
                          const PopupMenuItem<CourseSortOption>(
                            value: CourseSortOption.nameAsc,
                            child: Text('Name (A-Z)'),
                          ),
                          const PopupMenuItem<CourseSortOption>(
                            value: CourseSortOption.nameDesc,
                            child: Text('Name (Z-A)'),
                          ),
                          const PopupMenuItem<CourseSortOption>(
                            value: CourseSortOption.codeAsc,
                            child: Text('Course Code'),
                          ),
                          const PopupMenuItem<CourseSortOption>(
                            value: CourseSortOption.sessionsDesc,
                            child: Text('Sessions (High-Low)'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Courses List
          Expanded(child: Consumer2<SemesterProvider, StudentCourseProvider>(
            builder: (context, semesterProvider, studentProvider, child) {
              if (studentProvider.isLoading ||
                  semesterProvider.currentSemester == null ||
                  _selectedSemester == null) {
                return const Center(child: CircularProgressIndicator());
              }

              return FutureBuilder(
                future: _buildCourses(studentProvider),
                builder: (context, snapshot) {
                  switch (snapshot.connectionState) {
                    case ConnectionState.waiting:
                      return const Center(child: CircularProgressIndicator());
                    case ConnectionState.done:
                      return snapshot.data!;
                    default:
                      return const Center(child: CircularProgressIndicator());
                  }
                },
              );

              // Load data if needed
              // if (studentProvider.currentSemester != _selectedSemester!.id) {
              //   // Use addPostFrameCallback to avoid state errors during build
              //   studentProvider.loadEnrolledCourses(
              //       widget.user.id, _selectedSemester!.id);
              //   return const Center(child: CircularProgressIndicator());
              // }

              // 1. Filter Logic
            },
          )),
        ],
      ),
    );
  }
}
