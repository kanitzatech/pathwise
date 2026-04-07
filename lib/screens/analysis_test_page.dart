import 'package:flutter/material.dart';
import 'package:guidex/app_routes.dart';
import 'package:guidex/models/recommendation.dart';
import 'package:guidex/services/api_service.dart';

class AnalysisTestPage extends StatefulWidget {
  const AnalysisTestPage({super.key});

  @override
  State<AnalysisTestPage> createState() => _AnalysisTestPageState();
}

class _AnalysisTestPageState extends State<AnalysisTestPage> {
  final PageController _pageController = PageController();
  final ApiService _apiService = ApiService();
  int _currentStep = 0;
  bool _isLoading = false;

  // Screen 1 Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  String _selectedCategory = '';

  // Screen 2 Controllers
  final TextEditingController _physicsController = TextEditingController();
  final TextEditingController _chemistryController = TextEditingController();
  final TextEditingController _mathsController = TextEditingController();
  double _cutoff = 0.0;
  final List<String> _categories = ['OC', 'BC', 'MBC', 'SC', 'ST'];

  // Final Selection Data
  String? _selectedDistrict = 'Chennai';
  String _selectedInterest = 'Computer Science Engineering';

  // Screen 3 Data
  final List<String> _selectedCourses = [];
  final List<String> _selectedColleges = [];

  final List<String> _fallbackCourses = [
    'Computer Science Engineering',
    'Information Technology',
    'Electronics and Communication Engineering',
    'Electrical and Electronics Engineering',
    'Mechanical Engineering',
    'Civil Engineering',
    'Biomedical Engineering',
  ];
  final List<String> _collegeOptions = [
    'Anna University - CEG Campus',
    'PSG College of Technology',
    'SSN College of Engineering',
    'Sri Sivasubramaniya Nadar College',
    'Thiagarajar College of Engineering',
    'Coimbatore Institute of Technology',
    'Government College of Technology, Coimbatore',
    'Kumaraguru College of Technology',
    'Velammal Engineering College',
    'Rajalakshmi Engineering College',
    'SRM Institute of Science and Technology',
    'VIT Chennai',
  ];
  List<String> _courseOptions = [];
  bool _coursesLoading = false;
  bool _loadedCoursesFromApi = false;
  final List<String> _districts = [
    'Any',
    'Ariyalur',
    'Chengalpattu',
    'Chennai',
    'Coimbatore',
    'Cuddalore',
    'Dharmapuri',
    'Dindigul',
    'Erode',
    'Kancheepuram',
    'Kanyakumari',
    'Karur',
    'Krishnagiri',
    'Madurai',
    'Nagapattinam',
    'Namakkal',
    'Nilgiris',
    'Perambalur',
    'Pudukkottai',
    'Ramanathapuram',
    'Salem',
    'Sivagangai',
    'Thanjavur',
    'Theni',
    'Thiruvallur',
    'Thiruvannamalai',
    'Thiruvarur',
    'Thoothukudi',
    'Tiruchirappalli',
    'Tirunelveli',
    'Tiruppur',
    'Vellore',
    'Villupuram',
    'Virudhunagar',
  ];

  @override
  void initState() {
    super.initState();
    _physicsController.addListener(_calculateCutoff);
    _chemistryController.addListener(_calculateCutoff);
    _mathsController.addListener(_calculateCutoff);
    _loadCourses();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _mobileController.dispose();
    _physicsController.dispose();
    _chemistryController.dispose();
    _mathsController.dispose();
    super.dispose();
  }

  void _calculateCutoff() {
    final p = double.tryParse(_physicsController.text) ?? 0.0;
    final c = double.tryParse(_chemistryController.text) ?? 0.0;
    final m = double.tryParse(_mathsController.text) ?? 0.0;
    setState(() {
      _cutoff = (p / 2) + (c / 2) + m;
    });
  }

  Future<void> _loadCourses() async {
    setState(() {
      _coursesLoading = true;
    });

    final courses = await _apiService.getCourses();
    if (!mounted) return;

    final resolved = courses.isEmpty ? _fallbackCourses : courses;
    setState(() {
      _courseOptions = resolved;
      _coursesLoading = false;
      _loadedCoursesFromApi = courses.isNotEmpty;
      if (!_courseOptions.contains(_selectedInterest) &&
          _courseOptions.isNotEmpty) {
        _selectedInterest = _courseOptions.first;
      }
    });
  }

