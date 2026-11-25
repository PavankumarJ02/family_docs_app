import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/document_item.dart';
import '../services/document_storage_service.dart';
import '../services/scanner_service.dart';
import '../theme/app_colors.dart';

class ScannerScreen extends StatefulWidget {
  final int memberId;
  final int categoryId;
  final String categoryName;
  final ScannerService? scannerService;

  const ScannerScreen({
    super.key,
    required this.memberId,
    required this.categoryId,
    required this.categoryName,
    this.scannerService,
  });

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  late final ScannerService _scannerService;
  final List<ScannedPageData> _pages = [];
  int _selectedIndex = 0;

  CameraController? _cameraController;
  bool _isCameraInitializing = true;
  String? _cameraError;
  bool _isCameraMode = true;
  bool _isSaving = false;
  bool _isProcessingPage = false;
  bool _showCornerHandles = false;

  late final TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _scannerService = widget.scannerService ?? ScannerService();
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    _titleController = TextEditingController(text: 'Scan_$stamp.pdf');
    _initCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    setState(() {
      _isCameraInitializing = true;
      _cameraError = null;
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isCameraInitializing = false;
          _cameraError =
              'No camera detected on this device. Use Gallery or Auto-Scan.';
        });
        return;
      }
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _isCameraInitializing = false;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _isCameraInitializing = false;
        _cameraError = e.code == 'CameraAccessDenied'
            ? 'Camera permission denied. Grant camera access in Settings or import from Gallery.'
            : 'Camera error: ${e.description ?? e.code}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCameraInitializing = false;
        _cameraError = 'Camera unavailable: $e';
      });
    }
  }

  Future<void> _captureFromCamera() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      final xFile = await controller.takePicture();
      final bytes = await File(xFile.path).readAsBytes();
      if (!mounted) return;
      setState(() {
        _pages.add(
          ScannedPageData(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            originalBytes: bytes,
            processedBytes: bytes,
          ),
        );
        _selectedIndex = _pages.length - 1;
        _isCameraMode = false;
        _showCornerHandles = false;
      });
    } catch (e) {
      _showSnack('Capture failed: $e');
    }
  }

  Future<void> _runNativeAutoScan() async {
    try {
      final scanned = await _scannerService.scanAutoPages();
      if (scanned == null || scanned.isEmpty) return;
      if (!mounted) return;
      setState(() {
        _pages.addAll(scanned);
        _selectedIndex = _pages.length - 1;
        _isCameraMode = false;
        _showCornerHandles = false;
      });
    } on ScannerPermissionException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Auto-scan unavailable: $e');
    }
  }

  Future<void> _pickImageForScan() async {
    const group = XTypeGroup(
      label: 'images',
      extensions: ['jpg', 'jpeg', 'png', 'webp'],
    );
    final picked = await openFile(acceptedTypeGroups: [group]);
    if (picked == null) return;
    final bytes = await File(picked.path).readAsBytes();
    if (!mounted) return;
    setState(() {
      _pages.add(
        ScannedPageData(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          originalBytes: bytes,
          processedBytes: bytes,
        ),
      );
      _selectedIndex = _pages.length - 1;
      _isCameraMode = false;
      _showCornerHandles = false;
    });
  }

  void _applyCurrentPageEdits() {
    if (_pages.isEmpty) return;
    final page = _pages[_selectedIndex];
    setState(() => _isProcessingPage = true);
    try {
      final updated = _scannerService.processPageImage(
        page.originalBytes,
        rotationDegrees: page.rotationDegrees,
        filter: page.filter,
        corners: page.corners,
      );
      setState(() {
        page.processedBytes = updated;
        _isProcessingPage = false;
        _showCornerHandles = false;
      });
    } catch (e) {
      setState(() => _isProcessingPage = false);
      _showSnack('Image processing failed: $e');
    }
  }

  void _rotateSelected() {
    if (_pages.isEmpty) return;
    final page = _pages[_selectedIndex];
    page.rotationDegrees = (page.rotationDegrees + 90) % 360;
    _applyCurrentPageEdits();
  }

  void _setFilter(ScanFilter filter) {
    if (_pages.isEmpty) return;
    _pages[_selectedIndex].filter = filter;
    _applyCurrentPageEdits();
  }

  void _deleteSelectedPage() {
    if (_pages.isEmpty) return;
    setState(() {
      _pages.removeAt(_selectedIndex);
      if (_pages.isEmpty) {
        _selectedIndex = 0;
        _isCameraMode = true;
      } else if (_selectedIndex >= _pages.length) {
        _selectedIndex = _pages.length - 1;
      }
    });
  }

  Future<void> _saveAsPdf() async {
    if (_pages.isEmpty || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      var title = DocumentStorageService.sanitizeFileName(
        _titleController.text.trim(),
      );
      if (title.isEmpty) title = 'Scanned_Document.pdf';
      if (!title.toLowerCase().endsWith('.pdf')) title = '$title.pdf';

      final pdfBytes = await _scannerService.generateMultiPagePdf(
        _pages.map((p) => p.processedBytes).toList(),
        title: title,
      );

      final saved = await DocumentStorageService().saveDocumentBytes(
        bytes: pdfBytes,
        memberId: widget.memberId,
        categoryId: widget.categoryId,
        originalName: title,
      );

      final id = await DatabaseHelper.instance.addDocument({
        'uuid': saved.uuid,
        'member_id': widget.memberId,
        'category_id': widget.categoryId,
        'file_name': title,
        'file_path': saved.relativePath,
        'size': saved.sizeBytes,
        'created_at': DateTime.now().toIso8601String(),
        'sync_status': 'local_only',
        'ocr_status': 'pending',
      });

      final createdRow = await DatabaseHelper.instance.getDocumentById(id);
      if (!mounted) return;
      Navigator.pop(
        context,
        createdRow != null ? DocumentItem.fromMap(createdRow) : null,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnack('Failed to save PDF: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isCameraMode
          ? const Color(0xFF0F172A)
          : AppColors.surfaceBackground,
      appBar: AppBar(
        backgroundColor: _isCameraMode
            ? const Color(0xFF0F172A)
            : AppColors.surfaceBackground,
        foregroundColor: _isCameraMode
            ? Colors.white
            : AppColors.enclavePrimary,
        title: Text(
          _isCameraMode
              ? 'Scan Document'
              : 'Review (${_pages.length} ${_pages.length == 1 ? 'Page' : 'Pages'})',
          style: TextStyle(
            color: _isCameraMode ? Colors.white : AppColors.enclavePrimary,
          ),
        ),
        actions: [
          if (!_isCameraMode && _pages.isNotEmpty)
            TextButton.icon(
              onPressed: _isSaving ? null : _saveAsPdf,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: const Text('Save PDF'),
            ),
        ],
      ),
      body: _isCameraMode ? _buildCameraView() : _buildReviewStudio(),
    );
  }

  Widget _buildCameraView() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_isCameraInitializing)
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  else if (_cameraError != null)
                    Container(
                      color: const Color(0xFF1E293B),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.no_photography_rounded,
                            color: Colors.white70,
                            size: 48,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _cameraError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _initCamera,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white38),
                            ),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry Camera'),
                          ),
                        ],
                      ),
                    )
                  else if (_cameraController != null)
                    CameraPreview(_cameraController!),

                  // Alignment guide frame
                  IgnorePointer(
                    child: Container(
                      margin: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.trustEmerald.withValues(alpha: 0.75),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          color: const Color(0xFF0F172A),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _camAction(
                      icon: Icons.photo_library_outlined,
                      label: 'Gallery',
                      onTap: _pickImageForScan,
                    ),
                    GestureDetector(
                      onTap: _captureFromCamera,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: Center(
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _camAction(
                      icon: Icons.auto_fix_high_rounded,
                      label: 'Auto Edge',
                      onTap: _runNativeAutoScan,
                    ),
                  ],
                ),
                if (_pages.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() => _isCameraMode = false),
                    child: Text(
                      'Back to ${_pages.length} scanned page(s)',
                      style: const TextStyle(color: AppColors.trustEmerald),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _camAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewStudio() {
    if (_pages.isEmpty) {
      return const Center(child: Text('No pages scanned yet.'));
    }
    final activePage = _pages[_selectedIndex];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Document Filename (PDF)',
              prefixIcon: Icon(Icons.description_outlined),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _showCornerHandles
                        ? _FourCornerCropOverlay(
                            imageBytes: activePage.originalBytes,
                            quad: activePage.corners,
                            onChanged: (q) =>
                                setState(() => activePage.corners = q),
                          )
                        : Image.memory(
                            activePage.processedBytes,
                            fit: BoxFit.contain,
                          ),
                  ),
                  if (_isProcessingPage)
                    Container(
                      color: Colors.black45,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        // Enhancement & Edit Toolbar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  avatar: Icon(
                    _showCornerHandles ? Icons.check_rounded : Icons.crop,
                    size: 16,
                  ),
                  label: Text(
                    _showCornerHandles ? 'Apply Crop' : '4-Corner Crop',
                  ),
                  onPressed: () {
                    if (_showCornerHandles) {
                      _applyCurrentPageEdits();
                    } else {
                      setState(() => _showCornerHandles = true);
                    }
                  },
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.rotate_right_rounded, size: 16),
                  label: const Text('Rotate'),
                  onPressed: _rotateSelected,
                ),
                const SizedBox(width: 8),
                ...ScanFilter.values.map((f) {
                  final selected = activePage.filter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.label),
                      selected: selected,
                      onSelected: (_) => _setFilter(f),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        // Multi-page reorder & delete tray
        Container(
          height: 92,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: AppColors.cardSurface,
            border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: () => setState(() => _isCameraMode = true),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 58,
                  height: 74,
                  decoration: BoxDecoration(
                    color: AppColors.securityIndigoSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.securityIndigo.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_rounded,
                        size: 20,
                        color: AppColors.securityIndigo,
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Add',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.securityIndigo,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pages.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = _pages.removeAt(oldIndex);
                      _pages.insert(newIndex, item);
                      _selectedIndex = newIndex;
                    });
                  },
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    final isSelected = index == _selectedIndex;
                    return GestureDetector(
                      key: ValueKey(page.id),
                      onTap: () => setState(() {
                        _selectedIndex = index;
                        _showCornerHandles = false;
                      }),
                      child: Container(
                        width: 56,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.securityIndigo
                                : AppColors.surfaceBorder,
                            width: isSelected ? 2.5 : 1,
                          ),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.memory(
                                page.processedBytes,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              bottom: 2,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              IconButton(
                onPressed: _deleteSelectedPage,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.alertRose,
                ),
                tooltip: 'Delete Selected Page',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FourCornerCropOverlay extends StatelessWidget {
  final Uint8List imageBytes;
  final NormalizedQuad quad;
  final ValueChanged<NormalizedQuad> onChanged;

  const _FourCornerCropOverlay({
    required this.imageBytes,
    required this.quad,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(imageBytes, fit: BoxFit.fill),
            CustomPaint(painter: _QuadPainter(quad)),
            _handle(
              w,
              h,
              quad.topLeft,
              (p) => onChanged(quad.copyWith(topLeft: p)),
            ),
            _handle(
              w,
              h,
              quad.topRight,
              (p) => onChanged(quad.copyWith(topRight: p)),
            ),
            _handle(
              w,
              h,
              quad.bottomLeft,
              (p) => onChanged(quad.copyWith(bottomLeft: p)),
            ),
            _handle(
              w,
              h,
              quad.bottomRight,
              (p) => onChanged(quad.copyWith(bottomRight: p)),
            ),
          ],
        );
      },
    );
  }

  Widget _handle(
    double w,
    double h,
    math.Point<double> pt,
    ValueChanged<math.Point<double>> onDrag,
  ) {
    return Positioned(
      left: (pt.x * w) - 16,
      top: (pt.y * h) - 16,
      child: GestureDetector(
        onPanUpdate: (details) {
          final nx = ((pt.x * w + details.delta.dx) / w).clamp(0.0, 1.0);
          final ny = ((pt.y * h + details.delta.dy) / h).clamp(0.0, 1.0);
          onDrag(math.Point(nx, ny));
        },
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.securityIndigo.withValues(alpha: 0.85),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
          ),
        ),
      ),
    );
  }
}

class _QuadPainter extends CustomPainter {
  final NormalizedQuad quad;
  const _QuadPainter(this.quad);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.trustEmerald
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(quad.topLeft.x * size.width, quad.topLeft.y * size.height)
      ..lineTo(quad.topRight.x * size.width, quad.topRight.y * size.height)
      ..lineTo(
        quad.bottomRight.x * size.width,
        quad.bottomRight.y * size.height,
      )
      ..lineTo(quad.bottomLeft.x * size.width, quad.bottomLeft.y * size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _QuadPainter oldDelegate) => true;
}
