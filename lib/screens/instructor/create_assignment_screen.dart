import 'package:elearning_management_app/providers/assignment_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/course.dart';
import '../../models/group.dart';
import '../../providers/content_provider.dart';
import '../../providers/group_provider.dart';

class CreateAssignmentScreen extends StatefulWidget {
  final Course course;
  final String instructorId;

  const CreateAssignmentScreen({
    Key? key,
    required this.course,
    required this.instructorId,
  }) : super(key: key);

  @override
  State<CreateAssignmentScreen> createState() => _CreateAssignmentScreenState();
}

class _CreateAssignmentScreenState extends State<CreateAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pointsController = TextEditingController(text: '100');
  final _maxAttemptsController = TextEditingController(text: '1');
  final _maxFileSizeController = TextEditingController(text: '10');

  DateTime _startDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  DateTime? _lateDueDate;
  bool _lateSubmissionAllowed = false;
  String _scopeType = 'all';
  List<String> _selectedGroups = [];
  List<String> _fileAttachments = [];
  List<String> _allowedFileTypes = ['.pdf', '.docx', '.txt'];
  List<Group> _availableGroups = [];

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    await context.read<GroupProvider>().loadGroups(widget.course.id);
    setState(() {
      _availableGroups = context.read<GroupProvider>().groups;
    });
  }

  Future<void> _selectDate(BuildContext context, String type) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: type == 'start'
          ? _startDate
          : (type == 'due' ? _dueDate : _lateDueDate ?? _dueDate),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          final dateTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );

          if (type == 'start') {
            _startDate = dateTime;
          } else if (type == 'due') {
            _dueDate = dateTime;
          } else {
            _lateDueDate = dateTime;
          }
        });
      }
    }
  }

  Future<void> _createAssignment() async {
    if (_formKey.currentState!.validate()) {
      final success = await context.read<AssignmentProvider>().createAssignment(
            courseId: widget.course.id,
            instructorId: widget.instructorId,
            title: _titleController.text,
            description: _descriptionController.text,
            fileAttachments: _fileAttachments,
            startDate: _startDate,
            dueDate: _dueDate,
            lateSubmissionAllowed: _lateSubmissionAllowed,
            lateDueDate: _lateDueDate,
            maxAttempts: int.parse(_maxAttemptsController.text),
            maxFileSize: int.parse(_maxFileSizeController.text) *
                1024 *
                1024, // Convert MB to bytes
            allowedFileTypes: _allowedFileTypes,
            scopeType: _scopeType,
            targetGroups: _selectedGroups,
            totalPoints: int.parse(_pointsController.text),
          );

      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Assignment', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: _createAssignment,
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Instructions',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter instructions';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Points
              TextFormField(
                controller: _pointsController,
                decoration: InputDecoration(
                  labelText: 'Total Points',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter points';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Dates section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Schedule',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Start date
                      ListTile(
                        leading: const Icon(Icons.play_arrow),
                        title: const Text('Start Date'),
                        subtitle: Text(
                          DateFormat('MMM dd, yyyy HH:mm').format(_startDate),
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () => _selectDate(context, 'start'),
                      ),

                      // Due date
                      ListTile(
                        leading: const Icon(Icons.event),
                        title: const Text('Due Date'),
                        subtitle: Text(
                          DateFormat('MMM dd, yyyy HH:mm').format(_dueDate),
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () => _selectDate(context, 'due'),
                      ),

                      // Late submission
                      SwitchListTile(
                        title: const Text('Allow late submission'),
                        value: _lateSubmissionAllowed,
                        onChanged: (value) {
                          setState(() {
                            _lateSubmissionAllowed = value;
                            if (value && _lateDueDate == null) {
                              _lateDueDate = _dueDate.add(
                                const Duration(days: 3),
                              );
                            }
                          });
                        },
                      ),

                      if (_lateSubmissionAllowed)
                        ListTile(
                          leading: const Icon(Icons.access_time),
                          title: const Text('Late Due Date'),
                          subtitle: Text(
                            _lateDueDate != null
                                ? DateFormat(
                                    'MMM dd, yyyy HH:mm',
                                  ).format(_lateDueDate!)
                                : 'Not set',
                          ),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () => _selectDate(context, 'late'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Submission settings
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Submission Settings',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Max attempts
                      TextFormField(
                        controller: _maxAttemptsController,
                        decoration: const InputDecoration(
                          labelText: 'Maximum Attempts',
                          helperText: 'Number of times students can submit',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),

                      // Max file size
                      TextFormField(
                        controller: _maxFileSizeController,
                        decoration: const InputDecoration(
                          labelText: 'Maximum File Size (MB)',
                          helperText: 'Maximum size per file in megabytes',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),

                      // Allowed file types
                      Text(
                        'Allowed File Types:',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          '.pdf',
                          '.docx',
                          '.txt',
                          '.zip',
                          '.jpg',
                          '.png',
                        ].map((type) {
                          return FilterChip(
                            label: Text(type),
                            selected: _allowedFileTypes.contains(type),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _allowedFileTypes.add(type);
                                } else {
                                  _allowedFileTypes.remove(type);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Target audience
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Target Audience',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      RadioListTile<String>(
                        title: const Text('All students'),
                        value: 'all',
                        groupValue: _scopeType,
                        onChanged: (value) {
                          setState(() {
                            _scopeType = value!;
                            _selectedGroups = [];
                          });
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('Specific groups'),
                        value: 'specific',
                        groupValue: _scopeType,
                        onChanged: (value) {
                          setState(() {
                            _scopeType = value!;
                          });
                        },
                      ),
                      if (_scopeType == 'specific')
                        ..._availableGroups.map((group) {
                          return CheckboxListTile(
                            title: Text(group.name),
                            value: _selectedGroups.contains(group.id),
                            onChanged: (checked) {
                              setState(() {
                                if (checked ?? false) {
                                  _selectedGroups.add(group.id);
                                } else {
                                  _selectedGroups.remove(group.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
