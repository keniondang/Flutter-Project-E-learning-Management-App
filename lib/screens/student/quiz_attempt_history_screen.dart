import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/quiz.dart';
import '../../models/user_model.dart';

class QuizAttemptHistoryScreen extends StatelessWidget {
  final Quiz quiz;
  final List<QuizAttempt> attempts;
  final UserModel student;

  const QuizAttemptHistoryScreen({
    Key? key,
    required this.quiz,
    required this.attempts,
    required this.student,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final completedAttempts = attempts.where((a) => a.isCompleted).toList();
    final highestScore = completedAttempts.isEmpty
        ? null
        : completedAttempts
            .map((a) => a.score ?? 0.0)
            .reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attempt History', style: GoogleFonts.poppins(fontSize: 18)),
            Text(
              quiz.title,
              style: GoogleFonts.poppins(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Summary Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[700]!, Colors.blue[500]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      'Attempts',
                      '${completedAttempts.length}/${quiz.maxAttempts}',
                      Icons.replay,
                    ),
                    Container(
                      height: 40,
                      width: 1,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    _buildStatItem(
                      'Highest Score',
                      highestScore != null
                          ? '${highestScore.toStringAsFixed(1)}/${quiz.totalPoints}'
                          : 'N/A',
                      Icons.emoji_events,
                    ),
                    Container(
                      height: 40,
                      width: 1,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    _buildStatItem(
                      'Percentage',
                      highestScore != null
                          ? '${((highestScore / quiz.totalPoints) * 100).toStringAsFixed(0)}%'
                          : 'N/A',
                      Icons.percent,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Attempt List
          Expanded(
            child: completedAttempts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.quiz_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No completed attempts yet',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Take the quiz to see your scores',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: completedAttempts.length,
                    itemBuilder: (context, index) {
                      final attempt = completedAttempts[index];
                      final isHighest = attempt.score == highestScore;
                      final percentage = attempt.score != null
                          ? (attempt.score! / quiz.totalPoints) * 100
                          : 0.0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: isHighest ? 4 : 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: isHighest
                              ? BorderSide(color: Colors.amber[700]!, width: 2)
                              : BorderSide.none,
                        ),
                        child: Container(
                          decoration: isHighest
                              ? BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.amber[50]!,
                                      Colors.white,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                )
                              : null,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: isHighest
                                      ? Colors.amber[700]
                                      : _getScoreColor(percentage)
                                          .withOpacity(0.2),
                                  child: Text(
                                    '#${attempt.attemptNumber}',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isHighest
                                          ? Colors.white
                                          : _getScoreColor(percentage),
                                    ),
                                  ),
                                ),
                                if (isHighest)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber[700],
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.emoji_events,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Row(
                              children: [
                                Text(
                                  'Attempt ${attempt.attemptNumber}',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                if (isHighest) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber[700],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'BEST',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'Submitted: ${DateFormat('MMM dd, yyyy HH:mm').format(attempt.submittedAt!)}',
                                  style: GoogleFonts.poppins(fontSize: 12),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: LinearProgressIndicator(
                                        value: percentage / 100,
                                        backgroundColor:
                                            Colors.grey[300],
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          _getScoreColor(percentage),
                                        ),
                                        minHeight: 8,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '${percentage.toStringAsFixed(0)}%',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _getScoreColor(percentage),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _getScoreColor(percentage)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${attempt.score?.toStringAsFixed(1)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _getScoreColor(percentage),
                                    ),
                                  ),
                                  Text(
                                    '/ ${quiz.totalPoints}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(double percentage) {
    if (percentage >= 80) return Colors.green[700]!;
    if (percentage >= 60) return Colors.blue[700]!;
    if (percentage >= 40) return Colors.orange[700]!;
    return Colors.red[700]!;
  }
}
