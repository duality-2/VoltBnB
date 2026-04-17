import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:voltbnb/features/charger/models/special_price_rule.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final snapshot = await FirebaseFirestore.instance.collection('chargers').limit(1).get();
  if (snapshot.docs.isNotEmpty) {
    final docId = snapshot.docs.first.id;
    final rules = [
      SpecialPriceRule(startHour: 18, endHour: 21, multiplier: 1.5, label: 'Peak Surge').toMap(),
      SpecialPriceRule(startHour: 22, endHour: 5, multiplier: 0.8, label: 'Happy Hour Discount').toMap(),
    ];

    await FirebaseFirestore.instance.collection('chargers').doc(docId).update({
      'pricingRules': rules,
    });
    print('Updated charger $docId with sample dynamic pricing rules!');
  } else {
    print('No chargers found in Firestore.');
  }
}
