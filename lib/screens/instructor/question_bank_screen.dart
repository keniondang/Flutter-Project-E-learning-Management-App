import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/course.dart';
import '../../models/quiz.dart'; // contains Question & QuestionOption models
import '../../providers/question_bank_provider.dart';

class QuestionBankScreen extends StatefulWidget {
  final Course course;

  const QuestionBankScreen({
    Key? key,
    required this.course,
  }) : super(key: key);

  @override
  State<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends State<QuestionBankScreen> {
  String _filterDifficulty = 'all';

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    await context.read<QuestionBankProvider>().loadQuestions(widget.course.id);
  }

  void _showAddEditQuestionDialog([Question? question]) {
    final isEdit = question != null;

    final questionController =
        TextEditingController(text: question?.questionText ?? '');

    // one-correct-answer model using radios
    final List<TextEditingController> optionControllers = [];
    final List<bool> correctAnswers = [];
    String difficulty = question?.difficulty ?? 'easy';

    if (isEdit) {
      for (final opt in question!.options) {
        optionControllers.add(TextEditingController(text: opt.text));
        correctAnswers.add(opt.isCorrect);
      }
      // Safety: ensure at least one correct
      if (!correctAnswers.contains(true) && correctAnswers.isNotEmpty) {
        correctAnswers[0] = true;
      }
    } else {
      // default 4 options, first is correct
      for (int i = 0; i < 4; i++) {
        optionControllers.add(TextEditingController());
        correctAnswers.add(i == 0);
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            isEdit ? 'Edit Question' : 'Add Question',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question text
                  TextField(
                    controller: questionController,
                    decoration: InputDecoration(
                      labelText: 'Question',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  // Difficulty
                  Text(
                    'Difficulty:',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'easy', label: Text('Easy')),
                      ButtonSegment(value: 'medium', label: Text('Medium')),
                      ButtonSegment(value: 'hard', label: Text('Hard')),
                    ],
                    selected: {difficulty},
                    onSelectionChanged: (Set<String> selected) {
                      setState(() => difficulty = selected.first);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Options
                  Text(
                    'Answer Options:',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    children: List.generate(optionControllers.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Radio<int>(
                              value: index,
                              groupValue: correctAnswers.indexOf(true),
                              onChanged: (value) {
                                setState(() {
                                  for (int i = 0;
                                      i < correctAnswers.length;
                                      i++) {
                                    correctAnswers[i] = i == value;
                                  }
                                });
                              },
                            ),
                            Expanded(
                              child: TextField(
                                controller: optionControllers[index],
                                decoration: InputDecoration(
                                  labelText: 'Option ${index + 1}',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  suffixIcon: correctAnswers[index]
                                      ? const Icon(Icons.check_circle,
                                          color: Colors.green)
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // dispose safely after dialog is removed
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  for (final c in optionControllers) c.dispose();
                  questionController.dispose();
                });
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (questionController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a question'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                // Ensure all options filled
                for (final c in optionControllers) {
                  if (c.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill all options'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                }

                // Build options
                final options = <QuestionOption>[];
                for (int i = 0; i < optionControllers.length; i++) {
                  options.add(QuestionOption(
                    text: optionControllers[i].text,
                    isCorrect: correctAnswers[i],
                  ));
                }

                final provider = context.read<QuestionBankProvider>();
                bool success;

                if (isEdit) {
                  success = await provider.updateQuestion(
                    id: question!.id,
                    questionText: questionController.text,
                    options: options,
                    difficulty: difficulty,
                  );
                } else {
                  success = await provider.createQuestion(
                    courseId: widget.course.id,
                    questionText: questionController.text,
                    options: options,
                    difficulty: difficulty,
                  );
                }

                if (success && mounted) {
                  Navigator.pop(context);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    for (final c in optionControllers) c.dispose();
                    questionController.dispose();
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEdit
                            ? 'Question updated successfully'
                            : 'Question added successfully',
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

  void _confirmDelete(Question question) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Question'),
        content: const Text('Are you sure you want to delete this question?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await context
                  .read<QuestionBankProvider>()
                  .deleteQuestion(question.id);

              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Question deleted successfully'),
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
        title: Text('Question Bank', style: GoogleFonts.poppins()),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditQuestionDialog(),
            tooltip: 'Add Question',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Filter:',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('All'),
                          selected: _filterDifficulty == 'all',
                          onSelected: (_) =>
                              setState(() => _filterDifficulty = 'all'),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Easy'),
                          selected: _filterDifficulty == 'easy',
                          backgroundColor: Colors.green[50],
                          selectedColor: Colors.green[200],
                          onSelected: (_) =>
                              setState(() => _filterDifficulty = 'easy'),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Medium'),
                          selected: _filterDifficulty == 'medium',
                          backgroundColor: Colors.orange[50],
                          selectedColor: Colors.orange[200],
                          onSelected: (_) =>
                              setState(() => _filterDifficulty = 'medium'),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Hard'),
                          selected: _filterDifficulty == 'hard',
                          backgroundColor: Colors.red[50],
                          selectedColor: Colors.red[200],
                          onSelected: (_) =>
                              setState(() => _filterDifficulty = 'hard'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: Consumer<QuestionBankProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Error loading questions',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(provider.error!),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadQuestions,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final questions = provider.questions.where((q) {
                  if (_filterDifficulty == 'all') return true;
                  return q.difficulty == _filterDifficulty;
                }).toList();

                if (questions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.help_outline,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No questions found',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: questions.length,
                  itemBuilder: (context, index) {
                    final question = questions[index];
                    final correctOption =
                        question.options.firstWhere((o) => o.isCorrect);

                    return ExpansionTile(
                      title: Text(
                        question.questionText,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Row(
                        children: [
                          Chip(
                            label: Text(
                              question.difficulty.toUpperCase(),
                              style: const TextStyle(fontSize: 10),
                            ),
                            backgroundColor: question.difficulty == 'easy'
                                ? Colors.green[100]
                                : question.difficulty == 'medium'
                                    ? Colors.orange[100]
                                    : Colors.red[100],
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Correct: ${correctOption.text}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showAddEditQuestionDialog(question);
                          } else if (value == 'delete') {
                            _confirmDelete(question);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete,
                                    size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete',
                                    style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: question.options
                                .asMap()
                                .entries
                                .map((entry) {
                              final opt = entry.value;
                              final idx = entry.key;
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 12,
                                  backgroundColor: opt.isCorrect
                                      ? Colors.green
                                      : Colors.grey[300],
                                  child: Text(
                                    String.fromCharCode(65 + idx), // A,B,C,D
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: opt.isCorrect
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  opt.text,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: opt.isCorrect
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color:
                                        opt.isCorrect ? Colors.green : null,
                                  ),
                                ),
                                trailing: opt.isCorrect
                                    ? const Icon(Icons.check_circle,
                                        color: Colors.green, size: 20)
                                    : null,
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditQuestionDialog(),
        child: const Icon(Icons.add),
        tooltip: 'Add Question',
      ),
    );
  }
}
