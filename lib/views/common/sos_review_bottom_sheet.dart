import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uni_transit/core/constants/app_colors.dart';

class SosReviewBottomSheet extends StatefulWidget {
  final String notificationId;
  final String alertId;
  final String alertMessage;

  const SosReviewBottomSheet({
    super.key,
    required this.notificationId,
    required this.alertId,
    required this.alertMessage,
  });

  @override
  State<SosReviewBottomSheet> createState() => _SosReviewBottomSheetState();
}

class _SosReviewBottomSheetState extends State<SosReviewBottomSheet> {
  int _rating = 5;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 1. Fetch user role (Student or Driver) to log in the review
      String userRole = 'Student';
      String displayName = user.displayName ?? 'Anonymous';
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        userRole = userDoc.data()?['role'] ?? 'Student';
        displayName = userDoc.data()?['name'] ?? displayName;
      }

      // 2. Save review to Firestore 'sos_reviews'
      await FirebaseFirestore.instance.collection('sos_reviews').add({
        'alertId': widget.alertId,
        'userId': user.uid,
        'userName': displayName,
        'userRole': userRole,
        'rating': _rating,
        'review': _commentController.text.trim(),
        'alertMessage': widget.alertMessage,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 3. Mark notification as reviewed
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(widget.notificationId)
          .update({'isReviewed': true});

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your feedback has been submitted successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit review: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Icon(Icons.rate_review_rounded, color: AppColors.primaryYellow, size: 48),
              const SizedBox(height: 12),
              Text(
                'Rate Emergency Assistance',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDark ? Colors.white : AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'How satisfied were you with the emergency response and assistance received for your SOS?',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.blueGrey[600],
                ),
              ),
              const SizedBox(height: 20),
              // Star Rating Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starVal = index + 1;
                  return IconButton(
                    onPressed: () {
                      setState(() {
                        _rating = starVal;
                      });
                    },
                    icon: Icon(
                      starVal <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
                      color: Colors.amber,
                      size: 40,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              // Comment Input
              TextField(
                controller: _commentController,
                maxLines: 3,
                style: TextStyle(color: isDark ? Colors.white : AppColors.primaryNavy),
                decoration: InputDecoration(
                  hintText: 'Share your comments or suggestions...',
                  hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.primaryYellow, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Submit and Cancel Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitReview,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryNavy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Submit Review',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
