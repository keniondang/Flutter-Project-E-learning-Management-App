import 'dart:typed_data';

import 'package:elearning_management_app/models/analytic.dart';
import 'package:elearning_management_app/models/student.dart';
import 'package:elearning_management_app/providers/course_material_provider.dart';
import 'package:elearning_management_app/providers/student_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/course_material.dart';
import '../../models/user_model.dart';

class MaterialViewerScreen extends StatefulWidget {
  final CourseMaterial material;
  final UserModel user;

  const MaterialViewerScreen({
    super.key,
    required this.material,
    required this.user,
  });

  @override
  State<MaterialViewerScreen> createState() => _MaterialViewerScreenState();
}

class _MaterialViewerScreenState extends State<MaterialViewerScreen> {
  @override
  void initState() {
    super.initState();

    if (widget.user.isStudent) {
      context
          .read<CourseMaterialProvider>()
          .markAsViewed(widget.material.id, widget.user.id);
    }
  }

  Future<void> _handleFileDownload(String url) async {
    final fileName = url.split('/').last;

    final bytes =
        await context.read<CourseMaterialProvider>().fetchFileAttachment(url);

    if (bytes != null) {
      if (widget.user.isStudent && mounted) {
        context
            .read<CourseMaterialProvider>()
            .trackDownload(widget.material.id, widget.user.id, fileName);
      }

      await FilePicker.platform.saveFile(fileName: fileName, bytes: bytes);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error downloading $fileName'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open $url')));
    }
  }

  void _showViewersSheet() {
    if (!widget.user.isInstructor) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _buildViewersBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Material', style: GoogleFonts.poppins()),
        actions: [
          if (widget.user.isInstructor)
            IconButton(
              icon: const Icon(Icons.analytics_outlined),
              tooltip: 'See Viewers & Downloads',
              onPressed: _showViewersSheet,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and description
            Text(
              widget.material.title,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.material.description != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.material.description!,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Files section
            if (widget.material.fileAttachments.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.folder, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            'Files',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...widget.material.fileAttachments.map((url) {
                        final fileName = url.split('/').last;
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              Icons.insert_drive_file,
                              color: Colors.grey[600],
                            ),
                            title: Text(fileName, style: GoogleFonts.poppins()),
                            trailing: IconButton(
                              icon: const Icon(Icons.download),
                              onPressed: () {
                                _handleFileDownload(url);
                              },
                              tooltip: 'Download',
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // External links section
            if (widget.material.externalLinks.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.link, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            'External Links',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...widget.material.externalLinks.map((link) {
                        return Card(
                          child: ListTile(
                            leading:
                                const Icon(Icons.public, color: Colors.blue),
                            title: Text(
                              link,
                              style: GoogleFonts.poppins(fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.open_in_new),
                              onPressed: () => _openLink(link),
                              tooltip: 'Open Link',
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildViewersBottomSheet() {
    return FutureBuilder<List<ViewAnalytic>>(
      future: context
          .read<CourseMaterialProvider>()
          .fetchViewAnalytics(widget.material.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final viewers = snapshot.data ?? [];

        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Viewed by ${viewers.length} students',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (viewers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text('No views yet')),
                )
              else
                Expanded(
                  child: FutureBuilder<List<MapEntry<String, Student?>>>(
                    future: Future.wait(viewers
                        .map((x) => x.userId)
                        .toSet()
                        .map((x) async => MapEntry(
                            x,
                            await context
                                .read<StudentProvider>()
                                .fetchUser(x)))),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final userMap = Map.fromEntries(
                          snapshot.data!.where((x) => x.value != null));

                      viewers.sort((a, b) => b.viewedAt.compareTo(a.viewedAt));

                      return ListView.builder(
                        itemCount: viewers.length,
                        itemBuilder: (context, index) {
                          final UserModel user =
                              userMap[viewers[index].userId]!;

                          return ListTile(
                            leading: user.hasAvatar
                                ? CircleAvatar(
                                    child: null,
                                    backgroundImage: MemoryImage(
                                        user.avatarBytes! as Uint8List))
                                : CircleAvatar(
                                    child:
                                        Text(user.fullName[0].toUpperCase())),
                            title: Text(user.fullName),
                            subtitle: Text(user.email),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  DateFormat('MMM dd, HH:mm')
                                      .format(viewers[index].viewedAt),
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                                if (widget.material.hasAttachments)
                                  IconButton(
                                    icon: const Icon(Icons.info_outline,
                                        color: Colors.blue),
                                    tooltip: 'View Downloads',
                                    onPressed: () =>
                                        _showDownloadAnalytics(context, user),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showDownloadAnalytics(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${user.fullName}\'s Downloads',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 500,
          child: FutureBuilder<List<DownloadAnalytic>>(
            future: context
                .read<CourseMaterialProvider>()
                .fetchDownloadAnalytics(widget.material.id, user.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }

              final downloads = snapshot.data ?? [];

              if (downloads.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No files downloaded.'),
                );
              }

              downloads
                  .sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListView.separated(
                    shrinkWrap: true,
                    separatorBuilder: (context, index) => const Divider(),
                    itemCount: downloads.length,
                    itemBuilder: (context, index) {
                      final item = downloads[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading:
                            const Icon(Icons.file_download, color: Colors.grey),
                        title: Text(item.fileName,
                            style:
                                const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text(
                          DateFormat('MMM dd, HH:mm').format(item.downloadedAt),
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
