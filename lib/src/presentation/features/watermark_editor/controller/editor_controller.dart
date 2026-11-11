import 'dart:async';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/base/result.dart';
import '../../../../domain/entities/document.dart';
import '../../../../domain/entities/image_format.dart';
import '../../../../domain/entities/normalized_rect.dart';
import '../../../../domain/entities/watermark_element.dart';
import '../../../../domain/repositories/document_repository.dart';
import '../../../../domain/services/watermark_geometry.dart';

/// Owns the editable draft of one document's watermark configuration.
///
/// Every mutation goes through this class, so the preview, the inspector
/// and the debounced draft save share one source of truth. It talks to the
/// domain repository interface only: the widget layer never sees storage
/// details and tests drive it with a fake.
///
/// Geometry stays in normalized page space; the widget layer converts to
/// pixels at the canvas boundary. The controller only clamps.
final class EditorController extends ChangeNotifier {
  EditorController({
    required DocumentEntity document,
    required WatermarkConfig config,
    required DocumentRepository repository,
    int initialPage = 0,
    Duration saveDebounce = const Duration(milliseconds: 600),
    String Function()? newId,
  }) : _document = document,
       _config = config,
       _repository = repository,
       _pageIndex = _pageWithin(document, initialPage),
       _saveDebounce = saveDebounce,
       _newId = newId ?? _defaultId;

  /// Where a fresh text element lands: centred, wide enough to read.
  static const NormalizedRect defaultTextRect = NormalizedRect.fromLTWH(
    0.2,
    0.45,
    0.6,
    0.1,
  );

  /// Where a fresh image element lands before its aspect ratio is known.
  static const NormalizedRect defaultImageRect = NormalizedRect.fromLTWH(
    0.35,
    0.35,
    0.3,
    0.3,
  );

  /// The width a fresh image element occupies on the page.
  static const double defaultImageWidth = 0.3;

  final DocumentEntity _document;
  final DocumentRepository _repository;
  final Duration _saveDebounce;
  final String Function() _newId;

  WatermarkConfig _config;
  int _pageIndex;
  String? _selectedId;
  Timer? _saveTimer;
  bool _dirty = false;
  bool _saving = false;
  bool _disposed = false;
  Object? _saveFailure;

  DocumentEntity get document => _document;

  WatermarkConfig get config => _config;

  /// The element the inspector edits, if any. A locked or hidden element
  /// can stay selected; gestures just refuse to transform it.
  String? get selectedId => _selectedId;

  WatermarkElement? get selectedElement {
    final id = _selectedId;
    if (id == null) return null;
    for (final element in _config.elements) {
      if (element.id == id) return element;
    }

    return null;
  }

  /// The page the preview shows and new elements are placed on.
  int get pageIndex => _pageIndex;

  int get pageCount => _document.pageCount;

  /// Elements painted on the current page, in paint order.
  List<WatermarkElement> get elementsForCurrentPage =>
      _config.elementsForPage(_pageIndex);

  /// Every distinct image asset the draft references, for preset saves and
  /// the preview's image cache.
  List<String> get imageAssetIds {
    final ids = <String>[];
    for (final element in _config.elements) {
      if (element is ImageWatermark &&
          element.assetId.isNotEmpty &&
          !ids.contains(element.assetId)) {
        ids.add(element.assetId);
      }
    }

    return ids;
  }

  /// Whether a change is waiting for the debounced save.
  bool get hasUnsavedDraft => _dirty;

  bool get isSaving => _saving;

  /// The last persistence failure, if any. The page surfaces it once; the
  /// draft stays dirty so the next edit retries.
  Object? get saveFailure => _saveFailure;

  // --- Selection and pages -------------------------------------------

  void select(String? id) {
    if (_selectedId == id) return;
    _selectedId = id;
    _notify();
  }

  void setPage(int index) {
    final next = _pageWithin(_document, index);
    if (next == _pageIndex) return;
    _pageIndex = next;
    _notify();
  }

