import 'package:elearning_management_app/providers/quiz_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/course.dart';
import '../../models/group.dart';
import '../../providers/group_provider.dart';
import '../../providers/question_bank_provider.dart';
import 'question_bank_screen.dart';

class CreateQuizScreen extends StatefulWidget {
  final Course course;
  final String instructorId;

  const CreateQuizScreen({
    Key? key,
    required this.course,
    required this.instructorId,
  }) : super(key: key);

  @override
  State<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController(text: '60');
  final _maxAttemptsController = TextEditingController(text: '1');
  final _totalPointsController = TextEditingController(text: '100');
  final _easyQuestionsController = TextEditingController(text: '5');
  final _mediumQuestionsController = TextEditingController(text: '3');
  final _hardQuestionsController = TextEditingController(text: '2');

  DateTime _openTime = DateTime.now();
  DateTime _closeTime = DateTime.now().add(const Duration(days: 7));
  String _scopeType = 'all';
  List<String> _selectedGroups = [];
  List<Group> _availableGroups = [];

  int _availableEasy = 0;
  int _availableMedium = 0;
  int _availableHard = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await context.read<GroupProvider>().loadGroups(widget.course.id);
    await context.read<QuestionBankProvider>().loadQuestions(widget.course.id);

    final questions = context.read<QuestionBankProvider>().questions;

    setState(() {
      _availableGroups = context.read<GroupProvider>().groups;
      _availableEasy = questions.where((q) => q.difficulty == 'easy').length;
      _availableMedium =
          questions.where((q) => q.difficulty == 'medium').length;
      _availableHard = questions.where((q) => q.difficulty == 'hard').length;
    });
  }

  Future<void> _selectDateTime(BuildContext context, bool isOpenTime) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isOpenTime ? _openTime : _closeTime,
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

          if (isOpenTime) {
            _openTime = dateTime;
          } else {
            _closeTime = dateTime;
          }
        });
      }
    }
  }

  Future<void> _createQuiz() async {
    if (_formKey.currentState!.validate()) {
      final easyCount = int.tryParse(_easyQuestionsController.text) ?? 0;
      final mediumCount = int.tryParse(_mediumQuestionsController.text) ?? 0;
      final hardCount = int.tryParse(_hardQuestionsController.text) ?? 0;

      if (easyCount > _availableEasy) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Not enough easy questions. Available: $_availableEasy',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (mediumCount > _availableMedium) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Not enough medium questions. Available: $_availableMedium',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (hardCount > _availableHard) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Not enough hard questions. Available: $_availableHard',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final success = await context.read<QuizProvider>().createQuiz(
            courseId: widget.course.id,
            instructorId: widget.instructorId,
            title: _titleController.text,
            description: _descriptionController.text.isNotEmpty
                ? _descriptionController.text
                : null,
            openTime: _openTime,
            closeTime: _closeTime,
            durationMinutes: int.parse(_durationController.text),
            maxAttempts: int.parse(_maxAttemptsController.text),
            easyQuestions: easyCount,
            mediumQuestions: mediumCount,
            hardQuestions: hardCount,
            totalPoints: int.parse(_totalPointsController.text),
            scopeType: _scopeType,
            targetGroups: _selectedGroups,
          );

      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quiz created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalQuestions = (int.tryParse(_easyQuestionsController.text) ?? 0) +
        (int.tryParse(_mediumQuestionsController.text) ?? 0) +
        (int.tryParse(_hardQuestionsController.text) ?? 0);

    return Scaffold(
      appBar: AppBar(
        title: Text('Create Quiz', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: _createQuiz,
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
                  labelText: 'Quiz Title',
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
                  labelText: 'Instructions (Optional)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              // Quiz settings card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quiz Settings',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _durationController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Duration (minutes)',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _maxAttemptsController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Max Attempts',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _totalPointsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Total Points',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Schedule card
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
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              title: const Text('Open Time'),
                              subtitle: Text(
                                DateFormat('MMM d, y h:mm a').format(_openTime),
                              ),
                              onTap: () => _selectDateTime(context, true),
                            ),
                          ),
                          Expanded(
                            child: ListTile(
                              title: const Text('Close Time'),
                              subtitle: Text(
                                DateFormat(
                                  'MMM d, y h:mm a',
                                ).format(_closeTime),
                              ),
                              onTap: () => _selectDateTime(context, false),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Question Distribution card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question Distribution',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildQuestionRow(
                        'Easy',
                        _easyQuestionsController,
                        _availableEasy,
                      ),
                      const SizedBox(height: 12),
                      _buildQuestionRow(
                        'Medium',
                        _mediumQuestionsController,
                        _availableMedium,
                      ),
                      const SizedBox(height: 12),
                      _buildQuestionRow(
                        'Hard',
                        _hardQuestionsController,
                        _availableHard,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Total Questions: $totalQuestions',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Manage Question Bank card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question Bank',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  QuestionBankScreen(course: widget.course),
                            ),
                          ).then(
                            (_) => _loadData(),
                          ); // 👈 refresh after returning
                        },
                        icon: const Icon(Icons.question_answer),
                        label: const Text('Manage Question Bank'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Scope card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scope',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _scopeType,
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('All Students'),
                          ),
                          DropdownMenuItem(
                            value: 'groups',
                            child: Text('Specific Groups'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _scopeType = value!;
                          });
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (_scopeType == 'groups') ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: _availableGroups.map((group) {
                            final isSelected = _selectedGroups.contains(
                              group.id,
                            );
                            return FilterChip(
                              label: Text(group.name),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedGroups.add(group.id);
                                  } else {
                                    _selectedGroups.remove(group.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
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

  Widget _buildQuestionRow(
    String label,
    TextEditingController controller,
    int available,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '$label Questions',
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Required';
              }
              final count = int.tryParse(value);
              if (count == null || count < 0) {
                return 'Invalid';
              }
              if (count > available) {
                return 'Max $available';
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 12),
        Text('Available: $available'),
      ],
    );
  }
}
