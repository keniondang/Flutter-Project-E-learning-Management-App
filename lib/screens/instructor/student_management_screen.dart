import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/student.dart';
import '../../providers/student_provider.dart';
import '../../services/csv_service.dart';

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({Key? key}) : super(key: key);

  @override
  State<StudentManagementScreen> createState() =>
      _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  final _searchController = TextEditingController();
  List<Student> _filteredStudents = [];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    await context.read<StudentProvider>().loadAllStudents();
    _filterStudents();
  }

  void _filterStudents() {
    final provider = context.read<StudentProvider>();
    final query = _searchController.text.toLowerCase();

    setState(() {
      if (query.isEmpty) {
        _filteredStudents = provider.students;
      } else {
        _filteredStudents = provider.students.where((student) {
          return student.fullName.toLowerCase().contains(query) ||
              student.username.toLowerCase().contains(query) ||
              student.email.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _showAddEditDialog([Student? student]) {
    final isEdit = student != null;
    final usernameController = TextEditingController(
      text: student?.username ?? '',
    );
    final emailController = TextEditingController(text: student?.email ?? '');
    final fullNameController = TextEditingController(
      text: student?.fullName ?? '',
    );
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isEdit ? 'Edit Student' : 'Add New Student',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                enabled: !isEdit, // Can't change username
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: 'johndoe',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'john@student.edu',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: fullNameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  hintText: 'John Doe',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              if (!isEdit) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
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
              if (emailController.text.isEmpty ||
                  fullNameController.text.isEmpty ||
                  (!isEdit &&
                      (usernameController.text.isEmpty ||
                          passwordController.text.isEmpty))) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill all fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final provider = context.read<StudentProvider>();

              if (isEdit) {
                final success = await provider.updateStudent(
                  id: student.id,
                  email: emailController.text,
                  fullName: fullNameController.text,
                );

                if (success && mounted) {
                  Navigator.pop(context);
                  _filterStudents();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Student updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } else {
                final result = await provider.createStudent(
                  username: usernameController.text,
                  email: emailController.text,
                  password: passwordController.text,
                  fullName: fullNameController.text,
                );

                if (result['success'] && mounted) {
                  Navigator.pop(context);
                  _filterStudents();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message']),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message']),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(isEdit ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  void _showCSVImportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Import Students from CSV',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CSV Format Required:',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'username,email,full_name,password',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'johndoe,john@student.edu,John Doe,password123\n'
                    'janedoe,jane@student.edu,Jane Doe,password456',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              _handleCSVImport();
            },
            icon: const Icon(Icons.upload_file),
            label: const Text('Choose CSV File'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCSVImport() async {
    final result = await CSVService.pickAndParseCSV();

    if (result == null || !mounted) return;

    final data = result['data'] as List<Map<String, dynamic>>;
    final headers = result['headers'] as List<String>;

    // Validate headers
    final requiredHeaders = ['username', 'email', 'full_name', 'password'];
    for (var header in requiredHeaders) {
      if (!headers.contains(header)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Missing required column: $header'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Import students
    final importResult = await context
        .read<StudentProvider>()
        .createMultipleStudents(data);

    if (mounted) {
      _filterStudents();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Import Results',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildResultRow(
                'Successfully imported:',
                importResult['successCount'],
                Colors.green,
              ),
              _buildResultRow(
                'Duplicates skipped:',
                importResult['duplicateCount'],
                Colors.orange,
              ),
              _buildResultRow(
                'Errors:',
                importResult['errorCount'],
                Colors.red,
              ),
              if (importResult['errors'] != null &&
                  (importResult['errors'] as List).isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Error details:',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                ...(importResult['errors'] as List)
                    .take(3)
                    .map(
                      (error) => Text(
                        '• $error',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
              ],
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildResultRow(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins()),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: GoogleFonts.poppins(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Student student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text(
          'Are you sure you want to delete ${student.fullName}? This will remove them from all groups and delete all their data.',
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
                  .deleteStudent(student.id);

              if (success && mounted) {
                _filterStudents();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Student deleted successfully'),
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Student Management', style: GoogleFonts.poppins()),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _showCSVImportDialog,
            tooltip: 'Import from CSV',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditDialog(),
            tooltip: 'Add Student',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, username, or email...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (_) => _filterStudents(),
            ),
          ),

          // Student list
          Expanded(
            child: Consumer<StudentProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (_filteredStudents.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isEmpty
                              ? 'No students yet'
                              : 'No students found',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (_searchController.text.isEmpty) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showAddEditDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Add First Student'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredStudents.length,
                  itemBuilder: (context, index) {
                    final student = _filteredStudents[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
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
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Username: ${student.username} | Email: ${student.email}',
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _showAddEditDialog(student),
                              tooltip: 'Edit',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20),
                              onPressed: () => _confirmDelete(student),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add),
        tooltip: 'Add Student',
      ),
    );
  }
}
