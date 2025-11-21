import 'package:hive_ce/hive.dart';

import '../models/course.dart';
import '../models/group.dart';
import '../models/student.dart';
import '../models/user_model.dart';
import '../models/assignment.dart';

@GenerateAdapters([
  AdapterSpec<Course>(),
  AdapterSpec<UserModel>(),
  AdapterSpec<Student>(),
  AdapterSpec<Group>(),
  AdapterSpec<Assignment>()
])
part 'hive_adapters.g.dart';
