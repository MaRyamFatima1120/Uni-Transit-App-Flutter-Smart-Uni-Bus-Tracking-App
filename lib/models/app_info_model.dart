import 'package:cloud_firestore/cloud_firestore.dart';

class AppInfoModel {
  final String appName;
  final String appTagline;
  final String visionHeader;
  final String vision;
  final String version;
  final String university;
  final String appLogoUrl;
  
  // Design System
  final String primaryColor;
  final String accentColor;
  final String backgroundColor;
  final String cardColor;
  final String textPrimaryColor;
  final String textSecondaryColor;

  final List<ContributorModel> contributors;

  AppInfoModel({
    required this.appName,
    required this.appTagline,
    required this.visionHeader,
    required this.vision,
    required this.version,
    required this.university,
    required this.appLogoUrl,
    required this.primaryColor,
    required this.accentColor,
    required this.backgroundColor,
    required this.cardColor,
    required this.textPrimaryColor,
    required this.textSecondaryColor,
    required this.contributors,
  });

  factory AppInfoModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    return AppInfoModel(
      appName: data['appName'] ?? 'UniTransit',
      appTagline: data['appTagline'] ?? 'Smart University Transport System',
      visionHeader: data['visionHeader'] ?? 'PROJECT VISION',
      vision: data['vision'] ?? '',
      version: data['version'] ?? '',
      university: data['university'] ?? '',
      appLogoUrl: data['appLogoUrl'] ?? '',
      
      primaryColor: data['primaryColor'] ?? '#1A237E',
      accentColor: data['accentColor'] ?? '#FFC107',
      backgroundColor: data['backgroundColor'] ?? '#F8FAFC',
      cardColor: data['cardColor'] ?? '#FFFFFF',
      textPrimaryColor: data['textPrimaryColor'] ?? '#0F172A',
      textSecondaryColor: data['textSecondaryColor'] ?? '#64748B',
      
      contributors: (data['contributors'] as List? ?? [])
          .map((item) => ContributorModel.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'appName': appName,
      'appTagline': appTagline,
      'visionHeader': visionHeader,
      'vision': vision,
      'version': version,
      'university': university,
      'appLogoUrl': appLogoUrl,
      'primaryColor': primaryColor,
      'accentColor': accentColor,
      'backgroundColor': backgroundColor,
      'cardColor': cardColor,
      'textPrimaryColor': textPrimaryColor,
      'textSecondaryColor': textSecondaryColor,
      'contributors': contributors.map((c) => c.toMap()).toList(),
    };
  }
}

class ContributorModel {
  final String name;
  final String role;
  final String subtitle;

  ContributorModel({required this.name, required this.role, required this.subtitle});

  factory ContributorModel.fromMap(Map<String, dynamic> map) {
    return ContributorModel(
      name: map['name'] ?? '',
      role: map['role'] ?? '',
      subtitle: map['subtitle'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'role': role, 'subtitle': subtitle};
}
