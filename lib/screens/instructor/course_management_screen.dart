import 'package:elearning_management_app/providers/instructor_course_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/course.dart';
import '../../models/semester.dart';
import '../../models/user_model.dart';
import '../../providers/semester_provider.dart';
import '../course_detail_screen.dart';

// 1. Define Sort Options
enum CourseSortOption {
  codeAsc,
  nameAsc,
  sessionsDesc,
  studentsDesc,
}

class CourseManagementScreen extends StatefulWidget {
  final UserModel user;

  const CourseManagementScreen({super.key, required this.user});

  @override
  State<CourseManagementScreen> createState() => _CourseManagementScreenState();
}

class _CourseManagementScreenState extends State<CourseManagementScreen> {
  Semester? _selectedSemester;

  // 2. Add State for Search and Sort
  final TextEditingController _searchController = TextEditingController();
  CourseSortOption _sortOption = CourseSortOption.codeAsc;

  @override
  void initState() {
    super.initState();
    _selectedSemester = context.read<SemesterProvider>().currentSemester;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddEditDialog([Course? course]) {
    if (_selectedSemester == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a semester first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final isEdit = course != null;
    final codeController = TextEditingController(text: course?.code ?? '');
    final nameController = TextEditingController(text: course?.name ?? '');
    int sessions = course?.sessions ?? 10;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            isEdit ? 'Edit Course' : 'Add New Course',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeController,
                  decoration: InputDecoration(
                    labelText: 'Course Code',
                    hintText: 'e.g., CS101',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Course Name',
                    hintText: 'e.g., Web Programming',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Number of Sessions:',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                    const SizedBox(width: 16),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 10, label: Text('10')),
                        ButtonSegment(value: 15, label: Text('15')),
                      ],
                      selected: {sessions},
                      onSelectionChanged: (Set<int> selected) {
                        setState(() => sessions = selected.first);
                      },
                    ),
                  ],
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

                final provider = context.read<InstructorCourseProvider>();
                bool success;

                if (isEdit) {
                  success = await provider.updateCourse(
                    id: course.id,
                    code: codeController.text,
                    name: nameController.text,
                    sessions: sessions,
                  );
                } else {
                  success = await provider.createCourse(
                    semesterId: _selectedSemester!.id,
                    code: codeController.text,
                    name: nameController.text,
                    sessions: sessions,
                  );
                }

                if (success && mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEdit
                            ? 'Course updated successfully'
                            : 'Course added successfully',
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

  void _confirmDelete(Course course) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Course'),
        content: Text(
          'Are you sure you want to delete "${course.name}"? This will also delete all associated groups and enrollments.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success =
                  await context.read<InstructorCourseProvider>().deleteCourse(
                        course.id,
                      );

              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Course deleted successfully'),
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

  // Helper method to get sort label
  String _getSortLabel(CourseSortOption option) {
    switch (option) {
      case CourseSortOption.codeAsc:
        return 'Code (A-Z)';
      case CourseSortOption.nameAsc:
        return 'Name (A-Z)';
      case CourseSortOption.sessionsDesc:
        return 'Sessions (High-Low)';
      case CourseSortOption.studentsDesc:
        return 'Students (High-Low)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final semesterProvider = context.watch<SemesterProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Course Management', style: GoogleFonts.poppins()),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditDialog(),
            tooltip: 'Add Course',
          ),
        ],
      ),
      body: Column(
        children: [
          // Semester selector
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                Text(
                  'Semester:',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<Semester>(
                    initialValue: _selectedSemester,
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
                        child: Row(
                          children: [
                            Text(semester.name),
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
                        _selectedSemester = semesterProvider.currentSemester;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // 3. Search and Sort Controls
          if (_selectedSemester != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by code or name...',
                        prefixIcon: const Icon(Icons.search),
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  PopupMenuButton<CourseSortOption>(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.sort),
                    ),
                    tooltip: 'Sort Courses',
                    onSelected: (CourseSortOption result) {
                      setState(() {
                        _sortOption = result;
                      });
                    },
                    itemBuilder: (BuildContext context) =>
                        CourseSortOption.values.map((option) {
                      return PopupMenuItem<CourseSortOption>(
                        value: option,
                        child: Row(
                          children: [
                            Icon(
                              option == _sortOption
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: option == _sortOption
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(_getSortLabel(option)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

          // Course list
          Expanded(
            child: Consumer<InstructorCourseProvider>(
              builder: (context, provider, child) {
                if (_selectedSemester == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.warning,
                          size: 60,
                          color: Colors.orange[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No semester selected',
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

                if (provider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error loading courses',
                            style: GoogleFonts.poppins(color: Colors.red)),
                        ElevatedButton(
                          onPressed: () =>
                              provider.loadCourses(_selectedSemester!.id),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.courses.isEmpty) {
                  return Center(
                    child: Text(
                      'No courses yet for ${_selectedSemester!.name}',
                      style: GoogleFonts.poppins(color: Colors.grey[600]),
                    ),
                  );
                }

                // 4. Filtering and Sorting Logic
                // Create a copy of the list to avoid modifying the provider's source
                List<Course> filteredCourses = provider.courses;

                // Apply Search Filter
                if (_searchController.text.isNotEmpty) {
                  final query = _searchController.text.toLowerCase();
                  filteredCourses = filteredCourses.where((course) {
                    return course.name.toLowerCase().contains(query) ||
                        course.code.toLowerCase().contains(query);
                  }).toList();
                }

                if (filteredCourses.isEmpty) {
                  return Center(
                    child: Text(
                      'No courses match your search',
                      style: GoogleFonts.poppins(color: Colors.grey[500]),
                    ),
                  );
                }

                // Apply Sort
                filteredCourses.sort((a, b) {
                  switch (_sortOption) {
                    case CourseSortOption.codeAsc:
                      return a.code.compareTo(b.code);
                    case CourseSortOption.nameAsc:
                      return a.name.compareTo(b.name);
                    case CourseSortOption.sessionsDesc:
                      return b.sessions.compareTo(a.sessions);
                    case CourseSortOption.studentsDesc:
                      return (b.studentCount ?? 0)
                          .compareTo(a.studentCount ?? 0);
                  }
                });

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:
                        MediaQuery.of(context).size.width > 800 ? 3 : 2,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: filteredCourses.length, // Use filtered list
                  itemBuilder: (context, index) {
                    final course = filteredCourses[index]; // Use filtered list
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
                            // Course header with cover image placeholder
                            Container(
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.blue[100],
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(4),
                                  topRight: Radius.circular(4),
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Icon(
                                      Icons.book,
                                      size: 40,
                                      color: Colors.blue[300],
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: PopupMenuButton<String>(
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit, size: 20),
                                              SizedBox(width: 8),
                                              Text('Edit'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.delete,
                                                size: 20,
                                                color: Colors.red,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Delete',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _showAddEditDialog(course);
                                        } else if (value == 'delete') {
                                          _confirmDelete(course);
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.more_vert,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Course info
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                      ],
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
                                        const Spacer(),
                                        Icon(
                                          Icons.group,
                                          size: 14,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${course.groupCount ?? 0}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.person,
                                          size: 14,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${course.studentCount ?? 0}',
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
              },
            ),
          ),
        ],
      ),
    );
  }
}
