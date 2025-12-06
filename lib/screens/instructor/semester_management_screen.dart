import 'package:elearning_management_app/providers/assignment_provider.dart';
import 'package:elearning_management_app/providers/assignment_submission_provider.dart';
import 'package:elearning_management_app/providers/instructor_course_provider.dart';
import 'package:elearning_management_app/providers/quiz_attempt_provider.dart';
import 'package:elearning_management_app/providers/quiz_provider.dart';
import 'package:elearning_management_app/providers/student_provider.dart';
import 'package:elearning_management_app/services/csv_export_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/semester.dart';
import '../../providers/semester_provider.dart';

class SemesterManagementScreen extends StatefulWidget {
  const SemesterManagementScreen({Key? key}) : super(key: key);

  @override
  State<SemesterManagementScreen> createState() =>
      _SemesterManagementScreenState();
}

class _SemesterManagementScreenState extends State<SemesterManagementScreen> {
  bool _isExporting = false; // Loading state

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<SemesterProvider>().loadSemesters());
  }

  void _showAddEditDialog([Semester? semester]) {
    final isEdit = semester != null;
    final codeController = TextEditingController(text: semester?.code ?? '');
    final nameController = TextEditingController(text: semester?.name ?? '');
    bool setAsCurrent = semester?.isCurrent ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            isEdit ? 'Edit Semester' : 'Add New Semester',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: InputDecoration(
                  labelText: 'Semester Code',
                  hintText: 'e.g., 2025-1',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Semester Name',
                  hintText: 'e.g., Fall 2025',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: Text(
                  'Set as Current Semester',
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                value: setAsCurrent,
                onChanged: (value) {
                  setState(() => setAsCurrent = value ?? false);
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (codeController.text.isEmpty ||
                    nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all fields'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final provider = context.read<SemesterProvider>();
                bool success;

                if (isEdit) {
                  success = await provider.updateSemester(
                    semester.id,
                    codeController.text,
                    nameController.text,
                    setAsCurrent,
                  );
                } else {
                  success = await provider.createSemester(
                    codeController.text,
                    nameController.text,
                    setAsCurrent,
                  );
                }

                if (success && mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEdit
                            ? 'Semester updated successfully'
                            : 'Semester added successfully',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: Text(isEdit ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Semester semester) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Semester'),
        content: Text(
          'Are you sure you want to delete "${semester.name}"? This will also delete all associated courses.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await context
                  .read<SemesterProvider>()
                  .deleteSemester(semester.id);

              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Semester deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // --- NEW: Semester Export Logic ---
  Future<void> _handleSemesterExport(Semester semester) async {
    setState(() => _isExporting = true);
    
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gathering semester data...')),
      );

      // 1. Get Providers
      final courseProvider = context.read<InstructorCourseProvider>();
      final studentProvider = context.read<StudentProvider>();
      final assignmentProvider = context.read<AssignmentProvider>();
      final submissionProvider = context.read<AssignmentSubmissionProvider>();
      final quizProvider = context.read<QuizProvider>();
      final attemptProvider = context.read<QuizAttemptProvider>();

      // 2. Load all courses for this semester
      await courseProvider.loadCourses(semester.id);
      final courses = courseProvider.courses;

      if (courses.isEmpty) {
        throw Exception("No courses found in this semester.");
      }

      // 3. Load all students (to map IDs to Names and get Base List)
      await studentProvider.loadAllStudents();
      final allStudents = studentProvider.students;

      // Data Structure: Map<StudentId, Map<CourseName, ScoreString>>
      Map<String, Map<String, String>> studentGrades = {};

      // Initialize map for all students
      for (var s in allStudents) {
        studentGrades[s.id] = {};
      }

      // 4. Iterate EVERY Course
      for (var course in courses) {
        // Load Course Content
        await assignmentProvider.loadAllAssignments(course.id);
        await quizProvider.loadAllQuizzes(course.id);
        
        final assignments = assignmentProvider.assignments;
        final quizzes = quizProvider.quizzes;

        // Load Enrollment for this course to filter relevant students
        // Capture the returned list!
        final enrolledStudents = await studentProvider.loadStudentsInCourse(course.id);
        
        // Process Enrolled Students
        for (var student in enrolledStudents) {
          double totalScore = 0;

          // Calculate Assignment Scores
          for (var assignment in assignments) {
            // Fetch submission (cache or DB)
            final sub = await submissionProvider.fetchStudentSubmission(assignment.id, student.id);
            if (sub != null && sub.grade != null) {
              totalScore += sub.grade!;
            }
          }

          // Calculate Quiz Scores
          for (var quiz in quizzes) {
            // Load attempts
            await attemptProvider.loadSubmissions(quiz.id); 
            final bestAttempt = attemptProvider.getSubmissionForStudent(student.id);
            
            if (bestAttempt != null && bestAttempt.score != null) {
              totalScore += bestAttempt.score!;
            }
          }

          // Store the total score for this student in this course
          studentGrades[student.id]?[course.name] = totalScore.toStringAsFixed(2);
        }
      }

      // 5. Generate CSV
      await CsvExportService().exportSemesterSummary(
        semesterName: semester.name,
        courseNames: courses.map((c) => c.name).toList(),
        allStudents: allStudents,
        studentGrades: studentGrades,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Semester Report exported to Downloads'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Semester Management', style: GoogleFonts.poppins()),
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)),
            )
          else
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddEditDialog(),
              tooltip: 'Add Semester',
            ),
        ],
      ),
      body: Consumer<SemesterProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error loading semesters',
                    style: GoogleFonts.poppins(fontSize: 18, color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  Text(provider.error!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.loadSemesters(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (provider.semesters.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No semesters yet',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddEditDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Semester'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.semesters.length,
            itemBuilder: (context, index) {
              final semester = provider.semesters[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: semester.isCurrent
                        ? Colors.green
                        : Colors.grey[400],
                    child: const Icon(Icons.calendar_month, color: Colors.white),
                  ),
                  title: Text(
                    semester.name,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Code: ${semester.code}',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                      if (semester.isCurrent)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Current',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --- EXPORT BUTTON ---
                      IconButton(
                        icon: const Icon(Icons.download, color: Colors.blue),
                        tooltip: 'Export Report',
                        onPressed: _isExporting ? null : () => _handleSemesterExport(semester),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _showAddEditDialog(semester),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        onPressed: () => _confirmDelete(semester),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add),
        tooltip: 'Add Semester',
      ),
    );
  }
}