import 'package:elearning_management_app/screens/shared/private_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/course.dart';
import '../../models/user_model.dart';
import '../../providers/group_provider.dart';
import '../../providers/student_provider.dart';
import '../../providers/message_provider.dart';

class CoursePeopleTab extends StatefulWidget {
  final Course course;
  final UserModel user;

  const CoursePeopleTab({super.key, required this.course, required this.user});

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
    await Future.wait([
      context.read<GroupProvider>().loadGroups(widget.course.id),
      context.read<StudentProvider>().loadStudentsForCourse(widget.course.id),
    ]);
  }

  void _openChat(UserModel target) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => MessageProvider(),
          child: PrivateChatScreen(
            currentUser: widget.user,
            targetUser: target,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupProvider = context.watch<GroupProvider>();
    final studentProvider = context.watch<StudentProvider>();

    if (groupProvider.isLoading || studentProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- INSTRUCTOR SECTION (Visible only to Students) ---
          if (widget.user.isStudent) ...[
            Text(
              'Instructor',
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              color: Colors.blue[50],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: const CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: Text(
                  'Course Instructor',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, color: Colors.blue[900]),
                ),
                subtitle: Text(
                  'Tap to send a private message',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.blue[700]),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.message, color: Colors.blue),
                  onPressed: () {
                    if (widget.course.instructorId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                "Instructor not assigned to this course.")),
                      );
                      return;
                    }

                    final instructor = UserModel(
                      id: widget.course.instructorId!,
                      email: '',
                      username: 'Instructor',
                      fullName: 'Instructor',
                      role: 'instructor',
                    );
                    _openChat(instructor);
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
          ],

          // --- STUDENTS SECTION ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Students',
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${studentProvider.students.length}',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, color: Colors.grey[700]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (studentProvider.students.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.people_outline,
                        size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text(
                      'No students enrolled yet.',
                      style: GoogleFonts.poppins(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          else
            ...studentProvider.students.map((student) {
              // LOGIC: Show message button ONLY if current user is Instructor
              // Students CANNOT message other students
              final showMessageButton = widget.user.isInstructor;
              final isMe = student.id == widget.user.id;

              // Find group name safely
              String groupName = 'No Group';
              if (widget.course.groupIds.isNotEmpty) {
                final entry = student.groupMap.entries.firstWhere(
                  (e) => widget.course.groupIds.contains(e.key),
                  orElse: () => const MapEntry('', ''),
                );
                if (entry.value.isNotEmpty) groupName = entry.value;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        isMe ? Colors.blue[100] : Colors.green[100],
                    child: Text(
                      student.fullName.isNotEmpty
                          ? student.fullName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          color: isMe ? Colors.blue[700] : Colors.green[700],
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    isMe ? '${student.fullName} (You)' : student.fullName,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    groupName,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.grey[600]),
                  ),
                  trailing: showMessageButton && !isMe
                      ? IconButton(
                          icon: const Icon(Icons.message_outlined,
                              color: Colors.blue),
                          tooltip: 'Message Student',
                          onPressed: () => _openChat(student),
                        )
                      : null,
                ),
              );
            }),

          // Add some bottom padding for floating action buttons
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
