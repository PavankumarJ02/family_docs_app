import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../db/database_helper.dart';
import '../models/document_item.dart';
import '../theme/app_colors.dart';
import '../widgets/document_card.dart';
import '../widgets/empty_state_view.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<DocumentItem> _results = [];
  bool _isSearching = false;

  final List<String> _recentKeywords = [
    'Passport',
    'Aadhaar',
    'Insurance',
    'Tax',
    'PAN',
    'Certificate',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _executeSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final rawDocs = await DatabaseHelper.instance.searchDocuments(trimmed);

    if (!mounted) return;
    setState(() {
      _results = rawDocs.map((m) => DocumentItem.fromMap(m)).toList();
      _isSearching = false;
    });
  }

  void _onKeywordTapped(String keyword) {
    _controller.text = keyword;
    _executeSearch(keyword);
  }

  void _clearSearch() {
    _controller.clear();
    _executeSearch('');
  }

  void _showDocumentDetails(DocumentItem doc) {
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
              Text(
                doc.fileName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.enclavePrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "${doc.formattedSize} • Added ${doc.formattedDate}",
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    OpenFilex.open(doc.filePath);
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text("Open Document"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      appBar: AppBar(title: const Text("Search Vault")),
      body: Column(
        children: [
          // Search Input Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _executeSearch,
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textMuted,
                ),
                hintText: "Search files by name (e.g. Passport, Aadhaar)",
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        onPressed: _clearSearch,
                      )
                    : null,
              ),
            ),
          ),

          // Content Area
          Expanded(
            child: _controller.text.isEmpty
                ? _buildRecentSearches()
                : _buildResultsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSearches() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          "Quick Search Filters",
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _recentKeywords.map((kw) {
            return ActionChip(
              label: Text(kw),
              onPressed: () => _onKeywordTapped(kw),
              backgroundColor: AppColors.cardSurface,
              side: const BorderSide(color: AppColors.surfaceBorder, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.enclavePrimary,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 36),
        const EmptyStateView(
          icon: Icons.search_rounded,
          title: "Type to Search Your Vault",
          description:
              "Search documents across all family members and categories by filename.",
        ),
      ],
    );
  }

  Widget _buildResultsList() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_results.isEmpty) {
      return EmptyStateView(
        icon: Icons.search_off_rounded,
        title: "No Matching Documents",
        description:
            "No files matched '${_controller.text}'. Check the spelling or try a broader keyword.",
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final doc = _results[index];
        return DocumentCard(
          document: doc,
          onTap: () {
            OpenFilex.open(doc.filePath);
          },
          onLongPress: () {
            _showDocumentDetails(doc);
          },
        );
      },
    );
  }
}
