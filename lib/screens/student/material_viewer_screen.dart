import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/course_material.dart';
import '../../models/user_model.dart';

class MaterialViewerScreen extends StatefulWidget {
  final CourseMaterial material;
  final UserModel student;

  const MaterialViewerScreen({
    Key? key,
    required this.material,
    required this.student,
  }) : super(key: key);

  @override
  State<MaterialViewerScreen> createState() => _MaterialViewerScreenState();
}

class _MaterialViewerScreenState extends State<MaterialViewerScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _trackView();
  }

  Future<void> _trackView() async {
    try {
      await _supabase.from('material_views').upsert({
        'material_id': widget.material.id,
        'user_id': widget.student.id,
        'viewed_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error tracking view: $e');
    }
  }

  Future<void> _trackDownload() async {
    try {
      final response = await _supabase
          .from('material_views')
          .select('downloads')
          .eq('material_id', widget.material.id)
          .eq('user_id', widget.student.id)
          .single();

      final currentDownloads = response['downloads'] ?? 0;

      await _supabase
          .from('material_views')
          .update({'downloads': currentDownloads + 1})
          .eq('material_id', widget.material.id)
          .eq('user_id', widget.student.id);
    } catch (e) {
      print('Error tracking download: $e');
    }
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
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
              _trackDownload();
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
            if (widget.material.fileUrls.isNotEmpty) ...[
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
                      ...widget.material.fileUrls.map((url) {
                        final fileName = url.split('/').last;
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              Icons.insert_drive_file,
                              color: Colors.grey[600],
                            ),
                            title: Text(fileName, style: GoogleFonts.poppins()),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility),
                                  onPressed: () {
                                    // Preview functionality
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Preview coming soon'),
                                      ),
                                    );
                                  },
                                  tooltip: 'Preview',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.download),
                                  onPressed: () {
                                    _trackDownload();
                                    _openLink(url);
                                  },
                                  tooltip: 'Download',
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
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
                          Icon(Icons.link, color: Colors.green),
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
                            leading: Icon(Icons.public, color: Colors.blue),
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
                      }).toList(),
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
