import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:pointycastle/asn1.dart';

class ChatEncryptionService {
  static ChatEncryptionService? _instance;
  
  final FlutterSecureStorage _storage;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? _cachedPrivateKeyJson;
  List<String> _cachedKeyHistory = [];

  ChatEncryptionService._internal({
    FlutterSecureStorage? storage,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _storage = storage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true, resetOnError: true),
        ),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  factory ChatEncryptionService({
    FlutterSecureStorage? storage,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) {
    if (storage == null && firestore == null && auth == null) {
      _instance ??= ChatEncryptionService._internal();
      return _instance!;
    }
    return ChatEncryptionService._internal(
      storage: storage,
      firestore: firestore,
      auth: auth,
    );
  }

  // Constants
  static const String _privateKeyPrefix = 'chat_private_key_';
  static const String _publicKeyPrefix = 'chat_public_key_';

  // --- RSA Initialization & Storage ---

  Future<void> initializeKeys() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final keyPath = '$_privateKeyPrefix${user.uid}';
    String? jsonKeyData;
    try {
      jsonKeyData = await _storage.read(key: keyPath);
    } catch (e) {
      debugPrint("Secure storage read error: $e");
    }

    // 1. Fetch cloud backup & history first
    List<String> cloudKeyHistory = [];
    String? cloudLatestKeyJson;
    String? cloudLatestPubStr;

    try {
      final backupDoc = await _firestore.collection('user_keys').doc(user.uid).get();
      if (backupDoc.exists && backupDoc.data() != null) {
        final data = backupDoc.data()!;
        cloudLatestKeyJson = data['privateKeyJson'];
        cloudLatestPubStr = data['publicKeyString'];
        if (data['keyHistory'] is List) {
          cloudKeyHistory = List<String>.from(data['keyHistory']);
        }
        if (cloudLatestKeyJson != null && !cloudKeyHistory.contains(cloudLatestKeyJson)) {
          cloudKeyHistory.add(cloudLatestKeyJson);
        }
      }
    } catch (e) {
      debugPrint("Error fetching cloud key history: $e");
    }

    bool isValid = false;
    if (jsonKeyData != null && jsonKeyData.startsWith('{')) {
      try {
        final Map<String, dynamic> keyMap = json.decode(jsonKeyData);
        final privateKey = _parsePrivateKeyFromJson(keyMap);
        
        // Self-test
        final testEncrypter = encrypt.Encrypter(encrypt.RSA(privateKey: privateKey));
        final testPublicEncrypter = encrypt.Encrypter(encrypt.RSA(publicKey: _derivePublicKey(privateKey)));
        final plain = "self_test_${user.uid}";
        final enc = testPublicEncrypter.encrypt(plain);
        if (testEncrypter.decrypt(enc) == plain) {
          isValid = true;
          _cachedPrivateKeyJson = jsonKeyData;
          if (!cloudKeyHistory.contains(jsonKeyData)) {
            cloudKeyHistory.add(jsonKeyData);
          }
          _cachedKeyHistory = cloudKeyHistory;
        }
      } catch (e) {
        debugPrint("JSON key invalid: $e");
      }
    }

    if (!isValid) {
      try {
        debugPrint("Local RSA key missing/invalid. Attempting cloud recovery from Firestore for ${user.uid}...");
        if (cloudLatestKeyJson != null && cloudLatestPubStr != null) {
          // Test restored key
          final Map<String, dynamic> keyMap = json.decode(cloudLatestKeyJson);
          final privateKey = _parsePrivateKeyFromJson(keyMap);
          final testEncrypter = encrypt.Encrypter(encrypt.RSA(privateKey: privateKey));
          final testPublicEncrypter = encrypt.Encrypter(encrypt.RSA(publicKey: _derivePublicKey(privateKey)));
          final plain = "self_test_${user.uid}";
          if (testEncrypter.decrypt(testPublicEncrypter.encrypt(plain)) == plain) {
            debugPrint("Cloud recovery successful! Restoring private key to local secure storage.");
            jsonKeyData = cloudLatestKeyJson;
            await _storage.write(key: keyPath, value: cloudLatestKeyJson);
            await _syncPublicKeyToFirestore(user.uid, cloudLatestPubStr);
            isValid = true;
            _cachedPrivateKeyJson = cloudLatestKeyJson;
            if (!cloudKeyHistory.contains(cloudLatestKeyJson)) {
              cloudKeyHistory.add(cloudLatestKeyJson);
            }
            _cachedKeyHistory = cloudKeyHistory;
          }
        }
      } catch (e) {
        debugPrint("Cloud recovery failed: $e");
      }
    }

    if (!isValid) {
      debugPrint("Regenerating RSA keys (JSON format) for ${user.uid}...");
      final keyPair = _generateRSAkeyPair();
      final priv = keyPair.privateKey as pc.RSAPrivateKey;
      final pub = keyPair.publicKey as pc.RSAPublicKey;

      final privateKeyJson = json.encode({
        'n': priv.n.toString(),
        'e': priv.publicExponent.toString(),
        'd': priv.privateExponent.toString(),
        'p': priv.p.toString(),
        'q': priv.q.toString(),
      });

      final publicKeyString = _publicKeyToString(pub);

      await _storage.write(key: keyPath, value: privateKeyJson);
      await _syncPublicKeyToFirestore(user.uid, publicKeyString);

      if (!cloudKeyHistory.contains(privateKeyJson)) {
        cloudKeyHistory.add(privateKeyJson);
      }
      _cachedPrivateKeyJson = privateKeyJson;
      _cachedKeyHistory = cloudKeyHistory;

      // Save backup to cloud
      try {
        await _firestore.collection('user_keys').doc(user.uid).set({
          'privateKeyJson': privateKeyJson,
          'publicKeyString': publicKeyString,
          'keyHistory': cloudKeyHistory,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint("Error saving key backup to cloud: $e");
      }
    } else {
      // ⚡ SELF-HEAL & BACKUP: Verify local keys match server and ensure backup exists
      try {
        final Map<String, dynamic> keyMap = json.decode(_cachedPrivateKeyJson!);
        final priv = _parsePrivateKeyFromJson(keyMap);
        final pub = _derivePublicKey(priv);
        final localPubStr = _publicKeyToString(pub);
        
        // Ensure backup is stored in cloud with complete key history
        _firestore.collection('user_keys').doc(user.uid).set({
          'privateKeyJson': _cachedPrivateKeyJson,
          'publicKeyString': localPubStr,
          'keyHistory': _cachedKeyHistory,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Fetch server key
        final nutDoc = await _firestore.collection('nutritionists').doc(user.uid).get();
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        final serverPubStr = nutDoc.data()?['chatPublicKey'] ?? userDoc.data()?['chatPublicKey'];

        if (serverPubStr != localPubStr) {
          debugPrint("RSA Sync: Server key mismatch detected. Re-syncing...");
          await _syncPublicKeyToFirestore(user.uid, localPubStr);
        }
      } catch (e) {
        debugPrint("RSA Sync Verification failed: $e");
      }
    }
  }

  pc.RSAPrivateKey _parsePrivateKeyFromJson(Map<String, dynamic> map) {
    return pc.RSAPrivateKey(
      BigInt.parse(map['n']),
      BigInt.parse(map['d']),
      BigInt.parse(map['p']),
      BigInt.parse(map['q']),
      map['e'] != null ? BigInt.parse(map['e']) : BigInt.from(65537),
    );
  }

  pc.RSAPublicKey _parsePublicKeyFromString(String s) {
    final parts = s.split(":");
    return pc.RSAPublicKey(BigInt.parse(parts[0]), BigInt.parse(parts[1]));
  }

  pc.RSAPublicKey _derivePublicKey(pc.RSAPrivateKey priv) {
    return pc.RSAPublicKey(priv.n!, priv.publicExponent!);
  }

  String _publicKeyToString(pc.RSAPublicKey pub) {
    return "${pub.n}:${pub.publicExponent}";
  }

  Future<void> _syncPublicKeyToFirestore(String uid, String publicKeyString) async {
    try {
      final userRef = _firestore.collection('users').doc(uid);
      final nutRef = _firestore.collection('nutritionists').doc(uid);
      
      final uDoc = await userRef.get();
      if (uDoc.exists) {
        await userRef.update({'chatPublicKey': publicKeyString});
      }
      
      final nDoc = await nutRef.get();
      if (nDoc.exists) {
        await nutRef.update({'chatPublicKey': publicKeyString});
      }
    } catch (e) {
      debugPrint("Error syncing public key to Firestore: $e");
    }
  }

  // --- Encryption & Decryption ---

  Future<Map<String, String>> encryptMessage(String plaintext, String recipientId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {'cipherText': plaintext, 'isEncrypted': 'false'};

      // Fetch keys
      String? recipientPubStr;
      final rDoc = await _firestore.collection('users').doc(recipientId).get();
      recipientPubStr = rDoc.data()?['chatPublicKey'] ?? (await _firestore.collection('nutritionists').doc(recipientId).get()).data()?['chatPublicKey'];

      if (recipientPubStr == null || !recipientPubStr.contains(":")) {
        return {'cipherText': plaintext, 'isEncrypted': 'false'};
      }

      // AES Logic
      final aesKeyBytes = _generateRandomBytes(32);
      final aesIVBytes = _generateRandomBytes(16);
      final aesEncrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key(aesKeyBytes), mode: encrypt.AESMode.cbc));
      final encryptedMessage = aesEncrypter.encrypt(plaintext, iv: encrypt.IV(aesIVBytes));
      final keyPayload = base64.encode(aesKeyBytes) + "|" + base64.encode(aesIVBytes);

      // RSA Logic for recipient
      final rsaRecipient = encrypt.Encrypter(encrypt.RSA(publicKey: _parsePublicKeyFromString(recipientPubStr)));
      final encKeyRecipient = rsaRecipient.encrypt(keyPayload).base64;

      // RSA Logic for sender (self-decryption) - ALWAYS derive from local private key for 100% consistency
      String? encKeySender;
      try {
        final keyData = _cachedPrivateKeyJson ?? await _storage.read(key: '$_privateKeyPrefix${user.uid}');
        if (keyData != null && keyData.startsWith('{')) {
          final priv = _parsePrivateKeyFromJson(json.decode(keyData));
          final pub = _derivePublicKey(priv);
          final rsaSender = encrypt.Encrypter(encrypt.RSA(publicKey: pub));
          encKeySender = rsaSender.encrypt(keyPayload).base64;
        }
      } catch (e) {
        debugPrint("Local public key derivation failed: $e");
      }

      return {
        'cipherText': encryptedMessage.base64,
        'encryptedKey': encKeyRecipient,
        'senderEncryptedKey': encKeySender ?? encKeyRecipient,
        'isEncrypted': 'true',
      };
    } catch (e) {
      debugPrint("Encryption error: $e");
      return {'cipherText': plaintext, 'isEncrypted': 'false'};
    }
  }

  String _fallbackDecryption(Map<String, dynamic> data) {
    // 1. Plaintext fallback — if 'text' is not a sentinel value, use it directly
    final text = data['text'];
    if (text != null &&
        text.toString().isNotEmpty &&
        text.toString() != "[Encrypted]") {
      return text.toString();
    }

    // 2. Only try to UTF-8 decode cipherText if it does NOT look like base64.
    //    Base64 strings use A-Z, a-z, 0-9, +, /, and = for padding.
    //    A real plaintext message would never match that pattern exclusively.
    final cipherText = data['cipherText'];
    if (cipherText != null && cipherText.toString().isNotEmpty) {
      final cipherStr = cipherText.toString();
      final isBase64Like = RegExp(r'^[A-Za-z0-9+/]+=*$').hasMatch(cipherStr);
      if (!isBase64Like) {
        // Looks like raw text — return if it has no control characters
        if (!cipherStr.contains(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'))) {
          return cipherStr;
        }
      }
    }

    // 3. Message was encrypted with a key that is no longer available
    return "[Message from earlier session]";
  }

  Future<String> decryptMessage(Map<String, dynamic> data) async {
    // 1. Fast-path: If it's explicitly not encrypted, or if we now save plaintext as fallback
    final textVal = data['text'];
    if (textVal != null && textVal.toString().isNotEmpty && textVal.toString() != "[Encrypted]") {
      return textVal.toString();
    }
    
    if (data['isEncrypted'] != 'true') return data['cipherText'] ?? "";
    
    final user = _auth.currentUser;
    if (user == null) return "[Error: No User]";

    final msgSender = data['senderId'] ?? "unknown";
    final msgTime = data['timestamp'] != null ? data['timestamp'].toString() : "no-timestamp";

    try {
      final keyPath = '$_privateKeyPrefix${user.uid}';
      String? keyData = _cachedPrivateKeyJson ?? await _storage.read(key: keyPath);

      // Merge cached history with Firestore backup — only fetch if cache seems incomplete
      List<String> history = List.from(_cachedKeyHistory);
      try {
        final backupDoc = await _firestore.collection('user_keys').doc(user.uid).get();
        if (backupDoc.exists && backupDoc.data() != null) {
          final bData = backupDoc.data()!;
          if (bData['keyHistory'] is List) {
            for (final k in List<String>.from(bData['keyHistory'])) {
              if (!history.contains(k)) history.add(k);
            }
          }
          final cloudLatest = bData['privateKeyJson'] as String?;
          if (cloudLatest != null && !history.contains(cloudLatest)) {
            history.add(cloudLatest);
          }
        }
      } catch (_) {}

      if (keyData != null && keyData.startsWith('{')) {
        _cachedPrivateKeyJson = keyData;
        if (!history.contains(keyData)) history.add(keyData);
      } else if (history.isNotEmpty) {
        _cachedPrivateKeyJson = history.last;
        await _storage.write(key: keyPath, value: _cachedPrivateKeyJson!);
      }
      _cachedKeyHistory = history;

      // Build a deduplicated list of private keys to attempt, most-recent first
      final List<String> keysToTry = [];
      if (_cachedPrivateKeyJson != null && !keysToTry.contains(_cachedPrivateKeyJson)) {
        keysToTry.add(_cachedPrivateKeyJson!);
      }
      for (final k in _cachedKeyHistory.reversed) {
        if (!keysToTry.contains(k)) keysToTry.add(k);
      }

      // Collect ALL encrypted key variants stored on the message
      // Try both the recipient-facing key AND the sender-copy key so that
      // either party can decrypt their own history regardless of which role
      // they held when the message was sent.
      final List<String?> encKeyVariants = [
        data['encryptedKey'] as String?,
        data['senderEncryptedKey'] as String?,
      ].where((v) => v != null && v.isNotEmpty).toList();

      if (encKeyVariants.isEmpty) {
        debugPrint("E2EE decrypt FAILED: no encryptedKey fields for message from $msgSender at $msgTime");
        return _fallbackDecryption(data);
      }

      // Exhaustive search: every private key × every encrypted-key variant
      for (final keyJsonStr in keysToTry) {
        for (final encKeyB64 in encKeyVariants) {
          try {
            final privKey = _parsePrivateKeyFromJson(json.decode(keyJsonStr));
            final rsa = encrypt.Encrypter(encrypt.RSA(privateKey: privKey));
            final decryptedPayload = rsa.decrypt(encrypt.Encrypted.fromBase64(encKeyB64!));

            final parts = decryptedPayload.split('|');
            if (parts.length >= 2) {
              final aesKey = encrypt.Key(base64.decode(parts[0]));
              final iv = encrypt.IV(base64.decode(parts[1]));
              final aes = encrypt.Encrypter(encrypt.AES(aesKey, mode: encrypt.AESMode.cbc));
              final decryptedText = aes.decrypt(
                encrypt.Encrypted.fromBase64(data['cipherText'] as String),
                iv: iv,
              );
              debugPrint("E2EE decrypt SUCCESS: Decrypted message from $msgSender at $msgTime. Text: '$decryptedText'");
              return decryptedText;
            }
          } catch (_) {
            // Wrong key or block-type mismatch — try next combination
          }
        }
      }

      debugPrint("E2EE decrypt FAILED with all available keys for message from $msgSender at $msgTime. Trying fallback...");
      return _fallbackDecryption(data);
    } catch (e) {
      debugPrint("E2EE decrypt FAILED: Error decrypting message from $msgSender at $msgTime. Error: $e");
      return _fallbackDecryption(data);
    }
  }

  // --- Helpers ---
  pc.AsymmetricKeyPair<pc.PublicKey, pc.PrivateKey> _generateRSAkeyPair() {
    final gen = pc.RSAKeyGenerator()..init(pc.ParametersWithRandom(pc.RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64), _secureRandom()));
    return gen.generateKeyPair();
  }

  pc.SecureRandom _secureRandom() {
    final sr = pc.FortunaRandom();
    final r = Random.secure();
    sr.seed(pc.KeyParameter(Uint8List.fromList(List.generate(32, (_) => r.nextInt(256)))));
    return sr;
  }

  Uint8List _generateRandomBytes(int len) => Uint8List.fromList(List.generate(len, (_) => Random.secure().nextInt(256)));
}
