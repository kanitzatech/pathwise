import 'package:flutter/material.dart';
import 'package:guidex/app_routes.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isAgreeWithTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              children: [
                // Top blue Circle
                Positioned(
                  top: -150,
                  left: -50,
                  right: -50,
                  child: Container(
                    height: 400,
                    decoration: const BoxDecoration(
                      color: Color.fromARGB(255, 94, 194, 237),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 60),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 25),
                            const Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Let’s build your success path ! ',
                              style: TextStyle(
                                fontSize: 12,
                                // fontWeight: FontWeight.w400,
                                color: Colors.grey[800],
                              ),
                            ),

                            const SizedBox(height: 88),
                            // Name Field
                            _buildInputField(
                              hint: 'Enter your Name',
                              controller: _nameController,
                            ),
                            const SizedBox(height: 20),
                            // Email Field
                            _buildInputField(
                              hint: 'Enter your Email',
                              controller: _emailController,
                            ),
                            const SizedBox(height: 20),
                            // Password Field
                            _buildInputField(
                              hint: 'Enter your Password',
                              controller: _passwordController,
                              isPassword: true,
                              isPasswordVisible: _isPasswordVisible,
                              onToggleVisibility: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                            const SizedBox(height: 20),
                            // Agree with Terms and Condition
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: _isAgreeWithTerms,
                                  onChanged: (value) {
                                    setState(() {
                                      _isAgreeWithTerms = value ?? false;
                                    });
                                  },
                                  activeColor: const Color.fromARGB(
                                    255,
                                    94,
                                    194,
                                    237,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      'Agree with ',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {},
                                      child: const Text(
                                        'Terms & Condition',
                                        style: TextStyle(
                                          color: Color.fromARGB(
                                            255,
                                            51,
                                            156,
                                            201,
                                          ),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            // Sign Up Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: () {
                                  // For demo, go to home
                                  Navigator.pushNamed(context, AppRoutes.userCategory);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color.fromARGB(
                                    255,
                                    94,
                                    194,
                                    237,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Sign Up',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                            // Divider
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(color: Colors.grey[300]),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    'Or ',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(color: Colors.grey[300]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            //  const SizedBox(height: 30),
                            // Bottom Link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildSocialButton(Icons.apple, Colors.black),
                                const SizedBox(width: 20),
                                _buildSocialButton(
                                  Icons.g_mobiledata_rounded,
                                  Colors.red,
                                  isGoogle: true,
                                ),
                                const SizedBox(width: 20),
                                _buildSocialButton(
                                  Icons.facebook,
                                  Colors.blue[800]!,
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Social Buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Already have an account? ',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pop(context);
                                  },
                                  child: const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      color: Color.fromARGB(255, 5, 173, 245),
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    // required String label,
    required String hint,
    required TextEditingController controller,
    bool isPassword = false,
    bool? isPasswordVisible,
    VoidCallback? onToggleVisibility,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text(
        //   label,
        //   style: const TextStyle(
        //     fontSize: 14,
        //     fontWeight: FontWeight.w500,
        //     color: Colors.black87,
        //   ),
        // ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword && !(isPasswordVisible ?? false),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            filled: true,
            fillColor: Colors.grey[100],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      (isPasswordVisible ?? false)
                          ? Icons.visibility
                          : Icons.visibility_off_outlined,
                      color: Colors.grey[600],
                    ),
                    onPressed: onToggleVisibility,
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton(
    IconData icon,
    Color color, {
    bool isGoogle = false,
  }) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey[200]!),
        color: Colors.white,
      ),
      child: Center(
        child: Icon(icon, color: color, size: isGoogle ? 40 : 24),
      ),
    );
  }
}
