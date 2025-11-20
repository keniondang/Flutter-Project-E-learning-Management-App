import 'package:hive_ce/hive.dart';
import '../models/course.dart';

@GenerateAdapters([AdapterSpec<Course>()])
part 'hive_adapters.g.dart';
