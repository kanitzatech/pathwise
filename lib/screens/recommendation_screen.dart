import 'package:flutter/material.dart';
import 'package:guidex/services/api_service.dart';
import 'package:guidex/app_routes.dart';

class RecommendationScreen extends StatefulWidget {
  const RecommendationScreen({super.key});

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final _cutoffController = TextEditingController();

  String _selectedCategory = 'OC';
  String _selectedInterest = 'Software';
  String _sortBy = 'best_match';
  String? _selectedDistrict;

  final List<String> _categories = ['OC', 'BC', 'MBC', 'SC', 'ST'];
  final List<String> _interests = ['Software', 'Electronics', 'Mechanical', 'Civil', 'Biomedical'];
  List<String> _districts = ['All Districts'];

  List<dynamic> _recommendations = [];
  bool _isLoading = false;
  String _errorMessage = '';
  bool _hasSearched = false;

  int _currentPage = 0;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _scrollController.addListener(_onScroll);
    _fetchDistricts();
  }

  Future<void> _fetchDistricts() async {
    try {
      final districts = await _apiService.getDistricts();
      if (districts.isNotEmpty) {
        setState(() {
          _districts = ['All Districts', ...districts];
        });
      }
    } catch (e) {
      debugPrint('Error loading districts: $e');
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore && !_isLoading) {
        _fetchRecommendations(loadMore: true);
      }
    }
  }

  Future<void> _fetchRecommendations({bool loadMore = false}) async {
    if (!loadMore) {
      final cutoffText = _cutoffController.text.trim();
      if (cutoffText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your cutoff mark')));
        return;
      }

      final cutoff = double.tryParse(cutoffText);
      if (cutoff == null || cutoff < 0 || cutoff > 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid cutoff between 0 and 200')));
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = '';
        _hasSearched = true;
        _recommendations = [];
        _currentPage = 0;
        _hasMore = true;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final cutoff = double.parse(_cutoffController.text.trim());
      final districtQuery = (_selectedDistrict == null || _selectedDistrict == 'All Districts') ? null : _selectedDistrict;

      final results = await _apiService.getRecommendations(
        _selectedCategory,
        cutoff,
        _selectedInterest,
        district: districtQuery,
        sortBy: _sortBy,
        page: _currentPage,
        size: 20,
      );

      setState(() {
        if (loadMore) {
          _recommendations.addAll(results);
        } else {
          _recommendations = results;
        }

        if (results.length < 20) {
          _hasMore = false;
        } else {
          _currentPage++;
        }
      });
    } catch (e) {
      setState(() {
        if (!loadMore) _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  @override
  void dispose() {
    _cutoffController.dispose();
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showCollegeDetails(dynamic college) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.account_balance, color: Color(0xFF3B82F6), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      college['college_name'] ?? 'Unknown',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              _buildDetailRow(Icons.school, 'Course', college['course_name'] ?? 'N/A'),
              _buildDetailRow(Icons.pin_drop, 'District', college['district'] ?? 'N/A'),
              _buildDetailRow(Icons.category, 'Type', college['college_type'] ?? 'N/A'),
              _buildDetailRow(
                Icons.lightbulb_outline, 
                'Recommendation', 
                college['recommendation_type'] ?? 'SAFE',
                isHighlight: true
              ),
              _buildDetailRow(Icons.score, 'Closing Cutoff', '${college['cutoff'] ?? 'N/A'}', isHighlight: true),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text('$title:', style: TextStyle(fontSize: 15, color: Colors.grey[700])),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
                color: isHighlight ? Color(0xFF3B82F6) : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, AppRoutes.userCategory);
            }
          },
        ),
        title: const Text('Find Colleges', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Color(0xFF3B82F6),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildFilterPanel(),
          Expanded(
            child: _buildBodyContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: 'Category',
                  value: _selectedCategory,
                  items: _categories,
                  onChanged: (val) => setState(() => _selectedCategory = val!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: 'Interest',
                  value: _selectedInterest,
                  items: _interests,
                  onChanged: (val) => setState(() => _selectedInterest = val!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdown(
                  label: 'District',
                  value: _selectedDistrict ?? 'All Districts',
                  items: _districts,
                  onChanged: (val) => setState(() => _selectedDistrict = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildOutlinedDropdown(
                  label: 'Sort By',
                  value: _sortBy,
                  items: const {
                    'best_match': 'Rank by Best Match',
                    'highest_cutoff': 'Rank by Highest Cutoff',
                  },
                  onChanged: (val) {
                    setState(() => _sortBy = val!);
                    if (_hasSearched) _fetchRecommendations(); // Auto-refresh on sort change
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : _fetchRecommendations,
                    child: const Text('Search', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField() {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: _cutoffController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Your Cutoff',
          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF3B82F6)),
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildOutlinedDropdown({
    required String label,
    required String value,
    required Map<String, String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Color(0xFF3B82F6).withOpacity(0.05),
        border: Border.all(color: Color(0xFF3B82F6).withOpacity(0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.sort, color: Color(0xFF3B82F6), size: 18),
          style: const TextStyle(fontSize: 13, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600),
          items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) {
      return _buildSkeletonLoader();
    }

    if (_errorMessage.isNotEmpty) {
      return _buildErrorState();
    }

    if (_hasSearched && _recommendations.isEmpty) {
      return _buildEmptyState();
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded, size: 80, color: const Color(0xFF3B82F6).withOpacity(0.2)),
            const SizedBox(height: 16),
            const Text(
              'Enter your cutoff to find\nthe best colleges for you!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Grouping logic
    final dreamColleges = _recommendations.where((e) => e['recommendation_type'] == 'DREAM').toList();
    final targetColleges = _recommendations.where((e) => e['recommendation_type'] == 'TARGET').toList();
    final safeColleges = _recommendations.where((e) => e['recommendation_type'] == 'SAFE').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            'Showing ${_recommendations.length} colleges',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ),
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              if (dreamColleges.isNotEmpty) ...[
                _buildSectionHeader('🔥 Dream Colleges', Colors.green),
                ...dreamColleges.map((item) => _buildCollegeCard(item)),
              ],
              if (targetColleges.isNotEmpty) ...[
                _buildSectionHeader('⚖️ Target Colleges', Colors.orange),
                ...targetColleges.map((item) => _buildCollegeCard(item)),
              ],
              if (safeColleges.isNotEmpty) ...[
                _buildSectionHeader('🛡️ Safe Colleges', Colors.blue),
                ...safeColleges.map((item) => _buildCollegeCard(item)),
              ],
              if (_isLoadingMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (!_hasMore && _recommendations.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No more colleges found',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 12, left: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollegeCard(dynamic item) {
    final type = item['recommendation_type'] ?? 'SAFE';
    Color typeColor;
    String typeLabel;

    switch (type) {
      case 'DREAM':
        typeColor = Colors.green;
        typeLabel = 'Dream';
        break;
      case 'TARGET':
        typeColor = Colors.orange;
        typeLabel = 'Target';
        break;
      default:
        typeColor = Colors.blue;
        typeLabel = 'Safe';
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showCollegeDetails(item),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['college_name'] ?? 'Unknown College',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            typeLabel,
                            style: TextStyle(
                              color: typeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Cutoff',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF3B82F6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${item['cutoff']}',
                          style: const TextStyle(
                            color: Color(0xFF3B82F6),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.menu_book, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item['course_name'] ?? 'N/A',
                      style: TextStyle(fontSize: 14, color: Colors.grey[800], fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    item['district'] ?? 'Unknown',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 12),
                  if (item['college_type'] != null) ...[
                    Icon(Icons.account_balance, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      item['college_type'],
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ]
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off, size: 60, color: Colors.orange),
            ),
            const SizedBox(height: 24),
            const Text(
              "No colleges match your cutoff",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            const Text(
              "Try adjusting your cutoff, changing your category, or selecting a different location.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 60, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              "Connection Failed",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchRecommendations,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return FadeTransition(
          opacity: _animationController,
          child: Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(width: 200, height: 16, color: Colors.grey[200]),
                      Container(
                        width: 50,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(width: 150, height: 14, color: Colors.grey[200]),
                  const SizedBox(height: 8),
                  Container(width: 100, height: 14, color: Colors.grey[200]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
