import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import 'categories_screen.dart';
import 'search_screen.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  List<Map<String, dynamic>> members = [];

  @override
  void initState() {
    super.initState();
    loadMembers();
  }

  Future<void> loadMembers() async {
    final data = await DatabaseHelper.instance.getMembers();
    setState(() {
      members = data;
    });
  }

  void showAddMemberDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Family Member"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter member name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await DatabaseHelper.instance.addMember(controller.text.trim());
                Navigator.pop(context);
                loadMembers();
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void showRenameMemberDialog(int id, String oldName) {
    final controller = TextEditingController(text: oldName);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Rename Member"),
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
                await DatabaseHelper.instance.renameMember(
                  id,
                  controller.text.trim(),
                );
                Navigator.pop(context);
                loadMembers();
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
      appBar: AppBar(
        title: const Text("Family Members"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
        ],
      ),

      body: members.isEmpty
          ? const Center(child: Text("No members added yet"))
          : ListView.builder(
              itemCount: members.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(members[index]['name']),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoriesScreen(
                          memberId: members[index]['id'],
                          memberName: members[index]['name'],
                        ),
                      ),
                    );
                  },
                  onLongPress: () {
                    showRenameMemberDialog(
                      members[index]['id'],
                      members[index]['name'],
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: showAddMemberDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
