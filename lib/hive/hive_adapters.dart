import 'package:elearning_management_app/models/forum/forum_reply.dart';
import 'package:hive_ce/hive.dart';

import '../models/announcement.dart';
import '../models/assignment.dart';
import '../models/course.dart';
import '../models/course_material.dart';
import '../models/forum/forum.dart';
import '../models/group.dart';
import '../models/quiz.dart';
import '../models/semester.dart';
import '../models/student.dart';
import '../models/user_model.dart';

@GenerateAdapters([
  AdapterSpec<Course>(),
  AdapterSpec<UserModel>(),
  AdapterSpec<Student>(),
  AdapterSpec<Group>(),
  AdapterSpec<Semester>(),
  AdapterSpec<Assignment>(),
  AdapterSpec<Quiz>(),
  AdapterSpec<Announcement>(),
  AdapterSpec<CourseMaterial>(),
  AdapterSpec<Question>(),
  AdapterSpec<QuestionOption>(),
  AdapterSpec<QuizAttempt>(),
  AdapterSpec<AssignmentSubmission>(),
  AdapterSpec<Forum>(),
  AdapterSpec<ForumReply>(),
])
part 'hive_adapters.g.dart';
