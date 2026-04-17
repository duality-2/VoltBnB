import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _onboardingData = [
    {
      "title": "Find EV Chargers Anywhere",
      "body": "Locate available charging stations near you in real-time.",
      "icon": Icons.map_rounded,
    },
    {
      "title": "Book Your Time Slot",
      "body": "Reserve a charger in advance so you never have to wait in line.",
      "icon": Icons.calendar_month_rounded,
    },
    {
      "title": "Host and Earn",
      "body": "List your home charger and earn money while you're not using it.",
      "icon": Icons.payments_rounded,
    },
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Gradient Animation
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE8F5E9), // Light green tint
                    Color(0xFFF8FAFC), // White/gray
                    Color(0xFFF8FAFC),
                  ],
                ),
              ),
            ),
          ),
          // Decorative glowing orb
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00E676).withValues(alpha: 0.15),
              ),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true))
             .scaleXY(end: 1.2, duration: 4.seconds, curve: Curves.easeInOut),
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (value) => setState(() => _currentPage = value),
                    itemCount: _onboardingData.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Glassmorphic Icon Container
                            ClipRRect(
                              borderRadius: BorderRadius.circular(40),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.all(40),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(40),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 30,
                                        offset: const Offset(0, 10),
                                      )
                                    ],
                                  ),
                                  child: Icon(
                                    _onboardingData[index]['icon'] as IconData,
                                    size: 100,
                                    color: const Color(0xFF00E676),
                                  ),
                                ),
                              ),
                            ).animate(key: ValueKey('icon_$index'))
                             .scale(duration: 600.ms, curve: Curves.easeOutBack)
                             .fadeIn(duration: 400.ms),
                            const SizedBox(height: 56),
                            Text(
                              _onboardingData[index]['title'] as String,
                              style: const TextStyle(
                                fontSize: 32,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ).animate(key: ValueKey('title_$index'))
                             .slideY(begin: 0.5, end: 0, duration: 500.ms, curve: Curves.easeOutQuart)
                             .fadeIn(),
                            const SizedBox(height: 16),
                            Text(
                              _onboardingData[index]['body'] as String,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ).animate(key: ValueKey('body_$index'))
                             .slideY(begin: 0.5, end: 0, delay: 100.ms, duration: 500.ms, curve: Curves.easeOutQuart)
                             .fadeIn(delay: 100.ms),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // Bottom Navigation
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Smooth Pagination Dots
                      Row(
                        children: List.generate(
                          _onboardingData.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.only(right: 8),
                            height: 8,
                            width: _currentPage == index ? 32 : 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? const Color(0xFF00E676)
                                  : Colors.grey.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      // Modern Pill Button
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: _currentPage == _onboardingData.length - 1 ? 160 : 120,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_currentPage == _onboardingData.length - 1) {
                              _completeOnboarding();
                            } else {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOutCubic,
                              );
                            }
                          },
                          child: Text(
                            _currentPage == _onboardingData.length - 1
                                ? 'Get Started'
                                : 'Next',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
