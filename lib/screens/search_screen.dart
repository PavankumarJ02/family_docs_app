import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../db/database_helper.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List<Map<String, dynamic>> results = [];
  final controller = TextEditingController();

  Future<void> search(String text) async {
    if (text.trim().isEmpty) {
      setState(() => results = []);
      return;
    }

    final data = await DatabaseHelper.instance.searchDocuments(text.trim());
    setState(() {
      results = data;
    });
  }

  void showInfo(Map<String, dynamic> doc) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Document Info"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("📄 ${doc['file_name']}"),
            const SizedBox(height: 6),
            Text("📦 ${(doc['size'] / 1024).toStringAsFixed(1)} KB"),
            const SizedBox(height: 6),
            Text("📅 ${doc['created_at'].split('T')[0]}"),
            const SizedBox(height: 6),
            Text("🔄 ${doc['sync_status']}"),
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
      appBar: AppBar(title: const Text("Search Documents")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: "Search by file name",
                border: OutlineInputBorder(),
              ),
              onChanged: search,
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? const Center(child: Text("No results"))
                : ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final doc = results[index];
                      return ListTile(
                        leading: const Icon(Icons.insert_drive_file),
                        title: Text(doc['file_name']),
                        onTap: () {
                          OpenFilex.open(doc['file_path']);
                        },
                        onLongPress: () {
                          showInfo(doc);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
