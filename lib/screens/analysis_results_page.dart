import 'package:flutter/material.dart';
import 'package:guidex/models/recommendation.dart';
import 'package:guidex/services/api_service.dart';

class AnalysisResultsPage extends StatefulWidget {
  final String? name;
  final double? cutoff;
  final String? category;
  final List<String>? selectedCourses;
  final String? interest;
  final String? district;
  final List<Recommendation>? prefetchedRecommendations;
  final String? prefetchError;

  const AnalysisResultsPage({
    super.key,
    this.name,
    this.cutoff,
    this.category,
    this.selectedCourses,
    this.interest,
    this.district,
    this.prefetchedRecommendations,
    this.prefetchError,
  });

  @override
  State<AnalysisResultsPage> createState() => _AnalysisResultsPageState();
}

class _AnalysisResultsPageState extends State<AnalysisResultsPage> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  String? _errorMessage;
  List<Recommendation> _recommendations = [];

  String get _resolvedCategory {
    final value = widget.category?.trim().toUpperCase();
    return (value == null || value.isEmpty) ? 'MBC' : value;
  }

  double get _resolvedCutoff {
    return widget.cutoff ?? 0.0;
  }

  String get _resolvedInterest {
    final interest = widget.interest?.trim();
    if (interest != null && interest.isNotEmpty) {
      return interest;
    }

    final firstCourse = widget.selectedCourses?.firstWhere(
      (item) => item.trim().isNotEmpty,
      orElse: () => 'Software',
    );
    return firstCourse?.trim() ?? 'Software';
  }

  @override
  void initState() {
    super.initState();

    if (widget.prefetchedRecommendations != null) {
      _recommendations =
          List<Recommendation>.from(widget.prefetchedRecommendations!);
      _isLoading = false;
      if (widget.prefetchError != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showSnackBar('Failed to fetch recommendations');
        });
      }
      return;
    }

    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    if (_resolvedCutoff <= 0) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please enter a valid cutoff and try again.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final requestedDistrict = widget.district?.trim();

      var results = await _apiService.getRecommendations(
        category: _resolvedCategory,
        cutoff: _resolvedCutoff,
        interest: _resolvedInterest,
        district: requestedDistrict,
      );

      if (!mounted) return;

      if (results.isEmpty &&
          requestedDistrict != null &&
          requestedDistrict.isNotEmpty) {
        final relaxedResults = await _apiService.getRecommendations(
          category: _resolvedCategory,
          cutoff: _resolvedCutoff,
          interest: _resolvedInterest,
          district: null,
        );

        if (!mounted) return;

        if (relaxedResults.isNotEmpty) {
          results = relaxedResults;
          _showSnackBar(
            'No exact match in $requestedDistrict. Showing best colleges from all districts.',
          );
        }
      }

      setState(() {
        _recommendations = results;
        _isLoading = false;
      });

      if (results.isEmpty) {
        final districtLabel =
            (requestedDistrict == null || requestedDistrict.isEmpty)
                ? 'all districts'
                : requestedDistrict;
        _showSnackBar(
          'No exact $_resolvedInterest seats found for $districtLabel. Try Software/IT or another category.',
        );
      }
    } catch (error) {
      if (!mounted) return;

      debugPrint('Recommendation fetch failed: $error');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to fetch recommendations';
      });
      _showSnackBar('Failed to fetch recommendations');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Colleges'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecommendations,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _recommendations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadRecommendations,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_recommendations.isEmpty) {
      return const Center(
        child: Text(
          'No colleges found',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRecommendations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _recommendations.length,
        itemBuilder: (context, index) {
          final item = _recommendations[index];
          return _buildRecommendationCard(item);
        },
      ),
    );
  }

  Widget _buildRecommendationCard(Recommendation item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.collegeName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.courseName,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip('Cutoff', item.cutoff.toStringAsFixed(2)),
                _buildInfoChip('Match', '${item.score.toStringAsFixed(1)}%'),
                if (item.district != null && item.district!.trim().isNotEmpty)
                  _buildInfoChip('District', item.district!),
                if (item.collegeType != null &&
                    item.collegeType!.trim().isNotEmpty)
                  _buildInfoChip('Type', item.collegeType!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