  String _interestForRecommendationQuery(String selectedCourse) {
    if (_loadedCoursesFromApi) {
      return selectedCourse;
    }

    final course = selectedCourse.toLowerCase();
    if (course.contains('computer') ||
        course.contains('software') ||
        course.contains('information technology') ||
        course == 'it') {
      return 'Software';
    }

    if (course.contains('electronics') ||
        course.contains('electrical') ||
        course.contains('ece') ||
        course.contains('eee')) {
      return 'Electronics';
    }

    if (course.contains('mechanical')) {
      return 'Mechanical';
    }

    return 'Software';
  }

  void _nextPage() async {
    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep++;
      });
      return;
    }

    setState(() => _isLoading = true);

    if (_nameController.text.isEmpty ||
        _selectedCategory.isEmpty ||
        _cutoff <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all academic details first'),
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    List<Recommendation> prefetchedRecommendations = const [];
    String? prefetchError;

    final recommendationCutoff = _cutoff > 100 ? _cutoff / 2 : _cutoff;
    final districtQuery =
        (_selectedDistrict == null || _selectedDistrict == 'Any')
            ? null
            : _selectedDistrict;

    try {
      final interestForQuery =
          _interestForRecommendationQuery(_selectedInterest);
      prefetchedRecommendations = await _apiService.getRecommendations(
        category: _selectedCategory,
        cutoff: recommendationCutoff,
        interest: interestForQuery,
        district: districtQuery,
        size: 30,
      );
    } catch (e) {
      prefetchError = e.toString().replaceFirst('Exception: ', '');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }

    if (!mounted) return;

    final selectedCoursesForResults = _selectedCourses.isEmpty
        ? <String>[_selectedInterest]
        : List<String>.from(_selectedCourses);

    Navigator.pushNamed(context, AppRoutes.analysisResults, arguments: {
      'name': _nameController.text.trim().isEmpty
          ? 'Student'
          : _nameController.text.trim(),
      'category': _selectedCategory,
      'cutoff': _cutoff,
      'selectedCourses': selectedCoursesForResults,
      'selectedColleges': List<String>.from(_selectedColleges),
      'interest': _selectedInterest,
      'district': _selectedDistrict == 'Any' ? null : _selectedDistrict,
      'prefetchedRecommendations': prefetchedRecommendations,
      'prefetchError': prefetchError,
    });
  }

  void _previousPage() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep--;
      });
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.userCategory);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                ],
              ),
            ),
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _previousPage,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 20, color: Color(0xFF1F2937)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / 3,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                  minHeight: 8,
                ),
              ),
            ),
          ),
          Text(
            "${_currentStep + 1}/3",
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4F46E5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Student Analysis Setup",
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827)),
          ),
          const SizedBox(height: 8),
          const Text(
            "Enter your basic information",
            style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 32),
          _buildTextField("Name", "Enter your full name", _nameController),
          const SizedBox(height: 20),
          _buildTextField(
              "Age / Date of Birth", "e.g. 18 or 12/05/2006", _ageController),
          const SizedBox(height: 20),
          _buildTextField("Mobile Number (Optional)", "Enter mobile number",
              _mobileController,
              isPhone: true),
          const SizedBox(height: 32),
          const Text(
            "Select Category",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _categories.map((cat) {
              final isSelected = _selectedCategory == cat;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFFE5E7EB),
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: const Color(0xFF4F46E5)
                                    .withValues(alpha: 0.1),
                                blurRadius: 8)
                          ]
                        : [],
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFF4B5563),
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Academic Details",
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827)),
          ),
          const SizedBox(height: 8),
          const Text(
            "Enter your marks to calculate cutoff",
            style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 32),
          _buildTextField("Physics Marks", "Out of 100", _physicsController,
              isNumber: true),
          const SizedBox(height: 20),
          _buildTextField("Chemistry Marks", "Out of 100", _chemistryController,
              isNumber: true),
          const SizedBox(height: 20),
          _buildTextField("Mathematics Marks", "Out of 100", _mathsController,
              isNumber: true),
          const SizedBox(height: 40),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  "Your Cutoff",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4F46E5)),
                ),
                const SizedBox(height: 12),
                Text(
                  _cutoff.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Your Preferences",
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827)),
          ),
          const SizedBox(height: 8),
          const Text(
            "Tell us what you like",
            style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 32),
          const Text(
            "Select Preferred Course",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151)),
          ),
          const SizedBox(height: 12),
          if (_coursesLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          _buildSingleSelectDropdown(
            label: "Course",
            options: _courseOptions.isEmpty ? _fallbackCourses : _courseOptions,
            selectedItem: _selectedInterest,
            onChanged: (val) => setState(() => _selectedInterest = val),
          ),
          const SizedBox(height: 32),
          const Text(
            "Location Preference",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151)),
          ),
          const SizedBox(height: 8),
          Text(
            'Using local district list for faster loading. Default district: Chennai.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          _buildSingleSelectDropdown(
            label: "District",
            options: _districts,
            selectedItem: _selectedDistrict ?? 'Chennai',
            onChanged: (val) => setState(() => _selectedDistrict = val),
          ),
          const SizedBox(height: 32),
          const Text(
            "College Preference",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151)),
          ),
          const SizedBox(height: 12),
          _MultiSelectDropdown(
            label: 'Colleges',
            options: _collegeOptions,
            selectedItems: _selectedColleges,
            onChanged: (selected) {
              setState(() {
                _selectedColleges
                  ..clear()
                  ..addAll(selected);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      String label, String hint, TextEditingController controller,
      {bool isNumber = false, bool isPhone = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151)),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType:
                isNumber || isPhone ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButton() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(
                    _currentStep < 2 ? "Next →" : "Start Analysis 🚀",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSingleSelectDropdown({
    required String label,
    required List<String> options,
    required String selectedItem,
    required Function(String) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: options.contains(selectedItem) ? selectedItem : options.first,
          isExpanded: true,
          items: options
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }
}

class _MultiSelectDropdown extends StatefulWidget {
  final String label;
  final List<String> options;
  final List<String> selectedItems;
  final Function(List<String>) onChanged;

  const _MultiSelectDropdown({
    required this.label,
    required this.options,
    required this.selectedItems,
    required this.onChanged,
  });

  @override
  State<_MultiSelectDropdown> createState() => _MultiSelectDropdownState();
}

class _MultiSelectDropdownState extends State<_MultiSelectDropdown> {
  void _showDropdown() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DropdownPanel(
        options: widget.options,
        initialSelected: widget.selectedItems,
        onChanged: (selected) {
          widget.onChanged(selected);
          setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showDropdown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
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
              child: widget.selectedItems.isEmpty
                  ? Text(
                      "Select preferred ${widget.label.toLowerCase()}",
                      style: const TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 14),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: widget.selectedItems.map((item) {
                        return Chip(
                          label: Text(
                            item,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4F46E5)),
                          ),
                          backgroundColor: const Color(0xFFEEF2FF),
                          deleteIcon: const Icon(Icons.close_rounded,
                              size: 14, color: Color(0xFF4F46E5)),
                          onDeleted: () {
                            setState(() {
                              widget.selectedItems.remove(item);
                              widget.onChanged(widget.selectedItems);
                            });
                          },
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide.none),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF6B7280)),
          ],
        ),
      ),
    );
  }
}

