class Recommendation {
  final String collegeName;
  final String courseName;
  final String district;
  final String collegeType;
  final double cutoff;
  final double score;
  final String recommendationType;

  Recommendation({
    required this.collegeName,
    required this.courseName,
    required this.district,
    required this.collegeType,
    required this.cutoff,
    required this.score,
    required this.recommendationType,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    final type = _readString(
      json,
      const ['recommendation_type', 'recommendationType', 'type'],
      fallback: 'SAFE',
    ).toUpperCase();

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
      district: _readString(json, const ['district', 'location'],
          fallback: 'Unknown District'),
      collegeType: _readString(
        json,
        const ['college_type', 'collegeType', 'type_name'],
        fallback: 'Unknown Type',
      ),
      cutoff: _readDouble(
          json, const ['cutoff', 'closing_cutoff', 'closingCutoff']),
      score: _readDouble(json, const ['score', 'match_score', 'matchScore']),
      recommendationType: type.isEmpty ? 'SAFE' : type,
    );
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
