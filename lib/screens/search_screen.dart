import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/document_item.dart';
import '../services/document_classifier_service.dart';
import '../services/ocr_search_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/document_card.dart';
import '../widgets/empty_state_view.dart';
import 'document_viewer_screen.dart';
import 'ocr_review_sheet.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final OcrSearchRepository _repository = MetadataOnlySearchRepository();

  List<DocumentItem> _results = [];
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isSearching = false;

  int? _selectedMemberId;
  int? _selectedCategoryId;
  String? _selectedDocType;
  String? _selectedFileType;
  bool _onlyWithExpiry = false;

  final List<String> _recentKeywords = [
    'Passport',
    'Aadhaar',
    'Insurance',
    'PAN',
    'Certificate',
  ];

  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadFilterOptions() async {
    final members = await DatabaseHelper.instance.getMembers();
    final categories = await DatabaseHelper.instance.getAllCategories();
    if (!mounted) return;
    setState(() {
      _members = members;
      _categories = categories;
    });
  }

  SearchFilterCriteria get _currentCriteria => SearchFilterCriteria(
    query: _controller.text,
    memberId: _selectedMemberId,
    categoryId: _selectedCategoryId,
    docType: _selectedDocType,
    fileType: _selectedFileType,
    onlyWithExpiry: _onlyWithExpiry,
  );

  Future<void> _executeSearch() async {
    final criteria = _currentCriteria;
    if (!criteria.hasActiveFilters) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final docs = await _repository.search(criteria);
    if (!mounted) return;
    setState(() {
      _results = docs;
      _isSearching = false;
    });
  }

  void _clearAll() {
    _controller.clear();
    setState(() {
      _selectedMemberId = null;
      _selectedCategoryId = null;
      _selectedDocType = null;
      _selectedFileType = null;
      _onlyWithExpiry = false;
      _results = [];
    });
  }

  void _openDocument(DocumentItem doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(
          document: doc,
          onAnalyzeDocument: (d, path) =>
              OcrReviewSheet.show(context, document: d, resolvedFilePath: path),
        ),
      ),
    ).then((_) => _executeSearch());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Vault'),
        actions: [
          if (_currentCriteria.hasActiveFilters)
            TextButton(onPressed: _clearAll, child: const Text('Reset')),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _controller,
              onChanged: (_) => _executeSearch(),
              decoration: InputDecoration(
                hintText: 'Search by filename, document type, or notes...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _controller.clear();
                          _executeSearch();
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Multi-dimension Filter Strip
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterDropdown<int?>(
                  label: _selectedMemberId == null
                      ? 'Member'
                      : (_members.firstWhere(
                              (m) => m['id'] == _selectedMemberId,
                              orElse: () => {'name': 'Member'},
                            )['name']
                            as String),
                  isActive: _selectedMemberId != null,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Members'),
                    ),
                    ..._members.map(
                      (m) => DropdownMenuItem<int?>(
                        value: m['id'] as int,
                        child: Text(m['name'] as String),
                      ),
                    ),
                  ],
                  onSelected: (v) {
                    setState(() => _selectedMemberId = v);
                    _executeSearch();
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterDropdown<int?>(
                  label: _selectedCategoryId == null
                      ? 'Category'
                      : (_categories.firstWhere(
                              (c) => c['id'] == _selectedCategoryId,
                              orElse: () => {'name': 'Category'},
                            )['name']
                            as String),
                  isActive: _selectedCategoryId != null,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Categories'),
                    ),
                    ..._categories.map(
                      (c) => DropdownMenuItem<int?>(
                        value: c['id'] as int,
                        child: Text(c['name'] as String),
                      ),
                    ),
                  ],
                  onSelected: (v) {
                    setState(() => _selectedCategoryId = v);
                    _executeSearch();
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterDropdown<String?>(
                  label: _selectedDocType ?? 'Doc Type',
                  isActive: _selectedDocType != null,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Document Types'),
                    ),
                    ...DocumentTypes.all.map(
                      (t) =>
                          DropdownMenuItem<String?>(value: t, child: Text(t)),
                    ),
                  ],
                  onSelected: (v) {
                    setState(() => _selectedDocType = v);
                    _executeSearch();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('PDF'),
                  selected: _selectedFileType == 'pdf',
                  onSelected: (sel) {
                    setState(() => _selectedFileType = sel ? 'pdf' : null);
                    _executeSearch();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Images'),
                  selected: _selectedFileType == 'image',
                  onSelected: (sel) {
                    setState(() => _selectedFileType = sel ? 'image' : null);
                    _executeSearch();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Has Expiry'),
                  selected: _onlyWithExpiry,
                  onSelected: (sel) {
                    setState(() => _onlyWithExpiry = sel);
                    _executeSearch();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : !_currentCriteria.hasActiveFilters
                ? _buildQuickSuggestions()
                : _results.isEmpty
                ? const EmptyStateView(
                    icon: Icons.search_off_rounded,
                    title: 'No Matching Documents',
                    description:
                        'Try adjusting your search keywords or active filters.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final doc = _results[index];
                      return DocumentCard(
                        document: doc,
                        onTap: () => _openDocument(doc),
                        onLongPress: () => _openDocument(doc),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown<T>({
    required String label,
    required bool isActive,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onSelected,
  }) {
    return PopupMenuButton<T>(
      onSelected: onSelected,
      itemBuilder: (_) => items
          .map((i) => PopupMenuItem<T>(value: i.value, child: i.child))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.securityIndigoSubtle
              : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? AppColors.securityIndigo
                : AppColors.surfaceBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? AppColors.securityIndigo
                    : AppColors.enclavePrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: isActive ? AppColors.securityIndigo : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSuggestions() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Quick Keywords',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.enclavePrimary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _recentKeywords.map((kw) {
            return ActionChip(
              label: Text(kw),
              onPressed: () {
                _controller.text = kw;
                _executeSearch();
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.privacy_tip_outlined,
                color: AppColors.securityIndigo,
                size: 20,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Search indexes filenames, document types, notes, and confirmed expiry metadata without storing plaintext OCR text.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