  /// Sets which pages paint [id]. Every page is stored explicitly once the
  /// assignment stops being "all pages", so a page left out really hides
  /// the element.
  void setElementPages(String id, Set<int> pages) {
    if (_indexOf(id) < 0) return;

    final all = <int>{for (var i = 0; i < pageCount; i++) i};
    final wanted = pages.intersection(all);
    final current = _config.pageAssignments;
    final next = <int, List<String>>{};

    for (final page in all) {
      final existing = current[page];
      final base = existing == null
          ? <String>{for (final element in _config.elements) element.id}
          : existing.toSet();
      base.remove(id);
      if (wanted.contains(page)) base.add(id);
      next[page] = base.toList();
    }

    _commit(_config.copyWith(pageAssignments: next));
  }

  /// Whether [id] paints on every page.
  bool paintsEveryPage(String id) {
    final assignments = _config.pageAssignments;
    if (assignments.isEmpty) return true;

    for (var page = 0; page < pageCount; page++) {
      if (!(assignments[page] ?? const <String>[]).contains(id)) return false;
    }

    return true;
  }

  // --- Adding and removing elements ----------------------------------

  /// Appends a text element and selects it.
  TextWatermark? addText({String content = ''}) {
    if (pageCount == 0) return null;

    final element = TextWatermark(
      id: _newId(),
      rect: defaultTextRect,
      content: content,
    );
    _insert(element, at: _config.elements.length);

    return element;
  }

  /// Appends an image element for an asset already stored in the vault and
  /// selects it. [naturalSize] keeps the placed aspect ratio if known.
  ImageWatermark? addImage(String assetId, {Size? naturalSize}) {
    if (pageCount == 0 || assetId.isEmpty) return null;

    final element = ImageWatermark(
      id: _newId(),
      rect: _defaultImageRect(naturalSize),
      assetId: assetId,
    );
    _insert(element, at: _config.elements.length);

    return element;
  }

  /// Inserts a copy above the original, nudged so both stay visible.
  void duplicate(String id) {
    final index = _indexOf(id);
    if (index < 0) return;

    final source = _config.elements[index];
    final rect = WatermarkGeometry.translate(
      source.rect,
      const NormalizedOffset(0.02, 0.02),
    );
    final copy = source.copyWith(rect: rect);

    // copyWith keeps the id; rebuild the subtype with the new identity.
    final cloned = _withId(copy, _newId());
    _insert(cloned, at: index + 1);
  }

  void remove(String id) {
    if (_indexOf(id) < 0) return;

    final elements = <WatermarkElement>[
      for (final element in _config.elements)
        if (element.id != id) element,
    ];

    var assignments = _config.pageAssignments;
    if (assignments.isNotEmpty) {
      assignments = {
        for (final entry in assignments.entries)
          entry.key: [
            for (final kept in entry.value)
              if (kept != id) kept,
          ],
      };
    }

    if (_selectedId == id) _selectedId = null;
    _commit(
      _config.copyWith(elements: elements, pageAssignments: assignments),
    );
  }

  // --- Layer order ----------------------------------------------------

  void bringToFront(String id) => _reorder(
    WatermarkGeometry.bringToFront(_config.elements, _requiredIndex(id)),
    id,
  );

  void sendToBack(String id) => _reorder(
    WatermarkGeometry.sendToBack(_config.elements, _requiredIndex(id)),
    id,
  );

  void moveForward(String id) => _reorder(
    WatermarkGeometry.moveForward(_config.elements, _requiredIndex(id)),
    id,
  );

  void moveBackward(String id) => _reorder(
    WatermarkGeometry.moveBackward(_config.elements, _requiredIndex(id)),
    id,
  );

  // --- Shared properties ---------------------------------------------

  /// Locked elements can still be selected and toggled; gestures skip them.
  void setLocked(String id, bool locked) {
    final index = _indexOf(id);
    if (index < 0) return;
    _replaceAt(index, _config.elements[index].copyWith(locked: locked));
  }

  void toggleLock(String id) {
    final element = _element(id);
    if (element == null) return;
    setLocked(id, !element.locked);
  }

  void setVisible(String id, bool visible) {
    final index = _indexOf(id);
    if (index < 0) return;
    _replaceAt(index, _config.elements[index].copyWith(visible: visible));
  }

  void toggleVisibility(String id) {
    final element = _element(id);
    if (element == null) return;
    setVisible(id, !element.visible);
  }

