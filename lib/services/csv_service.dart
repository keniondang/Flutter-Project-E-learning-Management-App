import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class CSVService {
  // CSV Import Result Model
  static Map<String, dynamic> createImportResult({
    required List<Map<String, dynamic>> data,
    required List<String> headers,
    required int successCount,
    required int errorCount,
    required int duplicateCount,
  }) {
    return {
      'data': data,
      'headers': headers,
      'successCount': successCount,
      'errorCount': errorCount,
      'duplicateCount': duplicateCount,
    };
  }

  // Pick and parse CSV file
  static Future<Map<String, dynamic>?> pickAndParseCSV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        final csvString = utf8.decode(bytes);
        
        List<List<dynamic>> csvTable = const CsvToListConverter().convert(
          csvString,
          eol: '\n',
        );

        if (csvTable.isEmpty) {
          return null;
        }

        // Extract headers
        List<String> headers = csvTable[0].map((e) => e.toString().trim()).toList();
        
        // Convert to list of maps
        List<Map<String, dynamic>> data = [];
        for (int i = 1; i < csvTable.length; i++) {
          Map<String, dynamic> row = {};
          for (int j = 0; j < headers.length && j < csvTable[i].length; j++) {
            row[headers[j]] = csvTable[i][j]?.toString().trim() ?? '';
          }
          data.add(row);
        }

        return {
          'headers': headers,
          'data': data,
          'fileName': result.files.single.name,
        };
      }
    } catch (e) {
      debugPrint('Error parsing CSV: $e');
    }
    return null;
  }

  // Generate sample CSV content
  static String generateSampleCSV(String type) {
    switch (type) {
      case 'students':
        return 'username,email,full_name,password\n'
               'johndoe,johndoe@student.edu,John Doe,password123\n'
               'janedoe,janedoe@student.edu,Jane Doe,password456';
      case 'groups':
        return 'group_name\n'
               'Group A\n'
               'Group B\n'
               'Group C';
      case 'enrollments':
        return 'student_username,group_name\n'
               'johndoe,Group A\n'
               'janedoe,Group B';
      default:
        return '';
    }
  }
}