class _DropdownPanel extends StatefulWidget {
  final List<String> options;
  final List<String> initialSelected;
  final Function(List<String>) onChanged;

  const _DropdownPanel({
    required this.options,
    required this.initialSelected,
    required this.onChanged,
  });

  @override
  State<_DropdownPanel> createState() => _DropdownPanelState();
}

class _DropdownPanelState extends State<_DropdownPanel> {
  late List<String> _selectedItems;
  late List<String> _filteredOptions;

  @override
  void initState() {
    super.initState();
    _selectedItems = List.from(widget.initialSelected);
    _filteredOptions = widget.options;
  }

  void _filterOptions(String query) {
    setState(() {
      _filteredOptions = widget.options
          .where((option) => option.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Select Courses",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827)),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: _filterOptions,
            decoration: InputDecoration(
              hintText: "Search courses...",
              prefixIcon:
                  const Icon(Icons.search_rounded, color: Color(0xFF9CA3AF)),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredOptions.length,
              itemBuilder: (context, index) {
                final option = _filteredOptions[index];
                final isSelected = _selectedItems.contains(option);
                return CheckboxListTile(
                  title: Text(
                    option,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFF374151),
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  value: isSelected,
                  activeColor: const Color(0xFF4F46E5),
                  checkColor: Colors.white,
                  onChanged: (checked) {
                    setState(() {
                      if (checked!) {
                        _selectedItems.add(option);
                      } else {
                        _selectedItems.remove(option);
                      }
                      widget.onChanged(_selectedItems);
                    });
                  },
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text(
                "Done",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
