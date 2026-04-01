import 'package:flutter/material.dart';
import 'package:guidex/app_routes.dart';
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

  final List<String> _fallbackCourses = [
    'Computer Science Engineering',
    'Information Technology',
    'Electronics and Communication Engineering',
    'Electrical and Electronics Engineering',
    'Mechanical Engineering',
    'Civil Engineering',
    'Biomedical Engineering',
  ];
  List<String> _courseOptions = [];
  bool _coursesLoading = false;
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
      if (!_courseOptions.contains(_selectedInterest) &&
          _courseOptions.isNotEmpty) {
        _selectedInterest = _courseOptions.first;
      }
    });
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

    if (!mounted) return;

    setState(() => _isLoading = false);

    final selectedCoursesForResults = <String>[_selectedInterest];

    Navigator.pushNamed(context, AppRoutes.analysisResults, arguments: {
      'name': _nameController.text.trim().isEmpty
          ? 'Student'
          : _nameController.text.trim(),
      'category': _selectedCategory,
      'cutoff': _cutoff,
      'selectedCourses': selectedCoursesForResults,
      'interest': _selectedInterest,
      'district': _selectedDistrict == 'Any' ? null : _selectedDistrict,
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
            options: _districts,
            selectedItem: _selectedDistrict ?? 'Chennai',
            onChanged: (val) => setState(() => _selectedDistrict = val),
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
