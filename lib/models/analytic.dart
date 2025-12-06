class ViewAnalytic {
  final String userId;
  final DateTime viewedAt;

  ViewAnalytic({required this.userId, required this.viewedAt});

  factory ViewAnalytic.fromJson(Map<String, dynamic> json) {
    return ViewAnalytic(
        userId: json['user_id'], viewedAt: DateTime.parse(json['viewed_at']));
  }
}

class DownloadAnalytic {
  final String fileName;
  final DateTime downloadedAt;

  DownloadAnalytic({required this.fileName, required this.downloadedAt});

  factory DownloadAnalytic.fromJson(Map<String, dynamic> json) {
    return DownloadAnalytic(
        fileName: json['file_name'],
        downloadedAt: DateTime.parse(json['downloaded_at']));
  }
}
