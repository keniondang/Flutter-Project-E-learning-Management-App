import 'dart:typed_data';

import 'package:elearning_management_app/screens/shared/private_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/course.dart';
import '../../models/student.dart';
import '../../models/user_model.dart';
import '../../providers/group_provider.dart';
import '../../providers/student_provider.dart';
import '../../providers/message_provider.dart';

enum PeopleSortOption { nameAsc, nameDesc, groupAsc }

class CoursePeopleTab extends StatefulWidget {
  final Course course;
  final UserModel user;

  const CoursePeopleTab({super.key, required this.course, required this.user});

  @override
  State<CoursePeopleTab> createState() => _CoursePeopleTabState();
}

class _CoursePeopleTabState extends State<CoursePeopleTab> {
  final TextEditingController _searchController = TextEditingController();
  PeopleSortOption _sortOption = PeopleSortOption.nameAsc;
  
  // State for Group Button Filter
  String? _selectedGroupId; // null means "All Groups"

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  String _getGroupName(Student student) {
    if (widget.course.groupIds.isNotEmpty) {
      // Find the group name corresponding to one of the course's group IDs
      final entry = student.groupMap.entries.firstWhere(
        (e) => widget.course.groupIds.contains(e.key),
        orElse: () => const MapEntry('', ''),
      );
      if (entry.value.isNotEmpty) return entry.value;
    }
    return 'No Group';
  }

  // --- Widget: Group Filter Buttons ---
  Widget _buildGroupFilterList() {
    final groups = context.watch<GroupProvider>().groups;

    if (groups.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Text("Filter Group:",
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          // "All" Button
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: const Text('All'),
              selected: _selectedGroupId == null,
              onSelected: (selected) {
                if (selected) setState(() => _selectedGroupId = null);
              },
              selectedColor: Colors.blue[100],
              labelStyle: TextStyle(
                color: _selectedGroupId == null ? Colors.blue[900] : Colors.black87,
                fontWeight:
                    _selectedGroupId == null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          // Individual Group Buttons
          ...groups.map((group) {
            final isSelected = _selectedGroupId == group.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(group.name),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _selectedGroupId = selected ? group.id : null);
                },
                selectedColor: Colors.blue[100],
                labelStyle: TextStyle(
                  color: isSelected ? Colors.blue[900] : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          }),
        ],
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

    // --- FILTER LOGIC ---
    List<Student> filteredStudents = studentProvider.students.where((student) {
      // 1. Text Search Filter
      final query = _searchController.text.toLowerCase();
      final nameMatch = student.fullName.toLowerCase().contains(query);
      final groupName = _getGroupName(student);
      final groupMatch = groupName.toLowerCase().contains(query);
      
      // 2. Group Button Filter
      bool groupButtonMatch = true;
      if (_selectedGroupId != null) {
        // Check if student belongs to the selected group ID
        groupButtonMatch = student.groupMap.containsKey(_selectedGroupId);
      }

      return (nameMatch || groupMatch) && groupButtonMatch;
    }).toList();

    // --- SORT LOGIC ---
    filteredStudents.sort((a, b) {
      switch (_sortOption) {
        case PeopleSortOption.nameAsc:
          return a.fullName.compareTo(b.fullName);
        case PeopleSortOption.nameDesc:
          return b.fullName.compareTo(a.fullName);
        case PeopleSortOption.groupAsc:
          final groupA = _getGroupName(a);
          final groupB = _getGroupName(b);
          int cmp = groupA.compareTo(groupB);
          if (cmp == 0) return a.fullName.compareTo(b.fullName);
          return cmp;
      }
    });

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
                        hasAvatar: false);
                    _openChat(instructor);
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
          ],

          // --- HEADER: Title & Count ---
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

          // --- CONTROLS: Search & Sort ---
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name...',
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  onChanged: (val) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<PeopleSortOption>(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.sort),
                ),
                tooltip: 'Sort Students',
                onSelected: (PeopleSortOption result) {
                  setState(() => _sortOption = result);
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem(
                    value: PeopleSortOption.nameAsc,
                    child: Text('Name (A-Z)'),
                  ),
                  const PopupMenuItem(
                    value: PeopleSortOption.nameDesc,
                    child: Text('Name (Z-A)'),
                  ),
                  const PopupMenuItem(
                    value: PeopleSortOption.groupAsc,
                    child: Text('Group (A-Z)'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // --- CONTROLS: Group Buttons ---
          _buildGroupFilterList(),
          
          const SizedBox(height: 16),

          // --- STUDENTS LIST ---
          if (filteredStudents.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text(
                      _searchController.text.isEmpty && _selectedGroupId == null
                          ? 'No students enrolled yet.'
                          : 'No matching students found.',
                      style: GoogleFonts.poppins(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          else
            ...filteredStudents.map((student) {
              final showMessageButton = widget.user.isInstructor;
              final isMe = student.id == widget.user.id;
              String groupName = _getGroupName(student);

              final hasAvatarImage = student.avatarBytes != null &&
                  student.avatarBytes!.isNotEmpty;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        isMe ? Colors.blue[100] : Colors.green[100],
                    backgroundImage: hasAvatarImage
                        ? MemoryImage(student.avatarBytes! as Uint8List)
                        : null,
                    child: hasAvatarImage
                        ? null
                        : Text(
                            student.fullName.isNotEmpty
                                ? student.fullName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                                color:
                                    isMe ? Colors.blue[700] : Colors.green[700],
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

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}