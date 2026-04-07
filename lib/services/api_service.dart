import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/recommendation.dart';

class ApiService {
  // Android emulator must use 10.0.2.2 to reach host machine localhost.
  static const String _androidEmulatorBaseUrl = 'http://10.0.2.2:8080';

  // Hosted backend fallback to ensure real data is available when local API is down.
  static const String _cloudRunBaseUrl = String.fromEnvironment(
    'CLOUD_API_BASE_URL',
    defaultValue: 'https://pathwise-backend-z43lsllm3q-el.a.run.app',
  );

  // For real devices, pass your PC LAN IP with --dart-define=LOCAL_API_HOST=192.x.x.x.
  static const String _realDeviceHost =
      String.fromEnvironment('LOCAL_API_HOST', defaultValue: '192.168.1.100');

  // Optional full override, e.g. --dart-define=API_BASE_URL=http://192.168.1.5:8080
  static const String _apiBaseUrlOverride =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const Duration _requestTimeout = Duration(seconds: 12);
  static const Duration _localProbeTimeout = Duration(seconds: 2);

  static String? _preferredBaseUrl;
  static List<String>? _cachedDistricts;
  static List<String>? _cachedCourses;

  String _normalizeBaseUrl(String rawBaseUrl) {
    final trimmed = rawBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return trimmed;
  }

  List<String> _baseCandidates() {
    final candidates = <String>[];

    final override = _normalizeBaseUrl(_apiBaseUrlOverride);
    if (override.isNotEmpty) {
      candidates.add(override);
      return candidates;
    }

    if (kIsWeb) {
      candidates.add(_cloudRunBaseUrl);
      candidates.add('http://localhost:8080');
      return candidates;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      candidates.add(_cloudRunBaseUrl);
      candidates.add(_androidEmulatorBaseUrl);
      candidates.add('http://$_realDeviceHost:8080');
      return candidates;
    }

    candidates.add(_cloudRunBaseUrl);
    candidates.add('http://$_realDeviceHost:8080');
    candidates.add('http://localhost:8080');
    return candidates;
  }

  List<String> _orderedBaseCandidates() {
    final candidates = _baseCandidates();
    final preferred = _preferredBaseUrl;
    if (preferred == null || preferred.trim().isEmpty) {
      return candidates;
    }

    final ordered = <String>[preferred, ...candidates];
    final seen = <String>{};
    return ordered.where((base) => seen.add(_normalizeBaseUrl(base))).toList();
  }

  Duration _timeoutForBase(String base, {String path = ''}) {
    final normalizedBase = _normalizeBaseUrl(base);
    final normalizedCloud = _normalizeBaseUrl(_cloudRunBaseUrl);

    final isMetadataPath = path == '/api/courses' ||
        path == '/api/districts' ||
        path == '/api/available-courses';

    if (isMetadataPath) {
      if (normalizedBase == normalizedCloud) {
        return const Duration(seconds: 4);
      }
      return const Duration(seconds: 1);
    }

    if (normalizedBase == normalizedCloud) {
      return _requestTimeout;
    }
    return _localProbeTimeout;
  }

  String _normalizeInterestForApi(String interest) {
    final raw = interest.trim();
    if (raw.isEmpty) {
      return raw;
    }

    final normalized =
        raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    const aliases = <String, String>{
      'cs': 'Computer Science Engineering',
      'cse': 'Computer Science Engineering',
      'computer science and engineering': 'Computer Science Engineering',
      'computer science engineering': 'Computer Science Engineering',
      'ec': 'Electronics and Communication Engineering',
      'ee': 'Electrical and Electronics Engineering',
      'ei': 'Electronics and Instrumentation Engineering',
      'it': 'Information Technology',
      'ece': 'Electronics and Communication Engineering',
      'eee': 'Electrical and Electronics Engineering',
      'ad': 'Artificial Intelligence and Data Science',
      'am': 'Artificial Intelligence and Machine Learning',
      'mech': 'Mechanical Engineering',
      'me': 'Mechanical Engineering',
      'ce': 'Civil Engineering',
      'civil': 'Civil Engineering',
      'bt': 'Biotechnology',
      'bme': 'Biomedical Engineering',
    };

    return aliases[normalized] ?? raw;
  }

  Uri _buildUri(
    String base,
    String path, {
    Map<String, String>? queryParameters,
  }) {
    return Uri.parse('$base$path').replace(queryParameters: queryParameters);
  }

