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
  static const Duration _requestTimeout = Duration(seconds: 10);
  static const Duration _localProbeTimeout = Duration(seconds: 2);

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

  Duration _timeoutForBase(String base) {
    final normalizedBase = _normalizeBaseUrl(base);
    final normalizedCloud = _normalizeBaseUrl(_cloudRunBaseUrl);
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
    for (final base in _baseCandidates()) {
      final uri =
          _buildUri(base, '/api/recommend', queryParameters: queryParams);
      debugPrint('Recommendation request URL: $uri');

      try {
        final timeout = _timeoutForBase(base);
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
        final rawList = _extractRecommendationArray(decoded);

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
    return _getStringList('/api/districts');
  }

  Future<List<String>> getCourses() async {
    return _getStringList('/api/courses');
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
    for (final base in _baseCandidates()) {
      final uri = _buildUri(base, '/api/available-courses',
          queryParameters: queryParams);
      debugPrint('Available courses request URL: $uri');

      try {
        final timeout = _timeoutForBase(base);
        final response = await http.get(uri).timeout(timeout);
        debugPrint('Available courses response status: ${response.statusCode}');

        if (response.statusCode != 200) {
          lastError = Exception(
              'Available courses API failed with status ${response.statusCode}');
          continue;
        }

        final decoded = json.decode(response.body);
        if (decoded is List) {
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
    for (final base in _baseCandidates()) {
      final uri = _buildUri(base, path);
      debugPrint('List request URL: $uri');

      try {
        final timeout = _timeoutForBase(base);
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

  List<dynamic> _extractRecommendationArray(dynamic decoded) {
    if (decoded is List) {
      return decoded;
    }

    if (decoded is Map<String, dynamic>) {
      final results = decoded['results'];
      if (results is List) {
        return results;
      }
    }

    return const [];
  }
}
