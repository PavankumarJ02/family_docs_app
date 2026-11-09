import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../db/database_helper.dart';
import 'package:open_filex/open_filex.dart';

class DocumentsScreen extends StatefulWidget {
  final int memberId;
  final int categoryId;
  final String categoryName;

  const DocumentsScreen({
    super.key,
    required this.memberId,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<Map<String, dynamic>> documents = [];

  @override
  void initState() {
    super.initState();
    loadDocuments();
  }

  Future<void> loadDocuments() async {
    final db = await DatabaseHelper.instance.database;
    final data = await db.query(
      'documents',
      where: 'member_id = ? AND category_id = ?',
      whereArgs: [widget.memberId, widget.categoryId],
      orderBy: 'created_at DESC',
    );
    setState(() {
      documents = data;
    });
  }

  Future<void> pickAndSaveDocument() async {
    final typeGroup = XTypeGroup(
      label: 'documents',
      extensions: ['pdf', 'jpg', 'png'],
    );

    final file = await openFile(acceptedTypeGroups: [typeGroup]);

    if (file == null) return;

    final pickedFile = File(file.path);
    final fileName = p.basename(pickedFile.path);
    final fileSize = await pickedFile.length();

    final dir = await getApplicationDocumentsDirectory();
    final saveDir = Directory(
      '${dir.path}/member_${widget.memberId}/category_${widget.categoryId}',
    );
    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }

    final savedFile = await pickedFile.copy('${saveDir.path}/$fileName');

    await DatabaseHelper.instance.addDocument({
      'member_id': widget.memberId,
      'category_id': widget.categoryId,
      'file_name': fileName,
      'file_path': savedFile.path,
      'size': fileSize,
      'created_at': DateTime.now().toIso8601String(),
      'sync_status': 'pending',
    });

    loadDocuments();
  }

  void showDocumentInfo(Map<String, dynamic> doc) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Document Info"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("📄 Name: ${doc['file_name']}"),
            const SizedBox(height: 8),
            Text("📦 Size: ${(doc['size'] / 1024).toStringAsFixed(1)} KB"),
            const SizedBox(height: 8),
            Text("📅 Added: ${doc['created_at'].split('T')[0]}"),
            const SizedBox(height: 8),
            Text("🔄 Sync: ${doc['sync_status']}"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.categoryName)),
      body: documents.isEmpty
          ? const Center(child: Text("No documents added yet"))
          : ListView.builder(
              itemCount: documents.length,
              itemBuilder: (context, index) {
                final doc = documents[index];
                return ListTile(
                  leading: const Icon(Icons.insert_drive_file),
                  title: Text(doc['file_name']),
                  subtitle: Text(
                    "Size: ${(doc['size'] / 1024).toStringAsFixed(1)} KB",
                  ),
                  onTap: () {
                    OpenFilex.open(doc['file_path']);
                  },
                  onLongPress: () {
                    showDocumentInfo(doc);
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: pickAndSaveDocument,
        child: const Icon(Icons.upload_file),
      ),
    );
  }
}