  Future<List<Recommendation>> getRecommendations({
    required String category,
    required double cutoff,
    required String interest,
    String? district,
  }) async {
    final queryParams = <String, String>{
      'category': category.trim().toUpperCase(),
      'cutoff': cutoff.toString(),
      'interest': _normalizeInterestForApi(interest),
    };

    final normalizedDistrict = district?.trim();
    if (normalizedDistrict != null &&
        normalizedDistrict.isNotEmpty &&
        normalizedDistrict.toLowerCase() != 'any') {
      queryParams['district'] = normalizedDistrict;
    }

    Object? lastError;
    for (final base in _orderedBaseCandidates()) {
      final uri =
          _buildUri(base, '/api/recommend', queryParameters: queryParams);
      debugPrint('Recommendation request URL: $uri');

      try {
        final timeout = _timeoutForBase(base, path: '/api/recommend');
        final response = await http.get(uri).timeout(timeout);
        debugPrint('Recommendation response status: ${response.statusCode}');
        debugPrint('Recommendation response body: ${response.body}');

        if (response.statusCode != 200) {
          lastError = Exception(
            'Recommendation API failed with status ${response.statusCode}',
          );
          continue;
        }

        final decoded = json.decode(response.body);
        final rawList = _extractRecommendationArray(
          decoded,
          studentCutoff: cutoff,
        );

        _preferredBaseUrl = _normalizeBaseUrl(base);

        return rawList
            .whereType<Map>()
            .map((entry) =>
                Recommendation.fromJson(Map<String, dynamic>.from(entry)))
            .toList();
      } on TimeoutException catch (error) {
        lastError = error;
        debugPrint('Recommendation timeout for $uri');
      } catch (error) {
        lastError = error;
        debugPrint('Recommendation request failed for $uri: $error');
      }
    }

    if (lastError is TimeoutException) {
      throw TimeoutException(
          'Recommendation request timed out', _requestTimeout);
    }
    throw Exception('Failed to fetch recommendations');
  }

  Future<List<String>> getDistricts() async {
    final cached = _cachedDistricts;
    if (cached != null && cached.isNotEmpty) {
      return List<String>.from(cached);
    }

    final fetched = await _getStringList('/api/districts');
    if (fetched.isNotEmpty) {
      _cachedDistricts = List<String>.from(fetched);
    }
    return fetched;
  }

  Future<List<String>> getCourses() async {
    final cached = _cachedCourses;
    if (cached != null && cached.isNotEmpty) {
      return List<String>.from(cached);
    }

    final fetched = await _getStringList('/api/courses');
    if (fetched.isNotEmpty) {
      _cachedCourses = List<String>.from(fetched);
    }
    return fetched;
  }

  Future<List<String>> getAvailableCourses({
    required String category,
    required double cutoff,
  }) async {
    final queryParams = <String, String>{
      'category': category.trim().toUpperCase(),
      'cutoff': cutoff.toString(),
    };

    Object? lastError;
    for (final base in _orderedBaseCandidates()) {
      final uri = _buildUri(base, '/api/available-courses',
          queryParameters: queryParams);
      debugPrint('Available courses request URL: $uri');

      try {
        final timeout = _timeoutForBase(base, path: '/api/available-courses');
        final response = await http.get(uri).timeout(timeout);
        debugPrint('Available courses response status: ${response.statusCode}');

        if (response.statusCode != 200) {
          lastError = Exception(
              'Available courses API failed with status ${response.statusCode}');
          continue;
        }

        final decoded = json.decode(response.body);
        if (decoded is List) {
          _preferredBaseUrl = _normalizeBaseUrl(base);
          return decoded
              .map((entry) => entry.toString().trim())
              .where((entry) => entry.isNotEmpty)
              .toList();
        }
      } on TimeoutException catch (error) {
        lastError = error;
        debugPrint('Available courses timeout for $uri');
      } catch (error) {
        lastError = error;
        debugPrint('Available courses request failed for $uri: $error');
      }
    }

    debugPrint('Failed available courses request. Last error: $lastError');
    return [];
  }

  Future<List<String>> _getStringList(String path) async {
    Object? lastError;
    for (final base in _orderedBaseCandidates()) {
      final uri = _buildUri(base, path);
      debugPrint('List request URL: $uri');

      try {
        final timeout = _timeoutForBase(base, path: path);
        final response = await http.get(uri).timeout(timeout);
        debugPrint('List response status: ${response.statusCode}');
        debugPrint('List response body: ${response.body}');

        if (response.statusCode != 200) {
          lastError =
              Exception('List API failed with status ${response.statusCode}');
          continue;
        }

        final decoded = json.decode(response.body);
        if (decoded is List) {
          _preferredBaseUrl = _normalizeBaseUrl(base);
          return decoded
              .map((entry) => entry.toString().trim())
              .where((entry) => entry.isNotEmpty)
              .toList();
        }
      } on TimeoutException catch (error) {
        lastError = error;
        debugPrint('List timeout for $uri');
      } catch (error) {
        lastError = error;
        debugPrint('List request failed for $uri: $error');
      }
    }

    debugPrint('Failed list request for $path. Last error: $lastError');
    return [];
  }

  List<dynamic> _extractRecommendationArray(
    dynamic decoded, {
    required double studentCutoff,
  }) {
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((entry) => _normalizeRecommendationItem(
                Map<String, dynamic>.from(entry),
                studentCutoff: studentCutoff,
              ))
          .toList();
    }

