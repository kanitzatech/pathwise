import 'package:flutter/material.dart';
import 'package:guidex/app_routes.dart';
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
    this.name = 'John Doe',
    this.cutoff = 182.5,
    this.category = 'BC',
    this.selectedCourses = const ['CSE', 'AI/Data Science', 'ECE'],
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
  String? _error;
  List<Recommendation> _recommendations = [];

  String get _displayName => (widget.name?.trim().isNotEmpty ?? false)
      ? widget.name!.trim()
      : 'Student';

  String get _displayCategory => (widget.category?.trim().isNotEmpty ?? false)
      ? widget.category!.trim()
      : 'NA';

  double get _displayCutoff => widget.cutoff ?? 0.0;

  List<String> get _displayCourses {
    final courses = widget.selectedCourses ?? const <String>[];
    if (courses.isNotEmpty) {
      return courses;
    }

    if (widget.interest != null && widget.interest!.trim().isNotEmpty) {
      return <String>[widget.interest!.trim()];
    }

    return const <String>['Software'];
  }

  @override
  void initState() {
    super.initState();

    if (widget.prefetchedRecommendations != null) {
      _recommendations =
          List<Recommendation>.from(widget.prefetchedRecommendations!);
      _error = widget.prefetchError;
      _isLoading = false;
      return;
    }

    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    final interest = (widget.interest?.trim().isNotEmpty ?? false)
        ? widget.interest!.trim()
        : _displayCourses.first;

    final category = _displayCategory;
    final cutoff = _displayCutoff;
    final district = widget.district;

    if (cutoff <= 0 || category == 'NA') {
      setState(() {
        _error = 'Missing analysis inputs. Please re-analyze and try again.';
        _isLoading = false;
      });
      return;
    }

    try {
      final recommendationCutoff = cutoff > 100 ? cutoff / 2 : cutoff;

      final results = await _apiService.getRecommendations(
        category: category,
        cutoff: recommendationCutoff,
        interest: interest,
        district: district,
        size: 12,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _recommendations = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        final raw = e.toString().replaceFirst('Exception: ', '');
        if (raw.toLowerCase().contains('handshake')) {
          _error =
              'Secure connection failed during handshake. Please check network/date-time and retry.';
        } else {
          _error = raw;
        }
        _isLoading = false;
      });
    }
  }

  List<Recommendation> _byType(String type) {
    final normalized = type.toUpperCase();
    return _recommendations
        .where((r) => r.recommendationType.toUpperCase() == normalized)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: _buildBottomActions(context),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 120),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildSummaryCard(),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                    color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _error = null;
                  _isLoading = true;
                });
                _loadRecommendations();
              },
              child: const Text('Retry'),
            ),
            const SizedBox(height: 100),
          ],
        ),
      );
    }

    final dream = _byType('DREAM');
    final target = _byType('TARGET');
    final safe = _byType('SAFE');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 24),
        _buildSummaryCard(),
        const SizedBox(height: 24),
        _buildInsightCard(),
        const SizedBox(height: 28),
        if (_recommendations.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Text(
              'No recommendations found for the selected inputs. Try Re-analyze with different preferences.',
              style: TextStyle(
                  color: Color(0xFF374151), fontWeight: FontWeight.w600),
            ),
          ),
        if (dream.isNotEmpty) ...[
          _buildSectionHeader('Dream Colleges', const Color(0xFFEF4444)),
          const SizedBox(height: 12),
          ...dream.map((item) =>
              _buildCollegeCard(item, 'Dream', const Color(0xFFEF4444))),
          const SizedBox(height: 20),
        ],
        if (target.isNotEmpty) ...[
          _buildSectionHeader('Target Colleges', const Color(0xFFF59E0B)),
          const SizedBox(height: 12),
          ...target.map((item) =>
              _buildCollegeCard(item, 'Target', const Color(0xFFF59E0B))),
          const SizedBox(height: 20),
        ],
        if (safe.isNotEmpty) ...[
          _buildSectionHeader('Safe Colleges', const Color(0xFF22C55E)),
          const SizedBox(height: 12),
          ...safe.map((item) =>
              _buildCollegeCard(item, 'Safe', const Color(0xFF22C55E))),
        ],
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF1F2937), size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.share_outlined,
                color: Color(0xFF1F2937), size: 22),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Analysis Report',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Based on your cutoff and preferences',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NAME',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade500,
                        letterSpacing: 1),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _displayName,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937)),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _displayCategory,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4F46E5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CUTOFF',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade500,
                          letterSpacing: 1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _displayCutoff.toStringAsFixed(1),
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF4F46E5)),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'COURSES',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade500,
                          letterSpacing: 1),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _displayCourses
                          .map((course) => _buildChip(course))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4B5563)),
      ),
    );
  }

  Widget _buildInsightCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.1), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Color(0xFF4F46E5), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Overall Insight',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4F46E5)),
                    ),
                    Text(
                      '${_recommendations.length} Colleges',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade800),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Fetched live recommendations from backend based on your profile and cutoff ${_displayCutoff.toStringAsFixed(1)}.',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1E1B4B),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827)),
        ),
      ],
    );
  }

  Widget _buildCollegeCard(Recommendation item, String badge, Color color) {
    final probability = switch (badge) {
      'Dream' => 35,
      'Target' => 70,
      _ => 92,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.collegeName,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.courseName} • ${item.district}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildProbabilityIndicator(probability, color),
                    const SizedBox(width: 8),
                    Text(
                      'Cutoff ${item.cutoff.toStringAsFixed(1)}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badge,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProbabilityIndicator(int value, Color color) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value / 100,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Download Report',
                  style: TextStyle(
                      color: Color(0xFF4B5563),
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () => Navigator.pushReplacementNamed(
                  context, AppRoutes.analysisTest),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 4,
                shadowColor: const Color(0xFF4F46E5).withValues(alpha: 0.3),
              ),
              child: const Text('Re-analyze',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
