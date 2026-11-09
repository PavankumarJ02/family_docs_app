import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import 'documents_screen.dart';

class CategoriesScreen extends StatefulWidget {
  final int memberId;
  final String memberName;

  const CategoriesScreen({
    super.key,
    required this.memberId,
    required this.memberName,
  });

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<Map<String, dynamic>> categories = [];

  @override
  void initState() {
    super.initState();
    loadCategories();
  }

  Future<void> loadCategories() async {
    final data = await DatabaseHelper.instance.getCategories(widget.memberId);
    setState(() {
      categories = data;
    });
  }

  void showAddCategoryDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Category"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter category name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await DatabaseHelper.instance.addCategory(
                  widget.memberId,
                  controller.text.trim(),
                );
                Navigator.pop(context);
                loadCategories();
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void showRenameCategoryDialog(int id, String oldName) {
    final controller = TextEditingController(text: oldName);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Rename Category"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter new name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await DatabaseHelper.instance.renameCategory(
                  id,
                  controller.text.trim(),
                );
                Navigator.pop(context);
                loadCategories();
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("${widget.memberName}'s Categories")),
      body: categories.isEmpty
          ? const Center(child: Text("No categories added yet"))
          : ListView.builder(
              itemCount: categories.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.folder),
                  title: Text(categories[index]['name']),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DocumentsScreen(
                          memberId: widget.memberId,
                          categoryId: categories[index]['id'],
                          categoryName: categories[index]['name'],
                        ),
                      ),
                    );
                  },
                  onLongPress: () {
                    showRenameCategoryDialog(
                      categories[index]['id'],
                      categories[index]['name'],
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: showAddCategoryDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