    if (decoded is Map<String, dynamic>) {
      final grouped = <String>['dream', 'target', 'safe'];
      final flattened = <Map<String, dynamic>>[];

      for (final group in grouped) {
        final value = decoded[group];
        if (value is! List) {
          continue;
        }

        for (final raw in value) {
          if (raw is Map) {
            final item = _normalizeRecommendationItem(
              Map<String, dynamic>.from(raw),
              groupedCategory: group,
              studentCutoff: studentCutoff,
            );
            flattened.add(item);
          }
        }
      }

      if (flattened.isNotEmpty) {
        return flattened;
      }

      final results = decoded['results'];
      if (results is List) {
        return results
            .whereType<Map>()
            .map((entry) => _normalizeRecommendationItem(
                  Map<String, dynamic>.from(entry),
                  studentCutoff: studentCutoff,
                ))
            .toList();
      }
    }

    return const [];
  }

  Map<String, dynamic> _normalizeRecommendationItem(
    Map<String, dynamic> item, {
    String? groupedCategory,
    required double studentCutoff,
  }) {
    final detectedCategory = _normalizeRecommendationCategory(
      item['category'] ??
          item['recommendation_type'] ??
          item['recommendationType'] ??
          item['type'],
    );

    if (groupedCategory != null &&
        detectedCategory != null &&
        groupedCategory != detectedCategory) {
      debugPrint(
        'Recommendation category mismatch for ${item['collegeName'] ?? item['college_name'] ?? 'unknown'}: payload=$detectedCategory grouped=$groupedCategory',
      );
    }

    final probability = _normalizeProbability(
      item['probability'] ??
          item['score'] ??
          item['match_score'] ??
          item['matchScore'],
    );
    if (probability != null) {
      item['probability'] = probability;
      item['score'] = probability;
    }

    final closingCutoff = _normalizeCutoff(
      item['cutoff'] ??
          item['closing_cutoff'] ??
          item['closingCutoff'] ??
          item['oc_min'],
    );

    final inferredCategory = _inferRecommendationCategory(
      probability: probability,
      closingCutoff: closingCutoff,
      studentCutoff: studentCutoff,
    );

    final resolvedCategory =
        groupedCategory ?? detectedCategory ?? inferredCategory;
    if (resolvedCategory != null) {
      item['category'] = resolvedCategory;
      item['recommendation_type'] = resolvedCategory;
      item['recommendationType'] = resolvedCategory;
    }

    return item;
  }

  String? _normalizeRecommendationCategory(dynamic value) {
    if (value == null) {
      return null;
    }

    final normalized = value.toString().trim().toLowerCase();

    const aliases = <String, String>{
      'dream': 'dream',
      'reach': 'dream',
      'aspirational': 'dream',
      'ambitious': 'dream',
      'target': 'target',
      'match': 'target',
      'moderate': 'target',
      'balanced': 'target',
      'safe': 'safe',
      'likely': 'safe',
      'safety': 'safe',
      'secure': 'safe',
    };

    final resolved = aliases[normalized];
    if (resolved != null) {
      return resolved;
    }

    return null;
  }

  double? _normalizeCutoff(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value.trim());
    }

    return null;
  }

  String? _inferRecommendationCategory({
    required int? probability,
    required double? closingCutoff,
    required double studentCutoff,
  }) {
    if (closingCutoff != null) {
      final comparableStudentCutoff =
          _normalizeStudentCutoffForComparison(studentCutoff, closingCutoff);
      final gap = comparableStudentCutoff - closingCutoff;

      if (gap >= 8) {
        if (probability != null && probability < 80) {
          return 'target';
        }
        return 'safe';
      }

      if (gap >= 1.5) {
        if (probability != null && probability >= 90) {
          return 'safe';
        }
        return 'target';
      }

      return 'dream';
    }

    if (probability == null) {
      return null;
    }

    if (probability >= 85) {
      return 'safe';
    }
    if (probability >= 60) {
      return 'target';
    }
    return 'dream';
  }

  double _normalizeStudentCutoffForComparison(
    double studentCutoff,
    double closingCutoff,
  ) {
    final studentLooksTwoHundredScale = studentCutoff > 110;
    final closingLooksHundredScale = closingCutoff <= 100;

    if (studentLooksTwoHundredScale && closingLooksHundredScale) {
      return studentCutoff / 2.0;
    }

    return studentCutoff;
  }

  int? _normalizeProbability(dynamic value) {
    if (value == null) {
      return null;
    }

    double? parsed;
    if (value is num) {
      parsed = value.toDouble();
    } else if (value is String) {
      parsed = double.tryParse(value.trim());
    }

    if (parsed == null) {
      return null;
    }

    if (parsed >= 0 && parsed <= 1) {
      parsed = parsed * 100;
    }

    final rounded = parsed.round();
    if (rounded < 0) {
      return 0;
    }
    if (rounded > 100) {
      return 100;
    }
    return rounded;
  }
}
