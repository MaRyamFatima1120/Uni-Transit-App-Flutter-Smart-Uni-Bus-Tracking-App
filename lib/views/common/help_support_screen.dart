import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uni_transit/services/auth_service.dart';
import 'package:intl/intl.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _issueController = TextEditingController();
  
  List<Map<String, dynamic>> _userTickets = [];
  String? _userRole;
  bool _isSubmitting = false;
  int _activeTabIndex = 0; // 0 for Submit, 1 for History
  final Set<String> _expandedTicketIds = {};
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _fetchUserTickets();
    _prefillUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _issueController.dispose();
    super.dispose();
  }

  void _prefillUserData() {
    if (_currentUser != null) {
      _nameController.text = _currentUser.displayName ?? '';
      _emailController.text = _currentUser.email ?? '';
      _phoneController.text = _currentUser.phoneNumber ?? '';
      
      AuthService().getUserRole(_currentUser.uid).then((role) {
        if (mounted) {
          setState(() {
            _userRole = role;
          });
        }
      });
    }
  }

  void _fetchUserTickets() {
    if (_currentUser == null) return;

    _firestore
        .collection('support_tickets')
        .where('userId', isEqualTo: _currentUser.uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      final List<Map<String, dynamic>> loadedTickets = [];
      for (var doc in snapshot.docs) {
        final ticket = doc.data();
        ticket['id'] = doc.id;
        loadedTickets.add(ticket);
      }

      if (mounted) {
        setState(() {
          _userTickets = loadedTickets;
        });
      }
    }, onError: (error) {
      debugPrint("Error fetching tickets: $error");
    });
  }

  Future<void> _submitTicket() async {
    if (_nameController.text.trim().isEmpty) {
      _showToast("Please enter your name", Colors.orange);
      return;
    }

    if (_phoneController.text.trim().isEmpty) {
      _showToast("Please enter your phone number", Colors.orange);
      return;
    }

    if (_issueController.text.trim().isEmpty) {
      _showToast("Please describe your issue", Colors.orange);
      return;
    }

    if (_currentUser == null) return;

    setState(() => _isSubmitting = true);

    try {
      await _firestore.collection('support_tickets').add({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'issue': _issueController.text.trim(),
        'status': 'Pending',
        'timestamp': FieldValue.serverTimestamp(),
        'userEmail': _currentUser.email,
        'userName': _currentUser.displayName ?? 'Anonymous',
        'userRole': _userRole ?? 'Unknown',
        'userId': _currentUser.uid,
        'userRead': true,
        'adminRead': false,
      });

      _issueController.clear();
      _showToast("Issue submitted successfully!", Colors.green);
      
      // Auto-switch to history tab to show the new ticket
      setState(() => _activeTabIndex = 1);
    } catch (e) {
      _showToast("Error: $e", Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showToast(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomHeader(context),
            _buildTabSelector(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                child: AnimatedCrossFade(
                  firstChild: _buildIssueReporter(),
                  secondChild: _buildTicketHistory(),
                  crossFadeState: _activeTabIndex == 0
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  duration: const Duration(milliseconds: 300),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(
        top: 10,
        bottom: 16,
        left: 24,
        right: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              Text(
                "SUPPORT",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 20),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            "How can we\nhelp you today?",
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.primaryNavy,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(0, "Submit Issue", Icons.edit_note_rounded),
          ),
          Expanded(
            child: _buildTabButton(1, "My Tickets (${_userTickets.length})", Icons.history_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _activeTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryNavy : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIssueReporter() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputLabel("Full Name"),
          _buildTextField(_nameController, "Enter your name", Icons.person_outline_rounded),
          const SizedBox(height: 24),
          
          _buildInputLabel("Email Address"),
          _buildTextField(_emailController, "Enter your email", Icons.alternate_email_rounded, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 24),
          
          _buildInputLabel("Phone Number"),
          _buildTextField(_phoneController, "Enter your phone", Icons.phone_android_rounded, keyboardType: TextInputType.phone),
          const SizedBox(height: 24),
          
          _buildInputLabel("Describe your issue"),
          _buildTextField(_issueController, "Provide details about your problem...", Icons.chat_bubble_outline_rounded, maxLines: 4),
          const SizedBox(height: 32),
          
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitTicket,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                shadowColor: AppColors.primaryNavy.withValues(alpha: 0.3),
              ),
              child: _isSubmitting
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Text(
                      "Submit", 
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800, 
                        fontSize: 16,
                        letterSpacing: 1,
                      )
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketHistory() {
    if (_userTickets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.support_agent_rounded, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text(
                "No tickets submitted yet",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "If you face any issues with your rides, submit a ticket and our support team will assist you.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _userTickets.map((ticket) => _buildTicketCard(ticket)).toList(),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final String ticketId = ticket['id'] ?? '';
    final bool isExpanded = _expandedTicketIds.contains(ticketId);
    
    final timestamp = ticket['timestamp'] as Timestamp?;
    final date = timestamp != null 
        ? DateFormat('MMM dd, hh:mm a').format(timestamp.toDate())
        : 'Recently';
    
    final status = ticket['status'] ?? 'Pending';
    final adminReply = ticket['adminReply'] as String?;
    final bool userRead = ticket['userRead'] ?? true;
    
    Color statusColor = AppColors.primaryYellow;
    if (status == 'Resolved') {
      statusColor = Colors.green;
    } else if (status == 'In Progress') {
      statusColor = AppColors.primaryNavy;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey(ticketId),
          initiallyExpanded: isExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              if (expanded) {
                _expandedTicketIds.add(ticketId);
                // Mark ticket as read when student views it
                if (!userRead) {
                  _firestore.collection('support_tickets').doc(ticketId).update({'userRead': true});
                }
              } else {
                _expandedTicketIds.remove(ticketId);
              }
            });
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          status.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 10, 
                            fontWeight: FontWeight.w800, 
                            color: statusColor,
                            letterSpacing: 0.5
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!userRead) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                date, 
                style: GoogleFonts.poppins(
                  fontSize: 11, 
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                )
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              ticket['issue'] ?? 'No description provided.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textDark,
                height: 1.5,
              ),
              maxLines: isExpanded ? 100 : 2,
              overflow: isExpanded ? null : TextOverflow.ellipsis,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1, color: AppColors.borderLight),
                  const SizedBox(height: 16),
                  
                  _buildDetailRow("Filed by", ticket['name'] ?? ''),
                  const SizedBox(height: 8),
                  _buildDetailRow("Phone", ticket['phone'] ?? ''),
                  const SizedBox(height: 8),
                  _buildDetailRow("Email", ticket['email'] ?? ''),
                  const SizedBox(height: 16),
                  
                  if (adminReply != null && adminReply.trim().isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.support_agent_rounded, size: 16, color: AppColors.primaryNavy),
                              const SizedBox(width: 8),
                              Text(
                                "ADMIN RESOLUTION",
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryNavy,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            adminReply,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppColors.textDark,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.hourglass_empty_rounded, size: 16, color: Colors.amber.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              status == 'In Progress' 
                                  ? "Support team is investigating your issue."
                                  : "Waiting for admin review.",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textDark,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 10),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 13),
        prefixIcon: Icon(icon, size: 20, color: AppColors.primaryNavy),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.primaryNavy, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(18),
      ),
    );
  }
}
