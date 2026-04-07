import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/recommendation.dart';

class ApiService {
  static const String _cloudRunApiBaseUrl =
      'https://pathwise-backend-960480080568.us-central1.run.app/api';
  static const bool _useCloudApiByDefault =
      bool.fromEnvironment('USE_CLOUD_API', defaultValue: true);
  static const String _apiBaseUrlOverride =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const String _realDeviceHost =
      String.fromEnvironment('LOCAL_API_HOST', defaultValue: '192.168.1.100');
  static const bool _androidEmulator =
      bool.fromEnvironment('ANDROID_EMULATOR', defaultValue: true);
  static const Duration _requestTimeout = Duration(seconds: 12);

  String _normalizeBaseUrl(String rawBaseUrl) {
    final trimmed = rawBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.isEmpty) {
      return trimmed;
    }

    return trimmed.endsWith('/api') ? trimmed : '$trimmed/api';
  }

  List<String> _districtBaseCandidates() {
    final candidates = <String>{};

    if (_apiBaseUrlOverride.trim().isNotEmpty) {
      candidates.add(_normalizeBaseUrl(_apiBaseUrlOverride));
    }

    candidates.add(_normalizeBaseUrl(baseUrl));
    candidates.add(_normalizeBaseUrl(_cloudRunApiBaseUrl));

    return candidates.where((entry) => entry.isNotEmpty).toList();
  }

  String get baseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) {
      return _normalizeBaseUrl(_apiBaseUrlOverride);
    }

    if (_useCloudApiByDefault) {
      return _normalizeBaseUrl(_cloudRunApiBaseUrl);
    }

    if (kIsWeb) {
      return _normalizeBaseUrl('http://localhost:8080/api');
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      const host = _androidEmulator ? '10.0.2.2' : _realDeviceHost;
      return _normalizeBaseUrl('http://$host:8080/api');
    }

    return _normalizeBaseUrl('http://$_realDeviceHost:8080/api');
  }

  Future<List<String>> getDistricts() async {
    final candidateBases = _districtBaseCandidates();
    for (final candidateBase in candidateBases) {
      final uri = _buildUriFromBase(candidateBase, '/districts');
      try {
        final response = await _get(uri);
        if (response.statusCode != 200) {
          debugPrint(
              'District API failed with status ${response.statusCode} on $candidateBase');
          continue;
        }

        final List<dynamic> decoded = json.decode(response.body);
        final districts = decoded.map((e) => e.toString()).toList();
        if (districts.isNotEmpty) {
          return districts;
        }

        debugPrint('District API returned empty list on $candidateBase');
      } catch (e) {
        debugPrint('Error fetching districts via $candidateBase: $e');
      }
    }

    return [];
  }

  Future<List<String>> getCourses() async {
    final candidateBases = _districtBaseCandidates();
    for (final candidateBase in candidateBases) {
      final uri = _buildUriFromBase(candidateBase, '/courses');
      try {
        final response = await _get(uri);
        if (response.statusCode != 200) {
          debugPrint(
              'Courses API failed with status ${response.statusCode} on $candidateBase');
          continue;
        }

        final List<dynamic> decoded = json.decode(response.body);
        final courses = decoded
            .map((e) => e.toString().trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

        if (courses.isNotEmpty) {
          return courses;
        }

        debugPrint('Courses API returned empty list on $candidateBase');
      } catch (e) {
        debugPrint('Error fetching courses via $candidateBase: $e');
      }
    }

    return [];
  }

  Future<List<Recommendation>> getRecommendations({
    required String category,
    required double cutoff,
    required String interest,
    String? district,
    String sortBy = 'best_match',
    int page = 0,
    int size = 20,
  }) async {
    final queryParams = <String, String>{
      'category': category,
      'cutoff': cutoff.toString(),
      'interest': interest,
      'sortBy': sortBy,
      'page': page.toString(),
      'size': size.toString(),
    };
    if (district != null && district.isNotEmpty) {
      queryParams['district'] = district;
    }

    final uri = _buildUri('/recommend', queryParameters: queryParams);

    try {
      final response = await _get(uri);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final resultsRaw = _extractRecommendationArray(decoded);

        return resultsRaw
            .whereType<Map>()
            .map((entry) =>
                Recommendation.fromJson(Map<String, dynamic>.from(entry)))
            .toList();
      } else {
        throw Exception(
            'Failed to load recommendations: ${response.statusCode}');
      }
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Failed to connect to backend: $e');
    }
  }

  Uri _buildUri(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    final uri = _buildUriFromBase(
      baseUrl,
      path,
      queryParameters: queryParameters,
    );
    return uri;
  }

  Uri _buildUriFromBase(
    String resolvedBaseUrl,
    String path, {
    Map<String, String>? queryParameters,
  }) {
    return Uri.parse('$resolvedBaseUrl$path')
        .replace(queryParameters: queryParameters);
  }

  Future<http.Response> _get(Uri uri) async {
    debugPrint('GET $uri');

    final attemptTimeouts = <Duration>[
      _requestTimeout,
      const Duration(seconds: 18)
    ];
    Object? lastError;

    for (var index = 0; index < attemptTimeouts.length; index++) {
      final timeout = attemptTimeouts[index];
      final isLastAttempt = index == attemptTimeouts.length - 1;

      try {
        final response = await http.get(uri).timeout(timeout);
        debugPrint('Response status ${response.statusCode} for $uri');
        return response;
      } on TimeoutException catch (error) {
        lastError = error;
        if (!isLastAttempt) {
          debugPrint(
              'Timeout for $uri after ${timeout.inSeconds}s. Retrying once...');
          continue;
        }
      } on http.ClientException catch (error) {
        lastError = error;
        final message = error.message.toLowerCase();
        final retryable = message.contains('handshake') ||
            message.contains('connection closed');
        if (retryable && !isLastAttempt) {
          debugPrint(
              'Transient network error for $uri: ${error.message}. Retrying once...');
          continue;
        }

        throw Exception(
          'Network error while contacting $uri: ${error.message}. '
          'Please verify internet connectivity and retry.',
        );
      } catch (error) {
        lastError = error;
        final message = error.toString().toLowerCase();
        final retryable = message.contains('handshake') ||
            message.contains('connection terminated');
        if (retryable && !isLastAttempt) {
          debugPrint('Handshake error for $uri. Retrying once...');
          continue;
        }

        if (message.contains('handshake')) {
          throw Exception(
            'Secure connection failed during handshake for $uri. '
            'Check mobile network stability and device date/time, then retry.',
          );
        }
      }
    }

    if (lastError is TimeoutException) {
      throw Exception(
        'Request timed out while loading $uri. '
        'Server may be waking up or network is slow. Please tap Retry.',
      );
    }

    throw Exception('Failed to load data from $uri. Please retry.');
  }

  List<dynamic> _extractRecommendationArray(dynamic decoded) {
    if (decoded is List) {
      return decoded;
    }

    if (decoded is Map<String, dynamic>) {
      for (final key in const [
        'results',
        'recommendations',
        'data',
        'content',
        'items'
      ]) {
        final value = decoded[key];
        if (value is List) {
          return value;
        }

        if (value is Map<String, dynamic>) {
          for (final nestedKey in const [
            'results',
            'recommendations',
            'content',
            'items'
          ]) {
            final nestedValue = value[nestedKey];
            if (nestedValue is List) {
              return nestedValue;
            }
          }
        }
      }
    }

    return const [];
  }
}
