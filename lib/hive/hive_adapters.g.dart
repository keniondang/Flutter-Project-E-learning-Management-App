// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_adapters.dart';

// **************************************************************************
// AdaptersGenerator
// **************************************************************************

class CourseAdapter extends TypeAdapter<Course> {
  @override
  final typeId = 0;

  @override
  Course read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Course(
      id: fields[0] as String,
      semesterId: fields[1] as String,
      code: fields[2] as String,
      name: fields[3] as String,
      sessions: (fields[4] as num).toInt(),
      coverImage: fields[5] as String?,
      createdAt: fields[6] as DateTime,
      semesterName: fields[7] as String?,
      groupIds: (fields[10] as Set?)?.cast<String>(),
      studentCount: (fields[12] as num?)?.toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, Course obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.semesterId)
      ..writeByte(2)
      ..write(obj.code)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.sessions)
      ..writeByte(5)
      ..write(obj.coverImage)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.semesterName)
      ..writeByte(10)
      ..write(obj.groupIds)
      ..writeByte(12)
      ..write(obj.studentCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class UserModelAdapter extends TypeAdapter<UserModel> {
  @override
  final typeId = 1;

  @override
  UserModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserModel(
      id: fields[0] as String,
      email: fields[1] as String,
      username: fields[2] as String,
      fullName: fields[3] as String,
      role: fields[4] as String,
      avatarUrl: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, UserModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.email)
      ..writeByte(2)
      ..write(obj.username)
      ..writeByte(3)
      ..write(obj.fullName)
      ..writeByte(4)
      ..write(obj.role)
      ..writeByte(5)
      ..write(obj.avatarUrl);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class StudentAdapter extends TypeAdapter<Student> {
  @override
  final typeId = 2;

  @override
  Student read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Student(
      id: fields[4] as String,
      email: fields[5] as String,
      username: fields[6] as String,
      fullName: fields[7] as String,
      avatarUrl: fields[8] as String?,
      groupMap: (fields[9] as Map?)?.cast<String, String>(),
      courseIds: (fields[11] as Set?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Student obj) {
    writer
      ..writeByte(7)
      ..writeByte(4)
      ..write(obj.id)
      ..writeByte(5)
      ..write(obj.email)
      ..writeByte(6)
      ..write(obj.username)
      ..writeByte(7)
      ..write(obj.fullName)
      ..writeByte(8)
      ..write(obj.avatarUrl)
      ..writeByte(9)
      ..write(obj.groupMap)
      ..writeByte(11)
      ..write(obj.courseIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class GroupAdapter extends TypeAdapter<Group> {
  @override
  final typeId = 3;

  @override
  Group read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Group(
      id: fields[0] as String,
      courseId: fields[1] as String,
      name: fields[2] as String,
      createdAt: fields[3] as DateTime,
      courseName: fields[4] as String?,
      studentCount: (fields[5] as num?)?.toInt(),
      semesterId: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Group obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.courseId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.courseName)
      ..writeByte(5)
      ..write(obj.studentCount)
      ..writeByte(6)
      ..write(obj.semesterId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AssignmentAdapter extends TypeAdapter<Assignment> {
  @override
  final typeId = 4;

  @override
  Assignment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Assignment(
      id: fields[0] as String,
      courseId: fields[1] as String,
      instructorId: fields[2] as String,
      title: fields[3] as String,
      description: fields[4] as String,
      fileAttachments: (fields[5] as List).cast<String>(),
      startDate: fields[6] as DateTime,
      dueDate: fields[7] as DateTime,
      lateSubmissionAllowed: fields[8] as bool,
      lateDueDate: fields[9] as DateTime?,
      maxAttempts: (fields[10] as num).toInt(),
      maxFileSize: (fields[11] as num).toInt(),
      allowedFileTypes: (fields[12] as List).cast<String>(),
      scopeType: fields[13] as String,
      targetGroups: (fields[14] as List).cast<String>(),
      totalPoints: (fields[15] as num).toInt(),
      createdAt: fields[16] as DateTime,
      semesterId: fields[17] as String?,
      submissionCount: (fields[18] as num?)?.toInt(),
      hasSubmitted: fields[19] as bool?,
      grade: (fields[20] as num?)?.toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, Assignment obj) {
    writer
      ..writeByte(21)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.courseId)
      ..writeByte(2)
      ..write(obj.instructorId)
      ..writeByte(3)
      ..write(obj.title)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.fileAttachments)
      ..writeByte(6)
      ..write(obj.startDate)
      ..writeByte(7)
      ..write(obj.dueDate)
      ..writeByte(8)
      ..write(obj.lateSubmissionAllowed)
      ..writeByte(9)
      ..write(obj.lateDueDate)
      ..writeByte(10)
      ..write(obj.maxAttempts)
      ..writeByte(11)
      ..write(obj.maxFileSize)
      ..writeByte(12)
      ..write(obj.allowedFileTypes)
      ..writeByte(13)
      ..write(obj.scopeType)
      ..writeByte(14)
      ..write(obj.targetGroups)
      ..writeByte(15)
      ..write(obj.totalPoints)
      ..writeByte(16)
      ..write(obj.createdAt)
      ..writeByte(17)
      ..write(obj.semesterId)
      ..writeByte(18)
      ..write(obj.submissionCount)
      ..writeByte(19)
      ..write(obj.hasSubmitted)
      ..writeByte(20)
      ..write(obj.grade);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssignmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
