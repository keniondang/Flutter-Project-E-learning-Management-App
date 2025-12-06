import 'package:elearning_management_app/providers/instructor_course_provider.dart';
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

class GroupManagementScreen extends StatefulWidget {
  const GroupManagementScreen({super.key});

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  Semester? _selectedSemester;
  Course? _selectedCourse;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
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

  // ... (Rest of the file remains unchanged: _showCSVImportDialog, _handleCSVImport, _confirmDelete, build method)
  // Ensure you keep the rest of the existing code here.

  // void _showCSVImportDialog() {
  //   if (_selectedCourse == null) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text('Please select a course first'),
  //         backgroundColor: Colors.orange,
  //       ),
  //     );
  //     return;
  //   }

  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: Text(
  //         'Import Groups from CSV',
  //         style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
  //       ),
  //       content: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Text(
  //             'CSV Format Required:',
  //             style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
  //           ),
  //           const SizedBox(height: 8),
  //           Container(
  //             padding: const EdgeInsets.all(12),
  //             decoration: BoxDecoration(
  //               color: Colors.grey[100],
  //               borderRadius: BorderRadius.circular(8),
  //               border: Border.all(color: Colors.grey[300]!),
  //             ),
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 Text(
  //                   'group_name',
  //                   style: GoogleFonts.poppins(
  //                     fontSize: 12,
  //                     fontWeight: FontWeight.w600,
  //                   ),
  //                 ),
  //                 Text(
  //                   'Group A\nGroup B\nGroup C',
  //                   style: GoogleFonts.poppins(fontSize: 12),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ],
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: const Text('Cancel'),
  //         ),
  //         ElevatedButton.icon(
  //           onPressed: () async {
  //             Navigator.pop(context);
  //             _handleCSVImport();
  //           },
  //           icon: const Icon(Icons.upload_file),
  //           label: const Text('Choose CSV File'),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Future<void> _handleCSVImport() async {
    final result = await CSVService.pickAndParseCSV();

    if (result == null || !mounted) return;

    final data = result['data'] as List<Map<String, dynamic>>;
    final headers = result['headers'] as List<String>;

    if (!headers.contains('group_name')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid CSV format. Required column: group_name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _showCSVPreviewDialog(data);
  }

  void _showCSVPreviewDialog(List<Map<String, dynamic>> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Import Preview',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${data.length} groups will be imported',
                style: GoogleFonts.poppins(),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: data.take(10).map((row) {
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.group, size: 20),
                        title: Text(row['group_name'] ?? ''),
                      );
                    }).toList(),
                  ),
                ),
              ),
              if (data.length > 10)
                Text(
                  '... and ${data.length - 10} more',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
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
            onPressed: () async {
              Navigator.pop(context);

              final groupNames = data
                  .map((row) => row['group_name']?.toString() ?? '')
                  .where((name) => name.isNotEmpty)
                  .toList();

              final success =
                  await context.read<GroupProvider>().createMultipleGroups(
                        courseId: _selectedCourse!.id,
                        groupNames: groupNames,
                      );

              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${groupNames.length} groups imported successfully',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Import'),
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
          // IconButton(
          //   icon: const Icon(Icons.upload_file),
          //   onPressed: _showCSVImportDialog,
          //   tooltip: 'Import from CSV',
          // ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditDialog(),
            tooltip: 'Add Group',
          ),
        ],
      ),
      body: Column(
        children: [
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

                if (provider.groups.isEmpty) {
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
                          'No groups yet',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
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
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.groups.length,
                  itemBuilder: (context, index) {
                    final group = provider.groups[index];
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
