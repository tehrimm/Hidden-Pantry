import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ProfileImageService {
  const ProfileImageService();

  Future<String?> pickAndUploadProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Not logged in.");

    // 1) Pick image from gallery
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85, // compress a bit
    );
    if (picked == null) return null; // user cancelled

    final file = File(picked.path);

    // 2) Upload to Firebase Storage
    final storage = FirebaseStorage.instance;
    final fileName = "profile_${DateTime.now().millisecondsSinceEpoch}.jpg";
    final path = "users/${user.uid}/profile/$fileName";

    final ref = storage.ref().child(path);
    final uploadTask = await ref.putFile(file);
    final url = await uploadTask.ref.getDownloadURL();

    // 3) Save URL to Firestore user doc
    final users = FirebaseFirestore.instance.collection("users");
    await users.doc(user.uid).set({
      "photoUrl": url,
      "photoPath": path,
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return url;
  }
}



