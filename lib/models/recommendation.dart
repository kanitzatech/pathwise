class Recommendation {
  final String collegeName;
  final String courseName;
  final double cutoff;
  final double score;
  final String? district;
  final String? collegeType;

  Recommendation({
    required this.collegeName,
    required this.courseName,
    required this.cutoff,
    required this.score,
    this.district,
    this.collegeType,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      collegeName: _readString(
        json,
        const ['college_name', 'collegeName', 'name', 'college'],
        fallback: 'Unknown College',
      ),
      courseName: _readString(
        json,
        const ['course_name', 'courseName', 'course', 'branch'],
        fallback: 'Unknown Course',
      ),
      district: _readOptionalString(json, const ['district', 'location']),
      collegeType: _readOptionalString(
        json,
        const ['college_type', 'collegeType', 'type_name'],
      ),
      cutoff: _readDouble(
          json, const ['cutoff', 'closing_cutoff', 'closingCutoff', 'oc_min']),
      score: _readDouble(json, const ['score', 'match_score', 'matchScore']),
    );
  }

  static String? _readOptionalString(
    Map<String, dynamic> source,
    List<String> keys,
  ) {
    final value = _readString(source, keys, fallback: '');
    return value.isEmpty ? null : value;
  }

  static String _readString(
    Map<String, dynamic> source,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = source[key];
      if (value == null) {
        continue;
      }

      final text = value.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return fallback;
  }

  static double _readDouble(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is num) {
        return value.toDouble();
      }

      if (value is String) {
        final parsed = double.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return 0.0;
  }
}
