import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8080/api';

  Future<List<String>> getDistricts() async {
    final uri = Uri.parse('$baseUrl/districts');
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final List<dynamic> decoded = json.decode(response.body);
        return decoded.map((e) => e.toString()).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching districts: $e');
      return [];
    }
  }

  Future<List<dynamic>> getRecommendations(
      String category, double cutoff, String interest, {String? district, String sortBy = 'best_match', int page = 0, int size = 20}) async {
    final queryParams = {
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

    final uri = Uri.parse('$baseUrl/recommend').replace(queryParameters: queryParams);

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic> && decoded.containsKey('results')) {
          return decoded['results'] as List<dynamic>;
        }
        return decoded as List<dynamic>;
      } else {
        throw Exception('Failed to load recommendations: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to backend: $e');
    }
  }
}
