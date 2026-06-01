import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uni_transit/core/constants/app_colors.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showLogo;
  final List<Widget>? actions;
  final bool centerTitle;
  final bool showBackArrow;

  const CustomAppBar({
    super.key,
    required this.title,
    this.showLogo = false,
    this.actions,
    this.centerTitle = true,
    this.showBackArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final canPop = Navigator.of(context).canPop();

    return AppBar(
      centerTitle: centerTitle,
      // Show back arrow if: explicitly enabled AND there's a route to pop to
      leading: (showBackArrow && canPop)
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            )
          : null,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      foregroundColor: isDark ? Colors.white : AppColors.primaryNavy,
      surfaceTintColor: Colors.transparent,
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          letterSpacing: 1.2,
          color: isDark ? Colors.white : AppColors.primaryNavy,
        ),
      ),
      actions: actions,
      elevation: 0,
      iconTheme: IconThemeData(
        color: isDark ? Colors.white : AppColors.primaryNavy,
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: isDark ? Colors.white10 : Colors.grey[200],
          height: 1,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
