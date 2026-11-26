import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/syllabus_cache_service.dart';
import '../models/syllabus_model.dart';

// ============ Syllabus Repository ============

class SyllabusRepository {
  final ApiClient _apiClient;
  final SyllabusCacheService _cacheService;

  SyllabusRepository({ApiClient? apiClient, SyllabusCacheService? cacheService})
    : _apiClient = apiClient ?? ApiClient(),
      _cacheService = cacheService ?? SyllabusCacheService();

  /// Get all class levels
  Future<List<ClassLevel>> getLevels() async {
    try {
      final response = await _apiClient.get<List<dynamic>>(
        AppConstants.syllabusLevelsEndpoint,
      );
      return response
          .map((json) => ClassLevel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching levels: $e');
      rethrow;
    }
  }

  /// Get syllabus items for a specific level with caching
  Future<SyllabusLevel> getSyllabusByLevel(
    int levelId, {
    bool forceRefresh = false,
  }) async {
    try {
      // Try cache first unless force refresh
      if (!forceRefresh) {
        final cached = await _cacheService.getCached(levelId);
        if (cached != null) {
          debugPrint('Syllabus loaded from cache for level $levelId');
          return SyllabusLevel.fromJson(cached);
        }
      }

      // Fetch from API
      final response = await _apiClient.get<Map<String, dynamic>>(
        AppConstants.syllabusLevelEndpoint(levelId),
      );

      // Cache the response
      await _cacheService.save(levelId, response);
      debugPrint('Syllabus cached for level $levelId');

      return SyllabusLevel.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching syllabus for level $levelId: $e');

      // On error, try to return cached data even if expired
      final cached = await _cacheService.getCached(
        levelId,
        ttlMillis: 7 * 24 * 60 * 60 * 1000, // Allow 7 days old cache on error
      );
      if (cached != null) {
        debugPrint('Returning stale cache for level $levelId due to error');
        return SyllabusLevel.fromJson(cached);
      }

      rethrow;
    }
  }

  /// Clear syllabus cache for a level
  Future<void> clearCache(int levelId) async {
    await _cacheService.clear(levelId);
  }

  /// Convert Google Drive share URL to direct download URL
  String? _getGoogleDriveDirectUrl(String url) {
    // Handle various Google Drive URL formats:
    // 1. https://drive.google.com/file/d/FILE_ID/view?usp=sharing
    // 2. https://drive.google.com/open?id=FILE_ID
    // 3. https://drive.google.com/uc?id=FILE_ID&export=download

    String? fileId;

    // Pattern 1: /file/d/FILE_ID/
    final filePattern = RegExp(r'/file/d/([a-zA-Z0-9_-]+)');
    final fileMatch = filePattern.firstMatch(url);
    if (fileMatch != null) {
      fileId = fileMatch.group(1);
    }

    // Pattern 2: ?id=FILE_ID or &id=FILE_ID
    if (fileId == null) {
      final idPattern = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)');
      final idMatch = idPattern.firstMatch(url);
      if (idMatch != null) {
        fileId = idMatch.group(1);
      }
    }

    if (fileId != null) {
      // Use Google Drive direct download URL
      return 'https://drive.google.com/uc?export=download&id=$fileId';
    }

    return null;
  }

  /// Check if URL is a Google Drive link
  bool _isGoogleDriveUrl(String url) {
    return url.contains('drive.google.com');
  }

