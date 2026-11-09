import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/category_item.dart';
import '../theme/app_colors.dart';
import '../widgets/category_card.dart';
import '../widgets/empty_state_view.dart';
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
  List<CategoryItem> _categories = [];
  bool _isLoading = true;
  int _selectedSpaceTab = 0; // 0: Shared Family Space, 1: Personal Vault

  @override
  void initState() {
    super.initState();
    loadCategories();
  }

  Future<void> loadCategories() async {
    setState(() => _isLoading = true);
    final db = DatabaseHelper.instance;
    final data = await db.getCategories(widget.memberId);

    final list = <CategoryItem>[];
    for (final raw in data) {
      final catId = raw['id'] as int;
      final count = await db.getCategoryDocumentCount(catId);
      list.add(CategoryItem.fromMap(raw, documentCount: count));
    }

    if (!mounted) return;
    setState(() {
      _categories = list;
      _isLoading = false;
    });
  }

  void showAddCategoryDialog() {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Create Document Category",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.enclavePrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Organize documents for ${widget.memberName}",
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: "Category name (e.g. Identity, Medical, Tax)",
                prefixIcon: Icon(Icons.create_new_folder_outlined),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancel"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = controller.text.trim();
                      if (name.isNotEmpty) {
                        final nav = Navigator.of(ctx);
                        await DatabaseHelper.instance.addCategory(
                          widget.memberId,
                          name,
                        );
                        nav.pop();
                        if (mounted) {
                          loadCategories();
                        }
                      }
                    },
                    child: const Text("Create"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void showCategoryOptionsModal(CategoryItem category) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                category.name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.enclavePrimary,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(
                  Icons.edit_rounded,
                  color: AppColors.securityIndigo,
                ),
                title: const Text("Rename Category"),
                onTap: () {
                  Navigator.pop(ctx);
                  showRenameCategoryDialog(category.id, category.name);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.alertRose,
                ),
                title: const Text(
                  "Delete Category & Documents",
                  style: TextStyle(color: AppColors.alertRose),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  confirmDeleteCategory(category);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showRenameCategoryDialog(int id, String oldName) {
    final controller = TextEditingController(text: oldName);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          "Rename Category",
          style: TextStyle(
            color: AppColors.enclavePrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Enter new category name",
            prefixIcon: Icon(Icons.edit_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await DatabaseHelper.instance.renameCategory(id, newName);
                if (mounted) {
                  Navigator.pop(context);
                  loadCategories();
                }
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void confirmDeleteCategory(CategoryItem category) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Category?"),
        content: Text(
          "Are you sure you want to delete '${category.name}'? All files inside this category will be removed.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertRose,
            ),
            onPressed: () async {
              await DatabaseHelper.instance.deleteCategory(category.id);
              if (mounted) {
                Navigator.pop(context);
                loadCategories();
              }
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      appBar: AppBar(
        title: Text("${widget.memberName}'s Vault"),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: "Add Category",
            onPressed: showAddCategoryDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadCategories,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Space Partitioning Selector Pill (Stitch Screen 4)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedSpaceTab = 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _selectedSpaceTab == 0
                                    ? AppColors.cardSurface
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _selectedSpaceTab == 0
                                    ? const [
                                        BoxShadow(
                                          color: Color(0x0A0F172A),
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  "Shared Space",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _selectedSpaceTab == 0
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: _selectedSpaceTab == 0
                                        ? AppColors.enclavePrimary
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedSpaceTab = 1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _selectedSpaceTab == 1
                                    ? AppColors.cardSurface
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _selectedSpaceTab == 1
                                    ? const [
                                        BoxShadow(
                                          color: Color(0x0A0F172A),
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  "Personal Space",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _selectedSpaceTab == 1
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: _selectedSpaceTab == 1
                                        ? AppColors.enclavePrimary
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Categories Grid or Empty State
                  if (_categories.isEmpty)
                    EmptyStateView(
                      icon: Icons.create_new_folder_outlined,
                      title: "No Categories Yet",
                      description:
                          "Create categories like Identity, Health, or Property to organize documents for ${widget.memberName}.",
                      actionLabel: "Add Category",
                      onAction: showAddCategoryDialog,
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.15,
                          ),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        return CategoryCard(
                          category: cat,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DocumentsScreen(
                                  memberId: widget.memberId,
                                  categoryId: cat.id,
                                  categoryName: cat.name,
                                ),
                              ),
                            ).then((_) => loadCategories());
                          },
                          onLongPress: () {
                            showCategoryOptionsModal(cat);
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showAddCategoryDialog,
        backgroundColor: AppColors.enclavePrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text("New Category"),
      ),
    );
  }
}
