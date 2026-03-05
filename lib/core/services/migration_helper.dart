import 'package:cloud_firestore/cloud_firestore.dart';


/// One-time migration script to update existing recipes with a searchable name field.
Future<void> migrateRecipes() async {
  print("[Migration] Starting migration...");
  final firestore = FirebaseFirestore.instance;
  
  try {
    final snap = await firestore.collection('recipes').get();
    print("[Migration] Found ${snap.docs.length} recipes.");
    
    final batch = firestore.batch();
    int count = 0;
    
    for (var doc in snap.docs) {
      final data = doc.data();
      if (!data.containsKey('name_search')) {
        final name = data['name'] ?? data['title'] ?? '';
        batch.update(doc.reference, {
          'name_search': name.toString().toLowerCase(),
        });
        count++;
      }
    }
    
    if (count > 0) {
      await batch.commit();
      print("[Migration] Successfully updated $count recipes.");
    } else {
      print("[Migration] No recipes needed updating.");
    }
  } catch (e) {
    print("[Migration] Error during migration: $e");
  }
}



