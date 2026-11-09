import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../db/database_helper.dart';
import '../models/document_item.dart';
import '../models/member.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/document_card.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/family_member_avatar.dart';
import '../widgets/vault_hero_card.dart';
import 'categories_screen.dart';
import 'reminders_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  int _currentNavIndex = 0;
  List<Map<String, dynamic>> _members = [];
  Map<int, int> _memberDocCounts = {};
  List<DocumentItem> _recentDocs = [];
  int _totalDocs = 0;
  int _totalStorageBytes = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    loadDashboardData();
  }

  Future<void> loadDashboardData() async {
    setState(() => _isLoading = true);
    final db = DatabaseHelper.instance;

    final membersData = await db.getMembers();
    final recentRaw = await db.getRecentDocuments(limit: 6);
    final totalDocs = await db.getTotalDocumentCount();
    final totalBytes = await db.getTotalStorageBytes();

    final counts = <int, int>{};
    for (final m in membersData) {
      final id = m['id'] as int;
      counts[id] = await db.getMemberDocumentCount(id);
    }

    if (!mounted) return;

    setState(() {
      _members = membersData;
      _memberDocCounts = counts;
      _recentDocs = recentRaw.map((m) => DocumentItem.fromMap(m)).toList();
      _totalDocs = totalDocs;
      _totalStorageBytes = totalBytes;
      _isLoading = false;
    });
  }

  String _formatStorage(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  void _onBottomNavTapped(int index) {
    if (index == _currentNavIndex) return;

    if (index == 0) {
      setState(() => _currentNavIndex = 0);
      loadDashboardData();
      return;
    }

    if (index == 1) {
      // Members quick action
      showAddMemberDialog();
      return;
    }

    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SearchScreen()),
      ).then((_) => loadDashboardData());
      return;
    }

    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RemindersScreen()),
      ).then((_) => loadDashboardData());
      return;
    }

    if (index == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      ).then((_) => loadDashboardData());
      return;
    }
  }

  void showAddMemberDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          "Add Family Member",
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
            hintText: "Enter member name (e.g. Rahul, Priya)",
            prefixIcon: Icon(Icons.person_add_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await DatabaseHelper.instance.addMember(name);
                if (mounted) {
                  Navigator.pop(context);
                  loadDashboardData();
                }
              }
            },
            child: const Text("Add Member"),
          ),
        ],
      ),
    );
  }

  void showMemberOptionsModal(int id, String currentName) {
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
                currentName,
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
                title: const Text("Rename Member"),
                onTap: () {
                  Navigator.pop(ctx);
                  showRenameMemberDialog(id, currentName);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.alertRose,
                ),
                title: const Text(
                  "Delete Member & Documents",
                  style: TextStyle(color: AppColors.alertRose),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  confirmDeleteMember(id, currentName);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showRenameMemberDialog(int id, String oldName) {
    final controller = TextEditingController(text: oldName);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          "Rename Family Member",
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
            hintText: "Enter new name",
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
                await DatabaseHelper.instance.renameMember(id, newName);
                if (mounted) {
                  Navigator.pop(context);
                  loadDashboardData();
                }
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void confirmDeleteMember(int id, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Member?"),
        content: Text(
          "Are you sure you want to delete '$name'? All categories and files belonging to this member will be permanently removed.",
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
              await DatabaseHelper.instance.deleteMember(id);
              if (mounted) {
                Navigator.pop(context);
                loadDashboardData();
              }
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void showDocumentMetadataSheet(DocumentItem doc) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.securityIndigoSubtle,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      doc.isPdf
                          ? Icons.picture_as_pdf_rounded
                          : Icons.insert_drive_file_rounded,
                      color: AppColors.securityIndigo,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.enclavePrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${doc.formattedSize} • Added ${doc.formattedDate}",
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildMetaRow("Storage Status", "Local Encrypted Enclave"),
                    const SizedBox(height: 8),
                    _buildMetaRow(
                      "File Location",
                      doc.filePath,
                      isSecondary: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text("Open File"),
                      onPressed: () {
                        Navigator.pop(ctx);
                        OpenFilex.open(doc.filePath);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.alertRose,
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text("Delete"),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await DatabaseHelper.instance.deleteDocument(
                          doc.id,
                          doc.filePath,
                        );
                        loadDashboardData();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, {bool isSecondary = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: isSecondary ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSecondary ? FontWeight.w400 : FontWeight.w600,
              color: AppColors.enclavePrimary,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      appBar: AppBar(
        title: const Text("Family Vault"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: "Search Documents",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ).then((_) => loadDashboardData());
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: "Add Family Member",
            onPressed: showAddMemberDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadDashboardData,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  // 1. Vault Hero Card
                  VaultHeroCard(
                    totalDocuments: _totalDocs,
                    formattedStorage: _formatStorage(_totalStorageBytes),
                    onScanTap: () {},
                    onUploadTap: () {},
                  ),
                  const SizedBox(height: 24),

                  // 2. Family Members Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Family Members",
                        style: TextStyle(
                          color: AppColors.enclavePrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: showAddMemberDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text("Add"),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.securityIndigo,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 3. Family Members Horizontal Carousel
                  if (_members.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.surfaceBorder,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: TextButton.icon(
                          onPressed: showAddMemberDialog,
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: const Text("Add First Family Member"),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 155,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _members.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          if (index == _members.length) {
                            // Add Member Card at end of reel
                            return GestureDetector(
                              onTap: showAddMemberDialog,
                              child: Container(
                                width: 120,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: AppColors.surfaceBorder,
                                    width: 1.5,
                                  ),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_rounded,
                                      color: AppColors.securityIndigo,
                                      size: 32,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      "Add Member",
                                      style: TextStyle(
                                        color: AppColors.enclavePrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          final raw = _members[index];
                          final id = raw['id'] as int;
                          final name = raw['name'] as String;
                          final count = _memberDocCounts[id] ?? 0;
                          final role = index == 0 ? 'Admin' : 'Member';

                          final member = Member(
                            id: id,
                            name: name,
                            role: role,
                            documentCount: count,
                          );

                          return FamilyMemberCard(
                            member: member,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CategoriesScreen(
                                    memberId: id,
                                    memberName: name,
                                  ),
                                ),
                              ).then((_) => loadDashboardData());
                            },
                            onLongPress: () {
                              showMemberOptionsModal(id, name);
                            },
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 28),

                  // 4. Expiry Advisory Notice Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warningAmberSubtle,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.warningAmber.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.notifications_active_outlined,
                          color: AppColors.warningAmber,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "Document validity & renewal tracker is active.",
                            style: TextStyle(
                              color: AppColors.enclavePrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RemindersScreen(),
                              ),
                            ).then((_) => loadDashboardData());
                          },
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: AppColors.warningAmber,
                          ),
                          child: const Text("View"),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 5. Recent Documents Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Recently Added Documents",
                        style: TextStyle(
                          color: AppColors.enclavePrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (_recentDocs.isNotEmpty)
                        Text(
                          "Total: $_totalDocs",
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 6. Recent Documents List
                  if (_recentDocs.isEmpty)
                    const EmptyStateView(
                      icon: Icons.folder_open_rounded,
                      title: "No Documents Uploaded Yet",
                      description:
                          "Select a family member above to add and organize documents inside categories.",
                    )
                  else
                    ..._recentDocs.map((doc) {
                      return DocumentCard(
                        document: doc,
                        onTap: () {
                          OpenFilex.open(doc.filePath);
                        },
                        onLongPress: () {
                          showDocumentMetadataSheet(doc);
                        },
                      );
                    }),
                  const SizedBox(height: 16),
                ],
              ),
            ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentNavIndex,
        onTap: _onBottomNavTapped,
      ),
    );
  }
}