  /// Open PDF directly from URL (for Google Drive links)
  Future<bool> openPdfFromUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error opening PDF URL: $e');
      return false;
    }
  }

  /// Download a PDF file and save to local storage
  Future<String> downloadPdf(SyllabusItem item) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final sanitizedName = item.subjectName
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(' ', '_');
      final fileName = 'syllabus_${item.id}_$sanitizedName.pdf';
      final filePath = '${dir.path}/syllabus/$fileName';

      // Create directory if it doesn't exist
      final syllabusDir = Directory('${dir.path}/syllabus');
      if (!await syllabusDir.exists()) {
        await syllabusDir.create(recursive: true);
      }

      // Check if file already exists and is valid
      final file = File(filePath);
      if (await file.exists()) {
        final fileSize = await file.length();
        // If file is too small, it might be an error page, delete it
        if (fileSize > 1024) {
          // > 1KB
          return filePath;
        } else {
          await file.delete();
        }
      }

      // Get the download URL
      String downloadUrl = item.url;
      if (_isGoogleDriveUrl(downloadUrl)) {
        final directUrl = _getGoogleDriveDirectUrl(downloadUrl);
        if (directUrl != null) {
          downloadUrl = directUrl;
        }
      }

      // Download the file with proper headers
      final dio = Dio();
      dio.options.followRedirects = true;
      dio.options.maxRedirects = 5;

      await dio.download(
        downloadUrl,
        filePath,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
          followRedirects: true,
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            debugPrint(
              'Download progress: ${(received / total * 100).toStringAsFixed(0)}%',
            );
          }
        },
      );

      // Verify the downloaded file is actually a PDF
      final downloadedFile = File(filePath);
      if (await downloadedFile.exists()) {
        final bytes = await downloadedFile.openRead(0, 4).first;
        // PDF files start with %PDF
        if (bytes.length >= 4 &&
            bytes[0] == 0x25 && // %
            bytes[1] == 0x50 && // P
            bytes[2] == 0x44 && // D
            bytes[3] == 0x46) {
          // F
          return filePath;
        } else {
          // Not a valid PDF, delete it
          await downloadedFile.delete();
          throw Exception(
            'Downloaded file is not a valid PDF. The file may require authentication.',
          );
        }
      }

      return filePath;
    } catch (e) {
      debugPrint('Error downloading PDF: $e');
      rethrow;
    }
  }

  /// Check if a PDF is already downloaded
  Future<String?> getLocalPdfPath(SyllabusItem item) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final sanitizedName = item.subjectName
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(' ', '_');
      final fileName = 'syllabus_${item.id}_$sanitizedName.pdf';
      final filePath = '${dir.path}/syllabus/$fileName';

      final file = File(filePath);
      if (await file.exists()) {
        // Verify it's a valid file (not an error page)
        final fileSize = await file.length();
        if (fileSize > 1024) {
          // > 1KB
          return filePath;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error checking local PDF: $e');
      return null;
    }
  }

  /// Delete a downloaded PDF
  Future<void> deleteLocalPdf(SyllabusItem item) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final sanitizedName = item.subjectName
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(' ', '_');
      final fileName = 'syllabus_${item.id}_$sanitizedName.pdf';
      final filePath = '${dir.path}/syllabus/$fileName';

      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting local PDF: $e');
    }
  }
}

final syllabusRepositoryProvider = Provider<SyllabusRepository>((ref) {
  return SyllabusRepository();
});

// ============ Syllabus State ============

class SyllabusState {
  final bool isLoading;
  final SyllabusLevel? syllabus;
  final String? error;

  /// The exception behind [error], so the screen can say what went wrong.
  final Object? loadFailure;
  final Map<int, SyllabusDownloadState> downloadStates;

  const SyllabusState({
    this.isLoading = false,
    this.syllabus,
    this.error,
    this.loadFailure,
    this.downloadStates = const {},
  });

  SyllabusState copyWith({
    bool? isLoading,
    SyllabusLevel? syllabus,
    String? error,
    Object? loadFailure,
    Map<int, SyllabusDownloadState>? downloadStates,
  }) {
    return SyllabusState(
      isLoading: isLoading ?? this.isLoading,
      syllabus: syllabus ?? this.syllabus,
      error: error,
      loadFailure: loadFailure,
      downloadStates: downloadStates ?? this.downloadStates,
    );
  }

  bool get hasItems => syllabus != null && syllabus!.items.isNotEmpty;