  void setOpacity(String id, double opacity) {
    _transform(id, (element) {
      return element.copyWith(opacity: opacity.clamp(0.0, 1.0).toDouble());
    });
  }

  void setRotation(String id, double degrees) {
    _transform(id, (element) {
      return element.copyWith(rotationDeg: _normalizeDegrees(degrees));
    });
  }

  /// Moves [id] by a normalized delta, clamped to the page.
  void moveBy(String id, NormalizedOffset delta) {
    _transform(id, (element) {
      return element.copyWith(
        rect: WatermarkGeometry.translate(element.rect, delta),
      );
    });
  }

  /// Writes a rect computed by the gesture layer.
  void setRect(String id, NormalizedRect rect) {
    _transform(id, (element) {
      return element.copyWith(rect: rect.clampToPage());
    });
  }

  // --- Text appearance -----------------------------------------------

  void updateText(
    String id, {
    String? content,
    FontToken? font,
    double? sizeLogical,
    int? colorArgb,
    bool? bold,
    bool? italic,
    TextAlignType? align,
    double? rotationDeg,
    double? opacity,
    OutlineSpec? outline,
    bool clearOutline = false,
    BackgroundSpec? background,
    bool clearBackground = false,
  }) {
    _transform(id, (element) {
      if (element is! TextWatermark) return element;

      return element.copyWith(
        content: content,
        font: font,
        sizeLogical: sizeLogical,
        colorArgb: colorArgb,
        bold: bold,
        italic: italic,
        align: align,
        rotationDeg:
            rotationDeg == null ? null : _normalizeDegrees(rotationDeg),
        opacity: opacity,
        outline: outline,
        clearOutline: clearOutline,
        background: background,
        clearBackground: clearBackground,
      );
    });
  }

  // --- Image appearance ----------------------------------------------

  void updateImage(
    String id, {
    double? opacity,
    double? rotationDeg,
    bool? lockAspect,
    CropRect? crop,
    bool clearCrop = false,
  }) {
    _transform(id, (element) {
      if (element is! ImageWatermark) return element;

      return element.copyWith(
        opacity: opacity,
        rotationDeg:
            rotationDeg == null ? null : _normalizeDegrees(rotationDeg),
        lockAspect: lockAspect,
        crop: crop,
        clearCrop: clearCrop,
      );
    });
  }

  /// Applies a crop window to an image element. The source asset is never
  /// touched: only the visible window changes.
  void applyCrop(String id, CropRect crop) {
    updateImage(id, crop: crop.clamped());
  }

  /// Restores the full source image.
  void resetCrop(String id) => updateImage(id, clearCrop: true);

  // --- Presets --------------------------------------------------------

  /// Replaces the draft with a preset's elements, re-pointed at this
  /// document by `PresetRepository.apply`.
  void applyElements(List<WatermarkElement> elements) {
    _selectedId = null;
    _commit(
      WatermarkConfig(elements: List<WatermarkElement>.of(elements)),
      force: true,
    );
  }

  // --- Draft persistence ---------------------------------------------

  /// Writes the current draft immediately. Call before leaving the page.
  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (!_dirty) return;

