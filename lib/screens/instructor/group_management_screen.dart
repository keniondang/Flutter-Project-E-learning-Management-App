import 'package:elearning_management_app/providers/instructor_course_provider.dart';
import 'package:elearning_management_app/providers/student_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/course.dart';
import '../../models/group.dart';
import '../../models/semester.dart';
import '../../providers/group_provider.dart';
import '../../providers/semester_provider.dart';
import '../../services/csv_service.dart';
import 'group_students_screen.dart';

enum GroupSortOption { nameAsc, nameDesc, studentCountDesc, newest }

class GroupManagementScreen extends StatefulWidget {
  const GroupManagementScreen({super.key});

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  Semester? _selectedSemester;
  Course? _selectedCourse;

  // Search and Sort State
  final TextEditingController _searchController = TextEditingController();
  GroupSortOption _sortOption = GroupSortOption.nameAsc;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final semesterProvider = context.read<SemesterProvider>();
    await semesterProvider.loadSemesters();

    if (semesterProvider.semesters.isNotEmpty) {
      setState(() {
        _selectedSemester = semesterProvider.currentSemester ??
            semesterProvider.semesters.first;
      });

      if (_selectedSemester != null) {
        await context
            .read<InstructorCourseProvider>()
            .loadCourses(_selectedSemester!.id);
      }
    }
  }

  String _getSortLabel(GroupSortOption option) {
    switch (option) {
      case GroupSortOption.nameAsc:
        return 'Name (A-Z)';
      case GroupSortOption.nameDesc:
        return 'Name (Z-A)';
      case GroupSortOption.studentCountDesc:
        return 'Most Students';
      case GroupSortOption.newest:
        return 'Newest Created';
    }
  }

  // --- CSV IMPORT LOGIC START ---

  Future<void> _handleEnrollmentImport() async {
    if (_selectedCourse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a course first')),
      );
      return;
    }

    // 1. Pick CSV
    final result = await CSVService.pickAndParseCSV();
    if (result == null || !mounted) return;

    final data = result['data'] as List<Map<String, dynamic>>;
    final headers = result['headers'] as List<String>;

    // 2. Validate Headers
    if (!headers.contains('student_username') ||
        !headers.contains('group_name')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Invalid CSV. Required columns: student_username, group_name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 3. Show Smart Preview Dialog
    _showSmartPreviewDialog(data);
  }

  // Analyzes CSV data against current DB state without writing
  Future<List<Map<String, dynamic>>> _analyzeCsvData(
      List<Map<String, dynamic>> rawData) async {
    final studentProvider = context.read<StudentProvider>();
    final groupProvider = context.read<GroupProvider>();

    // 1. Ensure we have all necessary data loaded
    final allStudents = await studentProvider.fetchAllStudents();
    final currentGroups = groupProvider.groups;

    // Map for O(1) lookup
    final studentMap = {for (var s in allStudents) s.username: s};
    final groupMap = {for (var g in currentGroups) g.name: g};

    // 2. Pre-fetch enrollments for the groups mentioned in CSV
    // This allows us to check "Already Assigned" status locally
    final targetGroupIds = rawData
        .map((row) => groupMap[row['group_name']]?.id)
        .whereType<String>()
        .toSet()
        .toList();

    if (targetGroupIds.isNotEmpty) {
      await studentProvider.loadStudentsInGroups(targetGroupIds);
    }

    // 3. Analyze each row
    List<Map<String, dynamic>> analyzedRows = [];

    for (var row in rawData) {
      String username = row['student_username']?.toString().trim() ?? '';
      String groupName = row['group_name']?.toString().trim() ?? '';
      
      String status = 'Ready';
      Color color = Colors.green;
      bool isValid = true;

      final student = studentMap[username];
      final group = groupMap[groupName];

      if (student == null) {
        status = 'Student Not Found';
        color = Colors.red;
        isValid = false;
      } else if (group == null) {
        status = 'Group Not Found';
        color = Colors.red;
        isValid = false;
      } else {
        // Check if student is already in THIS specific group
        if (student.groupMap.containsKey(group.id)) {
          status = 'Already Assigned';
          color = Colors.orange;
          isValid = false; // We skip duplicates
        }
      }

      analyzedRows.add({
        'student_username': username,
        'group_name': groupName,
        'status': status,
        'color': color,
        'isValid': isValid,
      });
    }

    return analyzedRows;
  }

  void _showSmartPreviewDialog(List<Map<String, dynamic>> rawData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _analyzeCsvData(rawData),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Analyzing CSV data..."),
                  ],
                ),
              );
            }

            if (snapshot.hasError) {
              return AlertDialog(
                title: const Text("Error"),
                content: Text("Failed to analyze CSV: ${snapshot.error}"),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close"))
                ],
              );
            }

            final analyzedData = snapshot.data!;
            final validCount = analyzedData.where((r) => r['isValid']).length;
            final errorCount = analyzedData.length - validCount;

            return AlertDialog(
              title: Text(
                'Import Preview',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(4)),
                          child: Text('$validCount Ready',
                              style: TextStyle(
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(4)),
                          child: Text('$errorCount Skipped',
                              style: TextStyle(
                                  color: Colors.orange[900],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowHeight: 40,
                              dataRowMinHeight: 40,
                              headingRowColor:
                                  MaterialStateProperty.all(Colors.grey[100]),
                              columns: const [
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Student')),
                                DataColumn(label: Text('Group')),
                              ],
                              rows: analyzedData.map((row) {
                                return DataRow(
                                  color: MaterialStateProperty.all(
                                      (row['color'] as Color).withOpacity(0.1)),
                                  cells: [
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            row['isValid']
                                                ? Icons.check_circle
                                                : (row['status'] ==
                                                        'Already Assigned'
                                                    ? Icons.info
                                                    : Icons.cancel),
                                            size: 16,
                                            color: row['color'],
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            row['status'],
                                            style: TextStyle(
                                                color: row['color'],
                                                fontWeight: FontWeight.w600,
                                                fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(Text(row['student_username'])),
                                    DataCell(Text(row['group_name'])),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: validCount > 0
                      ? () {
                          Navigator.pop(context); // Close Preview
                          _executeImport(analyzedData);
                        }
                      : null,
                  child: Text('Import $validCount Students'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _executeImport(List<Map<String, dynamic>> analyzedData) async {
    final validRows = analyzedData.where((r) => r['isValid']).toList();

    if (validRows.isEmpty) return;

    // Show Loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Processing enrollments...')),
    );

    // Call Provider with _selectedCourse!.id
    final result = await context
        .read<StudentProvider>()
        .enrollMultipleStudents(validRows, _selectedCourse!.id);

    if (mounted) {
      _showResultDialog(result, analyzedData.length);
      // Refresh group stats
      if (_selectedCourse != null) {
        context.read<GroupProvider>().loadGroups(_selectedCourse!.id);
      }
    }
  }

  void _showResultDialog(Map<String, dynamic> result, int totalProcessed) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Processed $totalProcessed rows.'),
            const SizedBox(height: 8),
            Text('✅ Success: ${result['successCount']}'),
            Text('⚠️ Skipped (Duplicates): ${result['duplicateCount']}'),
            Text('❌ Errors: ${result['errorCount']}'),
            if ((result['errors'] as List).isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Details:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Container(
                height: 100,
                width: double.maxFinite,
                padding: const EdgeInsets.all(8),
                color: Colors.grey[100],
                child: ListView(
                  children: (result['errors'] as List)
                      .map((e) => Text(e.toString(),
                          style:
                              const TextStyle(color: Colors.red, fontSize: 12)))
                      .toList(),
                ),
              ),
            ]
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  // --- CSV IMPORT LOGIC END ---

  void _showAddEditDialog([Group? group]) {
    if (_selectedCourse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a course first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final isEdit = group != null;
    final nameController = TextEditingController(text: group?.name ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isEdit ? 'Edit Group' : 'Add New Group',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: 'Group Name',
            hintText: 'e.g., Group A',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a group name'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final provider = context.read<GroupProvider>();
              bool success;

              if (isEdit) {
                success = await provider.updateGroup(
                  id: group.id,
                  name: nameController.text,
                );
              } else {
                success = await provider.createGroup(
                  courseId: _selectedCourse!.id,
                  name: nameController.text,
                );
              }

              if (success && mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isEdit
                          ? 'Group updated successfully'
                          : 'Group added successfully',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(provider.error ?? 'Failed to save group'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(isEdit ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Group group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text(
          'Are you sure you want to delete "${group.name}"? This will also remove all student enrollments.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await context.read<GroupProvider>().deleteGroup(
                    group.id,
                  );

              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Group deleted successfully'),
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

  @override
  Widget build(BuildContext context) {
    final semesterProvider = context.watch<SemesterProvider>();
    final courseProvider = context.watch<InstructorCourseProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Group Management', style: GoogleFonts.poppins()),
        actions: [
          // NEW: Import Button
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: _handleEnrollmentImport,
            tooltip: 'Import Enrollments (CSV)',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditDialog(),
            tooltip: 'Add Group',
          ),
        ],
      ),
      body: Column(
        children: [
          // Selectors
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'Semester:',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<Semester>(
                        value: _selectedSemester,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: semesterProvider.semesters.map((semester) {
                          return DropdownMenuItem(
                            value: semester,
                            child: Text(semester.name),
                          );
                        }).toList(),
                        onChanged: (semester) async {
                          setState(() {
                            _selectedSemester = semester;
                            _selectedCourse = null;
                          });
                          if (semester != null) {
                            await context
                                .read<InstructorCourseProvider>()
                                .loadCourses(
                                  semester.id,
                                );
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Course:',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: DropdownButtonFormField<Course>(
                        value: _selectedCourse,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: courseProvider.courses.map((course) {
                          return DropdownMenuItem(
                            value: course,
                            child: Text('${course.code} - ${course.name}'),
                          );
                        }).toList(),
                        onChanged: (course) {
                          setState(() => _selectedCourse = course);
                          if (course != null) {
                            context.read<GroupProvider>().loadGroups(course.id);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search and Sort Bar
          if (_selectedCourse != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              color: Colors.grey[100],
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search groups...',
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (val) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  PopupMenuButton<GroupSortOption>(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.sort),
                    ),
                    tooltip: 'Sort Groups',
                    onSelected: (GroupSortOption result) {
                      setState(() => _sortOption = result);
                    },
                    itemBuilder: (context) => GroupSortOption.values.map((opt) {
                      return PopupMenuItem(
                        value: opt,
                        child: Text(_getSortLabel(opt)),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

          // Group List
          Expanded(
            child: Consumer<GroupProvider>(
              builder: (context, provider, child) {
                if (_selectedCourse == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 60,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Select a course to view groups',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Filtering & Sorting Logic
                List<Group> filteredGroups = provider.groups.where((group) {
                  final query = _searchController.text.toLowerCase();
                  return group.name.toLowerCase().contains(query);
                }).toList();

                filteredGroups.sort((a, b) {
                  switch (_sortOption) {
                    case GroupSortOption.nameAsc:
                      return a.name.compareTo(b.name);
                    case GroupSortOption.nameDesc:
                      return b.name.compareTo(a.name);
                    case GroupSortOption.studentCountDesc:
                      return (b.studentCount ?? 0)
                          .compareTo(a.studentCount ?? 0);
                    case GroupSortOption.newest:
                      return b.createdAt.compareTo(a.createdAt);
                  }
                });

                if (filteredGroups.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.group_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isEmpty
                              ? 'No groups yet'
                              : 'No groups match search',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (_searchController.text.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'for ${_selectedCourse!.name}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showAddEditDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Add First Group'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredGroups.length,
                  itemBuilder: (context, index) {
                    final group = filteredGroups[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          child: Icon(Icons.group, color: Colors.blue[700]),
                        ),
                        title: Text(
                          group.name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${group.studentCount ?? 0} students',
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.people, size: 20),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => GroupStudentsScreen(
                                      group: group,
                                      course: _selectedCourse!,
                                    ),
                                  ),
                                );
                              },
                              tooltip: 'Manage Students',
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _showAddEditDialog(group),
                              tooltip: 'Edit',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20),
                              onPressed: () => _confirmDelete(group),
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedCourse != null
          ? FloatingActionButton(
              onPressed: () => _showAddEditDialog(),
              child: const Icon(Icons.add),
              tooltip: 'Add Group',
            )
          : null,
    );
  }
}