  /// Whether there is nothing to list — including the case where no syllabus
  /// has been loaded at all.
  ///
  /// The null case belongs here. This read `syllabus != null && …`, which is
  /// false when there is no syllabus, so a state of no syllabus / no error /
  /// not loading fell past every guard in `_SyllabusScreenState._buildBody`
  /// and reached `state.syllabus!.items.length`. That crashed 13 users on
  /// 1.0.0 (7) and took crash-free users to 66.67%; the "No Syllabus
  /// Available" branch it should have reached was already written.
  ///
  /// Keep this the exact complement of [hasItems]. The screen has no third
  /// branch, so any state both getters call false is a null dereference.
  bool get isEmpty => syllabus == null || syllabus!.items.isEmpty;
}

// ============ Syllabus Notifier ============

class SyllabusNotifier extends StateNotifier<SyllabusState> {
  final SyllabusRepository _repository;

  SyllabusNotifier(this._repository) : super(const SyllabusState());

  /// Load syllabus with caching support
  /// Set [forceRefresh] to true for pull-to-refresh
  Future<void> loadSyllabus(int levelId, {bool forceRefresh = false}) async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final syllabus = await _repository.getSyllabusByLevel(
        levelId,
        forceRefresh: forceRefresh,
      );

      // Check which PDFs are already downloaded
      final downloadStates = <int, SyllabusDownloadState>{};
      for (final item in syllabus.items) {
        if (item.linkType == SyllabusLinkType.pdf) {
          final localPath = await _repository.getLocalPdfPath(item);
          downloadStates[item.id] = SyllabusDownloadState(
            syllabusId: item.id,
            status: localPath != null
                ? SyllabusDownloadStatus.downloaded
                : SyllabusDownloadStatus.notDownloaded,
            localPath: localPath,
          );
        }
      }

      state = state.copyWith(
        isLoading: false,
        syllabus: syllabus,
        downloadStates: downloadStates,
      );
    } catch (e) {
      debugPrint('Error loading syllabus: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        loadFailure: e,
      );
    }
  }

  /// Refresh syllabus (force fetch from API)
  Future<void> refreshSyllabus(int levelId) async {
    await loadSyllabus(levelId, forceRefresh: true);
  }

  Future<String?> downloadPdf(SyllabusItem item) async {
    if (item.linkType != SyllabusLinkType.pdf) return null;

    // Update state to downloading
    final updatedStates = Map<int, SyllabusDownloadState>.from(
      state.downloadStates,
    );
    updatedStates[item.id] = SyllabusDownloadState(
      syllabusId: item.id,
      status: SyllabusDownloadStatus.downloading,
    );
    state = state.copyWith(downloadStates: updatedStates);

    try {
      final path = await _repository.downloadPdf(item);

      updatedStates[item.id] = SyllabusDownloadState(
        syllabusId: item.id,
        status: SyllabusDownloadStatus.downloaded,
        localPath: path,
      );
      state = state.copyWith(downloadStates: Map.from(updatedStates));

      return path;
    } catch (e) {
      updatedStates[item.id] = SyllabusDownloadState(
        syllabusId: item.id,
        status: SyllabusDownloadStatus.error,
        errorMessage: e.toString(),
      );
      state = state.copyWith(downloadStates: Map.from(updatedStates));
      return null;
    }
  }

  SyllabusDownloadState? getDownloadState(int syllabusId) {
    return state.downloadStates[syllabusId];
  }

  void clear() {
    state = const SyllabusState();
  }
}

// ============ Providers ============

/// Args for syllabus provider - includes level ID
class SyllabusArgs {
  final int levelId;

  const SyllabusArgs({required this.levelId});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyllabusArgs && other.levelId == levelId;
  }

  @override
  int get hashCode => levelId.hashCode;
}

final syllabusProvider =
    StateNotifierProvider.family<SyllabusNotifier, SyllabusState, int>((
      ref,
      levelId,
    ) {
      final repository = ref.watch(syllabusRepositoryProvider);
      return SyllabusNotifier(repository);
    });

/// Provider to get class levels
final classLevelsProvider = FutureProvider<List<ClassLevel>>((ref) async {
  final repository = ref.watch(syllabusRepositoryProvider);
  return repository.getLevels();
});
