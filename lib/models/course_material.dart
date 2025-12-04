class CourseMaterial {
  final String id;
  final String courseId;
  final String instructorId;
  final String title;
  final String? description;
  final bool hasAttachments;
  final List<String> fileAttachments;
  final List<String> externalLinks;
  final DateTime createdAt;

  final String? semesterId;

  // Additional fields
  final int? viewCount;
  final int? downloadCount;
  final bool? hasViewed;

  CourseMaterial(
      {required this.id,
      required this.courseId,
      required this.instructorId,
      required this.title,
      this.description,
      List<String>? fileAttachments,
      required this.hasAttachments,
      required this.externalLinks,
      required this.createdAt,
      this.viewCount,
      this.downloadCount,
      this.hasViewed,
      this.semesterId})
      : fileAttachments = fileAttachments ?? [];

  factory CourseMaterial.fromJson(
      {required Map<String, dynamic> json,
      List<String>? fileAttachments,
      int? viewCount,
      int? downloadCount}) {
    return CourseMaterial(
      id: json['id'],
      courseId: json['course_id'],
      instructorId: json['instructor_id'],
      title: json['title'],
      description: json['description'],
      hasAttachments: json['has_attachments'],
      fileAttachments: fileAttachments ?? [],
      externalLinks: List<String>.from(json['external_links'] ?? []),
      createdAt: DateTime.parse(json['created_at']),
      viewCount: viewCount ?? json['view_count'],
      downloadCount: downloadCount ?? json['download_count'],
      hasViewed: json['has_viewed'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'course_id': courseId,
      'instructor_id': instructorId,
      'title': title,
      'description': description,
      'file_urls': fileAttachments,
      'external_links': externalLinks,
    };
  }
}
