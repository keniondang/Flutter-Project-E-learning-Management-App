import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/course.dart';
import '../../models/group.dart';
import '../../models/student.dart';
import '../../providers/group_provider.dart';
import '../../providers/student_provider.dart';

class GroupStudentsScreen extends StatefulWidget {
  final Group group;
  final Course course;

  const GroupStudentsScreen({
    Key? key,
    required this.group,
    required this.course,
  }) : super(key: key);

  @override
  State<GroupStudentsScreen> createState() => _GroupStudentsScreenState();
}

class _GroupStudentsScreenState extends State<GroupStudentsScreen> {
  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    // This populates the provider.students list with ONLY this group's members
    await context.read<StudentProvider>().loadStudentsInGroup(widget.group.id);
  }

  void _showAddStudentDialog() {
    Student? selectedStudent;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              'Add Student to ${widget.group.name}',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            content: FutureBuilder<List<Student>>(
              future: context.read<StudentProvider>().fetchAllStudents(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data == null) {
                  return const Text('Error loading students');
                }

                // ✅ --- FIX 1: FILTERING --- ✅
                // Get the list of students already in this group (from the main provider state)
                final studentsInGroup = context
                    .read<StudentProvider>()
                    .students;
                final studentIdsInGroup = studentsInGroup
                    .map((s) => s.id)
                    .toSet();

                // Get all students and filter out the ones already in the group
                final allStudents = snapshot.data!;
                final availableStudents = allStudents
                    .where((student) => !studentIdsInGroup.contains(student.id))
                    .toList();

                return DropdownButtonFormField<Student>(
                  // ✅ --- FIX 2: THE RED SCREEN ERROR --- ✅
                  // The `hint` property tells the dropdown what to show when
                  // `value` (selectedStudent) is null. This fixes the assertion error.
                  value: selectedStudent,
                  hint: const Text('Select a student'),

                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),

                  // Use the newly filtered list
                  items: availableStudents.map((student) {
                    return DropdownMenuItem(
                      value: student,
                      child: Text('${student.fullName} (${student.username})'),
                    );
                  }).toList(),
                  onChanged: (student) {
                    setState(() => selectedStudent = student);
                  },
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedStudent == null
                    ? null
                    : () async {
                        final provider = context.read<StudentProvider>();

                        final success = await provider.enrollStudentInGroup(
                          studentId: selectedStudent!.id,
                          groupId: widget.group.id,
                          courseId: widget.course.id,
                        );

                        if (success && mounted) {
                          Navigator.pop(context);
                          await _loadStudents();
                          context
                              .read<GroupProvider>()
                              .refreshCurrentCourseGroups();

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Student added successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                provider.error ?? 'Failed to add student',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmRemoveStudent(Student student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Student'),
        content: Text(
          'Are you sure you want to remove ${student.fullName} from ${widget.group.name}?',
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
                  .read<StudentProvider>()
                  .removeStudentFromGroup(
                    studentId: student.id,
                    groupId: widget.group.id,
                  );

              if (success && mounted) {
                await _loadStudents();
                context.read<GroupProvider>().refreshCurrentCourseGroups();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Student removed successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.group.name, style: GoogleFonts.poppins(fontSize: 18)),
            Text(widget.course.name, style: GoogleFonts.poppins(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _showAddStudentDialog,
            tooltip: 'Add Student',
          ),
        ],
      ),
      body: Consumer<StudentProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.students.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No students in this group',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showAddStudentDialog,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add Students'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.students.length,
            itemBuilder: (context, index) {
              final student = provider.students[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue[100],
                    child: Text(
                      student.fullName[0].toUpperCase(),
                      style: TextStyle(color: Colors.blue[700]),
                    ),
                  ),
                  title: Text(
                    student.fullName,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'Username: ${student.username} | Email: ${student.email}',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red,
                    ),
                    onPressed: () => _confirmRemoveStudent(student),
                    tooltip: 'Remove from group',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
