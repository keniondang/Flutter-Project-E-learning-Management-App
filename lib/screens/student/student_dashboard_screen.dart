import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/user_model.dart';

class StudentDashboardScreen extends StatefulWidget {
  final UserModel student;

  const StudentDashboardScreen({Key? key, required this.student}) : super(key: key);

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  Map<String, dynamic> _dashboardData = {};
  List<Map<String, dynamic>> _upcomingDeadlines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      // Load dashboard statistics
      final stats = await _supabase
          .from('student_dashboard')
          .select()
          .eq('student_id', widget.student.id);

      // Load upcoming deadlines
      final now = DateTime.now();
      final deadlines = await _supabase
          .from('assignments')
          .select('*, courses(name)')
          .gte('due_date', now.toIso8601String())
          .order('due_date')
          .limit(5);

      setState(() {
        if (stats.isNotEmpty) {
          _dashboardData = stats.first;
        }
        _upcomingDeadlines = List<Map<String, dynamic>>.from(deadlines);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('My Dashboard', style: GoogleFonts.poppins()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress Overview
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Academic Progress',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildProgressRow(
                      'Assignments',
                      _dashboardData['submitted_assignments'] ?? 0,
                      _dashboardData['total_assignments'] ?? 0,
                      Colors.green,
                    ),
                    const SizedBox(height: 12),
                    _buildProgressRow(
                      'Quizzes',
                      _dashboardData['completed_quizzes'] ?? 0,
                      _dashboardData['total_quizzes'] ?? 0,
                      Colors.purple,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Upcoming Deadlines
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upcoming Deadlines',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_upcomingDeadlines.isEmpty)
                      Center(
                        child: Text(
                          'No upcoming deadlines',
                          style: GoogleFonts.poppins(color: Colors.grey[600]),
                        ),
                      )
                    else
                      ..._upcomingDeadlines.map((deadline) {
                        final dueDate = DateTime.parse(deadline['due_date']);
                        final daysLeft = dueDate.difference(DateTime.now()).inDays;
                        
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: daysLeft <= 2 
                                ? Colors.red[100] 
                                : Colors.blue[100],
                            child: Text(
                              daysLeft.toString(),
                              style: TextStyle(
                                color: daysLeft <= 2 
                                    ? Colors.red[700] 
                                    : Colors.blue[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            deadline['title'],
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            '${deadline['courses']['name']} • ${daysLeft == 0 ? "Today" : "$daysLeft days left"}',
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressRow(String label, int completed, int total, Color color) {
    final percentage = total > 0 ? (completed / total) : 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.poppins()),
            Text(
              '$completed / $total',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: percentage,
          backgroundColor: color.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
        ),
      ],
    );
  }
}