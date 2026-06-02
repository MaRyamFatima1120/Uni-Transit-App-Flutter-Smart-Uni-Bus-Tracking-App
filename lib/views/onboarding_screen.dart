import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:uni_transit/core/constants/app_assets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _floatingController;
  late Animation<double> _floatingAnimation;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: "Real-time ",
      highlightText: "Tracking",
      description: "Track your university bus in real-time and never miss your ride again with our advanced GPS system.",
      image: AppAssets.onboardingTracking,
      gradient: [const Color(0xFF141938), const Color(0xFF232A55)],
    ),
    OnboardingData(
      title: "Smart ",
      highlightText: "Hub ETA",
      description: "Get precise estimated arrival times for every campus hub. Plan your commute with total confidence.",
      image: AppAssets.onboardingSchedule,
      gradient: [const Color(0xFF1A2634), const Color(0xFF131D28)],
    ),
    OnboardingData(
      title: "Student ",
      highlightText: "Safety First",
      description: "Your safety is our priority. Quick-access SOS alerts and live location sharing for peace of mind.",
      image: AppAssets.onboardingSafety,
      gradient: [const Color(0xFF281E3B), const Color(0xFF161022)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _floatingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _floatingController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _floatingController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onFinish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient Animation
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _pages[_currentPage].gradient,
              ),
            ),
          ),

          // Glowing Orb 1 (Top Right / Center depending on page)
          AnimatedAlign(
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutQuint,
            alignment: _currentPage == 0
                ? Alignment.topRight
                : (_currentPage == 1 ? Alignment.centerRight : Alignment.topCenter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 1000),
              width: _currentPage == 1 ? 350 : 250,
              height: _currentPage == 1 ? 350 : 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryYellow.withValues(alpha: 0.06),
              ),
            ),
          ),

          // Glowing Orb 2 (Bottom Left / Center depending on page)
          AnimatedAlign(
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutQuint,
            alignment: _currentPage == 0
                ? Alignment.bottomLeft
                : (_currentPage == 1 ? Alignment.bottomCenter : Alignment.centerLeft),
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.03),
              ),
            ),
          ),

          // Content Pages
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _pages.length,
            itemBuilder: (context, index) => _buildPage(_pages[index]),
          ),

          // Bottom Controls
          Positioned(
            bottom: 40,
            left: 30,
            right: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Page Indicator
                Row(
                  children: List.generate(
                    _pages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      margin: const EdgeInsets.only(right: 8),
                      height: 8,
                      width: _currentPage == index ? 32 : 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? AppColors.primaryYellow
                            : Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: _currentPage == index
                            ? [
                                BoxShadow(
                                  color: AppColors.primaryYellow.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),

                // Navigation Button
                GestureDetector(
                  onTap: () {
                    if (_currentPage == _pages.length - 1) {
                      _onFinish();
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutQuart,
                      );
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: EdgeInsets.symmetric(
                      horizontal: _currentPage == _pages.length - 1 ? 28 : 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryYellow,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryYellow.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentPage == _pages.length - 1 ? "GET STARTED" : "NEXT",
                          style: GoogleFonts.poppins(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 1.0,
                          ),
                        ),
                        if (_currentPage != _pages.length - 1) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.black,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Skip Button
          Positioned(
            top: 60,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: TextButton(
                onPressed: _onFinish,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(
                  "SKIP",
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;
        final isSmallScreen = screenHeight < 700;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: screenHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: isSmallScreen ? 80 : 100),

                  // Illustration Card Container (Glassmorphic)
                  Container(
                    height: screenHeight * (isSmallScreen ? 0.32 : 0.36),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.08),
                          Colors.white.withValues(alpha: 0.02),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Soft Grid Pattern
                          Opacity(
                            opacity: 0.08,
                            child: CustomPaint(
                              size: Size.infinite,
                              painter: GridPainter(),
                            ),
                          ),
                          // Floor Shadow under the image
                          Positioned(
                            bottom: isSmallScreen ? 20 : 30,
                            child: AnimatedBuilder(
                              animation: _floatingAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: 1.0 - (0.15 * _floatingAnimation.value),
                                  child: Opacity(
                                    opacity: 0.8 - (0.3 * _floatingAnimation.value),
                                    child: Container(
                                      width: 140,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black,
                                            blurRadius: 10,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          // Floating Illustration Image
                          AnimatedBuilder(
                            animation: _floatingAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(0, -12 - (10 * _floatingAnimation.value)),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Image.asset(
                                    data.image,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.image_outlined,
                                        size: 80,
                                        color: Colors.white.withValues(alpha: 0.2),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: isSmallScreen ? 32 : 48),

                  // Title with yellow highlighted keyword
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: GoogleFonts.poppins(
                        fontSize: isSmallScreen ? 26 : 30,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                      children: [
                        TextSpan(text: data.title),
                        TextSpan(
                          text: data.highlightText,
                          style: const TextStyle(color: AppColors.primaryYellow),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Description Paragraph
                  Text(
                    data.description,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: isSmallScreen ? 14 : 15,
                      color: Colors.white.withValues(alpha: 0.7),
                      height: 1.6,
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  SizedBox(height: isSmallScreen ? 100 : 120),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class OnboardingData {
  final String title;
  final String highlightText;
  final String description;
  final String image;
  final List<Color> gradient;

  OnboardingData({
    required this.title,
    required this.highlightText,
    required this.description,
    required this.image,
    required this.gradient,
  });
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 1.0;

    const double step = 20.0;

    // Draw vertical lines
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
