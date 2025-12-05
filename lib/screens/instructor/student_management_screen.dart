import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/student.dart';
import '../../providers/student_provider.dart';

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

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
                final result = await provider.updateUser(
                  id: student.id,
                  email: emailController.text,
                  fullName: fullNameController.text,
                );

                if (result != null && mounted) {
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

  Future<void> _handleBulkCreateStudents(
      List<List<dynamic>> fields, Set<String> duplicates) async {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
              child: CircularProgressIndicator(),
            ));

    final insertedData =
        await context.read<StudentProvider>().bulkCreateStudents(fields
            .where((row) => !duplicates.contains(row[0]))
            .map((row) => {
                  'username': row[0],
                  'email': row[1],
                  'full_name': row[2],
                  'password': row[3],
                  'role': 'student',
                })
            .toList());

    if (mounted) {
      Navigator.pop(context);

      if (insertedData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to import students into database.'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        showDialog(
            context: context,
            builder: (context) => AlertDialog(
                  title: Text(
                    'Successfully imported ${insertedData.length} students.',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The Data Table
                      Container(
                        height: 500, // Fixed height for vertical scrolling
                        // width: double.maxFinite,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor:
                                  MaterialStateProperty.all(Colors.grey[100]),
                              columns: const [
                                DataColumn(label: Text('Username')),
                                DataColumn(label: Text('Full Name')),
                                DataColumn(label: Text('Email')),
                              ],
                              rows: insertedData.map((student) {
                                return DataRow(
                                  color:
                                      MaterialStateProperty.all(Colors.white),
                                  cells: [
                                    // Username
                                    DataCell(Text(student.username,
                                        style: const TextStyle(
                                            color: Colors.black87))),
                                    // Name
                                    DataCell(Text(student.fullName,
                                        style: const TextStyle(
                                            color: Colors.black87))),
                                    // Email
                                    DataCell(Text(student.email,
                                        style: const TextStyle(
                                            color: Colors.black87))),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Ok'),
                    ),
                  ],
                ));
      }
    }
  }

  AlertDialog _getImportPreviewDialog(
    List<List<dynamic>> fields,
    Set<String> duplicates,
  ) {
    final uniqueCount = fields.length - duplicates.length;

    return AlertDialog(
      title: Text(
        'Import Preview',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Text
          RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(color: Colors.black87, fontSize: 13),
              children: [
                const TextSpan(text: 'Ready to import '),
                TextSpan(
                  text: '$uniqueCount students',
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: '. '),
                if (duplicates.isNotEmpty) ...[
                  TextSpan(
                    text: '${duplicates.length} duplicates',
                    style: const TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' will be skipped.'),
                ]
              ],
            ),
          ),
          const SizedBox(height: 16),

          // The Data Table
          Container(
            height: 500, // Fixed height for vertical scrolling
            // width: double.maxFinite,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(4),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                  columns: const [
                    DataColumn(label: Text('Row')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Username')),
                    DataColumn(label: Text('Full Name')),
                    DataColumn(label: Text('Email')),
                  ],
                  rows: fields.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final row = entry.value;

                    final username = row[0].toString().trim();
                    final isDuplicate = duplicates.contains(username);

                    return DataRow(
                      color: MaterialStateProperty.all(isDuplicate
                          ? Colors.red.withOpacity(0.05)
                          : Colors.white),
                      cells: [
                        // Username
                        DataCell(Text(
                          index.toString(),
                          style: TextStyle(
                            color: isDuplicate ? Colors.grey : Colors.black87,
                          ),
                        )),
                        // Status Column
                        DataCell(
                          Row(
                            children: [
                              Icon(
                                isDuplicate
                                    ? Icons.cancel_outlined
                                    : Icons.check_circle_outline,
                                color: isDuplicate ? Colors.red : Colors.green,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isDuplicate ? 'Skip' : 'Add',
                                style: TextStyle(
                                    color:
                                        isDuplicate ? Colors.red : Colors.green,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        // Username
                        DataCell(Text(
                          username,
                          style: TextStyle(
                            color: isDuplicate ? Colors.grey : Colors.black87,
                          ),
                        )),
                        // Name
                        DataCell(Text(
                          row[2].toString(),
                          style: TextStyle(
                              color:
                                  isDuplicate ? Colors.grey : Colors.black87),
                        )),
                        // Email
                        DataCell(Text(
                          row[1].toString(),
                          style: TextStyle(
                              color:
                                  isDuplicate ? Colors.grey : Colors.black87),
                        )),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: uniqueCount > 0
              ? () {
                  Navigator.pop(context);
                  _handleBulkCreateStudents(fields, duplicates);
                }
              : null, // Disable button if there are no unique rows to add
          child: Text('Import $uniqueCount Students'),
        ),
      ],
    );
  }

  Future<void> _handleCSVImport() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result == null || !mounted) return;

    String csv = utf8.decode(result.files.first.bytes as List<int>);

    final fields = const CsvToListConverter(eol: "\n").convert(csv);
    fields.removeAt(0);

    final usernames = [
      for (List<dynamic> field in fields) (field.first as String).trim()
    ];

    if (mounted) {
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => FutureBuilder(
                future: context
                    .read<StudentProvider>()
                    .getDuplicateUsernames(usernames),
                builder: (context, snapshot) {
                  switch (snapshot.connectionState) {
                    case ConnectionState.waiting:
                      return const Center(child: CircularProgressIndicator());
                    case ConnectionState.done:
                      return _getImportPreviewDialog(
                          fields, snapshot.data!.toSet());
                    case _:
                      return const Center(child: CircularProgressIndicator());
                  }
                },
              ));
    }
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

                    // Check if avatar bytes are available
                    final hasAvatar = student.avatarBytes != null &&
                        student.avatarBytes!.isNotEmpty;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green[100],
                          // UPDATED: Show Avatar if available
                          backgroundImage: hasAvatar
                              ? MemoryImage(student.avatarBytes! as Uint8List)
                              : null,
                          child: hasAvatar
                              ? null
                              : Text(
                                  student.fullName.isNotEmpty
                                      ? student.fullName[0].toUpperCase()
                                      : '?',
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
        tooltip: 'Add Student',
        child: const Icon(Icons.add),
      ),
    );
  }
}
