import 'package:hive_ce/hive.dart';

import '../models/announcement.dart';
import '../models/assignment.dart';
import '../models/course.dart';
import '../models/course_material.dart';
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
])
part 'hive_adapters.g.dart';
