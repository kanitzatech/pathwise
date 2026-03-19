import 'package:flutter/material.dart';
import 'package:guidex/app_routes.dart';
import 'package:guidex/home.dart';
import 'package:guidex/onboardingscreen.dart';
import 'package:guidex/splashscreen.dart';
import 'package:guidex/login_page.dart';
import 'package:guidex/signup_page.dart';
import 'package:guidex/user_category_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'guideX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (context) => const SplashScreen(),
        AppRoutes.onboarding: (context) => const OnboardingScreen(),
        AppRoutes.login: (context) => const LoginPage(),
        AppRoutes.signup: (context) => const SignUpPage(),
        AppRoutes.userCategory: (context) => const UserCategoryPage(),
        AppRoutes.home: (context) => const Home(),
      },
    );
  }
}