    await _persist();
  }

  @override
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    _saveTimer = null;

    // Leaving the page must not drop the last edit. The repository handle
    // stays valid after the provider is disposed.
    if (_dirty) unawaited(_persist());

    super.dispose();
  }

  Future<void> _persist() async {
    if (!_dirty) return;

    final snapshot = _config;
    _dirty = false;
    _saving = true;
    _notify();

    try {
      final result = await _repository.saveWatermarkConfig(
        _document.id,
        snapshot,
      );
      if (result is Error) {
        _saveFailure = result.error;
        _dirty = true;
      } else {
        _saveFailure = null;
      }
    } catch (error) {
      _saveFailure = error;
      _dirty = true;
    }

    _saving = false;
    _notify();
  }

  // --- Internals ------------------------------------------------------

  int _indexOf(String id) =>
      _config.elements.indexWhere((element) => element.id == id);

  int _requiredIndex(String id) {
    final index = _indexOf(id);

    return index < 0 ? 0 : index;
  }

  WatermarkElement? _element(String id) {
    final index = _indexOf(id);

    return index < 0 ? null : _config.elements[index];
  }

  void _insert(WatermarkElement element, {required int at}) {
    final elements = List<WatermarkElement>.of(_config.elements)
      ..insert(at, element);

    var assignments = _config.pageAssignments;
    if (assignments.isNotEmpty) {
      // An explicit map means at least one page lists its elements, so a
      // new element has to be added to every page to stay "everywhere".
      assignments = {
        for (final entry in assignments.entries)
          entry.key: [...entry.value, element.id],
      };
    }

    _selectedId = element.id;
    _commit(
      _config.copyWith(elements: elements, pageAssignments: assignments),
    );
  }

  void _reorder(List<WatermarkElement> elements, String id) {
    if (_indexOf(id) < 0) return;

    _commit(_config.copyWith(elements: elements));
    if (_selectedId != id) {
      _selectedId = id;
      _notify();
    }
  }

  /// Writes [element] at [index] without the lock guard: locking and
  /// visibility must stay changeable on a locked element.
  void _replaceAt(int index, WatermarkElement element) {
    if (_config.elements[index] == element) return;

    final elements = List<WatermarkElement>.of(_config.elements);
    elements[index] = element;
    _commit(_config.copyWith(elements: elements));
  }

  /// Applies [transform] to the element with [id] unless it is locked.
  ///
  /// Locking is enforced here as well as in the gesture layer, so a stale
  /// panel or a keyboard nudge cannot move a locked element either.
  void _transform(
    String id,
    WatermarkElement Function(WatermarkElement element) transform,
  ) {
    final index = _indexOf(id);
    if (index < 0) return;

    final current = _config.elements[index];
    if (current.locked) return;

    final next = transform(current);
    if (next == current) return;

    final elements = List<WatermarkElement>.of(_config.elements);
    elements[index] = next;
    _commit(_config.copyWith(elements: elements));
  }

  void _commit(WatermarkConfig next, {bool force = false}) {
    if (!force && next == _config) return;

    _config = next;
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDebounce, () => unawaited(_persist()));
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  NormalizedRect _defaultImageRect(Size? naturalSize) {
    final page = _document.pageAt(_pageIndex);
    if (naturalSize == null ||
        naturalSize.height <= 0 ||
        naturalSize.width <= 0 ||
        page == null ||
        page.heightPt <= 0 ||
        page.widthPt <= 0) {
      return defaultImageRect;
    }

    final imageAspect = naturalSize.width / naturalSize.height;
    final pageAspect = page.widthPt / page.heightPt;
    final width = defaultImageWidth;
    final height = (width * pageAspect / imageAspect)
        .clamp(0.02, 1.0)
        .toDouble();

    return NormalizedRect.fromLTWH(
      ((1 - width) / 2).clamp(0.0, 1.0).toDouble(),
      ((1 - height) / 2).clamp(0.0, 1.0).toDouble(),
      width,
      height,
    );
  }

  WatermarkElement _withId(WatermarkElement element, String id) {
    if (element is TextWatermark) {
      return TextWatermark(
        id: id,
        rect: element.rect,
        rotationDeg: element.rotationDeg,
        opacity: element.opacity,
        locked: element.locked,
        visible: element.visible,
        content: element.content,
        font: element.font,
        sizeLogical: element.sizeLogical,
        colorArgb: element.colorArgb,
        bold: element.bold,
        italic: element.italic,
        align: element.align,
        outline: element.outline,
        background: element.background,
      );
    }

    final image = element as ImageWatermark;

    return ImageWatermark(
      id: id,
      rect: image.rect,
      rotationDeg: image.rotationDeg,
      opacity: image.opacity,
      locked: image.locked,
      visible: image.visible,
      assetId: image.assetId,
      lockAspect: image.lockAspect,
      crop: image.crop,
    );
  }

  static int _pageWithin(DocumentEntity document, int index) {
    if (document.pageCount <= 0) return 0;

    return index.clamp(0, document.pageCount - 1).toInt();
  }

  static double _normalizeDegrees(double degrees) {
    final result = degrees % 360;

    return result < 0 ? result + 360 : result;
  }

  static const Uuid _uuid = Uuid();

  static String _defaultId() => _uuid.v4();
}
