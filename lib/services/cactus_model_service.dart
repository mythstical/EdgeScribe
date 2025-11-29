import 'package:flutter/foundation.dart';
import 'package:cactus/cactus.dart';

/// Global Singleton Service for managing the Cactus LLM model
///
/// This service ensures the Qwen 2.5 0.6B model is loaded once on app startup
/// and kept resident in memory for use across all tabs/widgets.
///
/// Usage:
/// - Call `CactusModelService.instance.initialize()` in main.dart
/// - Access the model via `CactusModelService.instance.model` anywhere in the app
class CactusModelService extends ChangeNotifier {
  // Singleton pattern
  static final CactusModelService _instance = CactusModelService._internal();
  static CactusModelService get instance => _instance;

  CactusModelService._internal();

  // ═══════════════════════════════════════════════════════════════════════════
  // STATE
  // ═══════════════════════════════════════════════════════════════════════════

  CactusLM? _model;
  bool _isLoaded = false;
  String _loadingStatus = '';
  double? _loadingProgress;

  // Model configuration
  static const String _modelSlug = 'qwen3-0.6'; // Qwen 2.5 0.6B Instruct
  static const int _contextSize = 2048;

  // ═══════════════════════════════════════════════════════════════════════════
  // GETTERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Returns the loaded model instance (throws if not initialized)
  CactusLM get model {
    if (!_isLoaded || _model == null) {
      throw StateError(
        'CactusModelService not initialized. Call initialize() first.',
      );
    }
    return _model!;
  }

  /// Check if the model is loaded and ready
  bool get isLoaded => _isLoaded && _model != null && _model!.isLoaded();

  /// Current loading status message
  String get loadingStatus => _loadingStatus;

  /// Current loading progress (0.0 to 1.0, null if indeterminate)
  double? get loadingProgress => _loadingProgress;

  /// Model configuration info
  String get modelInfo => 'Model: $_modelSlug (Context: $_contextSize tokens)';

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Initialize the model (safe to call multiple times)
  ///
  /// This method:
  /// 1. Downloads the Qwen 2.5 0.6B model if needed
  /// 2. Initializes the model with 2048 token context
  /// 3. Keeps it resident in RAM for instant access
  ///
  /// Call this in main.dart on app startup for best UX.
  Future<void> initialize() async {
    // Already initialized
    if (_isLoaded && _model != null && _model!.isLoaded()) {
      print('[CactusModelService] Model already loaded');
      _loadingStatus = 'Model ready';
      notifyListeners();
      return;
    }

    try {
      print('[CactusModelService] Initializing model: $_modelSlug');

      // Create model instance if needed
      _model ??= CactusLM();

      // Update status
      _loadingStatus = 'Downloading model...';
      _loadingProgress = null;
      notifyListeners();

      // STEP 1: Download model
      print('[CactusModelService] Downloading model...');
      await _model!.downloadModel(
        model: _modelSlug,
        downloadProcessCallback: (progress, status, isError) {
          _loadingProgress = progress;
          _loadingStatus = isError ? 'Error: $status' : status;
          notifyListeners();

          if (isError) {
            print('[CactusModelService] Download error: $status');
          } else {
            print('[CactusModelService] Download: $status (${progress != null ? "${(progress * 100).toStringAsFixed(0)}%" : "..."})');
          }
        },
      );

      // STEP 2: Initialize model with parameters
      print('[CactusModelService] Initializing model...');
      _loadingStatus = 'Initializing neural engine...';
      _loadingProgress = null;
      notifyListeners();

      await _model!.initializeModel(
        params: CactusInitParams(
          model: _modelSlug,
          contextSize: _contextSize,
        ),
      );

      // Success
      _isLoaded = true;
      _loadingStatus = 'Model ready';
      _loadingProgress = 1.0;
      notifyListeners();

      print('[CactusModelService] ✓ Model loaded and resident in memory');
    } catch (e) {
      _isLoaded = false;
      _loadingStatus = 'Initialization failed: $e';
      _loadingProgress = null;
      notifyListeners();

      print('[CactusModelService] ✗ Initialization failed: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Unload the model from memory
  ///
  /// WARNING: This will break all widgets using the model.
  /// Only call this during app shutdown or when you're certain
  /// no features need the model anymore.
  void unload() {
    if (_model != null) {
      print('[CactusModelService] Unloading model...');
      _model!.unload();
      _isLoaded = false;
      _loadingStatus = 'Model unloaded';
      _loadingProgress = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unload();
    super.dispose();
  }
}
