import 'package:flutter/material.dart';

enum NotificationType { support, alert, success, warning, info, sosResolved }

class SystemNotificationModel {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationType type;
  final bool isRead;
  final String? targetRole; // 'Student', 'Driver', or 'All'
  final String? alertId;
  final bool isReviewed;
  final String? imageUrl;

  SystemNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    this.isRead = false,
    this.targetRole = 'All',
    this.alertId,
    this.isReviewed = false,
    this.imageUrl,
  });

  factory SystemNotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return SystemNotificationModel(
      id: id,
      title: map['title'] ?? 'No Title',
      message: map['message'] ?? 'No Message',
      timestamp: map['timestamp'] != null 
          ? (map['timestamp'] as dynamic).toDate() 
          : DateTime.now(),
      type: _parseType(map['type']),
      isRead: map['isRead'] ?? false,
      targetRole: map['targetRole'] ?? 'All',
      alertId: map['alertId'],
      isReviewed: map['isReviewed'] ?? false,
      imageUrl: map['imageUrl'] ?? map['image'],
    );
  }

  static NotificationType _parseType(String? type) {
    switch (type?.toLowerCase()) {
      case 'alert': return NotificationType.alert;
      case 'success': return NotificationType.success;
      case 'warning': return NotificationType.warning;
      case 'support': return NotificationType.support;
      case 'sos_resolved': return NotificationType.sosResolved;
      default: return NotificationType.info;
    }
  }

  Color get color {
    switch (type) {
      case NotificationType.alert: return Colors.red;
      case NotificationType.success: return Colors.green;
      case NotificationType.warning: return Colors.orange;
      case NotificationType.support: return Colors.blue;
      case NotificationType.sosResolved: return Colors.green;
      case NotificationType.info: return const Color(0xFF0A1D56); // primaryNavy
    }
  }

  IconData get icon {
    switch (type) {
      case NotificationType.alert: return Icons.error_outline;
      case NotificationType.success: return Icons.check_circle_outline;
      case NotificationType.warning: return Icons.warning_amber_rounded;
      case NotificationType.support: return Icons.help_outline;
      case NotificationType.sosResolved: return Icons.rate_review_outlined;
      case NotificationType.info: return Icons.notifications_none_rounded;
    }
  }
}
