import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../providers/semester_provider.dart';
import 'login_screen.dart';
import 'instructor/semester_management_screen.dart';
import 'instructor/course_management_screen.dart';
import 'instructor/group_management_screen.dart';
import 'instructor/student_management_screen.dart';
import 'course_detail_screen.dart';

class InstructorHomeScreen extends StatelessWidget {
  final UserModel user;
  final AuthService _authService = AuthService();

  InstructorHomeScreen({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Instructor Dashboard',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.logout();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome message
            Text(
              'Welcome, ${user.fullName}!',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Instructor',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Semester selector
            Consumer<SemesterProvider>(
              builder: (context, semesterProvider, child) {
                if (semesterProvider.semesters.isEmpty && !semesterProvider.isLoading) {
                  semesterProvider.loadSemesters();
                }
                
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Semester',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              semesterProvider.currentSemester?.name ?? 'No semester selected',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SemesterManagementScreen(),
                              ),
                            );
                          },
                          child: Text(
                            semesterProvider.semesters.isEmpty ? 'Create Semester' : 'Manage',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Dashboard Stats
            Text(
              'Dashboard Overview',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            
            // Stats grid
            LayoutBuilder(
              builder: (context, constraints) {
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: constraints.maxWidth > 600 ? 4 : 2,
                  childAspectRatio: constraints.maxWidth > 600 ? 1.5 : 1.2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildStatCard('Total Courses', '0', Icons.book, Colors.blue),
                    _buildStatCard('Total Students', '0', Icons.people, Colors.green),
                    _buildStatCard('Total Groups', '0', Icons.group, Colors.orange),
                    _buildStatCard('Total Assignments', '0', Icons.assignment, Colors.purple),
                    _buildStatCard('Total Quizzes', '0', Icons.quiz, Colors.red),
                    _buildStatCard('Total Materials', '0', Icons.folder, Colors.teal),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),

            // Quick Actions Section
            Text(
              'Quick Actions',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildActionButton(
                  context,
                  'Manage Semesters',
                  Icons.calendar_today,
                  Colors.blue,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SemesterManagementScreen(),
                      ),
                    );
                  },
                ),
                _buildActionButton(
                  context,
                  'Manage Courses',
                  Icons.book,
                  Colors.green,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CourseManagementScreen(user: user),
                      ),
                    );
                  },
                ),
                _buildActionButton(
                  context,
                  'Manage Groups',
                  Icons.group_work,
                  Colors.orange,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const GroupManagementScreen(),
                      ),
                    );
                  },
                ),
                _buildActionButton(
                  context,
                  'Manage Students',
                  Icons.people,
                  Colors.purple,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StudentManagementScreen(),
                      ),
                    );
                  },
                ),
                _buildActionButton(
                  context,
                  'View Courses',
                  Icons.class_,
                  Colors.indigo,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CourseManagementScreen(user: user),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}