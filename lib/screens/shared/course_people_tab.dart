import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/course.dart';
import '../../models/user_model.dart';
import '../../providers/group_provider.dart';
import '../../providers/student_provider.dart';

class CoursePeopleTab extends StatefulWidget {
  final Course course;
  final UserModel user;

  const CoursePeopleTab({Key? key, required this.course, required this.user})
      : super(key: key);

  @override
  State<CoursePeopleTab> createState() => _CoursePeopleTabState();
}

class _CoursePeopleTabState extends State<CoursePeopleTab> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Load both groups and students for this course
    await Future.wait([
      context.read<GroupProvider>().loadGroups(widget.course.id),
      context.read<StudentProvider>().loadStudentsForCourse(widget.course.id),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final groupProvider = context.watch<GroupProvider>();
    final studentProvider = context.watch<StudentProvider>();

    if (groupProvider.isLoading || studentProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (groupProvider.error != null || studentProvider.error != null) {
      return Center(
        child: Text(
          'Error loading data: ${groupProvider.error ?? studentProvider.error}',
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- Groups Section ---
        Text(
          'Groups',
          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (groupProvider.groups.isEmpty)
          Center(
            child: Text(
              'No groups in this course.',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          )
        else
          ...groupProvider.groups.map((group) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Icon(Icons.group, color: Colors.blue[700]),
                ),
                title: Text(
                  group.name,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  '${group.studentCount ?? 0} students',
                  style: GoogleFonts.poppins(fontSize: 12),
                ),
              ),
            );
          }),

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),

        // --- Students Section ---
        Text(
          'Students',
          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (studentProvider.students.isEmpty)
          Center(
            child: Text(
              'No students enrolled in this course.',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          )
        else
          ...studentProvider.students.map((student) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green[100],
                  child: Text(
                    student.fullName[0].toUpperCase(),
                    style: TextStyle(color: Colors.green[700]),
                  ),
                ),
                title: Text(
                  student.fullName,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  'Group: ${student.groupMap.entries.singleWhere((e) => widget.course.groupIds.contains(e.key), orElse: () => const MapEntry('', 'No group')).value}',
                  style: GoogleFonts.poppins(fontSize: 12),
                ),
              ),
            );
          }),
      ],
    );
  }
}
