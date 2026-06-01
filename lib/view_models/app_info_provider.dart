import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_info_model.dart';

final appInfoProvider = StreamProvider<AppInfoModel>((ref) {
  return FirebaseFirestore.instance
      .collection('app_settings')
      .doc('about')
      .snapshots()
      .map((snapshot) => AppInfoModel.fromFirestore(snapshot));
});
