class CourseMaterial {
  final String id;
  final String courseId;
  final String instructorId;
  final String title;
  final String? description;
  final List<String> fileUrls;
  final List<String> externalLinks;
  final DateTime createdAt;
  
  // Additional fields
  final int? viewCount;
  final int? downloadCount;
  final bool? hasViewed;

  CourseMaterial({
    required this.id,
    required this.courseId,
    required this.instructorId,
    required this.title,
    this.description,
    required this.fileUrls,
    required this.externalLinks,
    required this.createdAt,
    this.viewCount,
    this.downloadCount,
    this.hasViewed,
  });

  factory CourseMaterial.fromJson(Map<String, dynamic> json) {
    return CourseMaterial(
      id: json['id'],
      courseId: json['course_id'],
      instructorId: json['instructor_id'],
      title: json['title'],
      description: json['description'],
      fileUrls: List<String>.from(json['file_urls'] ?? []),
      externalLinks: List<String>.from(json['external_links'] ?? []),
      createdAt: DateTime.parse(json['created_at']),
      viewCount: json['view_count'],
      downloadCount: json['download_count'],
      hasViewed: json['has_viewed'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'course_id': courseId,
      'instructor_id': instructorId,
      'title': title,
      'description': description,
      'file_urls': fileUrls,
      'external_links': externalLinks,
    };
  }
}