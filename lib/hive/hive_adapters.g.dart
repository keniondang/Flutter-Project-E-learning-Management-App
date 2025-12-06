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
      instructorId: fields[13] as String?,
      semesterName: fields[7] as String?,
      groupIds: (fields[10] as Set?)?.cast<String>(),
      studentCount: (fields[12] as num?)?.toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, Course obj) {
    writer
      ..writeByte(11)
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
      ..write(obj.studentCount)
      ..writeByte(13)
      ..write(obj.instructorId);
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
      hasAvatar: fields[7] as bool,
      avatarBytes: (fields[6] as List?)?.cast<int>(),
    );
  }

  @override
  void write(BinaryWriter writer, UserModel obj) {
    writer
      ..writeByte(7)
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
      ..writeByte(6)
      ..write(obj.avatarBytes)
      ..writeByte(7)
      ..write(obj.hasAvatar);
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
      hasAvatar: fields[13] as bool,
      avatarBytes: (fields[12] as List?)?.cast<int>(),
      groupMap: (fields[9] as Map?)?.cast<String, String>(),
      courseIds: (fields[11] as Set?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Student obj) {
    writer
      ..writeByte(8)
      ..writeByte(4)
      ..write(obj.id)
      ..writeByte(5)
      ..write(obj.email)
      ..writeByte(6)
      ..write(obj.username)
      ..writeByte(7)
      ..write(obj.fullName)
      ..writeByte(9)
      ..write(obj.groupMap)
      ..writeByte(11)
      ..write(obj.courseIds)
      ..writeByte(12)
      ..write(obj.avatarBytes)
      ..writeByte(13)
      ..write(obj.hasAvatar);
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
      hasAttachments: fields[21] as bool,
      fileAttachments: (fields[5] as List?)?.cast<String>(),
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
      ..writeByte(22)
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
      ..write(obj.grade)
      ..writeByte(21)
      ..write(obj.hasAttachments);
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

class QuizAdapter extends TypeAdapter<Quiz> {
  @override
  final typeId = 5;

  @override
  Quiz read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Quiz(
      id: fields[0] as String,
      courseId: fields[1] as String,
      instructorId: fields[2] as String,
      title: fields[3] as String,
      description: fields[4] as String?,
      openTime: fields[5] as DateTime,
      closeTime: fields[6] as DateTime,
      durationMinutes: (fields[7] as num).toInt(),
      maxAttempts: (fields[8] as num).toInt(),
      easyQuestions: (fields[9] as num).toInt(),
      mediumQuestions: (fields[10] as num).toInt(),
      hardQuestions: (fields[11] as num).toInt(),
      totalPoints: (fields[12] as num).toInt(),
      scopeType: fields[13] as String,
      targetGroups: (fields[14] as List).cast<String>(),
      createdAt: fields[15] as DateTime,
      attemptCount: (fields[17] as num?)?.toInt(),
      highestScore: (fields[18] as num?)?.toDouble(),
      isCompleted: fields[19] as bool?,
      submissionCount: (fields[20] as num?)?.toInt(),
      semesterId: fields[16] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Quiz obj) {
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
      ..write(obj.openTime)
      ..writeByte(6)
      ..write(obj.closeTime)
      ..writeByte(7)
      ..write(obj.durationMinutes)
      ..writeByte(8)
      ..write(obj.maxAttempts)
      ..writeByte(9)
      ..write(obj.easyQuestions)
      ..writeByte(10)
      ..write(obj.mediumQuestions)
      ..writeByte(11)
      ..write(obj.hardQuestions)
      ..writeByte(12)
      ..write(obj.totalPoints)
      ..writeByte(13)
      ..write(obj.scopeType)
      ..writeByte(14)
      ..write(obj.targetGroups)
      ..writeByte(15)
      ..write(obj.createdAt)
      ..writeByte(16)
      ..write(obj.semesterId)
      ..writeByte(17)
      ..write(obj.attemptCount)
      ..writeByte(18)
      ..write(obj.highestScore)
      ..writeByte(19)
      ..write(obj.isCompleted)
      ..writeByte(20)
      ..write(obj.submissionCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuizAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AnnouncementAdapter extends TypeAdapter<Announcement> {
  @override
  final typeId = 6;

  @override
  Announcement read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Announcement(
      id: fields[0] as String,
      courseId: fields[1] as String,
      instructorId: fields[2] as String,
      title: fields[3] as String,
      content: fields[4] as String,
      scopeType: fields[6] as String,
      targetGroups: (fields[7] as List).cast<String>(),
      createdAt: fields[8] as DateTime,
      fileAttachments: (fields[5] as List?)?.cast<String>(),
      hasAttachments: fields[12] == null ? false : fields[12] as bool,
      viewCount: (fields[9] as num?)?.toInt(),
      commentCount: (fields[10] as num?)?.toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, Announcement obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.courseId)
      ..writeByte(2)
      ..write(obj.instructorId)
      ..writeByte(3)
      ..write(obj.title)
      ..writeByte(4)
      ..write(obj.content)
      ..writeByte(5)
      ..write(obj.fileAttachments)
      ..writeByte(6)
      ..write(obj.scopeType)
      ..writeByte(7)
      ..write(obj.targetGroups)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.viewCount)
      ..writeByte(10)
      ..write(obj.commentCount)
      ..writeByte(12)
      ..write(obj.hasAttachments);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnnouncementAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CourseMaterialAdapter extends TypeAdapter<CourseMaterial> {
  @override
  final typeId = 7;

  @override
  CourseMaterial read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CourseMaterial(
      id: fields[0] as String,
      courseId: fields[1] as String,
      instructorId: fields[2] as String,
      title: fields[3] as String,
      description: fields[4] as String?,
      fileAttachments: (fields[13] as List?)?.cast<String>(),
      hasAttachments: fields[12] as bool,
      externalLinks: (fields[6] as List).cast<String>(),
      createdAt: fields[7] as DateTime,
      semesterId: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CourseMaterial obj) {
    writer
      ..writeByte(10)
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
      ..writeByte(6)
      ..write(obj.externalLinks)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.semesterId)
      ..writeByte(12)
      ..write(obj.hasAttachments)
      ..writeByte(13)
      ..write(obj.fileAttachments);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseMaterialAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SemesterAdapter extends TypeAdapter<Semester> {
  @override
  final typeId = 8;

  @override
  Semester read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Semester(
      id: fields[0] as String,
      code: fields[1] as String,
      name: fields[2] as String,
      isCurrent: fields[3] as bool,
      createdAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Semester obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.code)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.isCurrent)
      ..writeByte(4)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SemesterAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class QuestionAdapter extends TypeAdapter<Question> {
  @override
  final typeId = 9;

  @override
  Question read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Question(
      id: fields[0] as String,
      courseId: fields[1] as String,
      questionText: fields[2] as String,
      options: (fields[3] as List).cast<QuestionOption>(),
      difficulty: fields[4] as String,
      createdAt: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Question obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.courseId)
      ..writeByte(2)
      ..write(obj.questionText)
      ..writeByte(3)
      ..write(obj.options)
      ..writeByte(4)
      ..write(obj.difficulty)
      ..writeByte(5)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuestionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class QuestionOptionAdapter extends TypeAdapter<QuestionOption> {
  @override
  final typeId = 10;

  @override
  QuestionOption read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QuestionOption(
      text: fields[0] as String,
      isCorrect: fields[1] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, QuestionOption obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.text)
      ..writeByte(1)
      ..write(obj.isCorrect);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuestionOptionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class QuizAttemptAdapter extends TypeAdapter<QuizAttempt> {
  @override
  final typeId = 11;

  @override
  QuizAttempt read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QuizAttempt(
      id: fields[0] as String,
      quizId: fields[1] as String,
      studentId: fields[2] as String,
      studentName: fields[3] as String,
      attemptNumber: (fields[4] as num).toInt(),
      startedAt: fields[5] as DateTime,
      submittedAt: fields[6] as DateTime?,
      score: (fields[7] as num?)?.toDouble(),
      isCompleted: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, QuizAttempt obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.quizId)
      ..writeByte(2)
      ..write(obj.studentId)
      ..writeByte(3)
      ..write(obj.studentName)
      ..writeByte(4)
      ..write(obj.attemptNumber)
      ..writeByte(5)
      ..write(obj.startedAt)
      ..writeByte(6)
      ..write(obj.submittedAt)
      ..writeByte(7)
      ..write(obj.score)
      ..writeByte(8)
      ..write(obj.isCompleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuizAttemptAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AssignmentSubmissionAdapter extends TypeAdapter<AssignmentSubmission> {
  @override
  final typeId = 12;

  @override
  AssignmentSubmission read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AssignmentSubmission(
      id: fields[0] as String,
      assignmentId: fields[1] as String,
      studentId: fields[2] as String,
      submissionFiles: (fields[4] as List).cast<String>(),
      hasAttachments: fields[12] as bool,
      submissionText: fields[5] as String?,
      attemptNumber: (fields[6] as num).toInt(),
      submittedAt: fields[7] as DateTime,
      isLate: fields[8] as bool,
      grade: (fields[9] as num?)?.toDouble(),
      feedback: fields[10] as String?,
      gradedAt: fields[11] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, AssignmentSubmission obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.assignmentId)
      ..writeByte(2)
      ..write(obj.studentId)
      ..writeByte(4)
      ..write(obj.submissionFiles)
      ..writeByte(5)
      ..write(obj.submissionText)
      ..writeByte(6)
      ..write(obj.attemptNumber)
      ..writeByte(7)
      ..write(obj.submittedAt)
      ..writeByte(8)
      ..write(obj.isLate)
      ..writeByte(9)
      ..write(obj.grade)
      ..writeByte(10)
      ..write(obj.feedback)
      ..writeByte(11)
      ..write(obj.gradedAt)
      ..writeByte(12)
      ..write(obj.hasAttachments);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssignmentSubmissionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ForumAdapter extends TypeAdapter<Forum> {
  @override
  final typeId = 13;

  @override
  Forum read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Forum(
      id: fields[0] as String,
      courseId: fields[1] as String,
      title: fields[2] as String,
      content: fields[3] as String,
      createdBy: fields[7] as String,
      replyCount: fields[5] == null ? 0 : (fields[5] as num).toInt(),
      createdAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Forum obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.courseId)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.content)
      ..writeByte(5)
      ..write(obj.replyCount)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.createdBy);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ForumAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ForumReplyAdapter extends TypeAdapter<ForumReply> {
  @override
  final typeId = 14;

  @override
  ForumReply read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ForumReply(
      id: fields[0] as String,
      forumId: fields[1] as String,
      content: fields[2] as String,
      userId: fields[3] as String,
      createdAt: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ForumReply obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.forumId)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.userId)
      ..writeByte(5)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ForumReplyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
