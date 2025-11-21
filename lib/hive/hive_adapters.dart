import 'package:hive_ce/hive.dart';

import '../models/course.dart';
import '../models/student.dart';
import '../models/user_model.dart';

@GenerateAdapters(
    [AdapterSpec<Course>(), AdapterSpec<UserModel>(), AdapterSpec<Student>()])
part 'hive_adapters.g.dart';
