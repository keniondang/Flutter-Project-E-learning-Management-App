import 'package:elearning_management_app/providers/course_material_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/course_material.dart';
import '../../models/user_model.dart';

class MaterialViewerScreen extends StatefulWidget {
  final CourseMaterial material;
  final UserModel student;

  const MaterialViewerScreen({
    super.key,
    required this.material,
    required this.student,
  });

  @override
  State<MaterialViewerScreen> createState() => _MaterialViewerScreenState();
}

class _MaterialViewerScreenState extends State<MaterialViewerScreen> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> _handleFileDownload(String url) async {
    final fileName = url.split('/').last;

    final bytes =
        await context.read<CourseMaterialProvider>().fetchFileAttachment(url);

    if (bytes != null) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Material', style: GoogleFonts.poppins()),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              // _trackDownload();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Download feature will be implemented'),
                ),
              );
            },
            tooltip: 'Download All',
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
                          Icon(Icons.folder, color: Colors.blue),
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
}
