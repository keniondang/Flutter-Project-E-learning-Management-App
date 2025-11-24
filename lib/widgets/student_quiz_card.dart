import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/quiz.dart';
import '../../models/user_model.dart';
import '../../providers/student_quiz_provider.dart';
import 'package:provider/provider.dart';

/// Enhanced Quiz Card for Student Classwork
/// Shows attempt count (e.g., "1/3") and highest score
class StudentQuizCard extends StatelessWidget {
  final Quiz quiz;
  final UserModel student;
  final VoidCallback? onTap;

  const StudentQuizCard({
    Key? key,
    required this.quiz,
    required this.student,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentQuizProvider>(
      builder: (context, provider, child) {
        // Get attempt data
        final attempts = provider.getAttemptsForQuiz(quiz.id);
        final completedAttempts = attempts.where((a) => a.isCompleted).length;
        final highestScore = provider.getHighestScore(quiz.id);
        final canAttempt = provider.canAttemptQuiz(quiz.id);
        
        // Calculate percentage
        final percentage = highestScore != null
            ? (highestScore / quiz.totalPoints) * 100
            : null;

        // Determine status
        String status;
        Color statusColor;
        
        if (quiz.isPastDue) {
          status = 'Closed';
          statusColor = Colors.grey;
        } else if (!quiz.isOpen) {
          status = 'Not Open';
          statusColor = Colors.orange;
        } else if (completedAttempts >= quiz.maxAttempts) {
          status = 'Completed';
          statusColor = Colors.green;
        } else if (completedAttempts > 0) {
          status = 'In Progress';
          statusColor = Colors.blue;
        } else {
          status = 'Not Started';
          statusColor = Colors.purple;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Status Row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          quiz.title,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor, width: 1),
                        ),
                        child: Text(
                          status,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Quiz Info Row
                  Row(
                    children: [
                      _buildInfoChip(
                        Icons.quiz,
                        '${quiz.totalQuestions} questions',
                      ),
                      const SizedBox(width: 8),
                      _buildInfoChip(
                        Icons.timer,
                        '${quiz.durationMinutes} min',
                      ),
                      const SizedBox(width: 8),
                      _buildInfoChip(
                        Icons.grade,
                        '${quiz.totalPoints} pts',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Due Date
                  Row(
                    children: [
                      Icon(Icons.event, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Due: ${DateFormat('MMM dd, HH:mm').format(quiz.closeTime)}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // ✅ ATTEMPT INDICATOR AND HIGHEST SCORE
                  Row(
                    children: [
                      // Attempt Counter
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: completedAttempts >= quiz.maxAttempts
                              ? Colors.green.withOpacity(0.1)
                              : Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: completedAttempts >= quiz.maxAttempts
                                ? Colors.green
                                : Colors.blue,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.replay,
                              size: 16,
                              color: completedAttempts >= quiz.maxAttempts
                                  ? Colors.green[700]
                                  : Colors.blue[700],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$completedAttempts/${quiz.maxAttempts}',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: completedAttempts >= quiz.maxAttempts
                                    ? Colors.green[700]
                                    : Colors.blue[700],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'attempts',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: completedAttempts >= quiz.maxAttempts
                                    ? Colors.green[700]
                                    : Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const Spacer(),
                      
                      // Highest Score Display
                      if (highestScore != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getScoreColor(percentage!)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getScoreColor(percentage),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.emoji_events,
                                size: 16,
                                color: _getScoreColor(percentage),
                              ),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${highestScore.toStringAsFixed(1)}/${quiz.totalPoints}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _getScoreColor(percentage),
                                    ),
                                  ),
                                  Text(
                                    '${percentage.toStringAsFixed(0)}%',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: _getScoreColor(percentage)
                                          .withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      else
                        // No attempts yet indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.pending_outlined,
                                size: 16,
                                color: Colors.grey[700],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Not attempted',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.blue[700]),
          const SizedBox(width: 3),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double percentage) {
    if (percentage >= 80) return Colors.green[700]!;
    if (percentage >= 60) return Colors.blue[700]!;
    if (percentage >= 40) return Colors.orange[700]!;
    return Colors.red[700]!;
  }
}
